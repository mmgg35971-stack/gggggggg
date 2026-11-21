-- ------------------------------------------------------------
-- Auto Impel (test): المحرك الجديد (Modules.ImpelTest)
-- ------------------------------------------------------------
local ITS = PN_Saved.ImpelTest
local IT_DEFAULT_HEIGHTS = { 2600, 2800, 3000, 1500, 1500 }
local ImpelTest = {
	enabled           = ITS.enabled == true,
	speed             = PN_pick(tonumber(ITS.speed), 90),
	verticalTP        = PN_pick(ITS.verticalTP, true),
	lowHP             = PN_pick(tonumber(ITS.lowHP), 300),
	attackRadius      = PN_pick(tonumber(ITS.attackRadius), 10),
	targetRange       = PN_pick(tonumber(ITS.targetRange), 400),
	autoQueue         = PN_pick(ITS.autoQueue, true),
	psCode            = PN_pick(ITS.psCode, ""),
	leaveOtherPlaces  = PN_pick(ITS.leaveOtherPlaces, true),
	buyMythical       = PN_pick(ITS.buyMythical, true),
	difficulty        = PN_pick(ITS.difficulty, "Nightmare"),
	autoRejoinOnStall = PN_pick(ITS.autoRejoinOnStall, false),
	stallMinutes      = PN_pick(tonumber(ITS.stallMinutes), 6),
	debug             = PN_pick(ITS.debug, false),
	heights           = {},
}
for f = 1, 5 do
	ImpelTest.heights[f] = PN_pick(tonumber(ITS["h" .. f]), IT_DEFAULT_HEIGHTS[f])
end

local function itApi()
	local T = getgenv().PrinceImpelTest
	if T and T.__loaded then
		return T
	end
	local ok, res = pcall(Modules.ImpelTest)
	if ok and type(res) == "table" then
		return res
	end
	pcall(function()
		getgenv().Library:Notify("[Auto Impel test] load error: " .. tostring(res), 8)
	end)
	return nil
end

local function itApply()
	local T = getgenv().PrinceImpelTest
	if not T then return end
	local s = T.settings
	s.speed = ImpelTest.speed
	s.verticalTP = ImpelTest.verticalTP
	s.lowHP = ImpelTest.lowHP
	s.attackRadius = ImpelTest.attackRadius
	s.targetRange = ImpelTest.targetRange
	s.autoQueue = ImpelTest.autoQueue
	s.psCode = ImpelTest.psCode
	s.leaveOtherPlaces = ImpelTest.leaveOtherPlaces
	s.buyMythical = ImpelTest.buyMythical
	s.difficulty = ImpelTest.difficulty
	s.autoRejoinOnStall = ImpelTest.autoRejoinOnStall
	s.stallMinutes = ImpelTest.stallMinutes
	s.debug = ImpelTest.debug
	s.floorHeight = {}
	for f = 1, 5 do s.floorHeight[f] = ImpelTest.heights[f] end
end

local function itStart()
	local T = itApi()
	if not T then return nil end
	itApply()
	T.start()
	return T
end

local function itStop()
	local T = getgenv().PrinceImpelTest
	if T and T.stop then T.stop() end
end

local function zyphStart()
	local Z = getgenv().PrinceZyph
	if Z and Z.running then
		return Z
	end
	local realG = getgenv()
	-- getgenv() الخاص بالسكربت: كل شي يروح للـ getgenv الحقيقي، بس Config يندمج ويه إعدادات التبويب
	local proxyG = setmetatable({}, {
		__index = realG,
		__newindex = function(_, k, v)
			if k == "Config" and type(v) == "table" then
				v = zyphMergeConfig(v)
			end
			realG[k] = v
		end,
	})
	local env = setmetatable({
		getgenv = function()
			return proxyG
		end,
	}, { __index = getfenv(1) })
	Z = { running = true, startTick = tick(), env = env, status = "Running", error = nil }
	getgenv().PrinceZyph = Z
	pcall(function()
		if setfenv then
			setfenv(Modules.ImpelZyph, env)
		end
	end)
	task.spawn(function()
		local ok, err = pcall(Modules.ImpelZyph)
		if not ok then
			Z.status = "Error"
			Z.error = tostring(err)
			pcall(function()
				getgenv().Library:Notify("[Impel Down Zyph] error: " .. tostring(err), 10)
			end)
		else
			Z.status = "Done"
		end
	end)
	return Z
end

