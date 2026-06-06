/* Shared Stripe checkout helper — requires signed-in user */
(function (global) {
  async function startStripeCheckout(tier, opts) {
    opts = opts || {};
    var sess = null;
    try { sess = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
    if (!sess || !sess.access_token) {
      var next = opts.next || (typeof window !== 'undefined' ? window.location.pathname.split('/').pop() : '');
      window.location.href = 'login.html?next=' + encodeURIComponent(next) + '#upgrade';
      return;
    }
    var url = (global.SUPA_URL || global.SUPABASE_URL) + '/functions/v1/create-checkout-session';
    var key = global.SUPA_KEY || global.SUPABASE_KEY;
    var res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': key,
        'Authorization': 'Bearer ' + sess.access_token,
      },
      body: JSON.stringify({
        tier: tier || 'monthly',
        promo_code: opts.promo_code || null,
        next: opts.next || null,
      }),
    });
    var data = await res.json().catch(function () { return {}; });
    if (!res.ok) {
      alert(data.error || 'Checkout unavailable. Use admin manual tier grant for now.');
      return;
    }
    if (data.url) window.location.href = data.url;
  }

  global.TCJCheckout = { start: startStripeCheckout };
})(typeof window !== 'undefined' ? window : globalThis);
