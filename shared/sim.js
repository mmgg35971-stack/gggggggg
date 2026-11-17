// World Simulation + Autonomous NPC routines + Event Engine.
// Runs whenever in-world time advances (player actions) and, coarsely, for the
// time the player was away (catchUp). Events are causal: each one is triggered
// by world conditions and changes those conditions in turn.
import { NPCS, LOCATIONS } from './world.js';
import { rand, roll, pick, clamp, timeInfo, DAY_MIN } from './state.js';
import { recordEvent, addMemory } from './memory.js';

// ------------------------------------------------------------ NPC routines
export function scheduledLocation(npcId, minutes) {
  const def = NPCS[npcId];
  const { hour, day } = timeInfo(minutes);
  const parity = day % 2 === 1 ? 'odd' : 'even';
  for (const s of def.schedule) {
    if (s.days && s.days !== parity) continue;
    if (hour >= s.from && hour < s.to) return s.loc;
  }
  return def.schedule[def.schedule.length - 1].loc;
}

/** Place every NPC according to routine, unless the story has overridden them. */
export function placeNpcs(state) {
  for (const [id, st] of Object.entries(state.npcs)) {
    if (!st.alive) { st.location = null; continue; }
    if (st.override) { st.location = st.override; continue; }
    st.location = scheduledLocation(id, state.time);
  }
}

// ------------------------------------------------------------ weather
const WEATHER_BY_SEASON = {
  spring: ['drizzle', 'rain', 'overcast', 'clear', 'fog', 'drizzle'],
  summer: ['clear', 'clear', 'overcast', 'rain', 'storm', 'clear'],
  autumn: ['fog', 'rain', 'overcast', 'drizzle', 'storm', 'clear'],
  winter: ['overcast', 'fog', 'storm', 'clear', 'drizzle', 'overcast']
};
function rollWeather(state, day) {
  const ti = timeInfo((day - 1) * DAY_MIN);
  state.world.weather = pick(state, WEATHER_BY_SEASON[ti.season]);
  state.world.weatherDay = day;
}

// ------------------------------------------------------------ news / rumours
// Rumours about the player travel from their settlement to others with a delay
// that depends on distance and on traders actually travelling the road.
const TRAVEL_HOURS = { 'mirefold>corvane': 10, 'corvane>mirefold': 10, 'fenrats>mirefold': 18, 'fenrats>corvane': 24, 'mirefold>fenrats': 30, 'corvane>fenrats': 30 };
const SETTLEMENTS = ['mirefold', 'corvane'];

export function queueRumour(state, { from, rep, text, delta }) {
  for (const to of SETTLEMENTS) {
    if (to === from || !from) continue;
    const h = TRAVEL_HOURS[`${from}>${to}`] || 20;
    state.world.pendingNews.push({ to, arrive: state.time + h * 60, rep, delta: Math.round(delta * 0.6), text });
  }
}

function deliverNews(state) {
  const due = state.world.pendingNews.filter((n) => n.arrive <= state.time);
  if (!due.length) return;
  state.world.pendingNews = state.world.pendingNews.filter((n) => n.arrive > state.time);
  for (const n of due) {
    if (n.rep === 'local') state.player.reputation.local[n.to] = clamp((state.player.reputation.local[n.to] || 0) + n.delta, -100, 100);
    else state.player.reputation[n.rep] = clamp((state.player.reputation[n.rep] || 0) + n.delta, -100, 100);
    recordEvent(state, { type: 'rumour_arrived', importance: 2, byPlayer: false, location: null, entities: [n.to, 'player'],
      text: { en: `Word reached ${n.to === 'corvane' ? 'Corvane' : 'Mirefold'}: ${n.text.en}`, ar: `وصل الخبر إلى ${n.to === 'corvane' ? 'كورفان' : 'ميرفولد'}: ${n.text.ar}` } });
  }
}

// ------------------------------------------------------------ daily world tick (event engine)
// Each rule: condition -> chance -> effects on conditions -> recorded event.
function dailyTick(state, day) {
  const c = state.world.conditions;
  const fenAlive = state.npcs.rusk?.alive && !state.player.flags.fenrats_broken;
  const out = [];

  // Bandits raid the road when active; the crown patrols when unrest is high.
  if (fenAlive && c.banditActivity > 50 && rand(state) < (c.banditActivity - 40) / 100) {
    c.grainSupply = clamp(c.grainSupply - 12, 0, 100);
    c.roadSafety = clamp(c.roadSafety - 10, 0, 100);
    c.unrest = clamp(c.unrest + 6, 0, 100);
    out.push({ type: 'caravan_raided', importance: 3, entities: ['fenrats', 'south_road'], location: 'south_road', cause: 'banditActivity',
      text: { en: 'A grain cart was robbed on the south road. Fen Rats, people say.', ar: 'سُرقت عربة شعير على الطريق الجنوبي. جرذان المستنقع، كما يقول الناس.' } });
  }
  if (c.unrest > 55 && rand(state) < 0.4) {
    c.banditActivity = clamp(c.banditActivity - 15, 0, 100);
    c.unrest = clamp(c.unrest - 10, 0, 100);
    out.push({ type: 'patrol', importance: 2, entities: ['dravell', 'south_road'], location: 'south_road', cause: 'unrest',
      text: { en: 'Dravell riders patrolled the south road after complaints from the vale.', ar: 'جاب فرسان آل درافيل الطريق الجنوبي بعد شكاوى أهل الوادي.' } });
  }
  // Supply drives prices; scarcity drives unrest.
  if (c.grainSupply < 40) {
    state.world.priceMod.mirefold = clamp(state.world.priceMod.mirefold + 0.08, 0.7, 2);
    c.unrest = clamp(c.unrest + 3, 0, 100);
    if (rand(state) < 0.3) out.push({ type: 'prices_rise', importance: 2, entities: ['mirefold'], location: 'mirefold_square', cause: 'grainSupply',
      text: { en: 'Bread is dearer in Mirefold; the barley carts are not getting through.', ar: 'غلا الخبز في ميرفولد؛ عربات الشعير لا تصل.' } });
  } else {
    state.world.priceMod.mirefold = clamp(state.world.priceMod.mirefold + (1 - state.world.priceMod.mirefold) * 0.2, 0.7, 2);
  }
  // Recovery when the road is safe.
  if (c.roadSafety > 60 || !fenAlive) c.grainSupply = clamp(c.grainSupply + 6, 0, 100);
  if (!fenAlive) { c.banditActivity = clamp(c.banditActivity - 10, 0, 100); c.roadSafety = clamp(c.roadSafety + 8, 0, 100); }
  else c.banditActivity = clamp(c.banditActivity + 2, 0, 100);

  // A caravan arrives in Corvane when the road is safe enough: cheaper goods there.
  if (c.roadSafety > 50 && rand(state) < 0.35) {
    state.world.priceMod.corvane = clamp(state.world.priceMod.corvane - 0.1, 0.7, 2);
    out.push({ type: 'caravan_arrived', importance: 2, entities: ['corvane', 'ledger'], location: 'corvane_market', cause: 'roadSafety',
      text: { en: 'A Ledger caravan reached Corvane market; prices there eased.', ar: 'وصلت قافلة للسجلّ إلى سوق كورفان؛ وانخفضت الأسعار هناك.' } });
  } else state.world.priceMod.corvane = clamp(state.world.priceMod.corvane + (1 - state.world.priceMod.corvane) * 0.2, 0.7, 2);

  // Personal NPC arcs that advance without the player.
  const lioCaptive = state.npcs.lio.alive && state.npcs.lio.captive;
  if (lioCaptive && day >= 25 && !state.player.flags.lio_moved) {
    // after weeks the dig ends and the Rats prepare to leave: Lio's fate worsens
    state.player.flags.lio_moved = true;
    out.push({ type: 'rats_leaving', importance: 3, entities: ['fenrats', 'lio'], location: 'blackfen', cause: 'time',
      text: { en: 'Hunters say the Fen Rats are packing their camp. Whatever they dug for, they found it.', ar: 'يقول الصيّادون إن جرذان المستنقع يحزمون معسكرهم. أيّاً كان ما حفروا من أجله، فقد وجدوه.' } });
  }
  if (lioCaptive && day >= 32 && !state.player.flags.lio_dead) {
    state.npcs.lio.alive = false; state.player.flags.lio_dead = true; state.npcs.rusk.fled = true;
    out.push({ type: 'lio_died', importance: 4, entities: ['lio', 'tobin', 'fenrats'], location: 'blackfen', cause: 'time',
      text: { en: 'Lio\'s body was found in the Blackfen bog. The Fen Rats are gone. Tobin has not spoken since.', ar: 'عُثر على جثة ليو في مستنقع بلاكفن. رحل جرذان المستنقع. ولم يتكلم توبن منذ ذلك الحين.' } });
    addMemory(state, 'tobin', 'Lio died in the bog while I waited for help.', 5, ['lio']);
  }
  if (state.world.conditions.grainSupply < 25 && !state.player.flags.hessa_closed && day > 20 && rand(state) < 0.2) {
    state.player.flags.hessa_closed = true;
    out.push({ type: 'hessa_struggles', importance: 3, entities: ['hessa', 'ledger'], location: 'sunken_lantern', cause: 'grainSupply',
      text: { en: 'Hessa has stopped serving stew; the Ledger\'s men were seen measuring the Lantern\'s rooms.', ar: 'توقفت هيسا عن تقديم الحساء؛ وشوهد رجال السجلّ يقيسون غرف الفانوس.' } });
  }

  for (const e of out) recordEvent(state, { ...e, byPlayer: false });
  return out;
}

/** Advance the world by `minutes`, ticking days and routines. Returns events. */
export function advanceTime(state, minutes) {
  const events = [];
  const start = state.time;
  state.time += Math.max(0, Math.round(minutes));
  // needs
  const hours = (state.time - start) / 60;
  const p = state.player;
  p.hunger = clamp(p.hunger + hours * 3, 0, 100);
  p.fatigue = clamp(p.fatigue + hours * 2.5, 0, 100);
  p.stamina = clamp(p.stamina + hours * 10, 0, 100);
  if (p.hunger >= 95 && hours >= 1) p.hp = Math.max(1, p.hp - Math.floor(hours / 2) - 1);
  // days
  const startDay = timeInfo(start).day; const endDay = timeInfo(state.time).day;
  for (let d = Math.max(startDay + 1, state.world.lastDailyTick + 1); d <= endDay; d++) {
    rollWeather(state, d);
    events.push(...dailyTick(state, d));
    state.world.lastDailyTick = d;
  }
  if (p.lodging && state.time > p.lodging.until) p.lodging = null;
  deliverNews(state);
  placeNpcs(state);
  return events;
}

/**
 * Offline progression: when the player returns after real time away, the world
 * moves on. 1 real hour = 1 in-world hour, capped at 7 days, simulated in
 * coarse daily steps (no per-minute detail). Returns the events that happened.
 */
export function catchUp(state, nowMs = Date.now()) {
  const awayH = Math.floor((nowMs - (state.lastPlayedReal || nowMs)) / 3600000);
  state.lastPlayedReal = nowMs;
  if (awayH < 1) return { hours: 0, events: [] };
  const hours = Math.min(awayH, 24 * 7);
  // the player's character rests in place; needs only partially accrue
  const p = state.player; const before = { hunger: p.hunger, fatigue: p.fatigue };
  const events = advanceTime(state, hours * 60);
  p.hunger = clamp(before.hunger + Math.min(30, hours), 0, 100);
  p.fatigue = clamp(before.fatigue - hours * 2, 0, 100);
  return { hours, events };
}

export { roll };
