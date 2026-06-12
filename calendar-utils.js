/* Shared calendar helpers — MP-04 between meal planner and diary */
(function (global) {
  var DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  function mondayOfWeek(offset) {
    offset = offset || 0;
    var d = new Date();
    var day = d.getDay();
    var diff = (day === 0 ? -6 : 1) - day;
    d.setDate(d.getDate() + diff + offset * 7);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  function weekDates(offset) {
    var mon = mondayOfWeek(offset);
    var out = [];
    for (var i = 0; i < 7; i++) {
      var x = new Date(mon);
      x.setDate(mon.getDate() + i);
      out.push(x);
    }
    return out;
  }

  function weekKey(offset) {
    var mon = mondayOfWeek(offset);
    return mon.getFullYear() + '-W' + String(Math.ceil((mon.getDate()) / 7)).padStart(2, '0') + '-' + mon.toISOString().slice(0, 10);
  }

  function formatShort(d) {
    return d.toLocaleDateString('en-AU', { weekday: 'short', day: 'numeric', month: 'short' });
  }

  function isSameDay(a, b) {
    return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  }

  function mondayOfDate(date) {
    var d = new Date(date);
    d.setHours(0, 0, 0, 0);
    var day = d.getDay();
    var mon = new Date(d);
    mon.setDate(d.getDate() - (day === 0 ? 6 : day - 1));
    return mon;
  }

  function mealPlanWeekKey(date) {
    return 'tcj_meal_' + mondayOfDate(date).toISOString().slice(0, 10);
  }

  function dayKeyForDateStr(dateStr) {
    var jsDay = new Date(dateStr + 'T00:00:00').getDay();
    return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][jsDay];
  }

  function mealsOnDate(dateStr) {
    try {
      var plan = JSON.parse(localStorage.getItem(mealPlanWeekKey(new Date(dateStr + 'T00:00:00'))) || '{}');
      var day = dayKeyForDateStr(dateStr);
      var names = [];
      ['Breakfast', 'Lunch', 'Dinner', 'Snack'].forEach(function (meal) {
        var slot = plan[day] && plan[day][meal];
        if (slot && slot.name) names.push({ meal: meal, name: slot.name, status: slot.status || 'planned' });
      });
      return names;
    } catch (_) { TcjErr.warn('calendar-utils.js:67', _); }
  }

  global.CalendarUtils = {
    DAYS: DAYS,
    mondayOfWeek: mondayOfWeek,
    weekDates: weekDates,
    weekKey: weekKey,
    formatShort: formatShort,
    isSameDay: isSameDay,
    mondayOfDate: mondayOfDate,
    mealPlanWeekKey: mealPlanWeekKey,
    dayKeyForDateStr: dayKeyForDateStr,
    mealsOnDate: mealsOnDate
  };
})(typeof window !== 'undefined' ? window : globalThis);
