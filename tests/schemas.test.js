import test from 'node:test';
import assert from 'node:assert/strict';
import { sanitizeInterpretation, sanitizeNarration } from '../shared/schemas.js';

test('interpretation: unknown action types and bad values are dropped', () => {
  const out = sanitizeInterpretation({ actions: [
    { type: 'summon_meteor' },
    { type: 'buy', item: 'stew', qty: 9999, approach: 'hypnotise', skill: 'telekinesis', difficulty: 'cakewalk' }
  ] });
  assert.equal(out.actions.length, 1);
  const a = out.actions[0];
  assert.equal(a.type, 'buy'); assert.equal(a.qty, 99);
  assert.equal(a.approach, null); assert.equal(a.skill, null); assert.equal(a.difficulty, null);
});

test('interpretation: garbage still yields a safe look action', () => {
  assert.equal(sanitizeInterpretation(null).actions[0].type, 'look');
  assert.equal(sanitizeInterpretation({ actions: 'lol' }).actions[0].type, 'look');
});

test('narration: absent NPCs cannot speak or form memories', () => {
  const out = sanitizeNarration({
    narration: 'Rain.',
    dialogue: [{ npc: 'hessa', line: 'Hello' }, { npc: 'marda', line: 'I am not here' }],
    memories: [{ npc: 'marda', text: 'x', importance: 5, attitude_delta: 5 }]
  }, { allowedNpcs: ['hessa'] });
  assert.deepEqual(out.dialogue.map((d) => d.npc), ['hessa']);
  assert.equal(out.memories.length, 0);
});

test('narration: attitude changes are clamped and cannot contradict the engine', () => {
  const out = sanitizeNarration({ narration: '', dialogue: [], memories: [
    { npc: 'hessa', text: 'liked it', importance: 3, attitude_delta: 50 },
    { npc: 'tobin', text: 'loved being stabbed', importance: 3, attitude_delta: 4 }
  ] }, { allowedNpcs: ['hessa', 'tobin'], engineAttitude: { tobin: -60 } });
  assert.equal(out.memories[0].attitude_delta, 5);
  assert.equal(out.memories[1].attitude_delta, 0);
});
