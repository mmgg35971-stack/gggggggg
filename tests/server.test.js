import test from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../server/app.js';

const quiet = { error() {} };
async function serve(opts) {
  const app = createApp({ log: quiet, ...opts });
  const srv = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  const base = `http://127.0.0.1:${srv.address().port}`;
  const post = (p, body, headers = {}) => fetch(base + p, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
  return { srv, base, post };
}
const fake = {
  name: 'fake', models: { interpret: 'f', narrate: 'f' },
  interpret: async () => ({ data: { language: 'en', in_character: true, actions: [{ type: 'teleport' }, { type: 'look' }] }, usage: {} }),
  narrate: async () => ({ data: { narration: 'ok', dialogue: [{ npc: 'rusk', line: 'not here' }], memories: [], summary_note: '' }, usage: {} })
};

test('health reports whether AI is configured, never the key', async () => {
  const { srv, base } = await serve({ provider: null });
  const h = await (await fetch(base + '/api/health')).json();
  assert.equal(h.ok, true); assert.equal(h.ai, null);
  assert.ok(!JSON.stringify(h).includes('sk-'));
  srv.close();
});

test('without a provider the AI routes answer 503 so the app falls back', async () => {
  const { srv, post } = await serve({ provider: null });
  assert.equal((await post('/api/ai/interpret', { text: 'hi' })).status, 503);
  srv.close();
});

test('app token is enforced when set', async () => {
  const { srv, post } = await serve({ provider: fake, appToken: 'secret' });
  assert.equal((await post('/api/ai/interpret', { text: 'hi' })).status, 401);
  assert.equal((await post('/api/ai/interpret', { text: 'hi' }, { 'x-app-token': 'secret' })).status, 200);
  srv.close();
});

test('input validation and output sanitising', async () => {
  const { srv, post } = await serve({ provider: fake });
  assert.equal((await post('/api/ai/interpret', { text: '' })).status, 400);
  assert.equal((await post('/api/ai/interpret', { text: 'x'.repeat(700) })).status, 400);
  const i = await (await post('/api/ai/interpret', { text: 'look', lang: 'en', context: {} })).json();
  assert.deepEqual(i.actions.map((a) => a.type), ['look']);
  assert.equal((await post('/api/ai/narrate', { nope: 1 })).status, 400);
  const n = await (await post('/api/ai/narrate', { results: [], allowed_npcs: ['hessa'] })).json();
  assert.equal(n.dialogue.length, 0);
  srv.close();
});

test('rate limit protects the AI budget', async () => {
  const { srv, post } = await serve({ provider: fake, rateLimitPerMin: 2 });
  await post('/api/ai/interpret', { text: 'a' }); await post('/api/ai/interpret', { text: 'b' });
  assert.equal((await post('/api/ai/interpret', { text: 'c' })).status, 429);
  srv.close();
});

test('provider errors become 502, not crashes', async () => {
  const broken = { ...fake, interpret: async () => { throw new Error('boom'); } };
  const { srv, post } = await serve({ provider: broken });
  assert.equal((await post('/api/ai/interpret', { text: 'a' })).status, 502);
  srv.close();
});
