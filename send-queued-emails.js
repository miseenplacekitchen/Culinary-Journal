// Supabase Edge Function: send-queued-emails
// Deploy to Supabase: supabase functions deploy send-queued-emails
// Set secret: supabase secrets set RESEND_API_KEY=re_your_key_here
//
// Call via cron (in Supabase SQL editor):
//   SELECT cron.schedule('send-emails', '*/5 * * * *',
//     $$SELECT net.http_post('https://kzywmodvfbyexqgipcjt.supabase.co/functions/v1/send-queued-emails',
//       '{}', 'application/json',
//       ARRAY[net.http_header('Authorization','Bearer YOUR_SERVICE_ROLE_KEY')])$$);
//
// Or call manually via: POST /functions/v1/send-queued-emails

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESEND_API = 'https://api.resend.com/emails';
const FROM       = 'The Culinary Journal <noreply@theculinaryjournal.site>';

Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL'),
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    );
    const RESEND_KEY = Deno.env.get('RESEND_API_KEY');
    if (!RESEND_KEY) return new Response('RESEND_API_KEY not set', { status: 500 });

    // Reset stale 'sending' rows stuck for more than 10 minutes
    await supabase
      .from('email_queue')
      .update({ status: 'pending' })
      .eq('status', 'sending')
      .lt('last_attempt_at', new Date(Date.now() - 10 * 60 * 1000).toISOString());

    // Fetch up to 20 pending emails (max 3 attempts each)
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
        // Mark as processing + increment attempts to avoid double-send
        await supabase.from('email_queue').update({ status: 'sending', attempts: (item.attempts || 0) + 1, last_attempt_at: new Date().toISOString() }).eq('id', item.id);

        // Load template
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

        // Interpolate variables — escape HTML in all user-supplied values
        const vars = item.variables || {};
        vars.name     = vars.name    || item.to_name || 'Member';
        vars.site_url = 'https://www.theculinaryjournal.site';

        // Plain text sanitiser for email subjects (no HTML entities)
        function escText(str) {
          return String(str || '').replace(/[\r\n\t]/g,' ').replace(/\s+/g,' ').trim().slice(0,200);
        }
        // HTML escaper for email body variables
        function escHtml(str) {
          return String(str || '')
            .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
            .replace(/"/g,'&quot;');
        }
        // URL allowlist — only allow our own site URLs
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

        // Wrap body in base template
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

        // Send via Resend
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
