/**
 * Static verification for Dish Index — no DB required.
 * Run: node tests/verify-dish-index-bindings.mjs
 */
import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function read(rel) {
  return readFileSync(join(root, rel), 'utf8');
}

const js = read('lib/dashboard-recipe-name-library.js');
const dash = read('dashboard.html');
const sqlFiles = readdirSync(join(root, 'database/sql'))
  .filter((f) => f.endsWith('.sql'))
  .map((f) => read(join('database/sql', f)))
  .join('\n');

const rpcCalls = [...js.matchAll(/rpc\(\s*['"]([^'"]+)['"]/g)].map((m) => m[1]);
const rpcUnique = [...new Set(rpcCalls)];

const failures = [];
const passes = [];

for (const rpc of rpcUnique) {
  const pattern = new RegExp(`FUNCTION\\s+public\\.${rpc}\\b`, 'i');
  if (!pattern.test(sqlFiles)) {
    failures.push(`RPC "${rpc}" called in JS but no CREATE FUNCTION in database/sql/*.sql`);
  } else {
    passes.push(`RPC ${rpc}`);
  }
}

const shellIds = [...js.matchAll(/id="(rnl-[^"]+)"/g)].map((m) => m[1]);
const boundIds = new Set([
  ...js.matchAll(/getElementById\(\s*['"](rnl-[^'"]+)['"]/g),
  ...js.matchAll(/id="(rnl-[^"]+)"[^>]*onclick/g),
].map((m) => m[1]));

const actionButtons = shellIds.filter((id) =>
  /btn|commit|close|filter|search|file|select-all|bulk-|col-vis|dup-|cov-/.test(id)
);
for (const id of actionButtons) {
  if (!boundIds.has(id) && !js.includes("document.getElementById('rnl-bulk-")) {
    const hasBulkDelegate = id.startsWith('rnl-bulk-') && js.includes("getElementById('" + id + "')");
    const hasDelegate = js.includes("'" + id + "'") || js.includes('"' + id + '"');
    if (!hasDelegate) {
      failures.push(`UI id "${id}" in renderShell may be unbound`);
    }
  }
}

if (!dash.includes('#rnl-table thead th.di-sticky-0') || !dash.includes('position: sticky')) {
  failures.push('Sticky header CSS missing on #rnl-table thead th.di-sticky-*');
} else {
  passes.push('Sticky header CSS');
}

if (!js.includes('syncDiStickyOffsets')) {
  failures.push('syncDiStickyOffsets() missing');
} else {
  passes.push('syncDiStickyOffsets');
}

const versionMatch = js.match(/_SHELL_VERSION = '([^']+)'/);
const scriptMatch = dash.match(/dashboard-recipe-name-library\.js\?v=([^"]+)/);
if (!versionMatch || !scriptMatch || versionMatch[1] !== scriptMatch[1]) {
  failures.push(`Version mismatch: JS=${versionMatch?.[1]} dashboard cache=${scriptMatch?.[1]}`);
} else {
  passes.push(`Version ${versionMatch[1]} synced`);
}

const requiredFeatures = [
  ['rnl-dup-btn', 'Duplicates button'],
  ['rnl-cov-btn', 'Coverage gaps button'],
  ['admin_dish_index_duplicate_clusters', 'Duplicate clusters RPC'],
  ['admin_dish_index_coverage_gaps', 'Coverage gaps RPC'],
  ['admin_dish_index_queue_counts', 'Queue counts RPC'],
  ['exportBulkPrintStudio', 'Bulk print export (dashboard-bulk-recipes.js)'],
];
const bulk = read('lib/dashboard-bulk-recipes.js');
for (const [needle, label] of requiredFeatures) {
  const hay = needle.startsWith('export') ? bulk : (needle.startsWith('admin_') ? js + sqlFiles : js);
  if (!hay.includes(needle)) failures.push(`Missing: ${label} (${needle})`);
  else passes.push(label);
}

console.log('Dish Index static verification\n');
console.log('PASS (' + passes.length + '):');
passes.forEach((p) => console.log('  ✓', p));
if (failures.length) {
  console.log('\nFAIL (' + failures.length + '):');
  failures.forEach((f) => console.log('  ✗', f));
  process.exit(1);
}
console.log('\nAll static checks passed.');
process.exit(0);
