// Prince Hub build: يجمع ملفات src/ حسب src/manifest.txt بملف واحد بـ dist/
// ويفحص السنتاكس (Luau) + حدود Luau (200 local / 200 upvalue) + المتغيرات اللي ما معرّفة.
//   node tools/build.js              -> يبني dist/PrinceHub_AllInOne.lua ويفحصه
//   node tools/build.js --check-only -> يفحص بس، ما يكتب شي
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const OUT = path.join(ROOT, 'dist', 'PrinceHub_AllInOne.lua');
const checkOnly = process.argv.includes('--check-only');

const files = fs.readFileSync(path.join(SRC, 'manifest.txt'), 'utf8')
  .split('\n').map(s => s.trim()).filter(s => s && !s.startsWith('#'));

let bundle = '';
for (const rel of files) {
  const p = path.join(SRC, rel);
  if (!fs.existsSync(p)) { console.error('missing file in manifest: ' + rel); process.exit(1); }
  let text = fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n');
  if (!text.endsWith('\n')) text += '\n';
  bundle += text;
}

const tmp = path.join(require('os').tmpdir(), 'princehub_build_check.lua');
const target = checkOnly ? tmp : OUT;
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, bundle);

// 1) syntax
try {
  execFileSync(process.execPath, [path.join(__dirname, 'check.js'), target], { stdio: 'pipe' });
} catch (e) {
  console.error(String(e.stdout || e.message));
  console.error('BUILD FAILED: syntax error (line numbers are in the bundled file)');
  process.exit(1);
}

// 2) lint
const lint = JSON.parse(execFileSync(process.execPath, [path.join(__dirname, 'lint.js'), target]).toString());
const baseline = JSON.parse(fs.readFileSync(path.join(__dirname, 'lint-baseline.json'), 'utf8'));
const allowed = new Set(baseline.allowedUndefined);
const newUndef = lint.undefined.filter(u => !allowed.has(u.name));
let failed = false;
if (lint.overLimit.length) {
  failed = true;
  console.error('Luau limit exceeded (Out of local registers in game):', JSON.stringify(lint.overLimit));
}
for (const h of lint.heavy) {
  if (h.maxLocals > 195) console.warn(`WARN: function at line ${h.line} has ${h.maxLocals}/200 locals - do not add more top-level locals there`);
}
if (newUndef.length) {
  failed = true;
  console.error('Undefined variables (typo or used before its local is declared):');
  for (const u of newUndef) console.error(`  ${u.name}  lines ${u.lines.join(', ')}`);
}
if (failed) { console.error('BUILD FAILED'); process.exit(1); }

const lines = bundle.split('\n').length - 1;
console.log(`OK  ${files.length} files -> ${checkOnly ? '(check only)' : path.relative(ROOT, OUT)}  (${lines} lines, ${(bundle.length / 1024).toFixed(0)} KB)`);
