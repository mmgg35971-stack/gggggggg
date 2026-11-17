import test from 'node:test';
import assert from 'node:assert/strict';
import { game } from './helpers.js';
import { scheduledLocation, placeNpcs, advanceTime, catchUp, queueRumour } from '../shared/sim.js';
import { NPCS } from '../shared/world.js';
import { DAY_MIN } from '../shared/state.js';

test('NPC routines: every NPC is somewhere valid at every hour', () => {
  for (const id of Object.keys(NPCS)) for (let h = 0; h < 48; h++) assert.ok(scheduledLocation(id, h * 60), `${id} at hour ${h}`);
});

test('overrides and death beat the schedule', () => {
  const s = game();
  s.npcs.pell.override = 'corvane_market'; s.npcs.oswin.alive = false; placeNpcs(s);
  assert.equal(s.npcs.pell.location, 'corvane_market');
  assert.equal(s.npcs.oswin.location, null);
});

test('time passing builds hunger and fatigue and ticks days', () => {
  const s = game(); const h0 = s.player.hunger;
  advanceTime(s, 3 * DAY_MIN);
  assert.ok(s.player.hunger > h0);
  assert.ok(s.world.lastDailyTick >= 3);
});

test('causal chain: heavy banditry eventually starves the grain supply and raises prices', () => {
  const s = game(); s.world.conditions.banditActivity = 95; s.world.conditions.roadSafety = 10;
  const p0 = s.world.priceMod.mirefold;
  const events = advanceTime(s, 15 * DAY_MIN);
  assert.ok(events.some((e) => e.type === 'caravan_raided'));
  assert.ok(s.world.conditions.grainSupply < 60);
  assert.ok(s.world.priceMod.mirefold >= p0);
});

test('with the Fen Rats broken the road recovers', () => {
  const s = game(); s.player.flags.fenrats_broken = true;
  const b0 = s.world.conditions.banditActivity;
  advanceTime(s, 10 * DAY_MIN);
  assert.ok(s.world.conditions.banditActivity < b0);
  assert.ok(s.world.conditions.roadSafety > 45);
});

test('personal arc: an unrescued Lio dies on day 32 and the quest fails', async () => {
  const s = game();
  s.player.quests.find_lio = { status: 'active', since: s.time };
  advanceTime(s, 33 * DAY_MIN);
  assert.equal(s.npcs.lio.alive, false);
  assert.equal(s.player.flags.lio_dead, true);
  assert.ok(s.chronicle.some((c) => c.type === 'lio_died'));
  const { applyActions } = await import('../shared/engine.js');
  applyActions(s, [{ type: 'look' }]);
  assert.equal(s.player.quests.find_lio.status, 'failed');
});

test('rumours reach the other town only after travel time', () => {
  const s = game();
  queueRumour(s, { from: 'mirefold', rep: 'local', delta: -20, text: { en: 'x', ar: 'x' } });
  assert.equal(s.player.reputation.local.corvane || 0, 0);
  advanceTime(s, 2 * 60);
  assert.equal(s.player.reputation.local.corvane || 0, 0);
  advanceTime(s, 12 * 60);
  assert.ok(s.player.reputation.local.corvane < 0);
});

test('catchUp: the world moves while the player is away, capped at a week', () => {
  const s = game(); const now = Date.now();
  s.lastPlayedReal = now - 30 * 60 * 1000;
  assert.equal(catchUp(s, now).hours, 0);
  s.lastPlayedReal = now - 30 * 24 * 3600 * 1000;
  const t0 = s.time;
  const r = catchUp(s, now);
  assert.equal(r.hours, 24 * 7);
  assert.equal(s.time - t0, 24 * 7 * 60);
});
