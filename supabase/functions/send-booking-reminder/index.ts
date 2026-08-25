import nodemailer from 'npm:nodemailer@6.9.9';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const RESTAURANT_ID = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
const STATUS_BASE_URL = 'https://prenota.hiooriental.com/booking-status.html';

const DAYS   = ['Domenica','Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato'];
const MONTHS = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl     = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  try {
    // Target: now + 12h, converted to Italy local time
    const now    = new Date();
    const target = new Date(now.getTime() + 12 * 3600_000);
    const offset = italyOffset(target);                           // +1 or +2
    const local  = new Date(target.getTime() + offset * 3600_000);

    const targetDate = local.toISOString().split('T')[0];
    const targetMin  = local.getUTCHours() * 60 + local.getUTCMinutes();
    const winLow     = targetMin - 10;   // ±10 min window — covers a 10-min cron interval
    const winHigh    = targetMin + 10;

    // Fetch bookings for that date (approved/seated, reminder not yet sent)
    const qs = new URLSearchParams({
      restaurant_id: `eq.${RESTAURANT_ID}`,
      date:          `eq.${targetDate}`,
      status:        'in.(approved,seated)',
      reminder_sent: 'eq.false',
      select:        '*,guests(first_name,surname,phone,email)',
    });

    const bookingsRes = await fetch(`${supabaseUrl}/rest/v1/bookings?${qs}`, {
      headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` },
    });
    const bookings: Record<string, any>[] = await bookingsRes.json();

    const results = [];
    for (const b of bookings) {
      // Filter by time window
      const [bh, bm] = (b.time_start || '00:00').split(':').map(Number);
      const bMin = bh * 60 + bm;
      if (bMin < winLow || bMin > winHigh) continue;

      const g          = b.guests || {};
      const nome       = (g.first_name  || '').toString();
      const cognome    = (g.surname     || '').toString();
      const phone      = (g.phone       || '').toString();
      const email      = (g.email       || '').toString();
      const timeStr    = (b.time_start  || '').toString().substring(0, 5);
      const dateFmt    = formatDateIT(b.date);
      const statusUrl  = `${STATUS_BASE_URL}?id=${b.id}`;
      const partySize  = Number(b.party_size) || 0;

      let waSent   = false;
      let mailSent = false;

      // ── WhatsApp ──────────────────────────────────────────────────
      if (phone) {
        const normalized = normalizePhone(phone);
        if (normalized) {
          waSent = await sendWhatsApp({ phone: normalized, nome, partySize, dateFmt, timeStr, statusUrl });
        }
      }

      // ── Email ─────────────────────────────────────────────────────
      if (email) {
        mailSent = await sendEmail({ email, nome, cognome, phone, date: b.date, timeStr, partySize, statusUrl });
      }

      // ── Mark reminder sent ────────────────────────────────────────
      if (waSent || mailSent) {
        await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${b.id}`, {
          method:  'PATCH',
          headers: {
            apikey:          serviceRoleKey,
            Authorization:  `Bearer ${serviceRoleKey}`,
            'Content-Type': 'application/json',
            Prefer:         'return=minimal',
          },
          body: JSON.stringify({ reminder_sent: true }),
        });
      }

      results.push({ id: b.id, waSent, mailSent });
    }

    return new Response(JSON.stringify({ ok: true, processed: results.length, results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-booking-reminder error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function italyOffset(d: Date): number {
  const y          = d.getUTCFullYear();
  const lastSunMar = lastSundayOf(y, 2);
  const lastSunOct = lastSundayOf(y, 9);
  return (d >= lastSunMar && d < lastSunOct) ? 2 : 1;
}

function lastSundayOf(year: number, month: number): Date {
  const last = new Date(Date.UTC(year, month + 1, 0, 1, 0, 0));
  last.setUTCDate(last.getUTCDate() - last.getUTCDay());
  return last;
}

function normalizePhone(phone: string): string | null {
  let p = phone.replace(/[\s\-\(\)\+\.]/g, '');
  if (p.startsWith('0039'))    p = '39' + p.slice(4);
  else if (p.startsWith('00')) p = p.slice(2);
  if (/^3\d{9}$/.test(p))     p = '39' + p;  // Italian mobile without country code
  return /^\d{10,15}$/.test(p) ? p : null;
}

function formatDateIT(dateStr: string): string {
  const d = new Date(dateStr + 'T12:00:00');
  return `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

// ── WhatsApp (Meta Cloud API) ─────────────────────────────────────────────────

async function sendWhatsApp(p: {
  phone: string; nome: string; partySize: number;
  dateFmt: string; timeStr: string; statusUrl: string;
}): Promise<boolean> {
  const token        = Deno.env.get('WHATSAPP_TOKEN');
  const phoneId      = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
  const templateName = Deno.env.get('WHATSAPP_TEMPLATE_NAME') ?? 'booking_reminder';
  if (!token || !phoneId) { console.warn('WhatsApp secrets not set'); return false; }

  try {
    const res = await fetch(`https://graph.facebook.com/v19.0/${phoneId}/messages`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: p.phone,
        type: 'template',
        template: {
          name:     templateName,
          language: { code: 'it' },
          components: [{
            type: 'body',
            parameters: [
              { type: 'text', text: p.nome || 'Cliente' },
              { type: 'text', text: p.dateFmt },
              { type: 'text', text: p.timeStr },
              { type: 'text', text: String(p.partySize) },
              { type: 'text', text: p.statusUrl },
            ],
          }],
        },
      }),
    });
    if (!res.ok) { console.error('WhatsApp error:', await res.text()); return false; }
    return true;
  } catch (e) { console.error('WhatsApp fetch error:', e); return false; }
}

// ── Email ─────────────────────────────────────────────────────────────────────

async function sendEmail(p: {
  email: string; nome: string; cognome: string; phone: string;
  date: string; timeStr: string; partySize: number; statusUrl: string;
}): Promise<boolean> {
  const smtpUser = Deno.env.get('SMTP_USER') ?? '';
  const restName = 'Hio Oriental Bar';
  try {
    const transporter = nodemailer.createTransport({
      host:   Deno.env.get('SMTP_HOST') ?? 'smtps.aruba.it',
      port:   parseInt(Deno.env.get('SMTP_PORT') ?? '465'),
      secure: true,
      auth:   { user: smtpUser, pass: Deno.env.get('SMTP_PASS') ?? '' },
    });
    const dateFmt = formatDateIT(p.date);
    const [h, m]  = p.timeStr.split(':').map(Number);
    const endMin  = h * 60 + m + 120;
    const endTime = `${String(Math.floor(endMin / 60) % 24).padStart(2,'0')}:${String(endMin % 60).padStart(2,'0')}`;

    await transporter.sendMail({
      from:    `${restName} <${smtpUser}>`,
      to:      p.email,
      subject: `Promemoria: ti aspettiamo oggi alle ${p.timeStr} — ${restName}`,
      html:    buildEmailHtml({ ...p, dateFmt, endTime, restName }),
    });
    return true;
  } catch (e) { console.error('Email reminder error:', e); return false; }
}

type EmailData = {
  nome: string; cognome: string; email: string; phone: string;
  dateFmt: string; timeStr: string; endTime: string;
  partySize: number; statusUrl: string; restName: string;
};

function buildEmailHtml(d: EmailData): string {
  const mapsUrl = 'https://maps.google.com/?q=Via+Giuseppe+Mazzini+5,+Palermo';
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
      <h2 style="color:#1a1a2e;font-size:20px;font-weight:700;margin:0 0 12px;">Ti aspettiamo stasera! 🍽️</h2>
      <p style="color:#555;font-size:14px;line-height:1.7;margin:0 0 24px;">
        Ciao${d.nome ? ` <strong>${d.nome}</strong>` : ''}, questo è un promemoria per la tua prenotazione di oggi.
        Non vediamo l'ora di accoglierti!
      </p>

      <table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #eee;">
        <tr>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#888;font-size:13px;width:150px;vertical-align:top;">Data</td>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#1a1a2e;font-size:13px;">${d.dateFmt}</td>
        </tr>
        <tr>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#888;font-size:13px;vertical-align:top;">Ora</td>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#1a1a2e;font-size:13px;">${d.timeStr} - ${d.endTime} (2 ore)</td>
        </tr>
        <tr>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#888;font-size:13px;">Persone</td>
          <td style="padding:10px 0;border-bottom:1px solid #eee;color:#1a1a2e;font-size:13px;">${d.partySize}</td>
        </tr>
      </table>

      <div style="text-align:center;margin:36px 0 0;">
        <a href="${d.statusUrl}" style="background:#3b4cc0;color:white;text-decoration:none;padding:14px 36px;border-radius:6px;font-size:15px;font-weight:600;display:inline-block;">
          Visualizza la prenotazione
        </a>
      </div>
    </td>
  </tr>

  <!-- Orario limite -->
  <tr>
    <td style="background:white;padding:0 40px 24px;">
      <p style="color:#e6a817;font-size:13px;line-height:1.6;margin:0;">
        Orario limite: Il tavolo sarà tenuto per un massimo di 20 minuti oltre l'orario prenotato, dopodiché la prenotazione verrà annullata.
      </p>
    </td>
  </tr>

  <!-- Footer -->
  <tr>
    <td style="background:white;padding:24px 40px 36px;border-radius:0 0 8px 8px;">
      <div style="border-top:1px solid #eee;padding-top:24px;">
        <p style="color:#555;font-size:13px;margin:0 0 2px;">Distinti saluti</p>
        <p style="color:#1a1a2e;font-size:13px;font-weight:700;margin:0 0 28px;">${d.restName}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 2px;">${d.restName}</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 2px;">Via Giuseppe Mazzini 5</p>
        <p style="color:#bbb;font-size:11px;text-align:center;margin:0 0 10px;">90139 Palermo</p>
        <p style="font-size:11px;text-align:center;margin:0;">
          <a href="${mapsUrl}" style="color:#888;text-decoration:underline;">Mostra sulla mappa</a>
          &nbsp;&nbsp;
          <a href="tel:+393285744906" style="color:#888;text-decoration:underline;">+39 328 574 4906</a>
          &nbsp;&nbsp;
          <a href="mailto:info@hiooriental.com" style="color:#888;text-decoration:underline;">info@hiooriental.com</a>
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
