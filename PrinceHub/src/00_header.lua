-- ============================================================
--  PRINCE HUB | ALL IN ONE   (v21)
--  الواجهة = واجهة الهب الكامل، ومضاف لها تبويبات: Kaitun و Cupid و Waves و Impel
--  و Impel Down Zyph و Auto Impel (test)
--
--  هذا الملف مبني من مجلد src/ بالأداة tools/build.js. لا تعدل الملف المبني،
--  عدل الملف بـ src/ وبعدين ابنِ:  node tools/build.js
--
--  ترتيب الملف (دوّر على "MODULE:" أو "NEW TABS" أو "BOOT"):
--    0) CORE            -> النسخة + منع التشغيل مرتين + سجل الأخطاء  (src/00_header.lua)
--    1) MODULE: Cupid      -> سكربت Cupid Dungeon            (src/modules/01_Cupid.lua)
--    2) MODULE: Kaitun     -> سكربت الكايتون                  (src/modules/02_Kaitun.lua)
--    3) MODULE: Waves      -> دنجن الأمواج، سولو/بارتي        (src/modules/03_Waves.lua)
--    4) MODULE: Impel      -> zephyron بطيران الكايتون        (src/modules/04_Impel.lua)
--    5) MODULE: ImpelZyph  -> zephyron الأصلي بدون تعديل      (src/modules/05_ImpelZyph.lua)
--    6) MODULE: ImpelTest  -> Auto Impel (test)               (src/modules/06_ImpelTest.lua)
--    7) MODULE: Hub        -> الهب الكامل + واجهة Linoria     (src/modules/07_Hub.lua)
--    8) NEW TABS           -> التبويبات الجديدة + زر X و P    (src/newtabs/*.lua)
--    9) BOOT               -> التشغيل                         (src/99_boot.lua)
--  أي سطر متعدل بالهب مكتوب جنبه [PRINCE HUB]، والتعديلات الجديدة [PRINCE HUB v18].
--
--  اختياري قبل التحميل:
--    getgenv().Config = { ... }                -- نفس الكونفك القديم
--    getgenv().PrinceHubAutoStart = "Kaitun"   -- أو "Cupid" أو "Waves" أو "WavesParty" أو "Impel"
--                                              -- أو "ImpelZyph" أو "ImpelTest"
--                                              -- أو {"Kaitun","Cupid"} أو false
--    getgenv().PrinceHubForceReload = true     -- يحمّل حتى لو الهب شغّال من قبل
-- ============================================================

-- ############################################################
-- CORE  [PRINCE HUB v18]
-- ############################################################
local PRINCE_HUB_VERSION = "v21"

-- منع التشغيل مرتين: إذا الهب شغّال (واجهته موجودة) ما نحمّل نسخة ثانية فوقه،
-- لأن نسختين يتعاركن على نفس الشخصية والريموتات. بعد Unload من Config يقبل يحمّل.
do
	local prev = getgenv().PrinceHubInstance
	local alive = false
	if type(prev) == "table" and type(prev.alive) == "function" then
		local ok, res = pcall(prev.alive)
		alive = ok and res == true
	end
	if alive and getgenv().PrinceHubForceReload ~= true then
		warn("[Prince Hub] already running (" .. tostring(prev.version) .. "). Unload it from Config first, or set getgenv().PrinceHubForceReload = true")
		pcall(function()
			local lib = getgenv().Library
			if lib and lib.Notify then lib:Notify("Prince Hub is already running", 5) end
		end)
		return
	end
	getgenv().PrinceHubForceReload = nil
end

-- سجل أخطاء واحد لكل الهب (أخطاء الموديولات والتبويبات)، ينسخ من Config > Prince Hub
local PH_Log = { entries = {}, max = 60, total = 0 } -- total = كل الأخطاء من البداية (حتى المنحذفة)
getgenv().PrinceHubLog = PH_Log

function PH_Log.add(where, msg)
	local list = PH_Log.entries
	PH_Log.total = PH_Log.total + 1
	list[#list + 1] = { t = os.time(), where = tostring(where), msg = tostring(msg) }
	while #list > PH_Log.max do table.remove(list, 1) end
	warn("[Prince Hub] " .. tostring(where) .. ": " .. tostring(msg))
end

function PH_Log.report()
	local exec = "?"
	pcall(function() if identifyexecutor then exec = tostring(identifyexecutor()) end end)
	local out = {
		"Prince Hub " .. PRINCE_HUB_VERSION .. " | PlaceId " .. tostring(game.PlaceId) .. " | JobId " .. tostring(game.JobId),
		"Executor: " .. exec,
		"Errors: " .. #PH_Log.entries,
	}
	for _, e in ipairs(PH_Log.entries) do
		out[#out + 1] = os.date("%H:%M:%S", e.t) .. " [" .. e.where .. "] " .. e.msg
	end
	return table.concat(out, "\n")
end

-- يشغّل دالة محمية ويسجل الخطأ ويا الـ traceback إذا صار
local function PH_try(where, fn, ...)
	local res = table.pack(xpcall(fn, function(err)
		return tostring(err) .. "\n" .. debug.traceback("", 2)
	end, ...))
	if not res[1] then
		PH_Log.add(where, res[2])
		return false, res[2]
	end
	return true, table.unpack(res, 2, res.n)
end

local Modules = {}
local PrinceNewTabs = {}
