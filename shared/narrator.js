// Offline narrator: turns engine results into readable prose without an AI.
// Also provides helpers used by both narrators to turn results into chat
// messages (events, quest updates, level-ups) so the UI is identical.
import { LOCATIONS, NPCS, QUESTS, SKILL_NAMES } from './world.js';
import { L, timeInfo, TIME_WORDS, WEATHER, npcName, npcsAt, attitudeBand, pick, locName } from './state.js';

const ATMOS = {
  dawn: { en: ['Grey light seeps over the thatch.', 'The first cocks crow somewhere behind the houses.'], ar: ['يتسلّل ضوء رمادي فوق سقوف القش.', 'تصيح أولى الديكة في مكان ما خلف البيوت.'] },
  morning: { en: ['The day has properly begun; carts creak and someone is beating a rug.', 'Morning smoke rises straight from the chimneys.'], ar: ['بدأ النهار حقاً؛ تصرّ العربات وأحدهم ينفض بساطاً.', 'يرتفع دخان الصباح مستقيماً من المداخن.'] },
  afternoon: { en: ['The afternoon drags, heavy and damp.', 'Shadows lengthen across the mud.'], ar: ['يمضي العصر ثقيلاً رطباً.', 'تطول الظلال على الوحل.'] },
  evening: { en: ['Lamps are being lit one by one.', 'The evening brings the smell of woodsmoke and cooking.'], ar: ['تُشعل المصابيح واحداً تلو الآخر.', 'يحمل المساء رائحة دخان الحطب والطبخ.'] },
  night: { en: ['It is full dark; only a few windows still glow.', 'Night has the vale; somewhere a dog will not stop barking.'], ar: ['الظلام دامس؛ وحدها نوافذ قليلة ما زالت تتوهّج.', 'الليل يطبق على الوادي؛ وكلب في مكان ما لا يكفّ عن النباح.'] }
};
const TRAVEL = {
  en: ['You set off.', 'You pull your cloak tighter and go.', 'The road takes you.'],
  ar: ['تنطلق في طريقك.', 'تشدّ عباءتك حولك وتمضي.', 'يأخذك الطريق.']
};
const SPEAK_FRAME = {
  hostile: { en: ['{n} glares at you.', '{n} does not hide the contempt.'], ar: ['يحدجك {n} بنظرة غاضبة.', 'لا يخفي {n} احتقاره.'] },
  cold: { en: ['{n} looks you over without warmth.', '{n} answers without looking up.'], ar: ['يتفحّصك {n} بلا دفء.', 'يجيب {n} دون أن يرفع عينيه.'] },
  neutral: { en: ['{n} turns to you.', '{n} pauses what they are doing.'], ar: ['يلتفت {n} إليك.', 'يتوقّف {n} عمّا يفعله.'] },
  warm: { en: ['{n} brightens when they see you.', '{n} leans in, glad of the company.'], ar: ['يشرق وجه {n} حين يراك.', 'يميل {n} نحوك، مسروراً بالرفقة.'] }
};
// Arabic verbs agree with the speaker: feminine forms of the frames above.
const SPEAK_FRAME_AR_F = {
  hostile: ['تحدجك {n} بنظرة غاضبة.', 'لا تخفي {n} احتقارها.'],
  cold: ['تتفحّصك {n} بلا دفء.', 'تجيب {n} دون أن ترفع عينيها.'],
  neutral: ['تلتفت {n} إليك.', 'تتوقّف {n} عمّا تفعله.'],
  warm: ['يشرق وجه {n} حين تراك.', 'تميل {n} نحوك، مسرورةً بالرفقة.']
};
/** NPC lines are written addressing a man; switch the endearments when the player chose "woman". */
export function addressPlayer(state, text, lang) {
  if (lang !== 'ar' || state.player.gender !== 'female') return text;
  return text.replace(/عزيزي/g, 'عزيزتي').replace(/يا صديقي/g, 'يا صديقتي').replace(/يا فتى/g, 'يا فتاة').replace(/يا رجل/g, 'يا امرأة');
}

function arrival(state, res, lang) {
  const loc = LOCATIONS[res.destination];
  const ti = timeInfo(state.time);
  const parts = [];
  parts.push(res.fact[lang].replace(/\s*\(\d+ (min|دقيقة)\)\.?$/, '.'));
  if (res.firstVisit) parts.push(L(loc.desc, lang));
  else parts.push(lang === 'ar' ? `${L(loc.name, lang)}، كما تركتها.` : `${L(loc.name, lang)}, much as you left it.`);
  parts.push(pick(state, ATMOS[ti.part][lang]) + ' ' + (lang === 'ar' ? `الجوّ: ${L(WEATHER[state.world.weather], lang)}.` : `Weather: ${L(WEATHER[state.world.weather], lang)}.`));
  const present = npcsAt(state, res.destination);
  if (present.length) parts.push((lang === 'ar' ? 'هنا: ' : 'Here: ') + present.map((id) => lang === 'ar' ? `${npcName(id, lang)}، ${L(NPCS[id].role, lang)}` : `${npcName(id, lang)} (${L(NPCS[id].role, lang)})`).join(lang === 'ar' ? '؛ ' : ', ') + '.');
  return parts.join(' ');
}

function freeText(res, lang) {
  const d = res.description || '';
  if (res.code === 'free_impossible') return res.fact[lang];
  const c = res.check;
  if (lang === 'ar') return res.ok ? (c?.dc <= 5 ? `${d}.` : `تحاول: ${d}. ${c?.crit ? 'وينجح ذلك على نحو يفوق ما توقّعت.' : 'وينجح الأمر.'}`) : `تحاول: ${d}. ${c?.fumble ? 'وينقلب الأمر عليك بشكل سيّئ.' : 'لكن الأمر لا يسير كما أردت.'}`;
  return res.ok ? (c?.dc <= 5 ? `${d}.` : `You try: ${d}. ${c?.crit ? 'It goes better than you dared hope.' : 'It works.'}`) : `You try: ${d}. ${c?.fumble ? 'It goes badly wrong.' : 'It does not go the way you wanted.'}`;
}

/** Offline narration: returns chat messages for one turn. */
export function narrateOffline(state, turn, lang) {
  const msgs = [];
  const prose = [];
  for (const res of turn.results) {
    if (res.code === 'move') prose.push(arrival(state, res, lang));
    else if (res.code === 'free' || res.code === 'free_impossible') prose.push(freeText(res, lang));
    else if (['talk', 'talk_guarded', 'talk_refused', 'social'].includes(res.code) && res.line) {
      const band = attitudeBand(state.npcs[res.npc].attitude);
      const frame = pick(state, lang === 'ar' && NPCS[res.npc].female ? SPEAK_FRAME_AR_F[band] : SPEAK_FRAME[band][lang]).replace('{n}', npcName(res.npc, lang));
      prose.push(res.code === 'social' ? res.fact[lang] + ' ' + frame : frame);
      if (res.code === 'talk_guarded') prose.push(res.fact[lang]);
      flush();
      msgs.push({ role: 'npc', speaker: res.npc, text: addressPlayer(state, L(res.line.text, lang), lang) });
      continue;
    } else prose.push(res.fact[lang]);
    if (res.line && !['talk', 'talk_guarded', 'talk_refused', 'social'].includes(res.code)) { flush(); msgs.push({ role: 'npc', speaker: res.line.npc, text: addressPlayer(state, L(res.line.text, lang), lang) }); }
    if (res.reveal) { flush(); msgs.push({ role: 'discovery', text: L(res.reveal, lang) }); }
  }
  flush();
  msgs.push(...systemMessages(state, turn, lang));
  return msgs;
  function flush() { if (prose.length) { msgs.push({ role: 'narrator', text: prose.join(' ') }); prose.length = 0; } }
}

/** Messages both narrators append: world events heard about, quests, level-ups. */
export function systemMessages(state, turn, lang) {
  const msgs = [];
  const here = LOCATIONS[state.player.location];
  for (const e of turn.worldEvents || []) {
    // the player only learns of world events that happen nearby or are big news
    const near = e.location && LOCATIONS[e.location]?.region === here.region;
    if (e.importance >= 3 || near) msgs.push({ role: 'event', text: L(e.text, lang) });
  }
  for (const q of turn.quests || []) {
    const d = QUESTS[q.quest];
    msgs.push({ role: 'event', text: lang === 'ar' ? `${q.status === 'done' ? 'اكتملت المهمة' : 'فشلت المهمة'}: ${L(d.title, lang)}${q.reward ? ` (+${q.reward} فضة)` : ''}` : `Quest ${q.status === 'done' ? 'completed' : 'failed'}: ${L(d.title, lang)}${q.reward ? ` (+${q.reward} silver)` : ''}` });
  }
  for (const r of turn.results) if (r.quest) msgs.push({ role: 'event', text: lang === 'ar' ? `مهمة جديدة في دفترك: ${L(QUESTS[r.quest].title, lang)}` : `New entry in your journal: ${L(QUESTS[r.quest].title, lang)}` });
  for (const u of turn.levelUps || []) {
    if (u.level) msgs.push({ role: 'system', text: lang === 'ar' ? `ارتقيت إلى المستوى ${u.level}.` : `You reached level ${u.level}.` });
    else msgs.push({ role: 'system', text: lang === 'ar' ? `تحسّنت مهارة ${L(SKILL_NAMES[u.skill], lang)} إلى ${u.lvl}.` : `${L(SKILL_NAMES[u.skill], lang)} improved to ${u.lvl}.` });
  }
  return msgs;
}

/** Opening scene for a new chronicle. */
export function openingScene(state, lang) {
  const p = state.player; const loc = LOCATIONS[p.location];
  const ti = timeInfo(state.time);
  const present = npcsAt(state, p.location);
  const text = lang === 'ar'
    ? `${L(TIME_WORDS[ti.season], lang)}، اليوم الأول. ${L(TIME_WORDS[ti.part], lang)} في وادي الغسق، و${L(WEATHER[state.world.weather], lang)} تنقر على النوافذ.\n\nوصلت إلى قرية ميرفولد بلا خطة سوى أن تبدأ من جديد. ${L(loc.desc, lang)}\n\n${present.length ? 'حولك: ' + present.map((id) => npcName(id, lang)).join('، ') + '.' : ''}\n\nلا أحد ينتظرك هنا، ولا قدر مكتوب. ما تفعله من الآن هو قصتك. اكتب ما تريد فعله.`
    : `Spring, the first day. ${L(TIME_WORDS[ti.part], lang)[0].toUpperCase() + L(TIME_WORDS[ti.part], lang).slice(1)} in the Dimmering Vale, and ${L(WEATHER[state.world.weather], lang)} taps at the shutters.\n\nYou have come to Mirefold with no plan but to begin again. ${L(loc.desc, lang)}\n\n${present.length ? 'Around you: ' + present.map((id) => npcName(id, lang)).join(', ') + '.' : ''}\n\nNo one is waiting for you here, and no fate is written. What you do from now on is your story. Write what you want to do.`;
  return [{ role: 'narrator', text }];
}

/** Message shown when the player returns after being away. */
export function absenceMessages(catch_, lang) {
  if (!catch_.hours) return [];
  const msgs = [{ role: 'system', text: lang === 'ar' ? `مضت ${catch_.hours} ساعة في العالم أثناء غيابك.` : `${catch_.hours} hours passed in the world while you were away.` }];
  for (const e of catch_.events.filter((x) => x.importance >= 2).slice(-6)) msgs.push({ role: 'event', text: L(e.text, lang) });
  return msgs;
}

export { locName };
