// Game State Manager: creates and inspects the structured game state.
// The state is a plain JSON object so it can be saved anywhere (IndexedDB on
// the phone, a file or a database on a server) and diffed in tests.
import { NPCS, LOCATIONS, ITEMS, BACKGROUNDS, STAT_KEYS, SKILL_KEYS, START_LOCATION, FACTIONS, WORLD_META } from './world.js';

export const STATE_VERSION = 1;
export const DAY_MIN = 24 * 60;
export const START_MINUTES = 7 * 60; // day 1, 07:00

// ------------------------------------------------------------ deterministic RNG
// mulberry32. The seed lives in state.rng so a save replays identically.
export function rand(state) {
  let t = (state.rng = (state.rng + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
export const roll = (state, sides) => 1 + Math.floor(rand(state) * sides);
export const pick = (state, arr) => arr[Math.floor(rand(state) * arr.length)];
export const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

// ------------------------------------------------------------ time
export function timeInfo(minutes) {
  const day = Math.floor(minutes / DAY_MIN) + 1;
  const minOfDay = minutes % DAY_MIN;
  const hour = Math.floor(minOfDay / 60);
  const minute = minOfDay % 60;
  const seasonIdx = Math.floor(((day - 1) % 360) / 90); // 90-day seasons, starts in spring
  const year = WORLD_META.startYear + Math.floor((day - 1) / 360);
  const seasons = ['spring', 'summer', 'autumn', 'winter'];
  let part = 'night';
  if (hour >= 5 && hour < 8) part = 'dawn';
  else if (hour >= 8 && hour < 12) part = 'morning';
  else if (hour >= 12 && hour < 17) part = 'afternoon';
  else if (hour >= 17 && hour < 21) part = 'evening';
  return { day, hour, minute, season: seasons[seasonIdx], year, part, isNight: hour < 6 || hour >= 21 };
}

export const TIME_WORDS = {
  dawn: { en: 'dawn', ar: 'الفجر' }, morning: { en: 'morning', ar: 'الصباح' }, afternoon: { en: 'afternoon', ar: 'العصر' },
  evening: { en: 'evening', ar: 'المساء' }, night: { en: 'night', ar: 'الليل' },
  spring: { en: 'spring', ar: 'الربيع' }, summer: { en: 'summer', ar: 'الصيف' }, autumn: { en: 'autumn', ar: 'الخريف' }, winter: { en: 'winter', ar: 'الشتاء' }
};
export const WEATHER = {
  clear: { en: 'clear skies', ar: 'سماء صافية' }, overcast: { en: 'low grey cloud', ar: 'غيوم رمادية منخفضة' }, drizzle: { en: 'a thin cold drizzle', ar: 'رذاذ بارد خفيف' },
  rain: { en: 'steady rain', ar: 'مطر متواصل' }, fog: { en: 'thick fog', ar: 'ضباب كثيف' }, storm: { en: 'a howling storm', ar: 'عاصفة عاتية' }
};

// ------------------------------------------------------------ stats
export const mod = (v) => Math.floor((v - 10) / 2);
export const POINT_BUY = { base: 10, points: 6, min: 7, max: 15 };

/** Validate a point-buy stat block coming from the client. Returns {ok, error}. */
export function validatePointBuy(stats) {
  let spent = 0;
  for (const k of STAT_KEYS) {
    const v = stats?.[k];
    if (!Number.isInteger(v) || v < POINT_BUY.min || v > POINT_BUY.max) return { ok: false, error: `bad_stat:${k}` };
    spent += v - POINT_BUY.base;
  }
  if (spent > POINT_BUY.points) return { ok: false, error: 'too_many_points' };
  return { ok: true };
}

export function xpForSkillLevel(lvl) { return 20 * (lvl + 1) * (lvl + 1); }
export function xpForCharLevel(lvl) { return 100 * lvl * lvl; }

// ------------------------------------------------------------ new game
export function newGame({ name, gender = 'unspecified', background = 'farmhand', stats, lang = 'ar', seed } = {}) {
  const bg = BACKGROUNDS[background];
  if (!bg) throw new Error('unknown_background');
  const cleanName = String(name || '').replace(/[<>\n\r]/g, '').trim().slice(0, 32);
  if (!cleanName) throw new Error('name_required');
  const base = stats || Object.fromEntries(STAT_KEYS.map((k) => [k, 10]));
  const v = validatePointBuy(base);
  if (!v.ok) throw new Error(v.error);
  const finalStats = { ...base };
  for (const [k, b] of Object.entries(bg.stats)) finalStats[k] += b;
  const skills = Object.fromEntries(SKILL_KEYS.map((k) => [k, { lvl: bg.skills[k] || 0, xp: 0 }]));
  const maxHp = 10 + mod(finalStats.con) * 2 + 4;

  const npcs = {};
  for (const [id, def] of Object.entries(NPCS)) {
    npcs[id] = { location: null, attitude: def.attitude, trust: 0, met: false, alive: true, hp: def.hp, gold: def.gold, captive: !!def.captive, fled: false, knownFacts: [] };
  }

  const state = {
    version: STATE_VERSION,
    id: 'save_' + Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36),
    createdAt: Date.now(),
    lastPlayedReal: Date.now(),
    rng: (seed ?? Math.floor(Math.random() * 2 ** 31)) >>> 0,
    lang,
    time: START_MINUTES,
    turn: 0,
    player: {
      name: cleanName, gender, background,
      stats: finalStats, skills,
      xp: 0, level: 1,
      hp: maxHp, maxHp, stamina: 100, hunger: 20, fatigue: 10,
      gold: bg.gold,
      inventory: bg.items.map(([id, qty]) => ({ id, qty })),
      equipped: { weapon: bg.equip?.weapon || null, armor: bg.equip?.armor || null, shield: null },
      location: START_LOCATION,
      known: { locations: [START_LOCATION, 'mirefold_square'], npcs: [], facts: [] },
      flags: {},
      reputation: { personal: {}, local: { mirefold: 0, corvane: 0 }, political: 0, military: 0, commercial: 0, criminal: 0, ...(bg.rep ? { criminal: bg.rep.criminal || 0 } : {}) },
      lodging: null, // { location, until }
      companions: [],
      quests: {} // id -> { status: 'active'|'done'|'failed', since, notes:[] }
    },
    npcs,
    world: {
      weather: 'drizzle',
      weatherDay: 1,
      conditions: { banditActivity: 65, grainSupply: 60, unrest: 30, roadSafety: 45 },
      priceMod: { mirefold: 1, corvane: 1 },
      factions: Object.fromEntries(Object.entries(FACTIONS).map(([id, f]) => [id, { power: f.power, playerStanding: 0 }])),
      lootTaken: {}, // `${loc}:${item}` -> true
      pendingNews: [], // rumours travelling between settlements
      lastDailyTick: 1
    },
    chat: [],      // UI transcript (capped)
    events: [],    // structured event log (memory source)
    memories: [],  // NPC memories about the player
    chronicle: [], // living history: important events that became part of the world
    summary: ''    // rolling summary of older turns (memory summarisation)
  };
  if (bg.rep?.local) state.player.reputation.local.mirefold += bg.rep.local;
  return state;
}

// ------------------------------------------------------------ inspectors
export const L = (obj, lang) => (obj ? obj[lang] ?? obj.en : '');
export const itemName = (id, lang) => L(ITEMS[id]?.name, lang) || id;
export const locName = (id, lang) => L(LOCATIONS[id]?.name, lang) || id;
export const npcName = (id, lang) => L(NPCS[id]?.name, lang) || id;

export function invCount(state, id) {
  return state.player.inventory.find((e) => e.id === id)?.qty || 0;
}
export function addItem(state, id, qty = 1) {
  const e = state.player.inventory.find((x) => x.id === id);
  if (e) e.qty += qty; else state.player.inventory.push({ id, qty });
}
export function removeItem(state, id, qty = 1) {
  const e = state.player.inventory.find((x) => x.id === id);
  if (!e || e.qty < qty) return false;
  e.qty -= qty;
  if (e.qty <= 0) {
    state.player.inventory = state.player.inventory.filter((x) => x !== e);
    for (const slot of ['weapon', 'armor', 'shield']) if (state.player.equipped[slot] === id && invCount(state, id) === 0) state.player.equipped[slot] = null;
  }
  return true;
}

export function npcsAt(state, loc) {
  return Object.entries(state.npcs).filter(([, n]) => n.location === loc && n.alive && !n.fled).map(([id]) => id);
}

export function attitudeBand(att) {
  if (att <= -40) return 'hostile';
  if (att < -5) return 'cold';
  if (att < 30) return 'neutral';
  return 'warm';
}

export function visibleExits(state, loc) {
  return (LOCATIONS[loc]?.exits || []).filter((e) => !e.hidden || state.player.flags[e.hidden]);
}

export function armorValue(state) {
  const eq = state.player.equipped;
  return (ITEMS[eq.armor]?.armor || 0) + (ITEMS[eq.shield]?.armor || 0);
}

export function settlementOf(loc) { return LOCATIONS[loc]?.settlement || null; }
