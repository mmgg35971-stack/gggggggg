import test from 'node:test';
import assert from 'node:assert/strict';
import { MOODS, BALLAD, moodForLocation } from '../app/music.js';
import { LOCATIONS } from '../shared/world.js';
import { UI } from '../app/i18n.js';

test('every location has a musical mood', () => {
  for (const [id, loc] of Object.entries(LOCATIONS)) assert.ok(MOODS[moodForLocation(loc)], id);
});

test('the ballad has matching Arabic and English verses', () => {
  assert.ok(BALLAD.en.length >= 4);
  assert.equal(BALLAD.ar.length, BALLAD.en.length);
});

test('every UI string exists in both languages', () => {
  for (const [k, v] of Object.entries(UI)) { assert.ok(v.ar, `${k}.ar`); assert.ok(v.en, `${k}.en`); }
});
