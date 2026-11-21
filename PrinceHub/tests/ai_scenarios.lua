-- سيناريوهات لعقل Prince AI (23_ai_core.lua). كل سيناريو يمشي ثانية بثانية بلقطات وهمية.
local AI = PrinceAICore
local results = {}
local function check(name, cond, extra)
	results[#results + 1] = { name = name, ok = cond and true or false, extra = extra }
end

-- يمشي العقل n ثانية. gen(t) يرجع اللقطة
local function sim(brain, from, to, gen)
	local plan
	for t = from, to do
		local s = gen(t)
		s.t = t
		plan = brain:tick(s)
	end
	return plan
end

local function cf(b, name) return b.facts[name] and b.facts[name].cf or 0 end
local function base(t) return { hp = 1000, maxHp = 1000, alive = true, pos = { x = 0, y = 100, z = 0 }, vy = 0, fps = 60, ping = 80, farms = { "Cupid" }, progress = { kills = 0 }, serverAge = 600, placeKind = "sea2" } end

-- 1) فارم شغال وماشي ويتقدم = كلشي تمام
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 120, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { kills = math.floor(t / 5) }; return s
	end)
	check("healthy farm: no problem", #b:problems() == 0 and plan == nil, b:summary())
	check("healthy farm: healthy fact", cf(b, "healthy") > 0.9, cf(b, "healthy"))
end

-- 2) علكان: الفارم شغال، ما يتحرك، ماكو هدف ولا تقدم
local stuckBrain
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 40, function(t) return base(t) end)
	check("stuck: detected", cf(b, "stuck") >= 0.55, cf(b, "stuck"))
	check("stuck: plan = unstick", plan and plan.action == "unstick" and plan.diag == "stuck", plan and plan.action)
	check("stuck: chain explains", plan and #plan.chain > 0 and string.find(plan.chain[1], "still", 1, true) ~= nil, plan and plan.chain[1])
	stuckBrain = b
end

-- 3) واكف فوق بوس ويقاتل (هدف + الدم يتغير) = مو علكان
do
	local b = AI.newBrain()
	sim(b, 1, 40, function(t)
		local s = base(t); s.target = "Kelvin"; s.hp = 1000 - (t % 4) * 120; return s
	end)
	check("fighting boss: not stuck", cf(b, "stuck") < 0.3, cf(b, "stuck"))
end

-- 3b) ينتظر بالـ Queue أو بالمين منيو = مو علكان، ولا "ماكو تقدم"
do
	local b = AI.newBrain()
	sim(b, 1, 600, function(t) local s = base(t); s.status = "Waiting for queue"; return s end)
	check("queue wait: not stuck", cf(b, "stuck") < 0.3, cf(b, "stuck"))
	check("queue wait: not no_progress", cf(b, "no_progress") < 0.3, cf(b, "no_progress"))
	local b2 = AI.newBrain()
	sim(b2, 1, 40, function(t) local s = base(t); s.placeKind = "menu"; return s end)
	check("main menu: not stuck", cf(b2, "stuck") < 0.3, cf(b2, "stuck"))
end

-- 4) واكف بسبب اللاك = network_lag مو stuck
do
	local b = AI.newBrain()
	sim(b, 1, 40, function(t) local s = base(t); s.ping = 950; return s end)
	check("lag: network_lag", cf(b, "network_lag") >= 0.55, cf(b, "network_lag"))
	check("lag: not called stuck", cf(b, "stuck") < 0.3, cf(b, "stuck"))
end

-- 5) يطيح بالفراغ
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 6, function(t) local s = base(t); s.vy = -120; s.pos = { x = 0, y = -60 * t, z = 0 }; return s end)
	check("void: falling_void", cf(b, "falling_void") >= 0.55, cf(b, "falling_void"))
	check("void: plan = lift_up", plan and plan.action == "lift_up", plan and plan.action)
end

-- 6) نفس الخطأ يتكرر
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 30, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { kills = t }
		if t % 3 == 0 then s.newErrors = { "module Cupid" } end
		return s
	end)
	check("crash loop: detected", cf(b, "crash_loop") >= 0.55, cf(b, "crash_loop"))
	check("crash loop: plan = reset_errors", plan and plan.action == "reset_errors", plan and plan.action)
end

-- 7) التعلم: unstick ما نفع مرتين -> يختار restart_farm
do
	local b = stuckBrain
	local t = 40
	for round = 1, 2 do
		local plan = b.plan
		check("learn round " .. round .. ": tries unstick", plan and plan.action == "unstick", plan and plan.action)
		b:executed(plan, true)
		sim(b, t + 1, t + 26, function(tt) return base(tt) end) -- بعده علكان
		t = t + 26
	end
	local s = b.stats["stuck|unstick"]
	check("learn: unstick recorded as failed twice", s and s.n == 2 and s.s == 0, s and (s.s .. "/" .. s.n))
	check("learn: switches to restart_farm", b.plan and b.plan.action == "restart_farm", b.plan and b.plan.action)
	check("learn: history says did not work", b.history[1].result == "did not work", b.history[1].result)
end

-- 8) التعلم الإيجابي: الفعل نفع
do
	local b = AI.newBrain()
	sim(b, 1, 30, function(t) return base(t) end)
	b:executed(b.plan, true)
	sim(b, 31, 50, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { kills = t }; return s end)
	local s = b.stats["stuck|unstick"]
	check("learn: success recorded", s and s.s == 1 and s.n == 1, s and (s.s .. "/" .. s.n))
	local e = b:expected("stuck", "unstick")
	check("learn: expected rises above 50%", e > 0.5, e)
end

-- 9) ماكو تقدم + سيرفر قديم -> no_progress و server_degraded، وما يسوي rejoin بالدنجن
do
	local gen = function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.serverAge = 6 * 3600; return s
	end
	local b = AI.newBrain()
	sim(b, 1, 600, gen)
	check("no progress: detected", cf(b, "no_progress") >= 0.55, cf(b, "no_progress"))
	check("old server: degraded", cf(b, "server_degraded") >= 0.55, cf(b, "server_degraded"))
	local b2 = AI.newBrain()
	b2.cooldowns.restart_farm = math.huge
	local plan = sim(b2, 1, 600, function(t) local s = gen(t); s.placeKind = "dungeon"; return s end)
	check("dungeon: never plans rejoin", not plan or plan.action ~= "rejoin", plan and plan.action)
	local b3 = AI.newBrain()
	b3.cooldowns.restart_farm = math.huge
	local plan3 = sim(b3, 1, 600, gen)
	check("outside dungeon: rejoin allowed", plan3 and plan3.action == "rejoin", plan3 and plan3.action)
end

-- 10) فارمين Impel سوة
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 5, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }; s.farms = { "Impel", "ImpelTest" }; s.conflict = 1; return s
	end)
	check("conflict: detected", cf(b, "conflict") >= 0.99, cf(b, "conflict"))
	check("conflict: suggest stop (not auto)", plan and plan.action == "stop_conflict" and plan.auto == false, plan and plan.action)
end

-- 11) يموت هواية
do
	local b = AI.newBrain()
	sim(b, 1, 60, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }
		if t == 10 or t == 30 then s.hp = 0; s.alive = false end
		return s
	end)
	check("deaths: dying_repeatedly", cf(b, "dying_repeatedly") >= 0.55, cf(b, "dying_repeatedly"))
end

-- 12) الدم ديقل بسرعة = خطر، وفرعين: قريب يموت (رفع طوارئ تلقائي) / بوس يضرب (انسحاب يحتاجك)
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 12, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }; s.hp = math.max(50, 1000 - t * 80); return s
	end)
	check("danger: detected", cf(b, "danger") >= 0.55, cf(b, "danger"))
	check("danger: branch imminent_death", plan and plan.cause == "imminent_death", plan and plan.cause)
	check("danger: emergency lift is automatic", plan and plan.action == "emergency_lift" and plan.auto == true, plan and plan.action)
	local b2 = AI.newBrain()
	local plan2 = sim(b2, 1, 14, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.target = "Kelvin"
		s.hp = (t < 8) and 1000 or math.max(200, 1000 - (t - 7) * 110); return s
	end)
	check("danger: boss branch", plan2 and (plan2.cause == "boss_burst" or plan2.cause == "imminent_death"), plan2 and plan2.cause)
end

-- 12b) فروع "علكان": يروح ويرجع / يحوم / ماكو سلاح
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 40, function(t) local s = base(t); s.pos = { x = (t % 2) * 30, y = 100, z = 0 }; return s end)
	check("stuck branch: path blocked (back and forth)", plan and plan.diag == "stuck" and plan.cause == "path_blocked", plan and (plan.diag .. "/" .. plan.cause))
	local b2 = AI.newBrain()
	local plan2 = sim(b2, 1, 40, function(t) local s = base(t); s.pos = { x = 0, y = 100 + ((t % 2) * 3), z = 0 }; return s end)
	check("stuck: still detected while bobbing", cf(b2, "stuck") >= 0.55, cf(b2, "stuck"))
	local b3 = AI.newBrain()
	local plan3 = sim(b3, 1, 40, function(t) local s = base(t); s.toolEquipped = false; return s end)
	check("stuck branch: no weapon -> equip", plan3 and plan3.cause == "no_weapon" and plan3.action == "equip_weapon", plan3 and (plan3.cause .. "/" .. plan3.action))
	check("options: several alternatives", #b3.options >= 2, #b3.options)
end

-- 12c) فروع الأداء: رام عالي -> سيرفر ثاني، جرافيك -> واطي
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 20, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }; s.fps = 9; s.memMb = 5000; return s end)
	check("perf branch: memory -> rejoin", b.causes.low_performance and b.causes.low_performance[1].id == "memory" and plan and plan.action == "rejoin", plan and plan.action)
	local b2 = AI.newBrain()
	local plan2 = sim(b2, 1, 20, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }; s.fps = 9; s.memMb = 1200; return s end)
	check("perf branch: render -> low graphics", plan2 and plan2.cause == "render_heavy" and plan2.action == "low_graphics", plan2 and plan2.action)
end

-- 12d) لاك متقطع -> ينتظر (ما يصرف من الميزانية)
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 30, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.progress = { k = t }; s.ping = (t % 2 == 0) and 1400 or 300; return s end)
	check("lag branch: spiky -> wait", plan and plan.cause == "spiky" and plan.action == "wait", plan and (tostring(plan.cause) .. "/" .. plan.action))
	if plan then b:executed(plan, true) end
	check("wait is free (budget kept)", b:budgetLeft() == 6, b:budgetLeft())
end

-- 12e) الهدف تحقق / ينتظر هواية / الهدف ما ياخذ ضرر
do
	local b = AI.newBrain()
	local plan = sim(b, 1, 5, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.goalReached = true; return s end)
	check("goal reached -> pause (needs you)", plan and plan.diag == "goal_done" and plan.action == "pause_farm" and plan.auto == false, plan and plan.diag)
	local b2 = AI.newBrain()
	local plan2 = sim(b2, 1, 700, function(t) local s = base(t); s.placeKind = "menu"; return s end)
	check("waiting too long in menu -> restart/rejoin", plan2 and plan2.diag == "waiting_too_long" and plan2.cause == "in_menu", plan2 and (plan2.diag .. "/" .. tostring(plan2.cause)))
	local b3 = AI.newBrain()
	sim(b3, 1, 600, function(t) local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }; s.target = "Vera"; s.hp = 1000; return s end)
	check("same target forever -> target_immune branch", b3.causes.no_progress and b3.causes.no_progress[1].id == "target_immune", b3.causes.no_progress and b3.causes.no_progress[1].id)
end

-- 12f) الفارم يبطأ (تقدم أقل من قبل)
do
	local b = AI.newBrain()
	sim(b, 1, 900, function(t)
		local s = base(t); s.pos = { x = t * 10, y = 100, z = 0 }
		local k = (t < 600) and math.floor(t / 10) or (60 + math.floor((t - 600) / 90))
		s.progress = { k = k }; return s
	end)
	check("slowing down detected", cf(b, "slowing_down") >= 0.55, cf(b, "slowing_down"))
end

-- 12g) التعلم على مستويين: السبب الجديد يستفيد من خبرة المشكلة
do
	local b = AI.newBrain({ stats = { ["stuck|unstick"] = { s = 0, n = 4 } } })
	local e, n, from = b:expected("stuck", "unstick", "path_blocked")
	check("hierarchical learning: falls back to problem stats", from == "problem" and n == 4 and e < 0.3, from)
	b.stats["stuck/path_blocked|unstick"] = { s = 3, n = 3 }
	local e2, _, from2 = b:expected("stuck", "unstick", "path_blocked")
	check("hierarchical learning: cause stats win", from2 == "cause" and e2 > 0.7, from2)
end

-- 13) الميزانية والـ cooldown
do
	local b = AI.newBrain({ autoBudget = 3 })
	sim(b, 1, 30, function(t) return base(t) end)
	for _ = 1, 3 do b:executed({ diag = "stuck", action = "unstick" }, true) end
	check("budget: used up", b:budgetLeft() == 0, b:budgetLeft())
	local plan = b:decide()
	check("cooldown: unstick not offered right after", plan and plan.action ~= "unstick", plan and plan.action)
end

-- 14) الأسئلة
do
	local b = AI.newBrain({ lang = "AR" })
	sim(b, 1, 40, function(t) return base(t) end)
	local cz = b:answer("شنو السبب")
	check("ask AR cause: lists branches", string.find(cz, "عام", 1, true) ~= nil, cz)
	check("ask tree", string.find(b:answer("شجرة"), "cause:", 1, true) ~= nil)
	check("ask plan: options", string.find(b:answer("plan"), "1)", 1, true) ~= nil, b:answer("plan"))
	local a = b:answer("ليش واكف؟")
	check("ask AR why: names the problem", string.find(a, "علكان", 1, true) ~= nil, a)
	check("ask AR why: gives reasons", string.find(a, "still", 1, true) ~= nil, a)
	local adv = b:answer("شسوي")
	check("ask AR advice: suggests a fix", string.find(adv, "أنصح", 1, true) ~= nil, adv)
	b.lang = "EN"
	check("ask EN learn: nothing yet", string.find(b:answer("what did you learn"), "nothing learned", 1, true) ~= nil, b:answer("learn"))
	check("intent: fps", AI.intentOf("why lag") == "why" and AI.intentOf("fps?") == "perf")
	check("explain has facts", #b:explain(20) > 2)
end

-- 15) الرياضيات
do
	check("ramp up", AI.ramp(5, 0, 10) == 0.5 and AI.ramp(-1, 0, 10) == 0 and AI.ramp(11, 0, 10) == 1)
	check("ramp down", math.abs(AI.ramp(0.3, 0.5, 0.2) - 2 / 3) < 1e-9)
	check("cf combine", math.abs(AI.cfCombine(0.6, 0.5) - 0.8) < 1e-9 and AI.cfCombine(0, 0) == 0)
	local sr = AI.newSeries(100)
	for i = 1, 10 do sr:push(i, 3 * i + 1) end
	check("series slope", math.abs(sr:slope(100, 10) - 3) < 1e-9, sr:slope(100, 10))
	sr:push(500, 1)
	check("series trims old", #sr.t == 1)
end

return results
