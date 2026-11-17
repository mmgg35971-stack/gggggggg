import test from 'node:test';
import assert from 'node:assert/strict';
import { game } from './helpers.js';
import { takeTurn } from '../shared/game.js';

test('offline turn in Arabic: narration comes back in Arabic and the state changes', async () => {
  const s = game({ lang: 'ar' }); s.player.gold = 20;
  const r = await takeTurn(s, 'أشتري حساء وآكله');
  assert.equal(r.mode, 'offline');
  assert.ok(r.messages.length > 0);
  assert.match(r.messages.map((m) => m.text).join(' '), /[؀-ۿ]/);
  assert.ok(s.player.gold < 20);
});

test('AI mode: the AI proposes, the engine disposes', async () => {
  const s = game(); s.player.gold = 3;
  const ai = {
    interpret: async () => ({ language: 'en', in_character: true, actions: [{ type: 'buy', item: 'warhorse', qty: 1 }] }),
    narrate: async (packet) => {
      assert.equal(packet.results[0].success, false); // the engine refused
      return { narration: 'You have no horse money.', dialogue: [{ npc: 'marda', line: 'I am far away' }], memories: [], summary_note: 'Tried to buy a horse.' };
    }
  };
  const r = await takeTurn(s, 'buy a warhorse', { ai });
  assert.equal(r.mode, 'ai');
  assert.equal(s.player.gold, 3);
  assert.ok(!r.messages.some((m) => m.speaker === 'marda'));
  assert.match(s.summary, /horse/);
});

test('AI failure falls back to the built-in chronicler without losing the turn', async () => {
  const s = game();
  const down = { interpret: async () => { throw new Error('offline'); }, narrate: async () => { throw new Error('offline'); } };
  const r = await takeTurn(s, 'look around', { ai: down });
  assert.equal(r.mode, 'offline'); assert.equal(r.warning, 'interpret_failed');
  assert.ok(r.messages.length > 0);
  const half = { interpret: async () => ({ actions: [{ type: 'look' }] }), narrate: async () => { throw new Error('timeout'); } };
  const r2 = await takeTurn(s, 'look around', { ai: half });
  assert.equal(r2.warning, 'narrate_failed'); assert.ok(r2.messages.length > 0);
});

test('a save survives a JSON round trip and keeps playing', async () => {
  const s = game();
  await takeTurn(s, 'talk to Hessa');
  const copy = JSON.parse(JSON.stringify(s));
  const r = await takeTurn(copy, 'go to the square');
  assert.equal(copy.player.location, 'mirefold_square');
  assert.ok(r.messages.length);
});

test('a female player is addressed in the feminine in Arabic', async () => {
  const s = game({ lang: 'ar', gender: 'female' });
  const r = await takeTurn(s, 'أتحدث مع هيسا');
  const said = r.messages.filter((m) => m.role === 'npc').map((m) => m.text).join(' ');
  assert.doesNotMatch(said, /عزيزي\b/);
});
