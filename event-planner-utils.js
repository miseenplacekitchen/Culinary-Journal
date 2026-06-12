/* Event planners — guest scaling + meal-planner sync */
(function (global) {
  var DAY_ORDER = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  function mondayOfCurrentWeek() {
    var d = new Date();
    var day = d.getDay();
    var mon = new Date(d);
    mon.setDate(d.getDate() - (day === 0 ? 6 : day - 1));
    mon.setHours(0, 0, 0, 0);
    return mon;
  }

  function currentWeekKey() {
    return 'tcj_meal_' + mondayOfCurrentWeek().toISOString().slice(0, 10);
  }

  function scaleLabel(baseGuests, guests) {
    baseGuests = parseInt(baseGuests, 10) || 4;
    guests = parseInt(guests, 10) || baseGuests;
    if (guests === baseGuests) return '';
    var ratio = guests / baseGuests;
    return ' (×' + guests + ' guests, ~' + (Math.round(ratio * 10) / 10) + '× quantities)';
  }

  function scaledNames(names, baseGuests, guests) {
    var suffix = scaleLabel(baseGuests, guests);
    return (names || []).map(function (n) {
      n = String(n || '').trim();
      return n ? n + suffix : n;
    }).filter(Boolean);
  }

  async function pushDishesToMealPlan(dishNames, opts) {
    opts = opts || {};
    var weekKey = opts.weekKey || currentWeekKey();
    var plan = {};
    try { plan = JSON.parse(localStorage.getItem(weekKey) || '{}'); } catch (_) { TcjErr.warn('degrade', _); }
    var meal = opts.meal || 'dinner';
    var startDay = opts.startDay || 'Sat';
    var startIdx = DAY_ORDER.indexOf(startDay);
    if (startIdx < 0) startIdx = 0;
    var guests = parseInt(opts.guests, 10) || 4;
    var baseGuests = parseInt(opts.baseGuests, 10) || 4;
    var label = opts.eventLabel || 'Event feast';
    var added = 0;

    (dishNames || []).forEach(function (name, i) {
      name = String(name || '').trim();
      if (!name) return;
      var day = DAY_ORDER[(startIdx + i) % DAY_ORDER.length];
      if (!plan[day]) plan[day] = {};
      var slotName = name + scaleLabel(baseGuests, guests);
      plan[day][meal] = {
        name: slotName,
        recipe_name: name,
        status: 'planned',
        servings: guests,
        source: 'event',
        source_label: label
      };
      added++;
    });

    if (!added) return 0;
    localStorage.setItem(weekKey, JSON.stringify(plan));
    localStorage.setItem('tcj_meal_ts_' + weekKey, String(Date.now()));

    try {
      var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
      var url = global.SUPA_URL || global.SUPABASE_URL;
      var key = global.SUPA_KEY || global.SUPABASE_KEY;
      if (sess && sess.access_token && url && key) {
        var serverTs = null;
        if (global.SharedSyncUtils) serverTs = global.SharedSyncUtils.getServerTs('tcj_meal_server_ts_' + weekKey);
        await fetch(url + '/rest/v1/rpc/save_my_meal_plan', {
          method: 'POST',
          headers: {
            'apikey': key,
            'Authorization': 'Bearer ' + sess.access_token,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            p_week_key: weekKey,
            p_plan_data: plan,
            p_client_updated_at: serverTs
          })
        });
      }
    } catch (_) { TcjErr.warn('event-planner-utils.js:90', _); }

    return added;
  }

  global.EventPlannerUtils = {
    scaleLabel: scaleLabel,
    scaledNames: scaledNames,
    pushDishesToMealPlan: pushDishesToMealPlan,
    currentWeekKey: currentWeekKey
  };
})(typeof window !== 'undefined' ? window : globalThis);
