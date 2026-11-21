-- ============================================================
--  PRINCE HUB | ALL IN ONE
--  الواجهة = واجهة الهب الكامل، ومضاف لها 4 تبويبات: Kaitun و Cupid و Waves و Impel
--
--  ترتيب الملف (دوّر على "MODULE:" أو "NEW TABS" أو "BOOT"):
--    1) MODULE: Cupid   -> سكربت Cupid Dungeon (يشتغل من تبويب Cupid)
--    2) MODULE: Kaitun  -> سكربت الكايتون الجديد (يشتغل من تبويب Kaitun)
--    3) MODULE: Waves   -> دنجن الأمواج، سولو/بارتي (يشتغل من تبويب Waves)
--    4) MODULE: Impel   -> سكربت zephyron للـ Impel Down بطيران الكايتون (تبويب Impel)
--    5) MODULE: Hub     -> الهب الكامل + الواجهة (أي سطر عدّلته مكتوب جنبه [PRINCE HUB])
--    6) NEW TABS        -> كود التبويبات الجديدة + زر X والمربع الصغير
--    7) BOOT            -> التشغيل
--
--  اختياري قبل التحميل:
--    getgenv().Config = { ... }                -- نفس الكونفك القديم
--    getgenv().PrinceHubAutoStart = "Kaitun"   -- أو "Cupid" أو "Waves" أو "WavesParty" أو "Impel"
--                                              -- أو {"Kaitun","Cupid"} أو false
-- ============================================================

local Modules = {}
local PrinceNewTabs = {}

