/**
 * Pasture & Hoof — protein-led sub-categories (C1–C7, 2026).
 * `ingredients` = cut/focus hints (not divisions).
 */
var TCJ_PASTURE_TAXONOMY = [
  {
    code: 'C1',
    name: 'Bovine & Cattle',
    shortName: 'Beef & Veal',
    emoji: '🐂',
    ingredients: ['Bone-In Ribs', 'Shanks', 'Brisket', 'Steaks', 'Oxtail', 'Minced Beef', 'Veal Cutlets'],
    tagline: 'The grand pasture traditions of beef and veal, celebrated through rich cuts, deep braises, and open fire.',
    description: 'From grass-fed cattle roaming ancestral ranges to highly prized marbled heritages. Beef represents texture, depth, and celebratory abundance, transforming beautifully through low-and-slow wood smoke, high-heat sears, and time-honoured family stews.'
  },
  {
    code: 'C2',
    name: 'Ovine & Caprine',
    shortName: 'Lamb & Goat',
    emoji: '🐑',
    ingredients: ['Whole Legs', 'Shoulder Cuts', 'Lamb Chops', 'Neck Rings', 'Goat Shanks', 'Diced Mutton'],
    tagline: 'The storied hill and mountain flocks of lamb, mutton, and goat that anchor global spice routes.',
    description: 'Defined by their rich, distinct flavours and deep melting tenderness. These traditional herd animals are the beating heart of communal feasts across the Mediterranean, the Middle East, South Asia, and Africa, thriving alongside vibrant spices and slow-cooked earthen pots.'
  },
  {
    code: 'C3',
    name: 'Porcine & Swine',
    shortName: 'Pork',
    emoji: '🐖',
    ingredients: ['Pork Belly', 'Loin Chops', 'Spare Ribs', 'Pork Shoulders', 'Tenderloin', 'Suckling Pig'],
    tagline: 'The exceptional versatility of pork, spanning crisp roasts, rich fats, and global delicatessen crafts.',
    description: 'A celebration of domesticated and wild swine heritages. Revered across Europe, East Asia, and the Americas for its incredible ability to render beautifully into golden crackling, absorb sweet glazes, or cure into legendary, generations-old pantry provisions.'
  },
  {
    code: 'C4',
    name: 'Heavy Herd Animals',
    shortName: 'Heavy Herd',
    emoji: '🦬',
    ingredients: ['Buffalo Striploin', 'Bison Patties', 'Camel Hump Fat', 'Camel Fillets', 'Heavy Stewing Cuts'],
    tagline: 'Resilient giants of the plains and deserts, yielding deeply robust, lean, and nutrient-dense meats.',
    description: 'Honoring water buffalo, bison, and camel traditions. These powerful animals are fundamentally woven into the survival and culinary heritages of South Asia, Southeast Asia, and the desert trades, offering incredible depth to slow-simmered, spice-laden curries and hand-pounded kebabs.'
  },
  {
    code: 'C5',
    name: 'Wild Deer & Antelope',
    shortName: 'Venison',
    emoji: '🫎',
    ingredients: ['Venison Loin', 'Haunch Cuts', 'Wild Antelope Steaks', 'Diced Game Meat'],
    tagline: 'Forest-foraged and wild-hunted venison that carries the lean, rustic essence of untamed woodlands.',
    description: 'Showcasing the seasonal hunting heritages of deer, elk, and antelope. Prized by woodland and high-country cooks for its pure, mineral-rich qualities, this meat is traditionally paired with forest berries, wild mushrooms, and warming winter stews.'
  },
  {
    code: 'C6',
    name: 'Leporidae & Small Game',
    shortName: 'Rabbit & Hare',
    emoji: '🐇',
    ingredients: ['Whole Rabbit', 'Rabbit Saddles', 'Hare Thighs', 'Lean Game Joints'],
    tagline: 'Lean, delicate country game that speaks to the rustic, resourceful kitchens of rural hillsides.',
    description: 'Bringing together traditional rabbit and hare preparations. Deeply rooted in European and countryside culinary heritages, these meats are celebrated for their tender, subtle profiles that pair beautifully with fresh garden herbs, white wines, and rich, velvety mustards.'
  },
  {
    code: 'C7',
    name: 'Steppe & Arctic Mammals',
    shortName: 'Steppe & Arctic',
    emoji: '🐴',
    ingredients: ['Horse Fillets', 'Reindeer Haunch', 'Horse Sausages', 'Arctic Land Mammal Cuts'],
    tagline: 'Storied, culturally specific land heritages shaped by the extreme landscapes of the steppes and frozen north.',
    description: 'A respectful home for horse meat, reindeer, and traditional northern game. From the nomadic horse-riding cultures of Central Asia and the horse-sashimi masters of Japan to the indigenous Arctic communities, these meats represent pure survival, deep history, and unique regional delicacies.'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_PASTURE_TAXONOMY };
}
