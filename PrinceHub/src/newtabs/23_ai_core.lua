-- ------------------------------------------------------------
-- PRINCE AI (CORE): محرك تحليل منطقي  [PRINCE HUB v19]
-- ------------------------------------------------------------
-- هذا الجزء "العقل" بس: ما يلمس اللعبة أبداً (لا Roblox ولا task)، فينفحص بالاختبارات.
-- الجزء اللي يقرا اللعبة وينفذ الأفعال بـ 24_ai_game.lua.
--
-- كيف يفكر (كل ثانية):
--   1) يلاحظ (observe):  يسجل لقطة من اللعبة بالذاكرة (دم، مكان، FPS، بنك، تقدم، أخطاء...)
--   2) يستنتج حقائق (derive): كل حقيقة إلها درجة صحة من 0 لـ 1 (منطق ضبابي / fuzzy)
--        مثال: "واكف بمكانه" = 0 إذا تحرك قبل 6 ثواني، و 1 إذا صارله 20 ثانية واكف
--   3) يطبق القواعد (infer): قواعد "إذا ... و ... و مو ... إذن ..." على طبقات،
--        كل طبقة تبني على اللي قبلها (stratified forward chaining)، والثقة تنجمع
--        بطريقة MYCIN (certainty factors). كل استنتاج يحفظ سلسلة الأسباب مالته.
--   4) يقرر (decide): لكل مشكلة أفعال ممكنة، يختار الأفضل حسب: الثقة × الخطورة ×
--        نسبة نجاح الفعل (يتعلمها) - كلفة الفعل، ويحترم الـ cooldown.
--   5) يتعلم (learn): بعد كل فعل يشوف هل المشكلة راحت، ويحدث نسبة النجاح (Laplace)
--        وتنحفظ بالملف، فالمرة الجاية يختار الفعل اللي فعلاً ينفع.
--   6) يشرح ويجاوب (explain / answer): ليش وصل لهالاستنتاج، ويجاوب أسئلة عربي أو إنكليزي.
local PrinceAICore = (function()
	local M = { VERSION = "1.0" }

	local function clamp(x, lo, hi)
		if x < lo then return lo end
		if x > hi then return hi end
		return x
	end
	M.clamp = clamp

	-- درجة صحة بين 0 و 1: صفر عند a، واحد عند b (إذا a أكبر من b تصير نازلة)
	function M.ramp(x, a, b)
		if x == nil then return 0 end
		if a == b then return (x >= b) and 1 or 0 end
		return clamp((x - a) / (b - a), 0, 1)
	end

	-- جمع الثقة (MYCIN): دليلين يقوّون بعض بدون ما يعبرون 1
	function M.cfCombine(a, b)
		if a >= 0 and b >= 0 then return a + b * (1 - a) end
		if a < 0 and b < 0 then return a + b * (1 + a) end
		return (a + b) / (1 - math.min(math.abs(a), math.abs(b)))
	end

	local function pct(x) return tostring(math.floor((x or 0) * 100 + 0.5)) .. "%" end
	M.pct = pct

	-- ================= الذاكرة: سلسلة قيم بالزمن =================
	local Series = {}
	Series.__index = Series

	function M.newSeries(maxAge)
		return setmetatable({ t = {}, v = {}, maxAge = maxAge or 300 }, Series)
	end

	function Series:push(t, v)
		if v == nil then return end
		local ts, vs = self.t, self.v
		ts[#ts + 1] = t
		vs[#vs + 1] = v
		local cut = t - self.maxAge
		local drop = 0
		while ts[drop + 1] and ts[drop + 1] < cut do drop = drop + 1 end
		if drop > 0 then
			for _ = 1, drop do
				table.remove(ts, 1)
				table.remove(vs, 1)
			end
		end
	end

	function Series:last()
		return self.v[#self.v]
	end

	-- القيم اللي بآخر window ثانية
	function Series:window(window, now)
		local outT, outV = {}, {}
		local from = now - window
		for i = 1, #self.t do
			if self.t[i] >= from then
				outT[#outT + 1] = self.t[i]
				outV[#outV + 1] = self.v[i]
			end
		end
		return outT, outV
	end

	-- الميل (تغيّر بالثانية) بطريقة least squares
	function Series:slope(window, now)
		local ts, vs = self:window(window, now)
		local n = #ts
		if n < 2 then return 0 end
		local mt, mv = 0, 0
		for i = 1, n do mt = mt + ts[i]; mv = mv + vs[i] end
		mt, mv = mt / n, mv / n
		local num, den = 0, 0
		for i = 1, n do
			num = num + (ts[i] - mt) * (vs[i] - mv)
			den = den + (ts[i] - mt) ^ 2
		end
		if den == 0 then return 0 end
		return num / den
	end

	function Series:stdev(window, now)
		local _, vs = self:window(window, now)
		local n = #vs
		if n < 2 then return 0 end
		local m = 0
		for i = 1, n do m = m + vs[i] end
		m = m / n
		local s = 0
		for i = 1, n do s = s + (vs[i] - m) ^ 2 end
		return math.sqrt(s / (n - 1))
	end

	function Series:mean(window, now)
		local _, vs = self:window(window, now)
		if #vs == 0 then return nil end
		local m = 0
		for i = 1, #vs do m = m + vs[i] end
		return m / #vs
	end

	-- ================= النصوص (EN / AR) =================
	M.TEXT = {
		EN = {
			stuck = "Stuck in place", danger = "In danger (HP falling)", falling_void = "Falling into the void",
			dying_repeatedly = "Dying again and again", crash_loop = "Same error repeating",
			module_failed = "A farm module crashed", no_progress = "Farm runs but no progress",
			network_lag = "Network lag (high ping)", low_performance = "Low FPS",
			server_degraded = "Old / bad server", conflict = "Two farms fighting each other",
			idle = "No farm is running", healthy = "Everything looks fine",
			unstick = "Jump + lift 25 studs", lift_up = "Lift back above the map",
			retreat_up = "Retreat up 80 studs", reset_errors = "Reset error counters",
			restart_farm = "Restart the farm", rejoin = "Rejoin another server",
			low_graphics = "Turn on low graphics", stop_conflict = "Stop one of the farms",
			pause_farm = "Pause the farm and check settings",
		},
		AR = {
			stuck = "علكان بمكانه", danger = "بخطر (الدم ديقل)", falling_void = "دا يوكع بالفراغ",
			dying_repeatedly = "يموت هواية", crash_loop = "نفس الخطأ يتكرر",
			module_failed = "موديول فارم وكف بخطأ", no_progress = "الفارم شغال بس ماكو تقدم",
			network_lag = "لاك بالنت (بنك عالي)", low_performance = "FPS واطي",
			server_degraded = "سيرفر قديم / خربان", conflict = "فارمين يتعاركون",
			idle = "ماكو فارم شغال", healthy = "كلشي تمام",
			unstick = "قفزة + رفع 25", lift_up = "رجعه فوق الماب",
			retreat_up = "انسحاب 80 لفوك", reset_errors = "تصفير عداد الأخطاء",
			restart_farm = "إعادة تشغيل الفارم", rejoin = "روح لسيرفر ثاني",
			low_graphics = "شغل الجرافيك الواطي", stop_conflict = "طفي واحد من الفارمات",
			pause_farm = "وكف الفارم وشوف الإعدادات",
		},
	}

	function M.t(lang, key)
		local L = M.TEXT[lang] or M.TEXT.EN
		return L[key] or M.TEXT.EN[key] or tostring(key)
	end

	-- ================= التشخيصات والأفعال =================
	-- severity: 1 خفيف، 2 متوسط، 3 خطر. actions: بالترتيب المفضل
	M.DIAGNOSES = {
		stuck            = { severity = 2, actions = { "unstick", "restart_farm" } },
		danger           = { severity = 3, actions = { "retreat_up" } },
		falling_void     = { severity = 3, actions = { "lift_up" } },
		dying_repeatedly = { severity = 3, actions = { "pause_farm" } },
		crash_loop       = { severity = 2, actions = { "reset_errors", "restart_farm" } },
		module_failed    = { severity = 2, actions = { "restart_farm" } },
		no_progress      = { severity = 1, actions = { "restart_farm", "rejoin" } },
		network_lag      = { severity = 1, actions = { "rejoin" } },
		low_performance  = { severity = 1, actions = { "low_graphics" } },
		server_degraded  = { severity = 1, actions = { "rejoin" } },
		conflict         = { severity = 2, actions = { "stop_conflict" } },
	}

	-- auto: مسموح ينفذه وحده بوضع Auto-fix. evalAfter: بعد كم ثانية يحكم إذا نفع
	M.ACTIONS = {
		unstick      = { auto = true,  cooldown = 25,  cost = 0.05, evalAfter = 15 },
		lift_up      = { auto = true,  cooldown = 8,   cost = 0.05, evalAfter = 8 },
		retreat_up   = { auto = false, cooldown = 20,  cost = 0.20, evalAfter = 15 },
		reset_errors = { auto = true,  cooldown = 60,  cost = 0.05, evalAfter = 60 },
		restart_farm = { auto = true,  cooldown = 240, cost = 0.30, evalAfter = 90 },
		rejoin       = { auto = true,  cooldown = 900, cost = 0.70, evalAfter = nil, notInDungeon = true },
		low_graphics = { auto = false, cooldown = 600, cost = 0.20, evalAfter = 60 },
		stop_conflict = { auto = false, cooldown = 60, cost = 0.30, evalAfter = 10 },
		pause_farm   = { auto = false, cooldown = 120, cost = 0.50, evalAfter = nil },
	}

	-- كلمات بحالة الفارم معناها "ينتظر عمداً"
	M.WAIT_WORDS = { "wait", "queue", "loading", "teleport", "joining", "lobby", "menu", "idle", "starting", "انتظار" }

	-- ================= القواعد =================
	-- all = كل الشروط لازم (AND = أقل درجة)، "!" = مو (NOT = 1 - الدرجة)
	-- any = واحد منهم يكفي (OR = أعلى درجة). layer = الطبقة (تبني على اللي قبلها)
	M.RULES = {
		-- طبقة 1: أسباب أساسية
		{ id = "lag+still",  layer = 1, all = { "still", "ping_high" }, conclude = "network_lag", strength = 0.8 },
		{ id = "lag",        layer = 1, all = { "ping_high" }, conclude = "network_lag", strength = 0.5 },
		{ id = "fps",        layer = 1, all = { "fps_low" }, conclude = "low_performance", strength = 0.9 },
		-- طبقة 2: المشاكل
		{ id = "stuck",      layer = 2, all = { "farm_active", "still", "!fighting", "!waiting", "!network_lag", "!dead" }, conclude = "stuck", strength = 0.9 },
		{ id = "danger",     layer = 2, all = { "hp_low", "hp_dropping", "!dead" }, conclude = "danger", strength = 0.9 },
		{ id = "danger-fight", layer = 2, all = { "hp_low", "fighting", "!dead" }, conclude = "danger", strength = 0.5 },
		{ id = "void",       layer = 2, all = { "falling", "deep_void" }, conclude = "falling_void", strength = 0.95 },
		{ id = "long-fall",  layer = 2, all = { "falling", "!fighting" }, conclude = "falling_void", strength = 0.35 },
		{ id = "deaths",     layer = 2, all = { "died_recently" }, conclude = "dying_repeatedly", strength = 0.85 },
		{ id = "crash",      layer = 2, all = { "errors_high", "errors_repeat" }, conclude = "crash_loop", strength = 0.9 },
		{ id = "errors",     layer = 2, all = { "errors_high" }, conclude = "crash_loop", strength = 0.4 },
		{ id = "module",     layer = 2, all = { "module_failed_flag" }, conclude = "module_failed", strength = 1.0 },
		{ id = "conflict",   layer = 2, all = { "multi_farm" }, conclude = "conflict", strength = 1.0 },
		{ id = "idle",       layer = 2, all = { "!farm_active" }, conclude = "idle", strength = 1.0 },
		-- طبقة 3: مشاكل مبنية على مشاكل
		{ id = "no-progress", layer = 3, all = { "farm_active", "progress_flat", "!stuck", "!waiting", "!dead", "!conflict" }, conclude = "no_progress", strength = 0.8 },
		{ id = "danger-loop", layer = 3, all = { "dying_repeatedly", "danger" }, conclude = "dying_repeatedly", strength = 0.5 },
		{ id = "stuck-fps",  layer = 3, all = { "stuck", "low_performance" }, conclude = "low_performance", strength = 0.4 },
		{ id = "old-server", layer = 3, all = { "server_old" }, any = { "network_lag", "low_performance", "no_progress" }, conclude = "server_degraded", strength = 0.8 },
		-- طبقة 4: الخلاصة
		{ id = "healthy",    layer = 4, all = { "farm_active", "!stuck", "!danger", "!crash_loop", "!no_progress", "!falling_void", "!conflict", "!dying_repeatedly", "!module_failed" }, conclude = "healthy", strength = 1.0 },
	}

	-- ================= العقل =================
	local Brain = {}
	Brain.__index = Brain

	function M.newBrain(opt)
		opt = opt or {}
		local B = setmetatable({}, Brain)
		B.lang = opt.lang or "EN"
		B.threshold = opt.threshold or 0.55   -- أقل ثقة حتى يعتبرها مشكلة
		B.rules = opt.rules or M.RULES
		B.stats = opt.stats or {}              -- التعلم: "diag|action" -> { s = نجح، n = مرات }
		B.mem = {
			hp = M.newSeries(120), y = M.newSeries(60), fps = M.newSeries(60), ping = M.newSeries(60),
		}
		B.st = {
			lastMoveT = nil, anchor = nil, fallStart = nil, wasAlive = true,
			lastProgressT = nil, progressKey = nil, farmSince = nil, farmKey = "",
			deaths = {}, errors = {},
		}
		B.facts = {}
		B.snap = nil
		B.now = 0
		B.cooldowns = {}
		B.pending = {}
		B.history = {}   -- آخر الأفعال: { t, diag, action, auto, result }
		B.autoLog = {}   -- أوقات الأفعال التلقائية (للميزانية)
		B.autoBudget = opt.autoBudget or 6     -- أكثر شي 6 أفعال تلقائية...
		B.budgetWindow = opt.budgetWindow or 600 -- ...بكل 10 دقايق
		B.plan = nil
		B.ticks = 0
		return B
	end

	-- 1) الملاحظة
	function Brain:observe(s)
		local t = s.t
		local st, mem = self.st, self.mem
		self.now = t
		self.snap = s
		self.ticks = self.ticks + 1

		-- الحركة: نحسب من آخر مرة ابتعد أكثر من 4 عن نقطة الارتكاز
		if s.pos then
			if not st.anchor then
				st.anchor, st.lastMoveT = s.pos, t
			else
				local dx, dy, dz = s.pos.x - st.anchor.x, s.pos.y - st.anchor.y, s.pos.z - st.anchor.z
				if math.sqrt(dx * dx + dy * dy + dz * dz) > 4 then
					st.anchor, st.lastMoveT = s.pos, t
				end
			end
			mem.y:push(t, s.pos.y)
		end

		-- الطيحة: سرعة نزول عالية بشكل مستمر
		if s.vy and s.vy < -60 then
			st.fallStart = st.fallStart or t
		else
			st.fallStart = nil
		end

		-- الموت
		local alive = s.alive ~= false and (s.hp == nil or s.hp > 0)
		if s.died or (st.wasAlive and not alive) then -- died = حدث Humanoid.Died من اللعبة
			st.deaths[#st.deaths + 1] = t
		end
		st.wasAlive = alive
		while st.deaths[1] and st.deaths[1] < t - 600 do table.remove(st.deaths, 1) end

		if s.hp and s.maxHp and s.maxHp > 0 then mem.hp:push(t, s.hp) end
		if s.fps then mem.fps:push(t, s.fps) end
		if s.ping then mem.ping:push(t, s.ping) end

		-- الفارم والتقدم: أي تغيير بالأرقام (لفل، فلوس، قتلات، موجة...) = تقدم
		local farms = s.farms or {}
		local farmKey = table.concat(farms, ",")
		if #farms == 0 then
			st.farmSince, st.lastProgressT = nil, nil
		elseif farmKey ~= st.farmKey or not st.farmSince then
			st.farmSince, st.lastProgressT = t, t
		end
		st.farmKey = farmKey
		local keys = {}
		for k in pairs(s.progress or {}) do keys[#keys + 1] = k end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(s.progress[k]) end
		local pkey = table.concat(parts, ";")
		if pkey ~= st.progressKey then
			if st.progressKey ~= nil and #farms > 0 then st.lastProgressT = t end
			st.progressKey = pkey
		end

		-- الأخطاء الجديدة
		for _, sig in ipairs(s.newErrors or {}) do
			st.errors[#st.errors + 1] = { t = t, sig = tostring(sig) }
		end
		while st.errors[1] and st.errors[1].t < t - 300 do table.remove(st.errors, 1) end
	end

	local function setFact(facts, name, cf, why)
		facts[name] = { cf = clamp(cf or 0, 0, 1), why = why, base = true }
	end

	-- 2) الحقائق (كل وحدة بدرجة 0..1 ويا سببها)
	function Brain:derive()
		local s, st, mem, t = self.snap or {}, self.st, self.mem, self.now
		local f = {}
		local R = M.ramp
		local farms = s.farms or {}

		setFact(f, "farm_active", #farms > 0 and 1 or 0, "active: " .. (#farms > 0 and table.concat(farms, ", ") or "none"))

		local alive = s.alive ~= false and (s.hp == nil or s.hp > 0)
		setFact(f, "dead", alive and 0 or 1, alive and "alive" or "character dead")

		local stillFor = st.lastMoveT and (t - st.lastMoveT) or 0
		setFact(f, "still", R(stillFor, 6, 20), string.format("did not move for %ds", math.floor(stillFor)))

		-- يقاتل؟ (هدف موجود، أو الدم يتغير، أو صار تقدم قريب)
		local fight, fwhy = 0, "no fight signs"
		if s.target and s.target ~= "" and s.target ~= "-" then
			fight, fwhy = 0.8, "target: " .. tostring(s.target)
		end
		local maxHp = s.maxHp or 0
		if maxHp > 0 then
			local hpVar = R(mem.hp:stdev(20, t) / maxHp, 0.01, 0.05)
			if hpVar > fight then fight, fwhy = hpVar, "HP changing (" .. pct(hpVar) .. ")" end
		end
		if st.lastProgressT and #farms > 0 then
			local recent = R(t - st.lastProgressT, 40, 10) * 0.7
			if recent > fight then fight, fwhy = recent, string.format("progress %ds ago", math.floor(t - st.lastProgressT)) end
		end
		setFact(f, "fighting", fight, fwhy)

		-- ينتظر عمداً؟ (Queue، تحميل، تيليبورت، المين منيو...) هنا الوكوف طبيعي
		local status = string.lower(tostring(s.status or ""))
		local wait, wwhy = 0, "not waiting"
		for _, w in ipairs(M.WAIT_WORDS) do
			if status ~= "" and string.find(status, w, 1, true) then wait, wwhy = 1, "status: " .. tostring(s.status) break end
		end
		if wait < 1 and (s.placeKind == "menu" or s.placeKind == "universe") then
			wait, wwhy = 0.8, "in " .. s.placeKind
		end
		setFact(f, "waiting", wait, wwhy)

		local hpFrac = (maxHp > 0 and s.hp) and (s.hp / maxHp) or 1
		setFact(f, "hp_low", R(hpFrac, 0.5, 0.15), "HP " .. pct(hpFrac))
		local drop = maxHp > 0 and (-mem.hp:slope(6, t) / maxHp) or 0
		setFact(f, "hp_dropping", R(drop, 0.01, 0.06), string.format("HP %s/s", pct(-drop)))

		local d10 = 0
		for _, dt in ipairs(st.deaths) do if dt >= t - 300 then d10 = d10 + 1 end end
		setFact(f, "died_recently", R(d10, 0.5, 2), d10 .. " deaths in 5 min")

		local fallFor = st.fallStart and (t - st.fallStart) or 0
		setFact(f, "falling", R(fallFor, 1, 3.5), string.format("falling for %.1fs", fallFor))
		local y = s.pos and s.pos.y or 0
		setFact(f, "deep_void", R(y, -30, -300), string.format("height %d", math.floor(y)))

		local e60, sigCount, topSig = 0, {}, nil
		for _, e in ipairs(st.errors) do
			if e.t >= t - 60 then e60 = e60 + 1 end
			if e.t >= t - 120 then
				sigCount[e.sig] = (sigCount[e.sig] or 0) + 1
				if not topSig or sigCount[e.sig] > sigCount[topSig] then topSig = e.sig end
			end
		end
		setFact(f, "errors_high", R(e60, 2, 10), e60 .. " errors in 60s")
		setFact(f, "errors_repeat", R(topSig and sigCount[topSig] or 0, 2, 6),
			topSig and (tostring(sigCount[topSig]) .. "x [" .. topSig .. "]") or "no repeats")

		local fps = mem.fps:mean(10, t)
		setFact(f, "fps_low", R(fps or 60, 25, 8), "FPS " .. tostring(fps and math.floor(fps) or "?"))
		local ping = mem.ping:mean(15, t)
		setFact(f, "ping_high", R(ping or 0, 250, 800), "ping " .. tostring(ping and math.floor(ping) or "?") .. "ms")

		local flatFor = (st.lastProgressT and #farms > 0) and (t - st.lastProgressT) or 0
		setFact(f, "progress_flat", R(flatFor, 120, 480), string.format("no progress for %dm %ds", math.floor(flatFor / 60), math.floor(flatFor % 60)))

		local age = (s.serverAge or 0) / 3600
		setFact(f, "server_old", R(age, 2, 6), string.format("server age %.1fh", age))

		setFact(f, "multi_farm", s.conflict or 0, s.conflictWhy or "no conflict")
		setFact(f, "module_failed_flag", s.moduleFailed and 1 or 0, s.moduleFailed and ("crashed: " .. tostring(s.moduleFailed)) or "modules ok")
		setFact(f, "in_dungeon", s.placeKind == "dungeon" and 1 or 0, "place: " .. tostring(s.placeKind or "?"))

		self.facts = f
		return f
	end

	local function premise(facts, rule)
		local cf, parts = 1, {}
		for _, name in ipairs(rule.all or {}) do
			local neg = string.sub(name, 1, 1) == "!"
			local key = neg and string.sub(name, 2) or name
			local v = facts[key] and facts[key].cf or 0
			if neg then v = 1 - v end
			if v < cf then cf = v end
			parts[#parts + 1] = (neg and "not " or "") .. key .. "(" .. pct(v) .. ")"
		end
		if rule.any then
			local best, bestName = 0, nil
			for _, name in ipairs(rule.any) do
				local v = facts[name] and facts[name].cf or 0
				if v > best then best, bestName = v, name end
			end
			if best < cf then cf = best end
			parts[#parts + 1] = "any[" .. tostring(bestName or "-") .. "(" .. pct(best) .. ")]"
		end
		return cf, table.concat(parts, " & ")
	end

	-- 3) الاستنتاج: طبقة طبقة، كل قاعدة تشتغل مرة بالطبقة، والثقة تنجمع (MYCIN)
	function Brain:infer()
		local facts = self.facts
		local maxLayer = 0
		for _, r in ipairs(self.rules) do if r.layer > maxLayer then maxLayer = r.layer end end
		for layer = 1, maxLayer do
			for _, r in ipairs(self.rules) do
				if r.layer == layer then
					local p, text = premise(facts, r)
					if p >= 0.2 then
						local add = p * (r.strength or 1)
						local cur = facts[r.conclude]
						if not cur or cur.base then
							cur = { cf = 0, chain = {}, derived = true }
							facts[r.conclude] = cur
						end
						cur.cf = M.cfCombine(cur.cf, add)
						cur.chain[#cur.chain + 1] = r.id .. ": " .. text .. " => " .. pct(add)
					end
				end
			end
		end
		return facts
	end

	function Brain:expected(diag, action)
		local s = self.stats[diag .. "|" .. action]
		if not s then return 0.5, 0 end
		return (s.s + 1) / (s.n + 2), s.n -- Laplace: يبدي من 50%، ويتحرك حسب النتائج
	end

	function Brain:budgetLeft()
		local n = 0
		for _, at in ipairs(self.autoLog) do if at >= self.now - self.budgetWindow then n = n + 1 end end
		return self.autoBudget - n
	end

	-- المشاكل المؤكدة، من الأخطر للأقل
	function Brain:problems()
		local list = {}
		for name, meta in pairs(M.DIAGNOSES) do
			local fct = self.facts[name]
			if fct and fct.cf >= self.threshold then
				list[#list + 1] = { name = name, cf = fct.cf, severity = meta.severity, chain = fct.chain or {} }
			end
		end
		table.sort(list, function(a, b)
			local sa, sb = a.cf * a.severity, b.cf * b.severity
			if sa == sb then return a.name < b.name end
			return sa > sb
		end)
		return list
	end

	-- 4) القرار
	function Brain:decide()
		local best = nil
		local inDungeon = self.facts.in_dungeon and self.facts.in_dungeon.cf >= 1
		for _, p in ipairs(self:problems()) do
			local meta = M.DIAGNOSES[p.name]
			for idx, aid in ipairs(meta.actions) do
				local a = M.ACTIONS[aid]
				local ready = (self.cooldowns[aid] or -math.huge) <= self.now
				local allowed = not (a.notInDungeon and inDungeon)
				if ready and allowed then
					local exp, n = self:expected(p.name, aid)
					local pref = 1 - (idx - 1) * 0.15
					local score = p.cf * (p.severity / 3) * exp * pref - a.cost * 0.3
					if not best or score > best.score then
						best = {
							diag = p.name, action = aid, score = score, cf = p.cf, expected = exp, tries = n,
							auto = a.auto, chain = p.chain,
						}
					end
				end
			end
		end
		self.plan = best
		return best
	end

	-- تسجيل إن الفعل انفذ (حتى نتعلم من نتيجته)
	function Brain:executed(plan, auto)
		local a = M.ACTIONS[plan.action]
		self.cooldowns[plan.action] = self.now + (a.cooldown or 30)
		if auto then self.autoLog[#self.autoLog + 1] = self.now end
		local h = { t = self.now, diag = plan.diag, action = plan.action, auto = auto == true, result = "pending" }
		self.history[#self.history + 1] = h
		while #self.history > 30 do table.remove(self.history, 1) end
		if a.evalAfter then
			self.pending[#self.pending + 1] = { at = self.now + a.evalAfter, diag = plan.diag, action = plan.action, h = h }
		else
			h.result = "done"
		end
		while self.autoLog[1] and self.autoLog[1] < self.now - self.budgetWindow do table.remove(self.autoLog, 1) end
	end

	-- 5) التعلم: المشكلة راحت بعد الفعل؟ = نجح
	function Brain:learn()
		local keep = {}
		local learned = {}
		for _, p in ipairs(self.pending) do
			if self.now >= p.at then
				local fct = self.facts[p.diag]
				local ok = not fct or fct.cf < 0.3
				local key = p.diag .. "|" .. p.action
				local s = self.stats[key] or { s = 0, n = 0 }
				s.n = s.n + 1
				if ok then s.s = s.s + 1 end
				self.stats[key] = s
				p.h.result = ok and "worked" or "did not work"
				learned[#learned + 1] = p
			else
				keep[#keep + 1] = p
			end
		end
		self.pending = keep
		return learned
	end

	-- دورة كاملة
	function Brain:tick(snap)
		self:observe(snap)
		self:derive()
		self:infer()
		local learned = self:learn()
		return self:decide(), learned
	end

	-- 6) الشرح
	function Brain:summary()
		local probs = self:problems()
		if #probs == 0 then
			local h = self.facts.healthy
			if h and h.cf >= 0.5 then return M.t(self.lang, "healthy") end
			local idle = self.facts.idle
			if idle and idle.cf >= 0.5 then return M.t(self.lang, "idle") end
			return M.t(self.lang, "healthy")
		end
		return M.t(self.lang, probs[1].name) .. " (" .. pct(probs[1].cf) .. ")"
	end

	function Brain:explain(maxLines)
		maxLines = maxLines or 12
		local out = {}
		local probs = self:problems()
		if #probs == 0 then
			out[#out + 1] = self:summary()
		end
		for _, p in ipairs(probs) do
			out[#out + 1] = M.t(self.lang, p.name) .. " = " .. pct(p.cf)
			for _, c in ipairs(p.chain) do out[#out + 1] = "  <- " .. c end
		end
		-- أهم الحقائق
		local names = {}
		for name, fct in pairs(self.facts) do
			if fct.base and fct.cf >= 0.3 then names[#names + 1] = name end
		end
		table.sort(names)
		if #names > 0 then
			out[#out + 1] = "facts:"
			for _, name in ipairs(names) do
				local fct = self.facts[name]
				out[#out + 1] = "  " .. name .. " " .. pct(fct.cf) .. " (" .. tostring(fct.why) .. ")"
			end
		end
		while #out > maxLines do table.remove(out) end
		return out
	end

	function Brain:planText(plan)
		plan = plan or self.plan
		if not plan then return "-" end
		return M.t(self.lang, plan.action) .. "  [" .. M.t(self.lang, plan.diag) .. ", " .. pct(plan.cf)
			.. ", works " .. pct(plan.expected) .. " of " .. plan.tries .. " tries]"
	end

	-- ================= الأسئلة =================
	M.INTENTS = {
		{ id = "why",      words = { "why", "problem", "wrong", "stuck", "ليش", "مشكلة", "مشكله", "شبي", "شبيه", "واكف", "علك", "خربان", "شنو صاير" } },
		{ id = "advice",   words = { "what should", "advice", "suggest", "fix", "help", "شسوي", "نصيحة", "نصيحه", "اقترح", "صلح", "ساعد" } },
		{ id = "errors",   words = { "error", "bug", "crash", "خطأ", "خطا", "اغلاط", "أخطاء", "اخطاء" } },
		{ id = "progress", words = { "progress", "level", "xp", "peli", "kills", "تقدم", "لفل", "فلوس", "قتل" } },
		{ id = "perf",     words = { "fps", "lag", "ping", "slow", "لاك", "بنك", "تقطيع", "بطيء", "بطيئ" } },
		{ id = "learn",    words = { "learn", "stats", "memory", "تعلم", "تعلمت", "احصائيات", "ذاكرة" } },
		{ id = "status",   words = { "status", "how", "state", "حالة", "حاله", "شلون", "وضع", "شكو" } },
	}

	function M.intentOf(q)
		q = string.lower(tostring(q or ""))
		for _, it in ipairs(M.INTENTS) do
			for _, w in ipairs(it.words) do
				if string.find(q, w, 1, true) then return it.id end
			end
		end
		return "status"
	end

	function Brain:answer(q)
		local AR = self.lang == "AR"
		local intent = M.intentOf(q)
		local f = self.facts
		local function cf(n) return f[n] and f[n].cf or 0 end
		local function why(n) return f[n] and f[n].why or "?" end
		local probs = self:problems()

		if intent == "why" then
			if #probs == 0 then
				return AR and ("ماكو مشكلة واضحة هسه. " .. self:summary()) or ("No clear problem right now. " .. self:summary())
			end
			local p = probs[1]
			local lines = { (AR and "المشكلة: " or "Problem: ") .. M.t(self.lang, p.name) .. " (" .. pct(p.cf) .. ")" }
			lines[#lines + 1] = AR and "الأسباب:" or "Because:"
			for i = 1, math.min(3, #p.chain) do lines[#lines + 1] = "- " .. p.chain[i] end
			return table.concat(lines, "\n")
		elseif intent == "advice" then
			local plan = self.plan
			if not plan then
				return AR and "ما أنصح بشي هسه، كلشي ماشي." or "Nothing to do right now, all good."
			end
			return (AR and "أنصح: " or "I suggest: ") .. self:planText(plan)
		elseif intent == "errors" then
			return (AR and "الأخطاء: " or "Errors: ") .. why("errors_high") .. ", " .. why("errors_repeat")
		elseif intent == "progress" then
			return (AR and "التقدم: " or "Progress: ") .. why("progress_flat") .. " | " .. why("farm_active")
		elseif intent == "perf" then
			return (AR and "الأداء: " or "Performance: ") .. why("fps_low") .. ", " .. why("ping_high") .. ", " .. why("server_old")
		elseif intent == "learn" then
			local keys = {}
			for k in pairs(self.stats) do keys[#keys + 1] = k end
			table.sort(keys)
			if #keys == 0 then
				return AR and "بعدني ما جربت أي فعل، ما تعلمت شي لهسه." or "I have not tried any fix yet, nothing learned."
			end
			local lines = { AR and "اللي تعلمته (نجح/جرب):" or "What I learned (worked/tried):" }
			for _, k in ipairs(keys) do
				local s = self.stats[k]
				local d, a = string.match(k, "^(.-)|(.*)$")
				lines[#lines + 1] = "- " .. M.t(self.lang, d) .. " -> " .. M.t(self.lang, a) .. ": " .. s.s .. "/" .. s.n
			end
			return table.concat(lines, "\n")
		end
		-- status
		local hp = why("hp_low")
		return (AR and "الحالة: " or "Status: ") .. self:summary() .. " | " .. why("farm_active") .. " | " .. hp
			.. (cf("still") > 0.5 and (" | " .. why("still")) or "")
	end

	return M
end)()
