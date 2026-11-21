-- ############################################################
-- MODULE: Waves  |  Auto Waves Dungeon (Solo / Party)
-- ############################################################
Modules.Waves = function(...)

-- ============================================================
-- PRINCE HUB | AUTO WAVES DUNGEON  (Solo / Party)
--
-- دنجن الأمواج (Universe Hub):
--   * كل 0.5 ثانية يفحص ملف الـ NPCs، إذا اكو NPC يروح له ويقتله.
--   * لما يوصل الموجة المحددة (الافتراضي 25) يسوي Respawn.
--   * الدخول للدنجن يدوي (ماكو auto join حالياً).
--
-- Solo  : يقتل أقرب NPC.
-- Party : نفس الشي، بس يترك الـ NPC اللي زميلك واگف عليه ويروح لغيره.
--
-- ترتيب هذا الموديول:
--   1) CFG            -> أرقام ثابتة تگدر تعدلها
--   2) W              -> الإعدادات اللي تتغير من التبويب + المعلومات
--   3) WEAPONS        -> قراءة الأسلحة من الباكباك + التجهيز
--   4) MOVEMENT       -> الحركة فوق العدو + noclip
--   5) NPC / WAVE     -> فحص الأعداء + قراءة رقم الموجة
--   6) COMBAT         -> الضرب
--   7) MAIN LOOP      -> اللوب الرئيسي
-- ============================================================

if getgenv().PrinceWaves then
	return getgenv().PrinceWaves
end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer         = Players.LocalPlayer

-- ============================================================
-- 1) CFG
-- ============================================================
local CFG = {
	SCAN_INTERVAL       = 0.5,   -- كل كم ثانية يفحص ملف الـ NPCs وهو منتظر
	NPC_FOLDERS         = { "NPCs", "Enemies" },
	MAX_TARGET_DISTANCE = 1500,  -- يتجاهل أي NPC أبعد من هذا
	MAX_TARGETS_PER_HIT = 20,    -- أكثر عدد NPCs بالضربة الوحدة

	-- وين يشتغل: Universe Hub (نفس مكان Cupid). اللوبي = حوالين 20000, 6, 0
	PLACE_IDS           = { [11424731604] = true },
	LOBBY_CENTER        = Vector3.new(20000, 6, 0),
	LOBBY_RADIUS        = 1500,

	COMBO_DELAY         = 0.15,  -- بين كل ضربة وضربة (نفس Cupid)
	COMBO_COOLDOWN      = 1.0,   -- بعد الضربة الخامسة
	HIT_ROTATION_X      = -90,   -- وضعية الشخصية فوق العدو (نفس Cupid)
	ARRIVE_DISTANCE     = 8,     -- لازم يكون بهذا القرب من مكانه فوق العدو حتى يضرب
	INVOKE_TIMEOUT      = 3,

	RESPAWN_GRACE       = 3,     -- ينتظر بعد الرسبون قبل ما يتحرك
	IDLE_DELAY          = 1.0,   -- بعد آخر NPC وقبل ما يرجع للنص
	SWITCH_MARGIN       = 25,    -- ما يبدل الهدف إلا إذا غيره أقرب بهذا الفرق
	STUCK_SECONDS       = 8,     -- يضرب وماكو دمج بهذي المدة => يصغّر مسافة الضرب
	MIN_RADIUS          = 15,
	RADIUS_RESTORE      = 60,    -- بعد ما يصغّر المسافة يجرب يرجّعها بعد هذي المدة
	CHASE_TIMEOUT       = 30,    -- يلحق هدف وما يوصله بهذي المدة => يتركه مؤقتاً
	BLACKLIST_SECONDS   = 20,
	PARTY_CLAIM_RADIUS  = 45,    -- بارتي: زميلك أقرب للـ NPC وبهذي المسافة => اتركه له
	VOID_DROP           = 80,    -- يتجاهل NPC نازل تحت الأرض بهذا المقدار

	HOLD_W_WHILE_MOVING = true,  -- نفس حركة Cupid (W + dash stamina)
	DASH_INTERVAL       = 0.35,
}

-- ============================================================
-- 2) W (public)
-- ============================================================
local W = {
	enabled = false,
	mode = "Solo",          -- "Solo" / "Party"
	status = "Off",
	note = nil,

	-- الإعدادات (تتغير من تبويب Waves)
	weapon = "",            -- "" = تلقائي (السلاح اللي بإيدك / أول سلاح بالباكباك)
	targetWave = 25,
	tweenSpeed = 100,
	hoverHeight = 8.5,
	attackRadius = 100,
	returnToCenter = true,
	autoBuso = true,
	splitTargets = true,

	-- معلومات
	wave = nil,
	npcCount = 0,
	kills = 0,
	runs = 0,
	deaths = 0,
	teammates = 0,
	effectiveRadius = 100,
	lastRunWave = nil,
	lastError = nil,

	CFG = CFG,
}
getgenv().PrinceWaves = W

local S = {
	loopId = 0,
	inArena = false,
	home = nil,     -- وين كنت واگف قبل أول NPC (يرجع له بين الأمواج)
	homeGrounded = false,
	floorY = nil,   -- ارتفاع أرض الساحة (ينعرف لما توگف على الأرض) حتى نتجاهل NPC واگع بالفراغ
	hadTarget = false,
	resting = false,
	idleSince = nil,

	armed = false,
	waveFresh = false,
	lastWave = nil,
	waveHighSince = nil,

	combo = 0,
	nextAttackAt = 0,
	radius = 100,
	radiusBase = nil,

	target = nil,
	targetSince = 0,
	arrivedAt = nil,
	progressAt = 0,
	lastHitCount = 0,
	noDamage = false,
	radiusRestoreAt = nil,
	radiusRestoredAt = nil,
	restoreDelay = nil,
	blacklist = {},
	blackCount = {},
	seen = {},      -- [npc] = آخر Health شفناه
	mates = nil,

	aliveSince = 0,
	lastChar = nil,
	wasDead = false,
	selfRespawn = false,

	busoChar = nil,
	weaponInfo = nil,
	weaponInfoAt = 0,
	equipFailSince = nil,

	move = {
		active = false, npc = nil, npcParent = nil, pos = nil, upright = false,
		lastGoal = nil, lastUpright = false, wDown = false, lastStam = 0, floor = nil,
	},
}

local ZERO = Vector3.new(0, 0, 0)
local HOVER_ROTATION = CFrame.Angles(math.rad(CFG.HIT_ROTATION_X), 0, 0)

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function getCharacter()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		return char
	end
	local pc = workspace:FindFirstChild("PlayerCharacters")
	local folderChar = pc and pc:FindFirstChild(LocalPlayer.Name)
	return folderChar or char
end

local function getRoot()
	local char = getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function xzDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function shortName(name)
	name = tostring(name or "?")
	if #name > 16 then
		return string.sub(name, 1, 16)
	end
	return name
end

local eventCache = {}
local function getEvent(name)
	local cached = eventCache[name]
	if cached and cached.Parent then
		return cached
	end
	local events = ReplicatedStorage:FindFirstChild("Events")
	local remote = events and events:FindFirstChild(name)
	eventCache[name] = remote
	return remote
end

-- ------------------------------------------------------------
-- وين أنا: لوبي / Cupid / ساحة الأمواج
-- ------------------------------------------------------------
local function isLobbyPos(pos)
	return xzDist(pos, CFG.LOBBY_CENTER) <= CFG.LOBBY_RADIUS
end

local function isCupidDungeonPos(pos)
	return pos.Y >= 250
		and pos.X >= -1350 and pos.X <= 950
		and pos.Z >= -5350 and pos.Z <= -2000
end

local function isArenaPos(pos)
	if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
		return false -- NaN
	end
	if math.abs(pos.Y) > 3000 then
		return false
	end
	return not isLobbyPos(pos) and not isCupidDungeonPos(pos)
end

-- ============================================================
-- 3) WEAPONS
-- ============================================================
local SLASH_NAMES = { "Slash1", "Slash2", "Slash3", "GroundSlash4", "GroundSlash5" }
local PUNCH_NAMES = {
	{ "Punch1" },
	{ "Punch2" },
	{ "Punch3" },
	{ "GroundPunch4", "Punch4" },
	{ "GroundPunch5", "Punch5" },
}
local SWORD_SPEEDS = {
	["Katana"]            = { 1.6666666269302368, 1.6666666269302368, 1.6666666269302368, 1.6666666269302368, 2 },
	["Cupid's Battleaxe"] = { 1.5196077823638916, 1.470588207244873, 1.470588207244873, 1.470588207244873, 1.470588207244873 },
	["Cupid's Chakram"]   = { 1.2999999523162842, 1.2999999523162842, 1.2999999523162842, 1.2999999523162842, 1.2999999523162842 },
	["Bisento"]           = { 2.0512821674346924, 1.7948716878890991, 1.846153974533081, 1.5384615659713745, 1.5384615659713745 },
}
local HOTBAR_SLOTS = {
	Zero = "Zero", One = "One", Two = "Two", Three = "Three", Four = "Four",
	Five = "Five", Six = "Six", Seven = "Seven", Eight = "Eight", Nine = "Nine",
}

-- "Kraken Blade (Red)" -> "Kraken Blade"
local function stripVariant(name)
	local s = string.gsub(tostring(name or ""), "%s*%b()", "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

-- أساليب القتال (Melee / BlackLeg / ...) : ReplicatedStorage.CombatAnimations.<الاسم>
local function getStyleFolder(name)
	local folder = ReplicatedStorage:FindFirstChild("CombatAnimations")
	return folder and folder:FindFirstChild(name)
end

-- السيوف : ReplicatedStorage.Modules.SwordHandle.Swords.<الاسم>
-- يرجع (فولدر السيف, هل گدرنا نوصل لفولدر السيوف أصلاً)
local function getSwordFolder(name)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local handle = modules and modules:FindFirstChild("SwordHandle")
	local swords = handle and handle:FindFirstChild("Swords")
	if not swords then
		return nil, false
	end
	return swords:FindFirstChild(name) or swords:FindFirstChild(stripVariant(name)), true
end

-- "Style" = أسلوب قتال، "Sword" = سيف، "Other" = مو سلاح معروف، "Unknown" = ما گدرنا نتأكد
local function weaponKind(name)
	if name == "Melee" or getStyleFolder(name) then
		return "Style"
	end
	local sword, known = getSwordFolder(name)
	if sword then
		return "Sword"
	end
	if known then
		return "Other"
	end
	return "Unknown"
end
W.weaponKind = weaponKind

local KIND_RANK = { Style = 1, Sword = 2, Unknown = 3, Other = 4 }

-- كل الـ Tools اللي بإيدك وبالباكباك (الأسلحة المعروفة أول)
function W.listWeapons()
	local names, seen = {}, {}
	local function add(container)
		if not container then return end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and not seen[tool.Name] then
				seen[tool.Name] = true
				names[#names + 1] = tool.Name
			end
		end
	end
	add(getCharacter())
	add(LocalPlayer:FindFirstChild("Backpack"))

	local rank = {}
	for _, name in ipairs(names) do
		rank[name] = KIND_RANK[weaponKind(name)] or 4
	end
	table.sort(names, function(a, b)
		if rank[a] ~= rank[b] then
			return rank[a] < rank[b]
		end
		return a < b
	end)
	return names
end

-- أنيميشن الضربة رقم i: الاسم المعروف أول، وإذا ماكو فأي اسم ينتهي بالرقم (Kick1, Slash2 ...)
local function findComboAnim(folder, i, candidates)
	for _, animName in ipairs(candidates) do
		local anim = folder:FindFirstChild(animName)
		if anim then
			return anim
		end
	end
	local suffix = tostring(i)
	for _, child in ipairs(folder:GetChildren()) do
		if string.match(child.Name, "^%a+" .. suffix .. "$") then
			return child
		end
	end
	if i == 1 then
		-- بعض الأساليب (مثل BlackLeg) أول ضربة مالتها اسمها Dash
		return folder:FindFirstChild("Dash")
	end
	return nil
end

local function meleeAnims()
	local anims = {}
	local folder = getStyleFolder("Melee")
	if folder then
		for i, candidates in ipairs(PUNCH_NAMES) do
			anims[i] = findComboAnim(folder, i, candidates)
		end
	end
	return anims
end

-- يرجع نوع السلاح + الأنيميشنات اللي تنرسل ويه كل ضربة
local function resolveWeaponInfo(name)
	local info = {
		name = name,
		wType = "Melee",
		anims = {},
		speeds = nil,
		defaultSpeed = 1.75,
		complete = false,
	}

	local style = getStyleFolder(name)
	if name == "Melee" or style then
		-- أسلوب قتال: النوع = اسم الأسلوب نفسه (مثل "BlackLeg")
		info.wType = name
		if style then
			for i, candidates in ipairs(PUNCH_NAMES) do
				info.anims[i] = findComboAnim(style, i, candidates)
			end
		end
	else
		-- أي شي ثاني ينحسب سيف (نفس Cupid)
		info.wType = "Sword"
		local sword = getSwordFolder(name)
		local slashes = sword and sword:FindFirstChild("Slashes")
		if slashes then
			for i, animName in ipairs(SLASH_NAMES) do
				info.anims[i] = findComboAnim(slashes, i, { animName })
			end
		end
		info.speeds = SWORD_SPEEDS[name] or SWORD_SPEEDS[stripVariant(name)]
		if string.find(name, "Kraken Blade", 1, true) then
			info.defaultSpeed = 1.4583332538604736
		end
	end

	local fallback = meleeAnims()
	local complete = true
	for i = 1, 5 do
		if not info.anims[i] then
			complete = false
			info.anims[i] = fallback[i]
		end
	end
	info.complete = complete
	return info
end

local function getWeaponInfo()
	local name = W.weapon
	local info = S.weaponInfo
	local now = tick()
	if info and info.name == name and (info.complete or now - S.weaponInfoAt < 3) then
		return info
	end
	info = resolveWeaponInfo(name)
	S.weaponInfo = info
	S.weaponInfoAt = now
	return info
end

local function findEquipped(name)
	local char = getCharacter()
	local tool = char and char:FindFirstChild(name)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function findHotbarKey(name)
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local gui = pg and pg:FindFirstChild("BackpackGui")
	local hotbar = gui and gui:FindFirstChild("Hotbar")
	if not hotbar then
		return nil
	end
	for _, slot in ipairs(hotbar:GetChildren()) do
		local keyName = HOTBAR_SLOTS[slot.Name]
		if keyName and slot:FindFirstChild(name) then
			return Enum.KeyCode[keyName]
		end
	end
	return nil
end

local function pressKey(keyCode)
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		task.wait(0.06)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
	end)
end

-- اختيار تلقائي: السلاح اللي بإيدك، وإلا أول سلاح معروف بالباكباك
local function autoPickWeapon()
	local char = getCharacter()
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and weaponKind(tool.Name) ~= "Other" then
				return tool.Name
			end
		end
	end
	for _, name in ipairs(W.listWeapons()) do
		if weaponKind(name) ~= "Other" then
			return name
		end
	end
	return nil
end

-- يتأكد إن السلاح المختار بإيدك (يرجع true إذا جاهز)
local function ensureWeapon()
	local name = W.weapon
	if not name or name == "" then
		name = autoPickWeapon()
		if not name then
			return false
		end
		W.weapon = name
	end

	if findEquipped(name) then
		S.equipFailSince = nil
		return true
	end

	local hum = getHumanoid()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(name)
	if tool and tool:IsA("Tool") and hum then
		pcall(function()
			hum:EquipTool(tool)
		end)
		task.wait(0.2)
		if findEquipped(name) then
			S.equipFailSince = nil
			return true
		end

		-- احتياط: اضغط رقم الخانة بالهوتبار
		local key = findHotbarKey(name)
		if key then
			pressKey(key)
			task.wait(0.25)
			if findEquipped(name) then
				S.equipFailSince = nil
				return true
			end
		end
	end

	-- السلاح المختار مو موجود من أكثر من 4 ثواني: جرّب سلاح ثاني
	local now = tick()
	S.equipFailSince = S.equipFailSince or now
	if now - S.equipFailSince > 4 then
		local alt = autoPickWeapon()
		if alt and alt ~= name then
			W.weapon = alt
			S.equipFailSince = nil
		end
	end
	return false
end

-- Buso مرة وحدة بكل حياة: يضغط J بعد 3 ثواني من تجهيز السلاح (نفس Cupid)
local function ensureBuso()
	if not W.autoBuso then
		return
	end
	local char = getCharacter()
	if not char or S.busoChar == char then
		return
	end
	S.busoChar = char
	task.spawn(function()
		task.wait(3)
		if W.enabled and getCharacter() == char then
			pressKey(Enum.KeyCode.J)
		end
	end)
end

-- مكان الـ NPC: من الـ HumanoidRootPart، وإذا مو محمّل (بعيد) ناخذه من realPos
local function getNPCPosition(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position, hrp
	end
	local real = npc:FindFirstChild("realPos")
	if real and real:IsA("CFrameValue") then
		local ok, cf = pcall(function()
			return real.Value
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position, nil
		end
	end
	return nil, nil
end

-- ============================================================
-- 4) MOVEMENT
-- ============================================================
local function setKeyW(down)
	if not CFG.HOLD_W_WHILE_MOVING then
		return
	end
	local m = S.move
	if m.wDown == down then
		return
	end
	m.wDown = down
	pcall(function()
		VirtualInputManager:SendKeyEvent(down, Enum.KeyCode.W, false, game)
	end)
end

local function dashStamina(rp)
	local m = S.move
	local now = tick()
	if now - m.lastStam < CFG.DASH_INTERVAL then
		return
	end
	m.lastStam = now
	local remote = getEvent("takestam")
	if remote then
		pcall(function()
			remote:FireServer(1, "dash", rp.CFrame)
		end)
	end
end

local function setTrackNPC(npc)
	local m = S.move
	if m.npc ~= npc then
		m.npc = npc
		m.npcParent = npc.Parent
	end
	m.pos = nil
	m.active = true
end

local function setTrackPos(pos, upright)
	local m = S.move
	m.npc = nil
	m.npcParent = nil
	m.pos = pos
	m.upright = upright == true
	m.active = true
end

-- يوقف الحركة ويرجع الشخصية طبيعية
local function releaseMovement()
	local m = S.move
	local wasActive = m.active
	m.active = false
	m.npc = nil
	m.npcParent = nil
	m.pos = nil
	m.lastGoal = nil
	setKeyW(false)
	if m.floor then
		pcall(function()
			m.floor:Destroy()
		end)
		m.floor = nil
	end
	if not wasActive then
		return
	end
	pcall(function()
		local hum = getHumanoid()
		local rp = getRoot()
		if hum then
			hum.AutoRotate = true
		end
		if rp and hum and hum.Health > 0 then
			rp.CFrame = CFrame.new(rp.Position)
			rp.AssemblyLinearVelocity = ZERO
			rp.AssemblyAngularVelocity = ZERO
		end
	end)
end

-- الحركة: كل فريم يقرّب الشخصية من مكانها (فوق العدو) بسرعة Tween Speed
RunService.Heartbeat:Connect(function(dt)
	local m = S.move
	if not W.enabled or not m.active then
		return
	end
	local rp = getRoot()
	local hum = getHumanoid()
	if not rp or not hum or hum.Health <= 0 then
		return
	end

	local goal, upright = nil, false
	if m.npc then
		local npcHum = m.npc:FindFirstChildOfClass("Humanoid")
		if npcHum and npcHum.Health > 0 and m.npc.Parent == m.npcParent then
			local p = getNPCPosition(m.npc)
			if p then
				goal = Vector3.new(p.X, p.Y + (tonumber(W.hoverHeight) or 8.5), p.Z)
			end
		end
	elseif m.pos then
		goal = m.pos
		upright = m.upright
	end

	if goal then
		m.lastGoal = goal
		m.lastUpright = upright
	else
		-- العدو مات/اختفى: اثبت بمكانك لحد ما اللوب يختار هدف جديد
		goal = m.lastGoal
		upright = m.lastUpright
	end
	if not goal then
		return
	end

	local cur = rp.Position
	local delta = goal - cur
	local dist = delta.Magnitude
	if dist > 4000 then
		return -- اللعبة نقلتنا (لوبي مثلاً): لا تسحب الشخصية
	end

	local step = (tonumber(W.tweenSpeed) or 100) * math.min(dt or 0.016, 0.05)
	local newPos = goal
	if dist > step and dist > 0.05 then
		newPos = cur + delta.Unit * step
	end

	-- مسافر = واگف عادي + أرضية مخفية تحته + W + dash stamina (نفس حركة Cupid)
	-- واصل   = وضعية القتال فوق العدو
	local travelling = dist > CFG.ARRIVE_DISTANCE
	if upright or travelling then
		rp.CFrame = CFrame.new(newPos)
	else
		rp.CFrame = CFrame.new(newPos) * HOVER_ROTATION
	end
	rp.AssemblyLinearVelocity = ZERO
	rp.AssemblyAngularVelocity = ZERO
	if hum.PlatformStand then
		hum.PlatformStand = false
	end
	if hum.AutoRotate then
		hum.AutoRotate = false
	end

	if travelling then
		local floor = m.floor
		if not (floor and floor.Parent) then
			floor = Instance.new("Part")
			floor.Name = "PrinceWavesFloor"
			floor.Size = Vector3.new(10, 1, 10)
			floor.Transparency = 1
			floor.Anchored = true
			floor.CanCollide = true
			floor.Parent = workspace
			m.floor = floor
		end
		floor.CFrame = CFrame.new(newPos.X, newPos.Y - 3.1, newPos.Z)
		dashStamina(rp)
	elseif m.floor then
		m.floor:Destroy()
		m.floor = nil
	end

	if dist > 14 then
		setKeyW(true)
	elseif dist < 6 then
		setKeyW(false)
	end
end)

-- Noclip بس وهو يتحرك/يقاتل (يرجّع التصادم مثل ما كان لما يوقف)
local noclipState = nil
RunService.Stepped:Connect(function()
	if not W.enabled or not S.move.active then
		if noclipState then
			for part, canCollide in pairs(noclipState.parts) do
				pcall(function()
					if part.Parent then
						part.CanCollide = canCollide
					end
				end)
			end
			noclipState = nil
		end
		return
	end

	local char = getCharacter()
	if not char then
		return
	end
	if not noclipState or noclipState.char ~= char then
		noclipState = { char = char, parts = {}, at = 0 }
	end

	local now = tick()
	if now - noclipState.at >= 2 then
		noclipState.at = now
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") and noclipState.parts[obj] == nil then
				noclipState.parts[obj] = obj.CanCollide
			end
		end
	end
	for part in pairs(noclipState.parts) do
		if part.Parent then
			part.CanCollide = false
		end
	end
end)

-- ============================================================
-- 5) NPC / WAVE
-- ============================================================
local function getNPCID(npc)
	local value = npc:FindFirstChild("NPCID")
	if value then
		return value.Value
	end
	local config = npc:FindFirstChild("Configuration")
	local configValue = config and config:FindFirstChild("NPCID")
	if configValue then
		return configValue.Value
	end
	return npc:GetAttribute("NPCID")
end

-- كل الـ NPCs الحيين (الأقرب أول)
local function scanNPCs(myPos)
	local list = {}
	local minY = S.floorY and (S.floorY - CFG.VOID_DROP) or nil
	for _, folderName in ipairs(CFG.NPC_FOLDERS) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, npc in ipairs(folder:GetChildren()) do
				if npc:IsA("Model") then
					local hum = npc:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						local p, hrp = getNPCPosition(npc)
						if p then
							local dist = xzDist(myPos, p)
							if dist <= CFG.MAX_TARGET_DISTANCE and (not minY or p.Y >= minY) then
								list[#list + 1] = { npc = npc, hrp = hrp, hum = hum, pos = p, dist = dist }
							end
						end
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a.dist < b.dist
	end)
	return list
end

-- يعد القتلى، ويعرف إذا الضرب دا يأثر (Health أي NPC قريب دا ينزل)
local function trackNPCs(list)
	local now = tick()
	local alive = {}
	for _, d in ipairs(list) do
		local health = d.hum.Health
		local before = S.seen[d.npc]
		if before and health < before - 0.001 and d.dist <= S.radius + 10 then
			S.progressAt = now
			S.noDamage = false
		end
		alive[d.npc] = health
	end
	for npc in pairs(S.seen) do
		if alive[npc] == nil then
			W.kills = W.kills + 1
			S.progressAt = now
			S.noDamage = false
		end
	end
	S.seen = alive
end

-- بارتي: أماكن زملائك الحيين اللي وياك بالساحة
local function getTeammates(myPos)
	local result = {}
	local folder = workspace:FindFirstChild("PlayerCharacters")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local char = player.Character
			if not (char and char:FindFirstChild("HumanoidRootPart")) then
				char = (folder and folder:FindFirstChild(player.Name)) or char
			end
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local p = hrp.Position
				if isArenaPos(p) and xzDist(myPos, p) <= CFG.MAX_TARGET_DISTANCE then
					result[#result + 1] = p
				end
			end
		end
	end
	return result
end

-- يختار الهدف: الأقرب، وبالبارتي يفضّل اللي ماكو زميل واگف عليه
local function chooseTarget(list)
	local now = tick()
	local mates = S.mates
	local useSplit = W.mode == "Party" and W.splitTargets and mates ~= nil and #mates > 0
	local current, bestFree, bestAny = nil, nil, nil

	for _, d in ipairs(list) do
		local blockedUntil = S.blacklist[d.npc]
		if blockedUntil and blockedUntil <= now then
			S.blacklist[d.npc] = nil
			blockedUntil = nil
		end
		if not blockedUntil then
			local claimed = false
			if useSplit then
				local p = d.pos
				for _, matePos in ipairs(mates) do
					local mateDist = xzDist(matePos, p)
					if mateDist <= CFG.PARTY_CLAIM_RADIUS and mateDist < d.dist then
						claimed = true
						break
					end
				end
			end
			d.claimed = claimed
			if not bestAny then
				bestAny = d
			end
			if not claimed and not bestFree then
				bestFree = d
			end
			if d.npc == S.target then
				current = d
			end
		end
	end

	-- إذا كلهم متروكين مؤقتاً نرجع للأقرب (أحسن من الوگفة على الأرض بينهم)
	local best = bestFree or bestAny or list[1]
	if current and best and current ~= best then
		-- لا تبدل الهدف إلا إذا الجديد أقرب بفرق واضح
		local currentAllowed = (not current.claimed) or best.claimed
		if currentAllowed and current.dist <= best.dist + CFG.SWITCH_MARGIN then
			return current
		end
	end
	return best
end

-- رقم الموجة من PlayerGui.Matchmake.Wave ("Wave 12")
local waveLabelCache = nil
local lastWaveDeepScan = 0

local function parseWaveLabel(obj)
	if not obj or not obj:IsA("TextLabel") then
		return nil
	end
	local ok, text = pcall(function()
		return obj.Text
	end)
	if not ok or type(text) ~= "string" then
		return nil
	end
	local n = string.match(string.lower(text), "^%s*wave%s*:?%s*(%d+)")
	return n and tonumber(n) or nil
end

local function readWave()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local matchmake = pg and pg:FindFirstChild("Matchmake")
	if not matchmake then
		return nil
	end
	local n = parseWaveLabel(matchmake:FindFirstChild("Wave"))
	if n then
		return n
	end
	if waveLabelCache and waveLabelCache.Parent then
		n = parseWaveLabel(waveLabelCache)
		if n then
			return n
		end
	end
	local now = tick()
	if now - lastWaveDeepScan < 2 then
		return nil
	end
	lastWaveDeepScan = now
	for _, obj in ipairs(matchmake:GetDescendants()) do
		n = parseWaveLabel(obj)
		if n then
			waveLabelCache = obj
			return n
		end
	end
	return nil
end
W.readWave = readWave

-- هل وصلنا موجة الـ Respawn؟
-- armed / waveFresh: حتى رقم قديم باقي من الجولة السابقة ما يسوي Respawn بالغلط.
local function checkWaveTarget()
	local wave = W.wave
	local target = tonumber(W.targetWave) or 25
	if not wave then
		S.waveHighSince = nil
		return false
	end
	if S.lastWave ~= nil and wave ~= S.lastWave then
		S.waveFresh = true
	end
	S.lastWave = wave
	if wave < target then
		S.armed = true
		S.waveHighSince = nil
		return false
	end
	if not (S.armed or S.waveFresh) then
		return false
	end
	S.waveHighSince = S.waveHighSince or tick()
	return tick() - S.waveHighSince >= 1
end

-- ============================================================
-- 6) COMBAT
-- ============================================================
-- ضربة وحدة من الكومبو (نفس باكيت Cupid: swingsfx وبعدها damage)
local function sendHit(combo, hrpList, npcIDs)
	local info = getWeaponInfo()
	local combatRegister = getEvent("CombatRegister")
	if not combatRegister then
		return false
	end

	local done = false
	task.spawn(function()
		pcall(function()
			local anim = info.anims[combo]
			if anim then
				local speed = (info.speeds and info.speeds[combo]) or info.defaultSpeed
				combatRegister:InvokeServer({
					[1] = "swingsfx", [2] = info.wType, [3] = combo, [4] = "Ground",
					[5] = (anim.Name == "Dash"), [6] = anim, [7] = speed, [8] = 1.5,
				})
			end
			local rp = getRoot()
			if not rp then
				return
			end
			local packet = {
				[1] = "damage", [2] = hrpList, [3] = info.wType,
				[4] = { combo, "Ground", info.wType }, [5] = true, [6] = rp.CFrame,
				aircombo = "Ground",
			}
			if #npcIDs > 0 then
				packet.NPCIDs = npcIDs
			end
			combatRegister:InvokeServer(packet)
		end)
		done = true
	end)

	-- لا تعلّق اللوب إذا السيرفر ما رد
	local started = tick()
	while not done and tick() - started < CFG.INVOKE_TIMEOUT do
		task.wait()
	end
	return done
end

local function doRespawn()
	local wave = W.wave
	W.status = "Respawn (wave " .. tostring(wave) .. ")"
	S.armed = false
	S.waveFresh = false
	S.lastWave = nil
	S.waveHighSince = nil
	S.selfRespawn = true
	releaseMovement()

	local dead = false
	for attempt = 1, 3 do
		local hum = getHumanoid()
		if not hum or hum.Health <= 0 then
			dead = true
			break
		end
		pcall(function()
			if attempt == 1 then
				hum.Health = 0
			elseif attempt == 2 then
				hum:ChangeState(Enum.HumanoidStateType.Dead)
			else
				local char = getCharacter()
				if char then
					char:BreakJoints()
				end
			end
		end)
		local started = tick()
		while tick() - started < 1.5 do
			local current = getHumanoid()
			if not current or current.Health <= 0 then
				dead = true
				break
			end
			task.wait(0.1)
		end
		if dead then
			break
		end
	end

	if dead then
		W.runs = W.runs + 1
		W.lastRunWave = wave
	else
		-- ما مات: جرّب مرة ثانية بعد شوية
		S.selfRespawn = false
		S.waveFresh = true
		W.status = "Respawn failed, retrying"
		task.wait(3)
	end
end

-- ============================================================
-- 7) MAIN LOOP
-- ============================================================
local function resetRunState()
	S.home = nil
	S.homeGrounded = false
	S.floorY = nil
	S.hadTarget = false
	S.resting = false
	S.idleSince = nil
	S.armed = false
	S.waveFresh = false
	S.lastWave = nil
	S.waveHighSince = nil
	S.blacklist = {}
	S.blackCount = {}
	S.seen = {}
	S.target = nil
	S.arrivedAt = nil
	S.mates = nil
	S.combo = 0
	S.lastHitCount = 0
	S.noDamage = false
	S.radiusRestoreAt = nil
	S.radiusRestoredAt = nil
	S.restoreDelay = nil
	W.note = nil
end

-- يترك الهدف مؤقتاً (المدة تتضاعف إذا تكرر نفس الهدف)
local function blacklistTarget(npc, now)
	local count = (S.blackCount[npc] or 0) + 1
	S.blackCount[npc] = count
	local seconds = math.min(CFG.BLACKLIST_SECONDS * (2 ^ (count - 1)), 300)
	S.blacklist[npc] = now + seconds
	S.target = nil
	S.arrivedAt = nil
end

local function enterArena(pos)
	resetRunState()
	S.inArena = true
	S.home = pos
	S.radiusBase = W.attackRadius
	S.radius = tonumber(W.attackRadius) or 100
	W.effectiveRadius = S.radius
end

local function leaveArena()
	resetRunState()
	S.inArena = false
	W.npcCount = 0
	W.teammates = 0
	releaseMovement()
end

-- ماكو NPCs: يرجع للنص (إذا مفعّل) وينتظر الموجة الجاية
local function idleTick(rp)
	S.target = nil
	S.combo = 0
	local now = tick()
	S.idleSince = S.idleSince or now

	if S.resting then
		W.status = "Waiting for next wave"
		return
	end
	if now - S.idleSince < CFG.IDLE_DELAY then
		W.status = "Wave clear"
		return
	end
	if W.returnToCenter and S.home and S.hadTarget then
		if (rp.Position - S.home).Magnitude > 4 then
			setTrackPos(S.home, true)
			W.status = "Returning to center"
			return
		end
	end
	releaseMovement()
	S.resting = true
	W.status = "Waiting for next wave"
end

local function fightTick(list, target, rp, now)
	S.idleSince = nil
	S.resting = false
	S.hadTarget = true

	local baseRadius = tonumber(W.attackRadius) or 100
	if S.radiusBase ~= W.attackRadius then
		S.radiusBase = W.attackRadius
		S.radius = baseRadius
		S.radiusRestoreAt = nil
		S.restoreDelay = nil
	end

	if S.target ~= target.npc then
		S.target = target.npc
		S.targetSince = now
		S.arrivedAt = nil
		S.progressAt = now
	end

	setTrackNPC(target.npc)

	if not ensureWeapon() then
		W.status = "No weapon: " .. shortName(W.weapon ~= "" and W.weapon or "?")
		task.wait(0.4)
		return
	end
	ensureBuso()

	local myPos = rp.Position
	local goal = Vector3.new(target.pos.X, target.pos.Y + (tonumber(W.hoverHeight) or 8.5), target.pos.Z)
	local arrived = target.hrp ~= nil and (myPos - goal).Magnitude <= CFG.ARRIVE_DISTANCE

	if not arrived then
		S.arrivedAt = nil
		if now - S.targetSince > CFG.CHASE_TIMEOUT and now - S.progressAt > CFG.CHASE_TIMEOUT then
			blacklistTarget(target.npc, now)
			S.progressAt = now
		end
		W.status = "Going to " .. shortName(target.npc.Name)
		task.wait(0.1)
		return
	end
	S.arrivedAt = S.arrivedAt or now

	-- واصل ويضرب بس ماكو دمج:
	--   إذا الضربة بيها أكثر من NPC => صغّر مسافة الضرب (يمكن السيرفر يرفض البعيدين)
	--   وإلا => اترك هذا الهدف مؤقتاً
	if now - math.max(S.progressAt, S.arrivedAt) > CFG.STUCK_SECONDS then
		if S.lastHitCount > 1 and S.radius > CFG.MIN_RADIUS + 0.5 then
			S.radius = math.max(CFG.MIN_RADIUS, math.floor(S.radius * 0.5))
			if S.radiusRestoredAt and now - S.radiusRestoredAt < 30 then
				S.restoreDelay = math.min((S.restoreDelay or CFG.RADIUS_RESTORE) * 2, 600)
			end
			S.radiusRestoreAt = now + (S.restoreDelay or CFG.RADIUS_RESTORE)
		else
			blacklistTarget(target.npc, now)
			S.noDamage = true
		end
		S.progressAt = now
		S.arrivedAt = now
	elseif S.radius < baseRadius and S.radiusRestoreAt and now >= S.radiusRestoreAt and now - S.progressAt < 2 then
		-- الضرب ماشي: جرّب ترجّع المسافة
		S.radius = math.min(baseRadius, S.radius * 2)
		S.radiusRestoredAt = now
		S.radiusRestoreAt = now + (S.restoreDelay or CFG.RADIUS_RESTORE)
	end
	W.effectiveRadius = S.radius

	if S.noDamage then
		W.note = "No damage: check weapon/hover"
	elseif S.radius < baseRadius then
		W.note = "Hit radius lowered to " .. tostring(S.radius)
	else
		W.note = nil
	end

	W.status = "Fighting " .. shortName(target.npc.Name)
	if now < S.nextAttackAt then
		task.wait(0.05)
		return
	end

	-- كل الـ NPCs اللي ضمن مسافة الضرب (الهدف أولهم)
	local hrpList, npcIDs = { target.hrp }, {}
	local targetID = getNPCID(target.npc)
	if targetID ~= nil then
		npcIDs[1] = targetID
	end
	for _, d in ipairs(list) do
		if #hrpList >= CFG.MAX_TARGETS_PER_HIT then
			break
		end
		if d.npc ~= target.npc and d.hrp and d.dist <= S.radius then
			hrpList[#hrpList + 1] = d.hrp
			local id = getNPCID(d.npc)
			if id ~= nil then
				npcIDs[#npcIDs + 1] = id
			end
		end
	end
	S.lastHitCount = #hrpList

	S.combo = S.combo + 1
	if S.combo > 5 then
		S.combo = 1
	end
	sendHit(S.combo, hrpList, npcIDs)

	if S.combo >= 5 then
		S.combo = 0
		S.nextAttackAt = tick() + CFG.COMBO_COOLDOWN
	else
		task.wait(CFG.COMBO_DELAY)
	end
end

local function step()
	local char = getCharacter()
	local rp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local now = tick()

	-- ميت / ينتظر الرسبون
	if not rp or not hum or hum.Health <= 0 then
		if not S.wasDead then
			S.wasDead = true
			if S.selfRespawn then
				S.selfRespawn = false
			elseif S.inArena then
				W.deaths = W.deaths + 1
			end
			releaseMovement()
		end
		W.status = "Dead / respawning"
		task.wait(0.5)
		return
	end

	if S.wasDead or S.lastChar ~= char then
		S.wasDead = false
		S.selfRespawn = false
		S.lastChar = char
		S.aliveSince = now
		S.combo = 0
		S.nextAttackAt = 0
		S.equipFailSince = nil
	end
	if now - S.aliveSince < CFG.RESPAWN_GRACE then
		W.status = "Spawning..."
		task.wait(0.25)
		return
	end

	local pos = rp.Position
	W.wave = readWave()

	if not (CFG.PLACE_IDS[game.PlaceId] or W.wave ~= nil) then
		if S.inArena then
			leaveArena()
		end
		W.status = "Not in Universe Hub"
		task.wait(1)
		return
	end

	if not isArenaPos(pos) then
		if S.inArena then
			leaveArena()
		end
		W.status = "Lobby: enter the dungeon"
		task.wait(CFG.SCAN_INTERVAL)
		return
	end

	if not S.inArena then
		enterArena(pos)
	end
	if not S.move.active then
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if grounded then
			-- واگف على أرض الساحة: هذا ارتفاع الأرض، ومكان الرجوع بين الأمواج
			if not S.floorY or pos.Y < S.floorY then
				S.floorY = pos.Y
			end
			if not S.hadTarget or not S.homeGrounded then
				S.home = pos
				S.homeGrounded = true
			end
		elseif not S.hadTarget and not S.homeGrounded then
			S.home = pos
		end
	end

	if checkWaveTarget() then
		doRespawn()
		return
	end

	-- فحص ملف الـ NPCs
	local list = scanNPCs(pos)
	W.npcCount = #list
	trackNPCs(list)

	if W.mode == "Party" then
		S.mates = getTeammates(pos)
		W.teammates = #S.mates
	else
		S.mates = nil
		W.teammates = 0
	end

	local target = (#list > 0) and chooseTarget(list) or nil
	if not target then
		idleTick(rp)
		task.wait(CFG.SCAN_INTERVAL)
		return
	end

	fightTick(list, target, rp, now)
end

local function mainLoop(myId)
	while W.enabled and S.loopId == myId do
		local ok, err = pcall(step)
		if not ok then
			W.lastError = tostring(err)
			W.status = "Error (see console)"
			warn("[Prince Waves] " .. tostring(err))
			task.wait(1)
		end
		task.wait()
	end
end

-- mode: "Solo" أو "Party"
function W.start(mode)
	W.mode = (mode == "Party") and "Party" or "Solo"
	if W.enabled then
		return
	end
	releaseMovement()
	W.enabled = true
	S.loopId = S.loopId + 1
	S.inArena = false
	S.wasDead = false
	S.selfRespawn = false
	S.lastChar = getCharacter()
	S.aliveSince = 0
	S.combo = 0
	S.nextAttackAt = 0
	S.equipFailSince = nil
	resetRunState()
	W.status = "Starting..."
	task.spawn(mainLoop, S.loopId)
end

function W.stop()
	if not W.enabled then
		return
	end
	S.loopId = S.loopId + 1
	leaveArena()
	W.enabled = false
	W.status = "Off"
end

return W

end -- END MODULE: Waves

