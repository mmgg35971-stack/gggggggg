-- ------------------------------------------------------------
-- الحفظ
-- ------------------------------------------------------------
local function PN_load()
	local ok, data = pcall(function()
		if isfile and readfile and isfile(PN_SAVE_FILE) then
			return PN_Http:JSONDecode(readfile(PN_SAVE_FILE))
		end
	end)
	return (ok and type(data) == "table") and data or {}
end

local PN_Saved = PN_load()
PN_Saved.Kaitun = type(PN_Saved.Kaitun) == "table" and PN_Saved.Kaitun or {}
PN_Saved.Cupid  = type(PN_Saved.Cupid)  == "table" and PN_Saved.Cupid  or {}
PN_Saved.Waves  = type(PN_Saved.Waves)  == "table" and PN_Saved.Waves  or {}
PN_Saved.Impel  = type(PN_Saved.Impel)  == "table" and PN_Saved.Impel  or {}
PN_Saved.Zyph   = type(PN_Saved.Zyph)   == "table" and PN_Saved.Zyph   or {}
PN_Saved.ImpelTest = type(PN_Saved.ImpelTest) == "table" and PN_Saved.ImpelTest or {}
PN_Saved.Overlay = type(PN_Saved.Overlay) == "table" and PN_Saved.Overlay or {}
PN_Saved.UI      = type(PN_Saved.UI)      == "table" and PN_Saved.UI      or {}

-- الحفظ يتأخر شوية حتى السلايدر ما يكتب الملف بكل حركة
local PN_savePending = false
local function PN_save()
	if PN_savePending then return end
	PN_savePending = true
	task.delay(0.5, function()
		PN_savePending = false
		pcall(function()
			if writefile then
				writefile(PN_SAVE_FILE, PN_Http:JSONEncode(PN_Saved))
			end
		end)
	end)
end

-- القيم الحالية: المحفوظ من الواجهة > Config > الافتراضي مال السكربت
local KS = PN_Saved.Kaitun
local CS = PN_Saved.Cupid
local WS = PN_Saved.Waves
WS.weapons = type(WS.weapons) == "table" and WS.weapons or {} -- السلاح محفوظ لكل حساب
local IS = PN_Saved.Impel
IS.weapons = type(IS.weapons) == "table" and IS.weapons or {}
IS.shop = type(IS.shop) == "table" and IS.shop or nil

local Kaitun = {
	enabled  = KS.enabled,
	joinSea2 = PN_pick(KS.joinSea2, PN_pick(PN_UMain.AUTO_JOIN_SEA2, true)),
	level    = PN_pick(KS.level,    PN_pick(PN_UMain.LEVEL, 675)),
	tween    = PN_pick(KS.tween,    PN_pick(PN_UMain.TWEEN_SPEED, 70)),
	strCap   = PN_pick(KS.strCap,   PN_pick(PN_get(PN_UMain, "STAT_CAP", "STRENGTH"), 750)),
	defCap   = PN_pick(KS.defCap,   PN_pick(PN_get(PN_UMain, "STAT_CAP", "DEFENSE"), 1275)),
	geppo    = PN_pick(KS.geppo,    PN_pick(PN_get(PN_UMain, "STYLE", "Geppo"), true)),
	buso     = PN_pick(KS.buso,     PN_pick(PN_get(PN_UMain, "HAKI", "Buso"), true)),
	scroll   = PN_pick(KS.scroll,   PN_pick(PN_get(PN_UMain, "ITEM", "World Scroll"), true)),
	psCode   = PN_pick(KS.psCode, ""),
	loaded = false, cfg = nil,
}
-- إذا ما محفوظ شي: نشغّل حسب AUTO_KAITUN بالكونفك (حتى loaders البوتات القديمة تظل تشتغل)
if Kaitun.enabled == nil then Kaitun.enabled = PN_UMain.AUTO_KAITUN == true end

local Cupid = {
	enabled       = CS.enabled == true,
	tween         = PN_pick(CS.tween, PN_pick(PN_UMain.TWEEN_SPEED, 150)),
	weapon        = PN_pick(CS.weapon, PN_get(PN_UMain, "WEAPONS", PN_LocalPlayer.Name) or ""),
	joinUniverse  = PN_pick(CS.joinUniverse,  PN_pick(PN_UMain.AUTO_JOIN_UNIVERSE_HUB, true)),
	joinCupid     = PN_pick(CS.joinCupid,     PN_pick(PN_UMain.AUTO_JOIN_CUPID, true)),
	autoDungeon   = PN_pick(CS.autoDungeon,   PN_pick(PN_UMain.AUTO_DUNGEON, true)),
	autoStore     = PN_pick(CS.autoStore,     PN_pick(PN_UMain.AUTO_STORE, true)),
	autoReplay    = PN_pick(CS.autoReplay,    PN_pick(PN_UMain.AUTO_REPLAY, true)),
	autoEquip     = PN_pick(CS.autoEquip,     PN_pick(PN_UMain.AUTO_EQUIP_ITEMS, true)),
	privacyCam    = PN_pick(CS.privacyCam,    PN_pick(PN_UMain.DUNGEON_PRIVACY_CAMERA, true)),
	hidePlayerGui = PN_pick(CS.hidePlayerGui, PN_pick(PN_UMain.PRIVACY_HIDE_PLAYER_GUI, true)),
	loaded = false, cfg = nil,
}

local Waves = {
	enabled      = WS.enabled == true,
	mode         = (WS.mode == "Party") and "Party" or "Solo",
	targetWave   = PN_pick(tonumber(WS.targetWave), 25),
	tween        = PN_pick(tonumber(WS.tween), 100),
	hover        = PN_pick(tonumber(WS.hover), 8.5),
	radius       = PN_pick(tonumber(WS.radius), 100),
	returnCenter = PN_pick(WS.returnCenter, true),
	buso         = PN_pick(WS.buso, true),
	split        = PN_pick(WS.split, true),
	weapon       = PN_pick(WS.weapons[PN_LocalPlayer.Name], ""), -- "" = تلقائي
}
if type(Waves.weapon) ~= "string" then Waves.weapon = "" end

-- Impel: الافتراضي من getgenv().Config.Misc / CircleQueue (نفس كونفك zephyron) إذا موجود
local PN_ZMisc = type(PN_UserConfig.Misc) == "table" and PN_UserConfig.Misc or {}
local PN_ZCircle = type(PN_UserConfig.CircleQueue) == "table" and PN_UserConfig.CircleQueue or {}
local Impel = {
	enabled     = IS.enabled == true,
	tween       = PN_pick(tonumber(IS.tween), 70),
	psCode      = PN_pick(IS.psCode, tostring(PN_ZMisc.PsCode or "")),
	webhook     = PN_pick(IS.webhook, tostring(PN_ZMisc.WebhookURL or "")),
	fpsCap      = PN_pick(tonumber(IS.fpsCap), tonumber(PN_ZMisc.FpsCap) or 25),
	fastMode    = PN_pick(IS.fastMode, PN_ZMisc.FastMode == true),
	errorKick   = PN_pick(IS.errorKick, false),
	noclip      = PN_pick(IS.noclip, true),
	raycast     = PN_pick(IS.raycast, true),
	tpF1        = PN_pick(tonumber(IS.tpF1), 2600),
	tpF2        = PN_pick(tonumber(IS.tpF2), 2800),
	tpF3        = PN_pick(tonumber(IS.tpF3), 3000),
	tpF4        = PN_pick(tonumber(IS.tpF4), 1500),
	circleOn    = PN_pick(IS.circleOn, PN_ZCircle.Enabled ~= false),
	circleOrder = PN_pick(IS.circleOrder, table.concat(type(PN_ZCircle.Order) == "table" and PN_ZCircle.Order or {}, ",")),
}

-- getgenv().PrinceHubAutoStart = "Kaitun" / "Cupid" / "Waves" / "WavesParty" / "Impel" / {"Kaitun","Cupid"} / false
local PN_Forced = getgenv().PrinceHubAutoStart
local PN_NoAuto = PN_Forced == false
if type(PN_Forced) == "string" then PN_Forced = { PN_Forced } end
if type(PN_Forced) == "table" then
	for _, id in ipairs(PN_Forced) do
		if id == "Kaitun" then Kaitun.enabled = true end
		if id == "Cupid" then Cupid.enabled = true end
		if id == "Waves" then Waves.enabled = true; Waves.mode = "Solo" end
		if id == "WavesParty" then Waves.enabled = true; Waves.mode = "Party" end
		if id == "Impel" then Impel.enabled = true end
		if id == "ImpelZyph" then PN_Saved.Zyph.enabled = true end
		if id == "ImpelTest" then PN_Saved.ImpelTest.enabled = true end
	end
end

function PrinceNewTabs.kaitunActive()
	return Kaitun.enabled == true and not PN_NoAuto
end

-- ------------------------------------------------------------
-- Config مال الهب القديم: نطفي AUTO_KAITUN / AUTO_JOIN_SEA2 (صارت للتبويب الجديد)
-- ------------------------------------------------------------
function PrinceNewTabs.prepareHubConfig()
	local cfg = PN_deepCopy(PN_UserConfig)
	cfg.MAIN = cfg.MAIN or {}
	cfg.MAIN.AUTO_KAITUN = false
	cfg.MAIN.AUTO_JOIN_SEA2 = false
	if (Kaitun.enabled or Cupid.enabled) and not PN_NoAuto then
		cfg.MAIN.AUTO_REJOIN = false -- الموديول الجديد عنده Auto Rejoin مالته
	end
	getgenv().Config = cfg
end

local PN_HubConfig = nil -- getgenv().Config مال الهب بعد ما يحمّل

-- يشغّل موديول ويرجع الـ Config table مالته (نفس اللي يقراه داخلياً)
local function PN_startModule(id, cfg)
	getgenv().Config = cfg
	task.spawn(function()
		local ok, err = pcall(Modules[id])
		if not ok then
			pcall(function()
				getgenv().Library:Notify("[" .. id .. "] error: " .. tostring(err), 10)
			end)
		end
	end)
	local moduleCfg = getgenv().Config
	if PN_HubConfig then getgenv().Config = PN_HubConfig end
	return moduleCfg
end

