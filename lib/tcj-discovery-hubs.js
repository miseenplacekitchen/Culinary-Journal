/**
 * Secondary discovery — not main book categories.
 * Festivals → occasion_tags + Festival Planner dish links.
 * Nourish & Heal → health_tags + dietary_tags hub.
 */
var TCJ_FESTIVAL_OCCASION = {
  onam: 'Onam',
  eid: 'Eid',
  christmas: 'Christmas',
  diwali: 'Diwali',
  wedding: 'Wedding',
  'lunar-new-year': 'Lunar New Year'
};

var TCJ_WELLNESS_FILTERS = [
  { id: 'all', label: 'All wellness', emoji: '💚' },
  { id: 'Vegan', label: 'Vegan', emoji: '🌱', type: 'dietary' },
  { id: 'Vegetarian', label: 'Vegetarian', emoji: '🥗', type: 'dietary' },
  { id: 'Gluten Free', label: 'Gluten free', emoji: '🌾', type: 'dietary' },
  { id: 'Dairy Free', label: 'Dairy free', emoji: '🥛', type: 'dietary' },
  { id: 'High Protein', label: 'High protein', emoji: '💪', type: 'health' },
  { id: 'Low Carb', label: 'Low carb', emoji: '🥦', type: 'health' },
  { id: 'Diabetic Friendly', label: 'Diabetic friendly', emoji: '🩺', type: 'health' },
  { id: 'Low Sodium', label: 'Low sodium', emoji: '🧂', type: 'health' },
  { id: 'Baby Friendly', label: 'Baby friendly', emoji: '👶', type: 'health' },
  { id: 'Kid Friendly', label: 'Kid friendly', emoji: '🧒', type: 'health' },
  { id: 'Recovery Food', label: 'Recovery & nourishing', emoji: '💚', type: 'health' }
];

var TCJ_DISCOVERY_HUBS = [
  {
    id: 'festivals',
    href: 'festival-planner.html',
    emoji: '🎉',
    name: 'Festival Planner',
    description: 'Occasion menus, sadya slots, and recipes tagged for Onam, Eid, Christmas, and more'
  },
  {
    id: 'nourish',
    href: 'nourish-heal.html',
    emoji: '💚',
    name: 'Nourish & Heal',
    description: 'Health-focused and dietary-specific recipes — vegan, gluten-free, low-GI, recovery foods, and gentle flavours'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_FESTIVAL_OCCASION, TCJ_WELLNESS_FILTERS, TCJ_DISCOVERY_HUBS };
}
