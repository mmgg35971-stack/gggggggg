import test from 'node:test';
import assert from 'node:assert/strict';
import { game, act, run } from './helpers.js';
import { invCount, npcsAt } from '../shared/state.js';
import { applyActions, priceOf } from '../shared/engine.js';
import { placeNpcs } from '../shared/sim.js';

test('move: travels along known roads, spends time, records the arrival', () => {
  const s = game(); const t0 = s.time;
  const [r] = run(s, act('move', { destination: 'mirefold_square' }));
  assert.equal(r.code, 'move'); assert.equal(s.player.location, 'mirefold_square');
  assert.ok(s.time > t0);
  assert.ok(s.events.some((e) => e.type === 'arrived' && e.location === 'mirefold_square'));
});

test('move: unknown places and hidden places are refused', () => {
  const s = game();
  assert.equal(run(s, act('move', { destination: 'atlantis' }))[0].code, 'move_unknown');
  assert.equal(run(s, act('move', { destination: 'mill_cellar' }))[0].code, 'move_noroute');
  assert.equal(s.player.location, 'sunken_lantern');
});

test('gate: the toll is charged, a poor or wanted traveller is stopped', () => {
  const s = game(); s.player.location = 'corvane_gate'; s.npcs.brannoc.override = 'corvane_gate';
  s.player.gold = 1;
  assert.equal(run(s, act('move', { destination: 'corvane_market' }))[0].code, 'gate_toll_short');
  s.player.gold = 10;
  const ok = run(s, act('move', { destination: 'corvane_market' }))[0];
  assert.equal(ok.code, 'move'); assert.equal(s.player.gold, 8);
  const w = game(); w.player.location = 'corvane_gate'; w.npcs.brannoc.override = 'corvane_gate'; w.player.reputation.criminal = 50;
  assert.equal(run(w, act('move', { destination: 'corvane_market' }))[0].code, 'gate_refused');
});

test('buy / sell: silver moves both ways and the seller must be present', () => {
  const s = game(); s.player.gold = 20;
  const price = priceOf(s, 'stew');
  const r = run(s, act('buy', { item: 'stew', qty: 2 }))[0];
  assert.equal(r.code, 'buy'); assert.equal(s.player.gold, 20 - price * 2); assert.equal(invCount(s, 'stew'), 2);
  s.player.gold = 0;
  assert.equal(run(s, act('buy', { item: 'stew' }))[0].code, 'buy_poor');
  s.player.location = 'south_road';
  assert.notEqual(run(s, act('buy', { item: 'stew' }))[0].code, 'buy');
});

test('eat: lowers hunger and consumes the item', () => {
  const s = game(); s.player.hunger = 70; s.player.gold = 10;
  run(s, act('buy', { item: 'stew' }));
  const r = run(s, act('eat', {}))[0];
  assert.equal(r.code, 'eat'); assert.ok(s.player.hunger < 70); assert.equal(invCount(s, 'stew'), 0);
});

test('talk: matching topic reveals knowledge and offers a quest', () => {
  const s = game(); placeNpcs(s);
  assert.ok(npcsAt(s, 'sunken_lantern').includes('tobin'));
  const r = run(s, act('talk', { npc: 'tobin', topic: 'Lio the missing apprentice' }))[0];
  assert.equal(r.code, 'talk'); assert.equal(r.quest, 'find_lio');
  assert.equal(s.player.quests.find_lio.status, 'active');
  assert.ok(s.npcs.tobin.met);
});

test('talk: absent NPCs cannot be spoken to', () => {
  const s = game();
  assert.equal(run(s, act('talk', { npc: 'marda' }))[0].code, 'talk_absent');
});

test('social: bribing without silver fails, bribing spends silver', () => {
  const s = game(); s.player.gold = 0;
  assert.equal(run(s, act('social', { npc: 'hessa', approach: 'bribe', qty: 5 }))[0].code, 'bribe_nogold');
  s.player.gold = 10;
  const r = run(s, act('social', { npc: 'hessa', approach: 'bribe', qty: 5, topic: 'gossip' }))[0];
  assert.equal(r.paid, 5); assert.equal(s.player.gold, 5);
});

test('search: a successful search reveals a hidden feature exactly once', () => {
  const s = game(); s.player.location = 'mirefold_square'; s.player.stats.per = 18;
  let found = null;
  for (let i = 0; i < 12 && !found; i++) { const r = run(s, act('search', { description: 'the well' }))[0]; if (r.reveal) found = r; }
  assert.ok(found, 'search eventually succeeds with high perception');
  const again = run(s, act('search', { description: 'the well' }))[0];
  assert.ok(!again.reveal || again.reveal !== found.reveal);
});

test('combat: attacking a villager has witnesses, reputation and memory consequences', () => {
  const s = game();
  const r = run(s, act('attack', { npc: 'tobin' }))[0];
  assert.ok(['attack', 'defeated'].includes(r.code));
  assert.ok(s.npcs.tobin.attitude <= -40);
  assert.ok(s.player.reputation.criminal > 0);
  assert.ok(s.memories.some((m) => m.npc === 'hessa' && /attack/.test(m.text)));
});

test('combat: the player can lose, and defeat has a cost', () => {
  const s = game(); s.player.hp = 1; s.player.gold = 40; s.player.location = 'corvane_gate'; s.npcs.brannoc.override = 'corvane_gate';
  s.player.stats.dex = 3;
  let r;
  for (let i = 0; i < 20; i++) { r = run(s, act('attack', { npc: 'brannoc' }))[0]; if (r.code === 'defeated' || !s.npcs.brannoc.alive) break; s.player.hp = 1; }
  assert.equal(r.code, 'defeated');
  assert.equal(s.player.location, 'chapel_ashen');
  assert.equal(s.player.gold, 20);
  assert.ok(s.events.some((e) => e.type === 'defeated'));
});

test('impossible free actions never succeed; the engine owns the roll', () => {
  const s = game();
  const r = run(s, act('free', { description: 'fly to the moon', difficulty: 'impossible' }))[0];
  assert.equal(r.code, 'free_impossible'); assert.equal(r.ok, false);
  const t = run(s, act('free', { description: 'hum a tune', difficulty: 'trivial' }))[0];
  assert.equal(t.code, 'free'); assert.ok(t.check && typeof t.check.total === 'number');
});

test('quest: bringing Lio to Tobin completes find_lio and pays the reward', () => {
  const s = game();
  run(s, act('talk', { npc: 'tobin', topic: 'Lio' }));
  s.npcs.lio.captive = false; s.player.companions.push('lio');
  const gold = s.player.gold;
  const turn = applyActions(s, [act('talk', { npc: 'tobin' })]);
  assert.equal(s.player.flags.lio_returned, true);
  assert.equal(s.player.quests.find_lio.status, 'done');
  assert.ok(s.player.gold > gold);
  assert.ok(turn.quests.some((q) => q.quest === 'find_lio'));
});

test('a broken resolver cannot crash a turn', () => {
  const s = game();
  const r = run(s, act('give', { npc: { bad: true }, item: 42 }))[0];
  assert.equal(typeof r.code, 'string');
});
