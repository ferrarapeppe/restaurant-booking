// Scelta dei tavoli per una prenotazione.
//
// Sta qui e non dentro una singola funzione perche' lo usano in due: il
// modulo pubblico, che assegna da solo quando entra una prenotazione, e
// l'app, che lo chiama per proporre allo staff. Scriverlo due volte
// significherebbe vederli divergere, e un giorno il sito assegnerebbe
// diversamente dalla sala.
//
// Non e' un'assegnazione definitiva ma una proposta: il proprietario la
// rivede. Per questo l'algoritmo puo' permettersi di essere semplice e
// prevedibile, invece che astuto.

export type Tavolo = {
  id: string;
  name: string;
  capacity: number;
};

export type Combinazione = {
  tavoli: Tavolo[];
  posti: number;
  /// Posti in piu' rispetto agli ospiti. Zero e' l'incastro perfetto.
  spreco: number;
  /// Quante coppie di numeri consecutivi: 12+13 vale 1, 12+17 vale 0.
  vicini: number;
};

/// Il numero del tavolo, per capire se due sono in fila.
///
/// I tavoli si possono spostare fisicamente per accostarli, quindi la
/// vicinanza non e' un vincolo ma una preferenza: serve solo a far
/// trascinare meno sedie.
function numeroDi(t: Tavolo): number {
  const n = parseInt(String(t.name).replace(/\D/g, ''), 10);
  return Number.isFinite(n) ? n : 9999;
}

function quantiVicini(tavoli: Tavolo[]): number {
  const numeri = tavoli.map(numeroDi).sort((a, b) => a - b);
  let n = 0;
  for (let i = 1; i < numeri.length; i++) {
    if (numeri[i] - numeri[i - 1] === 1) n++;
  }
  return n;
}

/// Ordina le combinazioni dalla migliore alla peggiore.
///
/// 1. meno posti sprecati — 3+2 per cinque persone batte un tavolo da 6;
/// 2. a parita', meno tavoli — meno gente da spostare;
/// 3. a parita', numeri consecutivi — meno sedie da trascinare;
/// 4. a parita', i numeri piu' bassi, solo per avere un esito stabile.
function confronta(a: Combinazione, b: Combinazione): number {
  if (a.spreco !== b.spreco) return a.spreco - b.spreco;
  if (a.tavoli.length !== b.tavoli.length) return a.tavoli.length - b.tavoli.length;
  if (a.vicini !== b.vicini) return b.vicini - a.vicini;
  const sa = a.tavoli.reduce((s, t) => s + numeroDi(t), 0);
  const sb = b.tavoli.reduce((s, t) => s + numeroDi(t), 0);
  return sa - sb;
}

/// Tutte le combinazioni possibili, ordinate.
///
/// Con al massimo una ventina di tavoli per sala le combinazioni sono
/// centomila nel caso peggiore: si enumerano tutte e si sceglie davvero la
/// migliore, invece di accontentarsi della prima che basta. Oltre quella
/// soglia si passa a un metodo spiccio, per non bloccare la richiesta.
export function combinazioni(
  liberi: Tavolo[],
  persone: number,
  massimoTavoli = 0,
): Combinazione[] {
  if (persone <= 0 || liberi.length === 0) return [];

  const tetto = massimoTavoli > 0 ? massimoTavoli : liberi.length;

  if (liberi.length > 20) return [spiccia(liberi, persone, tetto)].filter(Boolean) as Combinazione[];

  const trovate: Combinazione[] = [];
  const totali = 1 << liberi.length;
  for (let maschera = 1; maschera < totali; maschera++) {
    const scelti: Tavolo[] = [];
    let posti = 0;
    for (let i = 0; i < liberi.length; i++) {
      if (maschera & (1 << i)) {
        scelti.push(liberi[i]);
        posti += liberi[i].capacity;
      }
    }
    if (scelti.length > tetto) continue;
    if (posti < persone) continue;
    // Un tavolo di troppo e' sempre peggio: se togliendone uno basta
    // ancora, quella combinazione verra' trovata per conto suo.
    trovate.push({
      tavoli: scelti,
      posti,
      spreco: posti - persone,
      vicini: quantiVicini(scelti),
    });
  }
  trovate.sort(confronta);
  return trovate;
}

/// Metodo spiccio per sale molto grandi: prende i tavoli piu' piccoli finche'
/// non bastano. Non e' la combinazione ottima, ma e' immediata.
function spiccia(liberi: Tavolo[], persone: number, tetto: number): Combinazione | null {
  const ordinati = [...liberi].sort((a, b) => a.capacity - b.capacity);
  const scelti: Tavolo[] = [];
  let posti = 0;
  for (const t of ordinati) {
    if (posti >= persone || scelti.length >= tetto) break;
    scelti.push(t);
    posti += t.capacity;
  }
  if (posti < persone) return null;
  return {
    tavoli: scelti,
    posti,
    spreco: posti - persone,
    vicini: quantiVicini(scelti),
  };
}

/// I tavoli gia' impegnati in quella fascia oraria.
///
/// Guarda `booking_tables` e non piu' `bookings.table_id`: una prenotazione
/// puo' tenere piu' tavoli, e cercarli nella vecchia colonna ne vedrebbe
/// uno solo — cioe' darebbe per libero un tavolo occupato.
// deno-lint-ignore no-explicit-any
export async function tavoliOccupati(
  db: any,
  data: string,
  inizio: string,
  fine: string,
  escludiPrenotazione?: string,
): Promise<Set<string>> {
  let q = db
    .from('booking_tables')
    .select('table_id, bookings!inner(id, date, time_start, time_end, status)')
    .eq('bookings.date', data)
    .lt('bookings.time_start', fine)
    .gt('bookings.time_end', inizio)
    .not('bookings.status', 'in', '(canceled,canceled_by_venue,no_show,rejected)');
  if (escludiPrenotazione) q = q.neq('bookings.id', escludiPrenotazione);
  const { data: righe, error } = await q;
  if (error) throw new Error(`occupazione non leggibile: ${error.message}`);
  return new Set<string>((righe ?? []).map((r: Record<string, unknown>) => String(r.table_id)));
}

/// La proposta per una prenotazione: i tavoli liberi della sala, combinati.
// deno-lint-ignore no-explicit-any
export async function proponiTavoli(
  db: any,
  opzioni: {
    idRistorante: string;
    areaId: string;
    persone: number;
    data: string;
    inizio: string;
    fine: string;
    escludiPrenotazione?: string;
  },
): Promise<Combinazione | null> {
  const { data: tutti, error } = await db
    .from('tables')
    .select('id, name, capacity, is_active')
    .eq('restaurant_id', opzioni.idRistorante)
    .eq('area_id', opzioni.areaId);
  if (error) throw new Error(`tavoli non leggibili: ${error.message}`);

  const occupati = await tavoliOccupati(
    db, opzioni.data, opzioni.inizio, opzioni.fine, opzioni.escludiPrenotazione,
  );

  const liberi: Tavolo[] = (tutti ?? [])
    .filter((t: Record<string, unknown>) =>
      t.is_active !== false && !occupati.has(String(t.id)))
    .map((t: Record<string, unknown>) => ({
      id: String(t.id),
      name: String(t.name ?? ''),
      capacity: Number(t.capacity ?? 0),
    }))
    .filter((t: Tavolo) => t.capacity > 0);

  const tutte = combinazioni(liberi, opzioni.persone);
  return tutte.length > 0 ? tutte[0] : null;
}

/// Scrive l'assegnazione: sostituisce quella che c'era.
///
/// `bookings.table_id` resta allineato al primo tavolo perche' mezza app lo
/// legge ancora; la verita' completa sta in `booking_tables`.
// deno-lint-ignore no-explicit-any
export async function assegna(
  db: any,
  idPrenotazione: string,
  tavoli: Tavolo[],
): Promise<void> {
  await db.from('booking_tables').delete().eq('booking_id', idPrenotazione);
  if (tavoli.length === 0) {
    await db.from('bookings').update({ table_id: null }).eq('id', idPrenotazione);
    return;
  }
  const { error } = await db.from('booking_tables').insert(
    tavoli.map((t) => ({ booking_id: idPrenotazione, table_id: t.id })),
  );
  if (error) throw new Error(`assegnazione non riuscita: ${error.message}`);
  const primo = [...tavoli].sort((a, b) => numeroDi(a) - numeroDi(b))[0];
  await db.from('bookings').update({ table_id: primo.id }).eq('id', idPrenotazione);
}
