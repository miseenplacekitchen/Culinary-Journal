// Deploy: supabase functions deploy send-queued-emails
// Secrets: RESEND_API_KEY, CRON_SECRET (see send-queued-emails.js header)
// Cron SQL: database/sql/schedule-email-cron.sql

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESEND_API = 'https://api.resend.com/emails';
const FROM       = 'The Culinary Journal <noreply@theculinaryjournal.site>';

Deno.serve(async (req) => {
  const CRON_SECRET = Deno.env.get('CRON_SECRET');
  if (!CRON_SECRET) {
    return new Response('CRON_SECRET not configured', { status: 500 });
  }
  const authHeader = req.headers.get('Authorization') || '';
  const provided   = authHeader.replace('Bearer ', '').trim();
  const encoder    = new TextEncoder();
  const a = encoder.encode(provided);
  const b = encoder.encode(CRON_SECRET);
  let mismatch = a.length !== b.length ? 1 : 0;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    mismatch |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  if (mismatch !== 0) {
    return new Response('Unauthorized', { status: 401 });
  }
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL'),
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    );
    const RESEND_KEY = Deno.env.get('RESEND_API_KEY');
    if (!RESEND_KEY) return new Response('RESEND_API_KEY not set', { status: 500 });

    await supabase
      .from('email_queue')
      .update({ status: 'pending' })
      .eq('status', 'sending')
      .lt('last_attempt_at', new Date(Date.now() - 10 * 60 * 1000).toISOString());

    const { data: queue, error } = await supabase
      .from('email_queue')
      .select('id, template_key, to_email, to_name, variables, attempts')
      .eq('status', 'pending')
      .lt('attempts', 3)
      .order('created_at', { ascending: true })
      .limit(20);

    if (error) throw error;
    if (!queue || queue.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { headers: { 'Content-Type': 'application/json' } });
    }

    let sent = 0, failed = 0;

    for (const item of queue) {
      try {
        await supabase.from('email_queue').update({ status: 'sending', attempts: (item.attempts || 0) + 1, last_attempt_at: new Date().toISOString() }).eq('id', item.id);

        const { data: tmpl } = await supabase
          .from('email_templates')
          .select('subject, body')
          .eq('key', item.template_key)
          .single();

        if (!tmpl) {
          await supabase.from('email_queue').update({ status: 'failed', error_msg: 'Template not found' }).eq('id', item.id);
          failed++;
          continue;
        }

        const vars = item.variables || {};
        vars.name     = vars.name    || item.to_name || 'Member';
        vars.site_url = 'https://www.theculinaryjournal.site';

        function escText(str) {
          return String(str || '').replace(/[\r\n\t]/g,' ').replace(/\s+/g,' ').trim().slice(0,200);
        }
        function escHtml(str) {
          return String(str || '')
            .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
            .replace(/"/g,'&quot;');
        }
        function escUrl(str) {
          const s = String(str || '');
          return s.startsWith('https://www.theculinaryjournal.site/') ? s : '#';
        }

        let subject = tmpl.subject;
        let body    = tmpl.body;
        for (const [k, v] of Object.entries(vars)) {
          const re = new RegExp('{{' + k + '}}', 'g');
          const isUrl = k.endsWith('_url') || k.endsWith('_link');
          subject = subject.replace(re, escText(v));
          body    = body.replace(re, isUrl ? escUrl(v) : escHtml(v));
        }

        const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
  body { font-family: 'DM Sans', Arial, sans-serif; background: #0C0702; color: #e0d8cc; margin: 0; padding: 0; }
  .wrap { max-width: 560px; margin: 40px auto; background: #13100A; border: 1px solid rgba(222,168,43,0.2); border-radius: 12px; padding: 40px; }
  h2 { font-family: Georgia, serif; color: #DEA82B; }
  a { color: #DEA82B; }
  .footer { margin-top: 32px; padding-top: 20px; border-top: 1px solid rgba(255,255,255,0.08); font-size: 12px; color: rgba(255,255,255,0.3); }
</style></head>
<body><div class="wrap">
${body}
<div class="footer">The Culinary Journal · <a href="${vars.site_url}">${vars.site_url}</a></div>
</div></body></html>`;

        const res = await fetch(RESEND_API, {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + RESEND_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ from: FROM, to: [item.to_email], subject, html })
        });

        if (res.ok) {
          await supabase.from('email_queue').update({ status: 'sent', sent_at: new Date().toISOString() }).eq('id', item.id);
          sent++;
        } else {
          const err = await res.json().catch(() => ({}));
          const newAttempts = (item.attempts || 0) + 1;
          await supabase.from('email_queue').update({
            status: newAttempts >= 3 ? 'failed' : 'pending',
            error_msg: JSON.stringify(err),
            attempts: newAttempts,
            last_attempt_at: new Date().toISOString()
          }).eq('id', item.id);
          failed++;
        }
      } catch (e) {
        const newAttempts = (item.attempts || 0) + 1;
        await supabase.from('email_queue').update({
          status: newAttempts >= 3 ? 'failed' : 'pending',
          error_msg: String(e),
          attempts: newAttempts,
          last_attempt_at: new Date().toISOString()
        }).eq('id', item.id);
        failed++;
      }
    }

    return new Response(JSON.stringify({ sent, failed }), { headers: { 'Content-Type': 'application/json' } });

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
