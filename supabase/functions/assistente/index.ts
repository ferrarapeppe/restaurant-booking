// Assistente: risponde a domande sulle prenotazioni con i dati veri.
//
// Il modello non interroga il database: sceglie fra un elenco chiuso di
// domande che sappiamo rispondere, noi le eseguiamo, e lui mette i risultati
// in italiano. Lasciargli scrivere le query sarebbe piu' potente, ma vorrebbe
// dire dare a un sistema che a volte sbaglia la possibilita' di leggere o
// modificare qualunque cosa.
//
// Escono verso OpenAI solo i dati che la domanda richiede: mai l'archivio
// intero, e telefoni ed email solo cercando un cliente per nome.

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ID_RISTORANTE = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
// `trim`: incollando il nome nel pannello dei segreti ci finisce spesso uno
// spazio o un a capo, e OpenAI rifiuta "gpt-4o " senza dire perché.
const MODELLO = (Deno.env.get('OPENAI_MODEL') ?? '').trim() || 'gpt-4o-mini';
const GIRI_MASSIMI = 5;

function risposta(corpo: unknown, stato = 200) {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

const oggiIso = () => new Date().toISOString().slice(0, 10);

/// "2026-09-12" -> "sabato 12 settembre". Nel riquadro di conferma il
/// giorno della settimana vale più della data: un errore si vede a colpo d'occhio.
function dataEstesa(iso: string): string {
  try {
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString('it-IT', {
      weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC',
    });
  } catch (_) {
    return iso;
  }
}

// ── Cosa il modello puo' chiedere ────────────────────────────────────────────

const STRUMENTI = [
  {
    type: 'function',
    function: {
      name: 'elenco_prenotazioni',
      description: 'Elenco nominativo delle prenotazioni fra due date, con nome '
        + 'e cognome del cliente, telefono, orario, persone, stato, turno, tavolo, '
        + 'area e note. Per un giorno solo passa la stessa data in "da" e in "a". '
        + 'Usalo ogni volta che servono i nomi o i dettagli delle singole '
        + 'prenotazioni, anche su un mese intero: non chiamarlo giorno per giorno.',
      parameters: {
        type: 'object',
        properties: {
          da: { type: 'string', description: 'primo giorno, aaaa-mm-gg' },
          a: { type: 'string', description: 'ultimo giorno compreso, aaaa-mm-gg' },
        },
        required: ['da', 'a'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'conteggi_periodo',
      description: 'Numeri di un intervallo di date: quante prenotazioni, quanti '
        + 'coperti, divisi per stato, per turno, per area e per giorno. Usalo '
        + 'per QUALUNQUE domanda che copra piu\' di un giorno — un mese '
        + '("a settembre"), una settimana, un anno, "finora", "da qui a Natale" '
        + '— passando il primo e l\'ultimo giorno del periodo. Restituisce solo '
        + 'numeri: per i nomi usa elenco_prenotazioni.',
      parameters: {
        type: 'object',
        properties: {
          da: { type: 'string', description: 'aaaa-mm-gg' },
          a: { type: 'string', description: 'aaaa-mm-gg' },
        },
        required: ['da', 'a'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'proponi_operazione',
      description: 'Prepara un\'operazione su UNA prenotazione e la sottopone al '
        + 'personale. NON esegue niente: nessuna riga viene toccata e nessuna mail '
        + 'parte finché una persona non conferma toccando il pulsante. Usalo quando '
        + 'ti chiedono di accettare, assegnare o spostare un tavolo, annullare o '
        + 'correggere una prenotazione. Prima trova la prenotazione con '
        + 'elenco_prenotazioni per averne l\'id: non inventare mai un id. '
        + 'Se la richiesta riguarda più prenotazioni, chiamalo una volta per ognuna.',
      parameters: {
        type: 'object',
        properties: {
          tipo: {
            type: 'string',
            enum: ['accetta', 'tavolo', 'annulla', 'modifica'],
            description: 'accetta = conferma la prenotazione (manda la mail al '
              + 'cliente); tavolo = assegna o sposta il tavolo (nessuna mail); '
              + 'annulla = annulla o rifiuta (manda la mail al cliente); '
              + 'modifica = cambia persone, orario o note.',
          },
          id: { type: 'string', description: 'id preso da elenco_prenotazioni' },
          tavolo: { type: 'string', description: 'nome del tavolo, solo per tipo=tavolo' },
          persone: { type: 'integer', description: 'solo per tipo=modifica' },
          ora: { type: 'string', description: 'hh:mm, solo per tipo=modifica' },
          note: { type: 'string', description: 'solo per tipo=modifica' },
          motivo: {
            type: 'string',
            description: 'solo per tipo=annulla: "Al completo", "Chiuso" o "Altro"',
          },
        },
        required: ['tipo', 'id'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'cerca_cliente',
      description: 'Cerca un cliente per nome, cognome, telefono o email, e '
        + 'restituisce le sue prenotazioni.',
      parameters: {
        type: 'object',
        properties: { testo: { type: 'string' } },
        required: ['testo'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'orari_apertura',
      description: 'Giorni di apertura e chiusura, chiusure straordinarie, '
        + 'data da cui il sito accetta prenotazioni.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'tavoli_e_aree',
      description: 'Tavoli del locale con posti e area di appartenenza.',
      parameters: { type: 'object', properties: {} },
    },
  },
];

// ── Esecuzione ───────────────────────────────────────────────────────────────

function turnoDi(b: Record<string, unknown>): string {
  const grezzo = String(b.internal_notes ?? '');
  const t = grezzo.toUpperCase();
  if (t.includes('APERITIF') || t.includes('APERITIVO')) return 'aperitivo';
  if (t.includes('1°') || t.includes('1 TURNO')) return '1° turno';
  if (t.includes('2°') || t.includes('2 TURNO')) return '2° turno';
  const ora = String(b.time_start ?? '');
  if (ora.startsWith('18') || ora.startsWith('19')) return 'aperitivo';
  if (ora.startsWith('20') || ora.startsWith('21')) return '1° turno';
  if (ora.startsWith('22') || ora.startsWith('23')) return '2° turno';
  return 'non indicato';
}

function areaDi(b: Record<string, unknown>): string {
  const t = b.tables as Record<string, unknown> | null;
  const daTavolo = (t?.areas as Record<string, unknown> | null)?.name;
  if (daTavolo) return String(daTavolo);
  const m = /"area"\s*:\s*"([^"]*)"/.exec(String(b.internal_notes ?? ''));
  return (m?.[1] ?? 'non indicata').trim();
}

function nomeOspite(g: Record<string, unknown> | null): string {
  if (!g) return 'senza scheda';
  const unito = `${g.first_name ?? ''} ${g.surname ?? ''}`.trim();
  return unito || String(g.name ?? 'ospite');
}

const STATI: Record<string, string> = {
  approved: 'accettata', pending: 'in attesa', seated: 'arrivata',
  completed: 'conclusa', canceled: 'annullata', rejected: 'rifiutata',
  no_show: 'non presentato',
};

// deno-lint-ignore no-explicit-any
async function esegui(
  db: any,
  nome: string,
  arg: Record<string, unknown>,
  proposte: Record<string, unknown>[],
) {
  if (nome === 'elenco_prenotazioni') {
    // Un mese pieno sono poche centinaia di righe: si leggono in una volta.
    // Il tetto serve solo a non far esplodere la richiesta su un anno intero.
    const TETTO = 300;
    const da = String(arg.da ?? arg.data ?? '');
    const a = String(arg.a ?? arg.da ?? arg.data ?? '');
    const { data, error } = await db
      .from('bookings')
      .select('id, date, time_start, party_size, status, source, notes, internal_notes, '
        + 'guests(first_name, surname, name, phone), tables(name, areas(name))')
      .eq('restaurant_id', ID_RISTORANTE)
      .gte('date', da)
      .lte('date', a)
      .order('date')
      .order('time_start')
      .limit(TETTO + 1);
    if (error) return { errore: `lettura fallita: ${error.message}` };
    const righe = data ?? [];
    const troncato = righe.length > TETTO;
    return {
      da, a,
      totale: troncato ? `più di ${TETTO}` : righe.length,
      troncato: troncato
        ? `Mostrate solo le prime ${TETTO}: restringi il periodo per vederle tutte.`
        : undefined,
      coperti: righe.slice(0, TETTO).reduce((s: number, b: Record<string, unknown>) =>
        s + Number(b.party_size ?? 0), 0),
      prenotazioni: righe.slice(0, TETTO).map((b: Record<string, unknown>) => {
        const g = b.guests as Record<string, unknown> | null;
        return {
          // Serve a proponi_operazione: senza id non si può indicare
          // *quale* prenotazione accettare o annullare.
          id: b.id,
          data: b.date,
          ora: String(b.time_start ?? '').slice(0, 5),
          nome: nomeOspite(g),
          telefono: g?.phone ?? null,
          persone: b.party_size,
          stato: STATI[String(b.status)] ?? b.status,
          turno: turnoDi(b),
          area: areaDi(b),
          tavolo: (b.tables as Record<string, unknown> | null)?.name ?? 'non assegnato',
          origine: b.source === 'web' ? 'dal sito' : 'inserita a mano',
          note: b.notes ?? null,
        };
      }),
    };
  }

  if (nome === 'conteggi_periodo') {
    const { data, error } = await db
      .from('bookings')
      .select('date, party_size, status, time_start, internal_notes, tables(areas(name))')
      .eq('restaurant_id', ID_RISTORANTE)
      .gte('date', String(arg.da ?? ''))
      .lte('date', String(arg.a ?? ''));
    if (error) return { errore: `lettura fallita: ${error.message}` };
    const righe = data ?? [];
    const conta = (chiave: (b: Record<string, unknown>) => string) => {
      const m: Record<string, number> = {};
      for (const b of righe) m[chiave(b)] = (m[chiave(b)] ?? 0) + Number(b.party_size ?? 0);
      return m;
    };
    const valide = righe.filter((b: Record<string, unknown>) =>
      ['approved', 'pending', 'seated', 'completed'].includes(String(b.status)));
    // Per giorno, così una risposta sbagliata si smaschera da sola: se il
    // periodo chiesto non è quello giusto, le date lo dicono.
    const perGiorno: Record<string, number> = {};
    for (const b of valide) {
      const g = String(b.date ?? '');
      perGiorno[g] = (perGiorno[g] ?? 0) + 1;
    }
    return {
      da: arg.da, a: arg.a,
      prenotazioni: valide.length,
      prenotazioni_incluse_annullate: righe.length,
      coperti: valide.reduce((s: number, b: Record<string, unknown>) =>
        s + Number(b.party_size ?? 0), 0),
      prenotazioni_per_giorno: perGiorno,
      per_stato: righe.reduce((m: Record<string, number>, b: Record<string, unknown>) => {
        const k = STATI[String(b.status)] ?? String(b.status);
        m[k] = (m[k] ?? 0) + 1;
        return m;
      }, {}),
      coperti_per_turno: conta(turnoDi),
      coperti_per_area: conta(areaDi),
    };
  }

  // Prepara e basta. La scrittura vera la fa l'app, dopo che una persona ha
  // letto il riquadro e ha toccato Conferma: qui non si tocca nessuna riga.
  if (nome === 'proponi_operazione') {
    const tipo = String(arg.tipo ?? '');
    const id = String(arg.id ?? '').trim();
    if (!id) return { errore: 'manca l\'id della prenotazione' };

    const { data: b, error } = await db
      .from('bookings')
      .select('id, date, time_start, party_size, status, notes, internal_notes, '
        + 'table_id, guest_id, guests(id, first_name, surname, name, phone, email), '
        + 'tables(name, capacity)')
      .eq('restaurant_id', ID_RISTORANTE)
      .eq('id', id)
      .maybeSingle();
    if (error) return { errore: `lettura fallita: ${error.message}` };
    if (!b) {
      return { errore: 'prenotazione non trovata: ricontrolla l\'id con elenco_prenotazioni' };
    }

    const g = b.guests as Record<string, unknown> | null;
    const chi = nomeOspite(g);
    const haEmail = String(g?.email ?? '').includes('@');
    const base = `${chi} — ${dataEstesa(String(b.date))} alle `
      + `${String(b.time_start ?? '').slice(0, 5)}, ${b.party_size} persone`;
    const tavoloAttuale = (b.tables as Record<string, unknown> | null)?.name;

    const proposta: Record<string, unknown> = { tipo, id: b.id, prenotazione: b };

    if (tipo === 'accetta') {
      if (b.status === 'approved') {
        return { errore: `La prenotazione di ${chi} è già accettata: non serve fare nulla.` };
      }
      proposta.titolo = 'Accettare la prenotazione';
      proposta.descrizione = base;
      proposta.avviso = haEmail
        ? 'Al cliente parte la mail di conferma.'
        : 'Il cliente non ha email: non riceverà nessun avviso.';
    } else if (tipo === 'tavolo') {
      const cercato = String(arg.tavolo ?? '').trim();
      if (!cercato) return { errore: 'manca il nome del tavolo' };
      const { data: tavoli } = await db
        .from('tables').select('id, name, capacity').eq('restaurant_id', ID_RISTORANTE);
      const elenco = tavoli ?? [];
      const uguale = (x: Record<string, unknown>) =>
        String(x.name).toLowerCase() === cercato.toLowerCase();
      const contiene = (x: Record<string, unknown>) =>
        String(x.name).toLowerCase().includes(cercato.toLowerCase());
      const t = elenco.find(uguale) ?? elenco.find(contiene);
      if (!t) {
        return {
          errore: `nessun tavolo si chiama "${cercato}". Quelli esistenti sono: `
            + elenco.map((x: Record<string, unknown>) => x.name).join(', '),
        };
      }
      proposta.titolo = tavoloAttuale ? 'Spostare di tavolo' : 'Assegnare il tavolo';
      proposta.valori = { table_id: t.id, tavolo: t.name };
      proposta.descrizione = tavoloAttuale
        ? `${base} → dal tavolo ${tavoloAttuale} al tavolo ${t.name}`
        : `${base} → tavolo ${t.name}`;
      proposta.avviso = Number(t.capacity ?? 0) > 0
          && Number(t.capacity) < Number(b.party_size ?? 0)
        ? `Attenzione: il tavolo ${t.name} ha ${t.capacity} posti e loro sono ${b.party_size}.`
        : 'Operazione interna: al cliente non arriva nessuna mail.';
    } else if (tipo === 'annulla') {
      if (b.status === 'canceled' || b.status === 'rejected') {
        return { errore: `La prenotazione di ${chi} è già annullata.` };
      }
      proposta.titolo = 'Annullare la prenotazione';
      proposta.descrizione = base;
      proposta.valori = { motivo: String(arg.motivo ?? 'Al completo') };
      proposta.avviso = haEmail
        ? 'Confermando si apre la schermata di rifiuto: potrai rileggere e '
          + 'cambiare il messaggio prima che parta.'
        : 'Il cliente non ha email: non riceverà nessun avviso.';
    } else if (tipo === 'modifica') {
      const valori: Record<string, unknown> = {};
      const cambi: string[] = [];
      if (arg.persone != null && Number(arg.persone) > 0) {
        valori.party_size = Number(arg.persone);
        cambi.push(`persone: ${b.party_size} → ${valori.party_size}`);
      }
      if (arg.ora != null && String(arg.ora).trim() !== '') {
        const ora = String(arg.ora).slice(0, 5);
        valori.time_start = `${ora}:00`;
        cambi.push(`ora: ${String(b.time_start ?? '').slice(0, 5)} → ${ora}`);
      }
      if (arg.note != null) {
        valori.notes = String(arg.note);
        cambi.push('note aggiornate');
      }
      if (cambi.length === 0) return { errore: 'non è stato indicato cosa cambiare' };
      proposta.titolo = 'Modificare la prenotazione';
      proposta.valori = valori;
      proposta.descrizione = `${base}\n${cambi.join(' · ')}`;
      proposta.avviso = 'Al cliente non arriva nessuna mail.';
    } else {
      return { errore: 'tipo di operazione sconosciuto' };
    }

    proposte.push(proposta);
    // Al modello non serve la riga intera: solo sapere che è in attesa.
    return {
      preparata: true,
      titolo: proposta.titolo,
      descrizione: proposta.descrizione,
      avviso: proposta.avviso,
      nota: 'Il riquadro di conferma è già davanti al personale. Di\' che resti '
        + 'in attesa della conferma. Non dire che l\'operazione è fatta.',
    };
  }

  if (nome === 'cerca_cliente') {
    const pulito = String(arg.testo ?? '').replace(/[,()%_*."\\]/g, ' ').trim();
    if (!pulito) return { clienti: [] };
    const like = `%${pulito}%`;
    const { data: clienti } = await db
      .from('guests')
      .select('id, name, first_name, surname, phone, email, visits_count, tags')
      .eq('restaurant_id', ID_RISTORANTE)
      .or(`name.ilike.${like},first_name.ilike.${like},surname.ilike.${like},`
        + `phone.ilike.${like},email.ilike.${like}`)
      .limit(10);
    const id = (clienti ?? []).map((c: Record<string, unknown>) => c.id);
    const { data: pren } = id.length
      ? await db
        .from('bookings')
        .select('guest_id, date, time_start, party_size, status')
        .in('guest_id', id)
        .order('date', { ascending: false })
        .limit(40)
      : { data: [] };
    return {
      clienti: (clienti ?? []).map((c: Record<string, unknown>) => ({
        nome: nomeOspite(c),
        telefono: c.phone, email: c.email,
        visite: c.visits_count, etichette: c.tags,
        prenotazioni: (pren ?? [])
          .filter((b: Record<string, unknown>) => b.guest_id === c.id)
          .map((b: Record<string, unknown>) => ({
            data: b.date,
            ora: String(b.time_start ?? '').slice(0, 5),
            persone: b.party_size,
            stato: STATI[String(b.status)] ?? b.status,
          })),
      })),
    };
  }

  if (nome === 'orari_apertura') {
    const giorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
    const [{ data: orari }, { data: ristorante }] = await Promise.all([
      db.from('opening_hours')
        .select('day_of_week, special_date, is_closed, open_time, close_time, '
          + 'min_party_size, max_party_size, title')
        .eq('restaurant_id', ID_RISTORANTE),
      db.from('restaurants').select('settings').eq('id', ID_RISTORANTE).single(),
    ]);
    return {
      settimana: (orari ?? [])
        .filter((h: Record<string, unknown>) => !h.special_date)
        .map((h: Record<string, unknown>) => ({
          giorno: giorni[Number(h.day_of_week)],
          chiuso: h.is_closed === true,
          dalle: String(h.open_time ?? '').slice(0, 5),
          alle: String(h.close_time ?? '').slice(0, 5),
          coperti_min: h.min_party_size, coperti_max: h.max_party_size,
        })),
      date_speciali: (orari ?? [])
        .filter((h: Record<string, unknown>) => h.special_date)
        .map((h: Record<string, unknown>) => ({
          data: String(h.special_date).slice(0, 10),
          chiuso: h.is_closed === true,
          motivo: h.title ?? null,
        })),
      prenotazioni_online_dal:
        (ristorante?.settings as Record<string, unknown> | null)?.prenotazioni_dal ?? null,
      turni_disponibili: ['18:30', '20:00', '22:00'],
    };
  }

  if (nome === 'tavoli_e_aree') {
    const { data } = await db
      .from('tables')
      .select('name, capacity, is_active, areas(name)')
      .eq('restaurant_id', ID_RISTORANTE)
      .order('name');
    return {
      tavoli: (data ?? []).map((t: Record<string, unknown>) => ({
        nome: t.name,
        posti: t.capacity,
        area: (t.areas as Record<string, unknown> | null)?.name ?? 'senza area',
        attivo: t.is_active !== false,
      })),
      posti_totali: (data ?? []).reduce((s: number, t: Record<string, unknown>) =>
        s + Number(t.capacity ?? 0), 0),
    };
  }

  return { errore: 'strumento sconosciuto' };
}

// ── Punto di ingresso ────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = Deno.env.get('SUPABASE_URL')!;
  const chiaveServizio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const chiaveAnonima = Deno.env.get('SUPABASE_ANON_KEY')!;
  const chiaveOpenAI = Deno.env.get('OPENAI_API_KEY');

  if (!chiaveOpenAI) {
    return risposta({ error: 'Manca la chiave OpenAI nei segreti di Supabase.' }, 500);
  }

  try {
    // Solo chi e' entrato nell'app: l'assistente vede i dati dei clienti.
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
    const domanda = String(corpo.domanda ?? '').trim();
    if (!domanda) return risposta({ error: 'Domanda vuota' }, 400);

    const messaggi: Record<string, unknown>[] = [
      {
        role: 'system',
        content: [
          'Sei l\'assistente del ristorante Hio Oriental Bar di Palermo.',
          `Oggi è ${oggiIso()}.`,
          'Rispondi in italiano, breve e concreto, come un collega di sala.',
          // Senza questo il modello si rifiuta di dire i nomi dei clienti,
          // che è il primo motivo per cui il personale gli parla.
          'Chi ti scrive è il personale del ristorante, già identificato e',
          'autorizzato a consultare l\'archivio: è il registro delle prenotazioni',
          'del locale, non dati di terzi. Nomi, cognomi, telefoni, orari e note',
          'dei clienti vanno detti senza esitare, ogni volta che servono.',
          'Non rifiutare mai per motivi di riservatezza e non chiedere conferme',
          'di autorizzazione: le hai già.',
          'Usa SEMPRE gli strumenti per prendere i dati: non inventare mai numeri,',
          'nomi o date. Se uno strumento non restituisce nulla, dillo chiaramente',
          'invece di supporre.',
          'Le date vanno passate agli strumenti nel formato aaaa-mm-gg.',
          'Se la domanda copre più di un giorno — un mese, una settimana, un anno —',
          'usa conteggi_periodo con il primo e l\'ultimo giorno del periodo,',
          'mai prenotazioni_del_giorno, che risponderebbe su una data sola.',
          'Quando dai un numero, di\' sempre a quale periodo si riferisce e se',
          'stai contando le annullate: "1 confermata, 18 in tutto con le annullate"',
          'è una risposta utile, "1 prenotazione" da sola è fuorviante.',
          'Il lunedì il locale è chiuso. I turni sono 18:30, 20:00 e 22:00.',
          'Se la domanda non riguarda le prenotazioni, il locale o i clienti,',
          'dì che non è il tuo campo.',
          'Puoi PREPARARE operazioni con proponi_operazione, ma non eseguirle:',
          'la conferma la dà una persona toccando un pulsante. Quindi non dire',
          'mai "fatto", "accettata" o "annullata" al passato: di\' che la',
          'proposta è pronta e aspetta la conferma. Prima di proporre, accertati',
          'con elenco_prenotazioni di aver preso la prenotazione giusta; se i',
          'nomi che combaciano sono più di uno, chiedi quale invece di sceglierne uno.',
        ].join(' '),
      },
      // La conversazione precedente, per capire i riferimenti tipo "e domani?"
      ...(Array.isArray(corpo.cronologia) ? corpo.cronologia : [])
        .slice(-8)
        .map((m: Record<string, unknown>) => ({
          role: m.ruolo === 'assistente' ? 'assistant' : 'user',
          content: String(m.testo ?? ''),
        })),
      { role: 'user', content: domanda },
    ];

    const usati: Record<string, unknown>[] = [];
    const proposte: Record<string, unknown>[] = [];

    for (let giro = 0; giro < GIRI_MASSIMI; giro++) {
      const res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${chiaveOpenAI}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: MODELLO,
          messages: messaggi,
          tools: STRUMENTI,
          temperature: 0.2,
        }),
      });

      if (!res.ok) {
        const testo = await res.text();
        // Il nome del modello fra virgolette: così si vedono anche gli spazi.
        return risposta({
          error: `OpenAI ha rifiutato la richiesta (${res.status}) usando il `
            + `modello "${MODELLO}". Risposta: ${testo.slice(0, 300)}`,
          modello: MODELLO,
        }, 502);
      }

      const dati = await res.json();
      const scelta = dati.choices?.[0]?.message;
      if (!scelta) return risposta({ error: 'Risposta di OpenAI illeggibile' }, 502);

      const chiamate = scelta.tool_calls ?? [];
      if (chiamate.length === 0) {
        return risposta({
          risposta: scelta.content ?? '',
          strumenti: usati,
          proposte,
          // Dichiarato nella risposta perché il pannello dei segreti mostra
          // solo un'impronta: è l'unico modo di sapere quale modello risponde.
          modello: MODELLO,
        });
      }

      messaggi.push(scelta);
      for (const c of chiamate) {
        let argomenti: Record<string, unknown> = {};
        try {
          argomenti = JSON.parse(c.function?.arguments ?? '{}');
        } catch (_) { /* argomenti malformati: si esegue senza */ }
        // Con gli argomenti, non solo il nome: se sbaglia periodo si vede.
        usati.push({ nome: c.function?.name, argomenti });
        const esito = await esegui(db, c.function?.name, argomenti, proposte);
        messaggi.push({
          role: 'tool',
          tool_call_id: c.id,
          content: JSON.stringify(esito),
        });
      }
    }

    return risposta({
      error: 'Non sono riuscito a rispondere: troppi passaggi.',
    }, 500);
  } catch (e) {
    return risposta({ error: String(e) }, 500);
  }
});
