-- ------------------------------------------------------------
-- Kaitun start / stop
-- ------------------------------------------------------------
local function kaitunBuildConfig()
	local cfg = PN_deepCopy(PN_UserConfig)
	cfg.MAIN = cfg.MAIN or {}
	local m = cfg.MAIN
	m.AUTO_KAITUN = true
	m.AUTO_JOIN_SEA2 = Kaitun.joinSea2
	m.LEVEL = Kaitun.level
	m.TWEEN_SPEED = Kaitun.tween
	m.STAT_CAP = { STRENGTH = Kaitun.strCap, DEFENSE = Kaitun.defCap }
	m.STYLE = { Geppo = Kaitun.geppo }
	m.HAKI = { Buso = Kaitun.buso }
	m.ITEM = { ["World Scroll"] = Kaitun.scroll }
	cfg.GET = nil -- GET يتقدم على MAIN داخل السكربت، فنخلي الواجهة هي الأساس
	if Kaitun.psCode ~= "" then m.PS_CODE = Kaitun.psCode end
	return cfg
end

-- يحدّث الإعدادات وهو شغّال
local function kaitunApplyLive()
	local c = Kaitun.cfg and Kaitun.cfg.MAIN
	if not c then return end
	c.LEVEL = Kaitun.level
	c.TWEEN_SPEED = Kaitun.tween
	c.AUTO_JOIN_SEA2 = Kaitun.joinSea2
	c.STAT_CAP = c.STAT_CAP or {}
	c.STAT_CAP.STRENGTH = Kaitun.strCap
	c.STAT_CAP.DEFENSE = Kaitun.defCap
	c.STYLE = c.STYLE or {}; c.STYLE.Geppo = Kaitun.geppo
	c.HAKI = c.HAKI or {}; c.HAKI.Buso = Kaitun.buso
	c.ITEM = c.ITEM or {}; c.ITEM["World Scroll"] = Kaitun.scroll
	local H = getgenv().PrinceKaitunOnly
	if H then H.teleportSpeed = Kaitun.tween end
end

local function kaitunSetPSCode(code)
	code = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
	Kaitun.psCode = code
	if code ~= "" then
		getgenv().KaitunSea2Code = code
		pcall(function() if writefile then writefile("PrinceKaitunSea2PSCode.txt", code) end end)
		if Kaitun.cfg and Kaitun.cfg.MAIN then Kaitun.cfg.MAIN.RESOLVED_PS_CODE = code end
	end
end

local function kaitunStart()
	if Kaitun.loaded then
		local H = getgenv().PrinceKaitunOnly
		kaitunApplyLive()
		if H and H.startKaitunFarm then task.spawn(H.startKaitunFarm) end
		return
	end
	Kaitun.loaded = true
	if Kaitun.psCode ~= "" then kaitunSetPSCode(Kaitun.psCode) end
	Kaitun.cfg = PN_startModule("Kaitun", kaitunBuildConfig())
end

local function kaitunStop()
	getgenv().KaitunSea2Pending = false
	local H = getgenv().PrinceKaitunOnly
	if H and H.stopKaitunFarm then pcall(H.stopKaitunFarm) end
	if Kaitun.cfg and Kaitun.cfg.MAIN then
		Kaitun.cfg.MAIN.AUTO_JOIN_SEA2 = false
		Kaitun.cfg.MAIN.AUTO_REJOIN = false
	end
end

