import { SMTPClient } from 'https://deno.land/x/denomailer@1.3.3/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { nome, cognome, email, phone, date, time, persons, notes, turno, restaurantName } = await req.json();

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
    const subject = `Richiesta di prenotazione ricevuta (${persons} ${persons === 1 ? 'persona' : 'persone'}, ${dateSubject} ${time})`;

    const html = buildEmailHtml({ nome, cognome, email, phone, dateFormatted, time, endTime, persons, notes, turno, restName });

    const client = new SMTPClient({
      connection: {
        hostname: Deno.env.get('SMTP_HOST') ?? 'smtps.aruba.it',
        port: parseInt(Deno.env.get('SMTP_PORT') ?? '465'),
        tls: true,
        auth: {
          username: Deno.env.get('SMTP_USER') ?? '',
          password: Deno.env.get('SMTP_PASS') ?? '',
        },
      },
    });

    await client.send({
      from: `${restName} <${Deno.env.get('SMTP_USER')}>`,
      to: email,
      subject,
      html,
    });

    await client.close();

    return new Response(JSON.stringify({ success: true }), {
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

function buildEmailHtml(d: {
  nome: string; cognome: string; email: string; phone: string;
  dateFormatted: string; time: string; endTime: string; persons: number;
  notes: string; turno: string; restName: string;
}): string {
  const row = (label: string, value: string) => value ? `
    <tr>
      <td style="padding:12px 0;border-bottom:1px solid #eee;color:#999;font-size:13px;width:150px;vertical-align:top;">${label}</td>
      <td style="padding:12px 0;border-bottom:1px solid #eee;color:#1a1a2e;font-size:13px;">${value}</td>
    </tr>` : '';

  return `<!DOCTYPE html>
<html lang="it">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:24px 0;">
<tr><td>
<table width="600" align="center" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;">

  <!-- Header -->
  <tr>
    <td style="background:#1a1a1a;padding:32px;text-align:center;border-radius:8px 8px 0 0;">
      <h1 style="color:white;margin:0;font-size:22px;font-weight:700;letter-spacing:1px;">${d.restName}</h1>
    </td>
  </tr>

  <!-- Body -->
  <tr>
    <td style="background:white;padding:40px 40px 24px;">
      <h2 style="color:#1a1a2e;font-size:22px;font-weight:700;margin:0 0 16px;">Richiesta di prenotazione ricevuta</h2>
      <p style="color:#555;font-size:14px;line-height:1.7;margin:0 0 32px;">
        Grazie per la tua richiesta di prenotazione, ti risponderemo il prima possibile.
        Tieni presente che questa non è una conferma della tua prenotazione.
      </p>

      <!-- Dettagli -->
      <table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #eee;">
        ${row('Data', d.dateFormatted)}
        ${row('Tempo', `${d.time} - ${d.endTime} (2:00 ore)`)}
        ${row('Persone', String(d.persons))}
        ${row('Nome', d.nome)}
        ${row('Telefono', d.phone)}
        ${row('E-mail', d.email)}
        ${row('Messaggio', d.notes)}
        ${row('COGNOME', d.cognome)}
        ${row('SCEGLI', d.turno)}
      </table>

      <!-- CTA -->
      <div style="text-align:center;margin:36px 0 0;">
        <a href="https://ferrarapeppe.github.io/restaurant-booking/booking.html"
           style="background:#3b4cc0;color:white;text-decoration:none;padding:14px 36px;border-radius:6px;font-size:15px;font-weight:600;display:inline-block;">
          Visualizza la prenotazione
        </a>
      </div>
    </td>
  </tr>

  <!-- Footer -->
  <tr>
    <td style="background:white;padding:24px 40px 36px;border-radius:0 0 8px 8px;">
      <div style="border-top:1px solid #eee;padding-top:24px;">
        <p style="color:#555;font-size:13px;margin:0 0 2px;">Distinti saluti</p>
        <p style="color:#1a1a2e;font-size:13px;font-weight:700;margin:0 0 24px;">${d.restName}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0;">${d.restName}</p>
      </div>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;
}
