import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const RIC = require('../lib/recipe-import-core.js');

const blob = `Gothambu Puttu Recipe
Preparation Time : 10 mins Cooking time : 6-8 mins Serves : 4
Ingredients :
Wheat Flour /Atta : 2 cups Grated Coconut : 1 cup Water : 3/4 cup or enough to moisten the flour Salt to taste : How to make Gothumbu Puttu :
1. Dry roast wheat flour. 2. Add salt to water. 3. Wet the flour. 4. Pulse in mixer. 5. Optional coconut. 6. Fill cooker. 7. Layer tube. 8. Steam 6-8 minutes. 9. Serve hot with curry.
Related Posts
5/5 (1 Review)`;

const s = RIC.segmentRecipeImportText(blob);
const conf = RIC.computeImportConfidence(s.ingCount, s.method);
console.log('ing:', s.ingCount, 'meth:', s.methCount);
console.log('ings:', s.ingredients);
console.log('steps:', s.method.length, s.method[0]?.slice(0,40));
console.log('allowEnrich:', conf.allowEnrich, 'score:', conf.score);
process.exit(s.ingCount >= 4 && s.methCount >= 8 ? 0 : 1);
