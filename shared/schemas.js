// Structured contract between the AI layer and the game engine.
// The AI may only PROPOSE actions and narration in these shapes; the engine
// validates every field against the game state before anything is applied.
import { SKILL_KEYS } from './world.js';

export const ACTION_TYPES = [
  'look',      // describe surroundings / examine something
  'move',      // go to a location (destination)
  'talk',      // speak to an NPC (npc, topic, utterance)
  'social',    // persuade/intimidate/deceive/charm/bribe an NPC (npc, approach, goal, qty for bribe)
  'buy', 'sell',
  'give',      // give item or gold to NPC
  'take',      // pick up an item lying here
  'eat',       // eat/drink from inventory (item) or order food (buys)
  'rest',      // rest/sleep (hours); rent_room handled via 'rent'
  'rent',      // rent a room where available
  'wait',      // pass time (hours)
  'search',    // search location or a feature for hidden things
  'attack',    // attack an NPC
  'equip',     // equip an item
  'use',       // use an item (herbs, bandage, torch)
  'work',      // do paid work available here
  'hunt',      // hunt/forage in the wilds
  'free',      // anything else: engine resolves with a skill check (skill, difficulty)
  'meta'       // out-of-character: inventory/status/help (no time passes)
];
export const SOCIAL_APPROACHES = ['persuade', 'intimidate', 'deceive', 'charm', 'bribe'];
export const DIFFICULTIES = { trivial: 5, easy: 9, medium: 13, hard: 17, very_hard: 21, impossible: 99 };

const nstr = { type: ['string', 'null'] };
const nint = { type: ['integer', 'null'] };

/** JSON schema the AI interpreter must return (Structured Outputs). */
export const INTERPRET_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['language', 'actions', 'in_character'],
  properties: {
    language: { type: 'string', enum: ['ar', 'en'] },
    in_character: { type: 'boolean' },
    actions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['type', 'npc', 'item', 'qty', 'destination', 'approach', 'topic', 'utterance', 'skill', 'difficulty', 'hours', 'description'],
        properties: {
          type: { type: 'string', enum: ACTION_TYPES },
          npc: nstr, item: nstr, qty: nint, destination: nstr,
          approach: nstr, // one of SOCIAL_APPROACHES, validated in sanitizeInterpretation
          topic: nstr, utterance: nstr,
          skill: nstr, // one of SKILL_KEYS
          difficulty: nstr, // one of DIFFICULTIES keys
          hours: nint, description: nstr
        }
      }
    }
  }
};

/** JSON schema the AI narrator must return. */
export const NARRATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['narration', 'dialogue', 'memories', 'summary_note'],
  properties: {
    narration: { type: 'string' },
    dialogue: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, required: ['npc', 'line'], properties: { npc: { type: 'string' }, line: { type: 'string' } } }
    },
    memories: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false, required: ['npc', 'text', 'importance', 'attitude_delta'],
        properties: { npc: { type: 'string' }, text: { type: 'string' }, importance: { type: 'integer' }, attitude_delta: { type: 'integer' } }
      }
    },
    summary_note: { type: 'string' }
  }
};

const s = (v, max = 400) => (typeof v === 'string' ? v.slice(0, max) : null);

/** Normalise and sanity-check interpreter output. Unknown fields are dropped. */
export function sanitizeInterpretation(raw) {
  const out = { language: raw?.language === 'en' ? 'en' : 'ar', in_character: raw?.in_character !== false, actions: [] };
  const acts = Array.isArray(raw?.actions) ? raw.actions.slice(0, 4) : [];
  for (const a of acts) {
    if (!a || !ACTION_TYPES.includes(a.type)) continue;
    out.actions.push({
      type: a.type,
      npc: s(a.npc, 40), item: s(a.item, 40),
      qty: Number.isInteger(a.qty) ? Math.max(1, Math.min(99, a.qty)) : null,
      destination: s(a.destination, 40),
      approach: SOCIAL_APPROACHES.includes(a.approach) ? a.approach : null,
      topic: s(a.topic, 80), utterance: s(a.utterance, 400),
      skill: SKILL_KEYS.includes(a.skill) ? a.skill : null,
      difficulty: a.difficulty in DIFFICULTIES ? a.difficulty : null,
      hours: Number.isInteger(a.hours) ? Math.max(1, Math.min(72, a.hours)) : null,
      description: s(a.description, 300)
    });
  }
  if (!out.actions.length) out.actions.push({ type: 'look', npc: null, item: null, qty: null, destination: null, approach: null, topic: null, utterance: null, skill: null, difficulty: null, hours: null, description: null });
  return out;
}

/**
 * Validate narrator output against what the engine allows.
 * allowedNpcs: NPC ids actually present this turn. Attitude deltas are clamped
 * and must agree in sign with the engine's own verdict when one exists.
 */
export function sanitizeNarration(raw, { allowedNpcs = [], engineAttitude = {} } = {}) {
  const narration = s(raw?.narration, 4000) || '';
  const dialogue = (Array.isArray(raw?.dialogue) ? raw.dialogue : [])
    .filter((d) => d && allowedNpcs.includes(d.npc) && typeof d.line === 'string')
    .slice(0, 6).map((d) => ({ npc: d.npc, line: d.line.slice(0, 800) }));
  const memories = (Array.isArray(raw?.memories) ? raw.memories : [])
    .filter((m) => m && allowedNpcs.includes(m.npc) && typeof m.text === 'string')
    .slice(0, 4)
    .map((m) => {
      let delta = Number.isInteger(m.attitude_delta) ? Math.max(-5, Math.min(5, m.attitude_delta)) : 0;
      const eng = engineAttitude[m.npc];
      if (eng !== undefined && Math.sign(eng) !== 0 && Math.sign(delta) !== Math.sign(eng)) delta = 0; // AI cannot contradict engine
      return { npc: m.npc, text: m.text.slice(0, 240), importance: Math.max(1, Math.min(5, m.importance | 0 || 1)), attitude_delta: delta };
    });
  return { narration, dialogue, memories, summary_note: s(raw?.summary_note, 300) || '' };
}
