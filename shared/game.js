// Turn orchestrator: player text -> intent (AI or offline) -> engine ->
// narration (AI or offline) -> validated memory updates -> transcript.
// `ai` is an optional adapter { interpret(payload), narrate(payload) } that
// talks to the backend. If it is missing or fails, the game keeps working
// offline with the deterministic parser and narrator.
import { LOCATIONS, NPCS, ITEMS } from './world.js';
import { npcsAt, L, attitudeBand, clamp, visibleExits } from './state.js';
import { parseIntent, detectLang } from './parser.js';
import { applyActions } from './engine.js';
import { sanitizeInterpretation, sanitizeNarration } from './schemas.js';
import { buildContext, pushChat, addMemory, updateSummary } from './memory.js';
import { narrateOffline, systemMessages } from './narrator.js';
import { placeNpcs } from './sim.js';

export function interpretContext(state) {
  const p = state.player; const loc = LOCATIONS[p.location];
  const present = npcsAt(state, p.location);
  return {
    location: p.location,
    exits: visibleExits(state, p.location).map((e) => e.to),
    known_locations: p.known.locations,
    present_npcs: present.map((id) => ({ id, name: NPCS[id].name, role: NPCS[id].role.en })),
    inventory: p.inventory.map((i) => i.id),
    for_sale_here: [...(loc.services?.sells || []), ...present.flatMap((n) => NPCS[n].sells || [])],
    gold: p.gold,
    in_combat: Object.entries(state.npcs).filter(([, n]) => n.inCombat && n.alive && n.location === p.location).map(([id]) => id),
    recent: state.chat.slice(-4).map((m) => ({ role: m.role, speaker: m.speaker || null, text: String(m.text).slice(0, 200) }))
  };
}

function autoNote(turn) {
  const keep = turn.results.filter((r) => r.ok && ['move', 'talk', 'social', 'search', 'attack', 'give', 'sell', 'buy', 'free'].includes(r.code) || r.quest || r.code === 'defeated');
  return keep.map((r) => r.fact.en).join(' ').slice(0, 280);
}

export async function takeTurn(state, text, { ai = null, lang: forcedLang } = {}) {
  const clean = String(text || '').slice(0, 600).trim();
  if (!clean) return { messages: [], mode: 'none' };
  const lang = forcedLang || detectLang(clean) || state.lang;
  state.lang = lang;
  placeNpcs(state);
  pushChat(state, { role: 'player', text: clean });
  let mode = ai ? 'ai' : 'offline';
  let warning = null;

  // 1) understand the player's intent
  let intent;
  if (ai) {
    try {
      const raw = await ai.interpret({ text: clean, lang, context: interpretContext(state) });
      intent = sanitizeInterpretation(raw);
    } catch (err) {
      warning = 'interpret_failed'; mode = 'offline';
      intent = parseIntent(state, clean);
    }
  } else intent = parseIntent(state, clean);

  // 2) engine validates and applies
  const turn = applyActions(state, intent.actions);

  // 3) narration
  let messages;
  if (mode === 'ai') {
    const present = npcsAt(state, state.player.location);
    const involved = [...new Set([...present, ...turn.results.flatMap((r) => r.npcs || [])])].filter((id) => state.npcs[id]?.alive);
    const engineAttitude = {};
    for (const r of turn.results) for (const [n, d] of Object.entries(r.attitude || {})) engineAttitude[n] = (engineAttitude[n] || 0) + d;
    const packet = {
      lang,
      player_input: clean,
      context: buildContext(state, { query: clean, presentNpcs: involved, lang }),
      results: turn.results.map((r) => ({
        action: r.type, code: r.code, success: r.ok, fact: L(r.fact, lang),
        npc: r.npc || null, npc_line_to_convey: r.line ? L(r.line.text, lang) : null,
        discovery: r.reveal ? L(r.reveal, lang) : null,
        check: r.check ? { roll: r.check.d20, total: r.check.total, dc: r.check.dc, success: r.check.success } : null
      })),
      world_events: turn.worldEvents.map((e) => L(e.text, lang)),
      allowed_npcs: involved
    };
    try {
      const raw = await ai.narrate(packet);
      const nar = sanitizeNarration(raw, { allowedNpcs: involved, engineAttitude });
      messages = [];
      if (nar.narration) messages.push({ role: 'narrator', text: nar.narration });
      for (const d of nar.dialogue) messages.push({ role: 'npc', speaker: d.npc, text: d.line });
      // engine-provided lines the AI failed to voice are still delivered (no lost info)
      for (const r of turn.results) if (r.line && !nar.dialogue.some((d) => d.npc === r.line.npc)) messages.push({ role: 'npc', speaker: r.line.npc, text: L(r.line.text, lang) });
      for (const r of turn.results) if (r.reveal) messages.push({ role: 'discovery', text: L(r.reveal, lang) });
      messages.push(...systemMessages(state, turn, lang));
      for (const m of nar.memories) {
        addMemory(state, m.npc, m.text, m.importance, ['ai']);
        if (m.attitude_delta) state.npcs[m.npc].attitude = clamp(state.npcs[m.npc].attitude + m.attitude_delta, -100, 100);
      }
      updateSummary(state, nar.summary_note || autoNote(turn));
    } catch (err) {
      warning = 'narrate_failed'; mode = 'offline';
      messages = narrateOffline(state, turn, lang);
      updateSummary(state, autoNote(turn));
    }
  } else {
    messages = narrateOffline(state, turn, lang);
    updateSummary(state, autoNote(turn));
  }
  for (const m of messages) pushChat(state, m);
  state.lastPlayedReal = Date.now();
  return { messages, mode, warning, intent, turn: { results: turn.results.map((r) => ({ type: r.type, code: r.code, ok: r.ok })) } };
}

export { attitudeBand, ITEMS };
