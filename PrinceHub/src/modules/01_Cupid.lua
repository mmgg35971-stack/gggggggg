-- ############################################################
-- MODULE: Cupid  |  Cupid Dungeon (config only)
-- ############################################################
Modules.Cupid = function(...)

-- ============================================================
-- PRINCE PROJECT | CONFIG-ONLY CUPID DUNGEON SOURCE
-- Removed: old Kaitun, Sea farm, fish, merchant, ESP, misc, movement UI.
-- Kept only: Config, optimization, auto rejoin, universe hub join,
-- Cupid queue, auto dungeon, auto store, auto replay, auto equip items.
-- ============================================================

local DefaultConfig = {
	MAIN = {
		TWEEN_SPEED = 150,

		WEAPONS = {
			['Onesamaaa'] = 'Kraken Blade (Red)',
		},

		AUTO_REJOIN            = true,
		WHITE_SCREEN           = false,
		AUTO_HIDE_UI           = true,
		BOSS_PRIVACY_CAMERA    = true,
		BOSS_PRIVACY_CAMERA_HEIGHT = 520,
		BOSS_PRIVACY_CAMERA_FOV    = 40,
		BOSS_HIDE_HUD_BARS  = true,
		PRIVACY_HIDE_PLAYER_GUI = true,

		-- Sky/privacy view for the whole Cupid Dungeon run, not only Leo/Cupid.
		DUNGEON_PRIVACY_CAMERA = true,
		AUTO_JOIN_UNIVERSE_HUB = true,
		AUTO_JOIN_UNIVERSE     = nil, -- alias support from old configs
		AUTO_JOIN_CUPID        = true,
		AUTO_JOIN_CUPID_DUNGEON = nil, -- alias support from old configs
		AUTO_DUNGEON           = true,
		AUTO_STORE             = true,
		AUTO_REPLAY            = true,
		AUTO_EQUIP_ITEMS       = true,
		SHOW_WAYPOINT_UI       = false,
		SHOW_HP_BAR           = false,

		-- Safety timings for reported issues:
		-- prevents moving from spawn after death, prevents rushing barriers,
		-- and gives weapons time to enter hotbar/backpack.
		RESPAWN_GRACE_SECONDS  = 12,
		DUNGEON_ENTRY_TIMEOUT  = 120,
		NPC_WAIT_SECONDS       = 2.5,
		WAYPOINT_CLEAR_SECONDS = 12,
		WAYPOINT_MOVE_DELAY = 0,
		MIN_EMPTY_WAYPOINT_SECONDS = 0.10,
		NPC_SPAWN_GRACE_SECONDS = 2.0,
		POST_WAYPOINT_RESCAN_SECONDS = 1.15,
		POST_WAYPOINT_RESCAN_INTERVAL = 0.15,
		STUCK_RESET_SECONDS    = 25,
		LEO_POST_ROUTE_SEARCH_SECONDS = 3,
		CUPID_AGGRESSIVE_MODE = true,
		CUPID_STUCK_ATTACK_UNLOCK_SECONDS = 1.2,

		-- Extra route sweep so NPCs between two waypoints are not skipped.
		ROUTE_KILL_RADIUS      = 165,
		ROUTE_SWEEP_STEP       = 45,
		ROUTE_SWEEP_TIMEOUT    = 4.0,
		ROUTE_SWEEP_ENABLED    = true,
		START_DELAY_SECONDS    = 0,

		-- Combat pose: same idea as the old route source.
		-- The character keeps a controlled rotated CFrame while hovering.
		HOVER_HEIGHT           = 11.5,
		BOSS_HOVER_HEIGHT      = 11,
		BOSS_TWEEN_SPEED       = 130,
		BOSS_BLOCK_HOLD        = 1.4,
		BOSS_WAYPOINT_DELAY    = 0,
		LEO_TO_CUPID_TWEEN_SPEED = 120,
		LEO_TO_CUPID_WAYPOINT_DELAY = 0.05,

		HIT_ROTATION_X         = -90,
		HIT_ROTATION_Y         = 0,
		HIT_ROTATION_Z         = 0,

		-- Leo / Flame Pillar behavior:
		-- when Leo casts Flame Pillar, stay around this distance from him
		-- for this duration, instead of running far away.
		LEO_FLAME_PILLAR_DISTANCE = 65,
		LEO_FLAME_PILLAR_HOLD_TIME = 3,
		LEO_FLAME_PILLAR_GROUND_OFFSET = 0,
		LEO_FLAME_PILLAR_GROUND_Y = 506.753,
		LEO_FLAME_PILLAR_GROUND_REFERENCE = Vector3.new(-1094.156, 506.753, -4186.957),
		LEO_FLAME_PILLAR_USE_OLD_FLEE = true,
		LEO_FIXED_HOVER_HEIGHT = true,
		-- If true, Leo combat position tracks Leo's X/Z every frame instead of
		-- staying stuck on an old center point. Y stays fixed from LEO_FIXED_BASE_Y.
		LEO_TRACK_CENTER = true,
		-- Leo uses the same tracking style as Cupid Queen: refresh target position
		-- constantly, no lookAt center lock, but keep Y fixed so we do not follow
		-- Leo into the air.
		LEO_USE_CUPID_TRACK_STYLE = true,
		LEO_FIXED_BASE_Y = 506.753,
		LEO_PILLAR_FIXED_WAYPOINT = Vector3.new(-1079.728, 507.296, -3948.496),
		LEO_PILLAR_FIXED_HOLD_TIME = 5,
		LEO_HOVER_HEIGHT = 11,
		BLOCK_HOLD_EXTRA_SECONDS = 1.4,

		-- Waypoint 26 patrol tuning.
		-- This waypoint is the back-and-forth patrol area.
		PATROL_DURATION_SECONDS = 28,
		PATROL_CLEAR_SECONDS = 0.35,

		-- Cupid statue phase:
		-- keep scanning dynamically because statues can spawn/refresh one by one.
		STATUE_SEARCH_SECONDS = 45,
		STATUE_EMPTY_GRACE_SECONDS = 2.5,
		STATUE_SCAN_RADIUS = 450,
		STATUE_PICK_CLOSEST = true,
		STATUE_USE_HEART_TARGETS = true,
		-- Heart is used as a landmark, but damage should target statue.hitbox.
		-- barrelHP is the real life value when exposed.
		STATUE_HEART_HIT_SECONDS = 4.5,
		STATUE_KEEP_NOCLIP = true,
		STATUE_TWEEN_SPEED = 70,
		DEBUG_STATUES = false,
		DEBUG_BOSS_ANIMS = false,

		-- Leo privacy camera/HUD starts before the formal fightBoss phase.
		-- Leo usually spawns about 2.9s after waypoint 32.
		LEO_PRIVACY_START_WAYPOINT = 34,
		LEO_PRIVACY_START_DELAY = 2.9,

		EQUIP_ITEMS = {
			["Virtuous Cupid Queen's Outfit"]  = true,
			["Virtuous Cupid Queen's Wings"]   = true,
			["Leo's Blazing Scarf"]            = true,
			["Love Shades"]                    = true,
			["Love Boppers Headband"]          = true,
			["Virtuous Cupid Vanguard Helmet"] = true,
			["Worshiper's Cape"]               = true,
			["Cupid Mask"]                     = true,
		},
	},

	SETTINGS = {
		OPTIMIZATION = {
			FPS_CAP = 60,
			DISABLE3DRENDER = true,
		},
	},
}

local function deepMerge(base, override)
	if type(base) ~= 'table' then base = {} end
	if type(override) ~= 'table' then return base end
	for k, v in pairs(override) do
		if type(v) == 'table' and type(base[k]) == 'table' then
			deepMerge(base[k], v)
		else
			base[k] = v
		end
	end
	return base
end

if type(getgenv().Config) == 'table' then
	deepMerge(DefaultConfig, getgenv().Config)
end
getgenv().Config = DefaultConfig

local Config = getgenv().Config
getgenv().PrinceProjectStopped = false

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local TeleportService = game:GetService('TeleportService')
local VirtualInputManager = game:GetService('VirtualInputManager')
local CoreGui = game:GetService('CoreGui')
local Lighting = game:GetService('Lighting')
local LocalPlayer = Players.LocalPlayer

local MAIN_MENU_PLACE_ID = 1730877806
-- Cupid Dungeon queue lobby and actual run share this PlaceId.
-- Lobby/waiting spawn: Vector3.new(20003.221, 5.889, -7.513)
-- Real dungeon spawn:  Vector3.new(864.057, 308.142, -2281.369)
local UNIVERSE_HUB_PLACE_ID = 11424731604
local OLD_UNIVERSE_HUB_PLACE_ID = 6360478118
getgenv().PrinceProjectAutoJoinUniverseToken = (getgenv().PrinceProjectAutoJoinUniverseToken or 0) + 1
getgenv().PrinceProjectAutoJoinCupidToken = (getgenv().PrinceProjectAutoJoinCupidToken or 0) + 1

-- Auto join remotes from the reference hub.
-- Do not rely only on PlaceId checks here: some login/universe variants can share
-- confusing IDs or load remotes at different times. The remotes themselves simply
-- work only in the correct menu/place.
local function fireJoinUniverseHubRemote()
	local events = ReplicatedStorage:FindFirstChild('Events') or ReplicatedStorage:WaitForChild('Events', 2)
	local playgame = events and (events:FindFirstChild('playgame') or events:WaitForChild('playgame', 2))
	if not playgame then return false end

	pcall(function()
		local args = { 'Arena' }
		playgame:FireServer(unpack(args))
	end)
	return true
end

local function fireJoinCupidDungeonRemote()
	-- Copied from the working reference auto join:
	-- pcall + direct WaitForChild chain + Queue:InvokeServer("Cupid's Dungeon").
	local ok = pcall(function()
		local args = { [=[Cupid's Dungeon]=] }
		game:GetService('ReplicatedStorage')
			:WaitForChild('Events')
			:WaitForChild('Queue')
			:InvokeServer(unpack(args))
	end)

	return ok == true
end

local function notify(msg)
	-- Silent mode: no prints/warns.
end

local function safeWait(parent, childName, timeout)
	if not parent then return nil end
	return parent:FindFirstChild(childName) or parent:WaitForChild(childName, timeout or 10)
end

local function getMainCfg()
	return Config and Config.MAIN or {}
end

local function getOptCfg()
	return Config and Config.SETTINGS and Config.SETTINGS.OPTIMIZATION or {}
end

local function getCurrentRootPosition()
	local char = LocalPlayer.Character
	local rp = char and char:FindFirstChild('HumanoidRootPart')

	if not rp then
		local pc = workspace:FindFirstChild('PlayerCharacters')
		char = pc and pc:FindFirstChild(LocalPlayer.Name)
		rp = char and char:FindFirstChild('HumanoidRootPart')
	end

	return rp and rp.Position or nil
end

local function isCurrentPositionInCupidDungeonBounds()
	local pos = getCurrentRootPosition()
	if not pos then return false end

	return pos.Y >= 250
		and pos.X >= -1350 and pos.X <= 950
		and pos.Z >= -5350 and pos.Z <= -2000
end

local function isUniverseHubPlace()
	return game.PlaceId == UNIVERSE_HUB_PLACE_ID or game.PlaceId == OLD_UNIVERSE_HUB_PLACE_ID
end

local function isUniverseHubSpawnPosition()
	local pos = getCurrentRootPosition()
	if not pos then return false end

	-- User confirmed Universe Hub waiting spawn is around:
	-- Vector3.new(20003.221, 5.889, -7.513)
	return pos.X >= 19000 and pos.X <= 21000
		and pos.Y >= -50 and pos.Y <= 150
		and pos.Z >= -600 and pos.Z <= 600
end

-- ULTRA EARLY CUPID LOBBY MODE
-- Important: do this BEFORE loading optimization/camera/dungeon/combat code.
-- The Cupid queue lobby and the real Cupid run share PlaceId 11424731604.
-- So we must use POSITION, not only PlaceId:
--   lobby position 20003, 6, -8  -> queue only
--   run position   864, 308, -2281 -> load full dungeon source
if isUniverseHubPlace() and not isCurrentPositionInCupidDungeonBounds() then
	getgenv().PrinceProjectStopped = false
	getgenv().PrinceProjectAutoJoinCupidDungeonValue = true

	-- Simple lobby fix: when the script is launched in PlaceId 11424731604 at
	-- the lobby/waiting position, wait 20s before doing anything else. This gives
	-- the game enough time to move the player from the lobby spawn to the real
	-- Cupid Dungeon spawn before the full source starts loading.
	task.wait(20)

	task.spawn(function()
		task.wait(2 + math.random() * 2)
		while not getgenv().PrinceProjectStopped and getgenv().PrinceProjectAutoJoinCupidDungeonValue do
			pcall(function()
				local args = { "Cupid's Dungeon" }
				game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Queue"):InvokeServer(unpack(args))
			end)
			task.wait(1.5 + math.random() * 2)
		end
	end)

	-- Do not load the heavy dungeon/combat systems while still at the lobby
	-- position around Vector3.new(20003, 6, -8). Wait until the queue moves
	-- the player to the real Cupid spawn around Vector3.new(864, 308, -2281),
	-- then fall through and load the full source normally.
	while not getgenv().PrinceProjectStopped and not isCurrentPositionInCupidDungeonBounds() do
		task.wait(0.25)
	end

	getgenv().PrinceProjectAutoJoinCupidDungeonValue = false
	if getgenv().PrinceProjectStopped then return end

	-- We started from the Universe Hub spawn and the queue moved us into the real
	-- Cupid spawn. Force the rest of this execution to load dungeon mode even if
	-- Character/HRP briefly disappears while the dungeon area is still spawning.
	getgenv().PrinceProjectForceDungeonLoad = true
end

-- Early sky/privacy camera used before the full Auto Dungeon module is loaded.
-- In Universe Hub the script may be in join-only mode, so the normal dungeon
-- camera functions below are not available yet.
function startEarlyDungeonPrivacyCamera()
	if getMainCfg().DUNGEON_PRIVACY_CAMERA == false then return end
	if getgenv().PrinceProjectEarlyPrivacyCameraConn then return end

	pcall(function()
		if getMainCfg().PRIVACY_HIDE_PLAYER_GUI ~= false then
			local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
			if playerGui then
				for _, gui in ipairs(playerGui:GetChildren()) do
					if gui:IsA('ScreenGui') and gui.Enabled ~= false then
						gui.Enabled = false
					end
				end
			end
		end
	end)

	getgenv().PrinceProjectEarlyPrivacyCameraConn = RunService.RenderStepped:Connect(function()
		if getgenv().PrinceProjectStopped then return end

		local cam = workspace.CurrentCamera
		local pos = getCurrentRootPosition()
		if not cam or not pos then return end

		local height = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_HEIGHT) or 520
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CameraSubject = nil
		cam.FieldOfView = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_FOV) or 40
		cam.CFrame = CFrame.new(pos.X, pos.Y + height, pos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
	end)
end

-- ============================================================
-- OPTIMIZATION / DISPLAY
-- ============================================================
local function applyOptimization()
	local opt = getOptCfg()

	if tonumber(opt.FPS_CAP) and tonumber(opt.FPS_CAP) > 0 and setfpscap then
		pcall(function()
			setfpscap(tonumber(opt.FPS_CAP))
		end)
	end

	if opt.DISABLE3DRENDER then
		pcall(function()
			Lighting.GlobalShadows = false
			for _, effect in ipairs(Lighting:GetChildren()) do
				if effect:IsA('BlurEffect')
					or effect:IsA('BloomEffect')
					or effect:IsA('ColorCorrectionEffect')
					or effect:IsA('SunRaysEffect')
					or effect:IsA('DepthOfFieldEffect') then
					effect.Enabled = false
				end
			end
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA('BasePart') then
					obj.Material = Enum.Material.SmoothPlastic
					obj.Reflectance = 0
					obj.CastShadow = false
				end
			end
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
	end
end

local whiteScreenGui = nil
local function setWhiteScreen(state)
	if whiteScreenGui then
		whiteScreenGui:Destroy()
		whiteScreenGui = nil
	end

	if not state then return end

	local gui = Instance.new('ScreenGui')
	gui.Name = 'PrinceProjectWhiteScreen'
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.Parent = CoreGui

	local bg = Instance.new('Frame')
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = gui

	local title = Instance.new('TextLabel')
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.fromScale(0, 0.42)
	title.BackgroundTransparency = 1
	title.Text = 'PRINCE PROJECT'
	title.TextColor3 = Color3.new(0, 0, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = bg

	local timer = Instance.new('TextLabel')
	timer.Size = UDim2.new(1, 0, 0, 36)
	timer.Position = UDim2.fromScale(0, 0.54)
	timer.BackgroundTransparency = 1
	timer.Text = '00:00'
	timer.TextColor3 = Color3.fromRGB(30, 30, 30)
	timer.Font = Enum.Font.GothamBold
	timer.TextScaled = true
	timer.Parent = bg

	local start = tick()
	RunService.Heartbeat:Connect(function()
		if not gui.Parent then return end
		local elapsed = math.floor(tick() - start)
		timer.Text = string.format('%02d:%02d', math.floor(elapsed / 60), elapsed % 60)
	end)

	whiteScreenGui = gui
end

local function applyDisplayConfig()
	local cfg = getMainCfg()
	if cfg.WHITE_SCREEN then
		setWhiteScreen(true)
	end

	-- No heavy UI exists anymore, so AUTO_HIDE_UI is intentionally a no-op.
	-- The old 13k-line Linoria UI was removed.
end

-- ============================================================
-- AUTO REJOIN / AUTO JOIN
-- ============================================================
local function startAutoRejoin()
	if getgenv().PrinceProjectAutoRejoinStarted then return end
	getgenv().PrinceProjectAutoRejoinStarted = true

	local function rejoinMainMenu()
		if getgenv().PrinceProjectStopped then return end
		task.wait(2)
		if getgenv().PrinceProjectStopped then return end
		pcall(function()
			TeleportService:Teleport(MAIN_MENU_PLACE_ID, LocalPlayer)
		end)
	end

	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player)
			if player == LocalPlayer then
				rejoinMainMenu()
			end
		end)
	end)

	pcall(function()
		local robloxGui = CoreGui:FindFirstChild('RobloxPromptGui')
		local overlay = robloxGui and robloxGui:FindFirstChild('promptOverlay')
		if overlay then
			overlay.ChildAdded:Connect(function(child)
				if child.Name == 'ErrorPrompt' then
					rejoinMainMenu()
				end
			end)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			if getgenv().PrinceProjectStopped then break end
			local ok, found = pcall(function()
				local robloxGui = CoreGui:FindFirstChild('RobloxPromptGui')
				local overlay = robloxGui and robloxGui:FindFirstChild('promptOverlay')
				local err = overlay and overlay:FindFirstChild('ErrorPrompt')
				return err ~= nil and err.Visible ~= false
			end)
			if ok and found then
				rejoinMainMenu()
			end
		end
	end)
end

local function startAutoJoinUniverseHub()
	if getgenv().PrinceProjectAutoJoinUniverseStarted
		and getgenv().PrinceProjectAutoJoinUniverseActiveToken == getgenv().PrinceProjectAutoJoinUniverseToken then
		return
	end
	getgenv().PrinceProjectAutoJoinUniverseStarted = true
	getgenv().PrinceProjectAutoJoinUniverseActiveToken = getgenv().PrinceProjectAutoJoinUniverseToken

	task.spawn(function()
		task.wait(game.PlaceId == MAIN_MENU_PLACE_ID and 0.5 or 2)
		while (getMainCfg().AUTO_JOIN_UNIVERSE_HUB or getMainCfg().AUTO_JOIN_UNIVERSE)
			and not getgenv().PrinceProjectStopped
			and getgenv().PrinceProjectAutoJoinUniverseActiveToken == getgenv().PrinceProjectAutoJoinUniverseToken do
			-- Reference behavior: spam playgame('Arena').
			-- It only works in the main menu, but removing the hard PlaceId check
			-- fixes menu variants where the old check failed.
			if isCurrentPositionInCupidDungeonBounds() then break end

			-- Main Menu only: join Universe Hub with playgame('Arena').
			-- Once the player is at the Universe Hub spawn, Cupid queue takes over.
			if game.PlaceId == MAIN_MENU_PLACE_ID and not isUniverseHubSpawnPosition() then
				fireJoinUniverseHubRemote()
			end

			task.wait(game.PlaceId == MAIN_MENU_PLACE_ID and 0.9 or 2.0)
		end
	end)
end

local function startAutoJoinCupid()
	if getgenv()._autoJoinCupidThread then
		task.cancel(getgenv()._autoJoinCupidThread)
		getgenv()._autoJoinCupidThread = nil
	end

	-- Exact working reference shape, adapted without UI Toggles:
	-- if v then
	--     getgenv()._autoJoinCupidThread = task.spawn(function()
	--         task.wait(2 + math.random() * 2)
	--         while Toggles.AutoJoinCupidDungeonToggle and Toggles.AutoJoinCupidDungeonToggle.Value do
	--             pcall(function()
	--                 local args = { "Cupid's Dungeon" }
	--                 game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Queue"):InvokeServer(unpack(args))
	--             end)
	--             task.wait(1.5 + math.random() * 2)
	--         end
	--     end)
	-- end
	getgenv().PrinceProjectAutoJoinCupidDungeonValue = true
	getgenv()._autoJoinCupidThread = task.spawn(function()
		task.wait(2 + math.random() * 2)
		while getgenv().PrinceProjectAutoJoinCupidDungeonValue do
			pcall(function()
				local args = { "Cupid's Dungeon" }
				game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("Queue"):InvokeServer(unpack(args))
			end)

			if getgenv().PrinceProjectStopped or isCurrentPositionInCupidDungeonBounds() then
				getgenv().PrinceProjectAutoJoinCupidDungeonValue = false
				break
			end

			task.wait(1.5 + math.random() * 2)
		end
	end)
end

-- ============================================================
-- MENU / UNIVERSE HUB JOIN-ONLY GATE
-- ============================================================
local function startJoinOnlyDungeonCameraWatcher()
	if getgenv().PrinceProjectJoinOnlyCameraWatcherStarted then return end
	getgenv().PrinceProjectJoinOnlyCameraWatcherStarted = true

	task.spawn(function()
		local camConn = nil
		while not getgenv().PrinceProjectStopped do
			local pos = getCurrentRootPosition()
			if pos and isCurrentPositionInCupidDungeonBounds() then
				-- Minimal privacy camera while the full dungeon source reloads.
				-- This starts as soon as the player appears at the Cupid spawn
				-- around Vector3.new(864, 308, -2281), before the route teleport.
				if not camConn then
					pcall(function()
						local cam = workspace.CurrentCamera
						if cam then
							cam.CameraType = Enum.CameraType.Scriptable
							cam.CameraSubject = nil
							cam.FieldOfView = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_FOV) or 40
						end
					end)

					camConn = RunService.RenderStepped:Connect(function()
						local liveCam = workspace.CurrentCamera
						local rpPos = getCurrentRootPosition()
						if liveCam and rpPos then
							local height = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_HEIGHT) or 520
							liveCam.CameraType = Enum.CameraType.Scriptable
							liveCam.CameraSubject = nil
							liveCam.FieldOfView = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_FOV) or 40
							liveCam.CFrame = CFrame.new(rpPos.X, rpPos.Y + height, rpPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
						end
					end)
				end
			end
			task.wait(0.1)
		end
		if camConn then camConn:Disconnect() end
	end)
end

local function shouldUseJoinOnlyMode()
	if getgenv().PrinceProjectForceDungeonLoad then
		return false
	end

	-- Important: Universe Hub and Cupid Dungeon can share the same PlaceId after
	-- Queue moves the player. Position decides first.
	-- If we are already at the real Cupid spawn/route bounds around
	-- Vector3.new(864, 308, -2281), load the full dungeon source.
	if isCurrentPositionInCupidDungeonBounds() then
		return false
	end

	-- Main Menu / Universe Hub must stay light while outside the dungeon bounds,
	-- even if Character/HRP has not replicated yet.
	if game.PlaceId == MAIN_MENU_PLACE_ID or game.PlaceId == UNIVERSE_HUB_PLACE_ID then
		return true
	end

	local cfg = getMainCfg()
	local wantsJoin = cfg.AUTO_JOIN_UNIVERSE_HUB or cfg.AUTO_JOIN_UNIVERSE or cfg.AUTO_JOIN_CUPID or cfg.AUTO_JOIN_CUPID_DUNGEON
	if not wantsJoin then return false end

	-- If the character is not loaded/positioned yet, do NOT return early.
	-- The source must stay alive after Queue("Cupid's Dungeon") teleports the
	-- player into the actual run; otherwise camera/dungeon logic only starts if
	-- the user re-executes the script manually.
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild('HumanoidRootPart') then
		local pc = workspace:FindFirstChild('PlayerCharacters')
		char = pc and pc:FindFirstChild(LocalPlayer.Name) or char
	end
	local rp = char and char:FindFirstChild('HumanoidRootPart')
	if not rp then return true end

	-- If we are not physically inside Cupid Dungeon, use join-only mode.
	return not isCurrentPositionInCupidDungeonBounds()
end

local BOOT_JOIN_ONLY_MODE = shouldUseJoinOnlyMode()
if BOOT_JOIN_ONLY_MODE then
	if getgenv().PrinceProjectForceDungeonLoad then
		BOOT_JOIN_ONLY_MODE = false
	end
end

if BOOT_JOIN_ONLY_MODE then
	-- Cupid lobby / Universe Hub: queue only while at the lobby position, then
	-- continue loading the full dungeon source once the player reaches the real
	-- dungeon spawn. Do NOT return permanently here.
	if (isUniverseHubPlace() or isUniverseHubSpawnPosition()) and not isCurrentPositionInCupidDungeonBounds() then
		getgenv().PrinceProjectStopped = false
		getgenv().PrinceProjectAutoJoinCupidDungeonValue = true
		getgenv().PrinceProjectAutoJoinCupidStarted = nil

		if getMainCfg().AUTO_JOIN_CUPID ~= false and not getgenv().PrinceProjectStopped then
			startAutoJoinCupid()
		end

		notify('Universe Hub queue-only source loaded.')

		while not getgenv().PrinceProjectStopped and not isCurrentPositionInCupidDungeonBounds() do
			task.wait(0.25)
		end

		getgenv().PrinceProjectAutoJoinCupidDungeonValue = false
		if getgenv().PrinceProjectStopped then return end

		getgenv().PrinceProjectForceDungeonLoad = true
		BOOT_JOIN_ONLY_MODE = false
	end

	applyOptimization()
	applyDisplayConfig()

	-- Reset join-loop guards in join-only mode. After teleport/re-exec some
	-- executors keep getgenv() flags, which made Universe Hub stop queueing.
	getgenv().PrinceProjectAutoJoinUniverseStarted = nil
	getgenv().PrinceProjectAutoJoinCupidStarted = nil

	-- Main Menu: only auto join Universe Hub. Do not load dungeon systems here.
	if game.PlaceId == MAIN_MENU_PLACE_ID then
		if getMainCfg().AUTO_REJOIN and not getgenv().PrinceProjectStopped then
			startAutoRejoin()
		end

		if (getMainCfg().AUTO_JOIN_UNIVERSE_HUB or getMainCfg().AUTO_JOIN_UNIVERSE) and not getgenv().PrinceProjectStopped then
			startAutoJoinUniverseHub()
		end

		notify('Main Menu join-only source loaded.')
		return
	end

	-- Fallback join-only: try both light joiners, then stop before dungeon code.
	if getMainCfg().AUTO_REJOIN and not getgenv().PrinceProjectStopped then
		startAutoRejoin()
	end
	if (getMainCfg().AUTO_JOIN_UNIVERSE_HUB or getMainCfg().AUTO_JOIN_UNIVERSE) and not getgenv().PrinceProjectStopped then
		startAutoJoinUniverseHub()
	end
	if (getMainCfg().AUTO_JOIN_CUPID or getMainCfg().AUTO_JOIN_CUPID_DUNGEON) and not getgenv().PrinceProjectStopped then
		startAutoJoinCupid()
	end

	notify('Config-only join source loaded.')
	return
end

-- ============================================================
-- AUTO DUNGEON
-- ============================================================
local AD = {}
getgenv().PrinceCupidAD = AD -- [PRINCE HUB] used by the Cupid tab status
getgenv()._AD = AD

AD.enabled = false
AD.loopID = 0
AD.status = 'idle'
AD.weapon = 'Kraken Blade'
AD.comboDelayNPC = 0.15
AD.comboDelayLeo = 0.05
AD.comboDelayCupid = 0.05
AD.fullComboWait = 1.0
AD.fullComboWaitCupid = 1.0
AD.upHeight = tonumber(getMainCfg().HOVER_HEIGHT) or 11
AD.hitRotationX = tonumber(getMainCfg().HIT_ROTATION_X) or -90
AD.hitRotationY = tonumber(getMainCfg().HIT_ROTATION_Y) or 0
AD.hitRotationZ = tonumber(getMainCfg().HIT_ROTATION_Z) or 0
AD.startDelay = tonumber(getMainCfg().START_DELAY_SECONDS) or 0
AD.pillarFlee = tonumber(getMainCfg().LEO_FLAME_PILLAR_DISTANCE) or 60
AD.leoFlamePillarDistance = tonumber(getMainCfg().LEO_FLAME_PILLAR_DISTANCE) or 65
AD.leoFlamePillarHoldTime = tonumber(getMainCfg().LEO_FLAME_PILLAR_HOLD_TIME) or 3
AD.leoFlamePillarGroundOffset = tonumber(getMainCfg().LEO_FLAME_PILLAR_GROUND_OFFSET) or 0
AD.leoFlamePillarGroundY = tonumber(getMainCfg().LEO_FLAME_PILLAR_GROUND_Y) or 506.753
AD.leoFlamePillarGroundReference = getMainCfg().LEO_FLAME_PILLAR_GROUND_REFERENCE or Vector3.new(-1094.156, 506.753, -4186.957)
AD.leoFlamePillarUseOldFlee = getMainCfg().LEO_FLAME_PILLAR_USE_OLD_FLEE ~= false
AD.leoFixedHoverHeight = getMainCfg().LEO_FIXED_HOVER_HEIGHT ~= false
AD.leoTrackCenter = getMainCfg().LEO_TRACK_CENTER ~= false
AD.leoFixedBaseY = tonumber(getMainCfg().LEO_FIXED_BASE_Y) or 506.753
AD.leoPillarFixedWaypoint = getMainCfg().LEO_PILLAR_FIXED_WAYPOINT or Vector3.new(-1079.728, 507.296, -3948.496)
AD.leoPillarFixedHoldTime = tonumber(getMainCfg().LEO_PILLAR_FIXED_HOLD_TIME) or 5
AD.blockHoldExtraSeconds = tonumber(getMainCfg().BLOCK_HOLD_EXTRA_SECONDS) or 1.4
AD.waypointMoveDelay = tonumber(getMainCfg().WAYPOINT_MOVE_DELAY) or 0

local function applyDungeonRuntimeSettings()
	AD.upHeight = tonumber(getMainCfg().HOVER_HEIGHT) or 11
	getgenv().adTweenSpeed = tonumber(getMainCfg().TWEEN_SPEED) or 110
	AD.blockHoldExtraSeconds = tonumber(getMainCfg().BLOCK_HOLD_EXTRA_SECONDS) or 1.4
	AD.waypointMoveDelay = tonumber(getMainCfg().WAYPOINT_MOVE_DELAY) or 0
end

local function applyBossRuntimeSettings()
	-- Default boss settings shown in the UI screenshot:
	-- Height 11 / Boss Speed 130 / Block 1.4 / Delay 0.00
	-- Normal waypoint tween speed stays MAIN.TWEEN_SPEED = 110.
	AD.upHeight = tonumber(getMainCfg().BOSS_HOVER_HEIGHT) or 11
	getgenv().adTweenSpeed = tonumber(getMainCfg().BOSS_TWEEN_SPEED) or 130
	AD.blockHoldExtraSeconds = tonumber(getMainCfg().BOSS_BLOCK_HOLD) or 1.4
	AD.waypointMoveDelay = tonumber(getMainCfg().BOSS_WAYPOINT_DELAY) or 0
end
AD.waypointIdx = 0
AD.kills = 0

local Events = safeWait(ReplicatedStorage, 'Events', 20)
local combatRegister = safeWait(Events, 'CombatRegister', 20)
local blockRemote = safeWait(Events, 'Block', 20)
local hotbarRemote = safeWait(Events, 'Hotbar', 20)
local fruitStorageRemote = safeWait(Events, 'FruitStorage', 20)
local toolsRemote = safeWait(Events, 'Tools', 20)
local takeStamRemote = safeWait(Events, 'takestam', 20)
local combatAnimsFolder = safeWait(safeWait(ReplicatedStorage, 'CombatAnimations', 20), 'Melee', 20)

local CombatAnims = combatAnimsFolder and {
	combatAnimsFolder:FindFirstChild('Punch1'),
	combatAnimsFolder:FindFirstChild('Punch2'),
	combatAnimsFolder:FindFirstChild('Punch3'),
	combatAnimsFolder:FindFirstChild('GroundPunch4'),
	combatAnimsFolder:FindFirstChild('GroundPunch5'),
} or {}

local KrakenAnims, KatanaAnims, CupidAxeAnims, ChakramAnims, BisentoAnims = {}, {}, {}, {}, {}
local DynamicSwordAnims = {}
local KatanaSwingSpeeds   = {1.6666666269302368,1.6666666269302368,1.6666666269302368,1.6666666269302368,2}
local CupidAxeSwingSpeeds = {1.5196077823638916,1.470588207244873,1.470588207244873,1.470588207244873,1.470588207244873}
local ChakramSwingSpeeds  = {1.2999999523162842,1.2999999523162842,1.2999999523162842,1.2999999523162842,1.2999999523162842}
local BisentoSwingSpeeds  = {2.0512821674346924,1.7948716878890991,1.846153974533081,1.5384615659713745,1.5384615659713745}

local function loadSwordAnims(swordName, dest)
	task.spawn(function()
		local ok, slashes = pcall(function()
			return ReplicatedStorage:WaitForChild('Modules', 10)
				:WaitForChild('SwordHandle', 10)
				:WaitForChild('Swords', 10)
				:WaitForChild(swordName, 10)
				:WaitForChild('Slashes', 10)
		end)
		if ok and slashes then
			for i, name in ipairs({'Slash1','Slash2','Slash3','GroundSlash4','GroundSlash5'}) do
				dest[i] = slashes:FindFirstChild(name) or slashes:WaitForChild(name, 3)
			end
		end
	end)
end

loadSwordAnims('Kraken Blade', KrakenAnims)
loadSwordAnims('Katana', KatanaAnims)
loadSwordAnims([=[Cupid's Battleaxe]=], CupidAxeAnims)
loadSwordAnims([=[Cupid's Chakram]=], ChakramAnims)
loadSwordAnims('Bisento', BisentoAnims)

local function getDynamicSwordAnims(weaponName)
	weaponName = tostring(weaponName or '')
	if weaponName == '' or weaponName == 'Melee' then return nil end
	if DynamicSwordAnims[weaponName] then return DynamicSwordAnims[weaponName] end

	local dest = {}
	DynamicSwordAnims[weaponName] = dest
	loadSwordAnims(weaponName, dest)

	if weaponName:find('Kraken Blade', 1, true) and weaponName ~= 'Kraken Blade' then
		task.delay(1, function()
			local missing = true
			for i = 1, 5 do
				if dest[i] then missing = false break end
			end
			if missing then
				loadSwordAnims('Kraken Blade', dest)
			end
		end)
	end

	return dest
end

-- Anti AFK
pcall(function()
	LocalPlayer.Idled:Connect(function()
		game:GetService('VirtualUser'):CaptureController()
		game:GetService('VirtualUser'):ClickButton2(Vector2.new())
	end)
end)

local activeTpConn = nil
local invisibleFloor = nil
local tpId = 0
local lockedPosition = nil
local lockedLookAt = nil
local antiKBEnabled = false
local canAttack = true
local weaponEquipped = false
local hakiUsed = false
local hookedBossNPC = nil
local hookedBossCleanup = nil
local cupidTrackTarget = nil
local cupidTrackActive = false
local lastDeathAt = 0
local lastProgressAt = tick()
local lastAttackAt = tick()
local lastSafeDungeonPos = nil
local dungeonRunStartedAt = 0
local lastTakeStam = 0
local waypointGui = nil
local waypointLabel = nil
local waypointSubLabel = nil
local hpBarGui = nil
local hpBarFill = nil
local hpBarText = nil
local bossPrivacyCameraActive = false
local bossPrivacyCameraTargetName = nil
local bossPrivacyCameraConn = nil
local bossPrivacyOldCameraType = nil
local bossPrivacyOldCameraSubject = nil
local bossPrivacyOldCameraCFrame = nil
local bossPrivacyOldCameraFOV = nil
local bossHudBarsHidden = false
local bossHudBarsTransparencyCache = {}
local bossHiddenGuiEnabledCache = {}
local dungeonPrivacyCameraActive = false
local leoBaseY = nil
local flameGroundLock = false
local leoPrivacyStartedForLoop = nil

-- Forward declarations needed because some runtime loops are defined before
-- these helpers in this source.
local findBossGlobal
local isPlayerInDungeonArea
local leoDodgeToken = 0
local leoDodgeActive = false
local lastLeoUltDodgeAt = 0
local lastLeoPillarDodgeAt = 0
local leoCombatTrackTarget = nil

-- Forward declaration is required because waypoint UI helper functions are
-- defined before the DUNGEON_WAYPOINTS table in this config-only source.
DUNGEON_WAYPOINTS = {}

getgenv().adTweenSpeed = tonumber(getMainCfg().TWEEN_SPEED) or 110
getgenv().adSkipHit = false
getgenv().adStatuePhaseActive = false
getgenv().adCupidPhase2Permanent = false
getgenv().adAutoStoreFruits = getMainCfg().AUTO_STORE == true
getgenv().adAutoReplay = getMainCfg().AUTO_REPLAY == true
getgenv().adAutoEquipItems = getMainCfg().AUTO_EQUIP_ITEMS == true
getgenv().adItemsToEquip = type(getMainCfg().EQUIP_ITEMS) == 'table' and getMainCfg().EQUIP_ITEMS or {}

local function getCharFolder()
	local pc = workspace:FindFirstChild('PlayerCharacters')
	return pc and pc:FindFirstChild(LocalPlayer.Name)
end

local function getCharacter()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild('HumanoidRootPart') then return char end
	return getCharFolder() or char
end

local function getRoot()
	local char = getCharacter()
	return char and char:FindFirstChild('HumanoidRootPart')
end

local function getHumanoid()
	local char = getCharacter()
	return char and char:FindFirstChildOfClass('Humanoid')
end

local function getWaypointTotal()
	return #DUNGEON_WAYPOINTS
end

local function getWaypointTypeText(wp)
	if not wp then return 'unknown' end
	if wp.type == 'patrol' then return 'patrol' end
	return 'normal'
end

local function createWaypointUI()
	-- UI disabled: waypoint display removed.
	return
    --[[
    if getMainCfg().SHOW_WAYPOINT_UI == false then return end
    if waypointGui and waypointGui.Parent then return end

    local old = CoreGui:FindFirstChild('PrinceProjectWaypointUI')
    if old then old:Destroy() end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'PrinceProjectWaypointUI'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999998
    gui.Parent = CoreGui

    local frame = Instance.new('Frame')
    frame.Name = 'Main'
    frame.Size = UDim2.fromOffset(230, 72)
    frame.Position = UDim2.new(0.5, -115, 0, 22)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(160, 105, 255)
    stroke.Transparency = 0.25
    stroke.Thickness = 1.5
    stroke.Parent = frame

    local title = Instance.new('TextLabel')
    title.Name = 'WaypointLabel'
    title.Size = UDim2.new(1, -16, 0, 34)
    title.Position = UDim2.fromOffset(8, 7)
    title.BackgroundTransparency = 1
    title.Text = 'Waypoint - / -'
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 19
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = frame

    local sub = Instance.new('TextLabel')
    sub.Name = 'SubLabel'
    sub.Size = UDim2.new(1, -16, 0, 24)
    sub.Position = UDim2.fromOffset(8, 42)
    sub.BackgroundTransparency = 1
    sub.Text = 'waiting'
    sub.TextColor3 = Color3.fromRGB(205, 195, 230)
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 13
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.Parent = frame

    waypointGui = gui
    waypointLabel = title
    waypointSubLabel = sub
    ]]
end

local function updateWaypointUI(index, total, wp, extraStatus)
	if getMainCfg().SHOW_WAYPOINT_UI == false then return end
	createWaypointUI()
	if not waypointLabel or not waypointSubLabel then return end

	index = tonumber(index) or 0
	total = tonumber(total) or getWaypointTotal()

	if index <= 0 then
		waypointLabel.Text = 'Waypoint - / ' .. tostring(total)
	else
		waypointLabel.Text = 'Waypoint ' .. tostring(index) .. ' / ' .. tostring(total)
	end

	local wpType = getWaypointTypeText(wp)
	local status = tostring(extraStatus or AD.status or 'running')
	waypointSubLabel.Text = wpType .. ' • ' .. status
end

local function hideWaypointUI()
	if waypointGui then
		waypointGui:Destroy()
		waypointGui = nil
		waypointLabel = nil
		waypointSubLabel = nil
	end
end

local function createHPBarUI()
	if getMainCfg().SHOW_HP_BAR == false then return end
	if hpBarGui and hpBarGui.Parent then return end

	local old = CoreGui:FindFirstChild('PrinceProjectHPBar')
	if old then old:Destroy() end

	local gui = Instance.new('ScreenGui')
	gui.Name = 'PrinceProjectHPBar'
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000001
	gui.Parent = CoreGui

	local frame = Instance.new('Frame')
	frame.Name = 'Main'
	frame.Size = UDim2.fromOffset(300, 42)
	frame.Position = UDim2.new(0.5, -150, 1, -74)
	frame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new('UIStroke')
	stroke.Color = Color3.fromRGB(255, 105, 145)
	stroke.Transparency = 0.18
	stroke.Thickness = 1.6
	stroke.Parent = frame

	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(0, 48, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.BackgroundTransparency = 1
	title.Text = 'HP'
	title.TextColor3 = Color3.fromRGB(255, 235, 242)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local barBack = Instance.new('Frame')
	barBack.Name = 'BarBack'
	barBack.Size = UDim2.new(1, -82, 0, 16)
	barBack.Position = UDim2.fromOffset(58, 13)
	barBack.BackgroundColor3 = Color3.fromRGB(32, 20, 28)
	barBack.BorderSizePixel = 0
	barBack.Parent = frame

	local backCorner = Instance.new('UICorner')
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = barBack

	local fill = Instance.new('Frame')
	fill.Name = 'Fill'
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 77, 118)
	fill.BorderSizePixel = 0
	fill.Parent = barBack

	local fillCorner = Instance.new('UICorner')
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local gradient = Instance.new('UIGradient')
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 105)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 175)),
	})
	gradient.Parent = fill

	local text = Instance.new('TextLabel')
	text.Name = 'HPText'
	text.Size = UDim2.new(1, -82, 0, 18)
	text.Position = UDim2.fromOffset(58, 12)
	text.BackgroundTransparency = 1
	text.Text = '0 / 0'
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 12
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.Parent = frame

	hpBarGui = gui
	hpBarFill = fill
	hpBarText = text
end

local function updateHPBarUI()
	if getMainCfg().SHOW_HP_BAR == false then return end
	createHPBarUI()
	if not hpBarFill or not hpBarText then return end

	local hum = getHumanoid()
	local hp = hum and math.max(0, hum.Health) or 0
	local maxHp = hum and math.max(1, hum.MaxHealth) or 1
	local ratio = math.clamp(hp / maxHp, 0, 1)

	hpBarFill.Size = UDim2.fromScale(ratio, 1)
	hpBarText.Text = tostring(math.floor(hp + 0.5)) .. ' / ' .. tostring(math.floor(maxHp + 0.5))
end

local function hideHPBarUI()
	if hpBarGui then
		hpBarGui:Destroy()
		hpBarGui = nil
		hpBarFill = nil
		hpBarText = nil
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		if getgenv().PrinceProjectStopped then
			hideHPBarUI()
			break
		end
		if AD and AD.enabled and isPlayerInDungeonArea() then
			updateHPBarUI()
		else
			hideHPBarUI()
		end
	end
end)

local function getBossPrivacyCameraCenter()
	local boss = bossPrivacyCameraTargetName and findBossGlobal(bossPrivacyCameraTargetName)
	local hrp = boss and boss:FindFirstChild('HumanoidRootPart')
	if hrp then return hrp.Position end

	local rp = getRoot()
	if rp then return rp.Position end

	return Vector3.new(0, 0, 0)
end

local function cacheAndSetBossHudTransparency(obj, propName, value)
	local ok, oldValue = pcall(function()
		return obj[propName]
	end)
	if not ok then return end

	table.insert(bossHudBarsTransparencyCache, {
		obj = obj,
		prop = propName,
		value = oldValue,
	})

	pcall(function()
		obj[propName] = value
	end)
end

local function makeBossHudObjectInvisible(obj)
	if not obj then return end

	if obj:IsA('GuiObject') then
		cacheAndSetBossHudTransparency(obj, 'BackgroundTransparency', 1)
	end
	if obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox') then
		cacheAndSetBossHudTransparency(obj, 'TextTransparency', 1)
		cacheAndSetBossHudTransparency(obj, 'TextStrokeTransparency', 1)
	end
	if obj:IsA('ImageLabel') or obj:IsA('ImageButton') then
		cacheAndSetBossHudTransparency(obj, 'ImageTransparency', 1)
	end
	if obj:IsA('UIStroke') then
		cacheAndSetBossHudTransparency(obj, 'Transparency', 1)
	end
end

local function hidePrivacyPlayerGui()
	if getMainCfg().PRIVACY_HIDE_PLAYER_GUI == false then return end

	pcall(function()
		local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
		if not playerGui then return end

		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA('ScreenGui') and gui.Enabled ~= false then
				table.insert(bossHiddenGuiEnabledCache, {
					obj = gui,
					value = gui.Enabled,
				})
				gui.Enabled = false
			end
		end
	end)
end

local function restorePrivacyPlayerGui()
	for i = #bossHiddenGuiEnabledCache, 1, -1 do
		local item = bossHiddenGuiEnabledCache[i]
		if item and item.obj and item.obj.Parent then
			pcall(function()
				item.obj.Enabled = item.value
			end)
		end
	end
	bossHiddenGuiEnabledCache = {}
end

local function hideBossHudBars()
	if getMainCfg().BOSS_HIDE_HUD_BARS == false then return end
	if bossHudBarsHidden then return end

	bossHudBarsHidden = true
	bossHudBarsTransparencyCache = {}
	bossHiddenGuiEnabledCache = {}

	-- Full privacy: hide every PlayerGui ScreenGui too.
	-- This removes leftover regen text such as '+9', hotbar UI, HP/stamina UI, etc.
	hidePrivacyPlayerGui()

	pcall(function()
		local targets = {}

		local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
		local playerBars = playerGui
			and playerGui:FindFirstChild('HUD')
			and playerGui.HUD:FindFirstChild('Main')
			and playerGui.HUD.Main:FindFirstChild('Bars')
		if playerBars then table.insert(targets, playerBars) end

		local templateBars = ReplicatedStorage:FindFirstChild('GUIS')
			and ReplicatedStorage.GUIS:FindFirstChild('HUD')
			and ReplicatedStorage.GUIS.HUD:FindFirstChild('Main')
			and ReplicatedStorage.GUIS.HUD.Main:FindFirstChild('Bars')
		if templateBars then table.insert(targets, templateBars) end

		for _, root in ipairs(targets) do
			makeBossHudObjectInvisible(root)
			for _, obj in ipairs(root:GetDescendants()) do
				makeBossHudObjectInvisible(obj)
			end
		end
	end)
end

local function restoreBossHudBars()
	restorePrivacyPlayerGui()
	if not bossHudBarsHidden then return end

	for i = #bossHudBarsTransparencyCache, 1, -1 do
		local item = bossHudBarsTransparencyCache[i]
		if item and item.obj and item.obj.Parent then
			pcall(function()
				item.obj[item.prop] = item.value
			end)
		end
	end

	bossHudBarsTransparencyCache = {}
	bossHudBarsHidden = false
end

local function startBossPrivacyCamera(targetName)
	hideBossHudBars()
	if getMainCfg().BOSS_PRIVACY_CAMERA == false then return end
	bossPrivacyCameraTargetName = targetName or bossPrivacyCameraTargetName

	pcall(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		if not bossPrivacyCameraActive then
			bossPrivacyOldCameraType = cam.CameraType
			bossPrivacyOldCameraSubject = cam.CameraSubject
			bossPrivacyOldCameraCFrame = cam.CFrame
			bossPrivacyOldCameraFOV = cam.FieldOfView
		end

		bossPrivacyCameraActive = true
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CameraSubject = nil
		cam.FieldOfView = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_FOV) or 40

		if bossPrivacyCameraConn then
			bossPrivacyCameraConn:Disconnect()
			bossPrivacyCameraConn = nil
		end

		bossPrivacyCameraConn = RunService.RenderStepped:Connect(function()
			if not bossPrivacyCameraActive then return end
			local liveCam = workspace.CurrentCamera
			if not liveCam then return end

			local center = getBossPrivacyCameraCenter()
			local height = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_HEIGHT) or 520
			local privacyCFrame = CFrame.new(center.X, center.Y + height, center.Z) * CFrame.Angles(math.rad(-90), 0, 0)

			liveCam.CameraType = Enum.CameraType.Scriptable
			liveCam.CameraSubject = nil
			liveCam.FieldOfView = tonumber(getMainCfg().BOSS_PRIVACY_CAMERA_FOV) or 40
			liveCam.CFrame = privacyCFrame
		end)
	end)
end

local function stopBossPrivacyCamera(force)
	-- If dungeon-wide privacy is enabled, boss phases must not restore the camera.
	-- Only AD.stopDungeon / full script stop should force restore.
	if dungeonPrivacyCameraActive and not force then
		bossPrivacyCameraTargetName = nil
		return
	end

	restoreBossHudBars()
	leoPrivacyStartedForLoop = nil
	if not bossPrivacyCameraActive and not bossPrivacyCameraConn then return end

	pcall(function()
		if bossPrivacyCameraConn then
			bossPrivacyCameraConn:Disconnect()
			bossPrivacyCameraConn = nil
		end

		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = bossPrivacyOldCameraType or Enum.CameraType.Custom
			cam.CameraSubject = bossPrivacyOldCameraSubject or getHumanoid()
			if bossPrivacyOldCameraCFrame then
				cam.CFrame = bossPrivacyOldCameraCFrame
			end
			if bossPrivacyOldCameraFOV then
				cam.FieldOfView = bossPrivacyOldCameraFOV
			end
		end
	end)

	bossPrivacyCameraActive = false
	bossPrivacyCameraTargetName = nil
	bossPrivacyOldCameraType = nil
	bossPrivacyOldCameraSubject = nil
	bossPrivacyOldCameraCFrame = nil
	bossPrivacyOldCameraFOV = nil
	dungeonPrivacyCameraActive = false
end

local function makeCombatCFrame(pos, lookAtPos)
	local cf
	if typeof(lookAtPos) == 'Vector3' then
		local flatTarget = Vector3.new(lookAtPos.X, pos.Y, lookAtPos.Z)
		if (flatTarget - pos).Magnitude > 0.05 then
			cf = CFrame.lookAt(pos, flatTarget)
		end
	end

	cf = cf or CFrame.new(pos)
	return cf * CFrame.Angles(
		math.rad(tonumber(AD.hitRotationX) or -90),
		math.rad(tonumber(AD.hitRotationY) or 0),
		math.rad(tonumber(AD.hitRotationZ) or 0)
	)
end

local function getGroundYAt(pos, fallbackY)
	if typeof(pos) ~= 'Vector3' then return fallbackY end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local char = getCharacter()
	if char then table.insert(ignore, char) end
	local npcs = workspace:FindFirstChild('NPCs')
	local enemies = workspace:FindFirstChild('Enemies')
	if npcs then table.insert(ignore, npcs) end
	if enemies then table.insert(ignore, enemies) end
	params.FilterDescendantsInstances = ignore

	local origin = Vector3.new(pos.X, pos.Y + 40, pos.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -180, 0), params)
	if result then
		return result.Position.Y
	end

	return fallbackY
end

local function getBossBaseY(npc)
	local hrp = npc and npc:FindFirstChild('HumanoidRootPart')
	return hrp and hrp.Position.Y or nil
end

local function markProgress(reason)
	lastProgressAt = tick()
	AD.status = reason or AD.status
end

local function getRespawnGrace()
	return tonumber(getMainCfg().RESPAWN_GRACE_SECONDS) or 12
end

local function isAliveStable()
	local hum = getHumanoid()
	local rp = getRoot()
	return hum and rp and hum.Health > 0 and (tick() - lastDeathAt) >= getRespawnGrace()
end

local function isInCupidDungeonArea(pos)
	if typeof(pos) ~= 'Vector3' then return false end

	-- Cupid Dungeon route + Leo + Cupid boss arena bounds.
	-- This avoids trying to noclip from the lobby/spawn/leaderboard area after death.
	return pos.Y >= 250
		and pos.X >= -1350 and pos.X <= 950
		and pos.Z >= -5350 and pos.Z <= -2000
end

isPlayerInDungeonArea = function()
	local rp = getRoot()
	return rp and isInCupidDungeonArea(rp.Position) or false
end

local function waitUntilDungeonArea(timeout)
	timeout = timeout or tonumber(getMainCfg().DUNGEON_ENTRY_TIMEOUT) or 120
	local started = tick()

	while AD.enabled and tick() - started < timeout do
		local rp = getRoot()
		local hum = getHumanoid()
		if hum and hum.Health <= 0 then
			lastDeathAt = tick()
		end

		if isAliveStable() and rp and isInCupidDungeonArea(rp.Position) then
			lastSafeDungeonPos = rp.Position
			return true
		end

		AD.status = 'waiting dungeon area'
		task.wait(0.5)
	end

	return false
end

local function resetMovementState()
	tpId = tpId + 1
	lockedPosition = nil
	lockedLookAt = nil
	leoCombatTrackTarget = nil
	antiKBEnabled = false
	cupidTrackTarget = nil
	cupidTrackActive = false
	leoCombatTrackTarget = nil
	leoDodgeActive = false
	canAttack = true
	getgenv().adSkipHit = false
	if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
	if invisibleFloor then invisibleFloor:Destroy(); invisibleFloor = nil end
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
end

local function takeDashStamina()
	if not takeStamRemote then return end
	local rp = getRoot()
	if not rp then return end

	local now = tick()
	if now - lastTakeStam < 0.35 then return end
	lastTakeStam = now

	pcall(function()
		takeStamRemote:FireServer(1, 'dash', rp.CFrame)
	end)
end

local function setNoclip(state)
	if getgenv().PrinceProjectNoclipConn then
		getgenv().PrinceProjectNoclipConn:Disconnect()
		getgenv().PrinceProjectNoclipConn = nil
	end
	if not state then return end
	getgenv().PrinceProjectNoclipConn = RunService.Stepped:Connect(function()
		-- Noclip is allowed only while we are really inside Cupid Dungeon.
		-- This prevents the death/spawn bug where the bot tries to go through lobby walls.
		if not isPlayerInDungeonArea() then return end

		takeDashStamina()

		local char = getCharacter()
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA('BasePart') then
				part.CanCollide = false
			end
		end
	end)
end

local function hookCharacter(char)
	lastDeathAt = tick()
	resetMovementState()
	weaponEquipped = false
	hakiUsed = false

	task.spawn(function()
		local hum = char and (char:FindFirstChildOfClass('Humanoid') or char:WaitForChild('Humanoid', 8))
		if hum then
			hum.Died:Connect(function()
				lastDeathAt = tick()
				resetMovementState()
				setNoclip(false)
			end)
		end
	end)
end

if LocalPlayer.Character then
	hookCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

RunService.Heartbeat:Connect(function()
	local rp = getRoot()
	local hum = getHumanoid()
	if not rp or not hum then return end
	if hum.PlatformStand then hum.PlatformStand = false end

	-- Leo live tracking during combo:
	-- attackNPC() can spend about 1 second sending the 5 hits, so the normal
	-- killAllNPCsAtPos() loop cannot refresh Leo's X/Z during that time.
	-- This keeps the player centered on Leo every frame while Y stays fixed.
	if leoCombatTrackTarget and AD.enabled and not leoDodgeActive and not getgenv().adSkipHit then
		local leoHrp = leoCombatTrackTarget:FindFirstChild('HumanoidRootPart')
		local leoHum = leoCombatTrackTarget:FindFirstChildOfClass('Humanoid')
		if leoHrp and leoHum and leoHum.Health > 0 then
			local baseY = tonumber(getMainCfg().LEO_FIXED_BASE_Y) or AD.leoFixedBaseY or leoHrp.Position.Y
			local height = tonumber(getMainCfg().LEO_HOVER_HEIGHT) or 11
			lockedPosition = Vector3.new(leoHrp.Position.X, baseY + height, leoHrp.Position.Z)
			lockedLookAt = nil
		else
			leoCombatTrackTarget = nil
		end
	end

	if lockedPosition then
		local dist = (rp.Position - lockedPosition).Magnitude
		local newPos = lockedPosition
		if dist > 0.5 then
			local dir = (lockedPosition - rp.Position).Unit
			local step = math.min((getgenv().adTweenSpeed or 110) * 0.016, dist)
			newPos = rp.Position + dir * step
		end

		if flameGroundLock then
			-- Flame Pillar dodge must stay grounded: no hover rotation CFrame here.
			rp.CFrame = CFrame.new(newPos)
		else
			rp.CFrame = makeCombatCFrame(newPos, lockedLookAt)
		end

		rp.AssemblyLinearVelocity = Vector3.zero
		rp.AssemblyAngularVelocity = Vector3.zero
		hum.AutoRotate = false
		return
	elseif hum.AutoRotate == false then
		hum.AutoRotate = true
	end

	if antiKBEnabled then
		rp.AssemblyLinearVelocity = Vector3.zero
		rp.AssemblyAngularVelocity = Vector3.zero
	end
end)

local function DoSafeTeleport(targetPos, keepNoclip)
	if typeof(targetPos) == 'CFrame' then targetPos = targetPos.Position end
	if typeof(targetPos) ~= 'Vector3' then return false end

	local rp = getRoot()
	local hum = getHumanoid()
	if not rp or not hum or hum.Health <= 0 then return false end

	if not isAliveStable() then
		resetMovementState()
		return false
	end

	if not isInCupidDungeonArea(rp.Position) then
		resetMovementState()
		AD.status = 'blocked: not in dungeon'
		return false
	end

	if not isInCupidDungeonArea(targetPos) then
		AD.status = 'blocked: target outside dungeon'
		return false
	end

	lastSafeDungeonPos = rp.Position
	setNoclip(true)

	local dist = (rp.Position - targetPos).Magnitude

	-- Always use tween movement, even for short NPC-to-NPC transitions.
	-- No instant CFrame jump at the beginning.
	if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
	if invisibleFloor then invisibleFloor:Destroy(); invisibleFloor = nil end

	tpId = tpId + 1
	local currentTpId = tpId
	local reached = false

	local floor = Instance.new('Part')
	floor.Name = 'PrinceProjectInvisibleFloor'
	floor.Size = Vector3.new(10, 1, 10)
	floor.Transparency = 1
	floor.Anchored = true
	floor.CanCollide = true
	floor.Parent = workspace
	invisibleFloor = floor

	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)

	activeTpConn = RunService.Heartbeat:Connect(function(dt)
		takeDashStamina()
		rp = getRoot()
		hum = getHumanoid()
		if not rp or not hum or hum.Health <= 0 or tpId ~= currentTpId then
			reached = true
			if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
			return
		end

		local currentDist = (rp.Position - targetPos).Magnitude
		if currentDist <= 1.5 then
			-- No final instant snap. Stop the tween when close enough.
			-- This keeps statue-to-statue and waypoint movement fully tween-based.
			rp.AssemblyLinearVelocity = Vector3.zero
			lastSafeDungeonPos = rp.Position
			markProgress('teleport reached')
			reached = true
			if invisibleFloor then invisibleFloor:Destroy(); invisibleFloor = nil end
			if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
			return
		end

		local dir = (targetPos - rp.Position).Unit
		local moveStep = math.min((getgenv().adTweenSpeed or 110) * dt, currentDist * 0.98)
		rp.CFrame = CFrame.new(rp.Position + dir * moveStep)
		rp.AssemblyLinearVelocity = Vector3.zero
		if invisibleFloor and invisibleFloor.Parent then
			invisibleFloor.CFrame = rp.CFrame * CFrame.new(0, -3.1, 0)
		end
	end)

	while not reached and tpId == currentTpId do
		task.wait(0.1)
	end

	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
	if not keepNoclip then
		setNoclip(false)
	end
	return reached == true
end

local function applyWeaponFromConfig()
	local weapons = getMainCfg().WEAPONS
	if type(weapons) == 'table' then
		local selected = weapons[LocalPlayer.Name]
		if type(selected) == 'string' and selected ~= '' then
			AD.weapon = selected
		end
	end
end

local function getWeaponKeyword(weaponName)
	weaponName = tostring(weaponName or '')
	return string.lower(weaponName):gsub('%b()', ''):gsub('%s+$', ''):gsub('^%s+', '')
end

local function weaponMatchesName(toolName, weaponName)
	toolName = string.lower(tostring(toolName or ''))
	weaponName = tostring(weaponName or '')
	local keyword = getWeaponKeyword(weaponName)
	local exact = string.lower(weaponName)

	return toolName == exact
		or toolName:find(keyword, 1, true) ~= nil
		or keyword:find(toolName, 1, true) ~= nil
end

local function findConfiguredWeaponTool()
	local weaponName = AD.weapon or 'Melee'
	local char = getCharacter()
	local bp = LocalPlayer:FindFirstChild('Backpack')

	local function scan(container)
		if not container then return nil end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA('Tool') and weaponMatchesName(tool.Name, weaponName) then
				return tool
			end
		end
		return nil
	end

	return scan(char), scan(bp)
end

local function findHotbarWeaponSlot(weaponName)
	local slotKeys = {
		Zero = Enum.KeyCode.Zero,
		One = Enum.KeyCode.One,
		Two = Enum.KeyCode.Two,
		Three = Enum.KeyCode.Three,
		Four = Enum.KeyCode.Four,
		Five = Enum.KeyCode.Five,
		Six = Enum.KeyCode.Six,
		Seven = Enum.KeyCode.Seven,
		Eight = Enum.KeyCode.Eight,
		Nine = Enum.KeyCode.Nine,
	}
	local preferredOrder = {'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}

	local pg = LocalPlayer:FindFirstChild('PlayerGui')
	local backpackGui = pg and pg:FindFirstChild('BackpackGui')
	local backpackFrame = backpackGui and backpackGui:FindFirstChild('Backpack')
	local inventoryFrame = backpackFrame and backpackFrame:FindFirstChild('Inventory')
	local hotbar = backpackGui and backpackGui:FindFirstChild('Hotbar')
	local weaponBar = inventoryFrame and (
		inventoryFrame:FindFirstChild('WeaponsInventory')
			or inventoryFrame:FindFirstChild('Weapons')
	)
	if not hotbar and not weaponBar then return nil, nil, nil end

	local function scanSlot(slot)
		if not slot then return nil, nil, nil end
		for _, item in ipairs(slot:GetChildren()) do
			if weaponMatchesName(item.Name, weaponName) then
				return slot.Name, slotKeys[slot.Name], item
			end

			for _, desc in ipairs(item:GetDescendants()) do
				if weaponMatchesName(desc.Name, weaponName) then
					return slot.Name, slotKeys[slot.Name], desc
				end
			end
		end
		return nil, nil, nil
	end

	local function scanContainer(container)
		if not container then return nil, nil, nil end

		-- First scan the real key slots, e.g. Hotbar.One['Kraken Blade (Red)'].
		for _, slotName in ipairs(preferredOrder) do
			local a, b, c = scanSlot(container:FindFirstChild(slotName))
			if a then return a, b, c end
		end

		-- Fallback: some hotbars create extra slot objects; scan all children too.
		for _, slot in ipairs(container:GetChildren()) do
			local a, b, c = scanSlot(slot)
			if a then return a, b, c end
		end

		return nil, nil, nil
	end

	local a, b, c = scanContainer(hotbar)
	if a then return a, b, c end

	a, b, c = scanContainer(weaponBar)
	if a then return a, b, c end

	-- Extra fallback for layouts that nest the inventory deeper than expected.
	if backpackFrame then
		a, b, c = scanContainer(backpackFrame)
		if a then return a, b, c end
	end

	return nil, nil, nil
end

local function pressKey(keyCode, holdTime)
	if not keyCode then return end
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		task.wait(holdTime or 0.06)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
	end)
end

local function forceHotbarWeapon(realName)
	if not hotbarRemote then return end
	pcall(function()
		hotbarRemote:FireServer({
			Zero='None', One=realName, Two='None', Three='None', Four='None',
			Five='None', Six='None', Seven='None', Eight='None', Nine='None'
		})
	end)
end

local function ensureBusoOnce()
	if hakiUsed then return end
	hakiUsed = true

	-- Buso Haki: press J once, 3 seconds after the weapon is confirmed equipped.
	task.spawn(function()
		task.wait(3)
		if getgenv().PrinceProjectStopped then return end

		pressKey(Enum.KeyCode.J, 0.08)
	end)
end
-- [PRINCE HUB v18] forward declaration: equipWeapon uses it, but it is defined further down.
-- Before this, Step 2 (equip from inventory) never ran because the name was nil here.
local hasInventoryItemForEquip

local function equipWeapon()
	applyWeaponFromConfig()

	local weaponName = AD.weapon or 'Melee'
	local char = getCharacter()
	local hum = getHumanoid()
	local backpack = LocalPlayer:FindFirstChild('Backpack')

	if weaponName == 'Melee' then
		local melee = char and char:FindFirstChild('Melee') or backpack and backpack:FindFirstChild('Melee')
		if melee and hum and melee.Parent ~= char then
			pcall(function() hum:EquipTool(melee) end)
		end
		weaponEquipped = true
		return true
	end

	local function isEquippedNow()
		local currentChar = getCharacter()
		if not currentChar then return false end
		for _, tool in ipairs(currentChar:GetChildren()) do
			if tool:IsA('Tool') and weaponMatchesName(tool.Name, weaponName) then
				weaponEquipped = true
				return true
			end
		end
		return false
	end

	if isEquippedNow() then
		ensureBusoOnce()
		return true
	end

	local function clickWeaponIfAvailable()
		local slotName, hotbarKey = findHotbarWeaponSlot(weaponName)
		if not slotName then return false end

		if hotbarKey then
			pressKey(hotbarKey, 0.08)
			task.wait(0.22)
			return true
		end

		-- WeaponBar path: the item is in BackpackGui.Backpack.Inventory.WeaponsInventory.
		-- Equip it the same way, then wait a little longer for the game to finish moving it in-hand.
		if toolsRemote then
			pcall(function()
				local args = { 'equip', weaponName }
				toolsRemote:InvokeServer(unpack(args))
			end)
		end

		task.wait(0.45)
		return true
	end

	-- Step 1: if the selected weapon already exists in Hotbar / WeaponBar, select it once.
	if clickWeaponIfAvailable() then
		if isEquippedNow() then
			ensureBusoOnce()
			return true
		end
	end

	-- Step 2: if not in Hotbar / not equipped, ask the game to equip the configured sword.
	if hasInventoryItemForEquip and hasInventoryItemForEquip(weaponName) then
		pcall(function()
			if toolsRemote then
				local args = { 'equip', weaponName }
				toolsRemote:InvokeServer(unpack(args))
			end
		end)
	end
	task.wait(0.35)

	-- Step 3: recheck Hotbar and click the slot.
	for attempt = 1, 12 do
		if isEquippedNow() then
			ensureBusoOnce()
			return true
		end

		if clickWeaponIfAvailable() and isEquippedNow() then
			ensureBusoOnce()
			return true
		end

		local charTool, backpackTool = findConfiguredWeaponTool()
		if charTool then
			weaponEquipped = true
			ensureBusoOnce()
			return true
		end

		if backpackTool and hum then
			pcall(function() hum:EquipTool(backpackTool) end)
			task.wait(0.15)
			if isEquippedNow() then
				ensureBusoOnce()
				return true
			end
		end

		-- Last helper: force selected sword into slot One, then press One.
		if attempt == 5 then
			forceHotbarWeapon(weaponName)
			task.wait(0.2)
			pressKey(Enum.KeyCode.One, 0.08)
		end

		task.wait(0.18)
	end

	weaponEquipped = false
	AD.status = 'weapon not equipped'
	return false
end

local function getNPCID(npc)
	if not npc then return nil end
	local v = npc:FindFirstChild('NPCID')
	if v then return v.Value end
	local cfg = npc:FindFirstChild('Configuration')
	local cv = cfg and cfg:FindFirstChild('NPCID')
	if cv then return cv.Value end
	return npc:GetAttribute('NPCID')
end

local function getAllNearbyNPCs(pos, radius)
	local res = {}
	radius = radius or 80

	local function scan(folderName)
		local folder = workspace:FindFirstChild(folderName)
		if not folder then return end
		for _, npc in ipairs(folder:GetChildren()) do
			if npc:IsA('Model') then
				local hum = npc:FindFirstChild('Humanoid')
				local hrp = npc:FindFirstChild('HumanoidRootPart')
				if hum and hum.Health > 0 and hrp then
					local dx = pos.X - hrp.Position.X
					local dz = pos.Z - hrp.Position.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist <= radius then
						table.insert(res, {npc = npc, hrp = hrp, dist = dist})
					end
				end
			end
		end
	end

	scan('NPCs')
	scan('Enemies')
	table.sort(res, function(a, b) return a.dist < b.dist end)
	return res
end

function findBossGlobal(bossName)
	local wanted = string.lower(bossName)
	local function scan(folderName)
		local folder = workspace:FindFirstChild(folderName)
		if not folder then return nil end
		for _, npc in ipairs(folder:GetChildren()) do
			if npc:IsA('Model') and string.lower(npc.Name) == wanted then
				local hum = npc:FindFirstChild('Humanoid')
				local hrp = npc:FindFirstChild('HumanoidRootPart')
				if hum and hum.Health > 0 and hrp then
					return npc
				end
			end
		end
	end
	return scan('NPCs') or scan('Enemies')
end

local function getWeaponInfo()
	local weapon = AD.weapon or 'Melee'
	local isKraken = tostring(weapon):find('Kraken Blade', 1, true) ~= nil
	local isKatana = weapon == 'Katana'
	local isCupidAxe = weapon == [=[Cupid's Battleaxe]=]
	local isChakram = weapon == [=[Cupid's Chakram]=]
	local isBisento = weapon == 'Bisento'

	-- Every configured weapon except Melee is treated as Sword. For swords that
	-- were not hardcoded before, try to load their exact Slashes module dynamically
	-- and fall back to CombatAnims if the module is missing/not streamed yet.
	local weaponType = (weapon ~= 'Melee') and 'Sword' or 'Melee'
	local anims = CombatAnims
	local speeds = nil
	local defaultSpeed = 1.75

	if isBisento then anims = BisentoAnims; speeds = BisentoSwingSpeeds
	elseif isChakram then anims = ChakramAnims; speeds = ChakramSwingSpeeds
	elseif isCupidAxe then anims = CupidAxeAnims; speeds = CupidAxeSwingSpeeds
	elseif isKatana then anims = KatanaAnims; speeds = KatanaSwingSpeeds
	elseif isKraken then anims = KrakenAnims; defaultSpeed = 1.4583332538604736
	elseif weapon ~= 'Melee' then anims = getDynamicSwordAnims(weapon) or CombatAnims end

	return weaponType, anims, speeds, defaultSpeed
end

local function attackNPC(npc)
	if not npc or not combatRegister then return end
	local hum = npc:FindFirstChild('Humanoid')
	local hrp = npc:FindFirstChild('HumanoidRootPart')
	if not hum or hum.Health <= 0 or not hrp then return end
	if not canAttack then return end

	canAttack = false
	antiKBEnabled = true
	if not equipWeapon() then
		canAttack = true
		antiKBEnabled = false
		return
	end

	local lowerName = string.lower(npc.Name)
	local isCupid = lowerName == 'cupid queen'
	local isLeo = lowerName == 'leo'
	local delay = isCupid and AD.comboDelayCupid or (isLeo and AD.comboDelayLeo or AD.comboDelayNPC)
	local weaponType, anims, speeds, defaultSpeed = getWeaponInfo()

	for combo = 1, 5 do
		if not AD.enabled then break end
		if getgenv().adSkipHit and lowerName ~= 'cupid queen' then break end
		if getgenv().adStatuePhaseActive then break end

		hum = npc:FindFirstChild('Humanoid')
		hrp = npc:FindFirstChild('HumanoidRootPart')
		local rp = getRoot()
		if not hum or hum.Health <= 0 or not hrp or not rp then break end

		local hrpList = {}
		local npcIDs = {}
		for _, data in ipairs(getAllNearbyNPCs(rp.Position, 120)) do
			table.insert(hrpList, data.hrp)
			local id = getNPCID(data.npc)
			if id then table.insert(npcIDs, id) end
		end
		if #hrpList == 0 then
			table.insert(hrpList, hrp)
			local id = getNPCID(npc)
			if id then table.insert(npcIDs, id) end
		end

		rp.AssemblyLinearVelocity = Vector3.zero
		rp.AssemblyAngularVelocity = Vector3.zero

		local anim = anims[combo] or CombatAnims[combo]
		local speed = speeds and speeds[combo] or defaultSpeed

		pcall(function()
			combatRegister:InvokeServer({[1]='swingsfx',[2]=weaponType,[3]=combo,[4]='Ground',[5]=false,[6]=anim,[7]=speed,[8]=1.5})
			local damageArgs = {[1]={[1]='damage',[2]=hrpList,[3]=weaponType,[4]={combo,'Ground',weaponType},[5]=true,[6]=rp.CFrame,aircombo='Ground'}}
			if #npcIDs > 0 then damageArgs[1].NPCIDs = npcIDs end
			combatRegister:InvokeServer(unpack(damageArgs))
		end)

		lastAttackAt = tick()
		markProgress('attacking ' .. tostring(npc.Name))
		task.wait(delay)
	end

	local waitTime = isCupid and AD.fullComboWaitCupid or (isLeo and 1.0 or AD.fullComboWait)
	task.wait(waitTime)
	antiKBEnabled = false
	canAttack = true
end

local LEO_ANIMS = {
	-- Current custom Leo system:
	-- Flame Pillar = forced ground tween away from Leo, wait 3s, then resume.
	-- Ult = forced tween to the fixed safe waypoint, wait 5s, then resume.
	-- Firefly/Hiken = short block timing.
	['rbxassetid://5244141327'] = { action = 'Pillar',      name = 'FlamePillar' },
	['5244141327']              = { action = 'Pillar',      name = 'FlamePillar' },
	['rbxassetid://5244138278'] = { action = 'PillarFixed', name = 'Ult' },
	['5244138278']              = { action = 'PillarFixed', name = 'Ult' },
	['rbxassetid://5220236154'] = { action = 'Block',       name = 'Firefly' },
	['5220236154']              = { action = 'Block',       name = 'Firefly' },
	['rbxassetid://5220917407'] = { action = 'Block',       name = 'Hiken' },
	['5220917407']              = { action = 'Block',       name = 'Hiken' },
}

local CUPID_ANIMS = {
	['rbxassetid://8756559629']      = 'Block',
	['rbxassetid://82430354923671']  = 'Block',
	['rbxassetid://129337113115675'] = 'Block',
	['rbxassetid://101880240326459'] = 'Block',
	['rbxassetid://101734841287531'] = 'Block',
	['rbxassetid://76758555772040']  = 'Block',
	['rbxassetid://3027864591']      = 'Block',
	['rbxassetid://3027717390']      = 'Block',
	['rbxassetid://72351954958849']  = 'Block',
	['rbxassetid://71247709504586']  = 'Block',
	['rbxassetid://10001705684']     = 'Block',
	['rbxassetid://9611810596']      = 'Block',
	['rbxassetid://76590479630089']  = 'Block',
	['rbxassetid://129473336385530'] = 'Block',
	['rbxassetid://16929753098']     = 'StatuePhase',
}

local blockKeyHeld = false
local lastCupidBlockAnimAt = {}
local function setCombatBlock(state)
	local weaponType = (AD.weapon == 'Melee') and 'Melee' or 'Sword'

	pcall(function()
		VirtualInputManager:SendKeyEvent(state == true, Enum.KeyCode.F, false, game)
	end)
	blockKeyHeld = state == true

	pcall(function()
		blockRemote:InvokeServer(state == true, weaponType, state == true)
	end)

	if weaponType ~= 'Melee' then
		pcall(function()
			blockRemote:InvokeServer(state == true, 'Melee', state == true)
		end)
	end
end

local function stopBlock()
	if blockKeyHeld then
		pcall(function()
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
		end)
		blockKeyHeld = false
	end

	setCombatBlock(false)
end

local function forceLeoTweenTo(pos, speed, timeout)
	if typeof(pos) == 'CFrame' then pos = pos.Position end
	if typeof(pos) ~= 'Vector3' then return false end

	-- Hard stop every normal movement/combat controller first.
	-- This prevents the boss hover lock / active tween / gravity correction from
	-- pulling the character back while Leo Ult or Flame Pillar dodge is running.
	tpId = tpId + 1
	if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
	if invisibleFloor then invisibleFloor:Destroy(); invisibleFloor = nil end
	lockedPosition = nil
	lockedLookAt = nil
	antiKBEnabled = true
	canAttack = false
	flameGroundLock = true

	speed = tonumber(speed) or 130
	timeout = tonumber(timeout) or 10
	local started = tick()
	setNoclip(true)

	-- Dedicated Leo dodge support floor. This avoids the rare case where Roblox
	-- gravity/physics lowers the character between two CFrame steps and ruins the
	-- path before the safe waypoint is reached.
	local supportFloor = Instance.new('Part')
	supportFloor.Name = 'PrinceProjectLeoDodgeFloor'
	supportFloor.Size = Vector3.new(16, 1, 16)
	supportFloor.Transparency = 1
	supportFloor.Anchored = true
	supportFloor.CanCollide = true
	supportFloor.Parent = workspace

	local reached = false
	local ok = pcall(function()
		while AD.enabled and tick() - started < timeout do
			local rp = getRoot()
			local hum = getHumanoid()
			if not rp or not hum or hum.Health <= 0 then break end

			local delta = pos - rp.Position
			local dist = delta.Magnitude
			if dist <= 2 then
				rp.CFrame = CFrame.new(pos)
				rp.AssemblyLinearVelocity = Vector3.zero
				rp.AssemblyAngularVelocity = Vector3.zero
				reached = true
				break
			end

			local dt = RunService.Heartbeat:Wait()
			local step = math.min(speed * dt, dist)
			local newPos = rp.Position + delta.Unit * step

			-- Force exact tween position every frame and cancel physics immediately.
			rp.CFrame = CFrame.new(newPos)
			rp.AssemblyLinearVelocity = Vector3.zero
			rp.AssemblyAngularVelocity = Vector3.zero
			hum.PlatformStand = false
			hum.Sit = false
			hum.AutoRotate = false

			if supportFloor and supportFloor.Parent then
				supportFloor.CFrame = CFrame.new(newPos.X, newPos.Y - 3.2, newPos.Z)
			end
		end
	end)

	if supportFloor then
		supportFloor:Destroy()
	end

	local rp = getRoot()
	if not reached and rp and (rp.Position - pos).Magnitude <= 5 then
		reached = true
	end

	return ok and reached
end

local function doLeoPillarFixedDodge()
	-- Leo ult/PillarFixed: force tween to the fixed waypoint, then wait 5s.
	local now = tick()
	if now - lastLeoUltDodgeAt < 1.25 then return end
	lastLeoUltDodgeAt = now

	getgenv().adSkipHit = true
	leoDodgeActive = true

	task.spawn(function()
		local specialPos = AD.leoPillarFixedWaypoint or Vector3.new(-1079.728, 507.296, -3948.496)
		lockedPosition = nil
		lockedLookAt = nil
		flameGroundLock = true
		setNoclip(true)

		-- Use a forced tween instead of the normal route tween so gravity/combat hover
		-- cannot pull the player backward before reaching the safe point.
		forceLeoTweenTo(specialPos, tonumber(getMainCfg().BOSS_TWEEN_SPEED) or 130, 12)

		local rp = getRoot()
		if rp and (rp.Position - specialPos).Magnitude > 5 then
			forceLeoTweenTo(specialPos, tonumber(getMainCfg().BOSS_TWEEN_SPEED) or 130, 8)
		end

		lockedPosition = specialPos
		lockedLookAt = nil
		flameGroundLock = true

		task.wait(tonumber(AD.leoPillarFixedHoldTime) or 5)

		getgenv().adSkipHit = false
		leoDodgeActive = false
		flameGroundLock = false
		lockedPosition = nil
		lockedLookAt = nil
		antiKBEnabled = false
		canAttack = true
	end)
end

local function startBossHook(bossModel, reactionTable)
	local conns = {}
	local function add(conn)
		table.insert(conns, conn)
	end
	local function cleanup()
		if tostring(bossModel.Name):lower() == 'leo' then
			leoCombatTrackTarget = nil
		end
		for _, conn in ipairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
		conns = {}
		stopBlock()
		getgenv().adSkipHit = false
		leoDodgeActive = false
		flameGroundLock = false
		lockedPosition = nil
		lockedLookAt = nil
		antiKBEnabled = false
		canAttack = true
	end

	local humanoid = bossModel:FindFirstChildOfClass('Humanoid')
	local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
	if not animator then return cleanup end

	add(animator.AnimationPlayed:Connect(function(track)
		local animId = track.Animation and track.Animation.AnimationId
		local cleanAnimId = animId and tostring(animId):lower():gsub('%s+', '') or nil
		local animNum = cleanAnimId and cleanAnimId:match('%d+') or nil
		local action = (animId and reactionTable[animId])
			or (cleanAnimId and reactionTable[cleanAnimId])
			or (animNum and reactionTable[animNum])

		-- Support both formats:
		-- current: ['id'] = 'PillarFixed'
		-- old/reference: ['id'] = { action = 'PillarFixed', name = 'Pillar2' }
		if type(action) == 'table' then
			action = action.action
		end

		if not action then
			if getMainCfg().DEBUG_BOSS_ANIMS and tostring(bossModel.Name):lower() == 'leo' then
				warn('[Prince Project] Unknown Leo animation: ' .. tostring(animId)
					.. ' num=' .. tostring(animNum)
					.. ' name=' .. tostring(track.Animation and track.Animation.Name or 'nil'))
			end
			return
		end

		if getMainCfg().DEBUG_BOSS_ANIMS and tostring(bossModel.Name):lower() == 'leo' then
			warn('[Prince Project] Leo animation matched: ' .. tostring(animId) .. ' -> ' .. tostring(action))
		end

		local rp = getRoot()
		local bossHrp = bossModel:FindFirstChild('HumanoidRootPart')
		if not rp or not bossHrp then return end

		local bossDistance = (rp.Position - bossHrp.Position).Magnitude

		-- Leo is handled with our custom safe system only.
		-- Do not let the generic boss handler override Flame Pillar / Ult movement.
		if tostring(bossModel.Name):lower() == 'leo' then
			if bossDistance > 200 then return end

			if action == 'Block' then
				local wT = (AD.weapon == 'Melee') and 'Melee' or 'Sword'
				getgenv().adSkipHit = true
				pcall(function()
					blockRemote:InvokeServer(true, wT, true)
				end)

				local released = false
				local function releaseLeoBlock()
					if released then return end
					released = true
					task.wait(0.15)
					pcall(function()
						blockRemote:InvokeServer(false, wT)
					end)
					getgenv().adSkipHit = false
				end

				add(track.Stopped:Connect(releaseLeoBlock))
				task.delay(3, releaseLeoBlock)

			elseif action == 'Pillar' or action == 'FlamePillar' then
				local now = tick()
				if now - lastLeoPillarDodgeAt < 1.25 then return end
				lastLeoPillarDodgeAt = now

				getgenv().adSkipHit = true
				leoDodgeActive = true

				local away = Vector3.new(
					rp.Position.X - bossHrp.Position.X,
					0,
					rp.Position.Z - bossHrp.Position.Z
				)
				if away.Magnitude > 0 then
					away = away.Unit
				else
					away = Vector3.new(1, 0, 0)
				end

				local fleePos = rp.Position + away * (tonumber(AD.pillarFlee) or 60)
				fleePos = Vector3.new(fleePos.X, bossHrp.Position.Y, fleePos.Z)

				task.spawn(function()
					lockedPosition = nil
					lockedLookAt = nil
					flameGroundLock = true
					setNoclip(true)

					forceLeoTweenTo(fleePos, tonumber(getMainCfg().BOSS_TWEEN_SPEED) or 130, 5)
					lockedPosition = fleePos
					lockedLookAt = nil

					-- Wait 3 seconds AFTER reaching the Flame Pillar dodge point.
					task.wait(tonumber(AD.leoFlamePillarHoldTime) or 3)

					getgenv().adSkipHit = false
					leoDodgeActive = false
					flameGroundLock = false
					lockedPosition = nil
					lockedLookAt = nil
					antiKBEnabled = false
					canAttack = true
				end)

				add(track.Stopped:Connect(function()
					-- No early release here. The timed holder above controls Flame Pillar.
				end))

			elseif action == 'PillarFixed' then
				doLeoPillarFixedDodge()
			end

			return
		end

		if action ~= 'FlamePillar' and action ~= 'Pillar' and action ~= 'PillarFixed' and bossDistance > 500 then return end
		if action == 'Block' and bossDistance > 260 then return end

		if action == 'Block' then
			-- Cupid Queen false-block fix for BOTH phase 1 and phase 2:
			-- Some ids in the old block list can also be transition/movement tracks.
			-- Only block real non-looped action tracks, and ignore duplicate triggers.
			local priority = track.Priority
			local isActionPriority = priority == Enum.AnimationPriority.Action
				or priority == Enum.AnimationPriority.Action2
				or priority == Enum.AnimationPriority.Action3
				or priority == Enum.AnimationPriority.Action4

			if track.Looped or not isActionPriority then
				return
			end

			local now = tick()
			local key = tostring(animId or cleanAnimId or animNum or 'unknown')
			if lastCupidBlockAnimAt[key] and now - lastCupidBlockAnimAt[key] < 0.65 then
				return
			end
			lastCupidBlockAnimAt[key] = now

			-- If we are already blocking from a previous Cupid action, do not restart
			-- another long fallback timer. This was one cause of "blocking for nothing".
			if blockKeyHeld then
				return
			end

			-- Cupid Queen old/reference block system:
			-- release 0.15s after animation stop in phase 1,
			-- release 0.05s after animation stop in phase 2,
			-- fallback unlock after 3s / 1s if track.Stopped does not fire.
			getgenv().adSkipHit = true
			setCombatBlock(true)

			local released = false
			local function release()
				if released then return end
				released = true

				local isPhase2 = getgenv().adCupidPhase2Permanent == true
				task.wait(isPhase2 and 0.05 or 0.15)

				setCombatBlock(false)
				getgenv().adSkipHit = false
			end

			add(track.Stopped:Connect(release))
			-- Shorter fallback: if track.Stopped does not fire, don't hold block
			-- for a full 3s while Cupid is no longer attacking.
			task.delay(getgenv().adCupidPhase2Permanent and 0.8 or 1.25, release)
		elseif action == 'FlamePillar' or action == 'Pillar' then
			-- Flame Pillar: go away on the ground, stay there 3s AFTER arriving,
			-- then release the lock so the bot goes back to Leo.
			getgenv().adSkipHit = true
			leoDodgeActive = true

			local away = Vector3.new(rp.Position.X - bossHrp.Position.X, 0, rp.Position.Z - bossHrp.Position.Z)
			if away.Magnitude > 0 then
				away = away.Unit
			else
				away = Vector3.new(1, 0, 0)
			end

			local fleePos = rp.Position + away * (tonumber(AD.pillarFlee) or 65)
			fleePos = Vector3.new(fleePos.X, bossHrp.Position.Y + (tonumber(AD.leoFlamePillarGroundOffset) or 0), fleePos.Z)

			task.spawn(function()
				lockedPosition = nil
				lockedLookAt = nil
				flameGroundLock = true
				setNoclip(true)

				DoSafeTeleport(fleePos, true)

				-- The important part: do not release on AnimationTrack.Stopped.
				-- Wait 3 seconds after reaching the dodge point.
				lockedPosition = fleePos
				lockedLookAt = nil
				task.wait(tonumber(AD.leoFlamePillarHoldTime) or 3)

				getgenv().adSkipHit = false
				leoDodgeActive = false
				flameGroundLock = false
				lockedPosition = nil
				lockedLookAt = nil
			end)

			add(track.Stopped:Connect(function()
				-- No early release here. The timed holder above controls the dodge.
			end))
		elseif action == 'PillarFixed' then
			doLeoPillarFixedDodge()
		elseif action == 'StatuePhase' then
			getgenv().adStatuePhaseActive = true
			task.delay(60, function()
				getgenv().adStatuePhaseActive = false
			end)
		end
	end))

	add(humanoid.Died:Connect(cleanup))
	return cleanup
end

local function checkPlayingLeoAnimations(leo)
	if not leo or not AD.enabled then return end
	local hum = leo:FindFirstChildOfClass('Humanoid')
	local animator = hum and hum:FindFirstChildOfClass('Animator')
	if not animator then return end

	local ok, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks()
	end)
	if not ok or type(tracks) ~= 'table' then return end

	for _, track in ipairs(tracks) do
		local animId = track.Animation and track.Animation.AnimationId
		local cleanAnimId = animId and tostring(animId):lower():gsub('%s+', '') or nil
		local animNum = cleanAnimId and cleanAnimId:match('%d+') or nil
		local info = (animId and LEO_ANIMS[animId]) or (cleanAnimId and LEO_ANIMS[cleanAnimId]) or (animNum and LEO_ANIMS[animNum])
		local action = type(info) == 'table' and info.action or info

		-- Backup detector: sometimes AnimationPlayed does not catch Leo ult in time.
		-- If the ult track is already playing, trigger the same safe waypoint dodge.
		if action == 'PillarFixed' then
			doLeoPillarFixedDodge()
		end
	end
end

local function recoverFromLeoUltGravity(leo)
	if not leo or not AD.enabled then return end
	if leoDodgeActive or getgenv().adSkipHit then return end

	local rp = getRoot()
	local hum = getHumanoid()
	local bossHrp = leo:FindFirstChild('HumanoidRootPart')
	if not rp or not hum or not bossHrp or hum.Health <= 0 then return end

	local state = hum:GetState()
	local badState = state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.PlatformStanding

	local expectedY = (tonumber(getMainCfg().LEO_FIXED_BASE_Y) or bossHrp.Position.Y) + (tonumber(getMainCfg().LEO_HOVER_HEIGHT) or 11)
	local gravityPull = rp.AssemblyLinearVelocity.Y < -85 or rp.Position.Y < expectedY - 18 or badState

	if gravityPull then
		hum.PlatformStand = false
		hum.Sit = false
		hum.AutoRotate = false
		rp.AssemblyLinearVelocity = Vector3.zero
		rp.AssemblyAngularVelocity = Vector3.zero

		-- Re-lock above Leo so the eaten ult gravity effect does not leave the bot
		-- stuck/falling for a long time.
		local safePos = Vector3.new(bossHrp.Position.X, expectedY, bossHrp.Position.Z)
		flameGroundLock = false
		lockedPosition = safePos
		lockedLookAt = Vector3.new(bossHrp.Position.X, expectedY, bossHrp.Position.Z)
		antiKBEnabled = true
		canAttack = true
		markProgress('leo gravity recovery')
	end
end

task.spawn(function()
	while task.wait(0.2) do
		if not AD.enabled then continue end

		local leo = findBossGlobal('Leo')
		if leo then
			-- Leo privacy must start as soon as Leo is actually alive/spawned,
			-- not after the formal fightBoss phase. Also keep Leo priority so
			-- early-streamed Cupid cannot steal the hook/camera during Leo.
			if not bossPrivacyCameraActive or bossPrivacyCameraTargetName ~= 'Leo' then
				leoPrivacyStartedForLoop = AD.loopID
				startBossPrivacyCamera('Leo')
			end

			if hookedBossNPC ~= leo then
				if hookedBossCleanup then hookedBossCleanup() end
				hookedBossCleanup = startBossHook(leo, LEO_ANIMS)
				hookedBossNPC = leo
			end

			checkPlayingLeoAnimations(leo)
			recoverFromLeoUltGravity(leo)
			continue
		end

		local cupid = findBossGlobal('Cupid Queen')
		if cupid and hookedBossNPC ~= cupid then
			if hookedBossCleanup then hookedBossCleanup() end
			hookedBossCleanup = startBossHook(cupid, CUPID_ANIMS)
			hookedBossNPC = cupid
		end
	end
end)

task.spawn(function()
	while task.wait(0.05) do
		if not cupidTrackActive or not AD.enabled or not cupidTrackTarget then continue end
		if getgenv().adStatuePhaseActive then continue end

		local hrp = cupidTrackTarget:FindFirstChild('HumanoidRootPart')
		local hum = cupidTrackTarget:FindFirstChild('Humanoid')
		local rp = getRoot()
		if not hrp or not hum or hum.Health <= 0 or not rp then
			cupidTrackTarget = nil
			cupidTrackActive = false
			continue
		end

		local targetPos = Vector3.new(hrp.Position.X, hrp.Position.Y + AD.upHeight, hrp.Position.Z)
		if (rp.Position - targetPos).Magnitude > 5 then
			lockedPosition = nil
			lockedLookAt = nil
			DoSafeTeleport(targetPos)
		end
		lockedPosition = targetPos
		lockedLookAt = nil
	end
end)

-- Leo tracking using the same idea as Cupid Queen tracking.
-- X/Z follows Leo constantly, but Y stays fixed at LEO_FIXED_BASE_Y + LEO_HOVER_HEIGHT.
task.spawn(function()
	while task.wait(0.05) do
		if not AD.enabled or not leoCombatTrackTarget then continue end
		if leoDodgeActive or getgenv().adSkipHit then continue end
		if getMainCfg().LEO_USE_CUPID_TRACK_STYLE == false then continue end

		local hrp = leoCombatTrackTarget:FindFirstChild('HumanoidRootPart')
		local hum = leoCombatTrackTarget:FindFirstChild('Humanoid')
		local rp = getRoot()
		if not hrp or not hum or hum.Health <= 0 or not rp then
			leoCombatTrackTarget = nil
			continue
		end

		local baseY = tonumber(getMainCfg().LEO_FIXED_BASE_Y) or AD.leoFixedBaseY or hrp.Position.Y
		local height = tonumber(getMainCfg().LEO_HOVER_HEIGHT) or AD.upHeight or 11
		local targetPos = Vector3.new(hrp.Position.X, baseY + height, hrp.Position.Z)

		if (rp.Position - targetPos).Magnitude > 5 then
			lockedPosition = nil
			lockedLookAt = nil
			DoSafeTeleport(targetPos)
		end

		lockedPosition = targetPos
		lockedLookAt = nil
	end
end)

local function statuesNeedKilling()
	local pg = LocalPlayer:FindFirstChild('PlayerGui')
	local objectives = pg and pg:FindFirstChild('Objectives')
	local main = objectives and objectives:FindFirstChild('Main')
	return main and main:FindFirstChild('Take down the Statues') ~= nil
end

-- Same statue phase detectors as the reference script:
-- 1) objective child containing "statue"
-- 2) any workspace.Env.Statues child with barrelHP > 0
task.spawn(function()
	local pg = LocalPlayer:FindFirstChild('PlayerGui')
	local objectives = pg and pg:WaitForChild('Objectives', 30)
	if not objectives then return end
	local main = objectives:WaitForChild('Main', 30)
	if not main then return end

	main.ChildAdded:Connect(function(child)
		if tostring(child.Name):lower():find('statue', 1, true) then
			getgenv().adStatuePhaseActive = true
		end
	end)
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		if not AD.enabled then continue end
		if getgenv().adStatuePhaseActive then continue end

		local sf = workspace:FindFirstChild('Env') and workspace.Env:FindFirstChild('Statues')
		if not sf then continue end

		for _, statue in pairs(sf:GetChildren()) do
			local b = statue:FindFirstChild('barrelHP')
			if b and tonumber(b.Value) and tonumber(b.Value) > 0 then
				getgenv().adStatuePhaseActive = true
				break
			end
		end
	end
end)

local function getStatueHPValue(statue)
	if not statue or not statue.Parent then return 0 end

	-- Direct humanoid fallback if statue is represented like an NPC/model.
	local hum = statue:IsA('Model') and statue:FindFirstChildOfClass('Humanoid') or nil
	if hum then return tonumber(hum.Health) or 0 end

	local names = {'barrelHP', 'BarrelHP', 'HP', 'Health', 'health'}
	for _, name in ipairs(names) do
		local hp = statue:FindFirstChild(name, true)
		if hp and (hp:IsA('NumberValue') or hp:IsA('IntValue') or hp:IsA('StringValue')) then
			local ok, value = pcall(function()
				return tonumber(hp.Value)
			end)
			if ok and value then return value end
		end
	end

	for _, obj in ipairs(statue:GetDescendants()) do
		local n = string.lower(obj.Name)
		if (n:find('hp', 1, true) or n:find('health', 1, true))
			and (obj:IsA('NumberValue') or obj:IsA('IntValue') or obj:IsA('StringValue')) then
			local ok, value = pcall(function()
				return tonumber(obj.Value)
			end)
			if ok and value then return value end
		end
	end

	-- If no HP object is exposed, treat existing statue/hitbox as alive.
	-- It will be removed from detection once destroyed or moved away.
	return 1
end

local function getObjectWorldPosition(obj)
	if not obj then return nil end
	if obj:IsA('BasePart') then return obj.Position end
	if obj:IsA('Attachment') then return obj.WorldPosition end
	if obj:IsA('Model') then
		local pp = obj.PrimaryPart or obj:FindFirstChild('HumanoidRootPart') or obj:FindFirstChildWhichIsA('BasePart', true)
		return pp and pp.Position
	end
	local part = obj:FindFirstChildWhichIsA('BasePart', true)
	return part and part.Position
end

local function findStatueHitbox(statue)
	if not statue then return nil end
	if statue:IsA('BasePart') then return statue end

	local direct = statue:FindFirstChild('hitbox', true)
	if direct and direct:IsA('BasePart') then return direct end

	local best = nil
	for _, obj in ipairs(statue:GetDescendants()) do
		if obj:IsA('BasePart') then
			local n = string.lower(obj.Name)
			if n:find('hit', 1, true) or n:find('box', 1, true) or n:find('statue', 1, true) then
				best = obj
				break
			end
			best = best or obj
		end
	end

	return best
end

local function findStatueHPObject(statue)
	if not statue then return nil end

	local names = {'barrelHP', 'BarrelHP', 'HP', 'Health', 'health'}
	for _, name in ipairs(names) do
		local obj = statue:FindFirstChild(name, true)
		if obj and (obj:IsA('NumberValue') or obj:IsA('IntValue') or obj:IsA('StringValue')) then
			return obj
		end
	end

	for _, obj in ipairs(statue:GetDescendants()) do
		local n = string.lower(obj.Name)
		if (n:find('hp', 1, true) or n:find('health', 1, true))
			and (obj:IsA('NumberValue') or obj:IsA('IntValue') or obj:IsA('StringValue')) then
			return obj
		end
	end

	return nil
end

local function getStatueHPValueFromObject(hpObj)
	if not hpObj then return nil end
	local ok, value = pcall(function()
		return tonumber(hpObj.Value)
	end)
	return ok and value or nil
end

local function getKnownCupidStatueHearts()
	local result = {}
	local statuesFolder = workspace:FindFirstChild('Env') and workspace.Env:FindFirstChild('Statues')
	if not statuesFolder then return result end

	local function directBarrelHP(container)
		local hp = container and container:FindFirstChild('barrelHP')
		if hp and (hp:IsA('NumberValue') or hp:IsA('IntValue') or hp:IsA('StringValue')) then
			return hp
		end
		return nil
	end

	local function directHitbox(container)
		local hb = container and container:FindFirstChild('hitbox')
		if hb and hb:IsA('BasePart') then return hb end
		return nil
	end

	local function directHeart(container)
		local statueFix = container and container:FindFirstChild('StatueFix')
		local heart = statueFix and statueFix:FindFirstChild('Heart')
		if heart and heart:IsA('BasePart') then return heart end
		return nil
	end

	local function addStatue(container, label, index)
		if not container then return end

		local heart = directHeart(container)
		local hitbox = directHitbox(container) or heart or findStatueHitbox(container)
		if not hitbox then return end

		local hp = directBarrelHP(container) or findStatueHPObject(container)
		local hpValue = getStatueHPValueFromObject(hp)
		if hpValue ~= nil and hpValue <= 0 then return end

		table.insert(result, {
			model = container,
			hitbox = hitbox,
			heart = heart,
			hp = hp,
			hpValue = hpValue or 1,
			reason = label,
			knownIndex = index,
			isHeartTarget = heart ~= nil,
		})
	end

	-- Same exact structure as the reference script:
	-- 1) workspace.Env.Statues.Statue
	-- 2) workspace.Env.Statues:GetChildren()[2]
	-- 3) workspace.Env.Statues:GetChildren()[3]
	-- Each container should normally have direct children: hitbox + barrelHP,
	-- and the Heart is inside StatueFix.Heart as a landmark.
	local children = statuesFolder:GetChildren()
	addStatue(statuesFolder:FindFirstChild('Statue'), 'known:Statue', 1)
	addStatue(children[2], 'known:GetChildren()[2]', 2)
	addStatue(children[3], 'known:GetChildren()[3]', 3)

	-- Fallback: if the order/name changes, grab every parent that owns StatueFix.Heart.
	local seenContainers = {}
	for _, data in ipairs(result) do
		if data.model then seenContainers[data.model] = true end
	end

	for _, obj in ipairs(statuesFolder:GetDescendants()) do
		if obj.Name == 'Heart' and obj:IsA('BasePart') then
			local statueFix = obj.Parent
			local container = statueFix and statueFix.Parent
			if container and not seenContainers[container] then
				addStatue(container, 'known:fallback:' .. obj:GetFullName(), nil)
				seenContainers[container] = true
			end
		end
	end

	return result
end

local function getAliveStatues()
	local result = {}
	local seenHitboxes = {}
	local seenModels = {}
	local rp = getRoot()
	local scanRadius = tonumber(getMainCfg().STATUE_SCAN_RADIUS) or 450

	local roots = {
		workspace:FindFirstChild('Env') and workspace.Env:FindFirstChild('Statues'),
		workspace:FindFirstChild('Env'),
		workspace:FindFirstChild('Effects'),
		workspace:FindFirstChild('NPCs'),
		workspace:FindFirstChild('Enemies'),
	}

	if getMainCfg().STATUE_USE_HEART_TARGETS ~= false then
		for _, heartData in ipairs(getKnownCupidStatueHearts()) do
			if heartData.hitbox and heartData.hitbox.Parent then
				local hpValue = getStatueHPValueFromObject(heartData.hp)
				if hpValue == nil or hpValue > 0 then
					if not rp or (rp.Position - heartData.hitbox.Position).Magnitude <= scanRadius then
						heartData.hpValue = hpValue or 1
						heartData.distance = rp and (rp.Position - heartData.hitbox.Position).Magnitude or math.huge
						if not seenHitboxes[heartData.hitbox] then
							seenHitboxes[heartData.hitbox] = true
							table.insert(result, heartData)
						end
					end
				end
			end
		end
	end

	local function addCandidate(statue, reason)
		if not statue then return end

		local hitbox = findStatueHitbox(statue)
		if not hitbox then return end

		-- Prioritize unique hitboxes. This avoids killing the same statue twice
		-- through both hitbox-self and hitbox-parent candidates.
		if seenHitboxes[hitbox] then return end

		local hpObj = findStatueHPObject(statue)
		local hpValue = getStatueHPValueFromObject(hpObj)

		-- If parent/model has HP 0, skip. If no HP is exposed, treat as alive
		-- while the hitbox still exists.
		if hpValue ~= nil and hpValue <= 0 then return end

		if rp and (rp.Position - hitbox.Position).Magnitude > scanRadius then return end

		seenHitboxes[hitbox] = true
		seenModels[statue] = true

		local dist = rp and (rp.Position - hitbox.Position).Magnitude or math.huge
		table.insert(result, {
			model = statue,
			hitbox = hitbox,
			hp = hpObj,
			hpValue = hpValue or 1,
			reason = reason or 'scan',
			distance = dist,
		})
	end

	for _, root in ipairs(roots) do
		if root then
			for _, obj in ipairs(root:GetDescendants()) do
				local n = string.lower(obj.Name)

				if obj.Name == 'barrelHP' or n == 'hp' or n:find('health', 1, true) then
					addCandidate(obj.Parent, 'hp:' .. obj:GetFullName())
				elseif obj.Name == 'hitbox' and obj:IsA('BasePart') then
					-- Use the hitbox itself as a separate target when needed.
					-- This is important if the 3 statues are hitboxes inside one folder.
					addCandidate(obj, 'hitbox-self:' .. obj:GetFullName())
					addCandidate(obj.Parent, 'hitbox-parent:' .. obj:GetFullName())
				elseif n:find('statue', 1, true) then
					if obj:IsA('Model') or obj:IsA('Folder') then
						addCandidate(obj, 'name:' .. obj:GetFullName())
					else
						addCandidate(obj.Parent, 'name-parent:' .. obj:GetFullName())
					end
				end
			end
		end
	end

	-- Always sort again from the CURRENT player position.
	-- This guarantees the next target is the closest statue right now.
	rp = getRoot()
	table.sort(result, function(a, b)
		if not rp then return false end
		local da = a.hitbox and (rp.Position - a.hitbox.Position).Magnitude or math.huge
		local db = b.hitbox and (rp.Position - b.hitbox.Position).Magnitude or math.huge
		a.distance = da
		b.distance = db
		return da < db
	end)

	if getMainCfg().DEBUG_STATUES then
		local names = {}
		for i, s in ipairs(result) do
			names[i] = tostring(i)
				.. ':' .. tostring(s.model and s.model.Name or '?')
				.. ' dist=' .. string.format('%.1f', tonumber(s.distance) or 0)
				.. ' hp=' .. tostring(s.hpValue)
				.. ' reason=' .. tostring(s.reason)
		end
		warn('[Prince Project] Statues detected sorted closest-first: ' .. tostring(#result) .. ' | ' .. table.concat(names, ' | '))
	end

	return result
end

local function getClosestAliveStatue()
	local alive = getAliveStatues()
	if #alive == 0 then return nil, alive end
	return alive[1], alive
end

local function hitStatue(statueData, loopID)
	if not statueData or not statueData.hitbox then return false end

	local hitbox = statueData.hitbox
	local weaponType, anims, speeds, defaultSpeed = getWeaponInfo()
	local hpKnown = statueData.hp ~= nil
	local maxHitTime = statueData.isHeartTarget and (tonumber(getMainCfg().STATUE_HEART_HIT_SECONDS) or 4.5) or 12

	lockedPosition = nil
	lockedLookAt = nil

	-- Statue mode must mimic the reference source:
	-- stay in noclip and go directly inside the statue hitbox, then keep hitting barrelHP.
	local savedSpeed = getgenv().adTweenSpeed
	getgenv().adTweenSpeed = tonumber(getMainCfg().STATUE_TWEEN_SPEED) or 70
	if getMainCfg().STATUE_KEEP_NOCLIP ~= false then
		setNoclip(true)
	end

	if not DoSafeTeleport(hitbox.Position, true) then
		getgenv().adTweenSpeed = savedSpeed
		return false
	end

	getgenv().adTweenSpeed = savedSpeed
	lockedPosition = nil
	lockedLookAt = nil
	if getMainCfg().STATUE_KEEP_NOCLIP ~= false then
		setNoclip(true)
	end
	task.wait(0.3)

	local started = tick()
	while AD.enabled
		and AD.loopID == loopID
		and hitbox.Parent
		and tick() - started < maxHitTime
		and ((hpKnown and (getStatueHPValueFromObject(statueData.hp) or 0) > 0) or (not hpKnown and getStatueHPValue(statueData.model) > 0)) do
		local rp = getRoot()
		if not rp then return false end

		if (rp.Position - hitbox.Position).Magnitude > 5 then
			lockedPosition = nil
			lockedLookAt = nil
			if getMainCfg().STATUE_KEEP_NOCLIP ~= false then
				setNoclip(true)
			end
			local savedSpeed = getgenv().adTweenSpeed
			getgenv().adTweenSpeed = tonumber(getMainCfg().STATUE_TWEEN_SPEED) or 70
			if not DoSafeTeleport(hitbox.Position, true) then
				getgenv().adTweenSpeed = savedSpeed
				return false
			end
			getgenv().adTweenSpeed = savedSpeed
			rp = getRoot()
			if not rp then return false end
		end

		-- Stay inside the statue hitbox, not hovering above it.
		if getMainCfg().STATUE_KEEP_NOCLIP ~= false then
			setNoclip(true)
		end
		lockedPosition = hitbox.Position
		lockedLookAt = nil
		canAttack = false
		antiKBEnabled = true

		for combo = 1, 5 do
			if not AD.enabled or AD.loopID ~= loopID then break end
			if hpKnown and (getStatueHPValueFromObject(statueData.hp) or 0) <= 0 then break end
			if not hpKnown and not statueData.isHeartTarget and getStatueHPValue(statueData.model) <= 0 then break end
			if not hitbox.Parent then break end

			rp = getRoot()
			if not rp then break end

			local anim = anims[combo] or CombatAnims[combo]
			local speed = speeds and speeds[combo] or defaultSpeed

			pcall(function()
				combatRegister:InvokeServer({
					[1] = 'swingsfx',
					[2] = weaponType,
					[3] = combo,
					[4] = 'Ground',
					[5] = false,
					[6] = anim,
					[7] = speed,
					[8] = 1.5,
				})

				combatRegister:InvokeServer({
					[1] = 'damage',
					[2] = { hitbox },
					[3] = weaponType,
					[4] = { combo, 'Ground', weaponType },
					[5] = true,
					[6] = rp.CFrame,
					aircombo = 'Ground',
				})
			end)

			lastAttackAt = tick()
			markProgress('hitting statue')
			task.wait(AD.comboDelayNPC)
		end

		task.wait(0.25)
		antiKBEnabled = false
		canAttack = true
	end

	lockedPosition = nil
	lockedLookAt = nil
	antiKBEnabled = false
	canAttack = true
	if getMainCfg().STATUE_KEEP_NOCLIP ~= false then
		setNoclip(false)
	end

	if hpKnown then
		return (getStatueHPValueFromObject(statueData.hp) or 0) <= 0 or not hitbox.Parent
	end

	if statueData.isHeartTarget then
		-- The reported statue targets are Heart parts. Some runs do not expose HP values
		-- on the parent, so after focusing that Heart for STATUE_HEART_HIT_SECONDS,
		-- mark this Heart as handled and rescan for the next closest Heart.
		return true
	end

	return getStatueHPValue(statueData.model) <= 0 or not hitbox.Parent
end

local function killStatues(loopID)
	AD.status = 'statues'
	updateWaypointUI(0, getWaypointTotal(), nil, 'statues')

	local weaponType, anims, speeds, defaultSpeed = getWeaponInfo()
	local sf = workspace:FindFirstChild('Env') and workspace.Env:FindFirstChild('Statues')
	if not sf then
		getgenv().adStatuePhaseActive = false
		return
	end

	-- Exact same statue order as the reference system:
	-- 1) workspace.Env.Statues.Statue
	-- 2) workspace.Env.Statues:GetChildren()[2]
	-- 3) workspace.Env.Statues:GetChildren()[3]
	local list = {
		{ statue = sf:FindFirstChild('Statue'), killIndex = 1 },
		{ statue = sf:GetChildren()[2], killIndex = 2 },
		{ statue = sf:GetChildren()[3], killIndex = 3 },
	}

	local killedCount = 0

	for _, entry in ipairs(list) do
		if not AD.enabled or AD.loopID ~= loopID then break end

		local statue = entry.statue
		if not statue then continue end

		local hitbox = statue:FindFirstChild('hitbox')
		local barrelHP = statue:FindFirstChild('barrelHP')
		if not hitbox or not hitbox:IsA('BasePart') then continue end
		if not barrelHP then continue end

		updateWaypointUI(0, getWaypointTotal(), nil, 'statue ' .. tostring(entry.killIndex))
		-- Silent mode: statue target debug removed.

		-- Same movement as the uploaded script: speed 70, no combat hover,
		-- noclip stays ON, and the player goes inside hitbox.Position.
		local savedSpeed = getgenv().adTweenSpeed
		getgenv().adTweenSpeed = tonumber(getMainCfg().STATUE_TWEEN_SPEED) or 70
		lockedPosition = nil
		lockedLookAt = nil
		setNoclip(true)
		DoSafeTeleport(hitbox.Position, true)
		getgenv().adTweenSpeed = savedSpeed
		lockedPosition = nil
		lockedLookAt = nil
		task.wait(0.3)

		while AD.enabled and AD.loopID == loopID do
			if not barrelHP or not barrelHP.Parent or tonumber(barrelHP.Value) <= 0 then
				killedCount += 1
				markProgress('statue killed ' .. tostring(killedCount))
				break
			end

			local rp = getRoot()
			if not rp then break end

			if (rp.Position - hitbox.Position).Magnitude > 5 then
				local savedSpeed2 = getgenv().adTweenSpeed
				getgenv().adTweenSpeed = tonumber(getMainCfg().STATUE_TWEEN_SPEED) or 70
				lockedPosition = nil
				lockedLookAt = nil
				setNoclip(true)
				DoSafeTeleport(hitbox.Position, true)
				getgenv().adTweenSpeed = savedSpeed2
				lockedPosition = nil
				lockedLookAt = nil
				task.wait(0.1)
				rp = getRoot()
				if not rp then break end
			end

			if not canAttack then task.wait(0.1) end
			canAttack = false
			antiKBEnabled = true
			setNoclip(true)
			lockedPosition = hitbox.Position
			lockedLookAt = nil

			for combo = 1, 5 do
				if not AD.enabled or AD.loopID ~= loopID then break end
				if not barrelHP or not barrelHP.Parent or tonumber(barrelHP.Value) <= 0 then break end

				rp = getRoot()
				if not rp then break end

				-- Keep the player moving/locked toward the statue hitbox without instant CFrame snap.
				-- Movement between statues is handled by DoSafeTeleport tween above.
				lockedPosition = hitbox.Position
				lockedLookAt = nil
				rp.AssemblyLinearVelocity = Vector3.zero
				rp.AssemblyAngularVelocity = Vector3.zero

				local anim = anims[combo] or CombatAnims[combo]
				local speed = speeds and speeds[combo] or defaultSpeed

				pcall(function()
					combatRegister:InvokeServer({
						[1] = 'swingsfx',
						[2] = weaponType,
						[3] = combo,
						[4] = 'Ground',
						[5] = false,
						[6] = anim,
						[7] = speed,
						[8] = 1.5,
					})

					combatRegister:InvokeServer({
						[1] = 'damage',
						[2] = { hitbox },
						[3] = weaponType,
						[4] = { combo, 'Ground', weaponType },
						[5] = true,
						[6] = rp.CFrame,
						aircombo = 'Ground',
					})
				end)

				lastAttackAt = tick()
				task.wait(AD.comboDelayNPC)
			end

			task.wait(AD.fullComboWait)
			antiKBEnabled = false
			canAttack = true
		end
	end

	lockedPosition = nil
	lockedLookAt = nil
	antiKBEnabled = false
	canAttack = true
	setNoclip(false)
	getgenv().adStatuePhaseActive = false
	updateWaypointUI(0, getWaypointTotal(), nil, 'statues done ' .. tostring(killedCount))
end

local function killAllNPCsAtPos(pos, radius)
	radius = radius or 120
	local killed = {}

	while AD.enabled do
		if getgenv().adStatuePhaseActive or statuesNeedKilling() then
			lockedPosition = nil
			lockedLookAt = nil
			getgenv().adStatuePhaseActive = true
			break
		end

		local rp = getRoot()
		if not rp then break end

		local allNPCs = {}
		local seen = {}
		for _, data in ipairs(getAllNearbyNPCs(pos, radius)) do
			if not killed[data.npc] and not seen[data.npc] then
				seen[data.npc] = true
				table.insert(allNPCs, data)
			end
		end
		for _, data in ipairs(getAllNearbyNPCs(rp.Position, radius)) do
			if not killed[data.npc] and not seen[data.npc] then
				seen[data.npc] = true
				table.insert(allNPCs, data)
			end
		end

		if #allNPCs == 0 then
			lockedPosition = nil
			break
		end

		table.sort(allNPCs, function(a, b)
			return (rp.Position - a.hrp.Position).Magnitude < (rp.Position - b.hrp.Position).Magnitude
		end)

		local target = allNPCs[1]
		local targetName = string.lower(target.npc.Name)
		local isCupidQueen = targetName == 'cupid queen'
		local isLeo = targetName == 'leo'
		local hrp = target.hrp

		-- Critical Leo fix: while an animation dodge is active, do NOT set the
		-- normal combat hover lockedPosition before checking adSkipHit.
		-- That old order was pulling the player back toward Leo mid-ult / mid-pillar.
		if getgenv().adSkipHit then
			if isCupidQueen then
				local ch = target.npc:FindFirstChild('Humanoid')
				if ch and ch.Health <= 2500 then
					getgenv().adCupidPhase2Permanent = true
				end
				cupidTrackTarget = target.npc
				cupidTrackActive = true

				-- Cupid aggressive mode: if the block key is not actually held anymore,
				-- do not let a stale adSkipHit pause attacks. This was causing the bot
				-- to wait even when Cupid Queen was hittable.
				if getMainCfg().CUPID_AGGRESSIVE_MODE ~= false and not blockKeyHeld then
					getgenv().adSkipHit = false
				else
					task.wait(0.03)
					continue
				end
			else
				if not leoDodgeActive then
					lockedPosition = nil
					lockedLookAt = nil
				end
				task.wait(0.05)
				continue
			end
		end

		if isCupidQueen then
			if hookedBossNPC ~= target.npc then
				if hookedBossCleanup then hookedBossCleanup() end
				hookedBossCleanup = startBossHook(target.npc, CUPID_ANIMS)
				hookedBossNPC = target.npc
			end
			local h = target.npc:FindFirstChild('Humanoid')
			if h and h.Health <= 2500 then getgenv().adCupidPhase2Permanent = true end
			cupidTrackTarget = target.npc
			cupidTrackActive = true
		else
			local baseY
			if isLeo and AD.leoFixedHoverHeight then
				baseY = tonumber(getMainCfg().LEO_FIXED_BASE_Y) or AD.leoFixedBaseY or hrp.Position.Y
			else
				baseY = getBossBaseY(target.npc) or hrp.Position.Y
			end

			local combatPos = Vector3.new(hrp.Position.X, baseY + AD.upHeight, hrp.Position.Z)
			lockedPosition = nil
			if (rp.Position - combatPos).Magnitude > 3 then
				DoSafeTeleport(combatPos)
			end

			-- Leo can move while the loop is attacking. Keep tracking his current
			-- X/Z every cycle so the bot stays above Leo instead of hovering over
			-- the first center point where the fight started.
			if isLeo and getMainCfg().LEO_TRACK_CENTER ~= false then
				leoCombatTrackTarget = target.npc
				local liveHrp = target.npc:FindFirstChild('HumanoidRootPart')
				if liveHrp then
					local leoHeight = tonumber(getMainCfg().LEO_HOVER_HEIGHT) or AD.upHeight or 11
					combatPos = Vector3.new(liveHrp.Position.X, baseY + leoHeight, liveHrp.Position.Z)
					hrp = liveHrp
				end
			else
				leoCombatTrackTarget = nil
			end

			lockedPosition = combatPos
			lockedLookAt = isLeo and nil or Vector3.new(hrp.Position.X, combatPos.Y, hrp.Position.Z)
		end

		-- adSkipHit is handled before normal combat positioning above.

		attackNPC(target.npc)
		local humAfter = target.npc:FindFirstChild('Humanoid')
		if not humAfter or humAfter.Health <= 0 then
			if isLeo then
				leoCombatTrackTarget = nil
			end
			killed[target.npc] = true
			AD.kills = AD.kills + 1
		end

		task.wait(0.05)
	end
end

local function quickPatrolClear(pos, radius)
	radius = radius or 130
	if not AD.enabled then return false end

	-- Patrol waypoint 26 must visibly tween A <-> B.
	-- So do not use the long spawn-grace clear here.
	-- If NPCs are already present, kill them; otherwise continue the patrol instantly.
	local nearby = getAllNearbyNPCs(pos, radius)
	if #nearby > 0 then
		markProgress('patrol kill')
		killAllNPCsAtPos(pos, radius)
		return true
	end

	return false
end

local function clearAreaAtWaypoint(pos, radius, timeout)
	radius = radius or tonumber(getMainCfg().ROUTE_KILL_RADIUS) or 165
	timeout = timeout or tonumber(getMainCfg().WAYPOINT_CLEAR_SECONDS) or 12

	local started = tick()
	local emptySince = nil
	local sawNPCAtWaypoint = false
	local lastSeenNPCAt = 0
	local spawnGrace = tonumber(getMainCfg().NPC_SPAWN_GRACE_SECONDS) or 1.5
	local minEmptyWait = tonumber(getMainCfg().MIN_EMPTY_WAYPOINT_SECONDS) or 0.10

	while AD.enabled and tick() - started < timeout do
		if not isAliveStable() or not isPlayerInDungeonArea() then
			resetMovementState()
			AD.status = 'waiting after respawn'
			return false
		end

		if getgenv().adStatuePhaseActive or statuesNeedKilling() then
			getgenv().adStatuePhaseActive = true
			return false
		end

		local nearby = getAllNearbyNPCs(pos, radius)
		if #nearby > 0 then
			-- NPC found: kill immediately, then restart the 2.2s spawn grace.
			-- This catches delayed second waves without forcing huge waypoint delays.
			emptySince = nil
			sawNPCAtWaypoint = true
			lastSeenNPCAt = tick()
			killAllNPCsAtPos(pos, radius)
			lastSeenNPCAt = tick()
			markProgress('clearing waypoint')
		else
			emptySince = emptySince or tick()

			local noNPCStable = tick() - emptySince >= minEmptyWait
			-- Important: do NOT wait 2.2s on waypoints where no NPC ever spawned.
			-- Spawn grace is only needed after at least one NPC was seen/killed there.
			local spawnGraceDone = (not sawNPCAtWaypoint) or (tick() - lastSeenNPCAt >= spawnGrace)

			if noNPCStable and spawnGraceDone then
				markProgress('waypoint clear')
				return true
			end

			task.wait(0.12)
		end
	end

	return true
end

local function postWaypointRescan(pos, radius)
	if typeof(pos) ~= 'Vector3' then return true end
	if not AD.enabled then return false end

	radius = radius or tonumber(getMainCfg().ROUTE_KILL_RADIUS) or 165
	local duration = tonumber(getMainCfg().POST_WAYPOINT_RESCAN_SECONDS) or 1.15
	local interval = tonumber(getMainCfg().POST_WAYPOINT_RESCAN_INTERVAL) or 0.15
	local started = tick()

	while AD.enabled and tick() - started < duration do
		if getgenv().adStatuePhaseActive or statuesNeedKilling() then return false end

		local nearbyAtPoint = getAllNearbyNPCs(pos, radius)
		local rp = getRoot()
		local nearbyPlayer = rp and getAllNearbyNPCs(rp.Position, radius) or {}

		if #nearbyAtPoint > 0 or #nearbyPlayer > 0 then
			markProgress('post waypoint NPC')
			killAllNPCsAtPos(pos, radius)
			-- Restart the small rescan window after killing, because some packs
			-- spawn a second wave shortly after the first one dies.
			started = tick()
		end

		task.wait(interval)
	end

	return true
end

local function sweepSegmentForMissedNPCs(fromPos, toPos, radius)
	if getMainCfg().ROUTE_SWEEP_ENABLED == false then return true end
	if typeof(fromPos) ~= 'Vector3' or typeof(toPos) ~= 'Vector3' then return true end
	if not AD.enabled then return false end

	radius = radius or tonumber(getMainCfg().ROUTE_KILL_RADIUS) or 165
	local step = tonumber(getMainCfg().ROUTE_SWEEP_STEP) or 85
	local timeout = tonumber(getMainCfg().ROUTE_SWEEP_TIMEOUT) or 3.2
	local delta = toPos - fromPos
	local dist = delta.Magnitude
	if dist <= 1 then return true end

	local points = math.max(1, math.ceil(dist / step))
	for n = 0, points do
		if not AD.enabled then return false end
		if getgenv().adStatuePhaseActive or statuesNeedKilling() then return false end

		local alpha = n / points
		local sample = fromPos:Lerp(toPos, alpha)
		local nearby = getAllNearbyNPCs(sample, radius)

		if #nearby > 0 then
			updateWaypointUI(AD.waypointIdx, #DUNGEON_WAYPOINTS, DUNGEON_WAYPOINTS[AD.waypointIdx], 'sweep missed NPC')
			-- Silent mode: missed NPC sweep debug removed.

			-- Move back to the nearest route sample, then clear quickly.
			-- This prevents leaving NPCs between waypoints without adding huge delays when none exist.
			lockedPosition = nil
			lockedLookAt = nil
			DoSafeTeleport(sample)
			clearAreaAtWaypoint(sample, radius, timeout)
		end

		task.wait(0.02)
	end

	return true
end

local function fightBoss(loopID, bossName, searchTimeoutOverride)
	applyBossRuntimeSettings()
	if tostring(bossName):lower() == 'leo' then
		-- Custom Leo height.
		AD.upHeight = tonumber(getMainCfg().LEO_HOVER_HEIGHT) or 11
		getgenv().adTweenSpeed = tonumber(getMainCfg().BOSS_TWEEN_SPEED) or 130
		AD.blockHoldExtraSeconds = 0.15
		AD.pillarFlee = tonumber(getMainCfg().LEO_FLAME_PILLAR_DISTANCE) or 60
	end
	AD.status = 'boss'
	if tostring(bossName):lower() == 'leo' then
		leoPrivacyStartedForLoop = loopID
	end
	startBossPrivacyCamera(bossName)
	canAttack = true
	getgenv().adSkipHit = false

	local searchStart = tick()
	local bossWasFound = false
	while AD.enabled and AD.loopID == loopID do
		local boss = findBossGlobal(bossName)
		if not boss then
			-- Important: after Leo has been found once, findBossGlobal returns nil
			-- as soon as he dies. Do not keep waiting for the full search timeout,
			-- otherwise the bot pauses several seconds before moving to Cupid.
			if bossWasFound then break end
			if tick() - searchStart > (tonumber(searchTimeoutOverride) or 30) then break end
			task.wait(0.2)
			continue
		end

		bossWasFound = true
		local hum = boss:FindFirstChild('Humanoid')
		local hrp = boss:FindFirstChild('HumanoidRootPart')
		if not hum or hum.Health <= 0 or not hrp then break end
		killAllNPCsAtPos(hrp.Position, 200)
		if getMainCfg().CUPID_AGGRESSIVE_MODE ~= false and not blockKeyHeld and not getgenv().adStatuePhaseActive then
			getgenv().adSkipHit = false
			canAttack = true
		end
		task.wait(0.02)
	end

	stopBossPrivacyCamera()
end

local function fightCupidQueen(loopID)
	applyBossRuntimeSettings()
	startBossPrivacyCamera('Cupid Queen')
	if not isAliveStable() or not isPlayerInDungeonArea() then
		resetMovementState()
		return
	end

	AD.status = 'boss'
	canAttack = true
	getgenv().adSkipHit = false
	getgenv().adCupidPhase2Permanent = false
	cupidTrackActive = false
	cupidTrackTarget = nil
	setNoclip(true)

	-- No forced walk/core animation during Cupid Queen.
	-- The old looped rbxassetid://13630769186 animation could make the
	-- character look like it was walking while attacking Cupid Queen.

	local boss = nil
	while AD.enabled and AD.loopID == loopID do
		boss = findBossGlobal('Cupid Queen')
		local h = boss and boss:FindFirstChild('Humanoid')
		if h and h.Health > 0 then break end
		task.wait(0.5)
	end
	if not boss or not AD.enabled or AD.loopID ~= loopID then return end

	if hookedBossNPC ~= boss then
		if hookedBossCleanup then hookedBossCleanup() end
		hookedBossCleanup = startBossHook(boss, CUPID_ANIMS)
		hookedBossNPC = boss
	end

	cupidTrackTarget = boss
	cupidTrackActive = true

	while AD.enabled and AD.loopID == loopID do
		if getgenv().adStatuePhaseActive or statuesNeedKilling() then
			getgenv().adStatuePhaseActive = false
			cupidTrackActive = false
			lockedPosition = nil
			lockedLookAt = nil
			killStatues(loopID)
			cupidTrackTarget = boss
			cupidTrackActive = true
			AD.status = 'boss'
			continue
		end

		local hum = boss:FindFirstChild('Humanoid')
		local hrp = boss:FindFirstChild('HumanoidRootPart')
		if not hum or hum.Health <= 0 or not hrp then
			cupidTrackActive = false
			cupidTrackTarget = nil
			break
		end

		killAllNPCsAtPos(hrp.Position, 200)
		task.wait(0.05)
	end

	setNoclip(false)
	stopBossPrivacyCamera()
end

DUNGEON_WAYPOINTS = {
	{pos=CFrame.new(864.057,308.442,-2281.369)},
	{pos=CFrame.new(663.821,310.375,-2280.452)},
	{pos=CFrame.new(530.736,310.375,-2395.278)},
	{pos=CFrame.new(529.187,320.375,-2559.292)},
	{pos=CFrame.new(525.878,320.547,-2650.659)},
	{pos=CFrame.new(421.200,320.457,-2725.460)},
	{pos=Vector3.new(217.095,320.375,-2704.779)},
	{pos=CFrame.new(108.374,344.782,-2707.636)},
	{pos=CFrame.new(14.713,373.595,-2706.241)},
	{pos=CFrame.new(-92.012,376.419,-2699.929)},
	{pos=CFrame.new(-169.500,376.711,-2699.747)},
	{pos=CFrame.new(-271.037,376.375,-2613.631)},
	{pos=CFrame.new(-285.967,376.375,-2776.954)},
	{pos=CFrame.new(-342.176,376.852,-2722.077)},
	{pos=CFrame.new(-376.101,376.375,-2697.313)},
	{pos=CFrame.new(-480.562,413.188,-2697.654)},
	{pos=CFrame.new(-564.035,434.114,-2697.977)},
	{pos=CFrame.new(-679.507,435.375,-2698.441)},
	{pos=CFrame.new(-744.393,435.375,-2680.910)},
	{pos=CFrame.new(-800.263,435.781,-2688.976)},
	{pos=CFrame.new(-832.069,435.829,-2644.643)},
	{pos=CFrame.new(-957.529,435.819,-2777.550)},
	{pos=CFrame.new(-978.196,435.375,-2823.386)},
	{pos=CFrame.new(-1075.806,435.375,-2920.543)},
	{pos=CFrame.new(-1080.805,444.375,-3100.134)},
	{type='patrol',posA=CFrame.new(-1182.491,444.375,-3179.820),posB=CFrame.new(-954.535,444.375,-3183.628),duration=tonumber(getMainCfg().PATROL_DURATION_SECONDS) or 8},
	{pos=CFrame.new(-1080.273,447.375,-3355.000)},
	{pos=CFrame.new(-1077.944,452.375,-3484.318)},
	{pos=CFrame.new(-1075.926,452.944,-3596.407)},
	{pos=CFrame.new(-1072.873,452.375,-3765.750)},
	{pos=CFrame.new(-1074.256,463.597,-3805.134)},
	{pos=CFrame.new(-1080.698,502.040,-3905.488)},
	{pos=CFrame.new(-1083.563,506.375,-3986.992)},
	{pos=CFrame.new(-1085.566,506.375,-4061.669)},
}

local function getWPPos(wp)
	if wp.type == 'patrol' then
		return (wp.posA.Position + wp.posB.Position) / 2
	end
	return typeof(wp.pos) == 'CFrame' and wp.pos.Position or wp.pos
end

local function findNearestWaypointIndex()
	local rp = getRoot()
	if not rp then return 1 end
	local bestIdx, bestDist = 1, math.huge
	for i, wp in ipairs(DUNGEON_WAYPOINTS) do
		local dist = (rp.Position - getWPPos(wp)).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestIdx = i
		end
	end
	if bestDist > 400 then return 1 end
	return bestIdx
end

local KNOWN_FRUITS = {
	Mero=true, Spin=true, Kilo=true, Venom=true, Budha=true, Gura=true,
	Heal=true, Mera=true, Goro=true, Suna=true, Ito=true, Paw=true,
	Kage=true, Hie=true, Suke=true, Tori=true, Dragon=true, Soul=true,
	Magu=true, Pika=true, Yuki=true, Ope=true, Yami=true, Zushi=true,
	Kira=true, Yomi=true, Bomu=true, Gomu=true, Bari=true, Horo=true,
	Goru=true, Mochi=true,
}

local SLOT_NAMES = {'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}
local SLOT_KEYS = {
	One=Enum.KeyCode.One, Two=Enum.KeyCode.Two, Three=Enum.KeyCode.Three,
	Four=Enum.KeyCode.Four, Five=Enum.KeyCode.Five, Six=Enum.KeyCode.Six,
	Seven=Enum.KeyCode.Seven, Eight=Enum.KeyCode.Eight, Nine=Enum.KeyCode.Nine,
	Zero=Enum.KeyCode.Zero,
}
local IGNORED_CHILDREN = {UIAspectRatioConstraint=true, Design=true, Number=true, HotbarObject=true}

local function storeFruitNow()
	if not fruitStorageRemote then return end
	local pg = LocalPlayer:FindFirstChild('PlayerGui')
	local hotbar = pg and pg:FindFirstChild('BackpackGui') and pg.BackpackGui:FindFirstChild('Hotbar')
	if not hotbar then return end

	for _, slotName in ipairs(SLOT_NAMES) do
		local slot = hotbar:FindFirstChild(slotName)
		if not slot then continue end

		local fruitFound = false
		for _, child in ipairs(slot:GetChildren()) do
			if not IGNORED_CHILDREN[child.Name] and KNOWN_FRUITS[child.Name] then
				fruitFound = true
				break
			end
		end

		if fruitFound then
			local key = SLOT_KEYS[slotName]
			if key then
				VirtualInputManager:SendKeyEvent(true, key, false, game)
				task.wait(0.15)
				VirtualInputManager:SendKeyEvent(false, key, false, game)
				task.wait(0.4)
				pcall(function() fruitStorageRemote:InvokeServer(true) end)
				task.wait(0.5)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		if getgenv().PrinceProjectStopped then break end
		if not getgenv().adAutoStoreFruits then continue end
		storeFruitNow()
		task.wait(2)
	end
end)

local function getInventoryRoot()
	return ReplicatedStorage:FindFirstChild('Stats' .. LocalPlayer.Name)
end

local function getInventoryValueString()
	-- Reference source uses: string.find(tostring(inventory.Value), "World Scroll")
	-- So the main inventory source is ReplicatedStorage['Stats'..Name].Inventory.Value.
	local root = getInventoryRoot()
	local inv = root and root:FindFirstChild('Inventory')
	if not inv then return '' end

	local ok, value = pcall(function()
		return inv.Value
	end)

	if ok and value ~= nil then
		return tostring(value)
	end

	return ''
end

local function normalizeItemName(value)
	return tostring(value or ''):lower():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function inventoryTextContains(itemName)
	local root = getInventoryRoot()
	if not root then return false end

	local wanted = normalizeItemName(itemName)
	if wanted == '' then return false end

	-- Main check copied from the World Scroll logic:
	-- string.find(tostring(inventory.Value), itemName)
	local inventoryText = normalizeItemName(getInventoryValueString())
	if inventoryText ~= '' and inventoryText:find(wanted, 1, true) then
		return true
	end

	-- Extra fallback: the game can also expose inventory entries as children.
	local inv = root:FindFirstChild('Inventory')
	if inv then

		for _, obj in ipairs(inv:GetDescendants()) do
			if normalizeItemName(obj.Name) == wanted then
				return true
			end

			local okObjValue, objValue = pcall(function()
				return obj.Value
			end)
			if okObjValue and objValue ~= nil and normalizeItemName(objValue):find(wanted, 1, true) then
				return true
			end
		end
	end

	-- Fallback: scan whole Stats folder, because some item unlocks are stored
	-- outside Inventory depending on the item category.
	for _, obj in ipairs(root:GetDescendants()) do
		if normalizeItemName(obj.Name) == wanted then
			return true
		end

		local okObjValue, objValue = pcall(function()
			return obj.Value
		end)
		if okObjValue and objValue ~= nil and normalizeItemName(objValue):find(wanted, 1, true) then
			return true
		end
	end

	return false
end

local function hotbarOrBackpackHasItem(itemName)
	local wanted = normalizeItemName(itemName)
	if wanted == '' then return false end

	local function scan(container)
		if not container then return false end
		for _, obj in ipairs(container:GetDescendants()) do
			if normalizeItemName(obj.Name) == wanted then
				return true
			end
		end
		return false
	end

	local char = getCharacter()
	local backpack = LocalPlayer:FindFirstChild('Backpack')
	if scan(char) or scan(backpack) then return true end

	local pg = LocalPlayer:FindFirstChild('PlayerGui')
	local backpackGui = pg and pg:FindFirstChild('BackpackGui')
	local backpackFrame = backpackGui and backpackGui:FindFirstChild('Backpack')
	local inventoryFrame = backpackFrame and backpackFrame:FindFirstChild('Inventory')
	return scan(backpackGui and backpackGui:FindFirstChild('Hotbar'))
		or scan(inventoryFrame and inventoryFrame:FindFirstChild('WeaponsInventory'))
		or scan(inventoryFrame and inventoryFrame:FindFirstChild('Weapons'))
		or scan(inventoryFrame)
end

hasInventoryItemForEquip = function(itemName) -- [PRINCE HUB v18] see forward declaration
	return inventoryTextContains(itemName) or hotbarOrBackpackHasItem(itemName)
end

local lastAutoEquipAttempt = {}
local function equipItemByName(itemName)
	if not toolsRemote then return false end
	if not itemName or tostring(itemName) == '' then return false end

	-- Exact equip remote format:
	-- ReplicatedStorage.Events.Tools:InvokeServer('equip', itemName)
	local ok = pcall(function()
		local args = { 'equip', tostring(itemName) }
		toolsRemote:InvokeServer(unpack(args))
	end)

	return ok == true
end

local function autoEquipItemsNow()
	if not getgenv().adAutoEquipItems or not toolsRemote then return end

	for itemName, enabled in pairs(getgenv().adItemsToEquip or {}) do
		-- Important: only equip if the item is detected in inventory/hotbar/backpack.
		-- If the item is not visible yet, do not call Tools:InvokeServer('equip', itemName).
		if enabled and hasInventoryItemForEquip(itemName) then
			local now = tick()
			if not lastAutoEquipAttempt[itemName] or now - lastAutoEquipAttempt[itemName] >= 4 then
				lastAutoEquipAttempt[itemName] = now
				equipItemByName(itemName)
				task.wait(0.15)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(2)
		if getgenv().PrinceProjectStopped then break end
		autoEquipItemsNow()
	end
end)

local function storeFruitsBeforeReplay()
	-- Restore camera/HUD before storing so you can visually check if fruit store works.
	stopBossPrivacyCamera(true)
	if getgenv().adAutoStoreFruits then
		task.wait(2)
		storeFruitNow()
		task.wait(1)
	end
end

local function replayOrStop()
	if getgenv().PrinceProjectStopped or not getgenv().adAutoReplay then
		AD.enabled = false
		AD.status = 'idle'
		return
	end

	AD.status = 'replay'
	task.wait(7)
	notify('Teleporting to Universe Hub...')
	pcall(function()
		TeleportService:TeleportToPlaceInstance(UNIVERSE_HUB_PLACE_ID, '2c6cd3f9-8a53-4cb8-9b8e-b2c8259c29c9', LocalPlayer)
	end)
	task.wait(8)
	AD.startDungeon()
end

local function onDungeonComplete()
	local boss = findBossGlobal('Cupid Queen')
	local alive = boss and boss:FindFirstChild('Humanoid') and boss.Humanoid.Health > 0
	if alive then
		task.spawn(function()
			fightCupidQueen(AD.loopID)
			onDungeonComplete()
		end)
		return
	end

	cupidTrackActive = false
	cupidTrackTarget = nil
	lockedPosition = nil
	stopBossPrivacyCamera(true)
	AD.status = 'replay'

	storeFruitsBeforeReplay()

	replayOrStop()
end

task.spawn(function()
	local handled = false
	while task.wait(1) do
		if getgenv().PrinceProjectStopped then break end
		local pg = LocalPlayer:FindFirstChild('PlayerGui')
		local exitQuest = pg and pg:FindFirstChild('Objectives') and pg.Objectives:FindFirstChild('Main') and pg.Objectives.Main:FindFirstChild('Head to the Exit')
		if exitQuest and not handled then
			handled = true
			task.spawn(function()
				task.wait(5)
				storeFruitsBeforeReplay()
				replayOrStop()
			end)
		elseif not exitQuest then
			handled = false
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if getgenv().PrinceProjectStopped then break end
		if not AD.enabled then continue end

		local hum = getHumanoid()
		local rp = getRoot()
		if not hum or not rp or hum.Health <= 0 then
			lastDeathAt = tick()
			resetMovementState()
			setNoclip(false)
			AD.status = 'dead / respawning'
			continue
		end

		if not isPlayerInDungeonArea() then
			resetMovementState()
			setNoclip(false)
			AD.status = 'outside dungeon - waiting'
			continue
		end

		local stuckLimit = tonumber(getMainCfg().STUCK_RESET_SECONDS) or 25
		if tick() - lastProgressAt > stuckLimit then
			resetMovementState()
			weaponEquipped = false
			canAttack = true
			antiKBEnabled = false
			equipWeapon()
			markProgress('watchdog reset')
		end

		-- Extra Leo safety: if the bot has stopped attacking Leo while no dodge/block
		-- is active, re-enable attacks immediately instead of waiting for watchdog.
		local leo = findBossGlobal('Leo')
		if leo and not getgenv().adSkipHit and not leoDodgeActive and canAttack == false then
			canAttack = true
			antiKBEnabled = false
			markProgress('leo attack unlocked')
		end

		-- Cupid aggressive safety: priority is to keep hitting Cupid Queen.
		-- If no real block/statue phase is active and the bot has not attacked for
		-- a short moment, unlock attack immediately instead of waiting.
		local cupid = findBossGlobal('Cupid Queen')
		if cupid and getMainCfg().CUPID_AGGRESSIVE_MODE ~= false and not getgenv().adStatuePhaseActive then
			if getgenv().adSkipHit and not blockKeyHeld then
				getgenv().adSkipHit = false
			end
			if canAttack == false and not blockKeyHeld and tick() - lastAttackAt > (tonumber(getMainCfg().CUPID_STUCK_ATTACK_UNLOCK_SECONDS) or 1.2) then
				canAttack = true
				antiKBEnabled = false
				markProgress('cupid attack unlocked')
			end
		end
	end
end)

function startDungeonPrivacyCamera()
	if getMainCfg().DUNGEON_PRIVACY_CAMERA == false then return end
	dungeonPrivacyCameraActive = true
	-- No boss target: camera follows the player from the sky.
	startBossPrivacyCamera(nil)
end

AD.stopDungeon = function()
	AD.enabled = false
	AD.loopID = AD.loopID + 1
	AD.status = 'idle'
	AD.waypointIdx = 0
	updateWaypointUI(0, getWaypointTotal(), nil, 'stopped')
	tpId = tpId + 1
	stopBlock()
	stopBossPrivacyCamera(true)
	setNoclip(false)
	antiKBEnabled = false
	lockedPosition = nil
	lockedLookAt = nil
	getgenv().adSkipHit = false
	getgenv().adCupidPhase2Permanent = false
	cupidTrackTarget = nil
	cupidTrackActive = false
	leoCombatTrackTarget = nil
	canAttack = true
	if activeTpConn then activeTpConn:Disconnect(); activeTpConn = nil end
	if invisibleFloor then invisibleFloor:Destroy(); invisibleFloor = nil end
	if hookedBossCleanup then hookedBossCleanup() end
	hookedBossCleanup = nil
	hookedBossNPC = nil
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
end

-- Keep these global to avoid Luau local-register overflow in the main chunk.
cancelButtonGui = nil
controlGui = nil
function stopPrinceProject()
	getgenv().PrinceProjectStopped = true

	local main = Config and Config.MAIN
	if type(main) == 'table' then
		main.AUTO_JOIN_UNIVERSE_HUB = false
		main.AUTO_JOIN_CUPID = false
		main.AUTO_DUNGEON = false
		main.AUTO_STORE = false
		main.AUTO_REPLAY = false
		main.AUTO_EQUIP_ITEMS = false
		main.WHITE_SCREEN = false
	end

	getgenv().adAutoStoreFruits = false
	getgenv().adAutoReplay = false
	getgenv().adAutoEquipItems = false
	getgenv().adSkipHit = false
	getgenv().adStatuePhaseActive = false
	getgenv().adCupidPhase2Permanent = false

	pcall(function()
		AD.stopDungeon()
	end)

	setWhiteScreen(false)
	hideWaypointUI()
	stopBossPrivacyCamera(true)
	resetMovementState()
	setNoclip(false)
	stopBlock()
	flameGroundLock = false
	leoDodgeActive = false
	antiKBEnabled = false
	lockedPosition = nil
	lockedLookAt = nil
	cupidTrackTarget = nil
	cupidTrackActive = false
	canAttack = true

	if cancelButtonGui then
		cancelButtonGui:Destroy()
		cancelButtonGui = nil
	end

	if controlGui then
		controlGui:Destroy()
		controlGui = nil
	end
end

-- Do NOT declare these as local functions: the main chunk is already near Luau's
-- 200-local-register limit, and allocating another local named createRuntimeControls
-- can crash some executors before the script even starts.
function createCancelButton()
	-- UI disabled: stop button removed.
end

function createRuntimeControls()
	-- UI disabled: runtime controls removed.
end

AD.startDungeon = function()
	if getgenv().PrinceProjectStopped then return end
	if AD.enabled then return end
	applyWeaponFromConfig()
	dungeonRunStartedAt = tick()
	lastProgressAt = tick()
	lastAttackAt = tick()

	AD.enabled = true
	AD.loopID = AD.loopID + 1
	local loopID = AD.loopID
	AD.kills = 0
	AD.status = 'waiting'
	createWaypointUI()
	updateWaypointUI(0, getWaypointTotal(), nil, 'waiting')
	startDungeonPrivacyCamera()
	weaponEquipped = false
	canAttack = true
	antiKBEnabled = false
	lockedPosition = nil
	getgenv().adSkipHit = false
	getgenv().adCupidPhase2Permanent = false

	equipWeapon()
	autoEquipItemsNow()

	task.spawn(function()
		local startDelay = tonumber(AD.startDelay) or 0
		if startDelay > 0 then
			for i = startDelay, 1, -1 do
				if getgenv().PrinceProjectStopped then return end
				if not AD.enabled or AD.loopID ~= loopID then return end
				AD.status = 'starts in ' .. tostring(i)
				task.wait(1)
			end
		end

		if not AD.enabled or AD.loopID ~= loopID then return end
		if getgenv().PrinceProjectStopped then return end
		if not waitUntilDungeonArea(tonumber(getMainCfg().DUNGEON_ENTRY_TIMEOUT) or 120) then
			AD.status = 'not in dungeon area'
			AD.enabled = false
			resetMovementState()
			return
		end
		AD.status = 'running'
		applyDungeonRuntimeSettings()
		updateWaypointUI(0, getWaypointTotal(), nil, 'running')

		-- Do NOT jump to Cupid just because the model exists in Workspace.
		-- Some runs spawn/stream the boss early, which made the bot skip stages,
		-- noclip through barriers, then stand still at Cupid.
		local leoNearby = findBossGlobal('Leo')
		if leoNearby then
			local lh = leoNearby:FindFirstChild('HumanoidRootPart')
			local rp = getRoot()
			if lh and rp and (rp.Position - lh.Position).Magnitude < 400 then
				fightBoss(loopID, 'Leo')
			end
		end

		local routeFailed = false
		local startIdx = findNearestWaypointIndex()
		local previousRoutePos = nil
		local routeKillRadius = tonumber(getMainCfg().ROUTE_KILL_RADIUS) or 165

		for i = startIdx, #DUNGEON_WAYPOINTS do
			if not AD.enabled or AD.loopID ~= loopID then break end
			AD.waypointIdx = i
			local wp = DUNGEON_WAYPOINTS[i]
			updateWaypointUI(i, #DUNGEON_WAYPOINTS, wp, 'moving')

			if wp.type == 'patrol' then
				updateWaypointUI(i, #DUNGEON_WAYPOINTS, wp, 'patrol')
				local posA = wp.posA.Position
				local posB = wp.posB.Position
				local startTime = tick()
				local goB = true
				local lastPatrolPos = previousRoutePos or (getRoot() and getRoot().Position) or posA
				while AD.enabled and AD.loopID == loopID and tick() - startTime < (wp.duration or 10) do
					local target = goB and posB or posA
					updateWaypointUI(i, #DUNGEON_WAYPOINTS, wp, goB and 'patrol to B' or 'patrol to A')

					if not DoSafeTeleport(target) then
						routeFailed = true
						break
					end

					sweepSegmentForMissedNPCs(lastPatrolPos, target, routeKillRadius)
					task.wait(tonumber(AD.waypointMoveDelay) or 0.02)
					quickPatrolClear(target, routeKillRadius)
					postWaypointRescan(target, routeKillRadius)
					lastPatrolPos = target
					goB = not goB
				end
				previousRoutePos = lastPatrolPos
			else
				local target = getWPPos(wp)
				local rpBefore = getRoot()
				local fromPos = previousRoutePos or (rpBefore and rpBefore.Position) or target

				if not DoSafeTeleport(target) then
					routeFailed = true
					break
				end

				-- Leo can spawn shortly after waypoint 34, before fightBoss('Leo') starts.
				-- Start privacy camera + HUD hide early here so the method is hidden in time.
				if i == (tonumber(getMainCfg().LEO_PRIVACY_START_WAYPOINT) or 32)
					and leoPrivacyStartedForLoop ~= loopID then
					leoPrivacyStartedForLoop = loopID
					task.spawn(function()
						-- Wait the known spawn delay, then only start privacy when Leo
						-- actually exists/alive. This prevents the camera from starting
						-- late after Leo is already dead.
						task.wait(tonumber(getMainCfg().LEO_PRIVACY_START_DELAY) or 2.9)
						local startedAt = tick()
						while AD.enabled and AD.loopID == loopID and not getgenv().PrinceProjectStopped and tick() - startedAt < 25 do
							local leo = findBossGlobal('Leo')
							if leo then
								startBossPrivacyCamera('Leo')
								break
							end
							task.wait(0.15)
						end
					end)
				end

				sweepSegmentForMissedNPCs(fromPos, target, routeKillRadius)
				task.wait(tonumber(AD.waypointMoveDelay) or 0.02)
				updateWaypointUI(i, #DUNGEON_WAYPOINTS, wp, 'clearing')
				clearAreaAtWaypoint(target, routeKillRadius, tonumber(getMainCfg().WAYPOINT_CLEAR_SECONDS) or 12)
				postWaypointRescan(target, routeKillRadius)
				previousRoutePos = target
			end
		end

		if routeFailed or not isAliveStable() or not isPlayerInDungeonArea() then
			resetMovementState()
			AD.status = 'route stopped safely'
			return
		end

		if not AD.enabled or AD.loopID ~= loopID then return end
		AD.waypointIdx = 0
		updateWaypointUI(0, #DUNGEON_WAYPOINTS, nil, 'Leo boss')

		-- Leo may already be killed during the last waypoint clear because he spawns
		-- close enough to waypoint 34. In that case, do NOT wait the full boss
		-- search timeout; just do a very short confirmation and move to Cupid.
		if findBossGlobal('Leo') then
			fightBoss(loopID, 'Leo', tonumber(getMainCfg().LEO_POST_ROUTE_SEARCH_SECONDS) or 3)
		else
			local leoSearchStarted = tick()
			while AD.enabled and AD.loopID == loopID and tick() - leoSearchStarted < (tonumber(getMainCfg().LEO_POST_ROUTE_SEARCH_SECONDS) or 3) do
				if findBossGlobal('Leo') then
					fightBoss(loopID, 'Leo', tonumber(getMainCfg().LEO_POST_ROUTE_SEARCH_SECONDS) or 3)
					break
				end
				task.wait(0.15)
			end
		end
		if not AD.enabled or AD.loopID ~= loopID then return end
		if not isAliveStable() or not isPlayerInDungeonArea() then
			resetMovementState()
			return
		end

		local savedLeoToCupidSpeed = getgenv().adTweenSpeed
		getgenv().adTweenSpeed = tonumber(getMainCfg().LEO_TO_CUPID_TWEEN_SPEED) or 120

		for _, pos in ipairs({
			Vector3.new(-1091.291,506.375,-4424.925),
			Vector3.new(-1092.546,568.555,-4497.691),
			Vector3.new(-1092.954,631.463,-4588.583),
			Vector3.new(-1091.032,639.903,-4747.583),
			Vector3.new(-1033.052,667.073,-5048.281),
			}) do
			lockedPosition = nil
			lockedLookAt = nil
			if not DoSafeTeleport(pos, true) then break end
			task.wait(tonumber(getMainCfg().LEO_TO_CUPID_WAYPOINT_DELAY) or 0.03)
		end

		getgenv().adTweenSpeed = savedLeoToCupidSpeed

		lockedPosition = nil
		lockedLookAt = nil
		updateWaypointUI(0, #DUNGEON_WAYPOINTS, nil, 'Cupid boss')
		fightCupidQueen(loopID)
		AD.status = 'complete'
		updateWaypointUI(0, #DUNGEON_WAYPOINTS, nil, 'complete')
		AD.enabled = false
		task.spawn(onDungeonComplete)
	end)
end

-- ============================================================
-- BOOT FROM CONFIG
-- ============================================================
applyOptimization()
applyDisplayConfig()
applyWeaponFromConfig()
-- UI disabled: no cancel button, no runtime controls.
-- createCancelButton()
-- createRuntimeControls()

if getMainCfg().AUTO_REJOIN and not getgenv().PrinceProjectStopped then
	startAutoRejoin()
end

if (getMainCfg().AUTO_JOIN_UNIVERSE_HUB or getMainCfg().AUTO_JOIN_UNIVERSE) and not getgenv().PrinceProjectStopped then
	startAutoJoinUniverseHub()
end

if (getMainCfg().AUTO_JOIN_CUPID or getMainCfg().AUTO_JOIN_CUPID_DUNGEON) and not getgenv().PrinceProjectStopped then
	startAutoJoinCupid()
end

if getMainCfg().AUTO_DUNGEON and not getgenv().PrinceProjectStopped then
	task.spawn(function()
		-- If launched from Universe Hub at Vector3.new(20003, 6, -8), the early
		-- queue block waits until the player reaches the real Cupid spawn, then
		-- sets PrinceProjectForceDungeonLoad. Start as soon as either condition is true.
		while not getgenv().PrinceProjectStopped do
			if getgenv().PrinceProjectForceDungeonLoad or isCurrentPositionInCupidDungeonBounds() then
				task.wait(0.25)
				if not getgenv().PrinceProjectStopped then
					AD.startDungeon()
				end
				break
			end
			task.wait(0.25)
		end
	end)
end

notify('Config-only source loaded.')

end -- END MODULE: Cupid

