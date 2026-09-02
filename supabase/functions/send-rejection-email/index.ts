import nodemailer from 'npm:nodemailer@6.9.9';

// ─── Invio con ritentativi ───────────────────────────────────────────────────
// Aruba applica greylisting: rifiuta temporaneamente la posta da IP che non
// conosce, aspettandosi un secondo tentativo dallo stesso indirizzo. Ma le
// edge function di Supabase escono da IP che cambiano a ogni chiamata, quindi
// l'invio riusciva solo quando capitava su un IP gia' autorizzato.
// Ritentare aumenta le probabilita' di finire su uno di quelli.
async function inviaConRitenta(
  transporter: { sendMail: (m: unknown) => Promise<unknown> },
  messaggio: unknown,
  tentativi = 4,
): Promise<unknown> {
  let ultimoErrore: unknown;
  for (let i = 0; i < tentativi; i++) {
    try {
      return await transporter.sendMail(messaggio);
    } catch (e) {
      ultimoErrore = e;
      const testo = String(e);
      const temporaneo = /temporarily rejected|temporaneamente rifiutata|Greylist|greylist|\b4\.\d\.\d\b|450|451|550 5\.1\.0/.test(testo);
      if (!temporaneo || i === tentativi - 1) throw e;
      console.warn(`invio rifiutato temporaneamente (tentativo ${i + 1}/${tentativi}): ${testo}`);
      await new Promise((r) => setTimeout(r, 1200 * (i + 1)));
    }
  }
  throw ultimoErrore;
}

// ─── Scelta del canale di invio ──────────────────────────────────────────────
// Se RESEND_API_KEY e' configurata si usa Resend, altrimenti si resta sull'SMTP
// di Aruba. Il passaggio si attiva e si annulla aggiungendo o togliendo il
// segreto, senza rideployare.
async function inviaEmail(
  transporter: { sendMail: (m: unknown) => Promise<unknown> },
  messaggio: { from: string; to: string; subject: string; html: string },
): Promise<unknown> {
  const chiaveResend = Deno.env.get('RESEND_API_KEY');
  if (chiaveResend) return await inviaConResend(chiaveResend, messaggio);
  return await inviaConRitenta(transporter, messaggio);
}

async function inviaConResend(
  chiave: string,
  messaggio: { from: string; to: string; subject: string; html: string },
): Promise<unknown> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${chiave}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: messaggio.from,
      to: [messaggio.to],
      subject: messaggio.subject,
      html: messaggio.html,
    }),
  });
  const corpo = await res.text();
  if (!res.ok) throw new Error(`Resend ${res.status}: ${corpo}`);
  return corpo;
}


const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ─── Identita' visiva, allineata al sito e alle altre due email ──────────────
// Georgia perche' nelle email i font web non si caricano (Gmail e Outlook
// rimuovono <link>): e' la famiglia di sistema piu' vicina al Playfair Display.
const C = {
  nero:        '#160E0A',
  neroSoft:    '#18130F',
  rosso:       '#B9172A',
  rossoChiaro: '#FBEAE9',
  oro:         '#CAB16F',
  testo:       '#18130F',
  testoSoft:   '#655D54',
  bordo:       '#D9CCB7',
  sfondo:      '#F5F0E7',
};
const FONT_TITOLO = `Georgia,'Times New Roman',serif`;
const FONT_TESTO = `Helvetica,Arial,sans-serif`;
const LOGO_URL = 'https://prenota.hiooriental.com/logo.png';

const DAYS = ['Domenica','Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato'];
const MONTHS = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const {
      email, nome, cognome, motivo, messaggio, tipo,
      date, time, persons,
      restaurantName, restaurantAddress, restaurantCity, restaurantPhone, restaurantEmail,
    } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: 'Email mancante' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Due lettere diverse dalla stessa funzione. Rifiutare una richiesta e
    // cancellare una prenotazione gia' confermata non sono la stessa cosa: la
    // seconda e' una parola data e poi ritirata, e il testo deve dirlo.
    const cancellazione = tipo === 'cancellazione';

    const smtpUser = Deno.env.get('SMTP_USER') ?? '';
    const transporter = nodemailer.createTransport({
      host: Deno.env.get('SMTP_HOST') ?? 'smtps.aruba.it',
      port: parseInt(Deno.env.get('SMTP_PORT') ?? '465'),
      secure: true,
      auth: { user: smtpUser, pass: Deno.env.get('SMTP_PASS') ?? '' },
    });

    const restName = restaurantName || 'Hio Oriental Bar';
    const restAddress = restaurantAddress || '';
    const restCity = restaurantCity || '';
    const restPhone = restaurantPhone || '';
    const restContactEmail = restaurantEmail || '';

    const guestName = [nome, cognome].filter(Boolean).join(' ').trim();
    const timeShort = (time || '').toString().substring(0, 5);

    // Quale prenotazione: senza, il cliente con piu' richieste non sa quale sia
    let quandoEsteso = '';
    let quandoBreve = '';
    if (date) {
      const d = new Date(`${date}T12:00:00`);
      if (!isNaN(d.getTime())) {
        quandoEsteso = `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
          + (timeShort ? ` alle ${timeShort}` : '');
        quandoBreve = `${d.getDate()}/${String(d.getMonth() + 1).padStart(2, '0')}`
          + (timeShort ? ` ${timeShort}` : '');
      }
    }

    const mapsUrl = `https://maps.google.com/?q=${encodeURIComponent(restAddress + ', ' + restCity)}`;
    const siteUrl = 'https://prenota.hiooriental.com/booking.html';
  const indirizzoPiede = [restAddress, restCity].filter(Boolean).join('<br>');
  const contattiPiede = [
    restPhone ? `<a href="tel:${restPhone.replace(/\s/g, '')}" style="color:${C.oro};text-decoration:none;">${restPhone}</a>` : '',
    restContactEmail ? `<a href="mailto:${restContactEmail}" style="color:${C.oro};text-decoration:none;">${restContactEmail}</a>` : '',
    `<a href="${siteUrl}" style="color:${C.oro};text-decoration:none;">Prenota un tavolo</a>`,
  ].filter(Boolean).join('<br>');

    const html = `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <!-- iOS e Gmail trasformano da soli indirizzi, telefoni e mail in link blu sottolineati -->
  <meta name="format-detection" content="telephone=no,date=no,address=no,email=no,url=no">
  <style>
    a[x-apple-data-detectors] {
      color: inherit !important;
      text-decoration: none !important;
      font-size: inherit !important;
      font-family: inherit !important;
      font-weight: inherit !important;
      line-height: inherit !important;
    }
  </style>
</head>
<body style="margin:0;padding:0;background:${C.sfondo};font-family:${FONT_TESTO};">
<table width="100%" cellpadding="0" cellspacing="0" style="background:${C.sfondo};padding:24px 12px;">
<tr><td>
<table width="100%" align="center" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;margin:0 auto;border-collapse:separate;">

  <!-- Intestazione -->
  <tr>
    <td style="background:${C.nero};padding:34px 24px 26px;text-align:center;border-radius:12px 12px 0 0;">
      <img src="${LOGO_URL}" width="240" alt="${restName}"
        style="display:block;width:240px;max-width:75%;height:auto;margin:0 auto;border:0;color:${C.oro};font-family:${FONT_TITOLO};font-size:22px;font-weight:bold;letter-spacing:2px;">
      ${[restAddress, restCity].filter(Boolean).join(', ') ? `<p style="color:#A79E90;font-family:${FONT_TESTO};font-size:13px;letter-spacing:0.5px;margin:14px 0 0;">${[restAddress, restCity].filter(Boolean).join(', ')}</p>` : ''}
    </td>
  </tr>

  <!-- Corpo -->
  <tr>
    <td style="background:white;padding:34px 32px 26px;">
      <h2 style="color:${C.neroSoft};font-family:${FONT_TITOLO};font-size:21px;font-weight:bold;line-height:1.35;margin:0 0 16px;">
        ${cancellazione ? 'Dobbiamo annullare la tua prenotazione.' : 'Non possiamo confermare la tua prenotazione.'}
      </h2>

      <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:15px;line-height:1.7;margin:0 0 18px;">
        ${cancellazione
          ? `${guestName ? `Gentile ${guestName}, ci dispiace` : 'Ci dispiace'} doverti comunicare che la tua prenotazione${quandoEsteso ? ` per <strong>${quandoEsteso}</strong>` : ''}${persons ? ` per ${persons} ${Number(persons) === 1 ? 'persona' : 'persone'}` : ''}, che avevamo confermato, non potrà essere mantenuta.`
          : `${guestName ? `Gentile ${guestName}, purtroppo` : 'Purtroppo'} non ci è possibile accogliere la tua richiesta${quandoEsteso ? ` per <strong>${quandoEsteso}</strong>` : ''}${persons ? ` per ${persons} ${Number(persons) === 1 ? 'persona' : 'persone'}` : ''}.`}
      </p>

      ${messaggio ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
        <tr>
          <td style="background:${C.rossoChiaro};border-left:3px solid ${C.rosso};padding:14px 16px;border-radius:0 8px 8px 0;">
            <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:14px;line-height:1.65;margin:0;">${messaggio}</p>
          </td>
        </tr>
      </table>` : ''}

      <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:15px;line-height:1.7;margin:0 0 26px;">
        ${cancellazione ? 'Ci scusiamo per il disagio.' : 'Ci dispiace davvero.'} Se vuoi provare con un'altra data o un altro orario, siamo a disposizione:
        scrivici a <a href="mailto:${restContactEmail}" style="color:${C.rosso};font-weight:bold;text-decoration:none;">${restContactEmail}</a>
        oppure chiamaci al <a href="tel:${restPhone.replace(/\s/g, '')}" style="color:${C.rosso};font-weight:bold;text-decoration:none;">${restPhone}</a>.
      </p>

      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0;">
        <tr>
          <td align="center">
            <a href="${siteUrl}" style="background:${C.rosso};color:#ffffff;text-decoration:none;padding:15px 34px;border-radius:8px;font-family:${FONT_TESTO};font-size:15px;font-weight:bold;display:inline-block;">
              ${cancellazione ? 'Prenota un altro giorno' : "Prova un'altra data"}
            </a>
          </td>
        </tr>
      </table>
    </td>
  </tr>

  <!-- Saluto -->
  <tr>
    <td style="background:white;padding:0 32px 30px;">
      <div style="border-top:1px solid ${C.bordo};padding-top:22px;">
        <p style="color:${C.testoSoft};font-family:${FONT_TESTO};font-size:14px;margin:0 0 2px;">A presto,</p>
        <p style="color:${C.testo};font-family:${FONT_TITOLO};font-size:15px;font-weight:bold;letter-spacing:1px;margin:0;">${restName}</p>
      </div>
    </td>
  </tr>

  <!-- Piè di pagina -->
  <tr>
    <td style="background:${C.nero};padding:24px 24px 28px;text-align:center;border-radius:0 0 12px 12px;">
      <p style="color:${C.oro};font-family:${FONT_TITOLO};font-size:14px;font-weight:bold;letter-spacing:3px;margin:0 0 12px;">${restName.toUpperCase()}</p>
      ${indirizzoPiede ? `<p style="margin:0 0 14px;">
        <a href="${mapsUrl}" style="color:#A79E90;text-decoration:none;font-family:${FONT_TESTO};font-size:12px;line-height:1.7;">${indirizzoPiede}</a>
      </p>` : ''}
      <p style="margin:0;font-family:${FONT_TESTO};font-size:12px;line-height:2;">${contattiPiede}</p>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;

    const subject = `${cancellazione ? 'Prenotazione annullata' : 'Prenotazione non confermata'}${guestName ? ` per ${guestName}` : ''}`
      + (quandoBreve ? ` (${quandoBreve})` : '');

    await inviaEmail(transporter, {
      from: `${restName} <${smtpUser}>`,
      to: email,
      subject,
      html,
    });

    return new Response(JSON.stringify({ success: true, canale: Deno.env.get('RESEND_API_KEY') ? 'resend' : 'smtp', motivo: motivo ?? null }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-rejection-email error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
