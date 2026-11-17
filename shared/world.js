// World seed: "The Dimmering Vale" in the Kingdom of Varrowmark.
// Original setting written for this game. Every entry is bilingual {en, ar}.
// This file is DATA ONLY. Runtime state lives in state.js and is created from it.
//
// Design notes (following the Story Bible master prompt):
// - Nothing here is "the main quest". Secrets, NPC goals and world pressures
//   exist on their own; the player can engage with them or ignore them.
// - Hidden content (locations, facts) is gated by checks, attitude or flags,
//   so the player has to discover it.

export const WORLD_META = {
  name: { en: 'The Dimmering Vale', ar: 'وادي الغَسَق' },
  realm: { en: 'Kingdom of Varrowmark', ar: 'مملكة فارومارك' },
  era: { en: 'Year 1147 of the Ashen Reckoning', ar: 'العام 1147 من التقويم الرمادي' },
  startYear: 1147,
  currency: { en: 'silver', ar: 'فضة' },
  premise: {
    en: 'A damp river vale on the southern march of Varrowmark. Forty years after the Glass War burned the old Sarithi ruins, the vale lives on barley, pelts and the trade road to Corvane. The crown is far away, the bandits are close, and people whisper that something under the ruins still remembers.',
    ar: 'وادٍ رطب على التخوم الجنوبية لمملكة فارومارك. بعد أربعين عاماً من حرب الزجاج التي أحرقت أطلال الساريثيين القديمة، يعيش الوادي على الشعير والجلود وطريق التجارة إلى كورفان. التاج بعيد، وقطّاع الطرق قريبون، والناس يتهامسون بأن شيئاً تحت الأطلال ما زال يتذكّر.'
  },
  lore: [
    { id: 'glass_war', en: 'The Glass War (1102-1107) ended when the Sarithi city of Vael Sarith burned. Varrowmark calls it a liberation; the vale folk call it the year the sky rained cinders.', ar: 'انتهت حرب الزجاج (1102-1107) باحتراق مدينة فايل ساريث الساريثية. تسمّيها فارومارك تحريراً، ويسمّيها أهل الوادي عامَ أمطرت السماء جمراً.' },
    { id: 'ashen_mother', en: 'The Ashen Mother is the vale\'s faith: she gathers the dead into her grey cloak so they can rest. Her priests forbid digging in the ruins.', ar: 'الأم الرمادية هي عقيدة الوادي: تجمع الموتى في عباءتها الرمادية كي يستريحوا. ويحرّم كهنتها الحفر في الأطلال.' },
    { id: 'grey_ledger', en: 'The Grey Ledger is a merchant guild that lends money to half the vale and keeps the other half in its books.', ar: 'السجلّ الرمادي نقابة تجّار تُقرض نصف الوادي وتُبقي النصف الآخر في دفاترها.' }
  ]
};

// ---------------------------------------------------------------- factions
export const FACTIONS = {
  crown: { name: { en: 'Crown of Varrowmark', ar: 'تاج فارومارك' }, power: 70, ideology: { en: 'Order through law and levy.', ar: 'النظام عبر القانون والجباية.' } },
  dravell: { name: { en: 'House Dravell', ar: 'آل درافيل' }, power: 55, ideology: { en: 'Noble lords of Corvane; blood before coin.', ar: 'سادة كورفان النبلاء؛ الدم قبل المال.' } },
  church: { name: { en: 'Chapel of the Ashen Mother', ar: 'كنيسة الأم الرمادية' }, power: 45, ideology: { en: 'Let the dead rest; leave the ruins buried.', ar: 'دعوا الموتى يستريحون؛ اتركوا الأطلال مدفونة.' } },
  ledger: { name: { en: 'The Grey Ledger', ar: 'السجلّ الرمادي' }, power: 60, ideology: { en: 'Every debt is a promise; every promise has a price.', ar: 'كل دَين وعد، ولكل وعد ثمن.' } },
  fenrats: { name: { en: 'The Fen Rats', ar: 'جرذان المستنقع' }, power: 35, ideology: { en: 'The road belongs to whoever holds it.', ar: 'الطريق لمن يمسكه.' } },
  unlit: { name: { en: 'The Unlit', ar: 'المُطفَؤون' }, power: 20, secret: true, ideology: { en: 'The Sarithi were not monsters; their glass remembers truths the crown burned.', ar: 'لم يكن الساريثيون وحوشاً؛ زجاجهم يتذكّر حقائق أحرقها التاج.' } },
  vale: { name: { en: 'Vale Folk', ar: 'أهل الوادي' }, power: 30, ideology: { en: 'Keep your head down and your barley dry.', ar: 'اخفض رأسك وأبقِ شعيرك جافاً.' } }
};

// ---------------------------------------------------------------- items
// price in silver. type: food|drink|weapon|armor|shield|tool|material|relic|clue|medicine
export const ITEMS = {
  bread: { name: { en: 'loaf of black bread', ar: 'رغيف خبز أسود' }, type: 'food', price: 1, food: 25, aliases: ['bread', 'loaf', 'خبز', 'رغيف'] },
  stew: { name: { en: 'bowl of barley stew', ar: 'وعاء حساء شعير' }, type: 'food', price: 3, food: 45, aliases: ['stew', 'soup', 'meal', 'food', 'حساء', 'شوربة', 'طعام', 'وجبة', 'اكل', 'أكل'] },
  ale: { name: { en: 'mug of ale', ar: 'كوب جعة' }, type: 'drink', price: 1, food: 5, aliases: ['ale', 'beer', 'drink', 'جعة', 'بيرة', 'شراب', 'مشروب'] },
  cider: { name: { en: 'cup of pear cider', ar: 'كوب عصير كمثرى' }, type: 'drink', price: 1, food: 8, aliases: ['cider', 'juice', 'عصير', 'كمثرى'] },
  torch: { name: { en: 'pitch torch', ar: 'مشعل قار' }, type: 'tool', price: 1, aliases: ['torch', 'مشعل', 'شعلة'] },
  rope: { name: { en: 'coil of hemp rope', ar: 'لفّة حبل قنّب' }, type: 'tool', price: 2, aliases: ['rope', 'حبل'] },
  dagger: { name: { en: 'iron dagger', ar: 'خنجر حديدي' }, type: 'weapon', price: 8, dmg: [1, 4], skill: 'swordsmanship', aliases: ['dagger', 'knife', 'خنجر', 'سكين'] },
  short_sword: { name: { en: 'short sword', ar: 'سيف قصير' }, type: 'weapon', price: 25, dmg: [2, 6], skill: 'swordsmanship', aliases: ['short sword', 'sword', 'سيف قصير', 'سيف'] },
  longsword: { name: { en: 'Kael longsword', ar: 'سيف كايل الطويل' }, type: 'weapon', price: 60, dmg: [3, 8], skill: 'swordsmanship', aliases: ['longsword', 'long sword', 'سيف طويل'] },
  hunting_bow: { name: { en: 'yew hunting bow', ar: 'قوس صيد من الطقسوس' }, type: 'weapon', price: 30, dmg: [2, 6], skill: 'archery', ranged: true, aliases: ['bow', 'hunting bow', 'قوس'] },
  cudgel: { name: { en: 'oak cudgel', ar: 'هراوة بلوط' }, type: 'weapon', price: 3, dmg: [1, 5], skill: 'swordsmanship', aliases: ['cudgel', 'club', 'هراوة', 'عصا'] },
  leather_armor: { name: { en: 'boiled leather jerkin', ar: 'سترة جلد مقسّى' }, type: 'armor', price: 30, armor: 2, aliases: ['leather', 'jerkin', 'leather armor', 'جلد', 'سترة', 'درع جلد'] },
  chainmail: { name: { en: 'riveted mail shirt', ar: 'قميص زرد مبرشم' }, type: 'armor', price: 120, armor: 4, aliases: ['mail', 'chainmail', 'chain mail', 'زرد', 'درع زرد'] },
  shield: { name: { en: 'round shield', ar: 'ترس مستدير' }, type: 'shield', price: 15, armor: 1, aliases: ['shield', 'ترس', 'درع خشب'] },
  healing_herbs: { name: { en: 'bundle of feverwort', ar: 'حزمة عشبة الحمّى' }, type: 'medicine', price: 5, heal: 8, aliases: ['herbs', 'feverwort', 'medicine', 'أعشاب', 'عشب', 'دواء'] },
  bandage: { name: { en: 'linen bandage', ar: 'ضماد كتّان' }, type: 'medicine', price: 2, heal: 4, aliases: ['bandage', 'ضماد', 'رباط'] },
  lockpick: { name: { en: 'set of lockpicks', ar: 'طقم مفاتيح فتح الأقفال' }, type: 'tool', price: 6, aliases: ['lockpick', 'lockpicks', 'picks', 'مفاتيح', 'أداة فتح'] },
  wolf_pelt: { name: { en: 'wolf pelt', ar: 'جلد ذئب' }, type: 'material', price: 6, aliases: ['pelt', 'wolf pelt', 'fur', 'جلد ذئب', 'فرو'] },
  barley_sack: { name: { en: 'sack of barley', ar: 'كيس شعير' }, type: 'material', price: 4, aliases: ['barley', 'sack', 'شعير', 'كيس'] },
  sarith_glass: { name: { en: 'shard of Sarithi glass', ar: 'شظية زجاج ساريثي' }, type: 'relic', price: 40, aliases: ['glass', 'shard', 'relic', 'sarithi glass', 'زجاج', 'شظية', 'أثر'] },
  ledger_page: { name: { en: 'torn ledger page with an unlit-candle sigil', ar: 'صفحة دفتر ممزقة عليها ختم شمعة مطفأة' }, type: 'clue', price: 0, aliases: ['page', 'ledger', 'paper', 'صفحة', 'ورقة', 'دفتر'] },
  lio_satchel: { name: { en: 'Lio\'s muddy satchel', ar: 'حقيبة ليو الموحلة' }, type: 'clue', price: 0, aliases: ['satchel', 'bag', 'حقيبة', 'كيس ليو'] },
  writ_of_passage: { name: { en: 'writ of passage to Corvane', ar: 'تصريح مرور إلى كورفان' }, type: 'tool', price: 10, aliases: ['writ', 'pass', 'permit', 'تصريح', 'إذن'] }
};

// ---------------------------------------------------------------- locations
// exits: [{ to, minutes, hidden?: flagName }]   hidden exits appear once flag is set
// features: searchable hidden things. { id, dc, flag, reveal:{en,ar}, item? }
// settlement: which community's reputation is affected by acts here.
export const LOCATIONS = {
  mirefold_square: {
    name: { en: 'Mirefold village square', ar: 'ساحة قرية ميرفولد' }, region: 'vale', type: 'village', settlement: 'mirefold', music: 'village',
    aliases: ['square', 'village', 'mirefold', 'ساحة', 'القرية', 'ميرفولد', 'الساحة'],
    desc: { en: 'A muddy square ringed by thatched houses and a leaning well. A crooked shrine to the Ashen Mother stands by the well, its grey ribbons limp with rain. Smoke from the forge and the smell of stew from the tavern mix in the wet air.', ar: 'ساحة موحلة تحيط بها بيوت سقوفها من القش وبئر مائلة. بجانب البئر مزار معوجّ للأم الرمادية، أشرطته الرمادية مرتخية من المطر. يختلط دخان المسبك برائحة الحساء القادمة من الحانة في الهواء الرطب.' },
    exits: [{ to: 'sunken_lantern', minutes: 2 }, { to: 'kael_forge', minutes: 2 }, { to: 'chapel_ashen', minutes: 3 }, { to: 'old_mill', minutes: 10 }, { to: 'south_road', minutes: 8 }],
    features: [{ id: 'well_carving', dc: 11, flag: 'saw_well_carving', reveal: { en: 'Under the moss on the well stones someone has scratched a small candle with no flame, fresh cuts in old stone.', ar: 'تحت الطحلب على حجارة البئر خدش أحدهم شمعة صغيرة بلا لهب، خدوش حديثة في حجر قديم.' } }]
  },
  sunken_lantern: {
    name: { en: 'The Sunken Lantern tavern', ar: 'حانة الفانوس الغارق' }, region: 'vale', type: 'tavern', settlement: 'mirefold', music: 'tavern',
    aliases: ['tavern', 'inn', 'lantern', 'sunken lantern', 'pub', 'حانة', 'الحانة', 'نزل', 'الفانوس', 'خمارة'],
    desc: { en: 'Low beams black with a century of smoke, a hearth big enough to roast a calf, and a lantern of green glass hanging over the bar that gives the place its name. Benches are worn smooth. A board by the door holds notices and debts.', ar: 'عوارض منخفضة سوّدها دخان قرن كامل، وموقد يتّسع لشواء عجل، وفانوس من زجاج أخضر معلّق فوق المشرب يمنح المكان اسمه. المقاعد ملساء من كثرة الجلوس، ولوح بجانب الباب تُعلّق عليه الإعلانات والديون.' },
    exits: [{ to: 'mirefold_square', minutes: 2 }],
    services: { room: 4, sells: ['bread', 'stew', 'ale', 'cider', 'torch'] , seller: 'hessa' },
    features: [{ id: 'notice_board', dc: 6, flag: 'read_notice_board', reveal: { en: 'Among the notices: "MISSING: Lio, apprentice to Tobin Marle, 17 winters, red hair. Last seen on the south road nine days past. Reward." Below it, a Grey Ledger notice of debts owed by the Sunken Lantern.', ar: 'بين الإعلانات: «مفقود: ليو، صبيّ التاجر توبن مارل، سبعة عشر شتاءً، شعر أحمر. شوهد آخر مرة على الطريق الجنوبي قبل تسعة أيام. مكافأة.» وتحته إشعار من السجلّ الرمادي بديون مستحقة على حانة الفانوس الغارق.' } }]
  },
  kael_forge: {
    name: { en: 'Kael\'s forge', ar: 'مسبك كايل' }, region: 'vale', type: 'smithy', settlement: 'mirefold', music: 'village',
    aliases: ['forge', 'smithy', 'blacksmith', 'smith', 'مسبك', 'الحداد', 'حدادة', 'ورشة'],
    desc: { en: 'An open-sided forge under a sod roof. The anvil is older than the village; the bellows wheeze like an old dog. Blades in various states of becoming hang from pegs.', ar: 'مسبك مفتوح الجوانب تحت سقف من العشب. السندان أقدم من القرية، والمنفاخ يلهث كالكلب العجوز. نصال في مراحل مختلفة من الصنع معلّقة على الأوتاد.' },
    exits: [{ to: 'mirefold_square', minutes: 2 }],
    services: { sells: ['dagger', 'short_sword', 'longsword', 'cudgel', 'leather_armor', 'chainmail', 'shield', 'rope', 'lockpick'], seller: 'oswin', buys: ['weapon', 'armor', 'shield', 'material'] }
  },
  chapel_ashen: {
    name: { en: 'Chapel of the Ashen Mother', ar: 'كنيسة الأم الرمادية' }, region: 'vale', type: 'temple', settlement: 'mirefold', music: 'temple',
    aliases: ['chapel', 'church', 'temple', 'shrine', 'كنيسة', 'معبد', 'الكنيسة', 'المعبد', 'مصلى'],
    desc: { en: 'A narrow stone chapel smelling of tallow and wet ash. Grey veils hang behind the altar, one for every family that lost someone in the Glass War. Candles burn in rows; one niche holds a candle that is never lit.', ar: 'كنيسة حجرية ضيقة تفوح منها رائحة الشحم والرماد الرطب. خلف المذبح ستائر رمادية، واحدة لكل عائلة فقدت أحداً في حرب الزجاج. تشتعل الشموع صفوفاً، وفي إحدى الكوّات شمعة لا تُشعل أبداً.' },
    exits: [{ to: 'mirefold_square', minutes: 3 }],
    services: { sells: ['healing_herbs', 'bandage'], seller: 'ilvane' }
  },
  old_mill: {
    name: { en: 'Garrow\'s watermill', ar: 'طاحونة غارو المائية' }, region: 'vale', type: 'village', settlement: 'mirefold', music: 'village',
    aliases: ['mill', 'watermill', 'miller', 'طاحونة', 'الطاحونة', 'مطحنة'],
    desc: { en: 'A tall timber mill on the brown Mire stream, its wheel groaning. Flour dust hangs in shafts of light. Sacks of barley are stacked against a trapdoor that someone has taken care to cover.', ar: 'طاحونة خشبية عالية على جدول المستنقع البنّي، عجلتها تئن. غبار الطحين معلّق في أشعة الضوء. أكياس الشعير مكدّسة فوق باب أرضيّ حرص أحدهم على تغطيته.' },
    exits: [{ to: 'mirefold_square', minutes: 10 }, { to: 'mill_cellar', minutes: 1, hidden: 'found_mill_cellar' }],
    services: { sells: ['barley_sack', 'bread'], seller: 'garrow' },
    features: [{ id: 'trapdoor', dc: 13, flag: 'found_mill_cellar', reveal: { en: 'Behind the barley sacks your fingers find an iron ring: a trapdoor, its hinges recently oiled.', ar: 'خلف أكياس الشعير تجد أصابعك حلقة حديدية: باب أرضيّ مفصّلاته مدهونة حديثاً.' } }]
  },
  mill_cellar: {
    name: { en: 'The cellar beneath the mill', ar: 'القبو تحت الطاحونة' }, region: 'vale', type: 'ruin', settlement: 'mirefold', music: 'ruins', hiddenLocation: true,
    aliases: ['cellar', 'basement', 'trapdoor', 'قبو', 'القبو', 'سرداب'],
    desc: { en: 'A damp cellar cut into older stone than the mill above. Straw-packed crates line the walls. In one, wrapped in wool, are pieces of glass that catch your candle and hold it a moment too long.', ar: 'قبو رطب محفور في حجر أقدم من الطاحونة فوقه. صناديق محشوّة بالقش على طول الجدران، وفي أحدها قطع زجاج ملفوفة بالصوف تلتقط ضوء شمعتك وتمسكه لحظة أطول مما ينبغي.' },
    exits: [{ to: 'old_mill', minutes: 1 }],
    loot: [{ item: 'sarith_glass', qty: 2 }, { item: 'ledger_page', qty: 1 }],
    features: [{ id: 'cellar_crates', dc: 8, flag: 'saw_cellar_crates', reveal: { en: 'Shipping marks on the crates: "Corvane, Q." and a candle with no flame.', ar: 'علامات شحن على الصناديق: «كورفان، ك.» وشمعة بلا لهب.' } }]
  },
  south_road: {
    name: { en: 'The south road crossroads', ar: 'مفترق الطريق الجنوبي' }, region: 'vale', type: 'wild', settlement: null, music: 'wilds', danger: 1,
    aliases: ['road', 'crossroads', 'south road', 'طريق', 'الطريق', 'المفترق', 'مفترق'],
    desc: { en: 'A gibbet-less crossroads where the Mirefold track meets the old trade road. A weathered milestone points south to Corvane, east into the dark mass of Blackfen, and west toward the burnt hill of Vael Sarith.', ar: 'مفترق طرق حيث يلتقي درب ميرفولد بطريق التجارة القديم. حجر مسافات متآكل يشير جنوباً إلى كورفان، وشرقاً إلى كتلة غابة بلاكفن المظلمة، وغرباً نحو التلّ المحترق لفايل ساريث.' },
    exits: [{ to: 'mirefold_square', minutes: 8 }, { to: 'blackfen', minutes: 60 }, { to: 'vael_sarith', minutes: 120 }, { to: 'corvane_gate', minutes: 240 }],
    features: [{ id: 'cart_tracks', dc: 12, flag: 'saw_cart_tracks', reveal: { en: 'Deep cart ruts turn off the road toward Blackfen where no cart has reason to go, and there are boot prints on both sides of them.', ar: 'آثار عجلات عربة عميقة تنحرف عن الطريق نحو بلاكفن حيث لا سبب لذهاب أي عربة، وعلى جانبيها آثار أحذية.' } }]
  },
  blackfen: {
    name: { en: 'Blackfen woods', ar: 'غابة بلاكفن' }, region: 'vale', type: 'forest', settlement: null, music: 'wilds', danger: 2,
    aliases: ['blackfen', 'woods', 'forest', 'fen', 'غابة', 'الغابة', 'بلاكفن', 'المستنقع'],
    desc: { en: 'Black alder and drowned oak rise from peat water. Mist lies in the hollows; every sound arrives late. Hunters\' blazes on the trees fade after the first mile.', ar: 'أشجار جار الماء السوداء والبلوط الغارق ترتفع من مياه الخثّ. يستقرّ الضباب في المنخفضات، وكل صوت يصل متأخراً. علامات الصيادين على الأشجار تختفي بعد الميل الأول.' },
    exits: [{ to: 'south_road', minutes: 60 }, { to: 'blackfen_camp', minutes: 40, hidden: 'found_bandit_camp' }],
    forage: { item: 'wolf_pelt', skill: 'hunting', dc: 13 },
    features: [{ id: 'camp_smoke', dc: 14, flag: 'found_bandit_camp', reveal: { en: 'Following the cart ruts and a thread of smoke, you find a path of laid logs across the bog leading deeper in: someone lives out there.', ar: 'بتتبّع آثار العربة وخيط من الدخان، تجد ممراً من جذوع مرصوفة فوق المستنقع يقود إلى الداخل: أحدهم يعيش هناك.' } }]
  },
  blackfen_camp: {
    name: { en: 'Fen Rat camp', ar: 'معسكر جرذان المستنقع' }, region: 'vale', type: 'camp', settlement: 'fenrats', music: 'danger', danger: 3, hiddenLocation: true,
    aliases: ['camp', 'bandit camp', 'bandits', 'معسكر', 'المعسكر', 'معسكر اللصوص'],
    desc: { en: 'A ring of hide tents on an island of firm ground, a palisade of sharpened stakes, and a pit where three men dig into older stone. A boy with red hair works chained to a post.', ar: 'حلقة من خيام الجلد على جزيرة من أرض صلبة، وسياج من أوتاد مدبّبة، وحفرة يحفر فيها ثلاثة رجال في حجر أقدم. صبيّ أحمر الشعر يعمل مقيّداً بسلسلة إلى عمود.' },
    exits: [{ to: 'blackfen', minutes: 40 }]
  },
  vael_sarith: {
    name: { en: 'Ruins of Vael Sarith', ar: 'أطلال فايل ساريث' }, region: 'vale', type: 'ruin', settlement: null, music: 'ruins', danger: 2,
    aliases: ['ruins', 'vael sarith', 'sarith', 'أطلال', 'الأطلال', 'ساريث', 'فايل'],
    desc: { en: 'A hill of fused black glass and broken columns. Rain runs in channels the Sarithi carved for it four hundred years ago. When the wind turns, the glass hums one long low note.', ar: 'تلّ من زجاج أسود منصهر وأعمدة مكسورة. يجري المطر في قنوات نحتها الساريثيون له قبل أربعمئة عام. وحين تدور الريح يطنّ الزجاج نغمة طويلة منخفضة.' },
    exits: [{ to: 'south_road', minutes: 120 }, { to: 'sarith_vault', minutes: 15, hidden: 'found_sarith_vault' }],
    loot: [{ item: 'lio_satchel', qty: 1 }],
    features: [{ id: 'fresh_digging', dc: 10, flag: 'saw_fresh_digging', reveal: { en: 'Fresh spoil heaps and a broken shovel: someone has been digging here recently, and a muddy satchel lies half-buried beside the pit.', ar: 'أكوام تراب حديثة ومجرفة مكسورة: أحدهم كان يحفر هنا مؤخراً، وحقيبة موحلة نصف مدفونة بجانب الحفرة.' } },
      { id: 'vault_seam', dc: 15, flag: 'found_sarith_vault', reveal: { en: 'Where two glass slabs meet, warm air breathes out of a seam. Pressing the slab, it pivots: stairs lead down into a sealed hall.', ar: 'حيث يلتقي لوحان من الزجاج، يتنفّس هواء دافئ من شقّ بينهما. حين تضغط اللوح يدور على محوره: سلالم تهبط إلى قاعة مختومة.' } }]
  },
  sarith_vault: {
    name: { en: 'The Glass Hall', ar: 'قاعة الزجاج' }, region: 'vale', type: 'ruin', settlement: null, music: 'ruins', hiddenLocation: true,
    aliases: ['hall', 'vault', 'glass hall', 'قاعة', 'القاعة', 'القبو الزجاجي'],
    desc: { en: 'An unburnt hall. Its walls are one continuous mural in coloured glass: Sarithi farmers, a festival, then soldiers in Varrowmark colours bringing torches to a city that opened its gates to them.', ar: 'قاعة لم تحترق. جدرانها جدارية واحدة متصلة من الزجاج الملوّن: مزارعون ساريثيون، ثم عيد، ثم جنود بألوان فارومارك يحملون المشاعل إلى مدينة فتحت لهم أبوابها.' },
    exits: [{ to: 'vael_sarith', minutes: 15 }],
    features: [{ id: 'mural_truth', dc: 9, flag: 'learned_glass_truth', reveal: { en: 'The mural tells it plainly: Vael Sarith surrendered. The burning came after. The crown\'s histories say the opposite.', ar: 'الجدارية تقولها بوضوح: فايل ساريث استسلمت، والحريق جاء بعد ذلك. وتواريخ التاج تقول العكس.' }, history: true }]
  },
  corvane_gate: {
    name: { en: 'The Bridge Gate of Corvane', ar: 'بوابة الجسر في كورفان' }, region: 'corvane', type: 'gate', settlement: 'corvane', music: 'town',
    aliases: ['gate', 'corvane', 'bridge gate', 'town', 'city', 'بوابة', 'كورفان', 'المدينة', 'البوابة'],
    desc: { en: 'A fortified bridge over the river Corve. Guards in Dravell green check carts and collect the bridge toll; heads of hanged smugglers have been replaced, this season, by painted warnings.', ar: 'جسر محصّن فوق نهر كورف. حرّاس بلون آل درافيل الأخضر يفتّشون العربات ويجمعون رسوم الجسر؛ وقد استُبدلت رؤوس المهرّبين المشنوقين هذا الموسم بتحذيرات مرسومة.' },
    exits: [{ to: 'south_road', minutes: 240 }, { to: 'corvane_market', minutes: 5, gate: { toll: 2, guard: 'brannoc' } }],
    gateRule: { en: 'Toll: 2 silver, or a writ of passage.', ar: 'الرسم: 2 فضة، أو تصريح مرور.' }
  },
  corvane_market: {
    name: { en: 'Corvane market', ar: 'سوق كورفان' }, region: 'corvane', type: 'market', settlement: 'corvane', music: 'town',
    aliases: ['market', 'bazaar', 'corvane market', 'سوق', 'السوق', 'البازار'],
    desc: { en: 'Stalls under striped awnings crowd a sloping square. Fishwives shout over cloth sellers; a Grey Ledger counting-house with iron shutters watches it all from the high side.', ar: 'بسطات تحت مظلات مخطّطة تزدحم في ساحة منحدرة. بائعات السمك يصرخن فوق باعة القماش، وبيت حسابات للسجلّ الرمادي بمصاريع حديدية يراقب كل شيء من الجهة العالية.' },
    exits: [{ to: 'corvane_gate', minutes: 5 }, { to: 'drowned_bell', minutes: 4 }, { to: 'corvane_keep', minutes: 10 }],
    services: { sells: ['bread', 'stew', 'torch', 'rope', 'hunting_bow', 'leather_armor', 'healing_herbs', 'writ_of_passage'], seller: 'marda', buys: ['material', 'relic', 'weapon', 'armor', 'food', 'tool'] }
  },
  drowned_bell: {
    name: { en: 'The Drowned Bell alehouse', ar: 'خمّارة الجرس الغريق' }, region: 'corvane', type: 'tavern', settlement: 'corvane', music: 'tavern',
    aliases: ['drowned bell', 'bell', 'alehouse', 'خمارة', 'الجرس', 'الجرس الغريق'],
    desc: { en: 'A riverside alehouse whose sign is a real bronze bell pulled from the Corve. Bargemen, off-duty guards and Ledger clerks drink at separate tables.', ar: 'خمّارة على ضفة النهر، لافتتها جرس برونزي حقيقي انتُشل من نهر كورف. النوتيّة والحرّاس خارج الخدمة وكتبة السجلّ يشربون كلٌّ على طاولته.' },
    exits: [{ to: 'corvane_market', minutes: 4 }],
    services: { room: 6, sells: ['stew', 'ale', 'cider', 'bread'], seller: null }
  },
  corvane_keep: {
    name: { en: 'Dravell Keep', ar: 'قلعة درافيل' }, region: 'corvane', type: 'castle', settlement: 'corvane', music: 'temple',
    aliases: ['keep', 'castle', 'dravell', 'قلعة', 'القلعة', 'درافيل'],
    desc: { en: 'A square grey keep above the town, its banners green and black. Petitioners wait in the outer yard; few get further.', ar: 'قلعة رمادية مربعة فوق البلدة، راياتها خضراء وسوداء. ينتظر أصحاب العرائض في الفناء الخارجي، وقليلون يتجاوزونه.' },
    exits: [{ to: 'corvane_market', minutes: 10 }]
  }
};

// ---------------------------------------------------------------- NPCs
// schedule: [{ from, to, loc }] hours 0-24, first match wins; `days: 'odd'|'even'` optional.
// topics: knowledge the NPC may share. minAttitude gates it. secret topics need a social check.
export const NPCS = {
  hessa: { female: true,
    name: { en: 'Hessa Vorn', ar: 'هيسا فورن' }, age: 46, role: { en: 'keeper of the Sunken Lantern', ar: 'صاحبة حانة الفانوس الغارق' }, faction: 'vale',
    aliases: ['hessa', 'tavernkeeper', 'innkeeper', 'barkeep', 'owner', 'هيسا', 'صاحبة الحانة', 'صاحب الحانة', 'الساقية', 'صاحبة النزل'],
    persona: { en: 'Widowed, shrewd and warm in a tired way. Calls everyone "love". Notices who pays and who lies. Laughs loudly, worries quietly.', ar: 'أرملة، داهية ودافئة بطريقة متعبة. تنادي الجميع «يا عزيزي». تلاحظ من يدفع ومن يكذب. تضحك بصوت عالٍ وتقلق بصمت.' },
    goals: { en: 'Pay off the Grey Ledger debt before the tavern is seized at midsummer.', ar: 'سداد دين السجلّ الرمادي قبل أن تُصادر الحانة في منتصف الصيف.' },
    fears: { en: 'Losing the tavern; anyone learning how her husband really died.', ar: 'خسارة الحانة؛ وأن يعرف أحد كيف مات زوجها حقاً.' },
    secret: { en: 'Her husband died smuggling Sarithi glass for Garrow the miller.', ar: 'مات زوجها وهو يهرّب زجاجاً ساريثياً لحساب غارو الطحّان.' },
    stats: { str: 10, dex: 10, con: 11, int: 12, wis: 13, cha: 14, per: 14, luck: 10 }, hp: 12, gold: 40,
    attitude: 5,
    schedule: [{ from: 0, to: 24, loc: 'sunken_lantern' }],
    greet: {
      hostile: { en: 'We\'re full. For you, we\'re always full.', ar: 'الحانة ممتلئة. بالنسبة لك، هي ممتلئة دائماً.' },
      cold: { en: 'Coin first, love. Then we talk.', ar: 'المال أولاً يا عزيزي، ثم نتكلم.' },
      neutral: { en: 'Sit by the fire and dry off, love. Stew\'s three, ale\'s one.', ar: 'اجلس قرب النار وجفّف نفسك يا عزيزي. الحساء بثلاث، والجعة بواحدة.' },
      warm: { en: 'There you are! Saved you the good bench.', ar: 'ها أنت! احتفظت لك بالمقعد الجيد.' }
    },
    topics: [
      { id: 'news', keys: ['news', 'rumor', 'rumour', 'gossip', 'happening', 'أخبار', 'اخبار', 'شائعات', 'إشاعات', 'جديد', 'يحدث'], text: { en: 'Tobin\'s lad Lio went missing on the south road nine days back. And the Fen Rats have been bold this spring, two carts lost already.', ar: 'صبيّ توبن، ليو، اختفى على الطريق الجنوبي قبل تسعة أيام. وجرذان المستنقع تجرّؤوا هذا الربيع، خسرنا عربتين حتى الآن.' }, minAttitude: -10, reveals: ['rumor_lio', 'rumor_fenrats'] },
      { id: 'debt', keys: ['debt', 'ledger', 'money', 'owe', 'دين', 'ديون', 'السجل', 'مال'], text: { en: 'The Ledger wants forty silver by midsummer or they take the Lantern. My Bram borrowed it, and Bram is in the ground.', ar: 'السجلّ يريد أربعين فضة قبل منتصف الصيف وإلا أخذوا الفانوس. زوجي برام اقترضها، وبرام تحت التراب.' }, minAttitude: 10, reveals: ['hessa_debt'] },
      { id: 'husband', keys: ['husband', 'bram', 'died', 'death', 'زوج', 'زوجها', 'برام', 'مات', 'موت'], text: { en: 'Bram drowned in the Mire, they said. He was carrying crates for Garrow that night. I never asked what was in them. I know now.', ar: 'قالوا إن برام غرق في المستنقع. كان يحمل صناديق لغارو تلك الليلة. لم أسأل يوماً ما الذي فيها. أعرف الآن.' }, minAttitude: 35, secret: true, reveals: ['hessa_secret', 'suspect_garrow'] },
      { id: 'room', keys: ['room', 'bed', 'sleep', 'stay', 'غرفة', 'سرير', 'نوم', 'مبيت', 'أبيت'], text: { en: 'Room upstairs is four silver a night, clean straw, a lock that mostly works.', ar: 'الغرفة في الأعلى بأربع فضة لليلة، قش نظيف، وقفل يعمل غالباً.' }, minAttitude: -20 }
    ]
  },
  oswin: {
    name: { en: 'Oswin Kael', ar: 'أوزوين كايل' }, age: 38, role: { en: 'blacksmith and old soldier', ar: 'حدّاد وجندي سابق' }, faction: 'vale',
    aliases: ['oswin', 'kael', 'smith', 'blacksmith', 'أوزوين', 'كايل', 'الحداد', 'حداد'],
    persona: { en: 'Gruff, honest to the point of rudeness, few words. Served in the levy; hates talk of war and men who boast. Respects good work and straight dealing.', ar: 'فظّ، صادق حدّ الوقاحة، قليل الكلام. خدم في الجباية العسكرية؛ يكره الحديث عن الحرب والمتبجّحين. يحترم العمل المتقن والتعامل المستقيم.' },
    goals: { en: 'Forge one masterwork blade worthy of his father\'s anvil.', ar: 'صنع سيف واحد متقن يليق بسندان أبيه.' },
    fears: { en: 'A new war calling up the levy.', ar: 'حرب جديدة تستدعي الجباية العسكرية.' },
    stats: { str: 16, dex: 11, con: 15, int: 10, wis: 12, cha: 8, per: 11, luck: 9 }, hp: 22, gold: 80, weapon: 'short_sword', armor: 2,
    attitude: 0,
    schedule: [{ from: 7, to: 18, loc: 'kael_forge' }, { from: 19, to: 22, loc: 'sunken_lantern' }, { from: 0, to: 24, loc: 'kael_forge' }],
    greet: {
      hostile: { en: 'Get away from my anvil.', ar: 'ابتعد عن سنداني.' },
      cold: { en: 'Buying or wasting my time?', ar: 'تشتري أم تضيّع وقتي؟' },
      neutral: { en: 'Mm. Steel\'s on the pegs. Prices are fair.', ar: 'همم. الفولاذ على الأوتاد. والأسعار عادلة.' },
      warm: { en: 'Good to see you. Hand me that tongs, would you.', ar: 'سرّني أن أراك. ناولني تلك الملقط، لو سمحت.' }
    },
    topics: [
      { id: 'news', keys: ['news', 'rumor', 'gossip', 'أخبار', 'اخبار', 'شائعات'], text: { en: 'Ledger men bought every spear-head I had last month. Somebody expects trouble.', ar: 'رجال السجلّ اشتروا كل رؤوس الرماح عندي الشهر الماضي. أحدهم يتوقّع مشاكل.' }, minAttitude: -5, reveals: ['rumor_spears'] },
      { id: 'fenrats', keys: ['fen rats', 'bandit', 'bandits', 'rats', 'لصوص', 'قطاع', 'جرذان', 'عصابة'], text: { en: 'Fen Rats camp somewhere east in Blackfen. Ysolde the hunter knows the bog better than they do.', ar: 'جرذان المستنقع يخيّمون في مكان ما شرقاً في بلاكفن. يسولد الصيّادة تعرف المستنقع أفضل منهم.' }, minAttitude: 0, reveals: ['ysolde_knows_bog'] },
      { id: 'war', keys: ['war', 'glass war', 'soldier', 'army', 'حرب', 'جيش', 'جندي'], text: { en: 'My father fought at Vael Sarith. He never spoke of it, except once, drunk: "They opened the gates, Os."', ar: 'أبي قاتل في فايل ساريث. لم يتحدث عنها قط، إلا مرة وهو ثمل: «لقد فتحوا الأبواب يا أوز».' }, minAttitude: 30, secret: true, reveals: ['clue_gates_opened'] }
    ]
  },
  ilvane: { female: true,
    name: { en: 'Mother Ilvane', ar: 'الأم إلفان' }, age: 61, role: { en: 'priestess of the Ashen Mother', ar: 'كاهنة الأم الرمادية' }, faction: 'church',
    aliases: ['ilvane', 'priestess', 'priest', 'mother ilvane', 'إلفان', 'الكاهنة', 'كاهنة', 'الأم'],
    persona: { en: 'Serene, precise, dogmatic about the dead. Speaks in measured sentences and parables. Kind to the poor, cold to grave-robbers.', ar: 'هادئة، دقيقة، متشدّدة في شأن الموتى. تتكلم بجمل موزونة وأمثال. رحيمة بالفقراء، باردة مع نابشي القبور.' },
    goals: { en: 'Keep the ruins sealed and the faithful from the "glass heresy".', ar: 'إبقاء الأطلال مختومة وحماية المؤمنين من «هرطقة الزجاج».' },
    fears: { en: 'That the Unlit are right.', ar: 'أن يكون المُطفَؤون على حق.' },
    stats: { str: 8, dex: 9, con: 10, int: 14, wis: 16, cha: 12, per: 13, luck: 10 }, hp: 10, gold: 25,
    attitude: 0,
    schedule: [{ from: 0, to: 24, loc: 'chapel_ashen' }],
    greet: {
      hostile: { en: 'The Mother forgives. I am not the Mother.', ar: 'الأم تغفر. وأنا لست الأم.' },
      cold: { en: 'State your need, child.', ar: 'اذكر حاجتك يا بنيّ.' },
      neutral: { en: 'Ash to ash, and peace between. How may the chapel help you?', ar: 'من الرماد إلى الرماد، والسلام بينهما. بمَ تخدمك الكنيسة؟' },
      warm: { en: 'Come in from the rain. Sit; the candles do not mind company.', ar: 'ادخل من المطر. اجلس؛ الشموع لا تمانع الرفقة.' }
    },
    topics: [
      { id: 'unlit_candle', keys: ['candle', 'unlit', 'never lit', 'شمعة', 'مطفأة', 'المطفؤون', 'المُطفَؤون'], text: { en: 'That niche honours the Sarithi dead. The unlit candle is our mourning. Lately some have stolen it as a sign for... other things.', ar: 'تلك الكوّة تكريم لموتى الساريثيين. الشمعة المطفأة حدادنا. ومؤخراً سرقها بعضهم رمزاً لـ... أمور أخرى.' }, minAttitude: 0, reveals: ['learned_unlit_symbol'] },
      { id: 'ruins', keys: ['ruins', 'sarith', 'vael', 'glass', 'أطلال', 'ساريث', 'زجاج'], text: { en: 'Vael Sarith is a grave. Whoever digs there digs into the Mother\'s cloak. Someone is digging.', ar: 'فايل ساريث قبر. ومن يحفر هناك يحفر في عباءة الأم. وأحدهم يحفر.' }, minAttitude: -10, reveals: ['rumor_digging'] },
      { id: 'heresy', keys: ['heresy', 'unlit', 'cult', 'garrow', 'هرطقة', 'طائفة', 'غارو'], text: { en: 'I will say it once: Garrow has not knelt here since the thaw, and his flour sacks go to Corvane heavier than flour.', ar: 'سأقولها مرة واحدة: غارو لم يركع هنا منذ ذوبان الثلج، وأكياس طحينه تذهب إلى كورفان أثقل من الطحين.' }, minAttitude: 25, secret: true, reveals: ['suspect_garrow'] }
    ]
  },
  garrow: {
    name: { en: 'Garrow Teal', ar: 'غارو تيل' }, age: 57, role: { en: 'miller of Mirefold', ar: 'طحّان ميرفولد' }, faction: 'unlit',
    aliases: ['garrow', 'miller', 'غارو', 'الطحان', 'طحان'],
    persona: { en: 'Soft-spoken, generous with bread, nervous laugh, sweats when pressed. Truly believes the Sarithi were wronged. Cowardly but not cruel.', ar: 'ليّن الكلام، كريم بالخبز، ضحكة متوترة، يتعرّق حين يُضغط عليه. يؤمن حقاً بأن الساريثيين ظُلموا. جبان لكنه ليس قاسياً.' },
    goals: { en: 'Smuggle enough Sarithi glass to "Q." in Corvane for the Unlit to prove the truth of the Glass War.', ar: 'تهريب ما يكفي من الزجاج الساريثي إلى «ك.» في كورفان كي يثبت المُطفَؤون حقيقة حرب الزجاج.' },
    fears: { en: 'The Fen Rats he hired; the crown\'s rope.', ar: 'جرذان المستنقع الذين استأجرهم؛ وحبل مشنقة التاج.' },
    secret: { en: 'He paid the Fen Rats to dig in the ruins; they seized Lio when the boy stumbled on the dig.', ar: 'دفع لجرذان المستنقع ليحفروا في الأطلال؛ فأسروا ليو حين عثر الصبي على موقع الحفر.' },
    stats: { str: 11, dex: 9, con: 10, int: 13, wis: 11, cha: 11, per: 10, luck: 9 }, hp: 11, gold: 120,
    attitude: 10,
    schedule: [{ from: 6, to: 17, loc: 'old_mill' }, { from: 18, to: 21, loc: 'sunken_lantern' }, { from: 0, to: 24, loc: 'old_mill' }],
    greet: {
      hostile: { en: 'I-I have nothing for you. Please go.', ar: 'ل-ليس عندي شيء لك. أرجوك اذهب.' },
      cold: { en: 'Flour\'s by the sack. Was there something else?', ar: 'الطحين بالكيس. هل من شيء آخر؟' },
      neutral: { en: 'Ah, a new face! Take a heel of bread, friend, no charge.', ar: 'آه، وجه جديد! خذ كسرة خبز يا صديقي، بلا ثمن.' },
      warm: { en: 'Friend! Sit, sit. The wheel is loud but the company is good.', ar: 'صديقي! اجلس، اجلس. العجلة صاخبة لكن الرفقة طيبة.' }
    },
    topics: [
      { id: 'news', keys: ['news', 'rumor', 'أخبار', 'اخبار'], text: { en: 'Oh, the usual. Rain. Prices. Poor Tobin\'s boy. Terrible. Terrible.', ar: 'آه، المعتاد. مطر. أسعار. صبيّ توبن المسكين. فظيع. فظيع.' }, minAttitude: -20 },
      { id: 'lio', keys: ['lio', 'boy', 'apprentice', 'missing', 'ليو', 'الصبي', 'المفقود', 'مفقود'], text: { en: 'Lio? I... no, I hadn\'t seen him. Not for weeks. Why do you ask me?', ar: 'ليو؟ أنا... لا، لم أره. منذ أسابيع. لماذا تسألني أنا؟' }, minAttitude: -50, reveals: ['garrow_nervous'] },
      { id: 'confession', keys: ['confess', 'truth', 'glass', 'unlit', 'cellar', 'fen rats', 'اعترف', 'الحقيقة', 'زجاج', 'القبو', 'المطفؤون'], text: { en: 'I only paid them to dig! The boy saw them and they took him. They\'re holding him at their camp in Blackfen till the dig is done. I never wanted... please.', ar: 'دفعت لهم ليحفروا فقط! الصبي رآهم فأخذوه. يحتجزونه في معسكرهم في بلاكفن حتى ينتهي الحفر. لم أُرِد قط... أرجوك.' }, minAttitude: 40, secret: true, reveals: ['garrow_confessed', 'lio_at_camp'], unlockFlag: 'found_bandit_camp' }
    ]
  },
  tobin: {
    name: { en: 'Tobin Marle', ar: 'توبن مارل' }, age: 33, role: { en: 'travelling merchant of the Grey Ledger', ar: 'تاجر جوّال من السجلّ الرمادي' }, faction: 'ledger',
    aliases: ['tobin', 'merchant', 'trader', 'peddler', 'توبن', 'التاجر', 'تاجر'],
    persona: { en: 'Talkative, quick with numbers and jokes, but hollow-eyed since Lio vanished. Loyal to whoever is loyal to him.', ar: 'ثرثار، سريع في الأرقام والنكات، لكن عينيه غائرتان منذ اختفى ليو. وفيّ لمن يفي له.' },
    goals: { en: 'Find Lio. Then open his own shop in Corvane, free of the Ledger.', ar: 'العثور على ليو. ثم فتح دكانه الخاص في كورفان بعيداً عن السجلّ.' },
    fears: { en: 'That Lio is dead because Tobin sent him alone.', ar: 'أن يكون ليو ميتاً لأن توبن أرسله وحده.' },
    stats: { str: 10, dex: 12, con: 11, int: 13, wis: 10, cha: 14, per: 12, luck: 12 }, hp: 12, gold: 150,
    attitude: 5,
    schedule: [
      { from: 8, to: 17, loc: 'mirefold_square', days: 'odd' }, { from: 17, to: 23, loc: 'sunken_lantern', days: 'odd' }, { from: 0, to: 24, loc: 'sunken_lantern', days: 'odd' },
      { from: 6, to: 10, loc: 'south_road', days: 'even' }, { from: 10, to: 19, loc: 'corvane_market', days: 'even' }, { from: 0, to: 24, loc: 'drowned_bell', days: 'even' }
    ],
    sells: ['rope', 'torch', 'bandage', 'cider', 'lockpick'],
    greet: {
      hostile: { en: 'I don\'t deal with your kind. Move along.', ar: 'لا أتعامل مع أمثالك. امضِ في طريقك.' },
      cold: { en: 'Trading? Make it quick.', ar: 'تتاجر؟ اختصر.' },
      neutral: { en: 'Rope, torches, bandages, the finest cider in the vale... and if you\'ve seen a red-haired boy, I\'ll pay more for that.', ar: 'حبال، مشاعل، ضمادات، أطيب عصير في الوادي... وإن رأيت صبياً أحمر الشعر، فسأدفع أكثر مقابل ذلك.' },
      warm: { en: 'My friend! Any word? Any word at all?', ar: 'صديقي! أيّ خبر؟ أيّ خبر على الإطلاق؟' }
    },
    topics: [
      { id: 'lio', keys: ['lio', 'boy', 'apprentice', 'missing', 'reward', 'ليو', 'الصبي', 'المفقود', 'مكافأة', 'مفقود'], text: { en: 'Lio went to fetch a debt in Corvane and never arrived. Someone at the crossroads saw him take the west fork, toward the ruins. Find him and I\'ll give you thirty silver and my word.', ar: 'ذهب ليو لتحصيل دين في كورفان ولم يصل. رآه أحدهم عند المفترق يسلك الفرع الغربي نحو الأطلال. اعثر عليه وسأعطيك ثلاثين فضة وكلمتي.' }, minAttitude: -10, reveals: ['lio_went_west'], quest: 'find_lio' },
      { id: 'ledger', keys: ['ledger', 'guild', 'السجل', 'نقابة'], text: { en: 'The Ledger owns my cart, my stock and half my teeth. A factor called Marda Quill keeps the books in Corvane.', ar: 'السجلّ يملك عربتي وبضاعتي ونصف أسناني. وكيلة تُدعى ماردا كويل تمسك الدفاتر في كورفان.' }, minAttitude: 5 }
    ]
  },
  ysolde: { female: true,
    name: { en: 'Ysolde Fenn', ar: 'يسولد فين' }, age: 27, role: { en: 'hunter of Blackfen', ar: 'صيّادة بلاكفن' }, faction: 'vale',
    aliases: ['ysolde', 'hunter', 'huntress', 'يسولد', 'الصيادة', 'صيادة', 'الصياد'],
    persona: { en: 'Laconic, watchful, dry humour. Trusts deeds over words. Saves every coin for land of her own.', ar: 'مقتضبة، يقظة، ذات دعابة جافة. تثق بالأفعال لا بالأقوال. تدّخر كل قطعة نقد لأرض تملكها.' },
    goals: { en: 'Buy the meadow by the Mire and stop renting from the Dravells.', ar: 'شراء المرج بجانب المستنقع والكفّ عن الاستئجار من آل درافيل.' },
    fears: { en: 'The Fen Rats, who killed her brother.', ar: 'جرذان المستنقع الذين قتلوا أخاها.' },
    stats: { str: 12, dex: 16, con: 12, int: 11, wis: 14, cha: 9, per: 16, luck: 11 }, hp: 15, gold: 30, weapon: 'hunting_bow', armor: 1,
    attitude: -5,
    schedule: [{ from: 5, to: 15, loc: 'blackfen' }, { from: 15, to: 19, loc: 'mirefold_square' }, { from: 19, to: 23, loc: 'sunken_lantern' }, { from: 0, to: 24, loc: 'mirefold_square' }],
    buys: ['material'],
    greet: {
      hostile: { en: 'Walk on.', ar: 'امضِ.' },
      cold: { en: 'Hm.', ar: 'همم.' },
      neutral: { en: 'Pelts are six. Directions are free, if I like you.', ar: 'الجلود بست. والإرشاد مجاني، إن أعجبتني.' },
      warm: { en: 'You again. Good. I wanted someone with a spine.', ar: 'أنت مجدداً. جيد. كنت أريد أحداً له عمود فقري.' }
    },
    topics: [
      { id: 'camp', keys: ['camp', 'fen rats', 'bandits', 'smoke', 'torches', 'معسكر', 'جرذان', 'لصوص', 'دخان', 'مشاعل'], text: { en: 'Torches out past the drowned oaks, three nights running. Follow the cart ruts from the crossroads, then the log path. Don\'t go alone.', ar: 'مشاعل وراء أشجار البلوط الغارقة، ثلاث ليالٍ متتالية. اتبع آثار العربة من المفترق، ثم ممرّ الجذوع. لا تذهب وحدك.' }, minAttitude: 15, reveals: ['found_bandit_camp_hint'], unlockFlag: 'found_bandit_camp' },
      { id: 'hunting', keys: ['hunt', 'hunting', 'wolves', 'pelts', 'صيد', 'ذئاب', 'جلود'], text: { en: 'Wolves are thin this spring. Something drove the deer out of the east fen.', ar: 'الذئاب نحيلة هذا الربيع. شيء ما طرد الغزلان من المستنقع الشرقي.' }, minAttitude: -20 }
    ]
  },
  pell: {
    name: { en: 'Pell', ar: 'بيل' }, age: 15, role: { en: 'rag-picker and errand runner', ar: 'جامع خِرَق وساعٍ للمهمّات' }, faction: 'vale',
    aliases: ['pell', 'urchin', 'rag-picker', 'beggar', 'بيل', 'الفتى', 'المتسول', 'الصبي الفقير'],
    persona: { en: 'Quick, cheeky, hungry. Sells rumours for coin or food; lies about small things, never about big ones.', ar: 'سريع، وقح، جائع. يبيع الشائعات مقابل المال أو الطعام؛ يكذب في الصغائر ولا يكذب في الكبائر.' },
    goals: { en: 'Get to Corvane and get apprenticed to anyone at all.', ar: 'الوصول إلى كورفان والتتلمذ على يد أيّ أحد.' },
    fears: { en: 'Winter.', ar: 'الشتاء.' },
    stats: { str: 7, dex: 14, con: 9, int: 12, wis: 10, cha: 12, per: 15, luck: 13 }, hp: 7, gold: 1,
    attitude: 0,
    schedule: [{ from: 6, to: 20, loc: 'mirefold_square' }, { from: 0, to: 24, loc: 'sunken_lantern' }],
    greet: {
      hostile: { en: 'Not talking to you.', ar: 'لن أكلمك.' },
      cold: { en: 'Information costs, stranger.', ar: 'المعلومة لها ثمن يا غريب.' },
      neutral: { en: 'A copper for a secret? Two for a good one.', ar: 'نحاسة مقابل سرّ؟ اثنتان مقابل سرّ جيد.' },
      warm: { en: 'Oi! I kept my ears open for you.', ar: 'هيه! أبقيت أذنيّ مفتوحتين لأجلك.' }
    },
    topics: [
      { id: 'secret', keys: ['secret', 'rumor', 'news', 'gossip', 'سر', 'سرّ', 'شائعة', 'أخبار', 'اخبار'], text: { en: 'The miller goes down to his cellar at night with a lamp, and comes up without it. And he drinks with men who smell like bog.', ar: 'الطحّان ينزل إلى قبوه ليلاً بمصباح، ويصعد من دونه. ويشرب مع رجال رائحتهم كالمستنقع.' }, minAttitude: 10, reveals: ['suspect_garrow', 'hint_mill_cellar'] }
    ]
  },
  brannoc: {
    name: { en: 'Captain Brannoc Hale', ar: 'القائد برانوك هيل' }, age: 44, role: { en: 'captain of the Bridge Gate', ar: 'قائد بوابة الجسر' }, faction: 'dravell',
    aliases: ['brannoc', 'captain', 'guard', 'guards', 'برانوك', 'القائد', 'الحارس', 'الحراس', 'قائد'],
    persona: { en: 'By-the-book on the surface, tired and underpaid beneath. Proud of order, privately open to "fees". Hates bandits more than anyone.', ar: 'ملتزم بالقواعد في الظاهر، متعب وقليل الأجر في الباطن. فخور بالنظام، ومنفتح سرّاً على «الرسوم». يكره قطّاع الطرق أكثر من أي أحد.' },
    goals: { en: 'Earn promotion to the keep guard by breaking the Fen Rats.', ar: 'نيل الترقية إلى حرس القلعة بسحق جرذان المستنقع.' },
    fears: { en: 'Lady Vessa\'s displeasure.', ar: 'سخط السيدة فيسا.' },
    stats: { str: 14, dex: 12, con: 14, int: 11, wis: 12, cha: 10, per: 13, luck: 10 }, hp: 20, gold: 35, weapon: 'longsword', armor: 4,
    attitude: -5,
    schedule: [{ from: 6, to: 20, loc: 'corvane_gate' }, { from: 20, to: 24, loc: 'drowned_bell' }, { from: 0, to: 6, loc: 'corvane_gate' }],
    greet: {
      hostile: { en: 'One more step and you\'ll hang from this bridge.', ar: 'خطوة أخرى وستُشنق على هذا الجسر.' },
      cold: { en: 'Toll is two silver. Pay or turn around.', ar: 'الرسم فضّتان. ادفع أو عُد أدراجك.' },
      neutral: { en: 'Name and business in Corvane. Toll is two.', ar: 'الاسم والغرض في كورفان. الرسم فضّتان.' },
      warm: { en: 'Ah, you. Go on through.', ar: 'آه، أنت. تفضّل بالعبور.' }
    },
    topics: [
      { id: 'fenrats', keys: ['fen rats', 'bandits', 'bounty', 'لصوص', 'جرذان', 'مكافأة', 'جائزة'], text: { en: 'House Dravell pays fifty silver for proof the Fen Rats are broken. Their chief calls himself Rusk the Knot.', ar: 'آل درافيل يدفعون خمسين فضة لمن يثبت أن جرذان المستنقع قد سُحقوا. زعيمهم يسمّي نفسه رَسك العُقدة.' }, minAttitude: -10, reveals: ['bounty_fenrats'], quest: 'break_fenrats' }
    ]
  },
  marda: { female: true,
    name: { en: 'Marda Quill', ar: 'ماردا كويل' }, age: 50, role: { en: 'factor of the Grey Ledger in Corvane', ar: 'وكيلة السجلّ الرمادي في كورفان' }, faction: 'ledger',
    aliases: ['marda', 'quill', 'factor', 'merchant', 'ماردا', 'كويل', 'الوكيلة'],
    persona: { en: 'Cold, exact, never raises her voice. Treats people as entries in a ledger: assets or liabilities. Keeps every promise to the letter and no further.', ar: 'باردة، دقيقة، لا ترفع صوتها أبداً. تعامل الناس كقيود في دفتر: أصول أو خصوم. تفي بكل وعد حرفياً ولا تزيد.' },
    goals: { en: 'Make the vale\'s debts into the vale\'s land.', ar: 'تحويل ديون الوادي إلى أراضيه.' },
    fears: { en: 'Being made to look a fool.', ar: 'أن تبدو حمقاء.' },
    secret: { en: 'She is "Q.", the Unlit buyer of Sarithi glass. She believes the truth is worth more than any debt.', ar: 'هي «ك.»، مشترية الزجاج الساريثي لحساب المُطفَئين. تؤمن بأن الحقيقة أثمن من أيّ دين.' },
    stats: { str: 9, dex: 10, con: 10, int: 16, wis: 14, cha: 13, per: 14, luck: 11 }, hp: 10, gold: 400,
    attitude: 0,
    schedule: [{ from: 8, to: 19, loc: 'corvane_market' }, { from: 0, to: 24, loc: 'corvane_market' }],
    greet: {
      hostile: { en: 'Your account is closed.', ar: 'حسابك مغلق.' },
      cold: { en: 'State your business.', ar: 'اذكر عملك.' },
      neutral: { en: 'The Ledger buys and sells. What do you bring?', ar: 'السجلّ يشتري ويبيع. ماذا تحمل؟' },
      warm: { en: 'A reliable face. Sit; we may do business beyond the counter.', ar: 'وجه يُعتمد عليه. اجلس؛ قد نتعامل فيما وراء المنضدة.' }
    },
    topics: [
      { id: 'glass', keys: ['glass', 'relic', 'sarith', 'shard', 'زجاج', 'أثر', 'شظية', 'ساريث'], text: { en: 'The Ledger does not trade in grave goods. (She glances at the shard.) Privately, I would pay sixty for a clean piece.', ar: 'السجلّ لا يتاجر بمقتنيات القبور. (تلقي نظرة على الشظية.) لكني سرّاً أدفع ستين لقطعة سليمة.' }, minAttitude: 0, reveals: ['marda_buys_glass'] },
      { id: 'q', keys: ['q.', 'unlit', 'candle', 'المطفؤون', 'شمعة', 'ك.'], text: { en: 'You have read something you should not have. Very well. The crown burned Vael Sarith after it surrendered. The glass remembers. Help us show it, and the Ledger forgets certain debts.', ar: 'قرأت شيئاً ما كان ينبغي لك. حسناً. التاج أحرق فايل ساريث بعد استسلامها. الزجاج يتذكّر. ساعدنا على إظهار ذلك، وسينسى السجلّ ديوناً معيّنة.' }, minAttitude: 20, secret: true, reveals: ['marda_is_q'] }
    ]
  },
  rusk: {
    name: { en: 'Rusk the Knot', ar: 'رَسك العُقدة' }, age: 40, role: { en: 'chief of the Fen Rats', ar: 'زعيم جرذان المستنقع' }, faction: 'fenrats',
    aliases: ['rusk', 'knot', 'chief', 'leader', 'bandit chief', 'رسك', 'العقدة', 'الزعيم', 'زعيم'],
    persona: { en: 'Pragmatic, brutal when useful, oddly courteous. Respects strength and a good bargain. Will sell anyone, including Garrow.', ar: 'عملي، وحشي حين يفيد ذلك، ومهذّب بشكل غريب. يحترم القوة والصفقة الجيدة. يبيع أيّ أحد، حتى غارو.' },
    goals: { en: 'Get paid for the dig and get out of the vale before the Dravells come.', ar: 'قبض أجر الحفر والخروج من الوادي قبل أن يأتي آل درافيل.' },
    fears: { en: 'Being cornered.', ar: 'أن يُحاصَر.' },
    stats: { str: 15, dex: 13, con: 14, int: 12, wis: 11, cha: 12, per: 12, luck: 10 }, hp: 24, gold: 90, weapon: 'short_sword', armor: 2,
    attitude: -15,
    schedule: [{ from: 0, to: 24, loc: 'blackfen_camp' }],
    greet: {
      hostile: { en: 'Kill this one.', ar: 'اقتلوا هذا.' },
      cold: { en: 'You\'ve walked a long way to die in a bog.', ar: 'مشيت طريقاً طويلاً لتموت في مستنقع.' },
      neutral: { en: 'A visitor. How novel. Speak, before my lads get bored.', ar: 'زائر. يا للجِدّة. تكلّم قبل أن يملّ رجالي.' },
      warm: { en: 'My favourite trespasser. Wine?', ar: 'متطفّلي المفضّل. نبيذ؟' }
    },
    topics: [
      { id: 'lio', keys: ['lio', 'boy', 'prisoner', 'release', 'free', 'ليو', 'الصبي', 'الأسير', 'أطلق', 'حرّر'], text: { en: 'The boy digs well. Forty silver and he walks. Or bring me the miller\'s head and he walks for free.', ar: 'الصبي يحفر جيداً. أربعون فضة ويمشي حراً. أو أحضر لي رأس الطحّان ويمشي مجاناً.' }, minAttitude: -30, reveals: ['rusk_ransom'] },
      { id: 'garrow', keys: ['garrow', 'miller', 'who paid', 'غارو', 'الطحان', 'من دفع'], text: { en: 'The miller pays us to dig for his glass. He\'s late paying. I don\'t like late.', ar: 'الطحّان يدفع لنا لنحفر من أجل زجاجه. وقد تأخر في الدفع. وأنا لا أحب التأخير.' }, minAttitude: -10, reveals: ['suspect_garrow', 'garrow_paid_rats'] }
    ]
  },
  lio: {
    name: { en: 'Lio', ar: 'ليو' }, age: 17, role: { en: 'Tobin\'s missing apprentice', ar: 'صبيّ توبن المفقود' }, faction: 'vale',
    aliases: ['lio', 'boy', 'apprentice', 'prisoner', 'ليو', 'الصبي', 'الأسير'],
    persona: { en: 'Frightened, sharp, stubborn. Hides fear behind questions.', ar: 'خائف، ذكي، عنيد. يخفي خوفه وراء الأسئلة.' },
    goals: { en: 'Go home.', ar: 'العودة إلى البيت.' },
    fears: { en: 'Being left here.', ar: 'أن يُترك هنا.' },
    stats: { str: 9, dex: 12, con: 10, int: 13, wis: 10, cha: 11, per: 13, luck: 8 }, hp: 8, gold: 0,
    attitude: 20, captive: true,
    schedule: [{ from: 0, to: 24, loc: 'blackfen_camp' }],
    greet: {
      hostile: { en: '...', ar: '...' }, cold: { en: 'Who are you?', ar: 'من أنت؟' },
      neutral: { en: 'Did Tobin send you? Please say Tobin sent you.', ar: 'هل أرسلك توبن؟ أرجوك قل إن توبن أرسلك.' },
      warm: { en: 'I knew someone would come.', ar: 'كنت أعرف أن أحداً سيأتي.' }
    },
    topics: [
      { id: 'what_happened', keys: ['what happened', 'how', 'why', 'ماذا حدث', 'كيف', 'لماذا'], text: { en: 'I took the ruin path to save an hour. They were digging. One of them had a letter with a candle on it. They grabbed me.', ar: 'سلكت درب الأطلال لأوفّر ساعة. كانوا يحفرون. أحدهم كان يحمل رسالة عليها شمعة. أمسكوا بي.' }, minAttitude: -20, reveals: ['lio_story'] }
    ]
  }
};

// ---------------------------------------------------------------- quests (templates)
// Quests are not forced; they are added to the journal when an NPC offers them
// (topic.quest) and resolved by world flags, however the player gets there.
export const QUESTS = {
  find_lio: {
    title: { en: 'The red-haired apprentice', ar: 'الصبيّ أحمر الشعر' }, type: 'personal', giver: 'tobin',
    desc: { en: 'Tobin Marle\'s apprentice Lio vanished on the south road. Tobin offers 30 silver.', ar: 'اختفى ليو صبيّ التاجر توبن مارل على الطريق الجنوبي. يعرض توبن 30 فضة.' },
    complete: { flag: 'lio_returned', reward: { gold: 30, attitude: { tobin: 30 }, rep: { local: 10 } } },
    fail: { flag: 'lio_dead' }
  },
  break_fenrats: {
    title: { en: 'A bounty on the Fen Rats', ar: 'مكافأة على رؤوس جرذان المستنقع' }, type: 'bounty', giver: 'brannoc',
    desc: { en: 'House Dravell pays 50 silver to whoever breaks the Fen Rats in Blackfen.', ar: 'يدفع آل درافيل 50 فضة لمن يسحق جرذان المستنقع في بلاكفن.' },
    complete: { flag: 'fenrats_broken', reward: { gold: 50, attitude: { brannoc: 25 }, rep: { military: 15, political: 5 } } }
  }
};

// ---------------------------------------------------------------- character creation
export const STAT_KEYS = ['str', 'dex', 'int', 'wis', 'cha', 'con', 'per', 'luck'];
export const STAT_NAMES = {
  str: { en: 'Strength', ar: 'القوة' }, dex: { en: 'Dexterity', ar: 'الرشاقة' }, int: { en: 'Intelligence', ar: 'الذكاء' }, wis: { en: 'Wisdom', ar: 'الحكمة' },
  cha: { en: 'Charisma', ar: 'الكاريزما' }, con: { en: 'Constitution', ar: 'البنية' }, per: { en: 'Perception', ar: 'الإدراك' }, luck: { en: 'Luck', ar: 'الحظ' }
};
export const SKILL_KEYS = ['swordsmanship', 'archery', 'magic', 'stealth', 'persuasion', 'trading', 'survival', 'leadership', 'blacksmithing', 'alchemy', 'medicine', 'hunting'];
export const SKILL_NAMES = {
  swordsmanship: { en: 'Swordsmanship', ar: 'المبارزة' }, archery: { en: 'Archery', ar: 'الرماية' }, magic: { en: 'Magic', ar: 'السحر' }, stealth: { en: 'Stealth', ar: 'التخفّي' },
  persuasion: { en: 'Persuasion', ar: 'الإقناع' }, trading: { en: 'Trading', ar: 'التجارة' }, survival: { en: 'Survival', ar: 'النجاة' }, leadership: { en: 'Leadership', ar: 'القيادة' },
  blacksmithing: { en: 'Blacksmithing', ar: 'الحدادة' }, alchemy: { en: 'Alchemy', ar: 'الخيمياء' }, medicine: { en: 'Medicine', ar: 'الطب' }, hunting: { en: 'Hunting', ar: 'الصيد' }
};
export const SKILL_STAT = {
  swordsmanship: 'str', archery: 'dex', magic: 'int', stealth: 'dex', persuasion: 'cha', trading: 'cha', survival: 'wis', leadership: 'cha',
  blacksmithing: 'str', alchemy: 'int', medicine: 'wis', hunting: 'per'
};

export const BACKGROUNDS = {
  farmhand: { name: { en: 'Farmhand', ar: 'عامل مزرعة' }, desc: { en: 'Barley, mud and long days. Strong back, few coins.', ar: 'شعير ووحل وأيام طويلة. ظهر قوي وقليل من المال.' }, stats: { str: 2, con: 2 }, skills: { survival: 2, hunting: 1 }, items: [['cudgel', 1], ['bread', 2]], gold: 6, equip: { weapon: 'cudgel' } },
  soldier: { name: { en: 'Discharged soldier', ar: 'جندي مسرَّح' }, desc: { en: 'Five years in the levy. You know which end of a sword to hold, and what it costs.', ar: 'خمس سنوات في الجيش. تعرف أيّ طرف من السيف تمسك، وكم يكلّف ذلك.' }, stats: { str: 2, con: 1, per: 1 }, skills: { swordsmanship: 3, leadership: 1 }, items: [['short_sword', 1], ['leather_armor', 1], ['bandage', 2]], gold: 8, equip: { weapon: 'short_sword', armor: 'leather_armor' } },
  merchant: { name: { en: 'Failed merchant', ar: 'تاجر مُفلس' }, desc: { en: 'Your last venture sank in the Corve. You still know a fair price when you see one.', ar: 'غرقت آخر تجارتك في نهر كورف. لكنك ما زلت تعرف السعر العادل حين تراه.' }, stats: { cha: 2, int: 1, luck: 1 }, skills: { trading: 3, persuasion: 2 }, items: [['dagger', 1], ['cider', 1]], gold: 25, equip: { weapon: 'dagger' } },
  scholar: { name: { en: 'Wandering scholar', ar: 'عالِم جوّال' }, desc: { en: 'Thrown out of a Corvane library for asking about the Glass War.', ar: 'طُردت من مكتبة في كورفان لأنك سألت عن حرب الزجاج.' }, stats: { int: 3, wis: 1 }, skills: { alchemy: 2, medicine: 2, magic: 1 }, items: [['dagger', 1], ['healing_herbs', 2], ['torch', 2]], gold: 12, equip: { weapon: 'dagger' } },
  outlaw: { name: { en: 'Outlaw', ar: 'خارج عن القانون' }, desc: { en: 'There is a price on a name that used to be yours.', ar: 'هناك ثمن على اسم كان لك يوماً.' }, stats: { dex: 3, per: 1 }, skills: { stealth: 3, swordsmanship: 1 }, items: [['dagger', 1], ['lockpick', 1]], gold: 10, equip: { weapon: 'dagger' }, rep: { criminal: 10, local: -5 } },
  hunter: { name: { en: 'Hunter', ar: 'صيّاد' }, desc: { en: 'You read tracks the way priests read scripture.', ar: 'تقرأ الآثار كما يقرأ الكهنة النصوص المقدّسة.' }, stats: { dex: 2, per: 2 }, skills: { archery: 2, hunting: 3, survival: 1 }, items: [['hunting_bow', 1], ['dagger', 1], ['bread', 1]], gold: 7, equip: { weapon: 'hunting_bow' } },
  acolyte: { name: { en: 'Lapsed acolyte', ar: 'مريد تارك' }, desc: { en: 'Raised by the Ashen Mother\'s chapel, until you started asking questions.', ar: 'ترعرعت في كنيسة الأم الرمادية، حتى بدأت تطرح الأسئلة.' }, stats: { wis: 2, cha: 1, int: 1 }, skills: { medicine: 3, persuasion: 1, magic: 1 }, items: [['bandage', 3], ['healing_herbs', 1], ['cudgel', 1]], gold: 9, equip: { weapon: 'cudgel' } }
};

export const START_LOCATION = 'sunken_lantern';
