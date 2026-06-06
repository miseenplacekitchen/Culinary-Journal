// Deploy: supabase functions deploy create-checkout-session
// Secrets: STRIPE_SECRET_KEY
// site_settings: stripe_enabled=true, stripe_publishable_key (public)

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const TIER_INTERVAL: Record<string, { mode: 'payment' | 'subscription'; interval?: Stripe.Checkout.SessionCreateParams.LineItem.PriceData.Recurring.Interval; interval_count?: number }> = {
  daily:   { mode: 'subscription', interval: 'day', interval_count: 1 },
  weekly:  { mode: 'subscription', interval: 'week', interval_count: 1 },
  monthly: { mode: 'subscription', interval: 'month', interval_count: 1 },
  yearly:  { mode: 'subscription', interval: 'year', interval_count: 1 },
};

const PRICE_KEYS: Record<string, string> = {
  daily: 'stripe_price_daily',
  weekly: 'stripe_price_weekly',
  monthly: 'stripe_price_monthly',
  yearly: 'stripe_price_yearly',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const stripeKey = (Deno.env.get('STRIPE_SECRET_KEY') ?? '').trim();
  if (!stripeKey) {
    return new Response(JSON.stringify({ error: 'Stripe is not configured. Add STRIPE_SECRET_KEY to Edge secrets.' }), {
      status: 503, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Sign in required' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey     = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('TCJ_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return new Response(JSON.stringify({ error: 'Missing Supabase credentials' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
  }

  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: 'Invalid session' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
  }

  let body: { tier?: string; promo_code?: string; next?: string } = {};
  try { body = await req.json(); } catch (_) {}

  const tier = (body.tier || 'monthly').toLowerCase();
  if (!TIER_INTERVAL[tier]) {
    return new Response(JSON.stringify({ error: 'Invalid tier' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: settings } = await admin.from('site_settings').select('key,value')
    .in('key', ['stripe_enabled', 'currency_code', 'checkout_success_url', 'checkout_cancel_url', PRICE_KEYS[tier], 'billing_no_refunds_banner']);

  const S: Record<string, string> = {};
  (settings ?? []).forEach((r: { key: string; value: string }) => { S[r.key] = r.value; });

  if (S.stripe_enabled !== 'true') {
    return new Response(JSON.stringify({ error: 'Stripe checkout is disabled. Admin can enable it in Finance → Pricing.' }), {
      status: 503, headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  const amount = parseFloat(S[PRICE_KEYS[tier]] || '4');
  const currency = (S.currency_code || 'usd').toLowerCase();
  const amountCents = Math.round(amount * 100);
  const origin = new URL(req.url).origin.replace(/\/functions\/v1.*/, '');
  const successUrl = (S.checkout_success_url || `${origin}/checkout-success.html`).replace('{ORIGIN}', origin) + '?session_id={CHECKOUT_SESSION_ID}';
  const cancelUrl  = body.next
    ? `${S.checkout_cancel_url || `${origin}/paid-members-only.html`}?next=${encodeURIComponent(body.next)}`
    : (S.checkout_cancel_url || `${origin}/paid-members-only.html`);

  const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' });
  const cfg = TIER_INTERVAL[tier];
  const lineItem: Stripe.Checkout.SessionCreateParams.LineItem = {
    quantity: 1,
    price_data: {
      currency,
      unit_amount: amountCents,
      product_data: {
        name: `The Culinary Journal — ${tier.charAt(0).toUpperCase() + tier.slice(1)}`,
        description: 'All sales final. No refunds.',
      },
      ...(cfg.mode === 'subscription' && cfg.interval ? {
        recurring: { interval: cfg.interval, interval_count: cfg.interval_count ?? 1 },
      } : {}),
    },
  };

  const session = await stripe.checkout.sessions.create({
    mode: cfg.mode,
    customer_email: user.email ?? undefined,
    client_reference_id: user.id,
    line_items: [lineItem],
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { user_id: user.id, tier, promo_code: body.promo_code || '' },
  });

  await admin.from('stripe_checkout_sessions').insert({
    user_id: user.id,
    stripe_session_id: session.id,
    tier,
    amount_cents: amountCents,
    currency,
    promo_code: body.promo_code || null,
    status: 'pending',
  });

  return new Response(JSON.stringify({ url: session.url, session_id: session.id }), {
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
});
