import nodemailer from 'npm:nodemailer@6.9.9';

// ─── Invio con ritentativi ───────────────────────────────────────────────────
// Serve solo quando si ricade sull'SMTP di Aruba, che rifiuta temporaneamente
// la posta dagli IP di Supabase, diversi a ogni chiamata.
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
      await new Promise((r) => setTimeout(r, 1200 * (i + 1)));
    }
  }
  throw ultimoErrore;
}

// ─── Scelta del canale ───────────────────────────────────────────────────────
async function inviaEmail(
  transporter: { sendMail: (m: unknown) => Promise<unknown> },
  messaggio: { from: string; to: string; subject: string; html: string; replyTo?: string },
): Promise<unknown> {
  const chiave = Deno.env.get('RESEND_API_KEY');
  if (!chiave) return await inviaConRitenta(transporter, messaggio);
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${chiave}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: messaggio.from,
      to: [messaggio.to],
      reply_to: messaggio.replyTo || undefined,
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

const C = {
  nero: '#0E0E0E', neroSoft: '#1A1A1A', rosso: '#B7182A',
  oro: '#C9B06E', oroChiaro: '#FBF7EE',
  testo: '#1A1A1A', testoSoft: '#5A5A5A', bordo: '#E4E1DC', sfondo: '#F4F2EF',
};
const FONT_TITOLO = `Georgia,'Times New Roman',serif`;
const FONT_TESTO = `Helvetica,Arial,sans-serif`;

const DAYS = ['Domenica','Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato'];
const MONTHS = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];

// Il messaggio è testo scritto dal cliente: va neutralizzato prima di
// inserirlo nell'HTML dell'email.
function esc(t: unknown): string {
  return String(t ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const {
      messaggio, nome, cognome, telefono, emailCliente,
      date, time, persons, bookingId,
      restaurantName, restaurantAddress, restaurantCity, restaurantEmail,
    } = await req.json();

    if (!messaggio) {
      return new Response(JSON.stringify({ error: 'Messaggio mancante' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const smtpUser = Deno.env.get('SMTP_USER') ?? '';
    // Il destinatario è il ristorante: dal profilo, o la casella SMTP
    const destinatario = restaurantEmail || smtpUser;
    if (!destinatario) {
      return new Response(JSON.stringify({ error: 'Nessun indirizzo del ristorante configurato' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const restName = restaurantName || 'Hio Oriental Bar';
    const cliente = [nome, cognome].filter(Boolean).join(' ').trim() || 'Cliente';
    const timeShort = (time || '').toString().substring(0, 5);

    let quando = '';
    if (date) {
      const d = new Date(`${date}T12:00:00`);
      if (!isNaN(d.getTime())) {
        quando = `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
          + (timeShort ? ` alle ${timeShort}` : '');
      }
    }

    const statusUrl = bookingId
      ? `https://prenota.hiooriental.com/booking-status.html?id=${bookingId}`
      : '';

    const riga = (etichetta: string, valore: string) => valore
      ? `<tr>
          <td style="padding:9px 0;border-bottom:1px solid ${C.bordo};color:${C.testoSoft};font-family:${FONT_TESTO};font-size:11px;font-weight:bold;letter-spacing:1px;text-transform:uppercase;width:104px;vertical-align:top;">${etichetta}</td>
          <td style="padding:9px 0;border-bottom:1px solid ${C.bordo};color:${C.testo};font-family:${FONT_TESTO};font-size:15px;font-weight:bold;word-break:break-word;">${valore}</td>
        </tr>` : '';

    const html = `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="format-detection" content="telephone=no,date=no,address=no,email=no,url=no">
  <style>
    a[x-apple-data-detectors]{color:inherit!important;text-decoration:none!important;font-size:inherit!important;font-family:inherit!important;font-weight:inherit!important;line-height:inherit!important;}
  </style>
</head>
<body style="margin:0;padding:0;background:${C.sfondo};font-family:${FONT_TESTO};">
<table width="100%" cellpadding="0" cellspacing="0" style="background:${C.sfondo};padding:24px 12px;">
<tr><td>
<table width="100%" align="center" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;margin:0 auto;border-collapse:separate;">
  <tr>
    <td style="background:${C.nero};padding:26px 24px;text-align:center;border-radius:12px 12px 0 0;">
      <p style="color:${C.oro};font-family:${FONT_TITOLO};font-size:15px;font-weight:bold;letter-spacing:3px;margin:0;">MESSAGGIO DA UN CLIENTE</p>
    </td>
  </tr>
  <tr>
    <td style="background:white;padding:30px 32px 26px;">
      <h2 style="color:${C.neroSoft};font-family:${FONT_TITOLO};font-size:20px;font-weight:bold;line-height:1.35;margin:0 0 6px;">
        ${esc(cliente)} ha scritto${quando ? ` sulla prenotazione di ${esc(quando)}` : ''}.
      </h2>
      <p style="color:${C.testoSoft};font-family:${FONT_TESTO};font-size:14px;line-height:1.6;margin:0 0 22px;">
        Rispondi dall'app, nella scheda Messaggi della prenotazione: la risposta comparirà al cliente.
      </p>

      <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
        <tr>
          <td style="background:${C.oroChiaro};border-left:3px solid ${C.oro};padding:16px 18px;border-radius:0 8px 8px 0;">
            <p style="color:${C.testo};font-family:${FONT_TESTO};font-size:15px;line-height:1.65;margin:0;white-space:pre-wrap;">${esc(messaggio)}</p>
          </td>
        </tr>
      </table>

      <table width="100%" cellpadding="0" cellspacing="0" style="border-top:2px solid ${C.oro};">
        ${riga('Quando', esc(quando))}
        ${riga('Persone', persons ? String(persons) : '')}
        ${riga('Cliente', esc(cliente))}
        ${riga('Telefono', telefono ? `<a href="tel:${esc(String(telefono).replace(/\s/g, ''))}" style="color:${C.testo};text-decoration:none;">${esc(telefono)}</a>` : '')}
        ${riga('E-mail', emailCliente ? `<a href="mailto:${esc(emailCliente)}" style="color:${C.testo};text-decoration:none;">${esc(emailCliente)}</a>` : '')}
      </table>

      ${statusUrl ? `<table width="100%" cellpadding="0" cellspacing="0" style="margin:28px 0 0;">
        <tr><td align="center">
          <a href="${statusUrl}" style="background:${C.rosso};color:#ffffff;text-decoration:none;padding:15px 34px;border-radius:8px;font-family:${FONT_TESTO};font-size:15px;font-weight:bold;display:inline-block;">
            Apri la prenotazione
          </a>
        </td></tr>
      </table>` : ''}
    </td>
  </tr>
  <tr>
    <td style="background:${C.nero};padding:20px 24px 24px;text-align:center;border-radius:0 0 12px 12px;">
      <p style="color:${C.oro};font-family:${FONT_TITOLO};font-size:13px;font-weight:bold;letter-spacing:3px;margin:0;">${esc(restName.toUpperCase())}</p>
      ${[restaurantAddress, restaurantCity].filter(Boolean).length
        ? `<p style="color:#B9B4AC;font-family:${FONT_TESTO};font-size:12px;line-height:1.6;margin:8px 0 0;">${esc([restaurantAddress, restaurantCity].filter(Boolean).join(', '))}</p>`
        : ''}
    </td>
  </tr>
</table>
</td></tr>
</table>
</body>
</html>`;

    const transporter = nodemailer.createTransport({
      host: Deno.env.get('SMTP_HOST') ?? 'smtps.aruba.it',
      port: parseInt(Deno.env.get('SMTP_PORT') ?? '465'),
      secure: true,
      auth: { user: smtpUser, pass: Deno.env.get('SMTP_PASS') ?? '' },
    });

    await inviaEmail(transporter, {
      from: `${restName} <${smtpUser}>`,
      to: destinatario,
      // Così "Rispondi" dal client di posta scrive al cliente, non a se stessi
      replyTo: emailCliente || undefined,
      subject: `Messaggio da ${cliente}${quando ? ` — prenotazione ${quando}` : ''}`,
      html,
    });

    return new Response(JSON.stringify({ success: true, canale: Deno.env.get('RESEND_API_KEY') ? 'resend' : 'smtp' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-guest-message-email error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
