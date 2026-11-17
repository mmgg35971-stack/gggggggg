// Offline intent parser (Arabic + English). Used when no AI server is
// reachable, and as a fast path. It turns free text into the same action
// shapes the AI interpreter produces, so the engine treats both identically.
import { NPCS, ITEMS, LOCATIONS } from './world.js';
import { resolveNpc, resolveItem, resolveLocation } from './engine.js';

export function detectLang(text) {
  const ar = (text.match(/[؀-ۿ]/g) || []).length;
  const la = (text.match(/[A-Za-z]/g) || []).length;
  return ar >= la ? 'ar' : 'en';
}
export function normalize(text) {
  return ' ' + String(text).toLowerCase()
    .replace(/[ً-ْـ]/g, '')
    .replace(/[إأآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه')
    .replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d))
    .replace(/[^\p{L}\p{N}\s"«»]/gu, ' ').replace(/\s+/g, ' ') + ' ';
}

// Ordered: earlier rules win when several match a clause.
const RULES = [
  ['meta', ['inventory', 'my status', 'stats', 'help me with commands', 'مخزوني', 'حالتي', 'ماذا احمل', 'ما معي']],
  ['attack', ['attack', 'hit ', 'strike', 'kill', 'fight', 'stab', 'punch', 'slash', 'shoot', 'هاجم', 'اهاجم', 'اضرب', 'اقتل', 'قاتل', 'اقاتل', 'اطعن', 'هجوم', 'اصوب', 'ارمي سهم']],
  ['social:bribe', ['bribe', 'ارشي', 'رشوه', 'ارشو', 'ارشيه']],
  ['social:intimidate', ['intimidate', 'threaten', 'scare', 'هدد', 'اهدد', 'ارهب', 'اخيف', 'تهديد']],
  ['social:deceive', ['lie to', 'deceive', 'trick', 'pretend', 'اكذب', 'اخدع', 'خداع', 'اتظاهر', 'احتال']],
  ['social:charm', ['charm', 'flatter', 'flirt', 'اغازل', 'اتملق', 'اجامل', 'امدح']],
  ['social:persuade', ['persuade', 'convince', 'negotiate', 'plead', 'اقنع', 'اقناع', 'اتفاوض', 'تفاوض', 'اترجي', 'اتوسل']],
  ['rent', ['rent', 'room for the night', 'room for tonight', 'استاجر', 'استئجار', 'اجار', 'غرفه للنوم', 'غرفه لليله']],
  ['buy', ['buy', 'purchase', 'order', 'اشتري', 'اشتر', 'شراء', 'اطلب']],
  ['sell', ['sell', 'ابيع', 'بيع ', ' بع ']],
  ['give', ['give', 'hand ', 'offer', 'pay ', 'اعطي', 'اعط', 'اهدي', 'اسلم', 'سلم ', 'ادفع', 'اقدم']],
  ['take', ['take', 'pick up', 'grab', 'loot', 'collect', 'خذ', 'اخذ', 'التقط', 'اجمع', 'احمل']],
  ['eat', ['eat', 'drink', 'have a meal', 'have some', 'اكل', 'اشرب', 'تناول', 'اتناول', 'اتغدي', 'اتعشي', 'افطر']],
  ['rest', ['sleep', 'rest', 'nap', 'انام', 'نوم', 'استريح', 'ارتاح', 'راحه', 'اغفو']],
  ['wait', ['wait', 'انتظر', 'اترقب']],
  ['use', ['use ', 'apply', 'bandage', 'heal', 'treat my', 'read ', 'استخدم', 'استعمل', 'عالج', 'اعالج', 'ضمد', 'اضمد', 'اقرا', 'افحص']],
  ['equip', ['equip', 'wield', 'wear', 'draw my', 'ارتدي', 'البس', 'اجهز', 'جهز', 'اشهر']],
  ['work', ['work', 'job', 'earn', 'اعمل', 'اشتغل', 'وظيفه', 'عمل ']],
  ['hunt', ['hunt', 'forage', 'trap', 'اصطاد', 'صيد', 'اقنص']],
  ['search', ['search', 'investigate', 'look for', 'inspect', 'explore', 'examine', 'dig', 'ابحث', 'فتش', 'افتش', 'تفحص', 'اتفحص', 'تحقق', 'اتحقق', 'استكشف', 'احفر', 'تحري']],
  ['move', ['go to', 'go ', 'walk', 'travel', 'head ', 'enter', 'leave', 'visit', 'return to', 'ride', 'اذهب', 'الذهاب', 'روح', 'اروح', 'امشي', 'سافر', 'السفر', 'ادخل', 'توجه', 'اتوجه', 'انتقل', 'زر ', 'ازور', 'ارجع', 'اعود', 'اغادر', 'غادر']],
  ['talk', ['talk', 'speak', 'ask', 'tell', 'say', 'greet', 'chat', 'tell me', 'تحدث', 'اتحدث', 'التحدث', 'كلم', 'اكلم', 'اسال', 'سوال', 'قل ', 'اقول', 'حدث', 'احيي', 'اخبر', 'احكي', 'اسولف', 'اتكلم']],
  ['look', ['look', 'observe', 'where am i', 'describe', 'around', 'انظر', 'تامل', 'اتامل', 'صف ', 'اين انا', 'حولي', 'اراقب', 'المح']]
];

const SKILL_HINTS = [
  ['stealth', ['sneak', 'hide', 'steal', 'pickpocket', 'quietly', 'اتسلل', 'اختبئ', 'اسرق', 'بهدوء', 'خلسه']],
  ['survival', ['climb', 'swim', 'track', 'cross', 'تسلق', 'اسبح', 'اتتبع', 'اعبر']],
  ['leadership', ['recruit', 'rally', 'lead', 'found a', 'mercenar', 'company', 'اجند', 'اقود', 'اسس', 'مرتزقه', 'جماعه']],
  ['trading', ['trade', 'haggle', 'invest', 'shop', 'business', 'merchant', 'تاجر', 'تجاره', 'اساوم', 'استثمر', 'متجر']],
  ['magic', ['spell', 'magic', 'ritual', 'سحر', 'تعويذه', 'طقس']],
  ['medicine', ['heal', 'cure', 'treat', 'اعالج', 'اشفي']],
  ['alchemy', ['brew', 'potion', 'mix', 'جرعه', 'اخلط', 'اقطر']],
  ['blacksmithing', ['forge', 'repair', 'smith', 'اصلح', 'اطرق', 'اصنع']],
  ['persuasion', ['join', 'marry', 'befriend', 'انضم', 'اتزوج', 'اصادق']]
];

const isLatin = (k) => /[a-z]/.test(k);
function keyHit(n, k) { return isLatin(k) ? n.includes(' ' + k.trimStart()) : n.includes(k); }
function verbOf(clause) {
  const n = normalize(clause);
  for (const [t, keys] of RULES) if (keys.some((k) => keyHit(n, k))) return t;
  return null;
}
// split "go to the tavern and talk to Hessa" / "اذهب للحانة واتحدث مع هيسا"
function splitConj(c) {
  const parts = c.split(/\s+and\s+|\s+و(?=\S)/i);
  if (parts.length < 2) return [c];
  const out = [parts[0]];
  for (let i = 1; i < parts.length; i++) {
    if (verbOf(parts[i])) out.push(parts[i]); else out[out.length - 1] += (/[a-z]/i.test(parts[i]) ? ' and ' : ' و') + parts[i];
  }
  return out;
}
function splitClauses(text) {
  const quotes = [];
  const masked = text.replace(/["«“](.+?)["»”]/g, (_, q) => { quotes.push(q); return ` __Q${quotes.length - 1}__ `; });
  return masked.split(/\bthen\b|\band then\b|\bafter that\b|ثم|بعدها|وبعد ذلك|[.;!?؟؛\n]+/i)
    .flatMap((c) => splitConj(c.trim())).map((c) => c.trim()).filter(Boolean)
    .map((c) => ({ text: c.replace(/__Q(\d+)__/g, (_, i) => `"${quotes[+i]}"`), quote: (c.match(/__Q(\d+)__/) || [])[1] !== undefined ? quotes[+c.match(/__Q(\d+)__/)[1]] : null }));
}

function findQty(n) {
  const m = n.match(/\b(\d{1,3})\b/);
  if (m) return parseInt(m[1], 10);
  const words = { ' one ': 1, ' two ': 2, ' three ': 3, ' five ': 5, ' ten ': 10, ' واحد ': 1, ' اثنين ': 2, ' اثنان ': 2, ' ثلاث ': 3, ' ثلاثه ': 3, ' خمس ': 5, ' عشر ': 10, ' عشره ': 10, ' عشرين ': 20, ' اربعين ': 40, ' ثلاثين ': 30 };
  for (const [w, v] of Object.entries(words)) if (n.includes(w)) return v;
  return null;
}

function hoursIn(n) {
  const m = n.match(/(\d{1,2})\s*(hour|hours|h|ساعه|ساعات)/);
  if (m) return parseInt(m[1], 10);
  if (/until morning|till dawn|all night|حتي الصباح|طوال الليل|حتي الفجر/.test(n)) return 8;
  return null;
}

function blank(type) { return { type, npc: null, item: null, qty: null, destination: null, approach: null, topic: null, utterance: null, skill: null, difficulty: null, hours: null, description: null }; }

const FANTASY = /\b(fly|flies|flying|teleport|dragon)\b|اطير|انتقل فورا|تنين/;
export function parseIntent(state, text) {
  const lang = detectLang(text);
  const actions = [];
  for (const clause of splitClauses(text).slice(0, 4)) {
    const n = normalize(clause.text);
    let type = null; let approach = null;
    for (const [t, keys] of RULES) {
      if (keys.some((k) => keyHit(n, k))) { [type, approach] = t.split(':'); break; }
    }
    const npc = resolveNpc(state, clause.text, { presentOnly: false });
    const presentNpc = resolveNpc(state, clause.text);
    const loc = resolveLocation(clause.text);
    const item = resolveItem(clause.text);
    if (clause.quote && !type) type = 'talk';
    if (!type) type = presentNpc ? 'talk' : loc && loc !== state.player.location ? 'move' : 'free';
    if (FANTASY.test(n)) type = 'free'; // "fly to the keep" is not a walk to the keep
    // "go to X and talk to Y" style: a talk clause naming a non-present NPC whose location is named -> move
    if (type === 'look' && (n.includes(' for ') || n.includes(' عن '))) type = 'search';
    const a = blank(type);
    a.approach = approach || null;
    a.npc = npc || null;
    a.item = item || null;
    a.destination = type === 'move' ? loc : null;
    a.qty = findQty(n);
    a.hours = hoursIn(n);
    a.utterance = clause.quote || (['talk', 'social'].includes(type) ? clause.text : null);
    a.topic = ['talk', 'social'].includes(type) ? clause.text : null;
    a.description = clause.text;
    if (type === 'rest' && !a.hours) a.hours = /nap|قيلوله|اغفو/.test(n) ? 2 : 8;
    if (type === 'free') {
      for (const [skill, keys] of SKILL_HINTS) if (keys.some((k) => n.includes(k))) { a.skill = skill; break; }
      a.difficulty = /found|establish|army|kingdom|king|marry|اسس|جيش|مملكه|ملك|اتزوج/.test(n) ? 'very_hard' : FANTASY.test(n) ? 'impossible' : /climb|steal|sneak|persuade|break|force|تسلق|اسرق|اتسلل|اكسر/.test(n) || a.skill ? 'medium' : 'trivial';
    }
    // Buying food and immediately eating it is one 'eat' action
    if (type === 'buy' && item && ['food', 'drink'].includes(ITEMS[item]?.type) && /eat|drink|اكل|اشرب|اتناول/.test(n)) a.type = 'eat';
    actions.push(a);
  }
  if (!actions.length) actions.push(blank('look'));
  return { language: lang, in_character: true, actions };
}

export const _test = { splitClauses, normalize, NPCS, LOCATIONS };
