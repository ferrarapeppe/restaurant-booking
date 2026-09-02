// Propone — e su richiesta applica — i tavoli di una prenotazione.
//
// La chiama l'app quando lo staff chiede "che tavoli le do?". Il calcolo sta
// in `_shared/tavoli.ts`, lo stesso che usa il modulo pubblico: cosi' la
// proposta che vedete in sala e quella che il sito fa da solo escono dalla
// stessa regola.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { proponiTavoli, assegna, type Combinazione } from '../_shared/tavoli.ts';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = Deno.env.get('SUPABASE_URL')!;
  const chiaveServizio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const chiaveAnonima = Deno.env.get('SUPABASE_ANON_KEY')!;

  try {
    // Solo staff attivo: assegnare tavoli e' un'operazione di sala.
    const comeChiamante = createClient(url, chiaveAnonima, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: { user } } = await comeChiamante.auth.getUser();
    if (!user) return risposta({ error: 'Non autenticato' }, 401);

    const db = createClient(url, chiaveServizio);
    const { data: membro } = await db
      .from('staff_members').select('active').eq('id', user.id).maybeSingle();
    if (!membro || membro.active !== true) {
      return risposta({ error: 'Accesso non abilitato' }, 403);
    }

    const corpo = await req.json().catch(() => ({}));
    const idPrenotazione = String(corpo.prenotazione_id ?? '').trim();
    const applica = corpo.applica === true;
    if (!idPrenotazione) return risposta({ error: 'Manca la prenotazione' }, 400);

    const { data: b } = await db
      .from('bookings')
      .select('id, date, time_start, time_end, party_size, table_id, internal_notes, '
        + 'tables!bookings_table_id_fkey(area_id)')
      .eq('restaurant_id', ID_RISTORANTE)
      .eq('id', idPrenotazione)
      .maybeSingle();
    if (!b) return risposta({ error: 'Prenotazione non trovata' }, 404);

    const persone = Number(b.party_size ?? 0);
    if (persone <= 0) return risposta({ error: 'Numero di persone non valido' }, 400);

    const inizio = String(b.time_start ?? '');
    // Le prenotazioni vecchie possono non avere una fine: si assumono due ore,
    // la stessa durata che usa il modulo pubblico.
    const fine = String(b.time_end ?? '') || sommaDueOre(inizio);

    // Quale sala. Nell'ordine: quella chiesta esplicitamente, quella del
    // tavolo gia' assegnato, quella scelta dal cliente nel modulo. Se non si
    // capisce, si valutano tutte e vince la combinazione migliore — senza
    // mai mescolarle fra loro.
    let aree: string[] = [];
    const areaChiesta = String(corpo.area_id ?? '').trim();
    if (areaChiesta) {
      aree = [areaChiesta];
    } else {
      const daTavolo = (b.tables as Record<string, unknown> | null)?.area_id;
      if (daTavolo) {
        aree = [String(daTavolo)];
      } else {
        const nome = nomeAreaScelta(String(b.internal_notes ?? ''));
        const { data: tutteAree } = await db
          .from('areas').select('id, name').eq('restaurant_id', ID_RISTORANTE);
        const trovata = (tutteAree ?? []).find((a: Record<string, unknown>) =>
          nome && String(a.name ?? '').toUpperCase() === nome.toUpperCase());
        aree = trovata
          ? [String(trovata.id)]
          : (tutteAree ?? []).map((a: Record<string, unknown>) => String(a.id));
      }
    }

    let migliore: Combinazione | null = null;
    for (const areaId of aree) {
      const c = await proponiTavoli(db, {
        idRistorante: ID_RISTORANTE,
        areaId,
        persone,
        data: String(b.date ?? ''),
        inizio,
        fine,
        escludiPrenotazione: idPrenotazione,
      });
      if (!c) continue;
      if (!migliore || c.spreco < migliore.spreco ||
          (c.spreco === migliore.spreco && c.tavoli.length < migliore.tavoli.length)) {
        migliore = c;
      }
    }

    if (!migliore) {
      return risposta({
        proposta: null,
        motivo: 'Nessuna combinazione libera per questa fascia oraria.',
      });
    }

    if (applica) await assegna(db, idPrenotazione, migliore.tavoli);

    return risposta({
      applicata: applica,
      proposta: {
        tavoli: migliore.tavoli.map((t) => ({ id: t.id, nome: t.name, posti: t.capacity })),
        posti: migliore.posti,
        persone,
        spreco: migliore.spreco,
        vicini: migliore.vicini,
      },
    });
  } catch (e) {
    return risposta({ error: String(e) }, 500);
  }
});

function sommaDueOre(ora: string): string {
  const [h, m] = ora.split(':').map(Number);
  if (!Number.isFinite(h)) return '23:59:00';
  const fine = (h + 2) % 24;
  return `${String(fine).padStart(2, '0')}:${String(m ?? 0).padStart(2, '0')}:00`;
}

/// La sala scelta dal cliente sta nel JSON delle note interne.
function nomeAreaScelta(grezzo: string): string {
  const m = /"area"\s*:\s*"([^"]*)"/.exec(grezzo);
  return (m?.[1] ?? '').trim();
}
