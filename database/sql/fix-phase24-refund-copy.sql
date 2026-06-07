-- ══════════════════════════════════════════════════════════════════════
-- fix-phase24-refund-copy.sql — Refund policy + purchase email template
-- Safe to re-run. Updates live wording (ON CONFLICT DO UPDATE).
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.site_settings (key, value) VALUES
  ('refund_policy',
   'Most of The Culinary Journal is free to use with a free account. If you choose a paid extra (such as a theme, optional plan, or subscription), that purchase is final once completed — we do not offer change-of-mind refunds.

Exceptions: If a payment was charged in error, duplicated, or you could not access what you paid for due to a technical fault on our side, contact us within 7 days at miseenplacekitchen.official@gmail.com and we will review it fairly.

Subscriptions: You may cancel anytime; access continues until the end of the paid period. Cancelling does not refund the current period.

By completing a purchase you agree to this policy. See subscription-terms.html for full subscription terms.'),
  ('billing_no_refunds_banner',
   'No refunds on completed purchases. Core features stay free. Billing error or access fault? Email us within 7 days.')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO public.email_templates (key, name, subject, body, updated_at) VALUES
('purchase_confirmation',
 'Purchase Confirmation',
 'Thank you for your purchase — The Culinary Journal',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Thank you, {{name}}</h2>
<p>We received your payment for <strong>{{product_name}}</strong>{{amount_line}}.</p>
<p>Your account has been updated. Sign in anytime at <a href="https://www.theculinaryjournal.site/login.html">The Culinary Journal</a>.</p>
<h3 style="font-family:Cormorant Garamond,serif;font-size:1.1rem;color:#e8e0d4;margin-top:20px">Refund policy</h3>
<p style="font-size:13px;line-height:1.6;color:#b0a898">Most of the site is free. Paid extras (themes, optional plans) are final once completed. If something went wrong technically — duplicate charge, wrong amount, or access failure on our side — contact <a href="mailto:miseenplacekitchen.official@gmail.com">miseenplacekitchen.official@gmail.com</a> within 7 days and we will review it.</p>
<p style="font-size:12px;color:#888">Questions? Reply to this email or write to miseenplacekitchen.official@gmail.com</p>',
 NOW()),
('subscription_confirmation',
 'Subscription / Tier Confirmation',
 'Your Culinary Journal plan is active',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">You''re all set, {{name}}</h2>
<p>Your <strong>{{tier_label}}</strong> access on The Culinary Journal is now active.</p>
<p>Most core features remain free for everyone. This plan unlocks the extras described at checkout.</p>
<h3 style="font-family:Cormorant Garamond,serif;font-size:1.1rem;color:#e8e0d4;margin-top:20px">Refund policy</h3>
<p style="font-size:13px;line-height:1.6;color:#b0a898">Completed purchases are final. You may cancel anytime; access continues until the end of the paid period. Billing errors or technical access issues? Contact us within 7 days at <a href="mailto:miseenplacekitchen.official@gmail.com">miseenplacekitchen.official@gmail.com</a>.</p>
<p style="font-size:12px;color:#888"><a href="https://www.theculinaryjournal.site/subscription-terms.html">Full subscription terms</a></p>',
 NOW())
ON CONFLICT (key) DO UPDATE SET
  name       = EXCLUDED.name,
  subject    = EXCLUDED.subject,
  body       = EXCLUDED.body,
  updated_at = NOW();

-- Public read for subscription-terms.html and upgrade pages (no admin login required)
DROP FUNCTION IF EXISTS public.get_public_billing_policy();
CREATE FUNCTION public.get_public_billing_policy()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT jsonb_build_object(
    'refund_policy', COALESCE((SELECT value FROM public.site_settings WHERE key = 'refund_policy'), ''),
    'billing_no_refunds_banner', COALESCE((SELECT value FROM public.site_settings WHERE key = 'billing_no_refunds_banner'), '')
  );
$$;
GRANT EXECUTE ON FUNCTION public.get_public_billing_policy() TO anon, authenticated;

SELECT 'fix-phase24-refund-copy.sql complete' AS status;
