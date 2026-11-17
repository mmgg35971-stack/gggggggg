import test from 'node:test';
import assert from 'node:assert/strict';
import { newGame, validatePointBuy, timeInfo, POINT_BUY, addItem, removeItem, invCount, attitudeBand } from '../shared/state.js';
import { STAT_KEYS, START_LOCATION, BACKGROUNDS } from '../shared/world.js';

const base = Object.fromEntries(STAT_KEYS.map((k) => [k, POINT_BUY.base]));

test('point-buy accepts the budget and rejects overspending or out-of-range stats', () => {
  assert.equal(validatePointBuy(base).ok, true);
  assert.equal(validatePointBuy({ ...base, str: 16 }).ok, false);
  assert.equal(validatePointBuy({ ...base, str: 6 }).ok, false);
  assert.equal(validatePointBuy({ ...base, str: 14, dex: 13 }).ok, false); // 7 points
  assert.equal(validatePointBuy({ ...base, str: 14, dex: 12, cha: 8 }).ok, true); // 6 - 2 + ... = 4
});

test('newGame builds a starting character at the inn with background kit', () => {
  for (const bg of Object.keys(BACKGROUNDS)) {
    const s = newGame({ name: '  Rhea  ', background: bg, seed: 1 });
    assert.equal(s.player.location, START_LOCATION);
    assert.equal(s.player.name, 'Rhea');
    assert.ok(s.player.hp > 0 && s.player.hp === s.player.maxHp);
    assert.ok(Array.isArray(s.player.inventory));
    assert.ok(s.npcs.hessa && s.npcs.hessa.alive);
  }
});

test('time math: days, seasons and night', () => {
  const t0 = timeInfo(0);
  assert.equal(t0.day, 1);
  assert.equal(timeInfo(24 * 60).day, 2);
  assert.equal(timeInfo(23 * 60).isNight, true);
  assert.equal(timeInfo(12 * 60).isNight, false);
  assert.notEqual(timeInfo(0).season, timeInfo(91 * 24 * 60).season);
});

test('inventory add/remove keeps counts honest', () => {
  const s = newGame({ name: 'A', seed: 2 });
  const before = invCount(s, 'bread');
  addItem(s, 'bread', 3);
  assert.equal(invCount(s, 'bread'), before + 3);
  assert.equal(removeItem(s, 'bread', before + 3), true);
  assert.equal(invCount(s, 'bread'), 0);
  assert.equal(removeItem(s, 'bread', 1), false);
});

test('attitude bands', () => {
  assert.equal(attitudeBand(-60), 'hostile');
  assert.equal(attitudeBand(-10), 'cold');
  assert.equal(attitudeBand(0), 'neutral');
  assert.equal(attitudeBand(50), 'warm');
});
