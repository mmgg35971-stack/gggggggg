// Memory Manager: event history, NPC memories, living history (chronicle),
// rolling summarisation and context retrieval for the AI Game Master.
//
// Retrieval is lexical + entity based (tokens, shared entity tags, recency,
// importance). It works offline on a phone. An embedding-based retriever can
// replace `scoreText` later without changing callers.
import { LOCATIONS, NPCS } from './world.js';
import { timeInfo, L, npcName, locName, attitudeBand } from './state.js';

const MAX_EVENTS = 600;
const MAX_MEMORIES = 400;
const MAX_CHAT = 300;

export function tokenize(text) {
  return String(text || '').toLowerCase()
    .replace(/[ً-ْـ]/g, '') // strip Arabic diacritics & tatweel
    .replace(/[إأآا]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه')
    .split(/[^\p{L}\p{N}]+/u).filter((w) => w.length > 2);
}

/** Record a structured event. importance 1-5; >=4 also enters the chronicle. */
export function recordEvent(state, ev) {
  const e = {
    id: 'ev' + (state.events.length + 1) + '_' + state.time,
    t: state.time,
    type: ev.type,
    text: ev.text, // {en, ar}
    entities: ev.entities || [],
    location: ev.location ?? state.player.location,
    importance: ev.importance || 1,
    witnesses: ev.witnesses || [],
    byPlayer: ev.byPlayer !== false,
    cause: ev.cause || null
  };
  state.events.push(e);
  if (state.events.length > MAX_EVENTS) state.events.splice(0, state.events.length - MAX_EVENTS);
  if (e.importance >= 4) addChronicle(state, e);
  return e;
}

/** Living history: important events become dated entries of the world's history. */
export function addChronicle(state, e) {
  const ti = timeInfo(e.t);
  state.chronicle.push({ t: e.t, day: ti.day, year: ti.year, season: ti.season, text: e.text, entities: e.entities, byPlayer: e.byPlayer, type: e.type });
}

export function addMemory(state, npc, text, importance = 2, tags = []) {
  state.memories.push({ npc, t: state.time, text: String(text).slice(0, 240), importance, tags });
  // forgetting curve: drop lowest-value old memories when over budget, never importance>=4
  if (state.memories.length > MAX_MEMORIES) {
    const scored = state.memories.map((m, i) => ({ i, v: m.importance * 10 - (state.time - m.t) / 1440 }));
    const removable = scored.filter((x) => state.memories[x.i].importance < 4).sort((a, b) => a.v - b.v);
    const drop = new Set(removable.slice(0, state.memories.length - MAX_MEMORIES).map((x) => x.i));
    state.memories = state.memories.filter((_, i) => !drop.has(i));
  }
}

export function pushChat(state, msg) {
  state.chat.push({ ...msg, t: state.time, turn: state.turn });
  if (state.chat.length > MAX_CHAT) {
    const removed = state.chat.splice(0, state.chat.length - MAX_CHAT);
    // fold removed lines into the summary so nothing important is silently lost
    const notes = removed.filter((m) => m.role === 'event').map((m) => m.text).join(' ');
    if (notes) state.summary = (state.summary + ' ' + notes).slice(-2000);
  }
}

function scoreText(queryTokens, text) {
  if (!queryTokens.size) return 0;
  const toks = tokenize(text);
  let hit = 0;
  for (const t of toks) if (queryTokens.has(t)) hit++;
  return hit / Math.sqrt(toks.length + 1);
}

/** Retrieve the most relevant past events for this turn. */
export function retrieveEvents(state, { query = '', entities = [], k = 6 }) {
  const q = new Set(tokenize(query));
  const ents = new Set(entities);
  const now = state.time;
  return state.events
    .map((e) => {
      const ageDays = (now - e.t) / 1440;
      const ent = e.entities.filter((x) => ents.has(x)).length;
      const lex = scoreText(q, e.text.en + ' ' + e.text.ar);
      const score = ent * 2 + lex * 3 + e.importance * 0.6 + Math.max(0, 2 - ageDays * 0.5);
      return { e, score };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, k)
    .map((x) => x.e);
}

export function memoriesOf(state, npc, k = 5) {
  return state.memories.filter((m) => m.npc === npc)
    .sort((a, b) => (b.importance * 3 + b.t / 1440) - (a.importance * 3 + a.t / 1440))
    .slice(0, k);
}

/**
 * Build the compact context packet for the AI. This is what keeps prompts
 * small: we never send the whole transcript, only state + retrieved memory.
 */
export function buildContext(state, { query = '', presentNpcs = [], lang }) {
  lang = lang || state.lang;
  const p = state.player;
  const loc = LOCATIONS[p.location];
  const ti = timeInfo(state.time);
  const entities = [p.location, ...presentNpcs];
  return {
    language: lang,
    time: { day: ti.day, hour: ti.hour, part: ti.part, season: ti.season, weather: state.world.weather },
    location: { id: p.location, name: L(loc.name, lang), description: L(loc.desc, lang), type: loc.type },
    exits: (loc.exits || []).filter((e) => !e.hidden || p.flags[e.hidden]).map((e) => ({ id: e.to, name: locName(e.to, lang), minutes: e.minutes })),
    player: {
      name: p.name, gender: p.gender, background: p.background, level: p.level, hp: p.hp, maxHp: p.maxHp, gold: p.gold, hunger: p.hunger, fatigue: p.fatigue,
      stats: p.stats,
      top_skills: Object.entries(p.skills).filter(([, v]) => v.lvl > 0).map(([k, v]) => `${k}:${v.lvl}`),
      inventory: p.inventory.map((i) => `${i.id}x${i.qty}`),
      equipped: p.equipped,
      reputation: { local: p.reputation.local, criminal: p.reputation.criminal, military: p.reputation.military, commercial: p.reputation.commercial },
      known_facts: p.known.facts.slice(-20)
    },
    present_npcs: presentNpcs.map((id) => {
      const def = NPCS[id]; const st = state.npcs[id];
      return {
        id, name: L(def.name, lang), gender: def.female ? 'female' : 'male', role: L(def.role, lang), age: def.age, persona: L(def.persona, lang), goals: L(def.goals, lang),
        attitude: st.attitude, attitude_band: attitudeBand(st.attitude), met_before: st.met, captive: st.captive,
        memories_of_player: memoriesOf(state, id).map((m) => m.text)
      };
    }),
    relevant_events: retrieveEvents(state, { query, entities }).map((e) => ({ day: timeInfo(e.t).day, text: L(e.text, lang) })),
    story_so_far: state.summary.slice(-1200),
    recent_turns: state.chat.slice(-8).map((m) => ({ role: m.role, speaker: m.speaker || null, text: String(m.text).slice(0, 300) }))
  };
}

/** Called each turn with the narrator's note; keeps a bounded rolling summary. */
export function updateSummary(state, note) {
  if (!note) return;
  const ti = timeInfo(state.time);
  state.summary = (state.summary + ` [D${ti.day}] ` + note).slice(-2400);
}

export { npcName };
