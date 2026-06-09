var fs = require('fs');
var path = require('path');
var vm = require('vm');
var code = fs.readFileSync(path.join(__dirname, '..', 'lib', 'recipe-import-core.js'), 'utf8');
var sandbox = { module: { exports: {} }, exports: {} };
vm.runInNewContext(code, sandbox);
var RIC = sandbox.module.exports;

var blob = [
  'Gothambu Puttu Recipe',
  'Preparation Time : 10 mins Cooking time : 6-8 mins Serves : 4',
  'Ingredients :',
  'Wheat Flour /Atta : 2 cups Grated Coconut : 1 cup Water : 3/4 cup or enough to moisten the flour Salt to taste : How to make Gothumbu Puttu :',
  '1. Dry roast wheat flour. 2. Add salt to water. 3. Wet the flour. 4. Pulse in mixer. 5. Optional coconut. 6. Fill cooker. 7. Layer tube. 8. Steam 6-8 minutes. 9. Serve hot with curry.',
  'Related Posts',
  '5/5 (1 Review)'
].join('\n');

var s = RIC.segmentRecipeImportText(blob);
var conf = RIC.computeImportConfidence(s.ingCount, s.method);
var ingOk = s.ingredients.every(function (l, i, arr) {
  if (i === 0) return /Wheat Flour.*:\s*2 cups$/i.test(l) && !/Grated Coconut/.test(l);
  if (i === 1) return /Grated Coconut.*:\s*1 cup$/i.test(l) && !/Water/.test(l);
  if (i === 2) return /Water.*:\s*3\/4 cup/i.test(l);
  if (i === 3) return /Salt to taste/i.test(l);
  return true;
});
var pass = s.ingCount >= 4 && s.methCount >= 8 && ingOk;
console.log(JSON.stringify({
  pass: pass,
  ingCount: s.ingCount,
  methCount: s.methCount,
  ingredients: s.ingredients,
  steps: s.method,
  allowEnrich: conf.allowEnrich,
  score: conf.score
}, null, 2));
process.exit(pass ? 0 : 1);
