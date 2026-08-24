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

// ─── Identita' visiva, allineata al sito ─────────────────────────────────────
// Nelle email i font web non si caricano (Gmail e Outlook rimuovono <link>):
// Georgia e' la famiglia di sistema piu' vicina al Playfair Display del sito.
const C = {
  nero:       '#0E0E0E',
  neroSoft:   '#1A1A1A',
  rosso:      '#B7182A',
  oro:        '#C9B06E',
  oroChiaro:  '#FBF7EE',
  testo:      '#1A1A1A',
  testoSoft:  '#5A5A5A',
  testoTenue: '#9A948C',
  bordo:      '#E4E1DC',
  sfondo:     '#F4F2EF',
};
const FONT_TITOLO = `Georgia,'Times New Roman',serif`;
const FONT_TESTO = `Helvetica,Arial,sans-serif`;
const LOGO_URL = 'https://ferrarapeppe.github.io/restaurant-booking/logo.png';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      nome, cognome, email, phone, date, time, persons, notes, turno, area,
      restaurantName, restaurantAddress, restaurantCity, restaurantPhone, restaurantEmail,
      bookingId,
    } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: 'Email cliente mancante' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const dateObj = new Date(date);
    const DAYS = ['Domenica','Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato'];
    const MONTHS = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];
    const DAYS_SHORT = ['dom','lun','mar','mer','gio','ven','sab'];
    const MONTHS_SHORT = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];

    const dateFormatted = `${DAYS[dateObj.getDay()]}, ${dateObj.getDate()} ${MONTHS[dateObj.getMonth()]} ${dateObj.getFullYear()}`;
    const dateSubject = `${DAYS_SHORT[dateObj.getDay()]} ${dateObj.getDate()} ${MONTHS_SHORT[dateObj.getMonth()]} ${dateObj.getFullYear()}`;

    const [h, m] = time.split(':').map(Number);
    const endMin = h * 60 + m + 120;
    const endTime = `${String(Math.floor(endMin / 60) % 24).padStart(2, '0')}:${String(endMin % 60).padStart(2, '0')}`;

    const restName = restaurantName || 'Hio Oriental Bar';
    const restAddress = restaurantAddress || '';
    const restCity = restaurantCity || '';
    const restPhone = restaurantPhone || '';
    const restContactEmail = restaurantEmail || '';

    const statusUrl = bookingId
      ? `https://ferrarapeppe.github.io/restaurant-booking/booking-status.html?id=${bookingId}`
      : `https://ferrarapeppe.github.io/restaurant-booking/booking.html`;

    const smtpUser = Deno.env.get('SMTP_USER') ?? '';

    const transporter = nodemailer.createTransport({
      host: Deno.env.get('SMTP_HOST') ?? 'smtps.aruba.it',
      port: parseInt(Deno.env.get('SMTP_PORT') ?? '465'),
      secure: true,
      auth: {
        user: smtpUser,
        pass: Deno.env.get('SMTP_PASS') ?? '',
      },
    });

    const data: EmailData = {
      nome, cognome, email, phone,
      dateFormatted, time, endTime, persons,
      notes: notes || '', turno: turno || '', area: area || '',
      restName, restAddress, restCity, restPhone, restContactEmail, statusUrl,
    };

    // Email 1 — Richiesta di prenotazione ricevuta (al cliente + notifica al ristorante)
    const nomeCompleto = [nome, cognome].filter(Boolean).join(' ').trim();
    const email1Subject = `Richiesta di prenotazione ricevuta${nomeCompleto ? ` da ${nomeCompleto}` : ''}`
      + ` (${persons} ${persons === 1 ? 'persona' : 'persone'}, ${dateSubject} ${time})`;
    const email1Html = buildEmail1Html(data);
    await inviaEmail(transporter, {
      from: `${restName} <${smtpUser}>`,
      to: email,
      subject: email1Subject,
      html: email1Html,
    });
    await inviaEmail(transporter, {
      from: `${restName} <${smtpUser}>`,
      to: 'prenota@hiooriental.com',
      subject: `[NUOVA PRENOTAZIONE] ${email1Subject}`,
      html: email1Html,
    });


    return new Response(JSON.stringify({ success: true, canale: Deno.env.get('RESEND_API_KEY') ? 'resend' : 'smtp' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-booking-email error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

// ─── Types ───────────────────────────────────────────────────────────────────

type EmailData = {
  nome: string; cognome: string; email: string; phone: string;
  dateFormatted: string; time: string; endTime: string; persons: number;
  notes: string; turno: string; area: string;
  restName: string; restAddress: string; restCity: string;
  restPhone: string; restContactEmail: string; statusUrl: string;
};

// ─── Shared builders ─────────────────────────────────────────────────────────

function row(label: string, value: string): string {
  if (!value) return '';
  return `<tr>
    <td style="padding:11px 0;border-bottom:1px solid ${C.bordo};color:${C.testoSoft};font-family:${FONT_TESTO};font-size:11px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;width:104px;vertical-align:top;">${label}</td>
    <td style="padding:11px 0;border-bottom:1px solid ${C.bordo};color:${C.testo};font-family:${FONT_TESTO};font-size:15px;font-weight:bold;word-break:break-word;">${value}</td>
  </tr>`;
}

const GAP = `<tr><td colspan="2" style="height:10px;"></td></tr>`;

function detailsTable(d: EmailData): string {
  return `<table width="100%" cellpadding="0" cellspacing="0" style="border-top:2px solid ${C.oro};">
    ${row('Data', d.dateFormatted)}
    ${row('Orario', `${d.time} &ndash; ${d.endTime}`)}
    ${d.area ? row('Area', d.area) : ''}
    ${row('Persone', String(d.persons))}
    ${d.turno ? row('Turno', d.turno) : ''}
    ${GAP}
    ${row('Cognome', d.cognome)}
    ${row('Nome', d.nome)}
    ${row('Telefono', d.phone ? `<a href="tel:${d.phone.replace(/\s/g, '')}" style="color:${C.testo};text-decoration:none;">${d.phone}</a>` : '')}
    ${row('E-mail', d.email ? `<a href="mailto:${d.email}" style="color:${C.testo};text-decoration:none;">${d.email}</a>` : '')}
    ${d.notes ? row('Messaggio', d.notes) : ''}
  </table>
  <p style="color:${C.rosso};font-family:${FONT_TESTO};font-size:13px;font-weight:bold;line-height:1.6;margin:12px 0 0;">
    Il tavolo sarà mantenuto a disposizione per un massimo di 20 minuti oltre l’orario della prenotazione.
    Trascorso questo termine, la prenotazione sarà considerata annullata.
  </p>`;
}

function header(restName: string, restAddress: string, restCity: string): string {
  const indirizzo = [restAddress, restCity].filter(Boolean).join(', ');
  // Se il client blocca le immagini resta il testo alternativo, gia' in oro su nero
  return `<tr>
    <td style="background:${C.nero};padding:34px 24px 26px;text-align:center;border-radius:12px 12px 0 0;">
      <img src="${LOGO_URL}" width="240" alt="${restName}"
        style="display:block;width:240px;max-width:75%;height:auto;margin:0 auto;border:0;color:${C.oro};font-family:${FONT_TITOLO};font-size:22px;font-weight:bold;letter-spacing:2px;">
      ${indirizzo ? `<p style="color:#B9B4AC;font-family:${FONT_TESTO};font-size:13px;letter-spacing:0.5px;margin:14px 0 0;">${indirizzo}</p>` : ''}
    </td>
  </tr>`;
}

function footer(d: EmailData): string {
  const mapsUrl = `https://maps.google.com/?q=${encodeURIComponent(d.restAddress + ', ' + d.restCity)}`;
  const siteUrl = `https://ferrarapeppe.github.io/restaurant-booking/booking.html`;
  const indirizzoPiede = [d.restAddress, d.restCity].filter(Boolean).join('<br>');
  const contattiPiede = [
    d.restPhone ? `<a href="tel:${d.restPhone.replace(/\s/g, '')}" style="color:${C.oro};text-decoration:none;">${d.restPhone}</a>` : '',
    d.restContactEmail ? `<a href="mailto:${d.restContactEmail}" style="color:${C.oro};text-decoration:none;">${d.restContactEmail}</a>` : '',
    `<a href="${siteUrl}" style="color:${C.oro};text-decoration:none;">Prenota un tavolo</a>`,
  ].filter(Boolean).join('<br>');
  return `<tr>
    <td style="background:white;padding:0 32px 30px;">
      <div style="border-top:1px solid ${C.bordo};padding-top:22px;">
        <p style="color:${C.testoSoft};font-family:${FONT_TESTO};font-size:14px;margin:0 0 2px;">A presto,</p>
        <p style="color:${C.testo};font-family:${FONT_TITOLO};font-size:15px;font-weight:bold;letter-spacing:1px;margin:0;">${d.restName}</p>
      </div>
    </td>
  </tr>
  <tr>
    <td style="background:${C.nero};padding:24px 24px 28px;text-align:center;border-radius:0 0 12px 12px;">
      <p style="color:${C.oro};font-family:${FONT_TITOLO};font-size:14px;font-weight:bold;letter-spacing:3px;margin:0 0 12px;">${d.restName.toUpperCase()}</p>
      <!-- Link dichiarato esplicitamente: cosi' il client non lo riscrive in blu.
           Le righe assenti dal profilo vengono omesse, non lasciate a meta'. -->
      ${indirizzoPiede ? `<p style="margin:0 0 14px;">
        <a href="${mapsUrl}" style="color:#B9B4AC;text-decoration:none;font-family:${FONT_TESTO};font-size:12px;line-height:1.7;">${indirizzoPiede}</a>
      </p>` : ''}
      <!-- Una voce per riga: su schermo stretto i separatori restavano appesi a fine riga -->
      <p style="margin:0;font-family:${FONT_TESTO};font-size:12px;line-height:2;">${contattiPiede}</p>
    </td>
  </tr>`;
}

function wrap(d: EmailData, body: string): string {
  return `<!DOCTYPE html>
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
  ${header(d.restName, d.restAddress, d.restCity)}
  ${body}
</table>
</td></tr>
</table>
</body>
</html>`;
}

// ─── Email 1: Conferma della prenotazione ────────────────────────────────────

function buildEmail1Html(d: EmailData): string {
  const body = `<tr>
    <td style="background:white;padding:34px 32px 26px;">
      <h2 style="color:${C.neroSoft};font-family:${FONT_TITOLO};font-size:21px;font-weight:bold;line-height:1.35;margin:0 0 16px;">
        Abbiamo ricevuto correttamente la tua richiesta di prenotazione.
      </h2>
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 22px;">
        <tr>
          <td style="background:${C.oroChiaro};border-left:3px solid ${C.oro};padding:14px 16px;border-radius:0 8px 8px 0;">
            <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:14px;line-height:1.65;margin:0;">
              Ti ricordiamo che <strong style="color:${C.rosso};">questa comunicazione non costituisce una conferma di prenotazione</strong>.
              La disponibilità verrà verificata dal nostro staff e riceverai una conferma definitiva il prima possibile.
            </p>
          </td>
        </tr>
      </table>
      <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:15px;line-height:1.7;margin:0 0 26px;">
        Grazie per averci contattato.
      </p>
      ${detailsTable(d)}
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:30px 0 0;">
        <tr>
          <td align="center">
            <a href="${d.statusUrl}" style="background:${C.rosso};color:#ffffff;text-decoration:none;padding:15px 34px;border-radius:8px;font-family:${FONT_TESTO};font-size:15px;font-weight:bold;display:inline-block;">
              Vedi la tua prenotazione
            </a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  ${footer(d)}`;
  return wrap(d, body);
}

// ─── Email 2: Nuovo messaggio ─────────────────────────────────────────────────

function buildEmail2Html(d: EmailData): string {
  const replyUrl = `mailto:${d.restContactEmail}?subject=Re: Prenotazione ${d.dateFormatted}`;
  const body = `<tr>
    <td style="background:white;padding:34px 32px 26px;">
      <h2 style="color:${C.neroSoft};font-family:${FONT_TITOLO};font-size:21px;font-weight:bold;line-height:1.35;margin:0 0 10px;">
        Nuovo messaggio sulla tua prenotazione
      </h2>
      <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:15px;line-height:1.7;margin:0 0 24px;">Gentile cliente, la aspettiamo.</p>
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 26px;">
        <tr>
          <td align="center">
            <a href="${replyUrl}" style="background:#ffffff;color:${C.rosso};text-decoration:none;padding:13px 30px;border:2px solid ${C.rosso};border-radius:8px;font-family:${FONT_TESTO};font-size:15px;font-weight:bold;display:inline-block;">
              Rispondi
            </a>
          </td>
        </tr>
      </table>
      ${detailsTable(d)}
      <table width="100%" cellpadding="0" cellspacing="0" style="margin:30px 0 0;">
        <tr>
          <td align="center">
            <a href="${d.statusUrl}" style="background:${C.rosso};color:#ffffff;text-decoration:none;padding:15px 34px;border-radius:8px;font-family:${FONT_TESTO};font-size:15px;font-weight:bold;display:inline-block;">
              Vedi la tua prenotazione
            </a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  ${footer(d)}`;
  return wrap(d, body);
}
