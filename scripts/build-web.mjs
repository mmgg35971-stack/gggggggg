// Assemble the web bundle the Android app ships: app/ at the root, shared/ beside it.
// main.js imports './shared/…', which the dev server also serves at /shared.
import { cpSync, rmSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'www');
rmSync(out, { recursive: true, force: true });
mkdirSync(out);
cpSync(join(root, 'app'), out, { recursive: true });
cpSync(join(root, 'shared'), join(out, 'shared'), { recursive: true });
console.log('web bundle written to', out);
