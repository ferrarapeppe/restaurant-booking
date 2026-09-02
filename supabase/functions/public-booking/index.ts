// Sportello pubblico del modulo di prenotazione.
//
// Prima il modulo e la pagina di stato parlavano direttamente al database con
// la chiave anonima, che e' pubblica: chiunque poteva leggere e riscrivere
// l'anagrafica clienti. Ora passano da qui, dove la chiave di servizio resta
// sul server e sono esposte solo quattro operazioni.
//
// Le regole di prenotazione (data di apertura, giorni chiusi, orari, coperti)
// sono verificate qui e non solo nel browser: chi salta il modulo e chiama
// direttamente non deve poter inserire quello che vuole.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { proponiTavoli, assegna } from '../_shared/tavoli.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ID_RISTORANTE = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
const ORARI_FISSI = ['18:30', '20:00', '22:00'];
const DURATA_MINUTI = 120;

function risposta(corpo: unknown, stato = 200) {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function isoDaData(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function oraFine(inizio: string): string {
  const [h, m] = inizio.split(':').map(Number);
  const fine = h * 60 + m + DURATA_MINUTI;
  return `${String(Math.floor(fine / 60) % 24).padStart(2, '0')}:${String(fine % 60).padStart(2, '0')}`;
}

/// Fascia oraria valida per una data: una data speciale vince sulla regola
/// settimanale, come fa il modulo.
function fasciaPerData(orari: Array<Record<string, unknown>>, iso: string) {
  const speciale = orari.find((h) => String(h.special_date ?? '').slice(0, 10) === iso);
  if (speciale) return speciale;
  const [a, m, g] = iso.split('-').map(Number);
  const giorno = new Date(a, m - 1, g);
  const dow = (giorno.getDay() + 6) % 7; // 0 = lunedi
  return orari.find((h) => !h.special_date && h.day_of_week === dow);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = Deno.env.get('SUPABASE_URL')!;
  const chiaveServizio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const db = createClient(url, chiaveServizio);

  const chiamaFunzione = async (nome: string, corpo: unknown) => {
    try {
      await fetch(`${url}/functions/v1/${nome}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${chiaveServizio}`,
        },
        body: JSON.stringify(corpo),
      });
    } catch (e) {
      // Una mail non partita non deve far fallire la prenotazione.
      console.warn(`${nome} non chiamata:`, e);
    }
  };

  try {
    const corpo = await req.json().catch(() => ({}));
    const azione = String(corpo.azione ?? '');

    // ── Dati per disegnare il modulo ─────────────────────────────────────────
    if (azione === 'configurazione') {
      const [ristorante, orari, aree] = await Promise.all([
        db.from('restaurants')
          .select('id, name, address, city, phone, email, settings')
          .eq('id', ID_RISTORANTE).single(),
        db.from('opening_hours')
          .select('id, day_of_week, special_date, is_closed, open_time, close_time, min_party_size, max_party_size, title')
          .eq('restaurant_id', ID_RISTORANTE).order('day_of_week'),
        db.from('areas')
          .select('id, name, sort_order')
          .eq('restaurant_id', ID_RISTORANTE).order('sort_order'),
      ]);
      return risposta({
        ristorante: ristorante.data,
        orari: orari.data ?? [],
        aree: aree.data ?? [],
      });
    }

    // ── Nuova prenotazione ───────────────────────────────────────────────────
    if (azione === 'prenota') {
      const nome = String(corpo.nome ?? '').trim();
      const cognome = String(corpo.cognome ?? '').trim();
      const email = String(corpo.email ?? '').trim().toLowerCase();
      const telefono = String(corpo.telefono ?? '').trim();
      const data = String(corpo.data ?? '').slice(0, 10);
      const ora = String(corpo.ora ?? '');
      const persone = Number(corpo.persone ?? 0);
      const idArea = String(corpo.area ?? '');
      const note = String(corpo.note ?? '').trim();
      const turno = String(corpo.turno ?? '').trim();

      if (!nome || !cognome) return risposta({ error: 'Nome e cognome sono obbligatori.' }, 400);
      if (!email.includes('@')) return risposta({ error: 'Email non valida.' }, 400);
      if (telefono.length < 6) return risposta({ error: 'Telefono non valido.' }, 400);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(data)) return risposta({ error: 'Data non valida.' }, 400);
      if (!ORARI_FISSI.includes(ora)) return risposta({ error: 'Orario non disponibile.' }, 400);

      const { data: ristorante } = await db.from('restaurants')
        .select('id, name, address, city, phone, email, settings')
        .eq('id', ID_RISTORANTE).single();
      if (!ristorante) return risposta({ error: 'Ristorante non trovato.' }, 404);

      // La data non deve essere passata ne' precedente all'apertura.
      const oggi = isoDaData(new Date());
      const apertura = String(
        (ristorante.settings as Record<string, unknown> | null)?.['prenotazioni_dal'] ?? '',
      ).slice(0, 10);
      const minima = apertura && apertura > oggi ? apertura : oggi;
      if (data < minima) {
        return risposta({ error: 'Non accettiamo ancora prenotazioni per questa data.' }, 400);
      }

      const { data: orari } = await db.from('opening_hours')
        .select('day_of_week, special_date, is_closed, min_party_size, max_party_size')
        .eq('restaurant_id', ID_RISTORANTE);
      const fascia = fasciaPerData(orari ?? [], data);
      if (!fascia || fascia.is_closed === true) {
        return risposta({ error: 'Il ristorante è chiuso in questa data.' }, 400);
      }

      const minimo = Number(fascia.min_party_size ?? 2);
      const massimo = Number(fascia.max_party_size ?? 15);
      if (!Number.isInteger(persone) || persone < minimo || persone > massimo) {
        return risposta({ error: `Il numero di persone deve essere tra ${minimo} e ${massimo}.` }, 400);
      }

      const { data: area } = await db.from('areas')
        .select('id, name').eq('id', idArea).eq('restaurant_id', ID_RISTORANTE).maybeSingle();
      if (!area) return risposta({ error: 'Area non valida.' }, 400);

      // Cliente: si aggiorna se esiste gia', altrimenti si crea.
      let idOspite: string | null = null;
      const { data: esistenti } = await db.from('guests')
        .select('id').eq('restaurant_id', ID_RISTORANTE).eq('email', email).limit(1);
      const completo = cognome ? `${nome} ${cognome}` : nome;
      if (esistenti && esistenti.length > 0) {
        idOspite = esistenti[0].id as string;
        await db.from('guests')
          .update({ name: completo, first_name: nome, surname: cognome, phone: telefono, email })
          .eq('id', idOspite);
      } else {
        const { data: nuovo } = await db.from('guests').insert({
          restaurant_id: ID_RISTORANTE,
          name: completo, first_name: nome, surname: cognome,
          phone: telefono, email, visits_count: 0, tags: [],
        }).select('id').single();
        idOspite = (nuovo?.id as string) ?? null;
      }

      const inizio = `${ora}:00`;
      const fine = `${oraFine(ora)}:00`;

      const { data: prenotazione, error: errorePrenotazione } = await db.from('bookings').insert({
        restaurant_id: ID_RISTORANTE,
        guest_id: idOspite,
        date: data,
        time_start: inizio,
        time_end: fine,
        party_size: persone,
        status: 'pending',
        source: 'web',
        notes: note || null,
        internal_notes: JSON.stringify({ turno, area: area.name }),
      }).select('id').single();

      if (errorePrenotazione || !prenotazione) {
        return risposta({ error: errorePrenotazione?.message ?? 'Prenotazione non registrata.' }, 400);
      }
      const idPrenotazione = prenotazione.id as string;

      // Pre-assegnazione dei tavoli, che possono essere piu' d'uno.
      //
      // Prima cercava un tavolo solo abbastanza grande: sei persone nel
      // dehors, dove i tavoli sono tutti da due, non entravano da nessuna
      // parte e la prenotazione restava senza niente. Ora si combinano.
      //
      // E' una proposta, non l'ultima parola: il proprietario la rivede in
      // sala. Per questo un errore qui non blocca la prenotazione.
      try {
        const scelta = await proponiTavoli(db, {
          idRistorante: ID_RISTORANTE,
          areaId: area.id as string,
          persone,
          data,
          inizio,
          fine,
          escludiPrenotazione: idPrenotazione,
        });
        if (scelta) await assegna(db, idPrenotazione, scelta.tavoli);
      } catch (e) {
        console.warn('assegnazione tavoli non riuscita:', e);
      }

      await chiamaFunzione('send-booking-email', {
        nome, cognome, email, phone: telefono,
        date: `${data}T00:00:00`,
        time: ora, persons: persone, notes: note, turno, area: area.name,
        restaurantName: ristorante.name,
        restaurantAddress: ristorante.address ?? '',
        restaurantCity: ristorante.city ?? '',
        restaurantPhone: ristorante.phone ?? '',
        restaurantEmail: ristorante.email ?? '',
        bookingId: idPrenotazione,
      });

      return risposta({ bookingId: idPrenotazione });
    }

    // ── Stato di una prenotazione ────────────────────────────────────────────
    // L'identificativo e' un UUID non indovinabile: e' quello a fare da chiave,
    // come prima. Si restituisce solo cio' che la pagina mostra davvero.
    if (azione === 'stato') {
      const id = String(corpo.id ?? '');
      if (!id) return risposta({ error: 'Prenotazione non trovata.' }, 404);

      const { data: prenotazione } = await db.from('bookings')
        .select('id, date, time_start, time_end, party_size, status, notes, internal_notes, created_at, restaurant_id, guests(first_name, surname)')
        .eq('id', id).maybeSingle();
      if (!prenotazione) return risposta({ error: 'Prenotazione non trovata.' }, 404);

      const [ristorante, messaggi] = await Promise.all([
        db.from('restaurants').select('name, address, city, phone, email')
          .eq('id', prenotazione.restaurant_id).single(),
        db.from('booking_messages').select('sender, message, created_at')
          .eq('booking_id', id).order('created_at', { ascending: true }),
      ]);

      return risposta({
        prenotazione,
        ristorante: ristorante.data,
        messaggi: messaggi.data ?? [],
      });
    }

    // ── Messaggio del cliente ────────────────────────────────────────────────
    if (azione === 'messaggio') {
      const id = String(corpo.id ?? '');
      const testo = String(corpo.testo ?? '').trim();
      if (!id || !testo) return risposta({ error: 'Messaggio vuoto.' }, 400);
      if (testo.length > 2000) return risposta({ error: 'Messaggio troppo lungo.' }, 400);

      const { data: prenotazione } = await db.from('bookings')
        .select('id, date, time_start, party_size, restaurant_id, guests(first_name, surname, phone, email)')
        .eq('id', id).maybeSingle();
      if (!prenotazione) return risposta({ error: 'Prenotazione non trovata.' }, 404);

      const { error } = await db.from('booking_messages')
        .insert({ booking_id: id, sender: 'guest', message: testo });
      if (error) return risposta({ error: error.message }, 400);

      const { data: ristorante } = await db.from('restaurants')
        .select('name, address, city, email').eq('id', prenotazione.restaurant_id).single();
      const ospite = (prenotazione.guests ?? {}) as Record<string, unknown>;

      await chiamaFunzione('send-guest-message-email', {
        messaggio: testo,
        nome: ospite.first_name ?? '', cognome: ospite.surname ?? '',
        telefono: ospite.phone ?? '', emailCliente: ospite.email ?? '',
        date: prenotazione.date, time: prenotazione.time_start,
        persons: prenotazione.party_size, bookingId: id,
        restaurantName: ristorante?.name ?? '',
        restaurantAddress: ristorante?.address ?? '',
        restaurantCity: ristorante?.city ?? '',
        restaurantEmail: ristorante?.email ?? '',
      });

      return risposta({ ok: true });
    }

    return risposta({ error: 'Azione sconosciuta' }, 400);
  } catch (e) {
    return risposta({ error: String(e) }, 500);
  }
});
