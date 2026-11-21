-- ------------------------------------------------------------
-- Cupid start / stop
-- ------------------------------------------------------------
local function cupidBuildConfig()
	local cfg = PN_deepCopy(PN_UserConfig)
	cfg.MAIN = cfg.MAIN or {}
	local m = cfg.MAIN
	m.TWEEN_SPEED = Cupid.tween
	m.AUTO_JOIN_UNIVERSE_HUB = Cupid.joinUniverse
	m.AUTO_JOIN_UNIVERSE = nil
	m.AUTO_JOIN_CUPID = Cupid.joinCupid
	m.AUTO_JOIN_CUPID_DUNGEON = nil
	m.AUTO_DUNGEON = Cupid.autoDungeon
	m.AUTO_STORE = Cupid.autoStore
	m.AUTO_REPLAY = Cupid.autoReplay
	m.AUTO_EQUIP_ITEMS = Cupid.autoEquip
	m.DUNGEON_PRIVACY_CAMERA = Cupid.privacyCam
	m.PRIVACY_HIDE_PLAYER_GUI = Cupid.hidePlayerGui
	if Cupid.weapon ~= "" then
		m.WEAPONS = type(m.WEAPONS) == "table" and m.WEAPONS or {}
		m.WEAPONS[PN_LocalPlayer.Name] = Cupid.weapon
	end
	return cfg
end

local function cupidApplyLive()
	local c = Cupid.cfg and Cupid.cfg.MAIN
	if not c then return end
	c.TWEEN_SPEED = Cupid.tween
	c.AUTO_STORE = Cupid.autoStore
	c.AUTO_REPLAY = Cupid.autoReplay
	c.AUTO_EQUIP_ITEMS = Cupid.autoEquip
	if Cupid.weapon ~= "" then
		c.WEAPONS = type(c.WEAPONS) == "table" and c.WEAPONS or {}
		c.WEAPONS[PN_LocalPlayer.Name] = Cupid.weapon
		local AD = getgenv().PrinceCupidAD
		if AD then AD.weapon = Cupid.weapon end
	end
end

local function cupidStart()
	-- سكربت الكيوبد مصمم ينعاد تشغيله (يصفّر PrinceProjectStopped والـ tokens)
	Cupid.loaded = true
	Cupid.cfg = PN_startModule("Cupid", cupidBuildConfig())
end

local function cupidStop()
	getgenv().PrinceProjectStopped = true
	getgenv().PrinceProjectAutoJoinCupidDungeonValue = false
	local AD = getgenv().PrinceCupidAD
	if AD then AD.enabled = false end
	pcall(function()
		local conn = getgenv().PrinceProjectEarlyPrivacyCameraConn
		if conn then conn:Disconnect() end
		getgenv().PrinceProjectEarlyPrivacyCameraConn = nil
	end)
	task.delay(0.3, function()
		pcall(function()
			local cam = workspace.CurrentCamera
			local char = PN_LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = 70
			if hum then cam.CameraSubject = hum end
		end)
	end)
end

