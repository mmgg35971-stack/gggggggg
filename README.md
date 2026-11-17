# حوليات وادي الغسق · Chronicles of the Dimmering Vale

لعبة تقمّص أدوار نصية في عالم مظلم من العصور الوسطى. تكتب ما تفعله بحرية، بالعربية أو الإنجليزية، ويردّ عليك راوٍ. المحرك يحسب نتيجة كل شيء، والذكاء الاصطناعي يروي فقط.

A chat-based dark medieval RPG. You type whatever you want to do, in Arabic or English. The engine decides what happens and a narrator tells it.

---

## العربية

### ما الذي يعمل الآن (المرحلة الأولى كاملة، وأجزاء من المراحل 2 و3)
- **واجهة محادثة** بطابع العصور الوسطى: رقّ، حبر، أختام، خطوط Amiri وReem Kufi وCinzel. تعمل من اليمين لليسار بالعربية.
- **موسيقى أصلية تُولَّد داخل اللعبة**: عود وناي وربابة وطبل وأجراس وكورال، بمقامات الحجاز والدوريان وغيرها. لكل مكان مزاج موسيقي، ولحن رئيسي بعنوان «أنشودة الطريق الرمادي» تظهر كلماته على الشاشة الأولى.
- **إنشاء الشخصية**: الاسم، كيف يُشار إليك، الماضي (7 خلفيات)، وتوزيع نقاط على 8 خصائص.
- **عالم أولي قابل للعب**: 15 مكاناً، و11 شخصية لها أهداف ومخاوف وأسرار وجداول يومية، و7 فصائل، ومهمّتان يمكن حلّهما بأكثر من طريقة.
- **فهم الأفعال الحرة**: محلّل محلي للعربية والإنجليزية، أو Claude عبر الخادم.
- **المحرك يقرر كل شيء**: الحركة، بوابة المدينة ورسومها، الشراء والبيع، الحوار والمواضيع المقفلة، الإقناع والتهديد والرشوة، البحث، العمل، الصيد، القتال والهزيمة.
- **عالم حيّ**: الطقس، الليل والنهار، الجوع والتعب، وأحداث يومية سببية (اللصوص ← نقص الشعير ← غلاء الأسعار ← اضطراب ← دوريات). الإشاعات عن أفعالك تصل إلى المدن الأخرى بعد وقت السفر. العالم يتقدّم وأنت غائب (ساعة حقيقية = ساعة في اللعبة، حتى 7 أيام).
- **ذاكرة طويلة**: سجلّ أحداث، وذكريات لكل شخصية لا تُنسى منها المهمّة، و«تاريخ الوادي» للأحداث الكبرى، وملخّص متجدّد.
- **الحفظ**: تلقائي على الجهاز، مع تصدير واستيراد وحذف.
- **67 اختباراً آلياً** تغطي كل نظام.

### البنية
```
app/      الواجهة: HTML وCSS وJS، والموسيقى، والخطوط
shared/   محرك اللعبة (يعمل في الهاتف وفي الخادم)
  world.js    بيانات العالم فقط
  state.js    حالة اللعبة، الوقت، إنشاء الشخصية
  engine.js   قواعد الأفعال ونتائجها (المصدر الوحيد للحقيقة)
  sim.js      الجداول، الطقس، الأحداث السببية، الإشاعات، التقدّم أثناء الغياب
  memory.js   الأحداث، الذكريات، التاريخ، الاسترجاع، حزمة السياق للذكاء الاصطناعي
  parser.js   فهم الأفعال محلياً
  narrator.js الراوي المحلي
  schemas.js  مخططات المخرجات المنظّمة وتنقيتها
  game.js     ترتيب الدور: فهم ← محرك ← رواية ← ذاكرة
server/   خادم صغير يحمل مفتاح Anthropic ولا شيء غيره
android/  مشروع Android (Capacitor)
tests/    الاختبارات
```

**لماذا هكذا؟** طلبتَ ألّا يتحكم الذكاء الاصطناعي بالبيانات مباشرة. لذلك يقترح Claude نيّة اللاعب بصيغة JSON صارمة، فينقّيها المحرك ويطبّقها برمي نرد محدّد البذرة. ثم يتسلّم Claude النتائج ليرويها فقط. لا يستطيع أن يُنطق شخصية غائبة، ولا أن يغيّر مشاعر شخصية بعكس ما قرّره المحرك، ولا أن يمنح شيئاً. إذا تعطّل الاتصال يكمل الراوي المحلي الدور نفسه دون أن يضيع شيء.

**المفتاح لا يوجد في التطبيق أبداً.** التطبيق يتصل بخادمك، والخادم يتصل بـ Anthropic.

### تقليل التكلفة
- نموذجان: `claude-haiku-5-5` لفهم الأفعال (سريع ورخيص)، و`claude-opus-5-5` للرواية.
- تخزين مؤقت لتعليمات النظام (prompt caching).
- لا يُرسَل النص الكامل للمحادثة. تُرسَل حزمة صغيرة فيها حالة المكان، والشخصيات الحاضرة وذكرياتها، وأهم الأحداث المسترجعة، والملخّص.
- مخرجات منظّمة (JSON schema)، وحدّ لعدد الطلبات لكل عنوان IP، ورمز تطبيق اختياري.

### التشغيل على الكمبيوتر
```bash
npm install
npm test                      # الاختبارات
ANTHROPIC_API_KEY=sk-ant-... npm start   # بدون المفتاح تعمل اللعبة بالراوي المحلي
# افتح http://localhost:8787
```
متغيرات الخادم:

| المتغير | الوظيفة |
|---|---|
| `ANTHROPIC_API_KEY` | مفتاح Anthropic (على الخادم فقط) |
| `APP_TOKEN` | رمز يجب أن يرسله التطبيق (اختياري لكن يُنصح به) |
| `PORT` | المنفذ، الافتراضي 8787 |
| `RATE_LIMIT_PER_MIN` | الحد الأقصى للطلبات لكل IP في الدقيقة، الافتراضي 40 |
| `AI_FAST_MODEL` / `AI_NARRATOR_MODEL` | تغيير النماذج |
| `AI_NARRATOR_EFFORT` | low / medium / high، الافتراضي low |

ارفع الخادم على أي استضافة Node (Render أو Railway أو Fly.io أو VPS)، ثم ضع عنوانه ورمز التطبيق في **الإعدادات** داخل اللعبة واضغط «اختبار الاتصال».

### بناء ملف APK
البناء يتم على خوادم GitHub. أدوات Google لـ Android غير متاحة في البيئة التي بُني فيها المشروع.
1. ارفع المشروع إلى مستودع على GitHub.
2. يعمل تلقائياً سير العمل `.github/workflows/android-apk.yml`: يشغّل الاختبارات، ثم يجمّع الواجهة، ثم يبني `dimmering-vale.apk`.
3. نزّل الملف من صفحة **Releases** (إصدار `latest`) أو من **Actions ← Artifacts**، وثبّته على الهاتف (اسمح بالتثبيت من هذا المصدر).

للبناء محلياً (يتطلب Android Studio وJDK 21): `npm run cap:sync && cd android && ./gradlew assembleDebug`.

### تغيير مزوّد الذكاء الاصطناعي
المزوّد كائن فيه `interpret()` و`narrate()` (انظر `server/ai/anthropic.js`). أنشئ ملفاً آخر بنفس الشكل ومرّره إلى `createApp({ provider })`.

### قاعدة البيانات
الحفظ حالياً في تخزين الجهاز (localStorage داخل WebView)، لأن اللعبة لاعب واحد وتعمل دون اتصال. الحالة كلها JSON بإصدار (`version`)، فيسهل لاحقاً إضافة مزامنة سحابية (مثل Postgres أو SQLite على الخادم) دون تغيير المحرك.

### الخطة القادمة
- **المرحلة 2**: مزيد من المعدات والحِرَف، وشجرة مهارات أعمق، ورفاق لهم قصص شخصية.
- **المرحلة 3**: فصائل تتصرّف من تلقاء نفسها (حروب، تحالفات، ملكية)، وأسرار عالمية متعدّدة الطبقات.
- **المرحلة 4**: بحث دلالي بالمتجهات في الذاكرة، وتوليد مهام بالذكاء الاصطناعي يتحقق منها المحرك.

---

## English

### What works now
- Medieval chat UI, Arabic RTL and English. The narration follows the language you type in.
- Original procedural soundtrack (Web Audio): oud/lute, recorder, hurdy-gurdy drone, frame drum, bells, choir; modal (hijaz, dorian, aeolian, phrygian, mixolydian); per-location moods; a composed theme, *The Ballad of the Ashen Road*.
- Character creation, a playable seed world (15 places, 11 NPCs with schedules, goals and secrets, 7 factions, 2 multi-solution quests).
- A deterministic, seeded engine for movement, gate tolls, trade, dialogue topics, social checks, search, work, hunting and fair combat in which you can lose.
- Living world: weather, day/night, needs, a causal daily event engine, rumours with travel delay, and world progression while you're away.
- Long-term memory: events, NPC memories with forgetting (important ones are kept), a living chronicle, and a rolling summary.
- Local saves with export, import and delete. 67 automated tests.

### Run
```bash
npm install && npm test
ANTHROPIC_API_KEY=... APP_TOKEN=... npm start   # http://localhost:8787
```
Without a key the game runs fully on the built-in parser and chronicler.

### APK
Push to GitHub. `.github/workflows/android-apk.yml` tests, builds and publishes `dimmering-vale.apk` as the `latest` release and as an Actions artifact. The debug APK installs on any Android 6+ phone. Signing a Play Store release needs a keystore added as a repository secret.

### Architecture in one line
Player text → intent (Claude Haiku with JSON schema, or the offline parser) → sanitize → **engine applies** → narration (Claude Opus with JSON schema, or offline) → sanitize (only present NPCs speak; attitude changes are clamped and must agree with the engine) → memory.

### Credits
Fonts: Cinzel, Cinzel Decorative, IM Fell English, Amiri, Reem Kufi, all under the SIL Open Font License. Music, world and text are original to this project.
