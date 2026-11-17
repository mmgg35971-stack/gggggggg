import test from 'node:test';
import assert from 'node:assert/strict';
import { game } from './helpers.js';
import { tokenize, recordEvent, addMemory, pushChat, retrieveEvents, memoriesOf, buildContext } from '../shared/memory.js';

test('Arabic normalisation makes spelling variants match', () => {
  assert.deepEqual(tokenize('أحمد'), tokenize('احمد'));
  assert.deepEqual(tokenize('الفانوسُ'), tokenize('الفانوس'));
});

test('important events enter the chronicle; small ones do not', () => {
  const s = game(); const c0 = s.chronicle.length;
  recordEvent(s, { type: 'x', importance: 2, text: { en: 'small', ar: 'صغير' } });
  recordEvent(s, { type: 'y', importance: 5, text: { en: 'big', ar: 'كبير' } });
  assert.equal(s.chronicle.length, c0 + 1);
});

test('retrieval prefers events about the entities and words of this turn', () => {
  const s = game();
  recordEvent(s, { type: 'a', importance: 1, entities: ['oswin'], text: { en: 'Bought a nail from the smith', ar: 'مسمار' } });
  recordEvent(s, { type: 'b', importance: 1, entities: ['marda'], text: { en: 'The factor counted glass beads', ar: 'خرز' } });
  const top = retrieveEvents(s, { query: 'glass beads', entities: ['marda'], k: 1 });
  assert.equal(top[0].type, 'b');
});

test('NPC memories: the important ones are never forgotten', () => {
  const s = game();
  addMemory(s, 'hessa', 'The stranger saved my inn.', 5);
  for (let i = 0; i < 1000; i++) addMemory(s, 'hessa', `small talk ${i}`, 1);
  assert.ok(s.memories.some((m) => m.text === 'The stranger saved my inn.'));
  assert.ok(s.memories.length < 1000);
  assert.equal(memoriesOf(s, 'hessa', 1)[0].text, 'The stranger saved my inn.');
});

test('chat is capped and overflowed events fold into the summary', () => {
  const s = game();
  pushChat(s, { role: 'event', text: 'THE BRIDGE BURNED' });
  for (let i = 0; i < 400; i++) pushChat(s, { role: 'narrator', text: 'n' + i });
  assert.ok(s.chat.length <= 300);
  assert.match(s.summary, /THE BRIDGE BURNED/);
});

test('AI context packet is compact and carries memories, not the transcript', () => {
  const s = game();
  for (let i = 0; i < 250; i++) pushChat(s, { role: 'narrator', text: 'long prose '.repeat(40) });
  addMemory(s, 'hessa', 'Paid for stew.', 2);
  const ctx = buildContext(s, { query: 'stew', presentNpcs: ['hessa'], lang: 'en' });
  const size = JSON.stringify(ctx).length;
  assert.ok(size < 12000, `context is ${size} chars`);
  assert.deepEqual(ctx.present_npcs[0].memories_of_player, ['Paid for stew.']);
  assert.equal(ctx.present_npcs[0].gender, 'female');
});
