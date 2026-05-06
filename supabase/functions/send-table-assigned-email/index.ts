import nodemailer from 'npm:nodemailer@6.9.9';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      email, nome, cognome, phone,
      date, time, persons, notes, turno, area,
      tableName,
      restaurantName, restaurantAddress, restaurantCity, restaurantPhone, restaurantEmail,
      bookingId,
    } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: 'Email cliente mancante' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const dateObj = new Date(date + 'T12:00:00');
    const DAYS = ['Domenica','Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato'];
    const MONTHS = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];
    const DAYS_SHORT = ['dom','lun','mar','mer','gio','ven','sab'];
    const MONTHS_SHORT = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];

    const dateFormatted = `${DAYS[dateObj.getDay()]}, ${dateObj.getDate()} ${MONTHS[dateObj.getMonth()]} ${dateObj.getFullYear()}`;
    const dateSubject = `${DAYS_SHORT[dateObj.getDay()]} ${dateObj.getDate()} ${MONTHS_SHORT[dateObj.getMonth()]} ${dateObj.getFullYear()}`;

    const timeShort = (time || '').substring(0, 5);
    const [h, m] = timeShort.split(':').map(Number);
    const endMin = h * 60 + m + 120;
    const endTime = `${String(Math.floor(endMin / 60) % 24).padStart(2, '0')}:${String(endMin % 60).padStart(2, '0')}`;

    const restName = restaurantName || 'Hio Oriental Bar';
    const restAddress = restaurantAddress || 'Via Giuseppe Mazzini 5';
    const restCity = restaurantCity || '90139 Palermo';
    const restPhone = restaurantPhone || '+39 328 574 4906';
    const restContactEmail = restaurantEmail || 'info@hiooriental.com';

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

    const subject = `Il tuo tavolo è confermato (${persons} ${persons === 1 ? 'persona' : 'persone'}, ${dateSubject} ${timeShort})`;

    await transporter.sendMail({
      from: `${restName} <${smtpUser}>`,
      to: email,
      subject,
      html: buildHtml({
        nome: nome || '', cognome: cognome || '', email, phone: phone || '',
        dateFormatted, time: timeShort, endTime, persons,
        notes: notes || '', turno: turno || '', area: area || '',
        tableName: tableName || '',
        restName, restAddress, restCity, restPhone, restContactEmail, statusUrl,
      }),
    });

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-table-assigned-email error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

type D = {
  nome: string; cognome: string; email: string; phone: string;
  dateFormatted: string; time: string; endTime: string; persons: number;
  notes: string; turno: string; area: string; tableName: string;
  restName: string; restAddress: string; restCity: string;
  restPhone: string; restContactEmail: string; statusUrl: string;
};

function row(label: string, value: string): string {
  if (!value) return '';
  return `<tr>
    <td style="padding:10px 0;border-bottom:1px solid #eee;color:#888;font-size:13px;width:150px;vertical-align:top;">${label}</td>
    <td style="padding:10px 0;border-bottom:1px solid #eee;color:#1a1a2e;font-size:13px;">${value}</td>
  </tr>`;
}

const GAP = `<tr><td colspan="2" style="height:8px;border-bottom:1px solid #eee;"></td></tr>`;

function buildHtml(d: D): string {
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
      <h1 style="color:white;margin:0;font-size:24px;font-weight:700;letter-spacing:1px;">${d.restName}</h1>
    </td>
  </tr>

  <!-- Body -->
  <tr>
    <td style="background:white;padding:40px 40px 24px;">
      <h2 style="color:#1a1a2e;font-size:20px;font-weight:700;margin:0 0 8px;">Il tuo tavolo è confermato!</h2>
      <p style="color:#1a1a2e;font-size:15px;font-weight:700;margin:0 0 24px;">Gentile cliente, ti aspettiamo!</p>

      <table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #eee;">
        ${row('Tavolo', d.tableName)}
        ${row('Data', d.dateFormatted)}
        ${row('Tempo', `${d.time} - ${d.endTime} (2:00 ore)`)}
        ${d.area ? row('La zona', d.area) : ''}
        ${row('Persone', String(d.persons))}
        ${GAP}
        ${row('Nome', d.nome)}
        ${row('Telefono', d.phone)}
        ${row('E-mail', d.email)}
        ${d.notes ? GAP + row('Messaggio', d.notes) : ''}
        ${GAP}
        ${row('COGNOME', d.cognome)}
        ${row('SCEGLI', d.turno)}
      </table>

      <div style="text-align:center;margin:36px 0 0;">
        <a href="${d.statusUrl}" style="background:#3b4cc0;color:white;text-decoration:none;padding:14px 36px;border-radius:6px;font-size:15px;font-weight:600;display:inline-block;">
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
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 2px;">${d.restName}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 2px;">${d.restAddress}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 8px;">${d.restCity}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0;">
          <a href="tel:${d.restPhone}" style="color:#bbb;text-decoration:none;">${d.restPhone}</a>
          &nbsp;&nbsp;·&nbsp;&nbsp;
          <a href="mailto:${d.restContactEmail}" style="color:#bbb;text-decoration:none;">${d.restContactEmail}</a>
        </p>
      </div>
    </td>
  </tr>

</table>
</td></tr>
</table>
</body>
</html>`;
}
