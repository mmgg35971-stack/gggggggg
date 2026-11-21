# Prince Hub (GPO)

سكربت Roblox للعبة GPO بواجهة Linoria بثيم هالوين 🎃، وبيه تبويبات Kaitun و Cupid و Waves و Impel و Impel Down Zyph و Auto Impel (test) و **Prince AI** (ذكاء اصطناعي بالتحليل المنطقي، شوف `CHANGELOG.md`).

## الملف اللي تشغّله
**`dist/PrinceHub_AllInOne.lua`**: ملف واحد فيه كلشي. لا تعدّل عليه مباشرة، لأنه ينبني من `src/`.

```lua
-- اختياري قبل التشغيل:
getgenv().Config = { MAIN = { LEVEL = 675, TWEEN_SPEED = 70, PS_CODE = "" } }
getgenv().PrinceHubAutoStart = "Kaitun"   -- "Cupid" / "Waves" / "WavesParty" / "Impel" / "ImpelZyph" / "ImpelTest" / {"Kaitun","Cupid"} / false
getgenv().PrinceHubForceReload = true     -- يحمّل حتى لو الهب شغّال
```

## ترتيب المشروع
```
src/
  manifest.txt          ترتيب الملفات داخل الملف النهائي
  00_header.lua         CORE: النسخة، منع التشغيل مرتين، سجل الأخطاء (PH_Log / PH_try)
  modules/
    01_Cupid.lua        Cupid Dungeon
    02_Kaitun.lua       Auto Kaitun + Sea 2 PS
    03_Waves.lua        دنجن الأمواج (Solo / Party)
    04_Impel.lua        zephyron بطيران الكايتون
    05_ImpelZyph.lua    zephyron الأصلي حرفياً (بدون تعديل)
    06_ImpelTest.lua    Auto Impel (test): المحرك الجديد + نظام الفحص
    07_Hub.lua          الهب الكامل + مكتبة Linoria
  newtabs/
    01_core.lua         أدوات مشتركة + Config اللودر
    02_state.lua        الحفظ (PrinceHubNewTabs.json) + الإعدادات + تشغيل الموديولات
    10_kaitun.lua ... 15_impeltest.lua   تشغيل/إيقاف كل موديول
    20_mini_toggle.lua  زر X والمربع P
    21_stats_overlay.lua نافذة الـ stats
    22_ui_scale.lua     حجم الواجهة للهاتف
    23_ai_core.lua      Prince AI: العقل (حقائق fuzzy + قواعد + قرار + تعلم + أسئلة)، بدون Roblox
    24_ai_game.lua      Prince AI: الحواس والأفعال والتبويب
    25_halloween_ui.lua ثيم الهالوين (ألوان، gradient، 🎃، قمر، جزيئات)
    30_build_tabs.lua   بناء التبويبات
    40_boot.lua         تشغيل الموديولات المفعّلة
  99_boot.lua           BOOT
tools/
  build.js              يبني dist/ ويفحصه
  check.js              فحص سنتاكس Luau
  lint.js               المتغيرات اللي ما معرّفة + حدود Luau (200 local / 200 upvalue)
  lint-baseline.json    الأسماء المسموحة (APIs الإكزكيوتر وغيرها)
tests/                  اختبارات تشغيل بـ Lua 5.3 (fengari)
docs/                   سجل المحادثات القديمة
```

## البناء والفحص
يحتاج Node.js 18 أو أحدث.
```bash
cd PrinceHub
npm install
node tools/build.js   # يبني dist/PrinceHub_AllInOne.lua ويفحصه
npm test              # فحص + اختبارات
```
البناء يفشل إذا صار:
- خطأ سنتاكس (رقم السطر يكون بالملف المبني)
- متغير ما معرّف (غلط إملائي، أو local ينستعمل قبل ما ينعرّف)
- دالة تعدّت حدود Luau

## إضافة ميزة جديدة
1. عدّل الملف المناسب بـ `src/` (أو سوي ملف جديد وضيفه بـ `src/manifest.txt` بالمكان الصح).
2. علّم السطر بـ `-- [PRINCE HUB vXX]`.
3. `node tools/build.js`.
4. موديول Cupid واصل **199/200** local بمستواه الأساسي: لا تضيف local جديد هناك، حط الأشياء الجديدة بجدول موجود أو داخل `do ... end`.

## الفحص باللعبة
إذا صار خطأ: **Config > Prince Hub > Copy error log** ودز السجل.
