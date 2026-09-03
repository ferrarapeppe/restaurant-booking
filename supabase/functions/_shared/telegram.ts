// Avvisi allo staff su Telegram.
//
// Verso i clienti resta l'email: un bot non puo' scrivere per primo a
// qualcuno, quindi Telegram non sostituisce niente di quello che il cliente
// riceve. Qui serve al personale, che il bot lo apre una volta e basta.
//
// I destinatari stanno in `restaurants.settings.telegram.chats` e possono
// essere persone o gruppi: per Telegram sono la stessa cosa, un numero di
// chat. Il gettone del bot sta fra i segreti della funzione, mai nel
// database: chiunque ce l'ha puo' scrivere a nome del ristorante.

export type Evento = 'prenotazione' | 'annullamento' | 'messaggio' | 'riepilogo';

export interface Chat {
  id: string;
  nome?: string;
}

export interface ImpostazioniTelegram {
  chats: Chat[];
  eventi: Record<string, unknown>;
}

/// Le impostazioni salvate, con i valori di ripiego.
export async function impostazioni(
  // deno-lint-ignore no-explicit-any
  db: any,
  idRistorante: string,
): Promise<ImpostazioniTelegram> {
  const { data } = await db
    .from('restaurants')
    .select('settings')
    .eq('id', idRistorante)
    .single();
  const grezze = (data?.settings ?? {}).telegram ?? {};
  return {
    chats: Array.isArray(grezze.chats) ? grezze.chats : [],
    // Se non e' stato scelto niente si avvisa: chi accende Telegram lo fa per
    // essere avvisato, non per configurare un elenco di eccezioni.
    eventi: typeof grezze.eventi === 'object' && grezze.eventi !== null
      ? grezze.eventi
      : {},
  };
}

/// Manda un messaggio a una chat sola. Restituisce l'errore invece di
/// sollevarlo: un avviso non partito non deve far fallire una prenotazione.
export async function inviaA(
  chatId: string,
  testo: string,
): Promise<string | null> {
  const gettone = Deno.env.get('TELEGRAM_BOT_TOKEN');
  if (!gettone) return 'TELEGRAM_BOT_TOKEN non impostato';
  try {
    const risposta = await fetch(
      `https://api.telegram.org/bot${gettone}/sendMessage`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: testo,
          parse_mode: 'HTML',
          // L'anteprima di un link occupa mezzo schermo e non serve.
          disable_web_page_preview: true,
        }),
      },
    );
    const esito = await risposta.json().catch(() => ({}));
    if (!esito.ok) return String(esito.description ?? `HTTP ${risposta.status}`);
    return null;
  } catch (e) {
    return String(e);
  }
}

/// Manda l'avviso a tutti i destinatari attivi per quel tipo di evento.
export async function avvisa(
  // deno-lint-ignore no-explicit-any
  db: any,
  idRistorante: string,
  evento: Evento,
  testo: string,
): Promise<void> {
  try {
    const cfg = await impostazioni(db, idRistorante);
    if (cfg.eventi[evento] === false) return;
    for (const chat of cfg.chats) {
      const errore = await inviaA(String(chat.id), testo);
      if (errore) console.warn(`telegram ${chat.id}: ${errore}`);
    }
  } catch (e) {
    console.warn('avviso telegram non partito:', e);
  }
}

/// Telegram interpreta &, < e > come marcatori: un cognome con la e
/// commerciale farebbe fallire l'invio con "can't parse entities".
export function pulisci(testo: unknown): string {
  return String(testo ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

/// "2026-09-03" -> "giovedì 3 settembre".
export function dataEstesa(iso: string): string {
  const [a, m, g] = String(iso).split('-').map(Number);
  if (!a || !m || !g) return String(iso);
  const giorni = ['domenica', 'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato'];
  const mesi = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
  const d = new Date(a, m - 1, g);
  return `${giorni[d.getDay()]} ${g} ${mesi[m - 1]}`;
}
