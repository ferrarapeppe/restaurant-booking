// Il banco di comando degli avvisi Telegram.
//
// Tre cose che il modulo condiviso non puo' fare da solo:
//   `chat-trovate`  scopre a quali chat il bot puo' scrivere, cosi' il
//                   proprietario non deve andare a cercare un numero di chat
//                   dentro una pagina di documentazione;
//   `prova`         manda un messaggio di prova, per sapere subito se
//                   funziona invece di scoprirlo alla prima prenotazione;
//   `stato`         avvisa quando una prenotazione cambia stato;
//   `riepilogo`     il messaggio della giornata, chiamato dal programmatore.
//
// Le prime tre le usa lo staff dall'app e vogliono un accesso valido.
// `riepilogo` arriva da un lavoro programmato, che si presenta con un gettone
// suo: non ha una persona dietro a cui chiedere le credenziali.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { avvisa, dataEstesa, impostazioni, inviaA, pulisci } from '../_shared/telegram.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ID_RISTORANTE = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

function risposta(corpo: unknown, stato = 200) {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/// Chi chiede deve essere personale in servizio.
// deno-lint-ignore no-explicit-any
async function staffValido(req: Request, db: any): Promise<boolean> {
  const intestazione = req.headers.get('Authorization') ?? '';
  const gettone = intestazione.replace('Bearer ', '').trim();
  if (!gettone) return false;
  const anonimo = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: `Bearer ${gettone}` } } },
  );
  const { data: utente } = await anonimo.auth.getUser();
  if (!utente?.user) return false;
  // In `staff_members` la chiave e' `id`, che *e'* l'identificativo
  // dell'utente: non c'e' nessuna colonna `user_id`. Cercando quella la
  // richiesta non trovava nessuno e rispondeva 401 a chi era regolarmente
  // dentro. Stesso controllo di `assegna-tavoli`.
  const { data: membro } = await db
    .from('staff_members')
    .select('active')
    .eq('id', utente.user.id)
    .maybeSingle();
  return membro?.active === true;
}

const ETICHETTE: Record<string, string> = {
  canceled: 'annullata dal cliente',
  no_show: 'segnata come non presentata',
  rejected: 'rifiutata',
  approved: 'accettata',
  seated: 'accomodata',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    const corpo = await req.json().catch(() => ({}));
    const azione = String(corpo.azione ?? '');

    // ── Il riepilogo della giornata ─────────────────────────────────────────
    // Si presenta col gettone del programmatore, non con un accesso di
    // persona: non c'e' nessuno seduto davanti alle otto del mattino.
    if (azione === 'riepilogo') {
      const atteso = Deno.env.get('TELEGRAM_CRON_TOKEN') ?? '';
      if (!atteso || String(corpo.gettone ?? '') !== atteso) {
        return risposta({ error: 'Non autorizzato.' }, 401);
      }
      return risposta(await mandaRiepilogo(db, String(corpo.data ?? '')));
    }

    if (!await staffValido(req, db)) {
      return risposta({ error: 'Non autorizzato.' }, 401);
    }

    // ── A quali chat puo' scrivere il bot ───────────────────────────────────
    // Telegram non ha un elenco dei destinatari: si ricava da chi ha scritto
    // di recente. Per questo l'app chiede di mandare un messaggio nel gruppo
    // prima di premere "Cerca".
    if (azione === 'chat-trovate') {
      const gettone = Deno.env.get('TELEGRAM_BOT_TOKEN');
      if (!gettone) {
        return risposta({ error: 'Il gettone del bot non è impostato.' }, 400);
      }
      const r = await fetch(`https://api.telegram.org/bot${gettone}/getUpdates`);
      const esito = await r.json().catch(() => ({}));
      if (!esito.ok) {
        return risposta({ error: String(esito.description ?? 'Telegram non risponde.') }, 400);
      }
      const viste = new Map<string, { id: string; nome: string; tipo: string }>();
      for (const agg of esito.result ?? []) {
        const chat = agg.message?.chat ?? agg.my_chat_member?.chat ??
          agg.channel_post?.chat;
        if (!chat) continue;
        viste.set(String(chat.id), {
          id: String(chat.id),
          nome: String(chat.title ?? [chat.first_name, chat.last_name].filter(Boolean).join(' ') ?? chat.id),
          tipo: String(chat.type ?? ''),
        });
      }
      return risposta({ chats: [...viste.values()] });
    }

    // ── Messaggio di prova ──────────────────────────────────────────────────
    if (azione === 'prova') {
      const chat = String(corpo.chat_id ?? '');
      if (!chat) return risposta({ error: 'Manca la chat.' }, 400);
      const errore = await inviaA(
        chat,
        '<b>HIO ORIENTAL</b>\nGli avvisi del gestionale arrivano qui.',
      );
      return errore ? risposta({ error: errore }, 400) : risposta({ ok: true });
    }

    // ── Cambio di stato di una prenotazione ─────────────────────────────────
    // Il testo si costruisce qui leggendo il database, non si prende da chi
    // chiama: un avviso deve dire quello che e' successo davvero.
    if (azione === 'stato') {
      const id = String(corpo.prenotazione_id ?? '');
      if (!id) return risposta({ error: 'Manca la prenotazione.' }, 400);
      const { data: b } = await db
        .from('bookings')
        .select('date, time_start, party_size, status, guests(first_name, surname, name, phone)')
        .eq('id', id)
        .maybeSingle();
      if (!b) return risposta({ error: 'Prenotazione non trovata.' }, 404);
      const etichetta = ETICHETTE[String(b.status)];
      // Solo i passaggi che tolgono qualcuno dalla sala: gli altri li vede
      // gia' chi li sta facendo, e un avviso per ogni tocco e' rumore.
      if (String(b.status) !== 'canceled' && String(b.status) !== 'no_show') {
        return risposta({ ok: true, saltato: true });
      }
      // deno-lint-ignore no-explicit-any
      const g = b.guests as any;
      const nome = [g?.first_name, g?.surname].filter(Boolean).join(' ') ||
        g?.name || 'Cliente';
      await avvisa(
        db,
        ID_RISTORANTE,
        'annullamento',
        `❌ <b>Prenotazione ${etichetta ?? 'aggiornata'}</b>\n` +
          `${pulisci(nome)} — ${dataEstesa(String(b.date))} alle ` +
          `${String(b.time_start).slice(0, 5)}\n` +
          `${b.party_size} ${b.party_size === 1 ? 'persona' : 'persone'}\n` +
          `Il tavolo torna libero.`,
      );
      return risposta({ ok: true });
    }

    return risposta({ error: 'Azione sconosciuta.' }, 400);
  } catch (e) {
    console.error('telegram:', e);
    return risposta({ error: String(e) }, 500);
  }
});

/// Il messaggio della giornata: coperti per turno e cose in sospeso.
// deno-lint-ignore no-explicit-any
async function mandaRiepilogo(db: any, dataChiesta: string) {
  const oggi = dataChiesta || new Date().toISOString().slice(0, 10);
  const { data: righe } = await db
    .from('bookings')
    .select('time_start, party_size, status, internal_notes, guests(first_name, surname, name)')
    .eq('restaurant_id', ID_RISTORANTE)
    .eq('date', oggi)
    .neq('status', 'canceled_by_venue');

  const vive = (righe ?? []).filter((b: Record<string, unknown>) =>
    ['approved', 'pending', 'seated', 'completed'].includes(String(b.status))
  );
  const inAttesa = vive.filter((b: Record<string, unknown>) => b.status === 'pending');
  const coperti = vive.reduce(
    (s: number, b: Record<string, unknown>) => s + Number(b.party_size ?? 0),
    0,
  );

  // Per turno, sull'orario: le prenotazioni prese al telefono non hanno un
  // turno scelto e senza questo sparirebbero dal conto.
  const turni = new Map<string, { coperti: number; tavoli: number }>();
  for (const b of vive) {
    const ora = String(b.time_start ?? '').slice(0, 5);
    const voce = turni.get(ora) ?? { coperti: 0, tavoli: 0 };
    voce.coperti += Number(b.party_size ?? 0);
    voce.tavoli += 1;
    turni.set(ora, voce);
  }
  const ordinati = [...turni.entries()].sort((a, b) => a[0].localeCompare(b[0]));

  const parti = [
    `📋 <b>${dataEstesa(oggi)}</b>`,
    vive.length === 0
      ? 'Nessuna prenotazione.'
      : `${vive.length} prenotazioni — ${coperti} coperti`,
  ];
  for (const [ora, v] of ordinati) {
    parti.push(`• ${ora} — ${v.coperti} coperti su ${v.tavoli} ${v.tavoli === 1 ? 'tavolo' : 'tavoli'}`);
  }
  if (inAttesa.length > 0) {
    parti.push('');
    parti.push(`⏳ <b>${inAttesa.length} da approvare</b>`);
    for (const b of inAttesa.slice(0, 10)) {
      // deno-lint-ignore no-explicit-any
      const g = b.guests as any;
      const nome = [g?.first_name, g?.surname].filter(Boolean).join(' ') ||
        g?.name || 'Cliente';
      parti.push(`• ${String(b.time_start).slice(0, 5)} ${pulisci(nome)} (${b.party_size})`);
    }
  }

  await avvisa(db, ID_RISTORANTE, 'riepilogo', parti.join('\n'));
  const cfg = await impostazioni(db, ID_RISTORANTE);
  return { ok: true, destinatari: cfg.chats.length, prenotazioni: vive.length };
}
