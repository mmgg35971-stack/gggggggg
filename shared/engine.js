// Game Engine: validates proposed actions against the state and applies their
// results deterministically (seeded RNG). The AI never edits state directly;
// it proposes actions (interpreter) and words (narrator). Everything that
// changes the world happens here.
//
// Each resolver returns a Result:
//   { code, ok, minutes, fact:{en,ar}, line?:{npc, text:{en,ar}}, reveal?:{en,ar},
//     attitude?:{npcId: delta}, npcs?:[ids involved] }
import { LOCATIONS, NPCS, ITEMS, QUESTS, SKILL_STAT } from './world.js';
import {
  rand, roll, clamp, mod, L, itemName, locName, npcName, invCount, addItem, removeItem, npcsAt, attitudeBand,
  visibleExits, armorValue, settlementOf, xpForSkillLevel, xpForCharLevel, timeInfo
} from './state.js';
import { DIFFICULTIES } from './schemas.js';
import { recordEvent, addMemory, tokenize } from './memory.js';
import { advanceTime, placeNpcs, queueRumour } from './sim.js';

const T = (en, ar) => ({ en, ar });

// ------------------------------------------------------------ entity resolution
function norm(s) { return tokenize(s).join(' '); }
function matchAliases(text, aliases) {
  const n = ' ' + norm(text) + ' ';
  let best = 0;
  for (const a of aliases) { const na = norm(a); if (na && n.includes(' ' + na + ' ')) best = Math.max(best, na.length); }
  return best;
}
export function resolveNpc(state, ref, { presentOnly = true } = {}) {
  if (!ref) return null;
  if (NPCS[ref]) return !presentOnly || npcsAt(state, state.player.location).includes(ref) ? ref : null;
  const pool = presentOnly ? npcsAt(state, state.player.location) : Object.keys(NPCS);
  let best = null, bestLen = 0;
  for (const id of pool) {
    const d = NPCS[id];
    const len = matchAliases(ref, [...d.aliases, d.name.en, d.name.ar]);
    if (len > bestLen) { best = id; bestLen = len; }
  }
  return best;
}
export function resolveItem(ref, candidates = Object.keys(ITEMS)) {
  if (!ref) return null;
  if (ITEMS[ref] && candidates.includes(ref)) return ref;
  let best = null, bestLen = 0;
  for (const id of candidates) {
    const d = ITEMS[id]; if (!d) continue;
    const len = matchAliases(ref, [...d.aliases, d.name.en, d.name.ar, id.replace(/_/g, ' ')]);
    if (len > bestLen) { best = id; bestLen = len; }
  }
  return best;
}
export function resolveLocation(ref) {
  if (!ref) return null;
  if (LOCATIONS[ref]) return ref;
  let best = null, bestLen = 0;
  for (const [id, d] of Object.entries(LOCATIONS)) {
    const len = matchAliases(ref, [...d.aliases, d.name.en, d.name.ar]);
    if (len > bestLen) { best = id; bestLen = len; }
  }
  return best;
}

// ------------------------------------------------------------ checks & progression
export function skillCheck(state, skill, dc, { stat, bonus = 0 } = {}) {
  const p = state.player;
  const st = stat || SKILL_STAT[skill] || 'luck';
  const d20 = roll(state, 20);
  const luckNudge = rand(state) < (p.stats.luck - 10) * 0.01 ? 1 : 0;
  const fatiguePen = p.fatigue > 80 ? -2 : 0;
  const hungerPen = p.hunger > 85 ? -2 : 0;
  const total = d20 + mod(p.stats[st]) + (skill ? p.skills[skill]?.lvl || 0 : 0) + bonus + luckNudge + fatiguePen + hungerPen;
  const success = d20 === 20 || (d20 !== 1 && total >= dc);
  if (skill) gainSkillXp(state, skill, success ? 8 + Math.floor(dc / 2) : 3);
  return { d20, total, dc, success, crit: d20 === 20, fumble: d20 === 1, skill, stat: st };
}

export function gainSkillXp(state, skill, amount) {
  const s = state.player.skills[skill]; if (!s) return;
  s.xp += amount;
  while (s.lvl < 10 && s.xp >= xpForSkillLevel(s.lvl)) { s.xp -= xpForSkillLevel(s.lvl); s.lvl++; state._levelUps = [...(state._levelUps || []), { skill, lvl: s.lvl }]; }
}
export function gainXp(state, amount) {
  const p = state.player; p.xp += amount;
  while (p.xp >= xpForCharLevel(p.level)) {
    p.level++; p.maxHp += 2 + Math.max(0, mod(p.stats.con)); p.hp = p.maxHp;
    state._levelUps = [...(state._levelUps || []), { level: p.level }];
  }
}

function changeAttitude(state, npc, delta, res) {
  const st = state.npcs[npc]; if (!st) return;
  st.attitude = clamp(st.attitude + delta, -100, 100);
  if (res) res.attitude = { ...(res.attitude || {}), [npc]: (res.attitude?.[npc] || 0) + delta };
}

/** Reputation change with witnesses and rumour spread (not everyone knows at once). */
export function changeRep(state, { dim, delta, text, witnessed = true }) {
  const p = state.player;
  const settlement = settlementOf(p.location);
  if (dim === 'local') {
    if (!settlement || settlement === 'fenrats') return;
    if (witnessed) p.reputation.local[settlement] = clamp((p.reputation.local[settlement] || 0) + delta, -100, 100);
    queueRumour(state, { from: settlement, rep: 'local', text, delta });
  } else {
    p.reputation[dim] = clamp((p.reputation[dim] || 0) + (witnessed ? delta : Math.round(delta / 2)), -100, 100);
    if (settlement) queueRumour(state, { from: settlement, rep: dim, text, delta: Math.round(delta / 2) });
  }
}

function learnFact(state, fact) { if (fact && !state.player.known.facts.includes(fact)) state.player.known.facts.push(fact); }

// ------------------------------------------------------------ economy
export function priceOf(state, itemId, { selling = false, npc = null } = {}) {
  const base = ITEMS[itemId]?.price || 0;
  const p = state.player;
  const settlement = settlementOf(p.location) || 'mirefold';
  let m = state.world.priceMod[settlement] || 1;
  if (npc) {
    const band = attitudeBand(state.npcs[npc].attitude);
    m *= band === 'warm' ? 0.9 : band === 'cold' ? 1.15 : band === 'hostile' ? 1.5 : 1;
  }
  m *= 1 - (p.skills.trading.lvl * 0.02) - clamp(p.reputation.commercial, -50, 50) * 0.002;
  if (selling) {
    let s = base * 0.5 / Math.max(0.6, m);
    if (itemId === 'sarith_glass' && npc === 'marda' && p.known.facts.includes('marda_buys_glass')) s = 60;
    return Math.max(1, Math.floor(s));
  }
  return Math.max(1, Math.round(base * m));
}

function sellerHere(state, itemId) {
  const loc = LOCATIONS[state.player.location];
  const present = npcsAt(state, state.player.location);
  if (loc.services?.sells?.includes(itemId)) {
    const s = loc.services.seller;
    if (!s || present.includes(s)) return { npc: s };
  }
  for (const id of present) if (NPCS[id].sells?.includes(itemId)) return { npc: id };
  return null;
}
function buyerHere(state, itemId) {
  const loc = LOCATIONS[state.player.location];
  const present = npcsAt(state, state.player.location);
  const type = ITEMS[itemId]?.type;
  if (itemId === 'sarith_glass' && present.includes('marda')) return { npc: 'marda' };
  if (loc.services?.buys?.includes(type)) {
    const s = loc.services.seller;
    if (!s || present.includes(s)) return { npc: s };
  }
  for (const id of present) if (NPCS[id].buys?.includes(type)) return { npc: id };
  return null;
}

// ------------------------------------------------------------ resolvers
const R = {};

R.meta = (state) => ({ code: 'meta', ok: true, minutes: 0, fact: T('(Status shown in the side panels.)', '(الحالة معروضة في اللوحات الجانبية.)') });

R.look = (state, a) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  const npcRef = a.npc && resolveNpc(state, a.npc);
  if (npcRef) {
    const d = NPCS[npcRef];
    return { code: 'look_npc', ok: true, minutes: 1, npcs: [npcRef], fact: T(`${d.name.en}, ${d.role.en}, about ${d.age}. ${d.persona.en.split('.')[0]}.`, `${d.name.ar}، ${d.role.ar}، في نحو ${d.age} من العمر. ${d.persona.ar.split('.')[0]}.`) };
  }
  const present = npcsAt(state, p.location);
  for (const id of present) { if (!p.known.npcs.includes(id)) p.known.npcs.push(id); }
  const exits = visibleExits(state, p.location);
  const loot = (loc.loot || []).filter((l) => !state.world.lootTaken[`${p.location}:${l.item}`] && lootVisible(state, p.location, l.item));
  const ppl = (lang) => present.map((id) => npcName(id, lang)).join(lang === 'ar' ? '، ' : ', ');
  const ex = (lang) => exits.map((e) => locName(e.to, lang)).join(lang === 'ar' ? '، ' : ', ');
  const items = (lang) => loot.map((l) => itemName(l.item, lang)).join(lang === 'ar' ? '، ' : ', ');
  return {
    code: 'look', ok: true, minutes: 2, npcs: present,
    fact: T(
      `${loc.desc.en}${present.length ? ` Present: ${ppl('en')}.` : ' No one else is here.'}${loot.length ? ` You notice: ${items('en')}.` : ''} Ways on: ${ex('en')}.`,
      `${loc.desc.ar}${present.length ? ` الحاضرون: ${ppl('ar')}.` : ' لا أحد غيرك هنا.'}${loot.length ? ` تلاحظ: ${items('ar')}.` : ''} الطرق من هنا: ${ex('ar')}.`)
  };
};

function lootVisible(state, loc, item) {
  if (loc === 'vael_sarith' && item === 'lio_satchel') return !!state.player.flags.saw_fresh_digging;
  return true;
}

// BFS through known/visible exits for multi-hop travel
function findPath(state, from, to) {
  const q = [[from, 0, []]]; const seen = new Set([from]);
  while (q.length) {
    const [cur, mins, path] = q.shift();
    if (cur === to) return { minutes: mins, path };
    for (const e of visibleExits(state, cur)) {
      if (seen.has(e.to)) continue;
      if (LOCATIONS[e.to].hiddenLocation && !state.player.known.locations.includes(e.to) && !state.player.flags[e.hidden]) continue;
      seen.add(e.to); q.push([e.to, mins + e.minutes, [...path, e.to]]);
    }
  }
  return null;
}

R.move = (state, a) => {
  const p = state.player;
  const dest = resolveLocation(a.destination || a.description || '');
  if (!dest) return { code: 'move_unknown', ok: false, minutes: 0, fact: T('You are not sure where that is.', 'لست متأكداً أين يقع ذلك.') };
  if (dest === p.location) return { code: 'move_here', ok: false, minutes: 0, fact: T(`You are already at ${locName(dest, 'en')}.`, `أنت بالفعل في ${locName(dest, 'ar')}.`) };
  const route = findPath(state, p.location, dest);
  if (!route) return { code: 'move_noroute', ok: false, minutes: 0, fact: T(`You know no way to reach ${locName(dest, 'en')} from here.`, `لا تعرف طريقاً إلى ${locName(dest, 'ar')} من هنا.`) };
  // Companions on a captive rescue slow the party a little
  let minutes = 0; let cur = p.location; const notes = [];
  for (const step of route.path) {
    const exit = visibleExits(state, cur).find((e) => e.to === step);
    // gate rule
    if (exit.gate) {
      const g = exit.gate; const guardPresent = npcsAt(state, cur).includes(g.guard);
      const freePass = invCount(state, 'writ_of_passage') > 0 || (state.player.flags.gate_free_until || 0) > state.time || attitudeBand(state.npcs[g.guard].attitude) === 'warm';
      if (guardPresent && !freePass) {
        if (p.reputation.criminal >= 40) return { code: 'gate_refused', ok: false, minutes, npcs: [g.guard], fact: T('The gate guards recognise your description from a wanted notice and bar the way.', 'يتعرّف حرّاس البوابة على أوصافك من إعلان مطلوبين ويسدّون الطريق.') };
        if (p.gold < g.toll) return { code: 'gate_toll_short', ok: false, minutes, npcs: [g.guard], fact: T(`The guard demands the ${g.toll} silver toll. You do not have it.`, `يطلب الحارس رسم ${g.toll} فضة، وليس معك ما يكفي.`) };
        p.gold -= g.toll; notes.push(T(`You paid the ${g.toll} silver bridge toll.`, `دفعت رسم الجسر ${g.toll} فضة.`));
      }
    }
    minutes += exit.minutes; cur = step;
    // wilderness danger on the way
    const L2 = LOCATIONS[step];
    if (L2.danger && exit.minutes >= 30 && state.npcs.rusk.alive && !p.flags.fenrats_broken && !state.npcs.rusk.fled) {
      const night = timeInfo(state.time + minutes).isNight;
      const chance = (state.world.conditions.banditActivity / 100) * 0.35 * (night ? 1.6 : 1);
      if (rand(state) < chance) {
        const chk = skillCheck(state, 'survival', 13, {});
        if (chk.success) notes.push(T('You spotted men waiting in the reeds and slipped around them.', 'لمحت رجالاً يتربّصون بين القصب وتسلّلت حولهم.'));
        else {
          const lost = Math.min(p.gold, 2 + roll(state, 6)); const dmg = roll(state, 4);
          p.gold -= lost; p.hp = Math.max(1, p.hp - dmg);
          notes.push(T(`Fen Rats ambushed you on the road: you lost ${lost} silver and took ${dmg} wounds before breaking free.`, `نصب لك جرذان المستنقع كميناً على الطريق: خسرت ${lost} فضة وأُصبت بـ ${dmg} جروح قبل أن تفلت.`));
          recordEvent(state, { type: 'ambushed', importance: 3, entities: ['fenrats', step, 'player'], location: step, text: T(`${p.name} was ambushed by Fen Rats on the road.`, `تعرّض ${p.name} لكمين من جرذان المستنقع على الطريق.`) });
        }
      }
    }
  }
  p.location = dest;
  if (!p.known.locations.includes(dest)) p.known.locations.push(dest);
  for (const c of p.companions) if (state.npcs[c]) state.npcs[c].override = dest;
  const first = !state.events.some((e) => e.type === 'arrived' && e.location === dest);
  recordEvent(state, { type: 'arrived', importance: first ? 2 : 1, entities: [dest], location: dest, text: T(`${p.name} arrived at ${locName(dest, 'en')}.`, `وصل ${p.name} إلى ${locName(dest, 'ar')}.`) });
  return {
    code: 'move', ok: true, minutes, destination: dest, firstVisit: first,
    fact: T([...notes.map((n) => n.en), `You travel to ${locName(dest, 'en')} (${minutes} min).`].join(' '), [...notes.map((n) => n.ar), `تسير إلى ${locName(dest, 'ar')} (${minutes} دقيقة).`].join(' '))
  };
};

function pickTopic(state, npc, text) {
  const def = NPCS[npc]; const st = state.npcs[npc];
  let best = null, bestLen = 0;
  for (const t of def.topics || []) {
    const len = matchAliases(text, t.keys);
    if (len > bestLen) { best = t; bestLen = len; }
  }
  if (!best) return { topic: null };
  if (st.attitude < best.minAttitude) return { topic: best, locked: true };
  return { topic: best };
}

function applyTopic(state, npc, topic, res) {
  const p = state.player;
  for (const r of topic.reveals || []) learnFact(state, r);
  if (topic.unlockFlag) p.flags[topic.unlockFlag] = true;
  if (topic.quest && !p.quests[topic.quest]) {
    p.quests[topic.quest] = { status: 'active', since: state.time };
    res.quest = topic.quest;
    recordEvent(state, { type: 'quest_offered', importance: 2, entities: [npc, topic.quest], text: T(`${npcName(npc, 'en')} asked ${p.name} for help: ${QUESTS[topic.quest].title.en}.`, `طلب ${npcName(npc, 'ar')} من ${p.name} المساعدة: ${QUESTS[topic.quest].title.ar}.`) });
  }
  if (topic.secret) {
    recordEvent(state, { type: 'secret_learned', importance: 3, entities: [npc, topic.id], text: T(`${npcName(npc, 'en')} told ${p.name} a secret.`, `أفضى ${npcName(npc, 'ar')} بسرّ إلى ${p.name}.`) });
    gainXp(state, 25);
  }
  res.line = { npc, text: topic.text };
}

R.talk = (state, a) => {
  const p = state.player;
  const npc = resolveNpc(state, a.npc || a.utterance || a.description || '');
  if (!npc) {
    const named = resolveNpc(state, a.npc || '', { presentOnly: false });
    if (named) return { code: 'talk_absent', ok: false, minutes: 0, fact: T(`${npcName(named, 'en')} is not here.`, `${npcName(named, 'ar')} ليس هنا.`) };
    const present = npcsAt(state, p.location);
    if (!present.length) return { code: 'talk_noone', ok: false, minutes: 1, fact: T('There is no one here to talk to.', 'لا أحد هنا لتتحدث معه.') };
    return R.talk(state, { ...a, npc: present[0] });
  }
  const st = state.npcs[npc]; const def = NPCS[npc];
  const res = { code: 'talk', ok: true, minutes: 10, npc, npcs: [npc] };
  const firstMeet = !st.met; st.met = true;
  if (!p.known.npcs.includes(npc)) p.known.npcs.push(npc);
  const band = attitudeBand(st.attitude);
  if (band === 'hostile' && npc !== 'rusk') {
    res.ok = false; res.code = 'talk_refused'; res.line = { npc, text: def.greet.hostile };
    res.fact = T(`${def.name.en} refuses to talk.`, `${def.name.ar} يرفض الكلام.`);
    return res;
  }
  const { topic, locked } = pickTopic(state, npc, [a.topic, a.utterance, a.description].filter(Boolean).join(' '));
  if (topic && !locked) {
    applyTopic(state, npc, topic, res);
    res.topic = topic.id;
    res.fact = T(`${def.name.en} talks about ${topic.id.replace(/_/g, ' ')}.`, `يتحدّث ${def.name.ar} عن الموضوع.`);
  } else if (topic && locked) {
    res.code = 'talk_guarded'; res.topic = topic.id;
    res.line = { npc, text: def.greet[band] };
    res.fact = T(`${def.name.en} clearly knows more about that, but does not trust you enough to say.`, `واضح أن ${def.name.ar} يعرف أكثر عن ذلك، لكنه لا يثق بك بما يكفي ليقول.`);
  } else {
    res.line = { npc, text: def.greet[band] };
    res.fact = T(`You talk with ${def.name.en}.`, `تتحدّث مع ${def.name.ar}.`);
  }
  if (firstMeet) {
    changeAttitude(state, npc, 2, res);
    addMemory(state, npc, `Met ${p.name} (${p.background}) on day ${timeInfo(state.time).day}.`, 2, ['meeting']);
  }
  if (a.utterance) res.playerSaid = a.utterance;
  return res;
};

const SOCIAL_DC = { persuade: 12, charm: 11, deceive: 13, intimidate: 13, bribe: 10 };
R.social = (state, a) => {
  const p = state.player;
  const npc = resolveNpc(state, a.npc || a.description || '');
  if (!npc) return { code: 'social_noone', ok: false, minutes: 0, fact: T('There is no one here by that description.', 'لا أحد هنا بهذه الأوصاف.') };
  const approach = a.approach || 'persuade';
  const st = state.npcs[npc]; const def = NPCS[npc];
  const res = { code: 'social', ok: false, minutes: 10, npc, npcs: [npc], approach };
  st.met = true; if (!p.known.npcs.includes(npc)) p.known.npcs.push(npc);
  const goalText = [a.topic, a.utterance, a.description].filter(Boolean).join(' ');
  const { topic } = pickTopic(state, npc, goalText);
  let dc = SOCIAL_DC[approach] + (topic?.secret ? 4 : 0) + (def.stats.wis >= 14 && approach === 'deceive' ? 2 : 0);
  dc -= Math.round(st.attitude / 10);
  let bonus = 0; let stat = 'cha';
  if (approach === 'intimidate') { stat = p.stats.str > p.stats.cha ? 'str' : 'cha'; bonus += Math.floor(p.level / 2); }
  if (approach === 'bribe') {
    const amount = Math.min(p.gold, a.qty || 0);
    if (amount <= 0) return { ...res, code: 'bribe_nogold', fact: T('You have nothing to offer.', 'ليس لديك ما تعرضه.') };
    bonus += Math.floor(amount / 3);
    p.gold -= amount; st.gold += amount; res.paid = amount;
  }
  // special cases first
  if (npc === 'rusk' && /lio|boy|release|free|ليو|الصبي|أطلق|اطلق|حرر|حرّر|فدية/i.test(goalText)) {
    dc = approach === 'bribe' ? (res.paid >= 40 ? 0 : 99) : approach === 'intimidate' ? 19 : 17;
  }
  if (npc === 'brannoc' && /pass|enter|let me|through|gate|ادخل|أدخل|عبور|أمر|امر|دخول|السماح/i.test(goalText)) dc = Math.min(dc, approach === 'bribe' ? 0 : 12);
  const chk = skillCheck(state, 'persuasion', dc, { stat, bonus });
  res.check = chk; res.ok = chk.success;
  const name = def.name;
  if (chk.success) {
    if (approach === 'intimidate') changeAttitude(state, npc, -6, res); else if (approach !== 'deceive') changeAttitude(state, npc, 3, res);
    if (npc === 'rusk' && dc >= 0 && /lio|boy|release|free|ليو|الصبي|أطلق|اطلق|حرر|حرّر|فدية/i.test(goalText) && state.npcs.lio.captive) {
      freeLio(state, res);
    } else if (npc === 'brannoc' && /pass|enter|let me|through|gate|ادخل|أدخل|عبور|دخول|السماح/i.test(goalText)) {
      p.flags.gate_free_until = state.time + 1440;
      res.fact = T('Brannoc waves you through the gate without the toll.', 'يشير لك برانوك بالعبور دون رسم.');
    } else if (topic) {
      applyTopic(state, npc, topic, res); res.topic = topic.id;
      res.fact = T(`Your ${approach} works: ${name.en} opens up about it.`, `ينجح أسلوبك: ${name.ar} يتكلّم عن الأمر.`);
    } else {
      res.fact = T(`Your ${approach} works on ${name.en}; they are more willing now.`, `ينجح أسلوبك مع ${name.ar}؛ صار أكثر استعداداً الآن.`);
    }
    if (!res.fact) res.fact = T(`Your ${approach} works on ${name.en}.`, `ينجح أسلوبك مع ${name.ar}.`);
    addMemory(state, npc, `${p.name} ${approach}d me${approach === 'intimidate' ? ' and I gave in' : ''}.`, approach === 'intimidate' ? 3 : 2, [approach]);
  } else {
    const d = approach === 'deceive' ? -10 : approach === 'intimidate' ? -8 : approach === 'bribe' ? -2 : -2;
    changeAttitude(state, npc, d, res);
    if (approach === 'bribe' && res.paid) { /* they keep the coin */ }
    res.fact = T(`Your attempt to ${approach} ${name.en} fails${approach === 'deceive' ? '; they see through you' : ''}.`, `تفشل محاولتك مع ${name.ar}${approach === 'deceive' ? '؛ لقد كشف كذبك' : ''}.`);
    addMemory(state, npc, `${p.name} tried to ${approach} me and failed.`, approach === 'deceive' ? 3 : 2, [approach]);
    if (approach === 'bribe' && npc === 'brannoc' && chk.fumble) { changeRep(state, { dim: 'criminal', delta: 5, text: T(`${p.name} tried to bribe a gate captain.`, `حاول ${p.name} رشوة قائد البوابة.`) }); }
  }
  if (approach === 'bribe' && res.paid) res.fact.en += ` (${res.paid} silver handed over.)`, res.fact.ar += ` (سلّمت ${res.paid} فضة.)`;
  return res;
};

function freeLio(state, res) {
  const p = state.player;
  state.npcs.lio.captive = false;
  state.npcs.lio.override = p.location;
  if (!p.companions.includes('lio')) p.companions.push('lio');
  p.flags.lio_freed = true;
  res.fact = T('Lio is unchained and stumbles to your side. He will follow you home.', 'فُكّ قيد ليو وتعثّر إلى جانبك. سيتبعك إلى البيت.');
  recordEvent(state, { type: 'lio_freed', importance: 4, entities: ['lio', 'fenrats', 'player'], text: T(`${p.name} freed Lio, Tobin's apprentice, from the Fen Rats.`, `حرّر ${p.name} ليو، صبيّ توبن، من جرذان المستنقع.`) });
  addMemory(state, 'lio', `${p.name} freed me from the Fen Rat camp.`, 5, ['rescue']);
  changeAttitude(state, 'lio', 40, res);
  gainXp(state, 60);
}

R.buy = (state, a) => {
  const p = state.player;
  const loc = LOCATIONS[p.location];
  const candidates = [...(loc.services?.sells || []), ...npcsAt(state, p.location).flatMap((n) => NPCS[n].sells || [])];
  const item = resolveItem(a.item || a.description || '', candidates);
  if (!item) return { code: 'buy_none', ok: false, minutes: 0, fact: T('No one here sells that.', 'لا أحد هنا يبيع ذلك.') };
  const seller = sellerHere(state, item);
  if (!seller) return { code: 'buy_noseller', ok: false, minutes: 0, fact: T('The seller is not here right now.', 'البائع ليس هنا الآن.') };
  if (seller.npc && attitudeBand(state.npcs[seller.npc].attitude) === 'hostile') return { code: 'buy_refused', ok: false, minutes: 1, npcs: [seller.npc], fact: T(`${npcName(seller.npc, 'en')} refuses to sell to you.`, `${npcName(seller.npc, 'ar')} يرفض البيع لك.`) };
  if (item === 'stew' && p.flags.hessa_closed && p.location === 'sunken_lantern') return { code: 'buy_soldout', ok: false, minutes: 1, fact: T('There is no stew; the pot is cold.', 'لا يوجد حساء؛ القدر بارد.') };
  const qty = a.qty || 1;
  const price = priceOf(state, item, { npc: seller.npc });
  const total = price * qty;
  if (p.gold < total) return { code: 'buy_poor', ok: false, minutes: 1, fact: T(`${itemName(item, 'en')} costs ${total} silver; you have ${p.gold}.`, `${itemName(item, 'ar')} ثمنه ${total} فضة؛ ومعك ${p.gold}.`) };
  p.gold -= total; addItem(state, item, qty);
  if (seller.npc) { state.npcs[seller.npc].gold += total; changeAttitude(state, seller.npc, total >= 10 ? 1 : 0); }
  gainSkillXp(state, 'trading', 2);
  return { code: 'buy', ok: true, minutes: 3, item, qty, price: total, npcs: seller.npc ? [seller.npc] : [], fact: T(`You buy ${qty} × ${itemName(item, 'en')} for ${total} silver.`, `تشتري ${qty} × ${itemName(item, 'ar')} مقابل ${total} فضة.`) };
};

R.sell = (state, a) => {
  const p = state.player;
  const item = resolveItem(a.item || a.description || '', p.inventory.map((i) => i.id));
  if (!item) return { code: 'sell_none', ok: false, minutes: 0, fact: T('You have nothing like that to sell.', 'ليس لديك شيء كهذا لتبيعه.') };
  if (ITEMS[item].type === 'clue') return { code: 'sell_clue', ok: false, minutes: 0, fact: T('No one would pay for that.', 'لن يدفع أحد مقابل هذا.') };
  const buyer = buyerHere(state, item);
  if (!buyer) return { code: 'sell_nobuyer', ok: false, minutes: 0, fact: T('No one here buys that.', 'لا أحد هنا يشتري ذلك.') };
  const qty = Math.min(a.qty || 1, invCount(state, item));
  const price = priceOf(state, item, { selling: true, npc: buyer.npc }) * qty;
  if (buyer.npc && state.npcs[buyer.npc].gold < price) return { code: 'sell_poorbuyer', ok: false, minutes: 1, fact: T(`${npcName(buyer.npc, 'en')} cannot afford it.`, `${npcName(buyer.npc, 'ar')} لا يملك ثمنه.`) };
  removeItem(state, item, qty); p.gold += price;
  if (buyer.npc) state.npcs[buyer.npc].gold -= price;
  gainSkillXp(state, 'trading', 3);
  if (item === 'sarith_glass') {
    learnFact(state, 'sold_glass');
    if (npcsAt(state, p.location).includes('ilvane') || settlementOf(p.location) === 'mirefold') changeRep(state, { dim: 'local', delta: -4, text: T(`${p.name} trades in grave glass.`, `${p.name} يتاجر بزجاج القبور.`) });
  }
  return { code: 'sell', ok: true, minutes: 3, item, qty, price, npcs: buyer.npc ? [buyer.npc] : [], fact: T(`You sell ${qty} × ${itemName(item, 'en')} for ${price} silver.`, `تبيع ${qty} × ${itemName(item, 'ar')} مقابل ${price} فضة.`) };
};

R.give = (state, a) => {
  const p = state.player;
  const npc = resolveNpc(state, a.npc || '');
  if (!npc) return { code: 'give_noone', ok: false, minutes: 0, fact: T('They are not here.', 'ليسوا هنا.') };
  const res = { code: 'give', ok: true, minutes: 2, npc, npcs: [npc] };
  const goldMatch = /silver|coin|gold|money|فضة|مال|نقود|ذهب|دراهم/i.test([a.item, a.description].join(' '));
  if (goldMatch || (!a.item && a.qty)) {
    const amt = Math.min(p.gold, a.qty || 1);
    if (amt <= 0) return { code: 'give_poor', ok: false, minutes: 0, fact: T('You have no silver.', 'ليس معك فضة.') };
    p.gold -= amt; state.npcs[npc].gold += amt;
    changeAttitude(state, npc, Math.min(15, 1 + Math.floor(amt / 2)), res);
    res.fact = T(`You give ${npcName(npc, 'en')} ${amt} silver.`, `تعطي ${npcName(npc, 'ar')} ${amt} فضة.`);
    if (npc === 'hessa') {
      p.flags.hessa_paid = (p.flags.hessa_paid || 0) + amt;
      if (p.flags.hessa_paid >= 40 && !p.flags.hessa_debt_cleared) {
        p.flags.hessa_debt_cleared = true; changeAttitude(state, 'hessa', 30, res);
        recordEvent(state, { type: 'debt_cleared', importance: 4, entities: ['hessa', 'ledger', 'player'], text: T(`${p.name} paid off the Sunken Lantern's debt to the Grey Ledger.`, `سدّد ${p.name} دين حانة الفانوس الغارق للسجلّ الرمادي.`) });
        changeRep(state, { dim: 'local', delta: 12, text: T(`${p.name} saved the Sunken Lantern.`, `أنقذ ${p.name} حانة الفانوس الغارق.`) });
      }
    }
    addMemory(state, npc, `${p.name} gave me ${amt} silver.`, amt >= 10 ? 3 : 2, ['gift']);
    return res;
  }
  const item = resolveItem(a.item || a.description || '', p.inventory.map((i) => i.id));
  if (!item) return { code: 'give_noitem', ok: false, minutes: 0, fact: T('You do not have that.', 'ليس لديك ذلك.') };
  removeItem(state, item, 1);
  changeAttitude(state, npc, Math.min(10, 1 + Math.floor((ITEMS[item].price || 2) / 4)), res);
  res.fact = T(`You give ${itemName(item, 'en')} to ${npcName(npc, 'en')}.`, `تعطي ${itemName(item, 'ar')} إلى ${npcName(npc, 'ar')}.`);
  if (item === 'lio_satchel' && npc === 'tobin') { learnFact(state, 'tobin_has_satchel'); changeAttitude(state, 'tobin', 8, res); res.line = { npc, text: T('That\'s his. That\'s Lio\'s. Where did you find it? The ruins? Then he went west after all...', 'هذه حقيبته. حقيبة ليو. أين وجدتها؟ في الأطلال؟ إذن ذهب غرباً فعلاً...') }; }
  if (item === 'ledger_page' && (npc === 'ilvane' || npc === 'brannoc')) { learnFact(state, 'reported_unlit'); state.player.flags.reported_unlit = true; changeAttitude(state, 'garrow', -30); res.line = { npc, text: T('This sigil... I will see to it that the right people know.', 'هذا الختم... سأحرص على أن يعرف الأشخاص المناسبون.') }; recordEvent(state, { type: 'unlit_reported', importance: 4, entities: ['unlit', 'garrow', npc, 'player'], text: T(`${p.name} handed proof of the Unlit to ${npcName(npc, 'en')}.`, `سلّم ${p.name} دليلاً على المُطفَئين إلى ${npcName(npc, 'ar')}.`) }); }
  addMemory(state, npc, `${p.name} gave me ${ITEMS[item].name.en}.`, 2, ['gift']);
  return res;
};

R.take = (state, a) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  const avail = (loc.loot || []).filter((l) => !state.world.lootTaken[`${p.location}:${l.item}`] && lootVisible(state, p.location, l.item));
  const item = resolveItem(a.item || a.description || '', avail.map((l) => l.item)) || (avail.length === 1 && !a.item ? avail[0].item : null);
  if (!item) return { code: 'take_none', ok: false, minutes: 1, fact: T('There is nothing like that here to take.', 'لا يوجد شيء كهذا هنا لتأخذه.') };
  const entry = avail.find((l) => l.item === item);
  state.world.lootTaken[`${p.location}:${item}`] = true; addItem(state, item, entry.qty);
  if (p.location === 'mill_cellar') {
    const witnesses = npcsAt(state, p.location);
    if (witnesses.includes('garrow')) changeAttitude(state, 'garrow', -25);
    recordEvent(state, { type: 'took_glass', importance: 3, entities: ['garrow', 'unlit', 'player'], text: T(`${p.name} took glass from Garrow's cellar.`, `أخذ ${p.name} زجاجاً من قبو غارو.`) });
  }
  return { code: 'take', ok: true, minutes: 2, item, qty: entry.qty, fact: T(`You take ${entry.qty} × ${itemName(item, 'en')}.`, `تأخذ ${entry.qty} × ${itemName(item, 'ar')}.`) };
};

R.eat = (state, a) => {
  const p = state.player;
  const edible = p.inventory.filter((i) => ['food', 'drink'].includes(ITEMS[i.id].type)).map((i) => i.id);
  let item = resolveItem(a.item || a.description || '', edible);
  if (!item && !a.item && edible.length) item = edible[edible.length - 1];
  let bought = null;
  if (!item) {
    const loc = LOCATIONS[p.location];
    const forSale = (loc.services?.sells || []).filter((i) => ['food', 'drink'].includes(ITEMS[i].type));
    const want = resolveItem(a.item || a.description || 'stew', forSale) || forSale.find((i) => ITEMS[i].type === 'food');
    if (!want) return { code: 'eat_none', ok: false, minutes: 0, fact: T('You have nothing to eat.', 'ليس لديك ما تأكله.') };
    bought = R.buy(state, { item: want, qty: 1 });
    if (!bought.ok) return bought;
    item = want;
  }
  removeItem(state, item, 1);
  p.hunger = clamp(p.hunger - (ITEMS[item].food || 10), 0, 100);
  p.stamina = clamp(p.stamina + 10, 0, 100);
  return { code: 'eat', ok: true, minutes: 15, item, fact: T(`${bought ? bought.fact.en + ' ' : ''}You eat the ${itemName(item, 'en')}.`, `${bought ? bought.fact.ar + ' ' : ''}تتناول ${itemName(item, 'ar')}.`) };
};

R.rent = (state, a) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  if (!loc.services?.room) return { code: 'rent_none', ok: false, minutes: 0, fact: T('There are no rooms to rent here.', 'لا توجد غرف للإيجار هنا.') };
  const price = Math.round(loc.services.room * (state.world.priceMod[settlementOf(p.location)] || 1));
  const nights = a.qty || 1;
  if (p.gold < price * nights) return { code: 'rent_poor', ok: false, minutes: 1, fact: T(`A room costs ${price} silver a night; you have ${p.gold}.`, `الغرفة بـ ${price} فضة لليلة؛ ومعك ${p.gold}.`) };
  p.gold -= price * nights;
  const ti = timeInfo(state.time);
  const until = (ti.day - 1 + nights) * 1440 + (ti.hour >= 10 ? 1440 : 0) + 10 * 60;
  p.lodging = { location: p.location, until };
  return { code: 'rent', ok: true, minutes: 3, fact: T(`You rent a room for ${nights} night(s), ${price * nights} silver.`, `تستأجر غرفة لـ ${nights} ليلة، بـ ${price * nights} فضة.`) };
};

R.rest = (state, a) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  const hours = a.hours || 8;
  const safe = p.lodging?.location === p.location;
  const res = { code: 'rest', ok: true, minutes: hours * 60 };
  if (!safe && loc.danger) {
    const chk = skillCheck(state, 'survival', 11 + loc.danger * 2, {});
    if (!chk.success) { const dmg = roll(state, 6); p.hp = Math.max(1, p.hp - dmg); res.minutes = Math.min(res.minutes, 180); res.fact = T(`Your sleep in the open is broken by an attack in the dark; you take ${dmg} wounds.`, `انقطع نومك في العراء بهجوم في الظلام؛ أُصبت بـ ${dmg} جروح.`); res.ok = false; return res; }
  }
  const quality = safe ? 1 : loc.type === 'tavern' || loc.type === 'temple' ? 0.6 : 0.4;
  const healed = Math.round(hours * (1 + Math.max(0, mod(p.stats.con))) * quality);
  p.hp = clamp(p.hp + healed, 0, p.maxHp);
  p.fatigue = clamp(p.fatigue - hours * 11 * quality, 0, 100);
  res.fact = T(`You ${hours >= 6 ? 'sleep' : 'rest'} for ${hours} hour(s)${safe ? ' in your rented room' : ''} and recover ${healed} health.`, `${hours >= 6 ? 'تنام' : 'تستريح'} ${hours} ساعة${safe ? ' في غرفتك المستأجرة' : ''} وتستعيد ${healed} من صحتك.`);
  return res;
};

R.wait = (state, a) => ({ code: 'wait', ok: true, minutes: (a.hours || 1) * 60, fact: T(`You wait for ${a.hours || 1} hour(s).`, `تنتظر ${a.hours || 1} ساعة.`) });

R.search = (state, a) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  const remaining = (loc.features || []).filter((f) => !p.flags[f.flag]);
  if (!remaining.length) return { code: 'search_empty', ok: true, minutes: 15, fact: T('You search carefully but find nothing new.', 'تبحث بعناية لكنك لا تجد شيئاً جديداً.') };
  const skill = ['forest', 'wild', 'ruin', 'camp'].includes(loc.type) ? 'survival' : null;
  const lit = invCount(state, 'torch') > 0 && ['ruin'].includes(loc.type) ? 2 : 0;
  const found = []; const missed = [];
  for (const f of remaining.sort((x, y) => x.dc - y.dc)) {
    const chk = skillCheck(state, skill, f.dc, { stat: 'per', bonus: lit + (p.known.facts.includes('hint_mill_cellar') && f.id === 'trapdoor' ? 3 : 0) + (p.flags.saw_cart_tracks && f.id === 'camp_smoke' ? 2 : 0) });
    if (chk.success) { found.push(f); p.flags[f.flag] = true; } else { missed.push(f); break; }
  }
  if (!found.length) return { code: 'search_fail', ok: false, minutes: 30, fact: T('You search for a while but nothing reveals itself. Perhaps with more knowledge, or better light...', 'تبحث مدة لكن لا شيء يكشف عن نفسه. ربما بمعرفة أكثر، أو ضوء أفضل...') };
  for (const f of found) {
    gainXp(state, 15);
    const ev = recordEvent(state, { type: 'discovery', importance: f.history ? 5 : 3, entities: [p.location, f.id, 'player'], text: T(`${p.name} discovered something at ${locName(p.location, 'en')}: ${f.reveal.en}`, `اكتشف ${p.name} شيئاً في ${locName(p.location, 'ar')}: ${f.reveal.ar}`) });
    learnFact(state, f.flag);
    void ev;
  }
  return { code: 'search', ok: true, minutes: 30, reveal: T(found.map((f) => f.reveal.en).join(' '), found.map((f) => f.reveal.ar).join(' ')), fact: T('Your search turns something up.', 'يكشف بحثك عن شيء.') };
};

R.equip = (state, a) => {
  const p = state.player;
  const item = resolveItem(a.item || a.description || '', p.inventory.map((i) => i.id).filter((i) => ['weapon', 'armor', 'shield'].includes(ITEMS[i].type)));
  if (!item) return { code: 'equip_none', ok: false, minutes: 0, fact: T('You have nothing like that to equip.', 'ليس لديك شيء كهذا لتجهّزه.') };
  p.equipped[ITEMS[item].type] = item;
  return { code: 'equip', ok: true, minutes: 2, item, fact: T(`You ready the ${itemName(item, 'en')}.`, `تجهّز ${itemName(item, 'ar')}.`) };
};

R.use = (state, a) => {
  const p = state.player;
  const item = resolveItem(a.item || a.description || '', p.inventory.map((i) => i.id));
  if (!item) return { code: 'use_none', ok: false, minutes: 0, fact: T('You do not have that.', 'ليس لديك ذلك.') };
  const d = ITEMS[item];
  if (d.type === 'medicine') {
    const chk = skillCheck(state, 'medicine', 8, {});
    const heal = d.heal + (chk.success ? p.skills.medicine.lvl + 2 : 0);
    removeItem(state, item, 1); p.hp = clamp(p.hp + heal, 0, p.maxHp);
    return { code: 'use_heal', ok: true, minutes: 10, fact: T(`You treat your wounds with the ${itemName(item, 'en')} and recover ${heal} health.`, `تعالج جروحك بـ ${itemName(item, 'ar')} وتستعيد ${heal} من صحتك.`) };
  }
  if (['food', 'drink'].includes(d.type)) return R.eat(state, { item });
  if (['weapon', 'armor', 'shield'].includes(d.type)) return R.equip(state, { item });
  if (d.type === 'clue' || d.type === 'relic') return { code: 'use_examine', ok: true, minutes: 5, fact: T(`You examine the ${itemName(item, 'en')} closely.`, `تتفحّص ${itemName(item, 'ar')} عن قرب.`), reveal: item === 'ledger_page' ? T('The page lists crates "to Q., Corvane" and payments "to R. for diggers". The sigil is a candle without a flame.', 'الصفحة تذكر صناديق «إلى ك.، كورفان» ومدفوعات «إلى ر. من أجل الحفّارين». والختم شمعة بلا لهب.') : item === 'lio_satchel' ? T('Inside: a debt note for Tobin and a charcoal sketch of torches near drowned oaks.', 'في داخلها: سند دين لتوبن ورسم بالفحم لمشاعل قرب أشجار بلوط غارقة.') : null };
  return { code: 'use_nothing', ok: false, minutes: 1, fact: T(`You find no particular use for the ${itemName(item, 'en')} here.`, `لا تجد استخداماً معيناً لـ ${itemName(item, 'ar')} هنا.`) };
};

const JOBS = {
  kael_forge: { npc: 'oswin', skill: 'blacksmithing', dc: 11, pay: [3, 6], en: 'working the bellows and hammering nails for Oswin', ar: 'تشغيل المنفاخ وطرق المسامير لأوزوين' },
  sunken_lantern: { npc: 'hessa', skill: 'trading', dc: 9, pay: [2, 4], en: 'serving tables and hauling kegs for Hessa', ar: 'خدمة الطاولات وحمل البراميل لهيسا' },
  old_mill: { npc: 'garrow', skill: null, dc: 10, stat: 'str', pay: [2, 5], en: 'hauling sacks at the mill', ar: 'حمل الأكياس في الطاحونة' },
  corvane_market: { npc: 'marda', skill: 'trading', dc: 12, pay: [4, 8], en: 'counting stock for the Ledger', ar: 'جرد البضائع لصالح السجلّ' }
};
R.work = (state, a) => {
  const p = state.player; const job = JOBS[p.location];
  if (!job) return { code: 'work_none', ok: false, minutes: 0, fact: T('There is no work to be had here.', 'لا يوجد عمل متاح هنا.') };
  if (!npcsAt(state, p.location).includes(job.npc)) return { code: 'work_noboss', ok: false, minutes: 0, fact: T(`${npcName(job.npc, 'en')} is not here to hire you.`, `${npcName(job.npc, 'ar')} ليس هنا ليوظّفك.`) };
  if (attitudeBand(state.npcs[job.npc].attitude) === 'hostile') return { code: 'work_refused', ok: false, minutes: 1, fact: T(`${npcName(job.npc, 'en')} won't hire you.`, `${npcName(job.npc, 'ar')} لن يوظّفك.`) };
  const chk = skillCheck(state, job.skill, job.dc, { stat: job.stat });
  const pay = chk.success ? job.pay[0] + Math.floor(rand(state) * (job.pay[1] - job.pay[0] + 1)) : job.pay[0] - 1;
  p.gold += Math.max(0, pay); p.fatigue = clamp(p.fatigue + 15, 0, 100);
  changeAttitude(state, job.npc, chk.success ? 2 : 0);
  if (chk.success) addMemory(state, job.npc, `${p.name} worked hard for me.`, 2, ['work']);
  gainXp(state, 5);
  return { code: 'work', ok: chk.success, minutes: 240, npcs: [job.npc], fact: T(`You spend four hours ${job.en} and earn ${Math.max(0, pay)} silver${chk.success ? '' : ' (clumsy work, short pay)'}.`, `تقضي أربع ساعات في ${job.ar} وتكسب ${Math.max(0, pay)} فضة${chk.success ? '' : ' (عمل متعثّر، وأجر ناقص)'}.`) };
};

R.hunt = (state) => {
  const p = state.player; const loc = LOCATIONS[p.location];
  if (!loc.forage) return { code: 'hunt_none', ok: false, minutes: 0, fact: T('There is nothing to hunt here.', 'لا يوجد ما يُصطاد هنا.') };
  const bonus = ITEMS[p.equipped.weapon]?.ranged ? 2 : 0;
  const chk = skillCheck(state, 'hunting', loc.forage.dc, { bonus });
  if (chk.success) { addItem(state, loc.forage.item, 1); p.hunger = clamp(p.hunger - 15, 0, 100); gainXp(state, 8); return { code: 'hunt', ok: true, minutes: 180, fact: T(`After three hours you bring down a wolf: you skin it (${itemName(loc.forage.item, 'en')}) and roast some meat.`, `بعد ثلاث ساعات تصطاد ذئباً: تسلخه (${itemName(loc.forage.item, 'ar')}) وتشوي بعض اللحم.`) }; }
  const hurt = chk.fumble ? roll(state, 4) : 0; p.hp = Math.max(1, p.hp - hurt);
  return { code: 'hunt_fail', ok: false, minutes: 180, fact: T(`Three hours in the bog and nothing to show for it${hurt ? `; you slipped and took ${hurt} wounds` : ''}.`, `ثلاث ساعات في المستنقع بلا نتيجة${hurt ? `؛ انزلقت وأُصبت بـ ${hurt} جروح` : ''}.`) };
};

// ------------------------------------------------------------ combat
function npcCombat(state, id) {
  const d = NPCS[id];
  return { atk: mod(d.stats.str) + Math.floor((d.stats.dex - 10) / 4) + (id === 'rusk' || id === 'brannoc' ? 3 : id === 'oswin' || id === 'ysolde' ? 2 : 0), def: 10 + mod(d.stats.dex) + (d.armor || 0), dmg: ITEMS[d.weapon]?.dmg || [1, 3] };
}
R.attack = (state, a) => {
  const p = state.player;
  const npc = resolveNpc(state, a.npc || a.description || '');
  if (!npc) return { code: 'attack_noone', ok: false, minutes: 0, fact: T('There is no such target here.', 'لا يوجد هدف كهذا هنا.') };
  const st = state.npcs[npc]; const def = NPCS[npc]; const nc = npcCombat(state, npc);
  const res = { code: 'attack', ok: true, minutes: 2, npc, npcs: [npc], combat: [] };
  const w = ITEMS[p.equipped.weapon]; const wSkill = w?.skill || 'swordsmanship';
  const firstBlow = !st.inCombat; st.inCombat = true;
  // player strike
  const chk = skillCheck(state, wSkill, nc.def, { stat: w?.ranged ? 'dex' : 'str', bonus: firstBlow && !st.met ? 2 : 0 });
  let dealt = 0;
  if (chk.success) {
    const [lo, hi] = w?.dmg || [1, 2];
    dealt = lo + Math.floor(rand(state) * (hi - lo + 1)) + Math.max(0, mod(p.stats.str)) + (chk.crit ? hi : 0);
    st.hp -= dealt;
  }
  res.combat.push({ who: 'player', hit: chk.success, dmg: dealt, crit: chk.crit });
  const lines = { en: [chk.success ? `You hit ${def.name.en} for ${dealt}${chk.crit ? ' (a brutal strike)' : ''}.` : `You swing at ${def.name.en} and miss.`], ar: [chk.success ? `تصيب ${def.name.ar} بـ ${dealt}${chk.crit ? ' (ضربة قاسية)' : ''}.` : `تهاجم ${def.name.ar} وتخطئ.`] };
  // consequences of violence
  if (firstBlow) {
    changeAttitude(state, npc, -60, res);
    const witnesses = npcsAt(state, p.location).filter((x) => x !== npc);
    for (const wn of witnesses) { changeAttitude(state, wn, def.faction === 'fenrats' ? 5 : -20, res); addMemory(state, wn, `Saw ${p.name} attack ${def.name.en}.`, 4, ['violence']); }
    if (def.faction !== 'fenrats') {
      changeRep(state, { dim: 'criminal', delta: 15, text: T(`${p.name} drew steel on ${def.name.en}.`, `شهر ${p.name} سلاحه على ${def.name.ar}.`), witnessed: witnesses.length > 0 });
      changeRep(state, { dim: 'local', delta: -20, text: T(`${p.name} attacked ${def.name.en}.`, `هاجم ${p.name} ${def.name.ar}.`), witnessed: witnesses.length > 0 });
    } else changeRep(state, { dim: 'military', delta: 4, text: T(`${p.name} fought the Fen Rats.`, `قاتل ${p.name} جرذان المستنقع.`) });
    addMemory(state, npc, `${p.name} attacked me.`, 5, ['violence']);
  }
  if (st.hp <= 0) {
    st.alive = false; st.location = null; st.inCombat = false;
    lines.en.push(`${def.name.en} falls and does not rise.`); lines.ar.push(`يسقط ${def.name.ar} ولا ينهض.`);
    recordEvent(state, { type: 'killed', importance: 5, entities: [npc, 'player', def.faction], text: T(`${p.name} killed ${def.name.en}, ${def.role.en}.`, `قتل ${p.name} ${def.name.ar}، ${def.role.ar}.`) });
    gainXp(state, 40);
    if (npc === 'rusk') {
      p.flags.fenrats_broken = true; state.world.campBandits = 0;
      if (state.npcs.lio.captive && state.npcs.lio.alive) freeLio(state, res);
      changeRep(state, { dim: 'military', delta: 15, text: T(`${p.name} broke the Fen Rats.`, `سحق ${p.name} جرذان المستنقع.`) });
    }
    res.fact = T(lines.en.join(' '), lines.ar.join(' '));
    return res;
  }
  // NPC may flee when badly hurt (not the chief in his camp, not captives)
  if (st.hp <= def.hp * 0.3 && npc !== 'rusk' && !st.captive && rand(state) < 0.6) {
    st.fled = true; st.inCombat = false;
    lines.en.push(`${def.name.en} breaks away and flees.`); lines.ar.push(`يفلت ${def.name.ar} ويهرب.`);
    res.fact = T(lines.en.join(' '), lines.ar.join(' '));
    return res;
  }
  // counter-attacks: target + camp bandits
  const attackers = [{ id: npc, ...nc }];
  if (p.location === 'blackfen_camp' && def.faction === 'fenrats') {
    const n = state.world.campBandits ?? 3;
    for (let i = 0; i < n; i++) attackers.push({ id: 'bandit', atk: 1, def: 11, dmg: [1, 4] });
  }
  const pDef = 10 + mod(p.stats.dex) + armorValue(state) + Math.floor(p.skills.swordsmanship.lvl / 3);
  for (const at of attackers) {
    const r = roll(state, 20) + at.atk;
    if (r >= pDef) {
      const dmg = at.dmg[0] + Math.floor(rand(state) * (at.dmg[1] - at.dmg[0] + 1));
      p.hp -= dmg;
      res.combat.push({ who: at.id, hit: true, dmg });
      lines.en.push(at.id === 'bandit' ? `A Fen Rat cuts you for ${dmg}.` : `${def.name.en} strikes back for ${dmg}.`);
      lines.ar.push(at.id === 'bandit' ? `يجرحك أحد جرذان المستنقع بـ ${dmg}.` : `يردّ ${def.name.ar} الضربة بـ ${dmg}.`);
    } else res.combat.push({ who: at.id, hit: false });
  }
  p.stamina = clamp(p.stamina - 12, 0, 100);
  if (p.hp <= 0) return defeat(state, npc, res, lines);
  res.fact = T(lines.en.join(' ') + ` (You: ${p.hp}/${p.maxHp} HP.)`, lines.ar.join(' ') + ` (أنت: ${p.hp}/${p.maxHp} صحة.)`);
  return res;
};

function defeat(state, npc, res, lines) {
  const p = state.player;
  const lost = Math.floor(p.gold / 2); p.gold -= lost;
  p.hp = Math.max(1, Math.floor(p.maxHp / 3));
  state.npcs[npc].inCombat = false;
  const wakeAt = 'chapel_ashen';
  p.location = wakeAt;
  res.code = 'defeated'; res.ok = false; res.minutes = 8 * 60; res.npcs = [];
  lines.en.push(`You go down. You wake hours later in the Chapel of the Ashen Mother, bandaged, ${lost} silver lighter.`);
  lines.ar.push(`تسقط أرضاً. تستيقظ بعد ساعات في كنيسة الأم الرمادية، مضمّد الجراح، وقد نقصت ${lost} فضة.`);
  recordEvent(state, { type: 'defeated', importance: 4, entities: ['player', npc], text: T(`${p.name} was beaten by ${npcName(npc, 'en')} and left for dead.`, `هُزم ${p.name} على يد ${npcName(npc, 'ar')} وتُرك ظنّاً أنه ميت.`) });
  res.fact = T(lines.en.join(' '), lines.ar.join(' '));
  res.destination = wakeAt;
  return res;
}

// free-form actions: the AI proposes skill+difficulty, the engine decides.
R.free = (state, a) => {
  const diff = a.difficulty || 'medium';
  const dc = DIFFICULTIES[diff];
  if (dc >= 99) return { code: 'free_impossible', ok: false, minutes: 5, description: a.description, fact: T('That is not possible in this world, at least not here and now.', 'هذا غير ممكن في هذا العالم، على الأقل ليس هنا والآن.') };
  const chk = skillCheck(state, a.skill || null, dc, { stat: a.skill ? undefined : 'luck' });
  gainXp(state, chk.success ? 4 : 1);
  const what = a.description || a.utterance || '';
  if (chk.success && dc >= 13) recordEvent(state, { type: 'deed', importance: dc >= 17 ? 3 : 2, entities: ['player'], text: T(`${state.player.name}: ${what}`.slice(0, 200), `${state.player.name}: ${what}`.slice(0, 200)) });
  return { code: 'free', ok: chk.success, minutes: Math.max(5, Math.min(240, (a.hours || 0) * 60 || 20)), check: chk, description: what,
    fact: T(`Attempt: "${what}". ${a.skill ? `(${a.skill}, ${diff})` : `(${diff})`} Result: ${chk.success ? (chk.crit ? 'a remarkable success' : 'success') : (chk.fumble ? 'a bad failure' : 'failure')}.`,
      `المحاولة: «${what}». ${a.skill ? `(${a.skill}، ${diff})` : `(${diff})`} النتيجة: ${chk.success ? (chk.crit ? 'نجاح باهر' : 'نجاح') : (chk.fumble ? 'فشل ذريع' : 'فشل')}.`) };
};

// ------------------------------------------------------------ quests
function checkQuests(state) {
  const p = state.player; const out = [];
  // Lio comes home when he reaches Tobin with the player
  if (p.companions.includes('lio') && npcsAt(state, p.location).includes('tobin') && !p.flags.lio_returned) {
    p.flags.lio_returned = true;
    p.companions = p.companions.filter((c) => c !== 'lio');
    state.npcs.lio.override = 'sunken_lantern';
    recordEvent(state, { type: 'lio_returned', importance: 4, entities: ['lio', 'tobin', 'player'], text: T(`${p.name} brought Lio home to Tobin Marle.`, `أعاد ${p.name} ليو إلى توبن مارل.`) });
    addMemory(state, 'tobin', `${p.name} brought Lio back to me alive. I owe them everything.`, 5, ['lio', 'rescue']);
    changeRep(state, { dim: 'local', delta: 10, text: T(`${p.name} rescued Tobin's apprentice.`, `أنقذ ${p.name} صبيّ توبن.`) });
    changeRep(state, { dim: 'commercial', delta: 10, text: T(`The Ledger hears ${p.name} helped one of its traders.`, `يسمع السجلّ أن ${p.name} ساعد أحد تجّاره.`) });
  }
  for (const [qid, q] of Object.entries(p.quests)) {
    if (q.status !== 'active') continue;
    const def = QUESTS[qid];
    if (p.flags[def.complete.flag]) {
      q.status = 'done'; q.ended = state.time;
      const rw = def.complete.reward;
      if (rw.gold) p.gold += rw.gold;
      for (const [n, d] of Object.entries(rw.attitude || {})) changeAttitude(state, n, d);
      gainXp(state, 80);
      out.push({ quest: qid, status: 'done', reward: rw.gold || 0 });
      recordEvent(state, { type: 'quest_done', importance: 3, entities: [qid, def.giver], text: T(`${p.name} completed "${def.title.en}".`, `أتمّ ${p.name} «${def.title.ar}».`) });
    } else if (def.fail && p.flags[def.fail.flag]) {
      q.status = 'failed'; q.ended = state.time; out.push({ quest: qid, status: 'failed' });
    }
  }
  return out;
}

// ------------------------------------------------------------ main entry
/**
 * Apply a list of proposed actions. Returns { results, worldEvents, quests, levelUps }.
 * Nothing outside this function mutates the game state during a turn.
 */
export function applyActions(state, actions) {
  placeNpcs(state);
  state._levelUps = [];
  const results = []; const worldEvents = [];
  for (const a of actions.slice(0, 4)) {
    const fn = R[a.type] || R.free;
    let res;
    try { res = fn(state, a); } catch (err) { res = { code: 'engine_error', ok: false, minutes: 0, fact: T('Something prevents that.', 'شيء ما يمنع ذلك.'), error: String(err?.message || err) }; }
    res.type = a.type;
    results.push(res);
    if (res.minutes) worldEvents.push(...advanceTime(state, res.minutes));
    else placeNpcs(state);
    if (res.code === 'defeated' || res.code === 'move_noroute') break;
  }
  const quests = checkQuests(state);
  state.turn++;
  const levelUps = state._levelUps; delete state._levelUps;
  return { results, worldEvents, quests, levelUps };
}
