import test from 'node:test';
import assert from 'node:assert/strict';
import { game } from './helpers.js';
import { parseIntent, detectLang } from '../shared/parser.js';
import { placeNpcs } from '../shared/sim.js';

const types = (s, text) => parseIntent(s, text).actions.map((a) => a.type);
const fresh = () => { const s = game(); placeNpcs(s); return s; };

test('language detection', () => {
  assert.equal(detectLang('أذهب إلى الساحة'), 'ar');
  assert.equal(detectLang('go to the square'), 'en');
});

const CASES = [
  ['look around', ['look']],
  ['أنظر حولي', ['look']],
  ['talk to Hessa', ['talk']],
  ['أتحدث مع هيسا', ['talk']],
  ['buy a bowl of stew and eat it', ['buy', 'eat']],
  ['أشتري حساء وآكله', ['buy', 'eat']],
  ['go to the square then search the well', ['move', 'search']],
  ['أذهب إلى الساحة ثم أبحث حول البئر', ['move', 'search']],
  ['attack Tobin', ['attack']],
  ['أهاجم توبن', ['attack']],
  ['rent a room', ['rent']],
  ['sleep for 8 hours', ['rest']]
];
for (const [text, want] of CASES) {
  test(`parses: ${text}`, () => assert.deepEqual(types(fresh(), text), want));
}

test('compound English sentence splits on "and" only when both halves are actions', () => {
  const s = fresh();
  assert.deepEqual(types(s, 'go to the square and talk to Pell'), ['move', 'talk']);
  assert.equal(types(s, 'ask Hessa about bread and ale').length, 1);
});

test('bribes carry the amount', () => {
  const a = parseIntent(fresh(), 'bribe Hessa with 5 silver').actions[0];
  assert.equal(a.type, 'social'); assert.equal(a.approach, 'bribe'); assert.equal(a.qty, 5);
});

test('fantasy is impossible, grand ambitions are very hard', () => {
  const s = fresh();
  const fly = parseIntent(s, 'I fly over the castle').actions[0];
  assert.equal(fly.type, 'free'); assert.equal(fly.difficulty, 'impossible');
  const army = parseIntent(s, 'I found a mercenary company').actions[0];
  assert.equal(army.difficulty, 'very_hard');
});
