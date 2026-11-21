Modules.ImpelTest = function(...)
-- ############################################################
-- AUTO IMPEL (TEST)  |  Prince Hub
-- نسخة جديدة مكتوبة من الصفر (مو نسخ من zyph). البيانات (نقاط الطوابق، أسماء الحواجز،
-- شكل باكيت الضرب) مأخوذة من دراسة السكربت الأصلي، أما المنطق والتصميم فجديد:
--
--   [1] Guard / Diagnostics  : كل خطوة تشتغل داخل حماية (xpcall) + سجل أخطاء + فحوصات صحة دورية
--   [2] Context / Remotes    : وصول آمن للشخصية والماب والـ remotes (مع cache وتحقق)
--   [3] Mover                : طيران خطوة بخطوة + ارتفاع آمن لكل طابق + كشف العلگة + تثبيت بالهوا
--   [4] Combat               : اختيار الهدف بالنقاط + بروفايل لكل boss + combo M1 + تتبع القتل
--   [5] Floors               : بيانات الطوابق 1-5 + المرحلة من الحواجز + levers + End zone + الشوب
--   [6] Places               : المين منيو / Universe (queue) / الدنجن / غيرها
--   [7] Watchdog / Recovery  : يصلح المشاكل وحده بالتدريج (إعادة تخطيط -> رفع -> تجاهل هدف -> إيقاف مؤقت -> rejoin)
-- ############################################################

local existing = getgenv().PrinceImpelTest
if existing and existing.__loaded then
	return existing
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local T = {
	__loaded = true,
	version = "test-1",
	enabled = false,
	running = false,
	state = "Idle",
	detail = "",
	place = "?",
	floor = nil,
	stage = nil,
	targetName = nil,
	kills = 0,
	startTick = nil,
	settings = {
		speed = 90, -- سرعة الطيران
		verticalTP = true, -- الصعود والنزول للارتفاع الآمن بـ TP (مثل الأصل) بدل الطيران
		lowHP = 300, -- تحت هذا الدم: يبتعد فوق الموب
		attackRadius = 10,
		targetRange = 400,
		autoQueue = true, -- بالـ Universe: يدخل الطابور وحده
		psCode = "", -- بالمين منيو: كود الـ PS
		leaveOtherPlaces = true, -- بأي مكان ثاني: يرجع للـ Universe
		buyMythical = true, -- بالنهاية: يشتري Mythical Fruit Chest إذا النقاط تكفي
		difficulty = "Nightmare",
		autoRejoinOnStall = false, -- إذا ما صار تقدم لمدة طويلة: rejoin
		stallMinutes = 6,
		floorHeight = { [1] = 2600, [2] = 2800, [3] = 3000, [4] = 1500, [5] = 1500 },
		debug = false,
	},
}
getgenv().PrinceImpelTest = T

local PLACE = {
	[1730877806] = "MainMenu",
	[6360478118] = "Universe",
	[7465136166] = "SecondSea",
	[3978370137] = "FirstSea",
	[11424731604] = "Dungeon",
}
local UNIVERSE_ID = 6360478118

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function finite(v)
	return v ~= nil and v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e7 and math.abs(v.Y) < 1e7 and math.abs(v.Z) < 1e7
end

local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- ============================================================
-- [1] GUARD / DIAGNOSTICS  (نظام المعالجة)
-- ============================================================
local D = {
	logs = {},
	errors = {},
	errorTimes = {},
	errorCount = 0,
	counters = {},
	checks = {},
	checkOrder = {},
	results = {},
	overall = "OK",
	lastProgress = tick(),
	progressKey = nil,
	recoveries = {},
	frameDt = 1 / 60,
}
T.diag = D

local LEVEL_RANK = { OK = 0, WARN = 1, FAIL = 2 }

function D.log(level, msg)
	local entry = { t = tick(), level = level, msg = tostring(msg) }
	table.insert(D.logs, entry)
	if #D.logs > 80 then
		table.remove(D.logs, 1)
	end
	if level == "ERROR" then
		warn("[Auto Impel test] " .. entry.msg)
	elseif T.settings.debug then
		print("[Auto Impel test][" .. level .. "] " .. entry.msg)
	end
end

function D.count(name, n)
	D.counters[name] = (D.counters[name] or 0) + (n or 1)
	return D.counters[name]
end

function D.error(where, err)
	D.errorCount = D.errorCount + 1
	D.count("err:" .. where)
	local msg = tostring(err)
	table.insert(D.errors, { t = tick(), where = where, msg = msg })
	if #D.errors > 30 then
		table.remove(D.errors, 1)
	end
	table.insert(D.errorTimes, tick())
	if #D.errorTimes > 100 then
		table.remove(D.errorTimes, 1)
	end
	D.log("ERROR", where .. ": " .. msg)
end

function D.recentErrors(window)
	local n, now = 0, tick()
	for i = #D.errorTimes, 1, -1 do
		if now - D.errorTimes[i] <= window then
			n = n + 1
		else
			break
		end
	end
	return n
end

-- كل خطوة تمر من هنا: أي خطأ ينمسك ويتسجل، والسكربت يكمل
function D.run(where, fn, ...)
	local ok, a, b, c = xpcall(fn, function(e)
		local tb = ""
		pcall(function()
			tb = debug.traceback("", 2) or ""
		end)
		return tostring(e) .. (tb ~= "" and ("\n" .. tb:sub(1, 400)) or "")
	end, ...)
	if not ok then
		D.error(where, a)
		return false, a
	end
	return true, a, b, c
end

function D.progress(key)
	if key ~= D.progressKey then
		D.progressKey = key
		D.lastProgress = tick()
	end
end

function D.addCheck(name, interval, fn)
	D.checks[name] = { interval = interval, fn = fn, last = 0 }
	table.insert(D.checkOrder, name)
end

function D.runChecks(force)
	local worst = "OK"
	for _, name in ipairs(D.checkOrder) do
		local c = D.checks[name]
		if force or tick() - c.last >= c.interval then
			c.last = tick()
			local ok, st, msg = pcall(c.fn)
			if not ok then
				D.results[name] = { status = "FAIL", msg = "check crashed: " .. tostring(st), t = tick() }
			else
				D.results[name] = { status = st or "OK", msg = msg or "", t = tick() }
			end
		end
		local r = D.results[name]
		if r and (LEVEL_RANK[r.status] or 0) > (LEVEL_RANK[worst] or 0) then
			worst = r.status
		end
	end
	D.overall = worst
	return worst
end

function D.recovery(name, msg)
	D.count("rec:" .. name)
	table.insert(D.recoveries, { t = tick(), name = name, msg = msg })
	if #D.recoveries > 20 then
		table.remove(D.recoveries, 1)
	end
	D.log("WARN", "recovery " .. name .. ": " .. tostring(msg))
end

function D.report()
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	add("=== Auto Impel (test) report  v" .. T.version .. " ===")
	add("state: " .. tostring(T.state) .. "  detail: " .. tostring(T.detail))
	add("place: " .. tostring(T.place) .. "  floor: " .. tostring(T.floor) .. "  stage: " .. tostring(T.stage))
	add("target: " .. tostring(T.targetName) .. "  kills: " .. tostring(T.kills))
	add(string.format("errors: %d total, %d in last 60s   fps ~%d", D.errorCount, D.recentErrors(60), math.floor(1 / math.max(D.frameDt, 1e-3))))
	add(string.format("no progress for: %ds", math.floor(tick() - D.lastProgress)))
	add("-- checks (" .. D.overall .. ")")
	for _, name in ipairs(D.checkOrder) do
		local r = D.results[name]
		if r then
			add(string.format("  [%s] %s: %s", r.status, name, r.msg))
		end
	end
	add("-- counters")
	local keys = {}
	for k in pairs(D.counters) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		add("  " .. k .. " = " .. tostring(D.counters[k]))
	end
	add("-- last errors")
	for i = math.max(1, #D.errors - 5), #D.errors do
		local e = D.errors[i]
		add(string.format("  %.0fs ago  %s: %s", tick() - e.t, e.where, (e.msg:gsub("\n.*", ""))))
	end
	add("-- last recoveries")
	for i = math.max(1, #D.recoveries - 5), #D.recoveries do
		local r = D.recoveries[i]
		add(string.format("  %.0fs ago  %s: %s", tick() - r.t, r.name, tostring(r.msg)))
	end
	return table.concat(lines, "\n")
end

-- ============================================================
-- [2] CONTEXT / REMOTES
-- ============================================================
local C = {}

function C.char()
	local ch = LocalPlayer.Character
	if ch and ch.Parent then
		return ch
	end
	local pc = workspace:FindFirstChild("PlayerCharacters")
	return pc and pc:FindFirstChild(LocalPlayer.Name) or ch
end

function C.hrp()
	local ch = C.char()
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

function C.hum()
	local ch = C.char()
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

function C.alive()
	local h = C.hum()
	return h ~= nil and h.Health > 0 and C.hrp() ~= nil
end

function C.placeName()
	return PLACE[game.PlaceId] or "Other"
end

function C.islands()
	return workspace:FindFirstChild("Islands")
end

function C.island(name)
	local isl = C.islands()
	return isl and isl:FindFirstChild(name)
end

function C.stats()
	return ReplicatedStorage:FindFirstChild("Stats" .. LocalPlayer.Name)
end

function C.statValue(name)
	local s = C.stats()
	local st = s and s:FindFirstChild("Stats")
	local v = st and st:FindFirstChild(name)
	return v and v.Value
end

function C.inventoryCount(itemName)
	local s = C.stats()
	local inv = s and s:FindFirstChild("Inventory") and s.Inventory:FindFirstChild("Inventory")
	if not inv then
		return nil
	end
	local n = tostring(inv.Value):match('"' .. itemName:gsub("%p", "%%%0") .. '":(%d+)')
	return tonumber(n) or 0
end

function C.points()
	local g = LocalPlayer:FindFirstChild("PlayerGui")
	g = g and g:FindFirstChild("BattleReportGui")
	local p = g and g:FindFirstChild("Points")
	return p and tonumber((tostring(p.Text):gsub("%D", ""))) or nil
end

local R = { cache = {} }

function R.get(name)
	local cached = R.cache[name]
	if cached and cached.Parent then
		return cached
	end
	local ev = ReplicatedStorage:FindFirstChild("Events")
	local r = ev and ev:FindFirstChild(name)
	R.cache[name] = r
	return r
end

function R.invoke(name, ...)
	local r = R.get(name)
	if not r then
		D.count("remote_missing:" .. name)
		return false, "missing remote " .. name
	end
	local args = { ... }
	local ok, res = pcall(function()
		return r:InvokeServer(unpack(args))
	end)
	if not ok then
		D.count("remote_fail:" .. name)
		D.log("WARN", "remote " .. name .. " failed: " .. tostring(res))
	end
	return ok, res
end

function R.fire(name, ...)
	local r = R.get(name)
	if not r then
		D.count("remote_missing:" .. name)
		return false
	end
	local args = { ... }
	local ok, res = pcall(function()
		r:FireServer(unpack(args))
	end)
	if not ok then
		D.count("remote_fail:" .. name)
		D.log("WARN", "remote " .. name .. " failed: " .. tostring(res))
	end
	return ok
end

-- ============================================================
-- [3] MOVER
-- ============================================================
local M = { token = 0, moving = false, holdPos = nil, holdLook = nil, stuckStreak = 0, lastResult = nil }
T.mover = M

local function setCF(pos, look)
	local hrp = C.hrp()
	if not hrp or not finite(pos) then
		return false
	end
	if look and finite(look) and (look - pos).Magnitude > 0.1 then
		hrp.CFrame = CFrame.new(pos, look)
	else
		hrp.CFrame = CFrame.new(pos)
	end
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
	return true
end

function M.hold(pos, look)
	M.holdPos = pos
	M.holdLook = look
end

function M.stop()
	M.token = M.token + 1
	M.moving = false
end

function M.tp(pos, look)
	M.token = M.token + 1
	if not setCF(pos, look) then
		return "nochar"
	end
	M.hold(pos, look)
	D.count("tp")
	task.wait(0.12)
	return "arrived"
end

-- طيران مستقيم بخطوات (Heartbeat). يرجع: arrived / aborted / stuck / timeout / nochar
function M.fly(target, speed, look)
	if not finite(target) then
		return "badtarget"
	end
	M.token = M.token + 1
	local my = M.token
	local hrp = C.hrp()
	if not hrp then
		return "nochar"
	end
	speed = math.clamp(tonumber(speed) or T.settings.speed, 10, 500)
	M.moving = true
	local start = tick()
	local last = start
	local dist0 = (target - hrp.Position).Magnitude
	local timeout = dist0 / speed * 2 + 4
	local best, bestAt = dist0, start
	local result
	while true do
		if M.token ~= my then
			result = "aborted"
			break
		end
		if not T.enabled or not C.alive() then
			result = "aborted"
			break
		end
		hrp = C.hrp()
		local now = tick()
		local dt = math.clamp(now - last, 0, 0.1)
		last = now
		local pos = hrp.Position
		local delta = target - pos
		local d = delta.Magnitude
		if d <= math.max(1, speed * dt) then
			setCF(target, look)
			M.hold(target, look)
			result = "arrived"
			break
		end
		local nextPos = pos + delta.Unit * (speed * dt)
		setCF(nextPos, look or target)
		if d < best - 0.5 then
			best, bestAt = d, now
		elseif now - bestAt > 3 then
			result = "stuck"
			break
		end
		if now - start > timeout then
			result = "timeout"
			break
		end
		task.wait()
	end
	if M.token == my then
		M.moving = false
	end
	if result == "stuck" or result == "timeout" then
		M.stuckStreak = M.stuckStreak + 1
		D.count("move_" .. result)
		local p = C.hrp() and C.hrp().Position
		if p then
			M.hold(p)
		end
	elseif result == "arrived" then
		M.stuckStreak = 0
	end
	M.lastResult = result
	return result
end

-- يروح للهدف: إذا بعيد (أو فرق ارتفاع كبير) يصعد للارتفاع الآمن مال الطابق، يعبر، وينزل
function M.goTo(target, opts)
	opts = opts or {}
	local hrp = C.hrp()
	if not hrp then
		return "nochar"
	end
	if not finite(target) then
		D.count("bad_target")
		return "badtarget"
	end
	local from = hrp.Position
	local d = (target - from).Magnitude
	if d <= 6 then
		setCF(target, opts.look)
		M.hold(target, opts.look)
		return "arrived"
	end
	local speed = opts.speed or T.settings.speed
	local safeY = opts.safeY
	local flat = flatDist(from, target)
	if safeY and safeY > math.max(from.Y, target.Y) + 30 and (flat > 150 or math.abs(target.Y - from.Y) > 80) then
		local up = V(from.X, safeY, from.Z)
		local r = T.settings.verticalTP and M.tp(up) or M.fly(up, speed * 2)
		if r ~= "arrived" then
			return r
		end
		r = M.fly(V(target.X, safeY, target.Z), speed)
		if r ~= "arrived" then
			return r
		end
		if T.settings.verticalTP then
			return M.tp(target, opts.look)
		end
		return M.fly(target, speed * 2, opts.look)
	end
	return M.fly(target, speed, opts.look)
end

-- noclip + تثبيت بالهوا (حتى ما يطيح وهو واقف يقاتل أو ينتظر)
local function startMoverLoops()
	if M.loopsStarted then
		return
	end
	M.loopsStarted = true
	local cachedChar, cachedParts, cachedAt = nil, {}, 0
	RunService.Stepped:Connect(function()
		if not T.enabled then
			return
		end
		local ch = C.char()
		if not ch then
			return
		end
		if ch ~= cachedChar or tick() - cachedAt > 2 then
			cachedChar, cachedParts, cachedAt = ch, {}, tick()
			for _, p in ipairs(ch:GetDescendants()) do
				if p:IsA("BasePart") then
					cachedParts[#cachedParts + 1] = p
				end
			end
		end
		for _, p in ipairs(cachedParts) do
			if p.Parent and p.CanCollide then
				p.CanCollide = false
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if type(dt) == "number" and dt > 0 then
			D.frameDt = D.frameDt * 0.95 + dt * 0.05
		end
		if not T.enabled or M.moving or not M.holdPos then
			return
		end
		local hrp = C.hrp()
		if not hrp or not C.alive() then
			return
		end
		local drift = (hrp.Position - M.holdPos).Magnitude
		if drift > 30 then
			-- قفزة كبيرة احنا ما سويناها = اللعبة نقلت اللاعب (طابق جديد / نهاية الدنجن): نقبل المكان الجديد
			M.holdPos = hrp.Position
			M.holdLook = nil
			D.count("external_teleport")
		elseif drift > 0.05 then
			setCF(M.holdPos, M.holdLook)
		else
			pcall(function()
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
		end
	end)
end

-- ============================================================
-- [4] COMBAT
-- ============================================================
local K = {
	combo = 0,
	lastSwing = 0,
	cd = 0,
	lastHitAt = 0,
	lastBuso = 0,
	lastEquip = 0,
	blacklist = {},
	target = nil,
	targetSince = 0,
	targetHP0 = nil,
}
T.combat = K

local WEAPON_PRIORITY = {
	{ "Dark Blade", 1100 },
	{ "Hollow's Great Sword", 1000 },
	{ "Kraken Blade", 100 },
	{ "Vrael's Pipe", 90 },
}
local IGNORE_NPC = { Scorpion = true, Basilisk = true }

-- بروفايل القتال لكل NPC (offset فوق/ورا الموب + مسافة الضربة)
local PROFILES = {
	["Kramprus"] = { offset = V(0, 6, 3), radius = 15 },
	["Elo The Bunny"] = { offset = V(0, 10, 6), radius = 20 },
	["Kelvin, The Nutcracker"] = { offset = V(0, 10, 3), radius = 15 },
	["Demon Jester"] = { offset = V(0, 8, 3), radius = 10 },
	["Cupid Queen"] = { offset = V(0, 8, 0), radius = 10 },
	["Mini Bunny"] = { offset = V(0, 7, 0), radius = 10 },
	["Blugori"] = { offset = V(0, 0, 15), radius = 40 },
	["Vera"] = { offset = V(0, 5, 4), radius = 20 },
}

function K.realName(npc)
	local rn
	pcall(function()
		rn = npc:GetAttribute("RealName")
	end)
	return rn or npc.Name
end

function K.alive(npc)
	if not npc or not npc.Parent then
		return false
	end
	local h = npc:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0 and npc:FindFirstChild("HumanoidRootPart") ~= nil
end

function K.isBoss(npc)
	local scaled = false
	pcall(function()
		scaled = npc:GetAttribute("HPScaled") == true
	end)
	return scaled or npc:FindFirstChild("Boss") ~= nil
end

function K.profile(npc)
	local p = PROFILES[K.realName(npc)]
	if p then
		return p
	end
	if npc:FindFirstChild("RaiuiSword") then
		return { offset = V(0, 7, 3), radius = 15 }
	end
	if K.isBoss(npc) then
		return { offset = V(0, 7, 3), radius = T.settings.attackRadius }
	end
	return { offset = V(0, 6, 3), radius = T.settings.attackRadius }
end

function K.npcs()
	local f = workspace:FindFirstChild("NPCs")
	return f and f:GetChildren() or {}
end

function K.hostilesNear(pos, radius)
	local n = 0
	for _, npc in ipairs(K.npcs()) do
		if K.alive(npc) and K.realName(npc) ~= "Mini Bunny" and not IGNORE_NPC[K.realName(npc)] then
			if (npc.HumanoidRootPart.Position - pos).Magnitude <= radius then
				n = n + 1
			end
		end
	end
	return n
end

local function inRedZone(pos)
	local rz = workspace:FindFirstChild("RedZone")
	if not rz or not rz:IsA("BasePart") then
		return false
	end
	local half = rz.Size / 2
	return math.abs(pos.X - rz.Position.X) <= half.X and math.abs(pos.Z - rz.Position.Z) <= half.Z
end

-- اختيار الهدف بالنقاط: Vera (الطابق 5) > Kelvin > boss > devil fruit > logia > الأقرب
function K.pickTarget(floorN)
	local hrp = C.hrp()
	if not hrp then
		return nil
	end
	local me = hrp.Position
	local best, bestScore = nil, -math.huge
	local now = tick()
	for _, npc in ipairs(K.npcs()) do
		if K.alive(npc) then
			local name = K.realName(npc)
			local black = K.blacklist[npc]
			if not IGNORE_NPC[name] and not (black and black > now) then
				local pos = npc.HumanoidRootPart.Position
				local dist = (pos - me).Magnitude
				local boss = K.isBoss(npc)
				local range = boss and math.max(T.settings.targetRange, 600) or T.settings.targetRange
				if dist <= range and not (floorN == 1 and inRedZone(pos)) then
					local prio = 1
					if name == "Warden of Impel Down, Vera" and floorN == 5 then
						prio = 6
					elseif name == "Kelvin, The Nutcracker" then
						prio = 5
					elseif boss then
						prio = 4
					elseif npc:FindFirstChild("Info") and npc.Info:FindFirstChild("DevilFruit") then
						prio = 3
					elseif npc:FindFirstChild("Logia") or npc:FindFirstChild("logia") then
						prio = 2
					end
					-- نفس الهدف الحالي ياخذ أفضلية حتى ما يتنقل بين الموبات
					local sticky = (npc == K.target) and 150 or 0
					local score = prio * 10000 - dist + sticky
					if score > bestScore then
						best, bestScore = npc, score
					end
				end
			end
		end
	end
	return best
end

function K.equip()
	local ch, hum = C.char(), C.hum()
	local bp = LocalPlayer:FindFirstChild("Backpack")
	if not ch or not hum then
		return "Melee"
	end
	local function match(tool, name)
		return tool.Name == name or string.find(tool.Name, name, 1, true) ~= nil
	end
	local bestTool, bestPrio = nil, 0
	local function scan(container)
		if not container then
			return
		end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				for _, wp in ipairs(WEAPON_PRIORITY) do
					if match(tool, wp[1]) and wp[2] > bestPrio then
						bestTool, bestPrio = tool, wp[2]
					end
				end
			end
		end
	end
	scan(bp)
	scan(ch)
	local wantType = bestTool and "Sword" or "Melee"
	if not bestTool then
		bestTool = (bp and bp:FindFirstChild("Melee")) or ch:FindFirstChild("Melee")
	end
	if not bestTool then
		D.count("no_weapon")
		return "Melee"
	end
	if bestTool.Parent ~= ch and tick() - K.lastEquip > 0.5 then
		K.lastEquip = tick()
		pcall(function()
			hum:EquipTool(bestTool)
		end)
		D.count("equip")
	end
	return wantType
end

function K.buso()
	local mastery = C.statValue("BusoMastery")
	if not mastery or mastery == 0 then
		return
	end
	local ch = C.char()
	if ch and not ch:FindFirstChild("BusoMelee") and tick() - K.lastBuso > 3 then
		K.lastBuso = tick()
		R.fire("Haki", "Buso")
	end
end

-- يتابع الهدف: يحسب القتل، ويكشف الهدف اللي ما ينضرب (stale) ويتجاهله فترة
function K.track(npc)
	local now = tick()
	if K.target and K.target ~= npc then
		if not K.alive(K.target) then
			T.kills = T.kills + 1
			D.count("kills")
			D.progress("kill:" .. T.kills)
		end
	end
	if K.target ~= npc then
		K.target = npc
		K.targetSince = now
		local h = npc and npc:FindFirstChildOfClass("Humanoid")
		K.targetHP0 = h and h.Health or nil
	end
	T.targetName = npc and K.realName(npc) or nil
	if npc then
		local h = npc:FindFirstChildOfClass("Humanoid")
		if h and K.targetHP0 and h.Health < K.targetHP0 - 0.5 then
			K.targetHP0 = h.Health
			K.targetSince = now
			D.progress("dmg:" .. tostring(npc) .. ":" .. math.floor(h.Health))
		elseif now - K.targetSince > 30 then
			K.blacklist[npc] = now + 45
			D.recovery("stale_target", K.realName(npc) .. " took no damage for 30s -> ignored 45s")
			K.target = nil
		end
	end
end

function K.swing(npc, radius)
	local now = tick()
	if now - K.lastSwing < K.cd then
		return "cooldown"
	end
	local hrp = C.hrp()
	local nh = npc:FindFirstChild("HumanoidRootPart")
	if not hrp or not nh then
		return "nochar"
	end
	local m1type = K.equip()
	K.buso()
	local hit = {}
	if (hrp.Position - nh.Position).Magnitude < radius then
		hit[#hit + 1] = nh
	end
	for _, other in ipairs(K.npcs()) do
		if other ~= npc and K.alive(other) and (other.HumanoidRootPart.Position - hrp.Position).Magnitude < radius then
			hit[#hit + 1] = other.HumanoidRootPart
		end
	end
	if #hit == 0 then
		D.count("swing_out_of_range")
		return "out_of_range"
	end
	if K.isBoss(npc) and npc:FindFirstChild("Blocking") then
		return "target_blocking"
	end
	if now - K.lastSwing > 2 then
		K.combo = 0
	end
	K.combo = K.combo + 1
	K.lastSwing = now
	local anim
	pcall(function()
		anim = ReplicatedStorage.CombatAnimations.Melee.Punch1
	end)
	R.invoke("CombatRegister", { "swingsfx", m1type, K.combo, "Ground", false, anim, 2, 2 })
	R.invoke("CombatRegister", {
		"damage",
		hit,
		m1type,
		{ K.combo, "Ground", m1type },
		true,
		CFrame.new(),
		aircombo = "Ground",
	})
	if K.combo >= 5 then
		K.combo = 0
		K.cd = 1.5
	else
		K.cd = 0.4
	end
	K.lastHitAt = now
	D.count("swings")
	if not K.alive(npc) then
		K.track(nil) -- مات بهاي الضربة: يتحسب القتل هسه
	end
	return "hit"
end

-- خطوة قتال وحدة: يتمركز فوق/ورا الموب ويضرب
function K.fight(npc, safeY)
	K.track(npc)
	if not K.target then
		return "dropped"
	end
	local nh = npc.HumanoidRootPart
	local hum = C.hum()
	local me = C.hrp()
	if not hum or not me then
		return "nochar"
	end
	local prof = K.profile(npc)
	if hum.Health < T.settings.lowHP then
		T.detail = "low HP: waiting above " .. K.realName(npc)
		M.goTo(nh.Position + V(0, 80, 0))
		return "retreat"
	end
	if C.char():FindFirstChild("Stun") then
		M.tp(nh.Position + V(0, 20, 0))
		return "stunned"
	end
	local desired = (nh.CFrame * CFrame.new(prof.offset.X, prof.offset.Y, prof.offset.Z)).Position
	if not finite(desired) then
		desired = nh.Position + V(0, 8, 0)
	end
	local d = (desired - me.Position).Magnitude
	if d > 6 then
		local r = M.goTo(desired, { safeY = (d > 150) and safeY or nil, look = nh.Position })
		if r ~= "arrived" then
			return r
		end
	else
		setCF(desired, nh.Position)
		M.hold(desired, nh.Position)
	end
	return K.swing(npc, prof.radius)
end

-- ============================================================
-- [5] FLOORS (بيانات)
-- ============================================================
local FLOORS = {
	[1] = {
		island = "Impel Base - Floor 1",
		route = { V(2951.299, 2075.445, -13815.629), V(2952.393, 2075.694, -13970.339) },
		stageBarriers = { "FirstBarrier" },
		routeIgnoreBarriers = true, -- الحاجز هنا يفتح المتاهة بس، النقطتين لازم ينزارن كلهن
		maze = {
			center = V(2674.464, 2075.445, -15478.549),
			exit1 = V(2674.897, 2075.271, -15479.060),
			exit2 = V(2674.464, 2085.445, -15538.549),
		},
	},
	[2] = {
		island = "Impel Base - Floor 2",
		route = {
			V(3210.583, 2380.431, -20259.123),
			V(3202.208, 2378.431, -20372.174),
			V(3433.396, 2378.431, -20397.320),
			V(3450.820, 2378.431, -20590.789),
			V(3199.311, 2343.738, -20533.364), -- lever
			V(3203.501, 2428.431, -20376.191),
			V(3198.931, 2378.381, -20566.570),
			V(3206.496, 2396.689, -20827.055),
			V(3199.434, 2378.381, -21072.609),
			V(3202.123, 2372.406, -20873.867),
		},
		stageBarriers = { "FirstBarrier", "MiddleBarrierRight", "RightFirstBarrier", "RightSecondBarrier" },
		levers = { [5] = { "Interactables", "BossGateLever", "Lever", "Meshes/Lev_Cube.004" } },
	},
	[3] = {
		island = "Impel Base - Floor 3",
		notifications = true,
		route = {
			V(4964.246, 2306.330, -20738.205),
			V(4805.387, 2306.330, -20756.287),
			V(4699.151, 2306.256, -20721.975),
			V(5099.945, 2306.330, -20780.996),
			V(5163.779, 2306.256, -20800.955),
			V(4983.416, 2306.330, -20861.434),
			V(4948.267, 2332.930, -20912.629),
			V(4858.270, 2368.330, -20999.174),
			V(4799.828, 2398.831, -20797.910),
			V(5148.434, 2398.130, -20800.434),
			V(5546.732, 2405.830, -20818.848),
			V(5593.460, 2499.830, -20967.906),
			V(5654.667, 2481.717, -20514.549),
			V(5665.250, 2482.330, -20251.170),
		},
		levers = {
			[3] = { "Interactables", "LeftAreaLever", "Lever", "Meshes/Lev_Cube.004" },
			[5] = { "Interactables", "RightAreaLever", "Lever", "Meshes/Lev_Cube.004" },
		},
	},
	[4] = {
		island = "Impel Base - Floor 4",
		route = {
			V(9993.813, 1616.554, -19118.842),
			V(9994.897, 1668.554, -19596.223),
			V(9739.063, 1668.554, -19747.475),
			V(9669.462, 1669.539, -20239.865),
			V(10124.128, 1669.175, -20304.375),
			V(10744.010, 1668.554, -20347.998),
			V(10957.755, 1668.554, -20534.695),
			V(10938.660, 1669.180, -20947.975),
			V(10566.386, 1658.665, -20986.961),
			V(9995.662, 1658.554, -21019.479),
			V(9978.057, 1694.553, -21877.172),
			V(9975.516, 1665.553, -22142.986),
		},
		stageBarriers = {
			"FirstBarrier",
			"SecondBarrier",
			"ThirdBarrier",
			"SixthBarrier",
			"SeventhBarrier",
			"SeventhBarrier2",
			"EighthBarrier1",
			"EighthBarrier2",
			"NinthZone",
		},
	},
	[5] = {
		island = "Impel Base - Floor 5",
		route = {
			V(10605.055, 542.720, -27458.152),
			V(10594.202, 490.720, -28463.830),
			V(10138.694, 459.916, -28431.334),
			V(9677.078, 512.720, -28457.684),
			V(9638.523, 451.819, -27622.115),
		},
		stageBarriers = { "Barrier2", "Barrier4", "Barrier5", "Barrier6", "Barrier7" },
		dwell = 4,
		clearRadius = 150,
	},
}
local FINISHED_ISLAND = "Impel Base - Finished"
local FINISHED_EXIT = V(6395.693, 653.778, -27926.844)
T.FLOORS = FLOORS

local F = { state = {}, visitedNotif = {} }

function F.detect()
	if C.island(FINISHED_ISLAND) then
		return "Finished"
	end
	for n = 5, 1, -1 do
		if C.island(FLOORS[n].island) then
			return n
		end
	end
	if C.island("Lobby") or C.island("Impel Base") then
		return "Lobby"
	end
	return nil
end

function F.safeY(n)
	local h = T.settings.floorHeight and T.settings.floorHeight[n]
	return tonumber(h) or 2600
end

local function barrierPresent(barriers, name)
	local b = barriers:FindFirstChild(name)
	if not b then
		return false
	end
	local tr = 0
	pcall(function()
		tr = tonumber(b.Transparency) or 0
	end)
	if b:IsA("BasePart") and tr >= 1 then
		return false -- حاجز شفاف بالكامل = مفتوح (مثل EighthBarrier1)
	end
	return true
end

-- المرحلة من الحواجز: أول حاجز بعده موجود = النقطة اللي لازم يخلصها
function F.barrierStage(n)
	local cfg = FLOORS[n]
	if not cfg.stageBarriers then
		return nil
	end
	local model = C.island(cfg.island)
	local barriers = model and model:FindFirstChild("Barriers")
	if not barriers then
		return nil
	end
	for i, name in ipairs(cfg.stageBarriers) do
		if barrierPresent(barriers, name) then
			return i
		end
	end
	return #cfg.stageBarriers + 1
end

local function findPath(root, path)
	local cur = root
	for _, name in ipairs(path) do
		cur = cur and cur:FindFirstChild(name)
	end
	return cur
end

function F.firePrompt(prompt)
	if not prompt or not prompt.Parent then
		return false
	end
	local ok = false
	pcall(function()
		prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 0, 15)
	end)
	if type(fireproximityprompt) == "function" then
		ok = pcall(fireproximityprompt, prompt)
	end
	if not ok then
		ok = pcall(function()
			prompt:InputHoldBegin()
			task.wait((tonumber(prompt.HoldDuration) or 0) + 0.3)
			prompt:InputHoldEnd()
		end)
	end
	D.count(ok and "prompt_fired" or "prompt_fail")
	return ok
end

local function promptPos(prompt)
	local p = prompt.Parent
	if not p then
		return nil
	end
	if p:IsA("BasePart") then
		return p.Position
	end
	if p:IsA("Attachment") then
		return p.WorldPosition
	end
	local ok, pv = pcall(function()
		return p:GetPivot().Position
	end)
	return ok and pv or nil
end

-- يسحب lever: يروح جنبه ويضغط
function F.useLever(n, path)
	local model = C.island(FLOORS[n].island)
	local part = model and findPath(model, path)
	local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt or not prompt.Enabled then
		return "done"
	end
	local pos = promptPos(prompt)
	if not pos then
		return "done"
	end
	local hrp = C.hrp()
	if (hrp.Position - pos).Magnitude > 8 then
		M.goTo(pos + V(0, 3, 0), { safeY = F.safeY(n), look = pos })
	end
	T.detail = "pulling lever"
	F.firePrompt(prompt)
	D.progress("lever:" .. n .. ":" .. table.concat(path, "/"))
	task.wait(0.6)
	return "pulled"
end

function F.endZone()
	local eff = workspace:FindFirstChild("Effects")
	local zones = eff and eff:FindFirstChild("Zones")
	local e = zones and zones:FindFirstChild("End")
	if e and e:FindFirstChild("BillboardGui") then
		if e:IsA("BasePart") then
			return e.Position
		end
		local ok, pv = pcall(function()
			return e:GetPivot().Position
		end)
		return ok and pv or nil
	end
	return nil
end

-- علامات الطابق 3 (NotificationTick) = المكان الجاي
function F.notification()
	local hrp = C.hrp()
	if not hrp then
		return nil
	end
	local best, bestD = nil, math.huge
	local now = tick()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Sound") and d.Name == "NotificationTick" then
			local att = d.Parent
			if att and att:IsA("Attachment") and not ((F.visitedNotif[att] or 0) > now) then
				local dist = (att.WorldPosition - hrp.Position).Magnitude
				if dist < bestD then
					best, bestD = att, dist
				end
			end
		end
	end
	if not best then
		return nil
	end
	local pos = best.WorldPosition
	if (pos - V(4932.19, 2380.067, -20928.676)).Magnitude < 5 then
		pos = V(4983.416, 2306.330, -20861.434) -- العلامة فوق الحايط: المكان الصحيح تحتها
	end
	return pos, best
end

function F.routeStep(n)
	local cfg = FLOORS[n]
	local st = F.state[n]
	if not st then
		st = { idx = 1, arrivedAt = nil }
		F.state[n] = st
	end
	local b = (not cfg.routeIgnoreBarriers) and F.barrierStage(n) or nil
	if b then
		if b <= #cfg.stageBarriers then
			st.idx = b -- الحاجز بعده موجود: نفس النقطة
		elseif st.idx < b then
			st.idx = b
		end
	end
	T.stage = st.idx .. "/" .. #cfg.route
	D.progress("route:" .. n .. ":" .. st.idx)
	if st.idx > #cfg.route then
		local e = F.endZone()
		if e then
			T.detail = "going to End zone"
			M.goTo(e, { safeY = F.safeY(n) })
			task.wait(1)
			return "end"
		end
		T.detail = "route done: waiting for boss / next floor"
		return "wait"
	end
	local p = cfg.route[st.idx]
	local hrp = C.hrp()
	if (hrp.Position - p).Magnitude > 5 then
		T.detail = "moving to point " .. st.idx
		local r = M.goTo(p, { safeY = F.safeY(n) })
		if r ~= "arrived" then
			D.log("WARN", "route " .. n .. ":" .. st.idx .. " move " .. tostring(r))
		end
		return r
	end
	local lever = cfg.levers and cfg.levers[st.idx]
	if lever and F.useLever(n, lever) == "pulled" then
		return "lever"
	end
	if K.hostilesNear(hrp.Position, cfg.clearRadius or 100) > 0 then
		st.arrivedAt = nil
		T.detail = "clearing enemies at point " .. st.idx
		return "enemies"
	end
	if b and b <= #cfg.stageBarriers and st.idx == b then
		T.detail = "waiting for barrier " .. tostring(cfg.stageBarriers[b]) .. " to open"
		return "barrier"
	end
	st.arrivedAt = st.arrivedAt or tick()
	if tick() - st.arrivedAt >= (cfg.dwell or 1.5) then
		st.idx = st.idx + 1
		st.arrivedAt = nil
		D.progress("route:" .. n .. ":" .. st.idx)
	end
	return "waiting"
end

function F.floor1()
	local ch = C.char()
	-- 1) الكلبشة: ياخذ المفتاح
	if ch:FindFirstChild("Cuffed") then
		local eff = workspace:FindFirstChild("Effects")
		local key = eff and eff:FindFirstChild("Key") and eff.Key:FindFirstChild("Key")
		if key then
			T.detail = "taking the key"
			local stand = key.Position + V(5, 0, 0)
			pcall(function()
				stand = key.Position + key.CFrame.RightVector * 5
			end)
			if (C.hrp().Position - stand).Magnitude > 4 then
				M.goTo(stand, { look = key.Position, speed = 40 })
			end
			local prompt = key:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				F.firePrompt(prompt)
			end
			pcall(function()
				workspace:SetAttribute("HandCuffed", true)
			end)
			D.progress("key")
			task.wait(0.3)
			return "key"
		end
		T.detail = "cuffed: waiting for the key"
		return "wait"
	end
	-- 2) الحاجز الأول: نقطتين وقتال الحراس
	local b = F.barrierStage(1)
	if b and b <= 1 then
		return F.routeStep(1)
	end
	-- 3) المتاهة: مركزها، وبعدين المخرج
	local mz = FLOORS[1].maze
	local hrp = C.hrp()
	T.stage = "maze"
	if flatDist(hrp.Position, mz.center) > 20 and not F.state.mazeExit then
		T.detail = "going to the maze"
		M.goTo(mz.center, { safeY = F.safeY(1) })
		return "maze"
	end
	if K.hostilesNear(mz.center, 200) > 0 then
		T.detail = "maze: clearing enemies"
		return "enemies"
	end
	F.state.mazeExit = true
	T.detail = "maze exit"
	if M.goTo(mz.exit1, { safeY = F.safeY(1) }) == "arrived" then
		M.goTo(mz.exit2)
		D.progress("maze_exit")
		task.wait(1)
	end
	return "exit"
end

function F.floor3()
	local hrp = C.hrp()
	-- levers مفعلة بالطابق: إذا قريبة (أو ماكو شي ثاني) يسحبها
	local model = C.island(FLOORS[3].island)
	local inter = model and model:FindFirstChild("Interactables")
	if inter then
		for _, it in ipairs(inter:GetChildren()) do
			local part = findPath(it, { "Lever", "Meshes/Lev_Cube.004" })
			local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
			if prompt and prompt.Enabled and (part.Position - hrp.Position).Magnitude <= 40 then
				return F.useLever(3, { "Interactables", it.Name, "Lever", "Meshes/Lev_Cube.004" })
			end
		end
	end
	local pos, att = F.notification()
	if pos then
		T.stage = "marker"
		D.progress("notif:" .. math.floor(pos.X) .. ":" .. math.floor(pos.Z))
		if (hrp.Position - pos).Magnitude > 6 then
			T.detail = "going to the marker"
			M.goTo(pos, { safeY = F.safeY(3) })
		elseif K.hostilesNear(hrp.Position, 300) == 0 then
			F.visitedNotif[att] = tick() + 20
			T.detail = "marker cleared"
		end
		return "marker"
	end
	return F.routeStep(3)
end

function F.finished()
	local st = F.state.finished
	if not st then
		st = { since = tick(), opened = false }
		F.state.finished = st
		M.stop()
	end
	T.stage = "shop"
	if tick() - st.since < 10 then
		T.detail = "dungeon done: waiting"
		return "wait"
	end
	local model = C.island(FINISHED_ISLAND)
	local chest = model and model:FindFirstChild("Models") and model.Models:FindFirstChild("Mythical Fruit Chest")
	if T.settings.buyMythical and chest and not st.opened then
		local owned = C.inventoryCount("Mythical Fruit Chest") or 0
		local prompt = nil
		for _, d in ipairs(chest:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompt = d
				break
			end
		end
		local cost = prompt and tonumber(tostring(prompt.ActionText):match("(%d+) IMPEL POINTS"))
		local pts = C.points()
		if owned >= 10 then
			D.log("INFO", "mythical cap reached (" .. owned .. ")")
			st.opened = true
		elseif prompt and cost and pts and pts >= cost then
			T.detail = "buying Mythical Fruit Chest (" .. cost .. " pts)"
			local pos = promptPos(prompt) or chest:GetPivot().Position
			M.goTo(pos + V(0, 3, 0), { look = pos })
			task.wait(0.5)
			F.firePrompt(prompt)
			D.count("mythical_bought")
			st.opened = true
			D.progress("mythical")
			return "buy"
		else
			D.log("INFO", "not enough points for mythical (" .. tostring(pts) .. "/" .. tostring(cost) .. ")")
			st.opened = true
		end
	end
	T.detail = "at the exit"
	if (C.hrp().Position - FINISHED_EXIT).Magnitude > 6 then
		M.goTo(FINISHED_EXIT)
	end
	D.progress("finished_exit")
	task.wait(2)
	return "exit"
end

function F.lobby()
	local npcs = workspace:FindFirstChild("NPCs")
	local vera = npcs and npcs:FindFirstChild("Vera")
	if vera and K.alive(vera) and not workspace:GetAttribute("HandCuffed") then
		T.stage = "tutorial"
		T.detail = "tutorial: Vera"
		return K.fight(vera, nil)
	end
	T.stage = "lobby"
	T.detail = "lobby: waiting"
	return "wait"
end

-- اختيار الصعوبة لما تطلع واجهة DiffChooser
local function selectDifficulty(gui)
	local ok = pcall(function()
		local btn = gui:FindFirstChild("Frame")
			and gui.Frame:FindFirstChild("ScrollingFrame")
			and gui.Frame.ScrollingFrame:FindFirstChild(T.settings.difficulty)
		if not btn then
			return
		end
		if type(getconnections) == "function" then
			for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }) do
				local s = btn[sig]
				for _, conn in ipairs(getconnections(s)) do
					pcall(conn.Function)
				end
			end
		end
		D.count("difficulty_selected")
	end)
	if not ok then
		D.count("difficulty_fail")
	end
end

-- ============================================================
-- [6] PLACES
-- ============================================================
local P = { lastQueue = 0, lastMenu = 0, lastLeave = 0 }

function P.dungeon()
	local n = F.detect()
	T.floor = n
	if n == nil then
		T.state = "Loading"
		T.detail = "waiting for the map"
		return
	end
	if n ~= F.lastFloor then
		F.lastFloor = n
		D.log("INFO", "floor -> " .. tostring(n))
		D.progress("floor:" .. tostring(n))
		M.stop()
		M.holdPos = nil
		K.target = nil
		T.stage = nil
	end
	if n == "Finished" then
		T.state = "Finished"
		return F.finished()
	end
	if n == "Lobby" then
		T.state = "Lobby"
		return F.lobby()
	end
	-- القتال أولاً (إلا إذا مكلبش)
	if not C.char():FindFirstChild("Cuffed") then
		local target = K.pickTarget(n)
		if target then
			T.state = "Fighting"
			T.detail = K.realName(target)
			return K.fight(target, F.safeY(n))
		end
	end
	K.track(nil)
	T.state = "Floor " .. n
	if n == 1 then
		return F.floor1()
	elseif n == 3 then
		return F.floor3()
	end
	return F.routeStep(n)
end

function P.universe()
	T.state = "Universe"
	if not T.settings.autoQueue then
		T.detail = "auto queue OFF"
		return
	end
	if tick() - P.lastQueue >= 3 then
		P.lastQueue = tick()
		T.detail = "queueing Impel Down"
		local n = D.count("queue_attempts")
		R.invoke("Queue", "ImpelDown")
		D.progress("queue:" .. math.floor(n / 20)) -- محاولات الطابور تعتبر تقدم بطيء
	end
	task.wait(0.5)
end

function P.mainMenu()
	T.state = "Main menu"
	if tick() - P.lastMenu < 4 then
		return
	end
	P.lastMenu = tick()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	local chooseType = pg and pg:FindFirstChild("chooseType")
	if chooseType then
		T.detail = "choosing Universe"
		pcall(function()
			chooseType.Frame.RemoteEvent:FireServer("universeHub")
		end)
		D.count("menu_universe")
		return
	end
	local ps = tostring(T.settings.psCode or "")
	if ps ~= "" then
		T.detail = "joining PS"
		pcall(function()
			pg.reserved.Frame.CodeBox.TextBox.Text = ps
		end)
		R.invoke("reserved", ps)
		D.count("menu_ps")
		return
	end
	T.detail = "teleport to Universe"
	pcall(function()
		TeleportService:Teleport(UNIVERSE_ID, LocalPlayer)
	end)
	D.count("menu_teleport")
end

function P.other()
	T.state = T.place
	if not T.settings.leaveOtherPlaces then
		T.detail = "idle (leave OFF)"
		return
	end
	if tick() - P.lastLeave >= 15 then
		P.lastLeave = tick()
		T.detail = "teleport to Universe"
		pcall(function()
			TeleportService:Teleport(UNIVERSE_ID, LocalPlayer)
		end)
		D.count("leave_teleport")
	end
end

function P.tick()
	T.place = C.placeName()
	if T.place ~= "MainMenu" and not C.alive() then
		T.state = "Dead / respawning"
		T.detail = "waiting for the character"
		M.stop()
		M.holdPos = nil
		return
	end
	if T.place == "Dungeon" then
		return P.dungeon()
	elseif T.place == "Universe" then
		return P.universe()
	elseif T.place == "MainMenu" then
		return P.mainMenu()
	end
	return P.other()
end

-- ============================================================
-- HEALTH CHECKS  (تفحص كل شي)
-- ============================================================
local function validateSettings()
	local s, fixed = T.settings, {}
	local function clamp(key, lo, hi, def)
		local v = tonumber(s[key])
		if not v or v ~= v then
			s[key] = def
			fixed[#fixed + 1] = key
		elseif v < lo or v > hi then
			s[key] = math.clamp(v, lo, hi)
			fixed[#fixed + 1] = key
		end
	end
	clamp("speed", 10, 500, 90)
	clamp("lowHP", 0, 100000, 300)
	clamp("attackRadius", 3, 60, 10)
	clamp("targetRange", 50, 3000, 400)
	clamp("stallMinutes", 1, 120, 6)
	if type(s.floorHeight) ~= "table" then
		s.floorHeight = { [1] = 2600, [2] = 2800, [3] = 3000, [4] = 1500, [5] = 1500 }
		fixed[#fixed + 1] = "floorHeight"
	end
	return fixed
end

D.addCheck("Settings", 5, function()
	local fixed = validateSettings()
	if #fixed > 0 then
		return "WARN", "fixed invalid: " .. table.concat(fixed, ", ")
	end
	return "OK", "valid"
end)

D.addCheck("Place", 5, function()
	local p = C.placeName()
	if p == "Other" then
		return "WARN", "unknown place " .. tostring(game.PlaceId)
	end
	return "OK", p
end)

D.addCheck("Character", 1, function()
	if C.placeName() == "MainMenu" then
		return "OK", "main menu"
	end
	local ch, hum, hrp = C.char(), C.hum(), C.hrp()
	if not ch then
		return "FAIL", "no character"
	end
	if not hrp then
		return "FAIL", "no HumanoidRootPart"
	end
	if not hum then
		return "FAIL", "no Humanoid"
	end
	if hum.Health <= 0 then
		return "WARN", "dead"
	end
	return "OK", string.format("HP %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
end)

D.addCheck("Position", 1, function()
	local hrp = C.hrp()
	if not hrp then
		return "OK", "-"
	end
	local p = hrp.Position
	if not finite(p) then
		return "FAIL", "position is NaN/inf"
	end
	if p.Y < -1000 then
		return "FAIL", "fell out of the map (Y " .. math.floor(p.Y) .. ")"
	end
	return "OK", string.format("%d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
end)

D.addCheck("Remotes", 5, function()
	local place = C.placeName()
	local need = {}
	if place == "Dungeon" then
		need = { "CombatRegister", "Haki" }
	elseif place == "Universe" then
		need = { "Queue" }
	end
	local missing = {}
	for _, name in ipairs(need) do
		if not R.get(name) then
			missing[#missing + 1] = name
		end
	end
	if #missing > 0 then
		return "FAIL", "missing: " .. table.concat(missing, ", ")
	end
	return "OK", #need > 0 and table.concat(need, ", ") or "none needed"
end)

D.addCheck("Map", 2, function()
	if C.placeName() ~= "Dungeon" then
		return "OK", "not in the dungeon"
	end
	local miss = {}
	for _, n in ipairs({ "Islands", "NPCs", "Effects" }) do
		if not workspace:FindFirstChild(n) then
			miss[#miss + 1] = n
		end
	end
	if #miss > 0 then
		return "FAIL", "missing workspace." .. table.concat(miss, ", workspace.")
	end
	local f = F.detect()
	if not f then
		return "WARN", "floor not detected yet"
	end
	return "OK", "floor " .. tostring(f)
end)

D.addCheck("Weapon", 3, function()
	if C.placeName() ~= "Dungeon" then
		return "OK", "-"
	end
	local bp = LocalPlayer:FindFirstChild("Backpack")
	local ch = C.char()
	local found
	for _, container in ipairs({ ch, bp }) do
		if container then
			for _, wp in ipairs(WEAPON_PRIORITY) do
				for _, tool in ipairs(container:GetChildren()) do
					if not found and tool:IsA("Tool") and string.find(tool.Name, wp[1], 1, true) then
						found = tool.Name
					end
				end
			end
		end
	end
	if found then
		return "OK", found
	end
	if (bp and bp:FindFirstChild("Melee")) or (ch and ch:FindFirstChild("Melee")) then
		return "WARN", "only Melee (no farm sword)"
	end
	return "FAIL", "no weapon / Melee"
end)

D.addCheck("Haki", 10, function()
	if C.placeName() ~= "Dungeon" then
		return "OK", "-"
	end
	local m = C.statValue("BusoMastery")
	if m == nil then
		return "WARN", "stats not found"
	end
	if m == 0 then
		return "WARN", "no Buso haki (weaker damage)"
	end
	return "OK", "Buso " .. tostring(m)
end)

D.addCheck("Movement", 1, function()
	if M.stuckStreak >= 3 then
		return "FAIL", "stuck " .. M.stuckStreak .. "x in a row"
	elseif M.stuckStreak > 0 then
		return "WARN", "stuck " .. M.stuckStreak .. "x"
	end
	return "OK", tostring(M.lastResult or "idle")
end)

D.addCheck("Combat", 1, function()
	if T.state ~= "Fighting" or not K.target then
		return "OK", "not fighting"
	end
	local since = math.floor(tick() - math.max(K.lastHitAt, K.targetSince))
	if since > 15 then
		return "FAIL", string.format("no hits for %ds on %s", since, tostring(T.targetName))
	elseif since > 6 then
		return "WARN", string.format("no hits for %ds", since)
	end
	return "OK", "hitting " .. tostring(T.targetName)
end)

D.addCheck("Errors", 2, function()
	local n = D.recentErrors(60)
	if n >= 12 then
		return "FAIL", n .. " errors in 60s"
	elseif n >= 3 then
		return "WARN", n .. " errors in 60s"
	end
	return "OK", D.errorCount .. " total"
end)

D.addCheck("Progress", 2, function()
	if not T.enabled then
		return "OK", "off"
	end
	local idle = math.floor(tick() - D.lastProgress)
	local limit = (tonumber(T.settings.stallMinutes) or 6) * 60
	if idle > limit then
		return "FAIL", string.format("no progress for %dm", math.floor(idle / 60))
	elseif idle > limit / 2 then
		return "WARN", string.format("no progress for %ds", idle)
	end
	return "OK", string.format("last %ds ago", idle)
end)

D.addCheck("Performance", 3, function()
	local fps = math.floor(1 / math.max(D.frameDt, 1e-3))
	if fps < 12 then
		return "WARN", string.format("low fps ~%d", fps)
	end
	return "OK", string.format("fps ~%d", fps)
end)

-- ============================================================
-- [7] WATCHDOG / RECOVERY
-- ============================================================
local W = { pausedUntil = 0, lastNudge = 0, lastRejoin = 0 }

function W.tick()
	D.runChecks(false)
	local hrp = C.hrp()
	-- 1) خارج الماب / NaN: يرجع للارتفاع الآمن فوق آخر نقطة معروفة
	if hrp and (not finite(hrp.Position) or hrp.Position.Y < -1000) then
		local n = tonumber(T.floor)
		local cfg = n and FLOORS[n]
		local st = n and F.state[n]
		local p = cfg and cfg.route[math.min((st and st.idx) or 1, #cfg.route)]
		if p then
			M.stop()
			setCF(V(p.X, F.safeY(n), p.Z))
			M.hold(V(p.X, F.safeY(n), p.Z))
			D.recovery("out_of_map", "moved back above route point")
		end
	end
	-- 2) علگة بالحركة: يرفعه شوية ويعيد التخطيط
	if M.stuckStreak >= 3 and tick() - W.lastNudge > 5 and hrp then
		W.lastNudge = tick()
		M.stop()
		local up = hrp.Position + V(0, 25, 0)
		setCF(up)
		M.hold(up)
		M.stuckStreak = 0
		D.recovery("stuck", "nudged up 25 and replanning")
	end
	-- 3) هواي أخطاء: إيقاف مؤقت 5 ثواني وتصفير الحالة
	if D.recentErrors(60) >= 12 and tick() > W.pausedUntil then
		W.pausedUntil = tick() + 5
		M.stop()
		K.target = nil
		F.state = { visitedNotif = {} }
		F.visitedNotif = {}
		D.errorTimes = {}
		D.recovery("error_burst", "paused 5s and reset state")
	end
	-- 4) وقت السيرفر انتهى (نفس قاعدة الأصل 2700 ثانية)
	local age = workspace:GetAttribute("serverAge")
	if C.placeName() == "Dungeon" and type(age) == "number" and age >= 2700 and tick() - W.lastRejoin > 30 then
		W.lastRejoin = tick()
		D.recovery("server_age", "server age " .. age .. " -> back to Universe")
		pcall(function()
			TeleportService:Teleport(UNIVERSE_ID, LocalPlayer)
		end)
	end
	-- 5) ماكو تقدم لمدة طويلة: rejoin (إذا مفعل)
	local limit = (tonumber(T.settings.stallMinutes) or 6) * 60
	if T.settings.autoRejoinOnStall and tick() - D.lastProgress > limit and tick() - W.lastRejoin > 60 then
		W.lastRejoin = tick()
		D.recovery("stall", "no progress for " .. math.floor(limit / 60) .. "m -> rejoin")
		pcall(function()
			TeleportService:Teleport(UNIVERSE_ID, LocalPlayer)
		end)
	end
end

-- ============================================================
-- API
-- ============================================================
function T.start()
	if T.enabled then
		return
	end
	validateSettings()
	T.enabled = true
	T.startTick = T.startTick or tick()
	D.lastProgress = tick()
	D.log("INFO", "started")
	startMoverLoops()
	if not T.running then
		T.running = true
		task.spawn(function()
			while T.running do
				if T.enabled and tick() >= W.pausedUntil then
					D.run("tick", P.tick)
				end
				task.wait(0.05)
			end
		end)
		task.spawn(function()
			while T.running do
				D.run("watchdog", W.tick)
				task.wait(1)
			end
		end)
		pcall(function()
			local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
			pg.ChildAdded:Connect(function(child)
				if child.Name == "DiffChooser" and T.enabled then
					task.wait(0.1)
					selectDifficulty(child)
				end
			end)
			local existingGui = pg:FindFirstChild("DiffChooser")
			if existingGui then
				selectDifficulty(existingGui)
			end
		end)
	end
end

function T.stop()
	T.enabled = false
	M.stop()
	M.holdPos = nil
	T.state = "Stopped"
	T.detail = ""
	D.log("INFO", "stopped")
	pcall(function()
		local ch = C.char()
		for _, p in ipairs(ch:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "HumanoidRootPart" or p.Name:find("Torso")) then
				p.CanCollide = true
			end
		end
	end)
end

function T.runChecksNow()
	D.runChecks(true)
	return D.report()
end

function T.resetErrors()
	D.errors = {}
	D.errorTimes = {}
	D.errorCount = 0
	D.recoveries = {}
end

-- للاختبار والتشخيص
T._internal = { D = D, C = C, R = R, M = M, K = K, F = F, P = P, W = W, validateSettings = validateSettings }

return T
end -- END MODULE: ImpelTest

