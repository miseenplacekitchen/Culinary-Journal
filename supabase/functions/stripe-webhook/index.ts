// Deploy: supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET

import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
  if (!stripeKey || !webhookSecret) {
    return new Response('Stripe secrets not configured', { status: 500 });
  }

  const signature = req.headers.get('stripe-signature');
  if (!signature) return new Response('No signature', { status: 400 });

  const body = await req.text();
  const stripe = new Stripe(stripeKey, { apiVersion: '2023-10-16' });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
  } catch (err) {
    return new Response(`Webhook error: ${err}`, { status: 400 });
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const userId = session.metadata?.user_id || session.client_reference_id;
    const tier   = session.metadata?.tier || 'monthly';
    if (userId) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
      const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('TCJ_SERVICE_ROLE_KEY') ?? '';
      const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
      await admin.rpc('apply_stripe_subscription', {
        p_user_id: userId,
        p_tier: tier,
        p_stripe_session_id: session.id,
        p_notes: `Stripe checkout ${session.id}`,
      });
      const promo = session.metadata?.promo_code;
      if (promo && promo.trim()) {
        await admin.rpc('increment_promo_use', { p_code: promo.trim() });
      }
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
