-- ------------------------------------------------------------
-- PRINCE AI (GAME): يقرا اللعبة وينفذ الأفعال  [PRINCE HUB v19]
-- ------------------------------------------------------------
-- العقل نفسه بـ 23_ai_core.lua. هنا:
--   sense()  -> لقطة من اللعبة كل ثانية (الشخصية، FPS، البنك، الفارمات، التقدم، الأخطاء)
--   ACT      -> الأفعال اللي يكدر يسويها (قفزة، رفع، إعادة تشغيل الفارم، سيرفر ثاني...)
--   الأوضاع: "Advise" = يحلل وينصح بس (الافتراضي)
--            "Auto-fix" = ينفذ وحده الأفعال الآمنة (ميزانية 6 أفعال بكل 10 دقايق)
--   الإعدادات والتعلم ينحفظون بـ PrinceHubNewTabs.json (قسم AI)
PN_Saved.AI = type(PN_Saved.AI) == "table" and PN_Saved.AI or {}
PN_Saved.AI.stats = type(PN_Saved.AI.stats) == "table" and PN_Saved.AI.stats or {}

local PrinceAI = {
	enabled = PN_Saved.AI.enabled ~= false,
	mode = (PN_Saved.AI.mode == "Auto-fix") and "Auto-fix" or "Advise",
	lang = (PN_Saved.AI.lang == "AR") and "AR" or "EN",
	notify = PN_Saved.AI.notify ~= false,
	threshold = tonumber(PN_Saved.AI.threshold) or 55,
	running = false, token = 0, brain = nil,
	fps = nil, died = false, lastSafe = nil,
	seenLog = PH_Log.total, seenIT = nil, lastAdvice = {},
	ui = nil,
}
getgenv().PrinceAI = PrinceAI

local AI_PLACES = { [1730877806] = "menu", [6360478118] = "universe", [7465136166] = "sea2", [11424731604] = "dungeon" }
local AI_PROGRESS_KEYS = { Kills = true, Wave = true, Stage = true, Waypoint = true, Points = true, Mythical = true, Runs = true, Where = true }
local AI_IMPEL_FAMILY = { Impel = true, ImpelZyph = true, ImpelTest = true }

function PrinceAI.say(text, t)
	if not PrinceAI.notify then return end
	pcall(function() getgenv().Library:Notify("[AI] " .. tostring(text), t or 4) end)
end

-- ================= الحواس =================
function PrinceAI.activeFarms()
	local list, infos = {}, {}
	for _, fm in ipairs(PN_Farms) do
		local ok, on = pcall(fm.active)
		if ok and on then
			list[#list + 1] = fm.id
			local okL, lines = pcall(fm.lines)
			infos[fm.id] = okL and lines or {}
		end
	end
	if Kaitun.enabled == true and not PN_NoAuto then
		list[#list + 1] = "Kaitun"
		infos.Kaitun = {}
	end
	return list, infos
end

function PrinceAI.sense(now)
	local s = { t = now, progress = {}, newErrors = {} }
	local char = PN_LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum then
		s.hp, s.maxHp = hum.Health, hum.MaxHealth
		s.alive = hum.Health > 0
	end
	if hrp then
		local p = hrp.Position
		s.pos = { x = p.X, y = p.Y, z = p.Z }
		pcall(function() s.vy = hrp.AssemblyLinearVelocity.Y end)
		-- آخر مكان آمن (مو دا يطيح وفوق الفراغ) حتى نرجعله
		if (s.vy or 0) > -40 and p.Y > -30 and s.alive ~= false then PrinceAI.lastSafe = p end
	end
	s.died = PrinceAI.died
	PrinceAI.died = false
	s.fps = PrinceAI.fps

	pcall(function()
		s.ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if not s.ping then
		pcall(function() s.ping = PN_LocalPlayer:GetNetworkPing() * 2000 end)
	end

	local farms, infos = PrinceAI.activeFarms()
	s.farms = farms
	for id, lines in pairs(infos) do
		for _, kv in ipairs(lines) do
			local k, v = kv[1], kv[2]
			if AI_PROGRESS_KEYS[k] then s.progress[id .. "." .. k] = tostring(v) end
			if (k == "Target" or k == "NPC") and v and v ~= "-" then s.target = tostring(v) end
			if k == "State" and v then s.status = tostring(v) end
		end
	end
	s.progress.level = PN_statValue("Level")
	s.progress.peli = PN_statValue("Peli")

	-- الأخطاء الجديدة من سجل الهب، ومن نظام فحص Auto Impel (test)
	local total = PH_Log.total
	if total > PrinceAI.seenLog then
		local n = math.min(total - PrinceAI.seenLog, #PH_Log.entries)
		for i = #PH_Log.entries - n + 1, #PH_Log.entries do
			s.newErrors[#s.newErrors + 1] = PH_Log.entries[i].where
		end
		PrinceAI.seenLog = total
	end
	local T = getgenv().PrinceImpelTest
	if T and T.diag then
		local D = T.diag
		local count = tonumber(D.errorCount) or 0
		if PrinceAI.seenIT and count > PrinceAI.seenIT then
			for i = math.max(1, #D.errors - (count - PrinceAI.seenIT) + 1), #D.errors do
				local e = D.errors[i]
				s.newErrors[#s.newErrors + 1] = "ImpelTest:" .. tostring(e and e.where)
			end
		end
		PrinceAI.seenIT = count
		if T.enabled and D.overall == "FAIL" then s.moduleFailed = "Auto Impel (test)" end
	end
	local Z = getgenv().PrinceZyph
	if Z and Z.error then s.moduleFailed = "Impel Down Zyph" end

	-- تعارض: أكثر من فارم Impel سوة أكيد غلط، وأي فارمين سوة مشكوك بيهم
	local impelCount = 0
	for _, id in ipairs(farms) do if AI_IMPEL_FAMILY[id] then impelCount = impelCount + 1 end end
	if impelCount >= 2 then
		s.conflict, s.conflictWhy = 1, "Impel farms together: " .. table.concat(farms, ", ")
	elseif #farms >= 2 then
		s.conflict, s.conflictWhy = 0.6, "two farms ON: " .. table.concat(farms, ", ")
	end

	s.serverAge = workspace.DistributedGameTime
	s.placeKind = AI_PLACES[game.PlaceId] or "other"
	return s
end

-- ================= الأفعال =================
local function aiRoot()
	local char = PN_LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

-- يطفي الفارم ويرجع يشغله (بس الفارمات اللي عدها start/stop)
local AI_RESTART = {
	Kaitun = { stop = function() kaitunStop() end, start = function() kaitunStart() end },
	Cupid = { stop = function() cupidStop() end, start = function() cupidStart() end },
	Waves = { stop = function() wavesStop() end, start = function() wavesStart(Waves.mode) end },
	ImpelTest = { stop = function() itStop() end, start = function() itStart() end },
	Impel = {
		stop = function() local I = getgenv().PrinceImpel; if I and I.stop then I.stop() end end,
		start = function() local I = impelApi(); if I then impelApply(); I.start() end end,
	},
}

function PrinceAI.firstRestartable()
	local farms = PrinceAI.activeFarms()
	for _, id in ipairs(farms) do
		if AI_RESTART[id] then return id end
	end
	return nil
end

PrinceAI.ACT = {
	unstick = function()
		local hrp, hum = aiRoot()
		if not hrp then return false, "no character" end
		if hum then hum.Jump = true end
		hrp.CFrame = hrp.CFrame + Vector3.new(0, 25, 0)
		return true, "jumped and lifted 25"
	end,
	lift_up = function()
		local hrp = aiRoot()
		if not hrp then return false, "no character" end
		local target = PrinceAI.lastSafe or Vector3.new(hrp.Position.X, 50, hrp.Position.Z)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.CFrame = CFrame.new(target + Vector3.new(0, 10, 0))
		return true, "back to last safe spot"
	end,
	retreat_up = function()
		local hrp = aiRoot()
		if not hrp then return false, "no character" end
		hrp.CFrame = hrp.CFrame + Vector3.new(0, 80, 0)
		return true, "retreated 80 up"
	end,
	reset_errors = function()
		local T = getgenv().PrinceImpelTest
		if T and T.resetErrors then pcall(T.resetErrors) end
		return true, "error counters reset"
	end,
	restart_farm = function()
		local id = PrinceAI.firstRestartable()
		if not id then return false, "this farm can not be restarted from here" end
		local R = AI_RESTART[id]
		pcall(R.stop)
		task.delay(3, function() PH_try("AI restart " .. id, R.start) end)
		return true, "restarting " .. id
	end,
	rejoin = function()
		if game.PlaceId == 11424731604 then return false, "not inside a dungeon" end
		task.spawn(function()
			pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, PN_LocalPlayer) end)
		end)
		return true, "rejoining"
	end,
	low_graphics = function()
		local Toggles = getgenv().Toggles
		if Toggles and Toggles.Graphics3DToggle then
			Toggles.Graphics3DToggle:SetValue(true)
			return true, "low graphics ON"
		end
		return false, "low graphics toggle not found"
	end,
	stop_conflict = function()
		local farms = PrinceAI.activeFarms()
		local has = {}
		for _, id in ipairs(farms) do has[id] = true end
		-- نخلي الأحدث (ImpelTest ثم Zyph) ونطفي القديم
		if has.Impel and (has.ImpelTest or has.ImpelZyph) then
			AI_RESTART.Impel.stop()
			return true, "stopped Impel"
		end
		if has.ImpelTest and has.ImpelZyph then
			itStop()
			return true, "stopped Auto Impel (test)"
		end
		return false, "stop one farm by hand"
	end,
	pause_farm = function()
		local id = PrinceAI.firstRestartable()
		if not id then return false, "stop the farm by hand" end
		pcall(AI_RESTART[id].stop)
		return true, "paused " .. id .. " (check HP/weapon settings)"
	end,
}

function PrinceAI.run(plan, auto)
	local B = PrinceAI.brain
	if not (B and plan) then return false, "no plan" end
	local fn = PrinceAI.ACT[plan.action]
	local ok, done, msg = pcall(fn)
	if not ok then
		PH_Log.add("AI " .. plan.action, done)
		done, msg = false, "error"
	end
	if done then
		B:executed(plan, auto)
		PrinceAI.say(PrinceAICore.t(PrinceAI.lang, plan.action) .. " <- " .. PrinceAICore.t(PrinceAI.lang, plan.diag), 5)
	else
		-- ما انفذ: cooldown قصير حتى ما يعيد كل ثانية
		B.cooldowns[plan.action] = B.now + 30
	end
	return done, msg
end

-- ================= الدورة =================
function PrinceAI.step()
	local B = PrinceAI.brain
	B.lang = PrinceAI.lang
	B.threshold = PrinceAI.threshold / 100
	local plan, learned = B:tick(PrinceAI.sense(os.clock()))
	if #learned > 0 then
		PN_Saved.AI.stats = B.stats
		PN_save()
	end
	if plan then
		if PrinceAI.mode == "Auto-fix" and plan.auto and B:budgetLeft() > 0 then
			PrinceAI.run(plan, true)
		else
			local last = PrinceAI.lastAdvice[plan.diag] or -math.huge
			if B.now - last > 90 then
				PrinceAI.lastAdvice[plan.diag] = B.now
				PrinceAI.say(PrinceAICore.t(PrinceAI.lang, plan.diag) .. " -> " .. PrinceAICore.t(PrinceAI.lang, plan.action), 5)
			end
		end
	end
end

function PrinceAI.start()
	if PrinceAI.running then return end
	PrinceAI.running = true
	PrinceAI.token = PrinceAI.token + 1
	local token = PrinceAI.token
	PrinceAI.brain = PrinceAI.brain or PrinceAICore.newBrain({ lang = PrinceAI.lang, stats = PN_Saved.AI.stats })

	-- FPS: عدد الفريمات بكل ثانية
	pcall(function()
		local frames, since = 0, os.clock()
		PrinceAI.fpsConn = game:GetService("RunService").Heartbeat:Connect(function()
			frames = frames + 1
			local now = os.clock()
			if now - since >= 1 then
				PrinceAI.fps = frames / (now - since)
				frames, since = 0, now
			end
		end)
	end)
	-- الموت: نتابع Humanoid.Died لكل شخصية جديدة
	local function hookChar(char)
		pcall(function()
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then hum.Died:Connect(function() PrinceAI.died = true end) end
		end)
	end
	if PN_LocalPlayer.Character then task.spawn(hookChar, PN_LocalPlayer.Character) end
	PrinceAI.charConn = PN_LocalPlayer.CharacterAdded:Connect(hookChar)

	task.spawn(function()
		while PrinceAI.running and PrinceAI.token == token do
			PH_try("AI step", PrinceAI.step)
			task.wait(1)
		end
	end)
end

function PrinceAI.stop()
	PrinceAI.running = false
	PrinceAI.token = PrinceAI.token + 1
	if PrinceAI.fpsConn then pcall(function() PrinceAI.fpsConn:Disconnect() end) end
	if PrinceAI.charConn then pcall(function() PrinceAI.charConn:Disconnect() end) end
	PrinceAI.fpsConn, PrinceAI.charConn = nil, nil
end

function PrinceAI.saveSettings()
	local S = PN_Saved.AI
	S.enabled, S.mode, S.lang, S.notify, S.threshold = PrinceAI.enabled, PrinceAI.mode, PrinceAI.lang, PrinceAI.notify, PrinceAI.threshold
	PN_save()
end

-- ================= التبويب =================
function PrinceAI.buildTab(T, Library)
	local function notify(text, t) pcall(function() Library:Notify(text, t or 3) end) end

	local Box = T:AddLeftGroupbox("Prince AI")
	Box:AddLabel("Logic engine: watches the game,", true)
	Box:AddLabel("finds the problem and why, then fixes it.", true)
	Box:AddToggle("PN_AIEnabled", {
		Text = "AI analysis", Default = PrinceAI.enabled,
		Callback = function(v)
			PrinceAI.enabled = v
			PrinceAI.saveSettings()
			if v then PrinceAI.start() else PrinceAI.stop() end
		end,
	})
	Box:AddDropdown("PN_AIMode", {
		Values = { "Advise", "Auto-fix" }, Default = PrinceAI.mode, Multi = false, Text = "Mode",
		Tooltip = "Advise = only tells you. Auto-fix = does safe fixes alone (max 6 per 10 min)",
		Callback = function(v) PrinceAI.mode = (v == "Auto-fix") and "Auto-fix" or "Advise"; PrinceAI.saveSettings() end,
	})
	Box:AddDropdown("PN_AILang", {
		Values = { "EN", "AR" }, Default = PrinceAI.lang, Multi = false, Text = "Language",
		Callback = function(v)
			PrinceAI.lang = (v == "AR") and "AR" or "EN"
			if PrinceAI.brain then PrinceAI.brain.lang = PrinceAI.lang end
			PrinceAI.saveSettings()
		end,
	})
	Box:AddToggle("PN_AINotify", {
		Text = "Notifications", Default = PrinceAI.notify,
		Callback = function(v) PrinceAI.notify = v; PrinceAI.saveSettings() end,
	})
	Box:AddSlider("PN_AIThreshold", {
		Text = "Sure enough at (%)", Default = math.clamp(PrinceAI.threshold, 30, 90), Min = 30, Max = 90, Rounding = 0,
		Tooltip = "Lower = finds problems faster (more false alarms)",
		Callback = function(v) PrinceAI.threshold = v; PrinceAI.saveSettings() end,
	})

	local Now = T:AddLeftGroupbox("Analysis")
	local lSummary = Now:AddLabel("State: -", true)
	local lPlan = Now:AddLabel("Plan: -", true)
	local lBudget = Now:AddLabel("Auto fixes left: -")
	Now:AddButton({
		Text = "Apply suggestion",
		Func = function()
			local B = PrinceAI.brain
			if not (B and B.plan) then notify("[AI] nothing to apply", 3) return end
			local done, msg = PrinceAI.run(B.plan, false)
			notify("[AI] " .. tostring(msg), 4)
		end,
	})
	Now:AddButton({
		Text = "Copy analysis",
		Func = function()
			local B = PrinceAI.brain
			if not B then notify("[AI] not running", 3) return end
			local lines = { "Prince AI " .. PrinceAICore.VERSION .. " | " .. B:summary(), "Plan: " .. B:planText() }
			for _, l in ipairs(B:explain(60)) do lines[#lines + 1] = l end
			lines[#lines + 1] = "history:"
			for _, h in ipairs(B.history) do
				lines[#lines + 1] = string.format("  %ds ago %s -> %s (%s%s)", math.floor(B.now - h.t), h.diag, h.action, h.result, h.auto and ", auto" or "")
			end
			local text = table.concat(lines, "\n")
			local copy = setclipboard or toclipboard
			if copy then pcall(copy, text); notify("[AI] analysis copied", 3) else print(text) end
		end,
	})

	local Why = T:AddRightGroupbox("Reasoning (why)")
	local lWhy = Why:AddLabel("-", true)

	local Ask = T:AddRightGroupbox("Ask the AI")
	Ask:AddLabel("why / status / advice / errors", true)
	Ask:AddLabel("progress / fps / learn  (or Arabic)", true)
	local lAnswer
	Ask:AddInput("PN_AIAsk", {
		Text = "Question", Default = "", Placeholder = "ليش واكف؟  /  what should I do?", Numeric = false, Finished = true,
		Callback = function(q)
			if not lAnswer then return end
			local B = PrinceAI.brain
			if not B then lAnswer:SetText("AI is off") return end
			B.lang = PrinceAI.lang
			lAnswer:SetText(B:answer(q))
		end,
	})
	lAnswer = Ask:AddLabel("-", true)
	Ask:AddButton({
		Text = "Forget what it learned",
		Func = function()
			PN_Saved.AI.stats = {}
			if PrinceAI.brain then PrinceAI.brain.stats = PN_Saved.AI.stats end
			PN_save()
			notify("[AI] learning reset", 3)
		end,
	})

	task.spawn(function()
		while Library.ScreenGui and Library.ScreenGui.Parent do
			pcall(function()
				local B = PrinceAI.brain
				if not (B and PrinceAI.running) then
					lSummary:SetText("State: AI off")
					return
				end
				lSummary:SetText("State: " .. B:summary())
				lPlan:SetText("Plan: " .. B:planText() .. ((B.plan and PrinceAI.mode == "Auto-fix" and not B.plan.auto) and "  (needs you: Apply)" or ""))
				lBudget:SetText("Auto fixes left: " .. B:budgetLeft() .. " / " .. B.autoBudget .. "  | mode " .. PrinceAI.mode)
				lWhy:SetText(table.concat(B:explain(12), "\n"))
			end)
			task.wait(1)
		end
	end)
end
