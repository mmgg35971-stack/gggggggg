-- ------------------------------------------------------------
-- PRINCE AI (CORE): محرك تحليل منطقي متفرع  [PRINCE HUB v20 / AI 2.0]
-- ------------------------------------------------------------
-- هذا الجزء "العقل" بس: ما يلمس اللعبة أبداً (لا Roblox ولا task)، فينفحص بالاختبارات.
-- الجزء اللي يقرا اللعبة وينفذ الأفعال بـ 24_ai_game.lua.
--
-- شجرة التفكير (كل ثانية):
--   1) يلاحظ (observe): لقطة من اللعبة بالذاكرة (دم، مسار الحركة، FPS، بنك، رام، لاعبين قريبين،
--      هدف، سلاح، تقدم، أخطاء...)
--   2) حقائق (derive): ~30 حقيقة، كل وحدة بدرجة من 0 لـ 1 (fuzzy) ويا سببها.
--   3) مشاكل (infer): قواعد "إذا ... و ... و مو ... أو ..." على 4 طبقات، والثقة تنجمع (MYCIN).
--   4) أسباب (diagnose): كل مشكلة إلها فروع أسباب (مثلاً علكان: طريق مسدود / يحوم بالجو /
--      ماكو سلاح / FPS واطي / عام)، وكل سبب إله أفعاله الخاصة.
--   5) قرار (decide): يقارن كل (مشكلة -> سبب -> فعل): الثقة × الخطورة × نسبة النجاح المتعلمة
--      × الأفضلية - الكلفة، ويحترم الـ cooldown ومكان اللاعب.
--   6) تعلم (learn): بعد كل فعل يشوف هل المشكلة راحت. يتعلم على مستويين: لكل سبب، ولكل مشكلة
--      (إذا السبب جديد يستفيد من خبرة المشكلة). ينحفظ بالملف.
--   7) شرح وأسئلة (explain / answer): الشجرة كاملة، والبدائل، والتاريخ، عربي وإنكليزي.
local PrinceAICore = (function()
	local M = { VERSION = "2.0" }

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

	local function dist(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

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
		while ts[1] and ts[1] < cut do
			table.remove(ts, 1)
			table.remove(vs, 1)
		end
	end

	function Series:last()
		return self.v[#self.v]
	end

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
			-- problems
			stuck = "Stuck in place", danger = "In danger (HP falling)", falling_void = "Falling into the void",
			dying_repeatedly = "Dying again and again", crash_loop = "Errors repeating",
			module_failed = "A farm module crashed", no_progress = "Farm runs but no progress",
			network_lag = "Network lag (high ping)", low_performance = "Low FPS",
			server_degraded = "Old / bad server", conflict = "Two farms fighting each other",
			slowing_down = "Farm is getting slower", waiting_too_long = "Waiting too long",
			goal_done = "Goal reached", idle = "No farm is running", healthy = "Everything looks fine",
			-- causes
			cause_general = "general", cause_path_blocked = "path blocked (going back and forth)",
			cause_hovering = "hovering in the air", cause_no_weapon = "no weapon equipped",
			cause_low_fps = "low FPS", cause_imminent_death = "about to die",
			cause_player_attack = "players nearby", cause_boss_burst = "boss hits hard",
			cause_fall_deaths = "deaths from falling", cause_pvp_deaths = "killed near players",
			cause_under_geared = "too weak for the enemy", cause_same_error = "same error again",
			cause_unstable_server = "many different errors", cause_goal_reached = "goal reached",
			cause_target_immune = "target takes no damage", cause_old_server = "old server",
			cause_memory = "memory too high", cause_in_menu = "stuck in menu / queue",
			cause_spiky = "ping jumps up and down", cause_render_heavy = "graphics too heavy",
			cause_status_error = "module says error",
			-- actions
			unstick = "Jump + lift 25 studs", lift_up = "Lift back above the map",
			retreat_up = "Retreat up 80 studs", emergency_lift = "Emergency lift 120 studs",
			reset_errors = "Reset error counters", restart_farm = "Restart the farm",
			rejoin = "Rejoin another server", low_graphics = "Turn on low graphics",
			stop_conflict = "Stop one of the farms", pause_farm = "Pause the farm and check settings",
			equip_weapon = "Equip a weapon", wait = "Wait it out",
		},
		AR = {
			stuck = "علكان بمكانه", danger = "بخطر (الدم ديقل)", falling_void = "دا يوكع بالفراغ",
			dying_repeatedly = "يموت هواية", crash_loop = "أخطاء تتكرر",
			module_failed = "موديول فارم وكف بخطأ", no_progress = "الفارم شغال بس ماكو تقدم",
			network_lag = "لاك بالنت (بنك عالي)", low_performance = "FPS واطي",
			server_degraded = "سيرفر قديم / خربان", conflict = "فارمين يتعاركون",
			slowing_down = "الفارم دا يبطأ", waiting_too_long = "ينتظر هواية",
			goal_done = "وصل للهدف", idle = "ماكو فارم شغال", healthy = "كلشي تمام",
			cause_general = "عام", cause_path_blocked = "الطريق مسدود (يروح ويرجع)",
			cause_hovering = "يحوم بالجو", cause_no_weapon = "ماكو سلاح بيده",
			cause_low_fps = "FPS واطي", cause_imminent_death = "قريب يموت",
			cause_player_attack = "لاعبين قريبين", cause_boss_burst = "البوس ضربه قوي",
			cause_fall_deaths = "يموت من الوكعة", cause_pvp_deaths = "يموت يم اللاعبين",
			cause_under_geared = "أضعف من العدو", cause_same_error = "نفس الخطأ ينعاد",
			cause_unstable_server = "أخطاء هواية مختلفة", cause_goal_reached = "وصل للهدف",
			cause_target_immune = "الهدف ما ياخذ ضرر", cause_old_server = "سيرفر قديم",
			cause_memory = "الرام عالي", cause_in_menu = "علكان بالمنيو / الكيو",
			cause_spiky = "البنك يصعد وينزل", cause_render_heavy = "الجرافيك ثقيل",
			cause_status_error = "الموديول يكول خطأ",
			unstick = "قفزة + رفع 25", lift_up = "رجعه فوق الماب",
			retreat_up = "انسحاب 80 لفوك", emergency_lift = "رفع طوارئ 120",
			reset_errors = "تصفير عداد الأخطاء", restart_farm = "إعادة تشغيل الفارم",
			rejoin = "روح لسيرفر ثاني", low_graphics = "شغل الجرافيك الواطي",
			stop_conflict = "طفي واحد من الفارمات", pause_farm = "وكف الفارم وشوف الإعدادات",
			equip_weapon = "لبّس سلاح", wait = "انتظر شوية",
		},
	}

	function M.t(lang, key)
		local L = M.TEXT[lang] or M.TEXT.EN
		return L[key] or M.TEXT.EN[key] or tostring(key)
	end

	-- ================= المشاكل وفروع الأسباب =================
	-- severity: 1 خفيف، 2 متوسط، 3 خطر
	-- causes: كل سبب إله شروطه (all / any مثل القواعد) وقوته وأفعاله بالترتيب المفضل.
	--         السبب "general" (fallback) ياخذ الثقة الباقية إذا ولا سبب واضح.
	M.DIAGNOSES = {
		stuck = { severity = 2, causes = {
			{ id = "path_blocked", all = { "looping" }, strength = 0.9, actions = { "unstick", "restart_farm" } },
			{ id = "hovering", all = { "hovering" }, strength = 0.85, actions = { "restart_farm", "unstick" } },
			{ id = "no_weapon", all = { "weapon_missing" }, strength = 0.9, actions = { "equip_weapon", "restart_farm" } },
			{ id = "low_fps", all = { "fps_low" }, strength = 0.8, actions = { "low_graphics", "unstick" } },
			{ id = "general", fallback = true, strength = 0.9, actions = { "unstick", "restart_farm", "rejoin" } },
		} },
		danger = { severity = 3, causes = {
			{ id = "imminent_death", all = { "hp_ttz" }, strength = 0.95, actions = { "emergency_lift", "retreat_up" } },
			{ id = "player_attack", all = { "players_near", "!fighting" }, strength = 0.8, actions = { "retreat_up", "rejoin" } },
			{ id = "boss_burst", all = { "fighting", "hp_dropping" }, strength = 0.85, actions = { "retreat_up" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "retreat_up" } },
		} },
		falling_void = { severity = 3, causes = {
			{ id = "general", fallback = true, strength = 1.0, actions = { "lift_up" } },
		} },
		dying_repeatedly = { severity = 3, causes = {
			{ id = "fall_deaths", all = { "fell_recently" }, strength = 0.85, actions = { "lift_up", "pause_farm" } },
			{ id = "pvp_deaths", all = { "players_near" }, strength = 0.8, actions = { "rejoin", "pause_farm" } },
			{ id = "under_geared", all = { "fighting" }, strength = 0.75, actions = { "pause_farm" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "pause_farm" } },
		} },
		crash_loop = { severity = 2, causes = {
			{ id = "same_error", all = { "errors_repeat" }, strength = 0.9, actions = { "reset_errors", "restart_farm" } },
			{ id = "unstable_server", all = { "errors_high", "!errors_repeat" }, strength = 0.7, actions = { "rejoin", "reset_errors" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "reset_errors" } },
		} },
		module_failed = { severity = 2, causes = {
			{ id = "status_error", all = { "status_error" }, strength = 0.8, actions = { "restart_farm" } },
			{ id = "general", fallback = true, strength = 0.9, actions = { "restart_farm", "rejoin" } },
		} },
		no_progress = { severity = 1, causes = {
			{ id = "goal_reached", all = { "goal_reached" }, strength = 1.0, actions = { "pause_farm" } },
			{ id = "target_immune", all = { "same_target_long" }, strength = 0.85, actions = { "restart_farm" } },
			{ id = "no_weapon", all = { "weapon_missing" }, strength = 0.9, actions = { "equip_weapon" } },
			{ id = "low_fps", all = { "fps_low" }, strength = 0.6, actions = { "low_graphics" } },
			{ id = "old_server", all = { "server_old" }, strength = 0.6, actions = { "rejoin" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "restart_farm", "rejoin" } },
		} },
		slowing_down = { severity = 1, causes = {
			{ id = "memory", all = { "memory_high" }, strength = 0.85, actions = { "rejoin" } },
			{ id = "old_server", all = { "server_old" }, strength = 0.8, actions = { "rejoin" } },
			{ id = "low_fps", all = { "fps_low" }, strength = 0.7, actions = { "low_graphics" } },
			{ id = "general", fallback = true, strength = 0.7, actions = { "restart_farm" } },
		} },
		waiting_too_long = { severity = 1, causes = {
			{ id = "in_menu", all = { "in_menu" }, strength = 0.8, actions = { "restart_farm", "rejoin" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "restart_farm", "rejoin" } },
		} },
		network_lag = { severity = 1, causes = {
			{ id = "spiky", all = { "ping_spiky" }, strength = 0.8, actions = { "wait" } },
			{ id = "old_server", all = { "server_old" }, strength = 0.8, actions = { "rejoin" } },
			{ id = "general", fallback = true, strength = 0.8, actions = { "wait", "rejoin" } },
		} },
		low_performance = { severity = 1, causes = {
			{ id = "memory", all = { "memory_high" }, strength = 0.9, actions = { "rejoin" } },
			{ id = "render_heavy", all = { "!memory_high" }, strength = 0.8, actions = { "low_graphics" } },
		} },
		server_degraded = { severity = 1, causes = {
			{ id = "general", fallback = true, strength = 1.0, actions = { "rejoin" } },
		} },
		conflict = { severity = 2, causes = {
			{ id = "general", fallback = true, strength = 1.0, actions = { "stop_conflict" } },
		} },
		goal_done = { severity = 1, causes = {
			{ id = "general", fallback = true, strength = 1.0, actions = { "pause_farm" } },
		} },
	}

	-- auto: مسموح ينفذه وحده بوضع Auto-fix. evalAfter: بعد كم ثانية يحكم إذا نفع.
	-- free: ما ينحسب من الميزانية. notInDungeon / notInMenu: ممنوع بهالمكان
	M.ACTIONS = {
		unstick        = { auto = true,  cooldown = 25,  cost = 0.05, evalAfter = 15, notInMenu = true },
		lift_up        = { auto = true,  cooldown = 8,   cost = 0.05, evalAfter = 8, notInMenu = true },
		retreat_up     = { auto = false, cooldown = 20,  cost = 0.20, evalAfter = 15, notInMenu = true },
		emergency_lift = { auto = true,  cooldown = 30,  cost = 0.10, evalAfter = 8, notInMenu = true },
		reset_errors   = { auto = true,  cooldown = 60,  cost = 0.05, evalAfter = 60 },
		restart_farm   = { auto = true,  cooldown = 240, cost = 0.30, evalAfter = 90 },
		rejoin         = { auto = true,  cooldown = 900, cost = 0.70, evalAfter = nil, notInDungeon = true },
		low_graphics   = { auto = false, cooldown = 600, cost = 0.20, evalAfter = 60 },
		stop_conflict  = { auto = false, cooldown = 60,  cost = 0.30, evalAfter = 10 },
		pause_farm     = { auto = false, cooldown = 120, cost = 0.50, evalAfter = nil },
		equip_weapon   = { auto = true,  cooldown = 20,  cost = 0.05, evalAfter = 10, notInMenu = true },
		wait           = { auto = true,  cooldown = 120, cost = 0.00, evalAfter = 60, free = true },
	}

	-- كلمات بحالة الفارم معناها "ينتظر عمداً" / "خطأ"
	M.WAIT_WORDS = { "wait", "queue", "loading", "teleport", "joining", "lobby", "menu", "idle", "starting", "انتظار" }
	M.ERROR_WORDS = { "error", "fail", "crash", "خطأ" }

	-- ================= القواعد (المشاكل) =================
	-- all = كل الشروط لازم (AND = أقل درجة)، "!" = مو (NOT = 1 - الدرجة)
	-- any = واحد منهم يكفي (OR = أعلى درجة). layer = الطبقة (تبني على اللي قبلها)
	M.RULES = {
		-- طبقة 1: أسباب أساسية
		{ id = "lag+still",  layer = 1, all = { "still", "ping_high" }, conclude = "network_lag", strength = 0.8 },
		{ id = "lag",        layer = 1, all = { "ping_high" }, conclude = "network_lag", strength = 0.5 },
		{ id = "lag-spiky",  layer = 1, all = { "ping_high", "ping_spiky" }, conclude = "network_lag", strength = 0.6 },
		{ id = "fps",        layer = 1, all = { "fps_low" }, conclude = "low_performance", strength = 0.9 },
		-- طبقة 2: المشاكل
		{ id = "stuck",      layer = 2, all = { "farm_active", "!fighting", "!waiting", "!network_lag", "!dead" }, any = { "still", "looping", "hovering" }, conclude = "stuck", strength = 0.9 },
		{ id = "danger",     layer = 2, all = { "hp_low", "hp_dropping", "!dead" }, conclude = "danger", strength = 0.9 },
		{ id = "danger-fight", layer = 2, all = { "hp_low", "fighting", "!dead" }, conclude = "danger", strength = 0.5 },
		{ id = "danger-ttz", layer = 2, all = { "hp_ttz", "!dead" }, conclude = "danger", strength = 0.9 },
		{ id = "void",       layer = 2, all = { "falling", "deep_void" }, conclude = "falling_void", strength = 0.95 },
		{ id = "long-fall",  layer = 2, all = { "falling", "!fighting" }, conclude = "falling_void", strength = 0.35 },
		{ id = "deaths",     layer = 2, all = { "died_recently" }, conclude = "dying_repeatedly", strength = 0.85 },
		{ id = "crash",      layer = 2, all = { "errors_high", "errors_repeat" }, conclude = "crash_loop", strength = 0.9 },
		{ id = "errors",     layer = 2, all = { "errors_high" }, conclude = "crash_loop", strength = 0.4 },
		{ id = "module",     layer = 2, all = { "module_failed_flag" }, conclude = "module_failed", strength = 1.0 },
		{ id = "status-err", layer = 2, all = { "farm_active", "status_error" }, conclude = "module_failed", strength = 0.6 },
		{ id = "conflict",   layer = 2, all = { "multi_farm" }, conclude = "conflict", strength = 1.0 },
		{ id = "waiting-long", layer = 2, all = { "farm_active", "waiting_long" }, conclude = "waiting_too_long", strength = 0.85 },
		{ id = "goal",       layer = 2, all = { "goal_reached" }, conclude = "goal_done", strength = 1.0 },
		{ id = "idle",       layer = 2, all = { "!farm_active" }, conclude = "idle", strength = 1.0 },
		-- طبقة 3: مشاكل مبنية على مشاكل
		{ id = "no-progress", layer = 3, all = { "farm_active", "progress_flat", "!stuck", "!waiting", "!dead", "!conflict", "!goal_done" }, conclude = "no_progress", strength = 0.8 },
		{ id = "slower",     layer = 3, all = { "farm_active", "efficiency_drop", "!stuck", "!waiting" }, conclude = "slowing_down", strength = 0.8 },
		{ id = "danger-loop", layer = 3, all = { "dying_repeatedly", "danger" }, conclude = "dying_repeatedly", strength = 0.5 },
		{ id = "stuck-fps",  layer = 3, all = { "stuck", "low_performance" }, conclude = "low_performance", strength = 0.4 },
		{ id = "old-server", layer = 3, all = { "server_old" }, any = { "network_lag", "low_performance", "no_progress", "slowing_down" }, conclude = "server_degraded", strength = 0.8 },
		{ id = "memory-perf", layer = 3, all = { "memory_high", "farm_active" }, conclude = "low_performance", strength = 0.5 },
		-- طبقة 4: الخلاصة
		{ id = "healthy",    layer = 4, all = { "farm_active", "!stuck", "!danger", "!crash_loop", "!no_progress", "!falling_void", "!conflict", "!dying_repeatedly", "!module_failed", "!waiting_too_long", "!slowing_down" }, conclude = "healthy", strength = 1.0 },
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
		B.stats = opt.stats or {}              -- التعلم: "diag|action" و "diag/cause|action" -> { s, n }
		B.mem = {
			hp = M.newSeries(120), y = M.newSeries(60), fps = M.newSeries(60), ping = M.newSeries(60),
		}
		B.st = {
			lastMoveT = nil, anchor = nil, fallStart = nil, lastFallT = nil, wasAlive = true,
			lastProgressT = nil, progressKey = nil, farmSince = nil, farmKey = "",
			deaths = {}, errors = {}, path = {}, progressEvents = {},
			target = nil, targetSince = nil, waitSince = nil, noToolSince = nil,
		}
		B.facts = {}
		B.causes = {}    -- diag -> { { id, cf, text, actions }, ... }
		B.options = {}   -- كل البدائل مرتبة (أحسن 6)
		B.snap = nil
		B.now = 0
		B.cooldowns = {}
		B.pending = {}
		B.history = {}   -- آخر الأفعال: { t, diag, cause, action, auto, result }
		B.autoLog = {}   -- أوقات الأفعال التلقائية (للميزانية)
		B.autoBudget = opt.autoBudget or 6     -- أكثر شي 6 أفعال تلقائية...
		B.budgetWindow = opt.budgetWindow or 600 -- ...بكل 10 دقايق
		B.plan = nil
		B.ticks = 0
		return B
	end

	local function isWaitingStatus(status)
		status = string.lower(tostring(status or ""))
		if status == "" then return false end
		for _, w in ipairs(M.WAIT_WORDS) do
			if string.find(status, w, 1, true) then return true end
		end
		return false
	end

	-- 1) الملاحظة
	function Brain:observe(s)
		local t = s.t
		local st, mem = self.st, self.mem
		self.now = t
		self.snap = s
		self.ticks = self.ticks + 1

		-- الحركة: من آخر مرة ابتعد أكثر من 4 عن نقطة الارتكاز + المسار (آخر 40 ثانية)
		if s.pos then
			if not st.anchor then
				st.anchor, st.lastMoveT = s.pos, t
			elseif dist(s.pos, st.anchor) > 4 then
				st.anchor, st.lastMoveT = s.pos, t
			end
			mem.y:push(t, s.pos.y)
			st.path[#st.path + 1] = { t = t, x = s.pos.x, y = s.pos.y, z = s.pos.z }
			while st.path[1] and st.path[1].t < t - 40 do table.remove(st.path, 1) end
		end

		-- الطيحة
		if s.vy and s.vy < -60 then
			st.fallStart = st.fallStart or t
			st.lastFallT = t
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

		-- الهدف: من متى نفس الهدف
		local target = (s.target and s.target ~= "" and s.target ~= "-") and s.target or nil
		if target ~= st.target then st.target, st.targetSince = target, t end

		-- السلاح
		if s.toolEquipped == false then st.noToolSince = st.noToolSince or t else st.noToolSince = nil end

		-- الانتظار
		local waiting = isWaitingStatus(s.status) or s.placeKind == "menu" or s.placeKind == "universe"
		if waiting then st.waitSince = st.waitSince or t else st.waitSince = nil end

		-- الفارم والتقدم: أي تغيير بالأرقام (لفل، فلوس، قتلات، موجة...) = تقدم
		local farms = s.farms or {}
		local farmKey = table.concat(farms, ",")
		if #farms == 0 then
			st.farmSince, st.lastProgressT = nil, nil
			st.progressEvents = {}
		elseif farmKey ~= st.farmKey or not st.farmSince then
			st.farmSince, st.lastProgressT = t, t
			st.progressEvents = {}
		end
		st.farmKey = farmKey
		local keys = {}
		for k in pairs(s.progress or {}) do keys[#keys + 1] = k end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(s.progress[k]) end
		local pkey = table.concat(parts, ";")
		if pkey ~= st.progressKey then
			if st.progressKey ~= nil and #farms > 0 then
				st.lastProgressT = t
				st.progressEvents[#st.progressEvents + 1] = t
			end
			st.progressKey = pkey
		end
		while st.progressEvents[1] and st.progressEvents[1] < t - 900 do table.remove(st.progressEvents, 1) end

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
		local farmOn = #farms > 0

		setFact(f, "farm_active", farmOn and 1 or 0, "active: " .. (farmOn and table.concat(farms, ", ") or "none"))

		local alive = s.alive ~= false and (s.hp == nil or s.hp > 0)
		setFact(f, "dead", alive and 0 or 1, alive and "alive" or "character dead")

		-- الحركة
		local stillFor = st.lastMoveT and (t - st.lastMoveT) or 0
		setFact(f, "still", R(stillFor, 6, 20), string.format("did not move for %ds", math.floor(stillFor)))

		-- يروح ويرجع (المسافة اللي مشاها كبيرة بس الصافي صغير) = طريق مسدود
		local traveled, net, ys = 0, 0, {}
		local path = st.path
		local from = nil
		for i = 1, #path do
			if path[i].t >= t - 30 then
				if from then traveled = traveled + dist(path[i], path[i - 1]) else from = i end
				ys[#ys + 1] = path[i].y
			end
		end
		if from then net = dist(path[#path], path[from]) end
		local loopScore = 0
		if traveled > 60 then loopScore = R(traveled / math.max(net, 1), 4, 10) end
		setFact(f, "looping", loopScore, string.format("moved %d but only %d away (30s)", math.floor(traveled), math.floor(net)))

		-- يحوم: أفقياً ما يتحرك بس فوك وجوة
		local horiz = 0
		if from then
			local a, b = path[from], path[#path]
			horiz = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		end
		local ystd = mem.y:stdev(20, t)
		setFact(f, "hovering", (horiz < 6 and #ys >= 10) and R(ystd, 3, 10) or 0, string.format("height jumps %.1f, moved %d sideways", ystd, math.floor(horiz)))

		-- يقاتل؟ (هدف موجود، أو الدم يتغير، أو صار تقدم قريب)
		local fight, fwhy = 0, "no fight signs"
		if st.target then
			fight, fwhy = 0.8, "target: " .. tostring(st.target)
		end
		local maxHp = s.maxHp or 0
		if maxHp > 0 then
			local hpVar = R(mem.hp:stdev(20, t) / maxHp, 0.01, 0.05)
			if hpVar > fight then fight, fwhy = hpVar, "HP changing (" .. pct(hpVar) .. ")" end
		end
		if st.lastProgressT and farmOn then
			local recent = R(t - st.lastProgressT, 40, 10) * 0.7
			if recent > fight then fight, fwhy = recent, string.format("progress %ds ago", math.floor(t - st.lastProgressT)) end
		end
		setFact(f, "fighting", fight, fwhy)

		-- ينتظر عمداً؟
		local wait, wwhy = 0, "not waiting"
		if isWaitingStatus(s.status) then
			wait, wwhy = 1, "status: " .. tostring(s.status)
		elseif s.placeKind == "menu" or s.placeKind == "universe" then
			wait, wwhy = 0.8, "in " .. s.placeKind
		end
		setFact(f, "waiting", wait, wwhy)
		local waitFor = st.waitSince and (t - st.waitSince) or 0
		setFact(f, "waiting_long", R(waitFor, 240, 600), string.format("waiting for %dm", math.floor(waitFor / 60)))
		setFact(f, "in_menu", (s.placeKind == "menu" or s.placeKind == "universe") and 1 or 0, "place: " .. tostring(s.placeKind or "?"))

		-- الدم
		local hpFrac = (maxHp > 0 and s.hp) and (s.hp / maxHp) or 1
		setFact(f, "hp_low", R(hpFrac, 0.5, 0.15), "HP " .. pct(hpFrac))
		local dropPerSec = maxHp > 0 and -mem.hp:slope(6, t) or 0
		setFact(f, "hp_dropping", R(dropPerSec / math.max(maxHp, 1), 0.01, 0.06), string.format("HP %s/s", pct(-dropPerSec / math.max(maxHp, 1))))
		-- توقع: بعد كم ثانية يخلص الدم بهالسرعة
		local ttz = (dropPerSec > 0 and s.hp) and (s.hp / dropPerSec) or math.huge
		setFact(f, "hp_ttz", (ttz < math.huge) and R(ttz, 12, 3) or 0, ttz < math.huge and string.format("HP gone in ~%.0fs", ttz) or "HP stable")

		local d5 = 0
		for _, dt in ipairs(st.deaths) do if dt >= t - 300 then d5 = d5 + 1 end end
		setFact(f, "died_recently", R(d5, 0.5, 2), d5 .. " deaths in 5 min")

		local fallFor = st.fallStart and (t - st.fallStart) or 0
		setFact(f, "falling", R(fallFor, 1, 3.5), string.format("falling for %.1fs", fallFor))
		setFact(f, "fell_recently", st.lastFallT and R(t - st.lastFallT, 60, 5) or 0, st.lastFallT and string.format("fell %ds ago", math.floor(t - st.lastFallT)) or "no falls")
		local y = s.pos and s.pos.y or 0
		setFact(f, "deep_void", R(y, -30, -300), string.format("height %d", math.floor(y)))

		-- الأخطاء
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
		local status = string.lower(tostring(s.status or ""))
		local serr = 0
		for _, w in ipairs(M.ERROR_WORDS) do
			if status ~= "" and string.find(status, w, 1, true) then serr = 1 end
		end
		setFact(f, "status_error", serr, "status: " .. tostring(s.status or "-"))

		-- الأداء
		local fps = mem.fps:mean(10, t)
		setFact(f, "fps_low", R(fps or 60, 25, 8), "FPS " .. tostring(fps and math.floor(fps) or "?"))
		local ping = mem.ping:mean(15, t)
		setFact(f, "ping_high", R(ping or 0, 250, 800), "ping " .. tostring(ping and math.floor(ping) or "?") .. "ms")
		local pstd = mem.ping:stdev(20, t)
		setFact(f, "ping_spiky", R(pstd, 80, 300), string.format("ping jumps +-%d", math.floor(pstd)))
		setFact(f, "memory_high", R(s.memMb or 0, 2500, 4500), "memory " .. tostring(s.memMb and math.floor(s.memMb) or "?") .. "MB")

		-- التقدم
		local flatFor = (st.lastProgressT and farmOn) and (t - st.lastProgressT) or 0
		setFact(f, "progress_flat", R(flatFor, 120, 480), string.format("no progress for %dm %ds", math.floor(flatFor / 60), math.floor(flatFor % 60)))
		local recentP, prevP = 0, 0
		for _, pt in ipairs(st.progressEvents) do
			if pt >= t - 300 then recentP = recentP + 1 elseif pt >= t - 600 then prevP = prevP + 1 end
		end
		local eff = 0
		if st.farmSince and t - st.farmSince >= 600 and prevP >= 5 then eff = R(recentP / prevP, 0.6, 0.2) end
		setFact(f, "efficiency_drop", eff, string.format("progress %d (last 5m) vs %d (before)", recentP, prevP))
		local sameFor = st.targetSince and st.target and (t - st.targetSince) or 0
		setFact(f, "same_target_long", R(sameFor, 90, 240), string.format("same target for %ds", math.floor(sameFor)))
		setFact(f, "goal_reached", s.goalReached and 1 or 0, s.goalReached and "goal reached" or "goal not reached")
		setFact(f, "weapon_missing", (farmOn and st.noToolSince) and R(t - st.noToolSince, 5, 20) or 0,
			st.noToolSince and string.format("no weapon for %ds", math.floor(t - st.noToolSince)) or "weapon ok")

		-- السيرفر والمكان
		local age = (s.serverAge or 0) / 3600
		setFact(f, "server_old", R(age, 2, 6), string.format("server age %.1fh", age))
		setFact(f, "players_near", R(s.playersNear or 0, 0.5, 3), tostring(s.playersNear or 0) .. " players near")
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
	M.premise = premise

	-- 3) الاستنتاج: طبقة طبقة، والثقة تنجمع (MYCIN)
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

	-- 4) الأسباب: لكل مشكلة، شكد كل فرع محتمل
	function Brain:diagnose()
		self.causes = {}
		for name, meta in pairs(M.DIAGNOSES) do
			local fct = self.facts[name]
			if fct and fct.cf >= self.threshold then
				local list, maxSpecific = {}, 0
				for _, c in ipairs(meta.causes) do
					if not c.fallback then
						local p, text = premise(self.facts, c)
						local cf = math.min(fct.cf, p) * (c.strength or 1)
						if cf > maxSpecific then maxSpecific = cf end
						list[#list + 1] = { id = c.id, cf = cf, text = text, actions = c.actions }
					end
				end
				for _, c in ipairs(meta.causes) do
					if c.fallback then
						list[#list + 1] = { id = c.id, cf = fct.cf * (1 - maxSpecific) * (c.strength or 1), text = "no clear cause", actions = c.actions, fallback = true }
					end
				end
				table.sort(list, function(a, b) return a.cf > b.cf end)
				self.causes[name] = list
			end
		end
		return self.causes
	end

	-- نسبة النجاح المتوقعة: للسبب إذا عنده خبرة، وإلا للمشكلة، وإلا 50%
	function Brain:expected(diag, action, cause)
		local s = cause and self.stats[diag .. "/" .. cause .. "|" .. action]
		if s and s.n > 0 then return (s.s + 1) / (s.n + 2), s.n, "cause" end
		s = self.stats[diag .. "|" .. action]
		if s and s.n > 0 then return (s.s + 1) / (s.n + 2), s.n, "problem" end
		return 0.5, 0, "prior"
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
				list[#list + 1] = { name = name, cf = fct.cf, severity = meta.severity, chain = fct.chain or {}, causes = self.causes[name] or {} }
			end
		end
		table.sort(list, function(a, b)
			local sa, sb = a.cf * a.severity, b.cf * b.severity
			if sa == sb then return a.name < b.name end
			return sa > sb
		end)
		return list
	end

	-- 5) القرار: كل (مشكلة -> سبب -> فعل)
	function Brain:decide()
		local opts = {}
		local inDungeon = self.facts.in_dungeon and self.facts.in_dungeon.cf >= 1
		local inMenu = self.facts.in_menu and self.facts.in_menu.cf >= 1
		for _, p in ipairs(self:problems()) do
			for _, c in ipairs(p.causes) do
				if c.cf >= 0.2 then
					for idx, aid in ipairs(c.actions) do
						local a = M.ACTIONS[aid]
						local ready = (self.cooldowns[aid] or -math.huge) <= self.now
						local allowed = not (a.notInDungeon and inDungeon) and not (a.notInMenu and inMenu)
						if ready and allowed then
							local exp, n, from = self:expected(p.name, aid, c.id)
							local pref = 1 - (idx - 1) * 0.15
							local score = c.cf * (p.severity / 3) * exp * pref - a.cost * 0.3
							opts[#opts + 1] = {
								diag = p.name, cause = c.id, action = aid, score = score, cf = c.cf, problemCf = p.cf,
								expected = exp, tries = n, learnedFrom = from, auto = a.auto, chain = p.chain, causeText = c.text,
							}
						end
					end
				end
			end
		end
		table.sort(opts, function(a, b) return a.score > b.score end)
		while #opts > 6 do table.remove(opts) end
		self.options = opts
		self.plan = opts[1]
		return self.plan
	end

	-- تسجيل إن الفعل انفذ (حتى نتعلم من نتيجته)
	function Brain:executed(plan, auto)
		local a = M.ACTIONS[plan.action]
		self.cooldowns[plan.action] = self.now + (a.cooldown or 30)
		if auto and not a.free then self.autoLog[#self.autoLog + 1] = self.now end
		local h = { t = self.now, diag = plan.diag, cause = plan.cause or "general", action = plan.action, auto = auto == true, result = "pending" }
		self.history[#self.history + 1] = h
		while #self.history > 30 do table.remove(self.history, 1) end
		if a.evalAfter then
			self.pending[#self.pending + 1] = { at = self.now + a.evalAfter, diag = plan.diag, cause = h.cause, action = plan.action, h = h }
		else
			h.result = "done"
		end
		while self.autoLog[1] and self.autoLog[1] < self.now - self.budgetWindow do table.remove(self.autoLog, 1) end
	end

	local function bump(stats, key, ok)
		local s = stats[key] or { s = 0, n = 0 }
		s.n = s.n + 1
		if ok then s.s = s.s + 1 end
		stats[key] = s
	end

	-- 6) التعلم: المشكلة راحت بعد الفعل؟ = نجح. يتعلم للسبب وللمشكلة
	function Brain:learn()
		local keep, learned = {}, {}
		for _, p in ipairs(self.pending) do
			if self.now >= p.at then
				local fct = self.facts[p.diag]
				local ok = not fct or fct.cf < 0.3
				bump(self.stats, p.diag .. "|" .. p.action, ok)
				bump(self.stats, p.diag .. "/" .. p.cause .. "|" .. p.action, ok)
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
		self:diagnose()
		local learned = self:learn()
		return self:decide(), learned
	end

	-- 7) الشرح
	function Brain:summary()
		local probs = self:problems()
		if #probs == 0 then
			local idle = self.facts.idle
			if idle and idle.cf >= 0.5 then return M.t(self.lang, "idle") end
			return M.t(self.lang, "healthy")
		end
		local p = probs[1]
		local c = p.causes[1]
		return M.t(self.lang, p.name) .. " (" .. pct(p.cf) .. ")" .. ((c and not c.fallback) and (" <- " .. M.t(self.lang, "cause_" .. c.id)) or "")
	end

	-- الشجرة: مشكلة -> ليش -> الأسباب -> الفعل
	function Brain:explain(maxLines)
		maxLines = maxLines or 14
		local out = {}
		local L = self.lang
		local probs = self:problems()
		if #probs == 0 then out[#out + 1] = self:summary() end
		for _, p in ipairs(probs) do
			out[#out + 1] = "# " .. M.t(L, p.name) .. " " .. pct(p.cf)
			if p.chain[1] then out[#out + 1] = "  why: " .. p.chain[1] end
			local parts = {}
			for i, c in ipairs(p.causes) do
				if i <= 4 then parts[#parts + 1] = M.t(L, "cause_" .. c.id) .. " " .. pct(c.cf) .. (i == 1 and " *" or "") end
			end
			out[#out + 1] = "  cause: " .. table.concat(parts, " | ")
			if self.plan and self.plan.diag == p.name then
				out[#out + 1] = "  do: " .. M.t(L, self.plan.action) .. " (works " .. pct(self.plan.expected) .. ", " .. self.plan.learnedFrom .. ")"
			end
		end
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
		local L = self.lang
		return M.t(L, plan.action) .. "  [" .. M.t(L, plan.diag) .. " <- " .. M.t(L, "cause_" .. (plan.cause or "general"))
			.. ", " .. pct(plan.cf) .. ", works " .. pct(plan.expected) .. " of " .. plan.tries .. " tries]"
	end

	-- ================= الأسئلة =================
	M.INTENTS = {
		{ id = "history",  words = { "history", "did you do", "شسويت", "سويت", "تاريخ" } },
		{ id = "learn",    words = { "learn", "stats", "memory", "تعلم", "تعلمت", "احصائيات", "ذاكرة" } },
		{ id = "tree",     words = { "tree", "think", "شجرة", "تفكر", "تفكير" } },
		{ id = "cause",    words = { "cause", "reason", "سبب", "اسباب", "أسباب" } },
		{ id = "plan",     words = { "plan", "options", "next", "خطة", "خطه", "بدائل", "الجاي" } },
		{ id = "why",      words = { "why", "problem", "wrong", "stuck", "ليش", "مشكلة", "مشكله", "شبي", "شبيه", "واكف", "علك", "خربان", "شنو صاير" } },
		{ id = "advice",   words = { "what should", "advice", "suggest", "fix", "help", "شسوي", "نصيحة", "نصيحه", "اقترح", "صلح", "ساعد" } },
		{ id = "errors",   words = { "error", "bug", "crash", "خطأ", "خطا", "اغلاط", "أخطاء", "اخطاء" } },
		{ id = "progress", words = { "progress", "level", "xp", "peli", "kills", "تقدم", "لفل", "فلوس", "قتل" } },
		{ id = "perf",     words = { "fps", "lag", "ping", "slow", "ram", "لاك", "بنك", "تقطيع", "بطيء", "بطيئ", "رام" } },
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
		local L = self.lang
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
			local lines = { (AR and "المشكلة: " or "Problem: ") .. M.t(L, p.name) .. " (" .. pct(p.cf) .. ")" }
			lines[#lines + 1] = AR and "الأسباب:" or "Because:"
			for i = 1, math.min(3, #p.chain) do lines[#lines + 1] = "- " .. p.chain[i] end
			local c = p.causes[1]
			if c then lines[#lines + 1] = (AR and "السبب الأرجح: " or "Most likely cause: ") .. M.t(L, "cause_" .. c.id) .. " (" .. pct(c.cf) .. ")" end
			return table.concat(lines, "\n")
		elseif intent == "cause" then
			if #probs == 0 then return AR and "ماكو مشكلة حتى أدور سببها." or "No problem to find a cause for." end
			local p = probs[1]
			local lines = { (AR and "أسباب محتملة لـ " or "Possible causes of ") .. M.t(L, p.name) .. ":" }
			for _, c in ipairs(p.causes) do
				lines[#lines + 1] = "- " .. M.t(L, "cause_" .. c.id) .. " " .. pct(c.cf) .. (c.fallback and "" or (" (" .. c.text .. ")"))
			end
			return table.concat(lines, "\n")
		elseif intent == "tree" then
			return table.concat(self:explain(20), "\n")
		elseif intent == "plan" then
			if #self.options == 0 then return AR and "ماكو خطة، كلشي ماشي." or "No plan needed, all good." end
			local lines = { AR and "البدائل (الأحسن أول):" or "Options (best first):" }
			for i, o in ipairs(self.options) do
				lines[#lines + 1] = i .. ") " .. M.t(L, o.action) .. " <- " .. M.t(L, "cause_" .. o.cause) .. string.format(" [%.2f]", o.score)
			end
			return table.concat(lines, "\n")
		elseif intent == "history" then
			if #self.history == 0 then return AR and "بعدني ما سويت أي شي." or "I have not done anything yet." end
			local lines = { AR and "آخر اللي سويته:" or "What I did lately:" }
			for i = #self.history, math.max(1, #self.history - 4), -1 do
				local h = self.history[i]
				lines[#lines + 1] = string.format("- %ds: %s <- %s (%s)", math.floor(self.now - h.t), M.t(L, h.action), M.t(L, h.diag), h.result)
			end
			return table.concat(lines, "\n")
		elseif intent == "advice" then
			local plan = self.plan
			if not plan then
				return AR and "ما أنصح بشي هسه، كلشي ماشي." or "Nothing to do right now, all good."
			end
			return (AR and "أنصح: " or "I suggest: ") .. self:planText(plan)
		elseif intent == "errors" then
			return (AR and "الأخطاء: " or "Errors: ") .. why("errors_high") .. ", " .. why("errors_repeat") .. ", " .. why("status_error")
		elseif intent == "progress" then
			return (AR and "التقدم: " or "Progress: ") .. why("progress_flat") .. " | " .. why("efficiency_drop") .. " | " .. why("farm_active")
		elseif intent == "perf" then
			return (AR and "الأداء: " or "Performance: ") .. why("fps_low") .. ", " .. why("ping_high") .. ", " .. why("ping_spiky") .. ", " .. why("memory_high") .. ", " .. why("server_old")
		elseif intent == "learn" then
			local keys = {}
			for k in pairs(self.stats) do
				if not string.find(k, "/", 1, true) then keys[#keys + 1] = k end
			end
			table.sort(keys)
			if #keys == 0 then
				return AR and "بعدني ما جربت أي فعل، ما تعلمت شي لهسه." or "I have not tried any fix yet, nothing learned."
			end
			local lines = { AR and "اللي تعلمته (نجح/جرب):" or "What I learned (worked/tried):" }
			for _, k in ipairs(keys) do
				local s = self.stats[k]
				local d, a = string.match(k, "^(.-)|(.*)$")
				lines[#lines + 1] = "- " .. M.t(L, d) .. " -> " .. M.t(L, a) .. ": " .. s.s .. "/" .. s.n
			end
			return table.concat(lines, "\n")
		end
		-- status
		return (AR and "الحالة: " or "Status: ") .. self:summary() .. " | " .. why("farm_active") .. " | " .. why("hp_low")
			.. (cf("still") > 0.5 and (" | " .. why("still")) or "")
	end

	return M
end)()
