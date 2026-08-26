// Gestione dei membri dello staff.
//
// Creare o cancellare un utente richiede la chiave di servizio, che non puo'
// stare nel sito: chiunque la leggesse potrebbe crearsi un accesso. Percio' le
// modifiche passano da qui, dove la chiave resta sul server, e solo dopo aver
// verificato che chi chiama sia davvero un amministratore.

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Le sezioni assegnabili. Tenerle qui evita che il browser possa inventarsi
// permessi non previsti passando chiavi arbitrarie.
const SEZIONI_VALIDE = [
  'dashboard', 'calendar', 'reservations', 'bookings',
  'floor_plan', 'guests', 'reports', 'assistente', 'settings',
];

function risposta(corpo: unknown, stato = 200) {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const urlSupabase = Deno.env.get('SUPABASE_URL')!;
  const chiaveServizio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const chiaveAnonima = Deno.env.get('SUPABASE_ANON_KEY')!;

  try {
    // 1. Chi sta chiamando? Il token arriva dall'app di chi e' entrato.
    const autorizzazione = req.headers.get('Authorization') ?? '';
    const comeChiamante = createClient(urlSupabase, chiaveAnonima, {
      global: { headers: { Authorization: autorizzazione } },
    });
    const { data: { user }, error: erroreUtente } = await comeChiamante.auth.getUser();
    if (erroreUtente || !user) return risposta({ error: 'Non autenticato' }, 401);

    // 2. E' un amministratore attivo? La verifica usa la chiave di servizio,
    //    cosi' non dipende dalle policy della tabella.
    const server = createClient(urlSupabase, chiaveServizio);
    const { data: chiamante } = await server
      .from('staff_members')
      .select('restaurant_id, role, active')
      .eq('id', user.id)
      .maybeSingle();

    if (!chiamante || chiamante.role !== 'admin' || !chiamante.active) {
      return risposta({ error: 'Riservato agli amministratori' }, 403);
    }
    const idRistorante = chiamante.restaurant_id;

    const corpo = await req.json().catch(() => ({}));
    const azione = String(corpo.azione ?? '');

    // ── Elenco ───────────────────────────────────────────────────────────────
    if (azione === 'elenco') {
      const { data, error } = await server
        .from('staff_members')
        .select('id, email, full_name, role, sections, active, created_at')
        .eq('restaurant_id', idRistorante)
        .order('created_at');
      if (error) return risposta({ error: error.message }, 400);
      return risposta({ membri: data ?? [] });
    }

    // ── Creazione ────────────────────────────────────────────────────────────
    if (azione === 'crea') {
      const email = String(corpo.email ?? '').trim().toLowerCase();
      const password = String(corpo.password ?? '');
      const nome = String(corpo.nome ?? '').trim();
      const ruolo = corpo.ruolo === 'admin' ? 'admin' : 'staff';
      const sezioni = (Array.isArray(corpo.sezioni) ? corpo.sezioni : [])
        .filter((s: unknown) => SEZIONI_VALIDE.includes(String(s)));

      if (!email.includes('@')) return risposta({ error: 'Email non valida' }, 400);
      if (password.length < 8) return risposta({ error: 'La password deve avere almeno 8 caratteri' }, 400);

      const { data: creato, error: erroreCreazione } = await server.auth.admin.createUser({
        email,
        password,
        email_confirm: true, // niente email di conferma: l'accesso lo consegna l'amministratore
      });
      if (erroreCreazione || !creato?.user) {
        return risposta({ error: erroreCreazione?.message ?? 'Creazione non riuscita' }, 400);
      }

      const { error: erroreRiga } = await server.from('staff_members').insert({
        id: creato.user.id,
        restaurant_id: idRistorante,
        email,
        full_name: nome,
        role: ruolo,
        sections: sezioni,
      });
      if (erroreRiga) {
        // Senza la riga dei permessi l'utente non potrebbe entrare da nessuna
        // parte: meglio non lasciarlo in giro a meta'.
        await server.auth.admin.deleteUser(creato.user.id);
        return risposta({ error: erroreRiga.message }, 400);
      }
      return risposta({ id: creato.user.id });
    }

    // ── Modifica ─────────────────────────────────────────────────────────────
    if (azione === 'modifica') {
      const id = String(corpo.id ?? '');
      if (!id) return risposta({ error: 'Manca l\'utente' }, 400);

      const { data: bersaglio } = await server
        .from('staff_members').select('id, role').eq('id', id)
        .eq('restaurant_id', idRistorante).maybeSingle();
      if (!bersaglio) return risposta({ error: 'Membro non trovato' }, 404);

      const modifiche: Record<string, unknown> = {};
      if (corpo.nome !== undefined) modifiche.full_name = String(corpo.nome).trim();
      if (corpo.ruolo !== undefined) modifiche.role = corpo.ruolo === 'admin' ? 'admin' : 'staff';
      if (corpo.attivo !== undefined) modifiche.active = corpo.attivo === true;
      if (Array.isArray(corpo.sezioni)) {
        modifiche.sections = corpo.sezioni.filter((s: unknown) => SEZIONI_VALIDE.includes(String(s)));
      }

      // Non ci si toglie da soli l'amministrazione: sarebbe un modo silenzioso
      // di restare chiusi fuori dalla gestione del team.
      const siDeclassa = id === user.id &&
        (modifiche.role === 'staff' || modifiche.active === false);
      if (siDeclassa) {
        return risposta({ error: 'Non puoi togliere a te stesso i permessi di amministratore' }, 400);
      }

      if (Object.keys(modifiche).length > 0) {
        const { error } = await server.from('staff_members').update(modifiche).eq('id', id);
        if (error) return risposta({ error: error.message }, 400);
      }

      if (corpo.password) {
        const password = String(corpo.password);
        if (password.length < 8) return risposta({ error: 'La password deve avere almeno 8 caratteri' }, 400);
        const { error } = await server.auth.admin.updateUserById(id, { password });
        if (error) return risposta({ error: error.message }, 400);
      }
      return risposta({ ok: true });
    }

    // ── Eliminazione ─────────────────────────────────────────────────────────
    if (azione === 'elimina') {
      const id = String(corpo.id ?? '');
      if (id === user.id) return risposta({ error: 'Non puoi eliminare te stesso' }, 400);

      const { data: bersaglio } = await server
        .from('staff_members').select('id').eq('id', id)
        .eq('restaurant_id', idRistorante).maybeSingle();
      if (!bersaglio) return risposta({ error: 'Membro non trovato' }, 404);

      const { error } = await server.auth.admin.deleteUser(id); // la riga cade con l'utente
      if (error) return risposta({ error: error.message }, 400);
      return risposta({ ok: true });
    }

    return risposta({ error: 'Azione sconosciuta' }, 400);
  } catch (e) {
    return risposta({ error: String(e) }, 500);
  }
});
