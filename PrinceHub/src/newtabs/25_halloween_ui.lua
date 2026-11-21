-- ------------------------------------------------------------
-- HALLOWEEN UI: "Dark Enchanted Night"  [PRINCE HUB v21]
-- ------------------------------------------------------------
-- مبني على دليل docs/DESIGN.md (من البرومبت الاحترافي):
--   * الأجواء أهم من الزخرفة: عنصر رئيسي واحد (قمر كبير خافت ورا الغيوم) + عنصرين مساعدين
--     (ضباب يمشي ببطء، شرارات صغيرة). بدون إيموجي كأيقونات: القرع مرسوم بـ Frames.
--   * البرتقالي بس للعناصر النشطة (التبويب المختار، التوكل، السلايدر، الشريط بالإشعار).
--     البنفسجي/اللافندر للمسة السحرية (عناوين البطاقات، حافة النافذة).
--   * بطاقات بخلفية أفتح درجة من الخلفية، حدود رفيعة، زوايا موحدة، ظل ناعم للنافذة.
--   * حركة قصيرة وهادئة، وتنطفي من Config > Prince Hub > Animations (تقليل الحركة).
-- محرك Linoria نفسه، فكل التبويبات والأزرار والكونفكات تشتغل مثل ما هي.
-- الثيم ينختار من Config > Prince Hub > Theme (Halloween / Classic)، ويتطبق بالتحميل الجاي.
US.theme = (US.theme == "Classic") and "Classic" or "Halloween"
US.motion = US.motion ~= false
PrinceNewTabs.theme = US.theme

local function hwHex(h)
	return Color3.fromRGB(tonumber(string.sub(h, 2, 3), 16), tonumber(string.sub(h, 4, 5), 16), tonumber(string.sub(h, 6, 7), 16))
end

local PN_Halloween = {
	-- ===== Design tokens =====
	C = {
		bg = hwHex("#0B0A10"),        -- Midnight Black: الخلفية الرئيسية
		bg2 = hwHex("#15131D"),       -- Deep Charcoal: خلفية ثانوية (مكان المحتوى)
		surface = hwHex("#211A2B"),   -- Haunted Plum: البطاقات
		raised = hwHex("#2C2038"),    -- Dark Violet: سطح مرتفع (عناصر، تبويب مختار)
		line = hwHex("#3A2D4A"),      -- حدود رفيعة
		primary = hwHex("#FF7518"),   -- Pumpkin Orange: العناصر النشطة بس
		ember = hwHex("#FF9A3D"),     -- Ember Glow
		purple = hwHex("#8B5CF6"),    -- Witch Purple
		lavender = hwHex("#C4A7FF"),  -- Ghost Lavender
		text = hwHex("#F5F0FA"),      -- Moonlight: النص الرئيسي
		text2 = hwHex("#B5ADBF"),     -- Mist Gray: النص الثانوي
		muted = hwHex("#827A8B"),     -- Ash Gray: النص الخافت
		success = hwHex("#75D6A1"), warning = hwHex("#F2C66D"), danger = hwHex("#F06A75"),
		moon = hwHex("#F3E9D2"), stem = hwHex("#5B7F3A"), pumpkinDark = hwHex("#C2410C"), carve = hwHex("#FFD27A"),
	},
	S = { xs = 4, sm = 8, md = 12, lg = 16 },          -- المسافات
	R = { sm = 4, md = 6, lg = 8, xl = 12 },            -- الزوايا
	M = { fast = 0.12, base = 0.18, slow = 0.35 },      -- مدة الحركة (ثواني)
	maxEmbers = 8,
	applied = false,
}
local HW = PN_Halloween

function HW.on()
	return PrinceNewTabs.theme == "Halloween"
end

function HW.motion()
	return US.motion ~= false
end

-- ===== أدوات صغيرة =====
local function hwMake(className, props, parent)
	local obj = Instance.new(className)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function hwCorner(obj, r)
	if obj:FindFirstChild("HWCorner") then return end
	hwMake("UICorner", { Name = "HWCorner", CornerRadius = (r == "full") and UDim.new(1, 0) or UDim.new(0, r or HW.R.lg) }, obj)
end

local function hwStroke(obj, color, thickness, transparency)
	local s = obj:FindFirstChild("HWStroke") or hwMake("UIStroke", { Name = "HWStroke" }, obj)
	s.Color = color or HW.C.line
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function hwGradient(obj, c1, c2, rotation, t1, t2)
	local g = hwMake("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 90,
	}, obj)
	if t1 then
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t1), NumberSequenceKeypoint.new(1, t2 or t1) })
	end
	return g
end

local function hwTween(obj, time, goal, style)
	local ok, tw = pcall(function()
		return game:GetService("TweenService"):Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	end)
	if ok and tw then tw:Play() end
	return tw
end

local function hwCircle(parent, size, pos, color, transparency, z)
	local c = hwMake("Frame", {
		Size = size, Position = pos, BackgroundColor3 = color, BackgroundTransparency = transparency,
		BorderSizePixel = 0, ZIndex = z or 0,
	}, parent)
	hwCorner(c, "full")
	return c
end

-- ===== القرع المرسوم (بدون إيموجي) =====
-- جسم بتدرج + ضلعين + عنق + وجه منحوت مضوي. size = العرض بالبكسل
function HW.pumpkin(parent, size, z, position)
	local C = HW.C
	local root = hwMake("Frame", {
		Name = "HWPumpkin", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size), Position = position or UDim2.fromOffset(0, 0), ZIndex = z,
	}, parent)
	local bh = math.floor(size * 0.8)
	local body = hwMake("Frame", {
		Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, bh), Position = UDim2.fromOffset(0, size - bh), ZIndex = z,
	}, root)
	hwCorner(body, "full")
	hwGradient(body, C.ember, C.pumpkinDark, 90)
	for _, x in ipairs({ 0.3, 0.7 }) do
		local rib = hwMake("Frame", {
			Name = "Rib", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.pumpkinDark, BackgroundTransparency = 0.55,
			BorderSizePixel = 0, Size = UDim2.new(0, math.max(1, math.floor(size * 0.08)), 0.8, 0), Position = UDim2.new(x, 0, 0.1, 0), ZIndex = z + 1,
		}, body)
		hwCorner(rib, "full")
	end
	local stem = hwMake("Frame", {
		Name = "Stem", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.stem, BorderSizePixel = 0,
		Size = UDim2.fromOffset(math.max(2, math.floor(size * 0.14)), math.max(3, math.floor(size * 0.26))),
		Position = UDim2.new(0.5, 1, 0, 0), Rotation = 12, ZIndex = z + 1,
	}, root)
	hwCorner(stem, HW.R.sm)
	if size >= 14 then
		local e = math.max(2, math.floor(size * 0.16))
		for _, x in ipairs({ 0.32, 0.68 }) do
			hwMake("Frame", {
				Name = "Eye", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.carve, BorderSizePixel = 0,
				Size = UDim2.fromOffset(e, e), Position = UDim2.new(x, 0, 0.42, 0), Rotation = 45, ZIndex = z + 2,
			}, body)
		end
		local mouth = hwMake("Frame", {
			Name = "Mouth", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.carve, BorderSizePixel = 0,
			Size = UDim2.new(0.46, 0, 0, math.max(2, math.floor(size * 0.1))), Position = UDim2.new(0.5, 0, 0.7, 0), ZIndex = z + 2,
		}, body)
		hwCorner(mouth, "full")
	end
	return root
end

-- ===== الألوان بالمكتبة (قبل ما تنبني النافذة) =====
function HW.palette(Library)
	local C = HW.C
	Library.FontColor = C.text
	Library.MainColor = C.raised
	Library.BackgroundColor = C.surface
	Library.AccentColor = C.primary
	Library.OutlineColor = C.line
	-- ألوان إضافية للـ registry (تنستعمل بأسمائها)
	Library.HWLavender = C.lavender
	Library.HWText2 = C.text2
	Library.HWPurple = C.purple
	pcall(function() Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor) end)
end
-- الهب يستدعيها قبل ما يبني النافذة (حتى العناصر تنخلق بالألوان الجديدة)
PrinceNewTabs.applyPalette = function(Library) HW.palette(Library) end

-- لون حالة (Prince AI وغيره): ما نعتمد على اللون بس، النص يكول الحالة هم
function HW.statusColor(level)
	local C = HW.C
	if level == "ok" then return C.success end
	if level == "warn" then return C.warning end
	if level == "bad" then return C.danger end
	if level == "busy" then return C.ember end
	return C.text2
end
PrinceNewTabs.hwStatusColor = function(level) if HW.on() then return HW.statusColor(level) end end

-- ===== البطاقات (groupboxes) =====
local function hwStyleBox(Library, box)
	if not box:IsA("Frame") or box:GetAttribute("HWStyled") then return end
	box:SetAttribute("HWStyled", true)
	box.BorderSizePixel = 0
	box.BackgroundTransparency = 0
	hwCorner(box, HW.R.lg)
	hwStroke(box, HW.C.line, 1, 0.1)
	local inner = box:FindFirstChildOfClass("Frame")
	if not inner then return end
	inner.BorderSizePixel = 0
	inner.BackgroundTransparency = 1
	hwCorner(inner, HW.R.lg)
	for _, ch in ipairs(inner:GetChildren()) do
		if ch:IsA("Frame") and ch.Size.Y.Offset == 2 and ch.Size.Y.Scale == 0 then
			-- الشريط اللي فوق: شريط لافندر قصير بدل خط برتقالي كامل
			ch.Size = UDim2.fromOffset(18, 2)
			ch.Position = UDim2.fromOffset(HW.S.sm, 0)
			ch.BackgroundColor3 = HW.C.lavender
			hwCorner(ch, "full")
			pcall(function() Library.RegistryMap[ch].Properties.BackgroundColor3 = "HWLavender" end)
		elseif ch:IsA("TextLabel") and ch.Position.Y.Offset == 2 then
			-- عنوان البطاقة (H2)
			ch.Font = Enum.Font.GothamBold
			ch.TextSize = 13
			ch.TextColor3 = HW.C.lavender
			pcall(function() Library.RegistryMap[ch].Properties.TextColor3 = "HWLavender" end)
		end
	end
end

-- ===== التبويبات =====
local function hwStyleTabButton(btn)
	if not btn:IsA("Frame") or btn:GetAttribute("HWStyled") then return end
	btn:SetAttribute("HWStyled", true)
	btn.BorderSizePixel = 0
	hwCorner(btn, HW.R.md)
	local bar = hwMake("Frame", {
		Name = "HWActiveBar", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = HW.C.primary, BorderSizePixel = 0,
		Size = UDim2.new(0.6, 0, 0, 2), Position = UDim2.new(0.5, 0, 1, 0), Visible = false, ZIndex = 4,
	}, btn)
	hwCorner(bar, "full")
end

-- التبويب النشط: خلفية مرتفعة + نص برتقالي + شريط تحت (مو اللون بس)
function HW.markTab(tabBar, name)
	for _, btn in ipairs(tabBar:GetChildren()) do
		if btn:IsA("Frame") then
			local label = btn:FindFirstChildOfClass("TextLabel")
			local active = label ~= nil and label.Text == name
			if label then label.TextColor3 = active and HW.C.primary or HW.C.text2 end
			btn.BackgroundTransparency = active and 0 or 0.35
			local bar = btn:FindFirstChild("HWActiveBar")
			if bar then bar.Visible = active end
		end
	end
end

-- انتقال ناعم بين التبويبات: المحتوى يطلع من تحت بـ 6 بكسل
function HW.slideIn(container)
	if not HW.motion() then return end
	for _, tf in ipairs(container:GetChildren()) do
		if tf.Name == "TabFrame" and tf.Visible then
			tf.Position = UDim2.fromOffset(0, 6)
			hwTween(tf, HW.M.base, { Position = UDim2.fromOffset(0, 0) })
		end
	end
end

-- ===== الخلفية: قمر + غيوم + ضباب + شرارات =====
local function hwBackground(inner)
	local C = HW.C
	local bg = hwMake("Frame", {
		Name = "HalloweenBG", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 0, ClipsDescendants = true,
	}, inner)
	hwCorner(bg, HW.R.xl)
	hwGradient(bg, C.bg, C.bg2, 90)

	-- إضاءة محيطة: بنفسجي تحت يسار، برتقالي خافت فوق يمين (حلقات شفافة = توهج ناعم)
	for i, tr in ipairs({ 0.93, 0.95, 0.97 }) do
		local s = 140 + i * 70
		hwCircle(bg, UDim2.fromOffset(s, s), UDim2.new(0, -s / 2, 1, -s / 2), C.purple, tr, 0)
	end
	for i, tr in ipairs({ 0.95, 0.965, 0.98 }) do
		local s = 120 + i * 60
		hwCircle(bg, UDim2.fromOffset(s, s), UDim2.new(1, -s / 2 - 70, 0, -s / 2 + 10), C.ember, tr, 0)
	end

	-- القمر الكبير (العنصر الرئيسي): خافت ورا الهيدر، ويا هالة وفوهات
	local moon = hwCircle(bg, UDim2.fromOffset(150, 150), UDim2.new(1, -190, 0, -64), C.moon, 0.86, 0)
	moon.Name = "HWMoon"
	hwCircle(moon, UDim2.fromOffset(26, 26), UDim2.fromOffset(38, 72), C.bg2, 0.92, 0)
	hwCircle(moon, UDim2.fromOffset(16, 16), UDim2.fromOffset(92, 98), C.bg2, 0.93, 0)
	hwCircle(bg, UDim2.fromOffset(200, 200), UDim2.new(1, -215, 0, -89), C.lavender, 0.965, 0)

	-- غيوم تعبر القمر
	local clouds = {}
	for i, info in ipairs({ { 170, 22, -250, 46 }, { 120, 16, -140, 22 } }) do
		local cl = hwMake("Frame", {
			Name = "HWCloud", BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25 + i * 0.1, BorderSizePixel = 0,
			Size = UDim2.fromOffset(info[1], info[2]), Position = UDim2.new(1, info[3], 0, info[4]), ZIndex = 0,
		}, bg)
		hwCorner(cl, "full")
		clouds[#clouds + 1] = cl
	end

	-- ضباب تحت: شريطين بشفافية متدرجة يمشون ببطء
	local fogs = {}
	for i = 1, 2 do
		local fog = hwMake("Frame", {
			Name = "HWFog", BackgroundColor3 = C.lavender, BorderSizePixel = 0,
			Size = UDim2.new(1.6, 0, 0, 70 + i * 20), Position = UDim2.new(-0.3 * i, 0, 1, -(70 + i * 20)), ZIndex = 0,
		}, bg)
		hwGradient(fog, C.lavender, C.lavender, 90, 1, 0.9 + i * 0.02)
		fogs[#fogs + 1] = fog
	end
	return bg, clouds, fogs
end

local function hwAmbientMotion(bg, outer, clouds, fogs)
	local alive = 0
	task.spawn(function()
		local tick0 = os.clock()
		while bg.Parent and outer.Parent do
			if outer.Visible and HW.motion() then
				local t = os.clock() - tick0
				-- الضباب والغيوم: حركة جيبية بطيئة جداً
				for i, fog in ipairs(fogs) do
					fog.Position = UDim2.new(-0.3 * i + math.sin(t / (14 + i * 6)) * 0.12, 0, 1, fog.Position.Y.Offset)
				end
				for i, cl in ipairs(clouds) do
					cl.Position = UDim2.new(1, cl.Position.X.Offset + math.sin(t / (9 + i * 4)) * 0.6, 0, cl.Position.Y.Offset)
				end
				-- شرارات صغيرة: قليلة، بطيئة، خافتة
				if alive < HW.maxEmbers and math.random() < 0.35 then
					alive = alive + 1
					local s = math.random(2, 3)
					local p = hwCircle(bg, UDim2.fromOffset(s, s), UDim2.new(math.random(4, 96) / 100, 0, 1, -math.random(4, 40)), HW.C.ember, 0.35, 0)
					p.Name = "HWEmber"
					local tw = hwTween(p, math.random(7, 12), {
						Position = UDim2.new(p.Position.X.Scale + math.random(-6, 6) / 100, 0, 0.25 + math.random() * 0.3, 0),
						BackgroundTransparency = 1,
					}, Enum.EasingStyle.Sine)
					local function done() alive = alive - 1; p:Destroy() end
					if tw then tw.Completed:Connect(done) else task.delay(8, done) end
				end
			end
			task.wait(0.25)
		end
	end)
end

-- ===== الهيدر: قرع + عنوان + بطاقة اللاعب + زر إغلاق =====
local function hwHeader(Library, inner, outer)
	local C = HW.C
	for _, ch in ipairs(inner:GetChildren()) do
		if ch:IsA("TextLabel") and ch.Position.Y.Offset == 0 and not ch:GetAttribute("HWOwn") then
			-- Display: خط Fantasy للعنوان القصير بس
			ch.Text = "PRINCE HUB"
			ch.Font = Enum.Font.Fantasy
			ch.TextSize = 18
			ch.Position = UDim2.fromOffset(30, 1)
			ch.TextColor3 = C.primary
			ch.TextStrokeTransparency = 1
			pcall(function() Library.RegistryMap[ch].Properties.TextColor3 = "AccentColor" end)
			break
		end
	end
	HW.pumpkin(inner, 16, 3, UDim2.fromOffset(9, 4))

	-- بطاقة اللاعب: حرف أول بدائرة + الاسم + حبة اللفل
	local card = hwMake("Frame", {
		Name = "HWProfile", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 3), Size = UDim2.new(0.5, 0, 0, 19), ZIndex = 3,
	}, inner)
	card:SetAttribute("HWOwn", true)
	hwMake("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
	}, card)
	local avatar = hwMake("TextLabel", {
		Name = "Avatar", LayoutOrder = 1, Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.raised, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.lavender, ZIndex = 3,
		Text = string.upper(string.sub(tostring(PN_LocalPlayer.DisplayName), 1, 1)),
	}, card)
	hwCorner(avatar, "full")
	hwStroke(avatar, C.purple, 1, 0.3)
	local name = hwMake("TextLabel", {
		Name = "PlayerName", LayoutOrder = 2, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text2,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(PN_LocalPlayer.DisplayName), ZIndex = 3,
	}, card)
	local pill = hwMake("TextLabel", {
		Name = "Level", LayoutOrder = 3, BackgroundColor3 = C.raised, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.ember, Text = "LV -", ZIndex = 3,
	}, card)
	hwCorner(pill, "full")
	hwMake("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, pill)
	task.spawn(function()
		while card.Parent do
			local lv = PN_statValue("Level")
			pill.Text = lv and ("LV " .. tostring(lv)) or "LV -"
			pill.Visible = lv ~= nil
			task.wait(5)
		end
	end)

	-- زر الإغلاق: Ghost (بدون خلفية) ويحمر عند المرور
	local close = outer:FindFirstChild("PrinceClose", true)
	if close then
		close.BackgroundColor3 = C.danger
		close.BackgroundTransparency = 1
		close.TextColor3 = C.text2
		close.Font = Enum.Font.GothamBold
		close.Position = UDim2.new(1, -25, 0, 3)
		pcall(function()
			close.MouseEnter:Connect(function()
				hwTween(close, HW.M.fast, { BackgroundTransparency = 0.15, TextColor3 = C.text })
			end)
			close.MouseLeave:Connect(function()
				hwTween(close, HW.M.fast, { BackgroundTransparency = 1, TextColor3 = C.text2 })
			end)
		end)
	end
end

-- ===== الزر المصغر: قرع مرسوم ويا توهج هادئ =====
local function hwMini(Library)
	local mini = Library.ScreenGui and Library.ScreenGui:FindFirstChild("PrinceMini")
	if not mini then return end
	mini.Text = ""
	mini.BackgroundColor3 = HW.C.surface
	mini.BackgroundTransparency = 0.1
	local c = mini:FindFirstChildOfClass("UICorner")
	if c then c.CornerRadius = UDim.new(1, 0) end
	local s = mini:FindFirstChildOfClass("UIStroke")
	if s then s.Color = HW.C.line; s.Thickness = 1.5 end
	local glow = hwCircle(mini, UDim2.new(1, 10, 1, 10), UDim2.fromOffset(-5, -5), HW.C.ember, 0.85, 99)
	glow.Name = "HWGlow"
	HW.pumpkin(mini, 30, 101, UDim2.fromOffset(8, 7))
	task.spawn(function()
		local up = true
		while mini.Parent do
			if mini.Visible and HW.motion() then
				hwTween(glow, 1.6, { BackgroundTransparency = up and 0.72 or 0.9 }, Enum.EasingStyle.Sine)
				up = not up
			end
			task.wait(1.6)
		end
	end)
end

-- ===== نافذة الـ stats =====
local function hwStats()
	local gui = getgenv().PrinceStatsGui
	local frame = gui and gui:FindFirstChild("PrinceStats")
	if not frame then return end
	frame.BackgroundColor3 = HW.C.surface
	local c = frame:FindFirstChildOfClass("UICorner")
	if c then c.CornerRadius = UDim.new(0, HW.R.lg) end
	local s = frame:FindFirstChildOfClass("UIStroke")
	if s then s.Color = HW.C.line; s.Thickness = 1 end
	local top = frame:FindFirstChild("Top")
	if not top then return end
	top.BackgroundColor3 = HW.C.raised
	for _, l in ipairs(top:GetChildren()) do
		if l:IsA("TextLabel") and l.Text == "Prince Stats" then
			l.Font = Enum.Font.GothamBold
			l.TextSize = 13
			l.TextColor3 = HW.C.lavender
			l.Position = UDim2.fromOffset(28, 0)
		elseif l:IsA("TextButton") then
			l.BackgroundColor3 = HW.C.surface
			l.TextColor3 = HW.C.text2
		end
	end
	HW.pumpkin(top, 14, 95, UDim2.fromOffset(8, 5))
end

-- ===== الإشعارات (Toast) =====
local function hwToast(n)
	if not n:IsA("Frame") then return end
	n.BorderSizePixel = 0
	hwCorner(n, HW.R.md)
	hwStroke(n, HW.C.line, 1, 0.1)
	for _, ch in ipairs(n:GetChildren()) do
		if ch:IsA("Frame") then
			ch.BorderSizePixel = 0
			hwCorner(ch, HW.R.md)
		end
	end
end

-- ===== التطبيق =====
function HW.apply(Library, Window)
	if not HW.on() or HW.applied then return end
	local outer = Library.MainWindowFrame
	local inner = outer and outer:FindFirstChildOfClass("Frame")
	if not inner then return end
	HW.applied = true
	local C = HW.C

	-- النافذة: زوايا 12، حافة رفيعة بلمعة لافندر من فوق (ضوء القمر)، وظل ناعم
	outer.BackgroundTransparency = 1
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	hwCorner(inner, HW.R.xl)
	local rim = hwStroke(inner, Color3.new(1, 1, 1), 1, 0)
	hwGradient(rim, C.lavender, C.line, 90, 0.35, 0)
	for i, tr in ipairs({ 0.55, 0.75 }) do
		local sh = hwMake("Frame", {
			Name = "HWShadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = tr, BorderSizePixel = 0,
			Size = UDim2.new(1, 8 * i, 1, 8 * i), Position = UDim2.fromOffset(-4 * i, 0), ZIndex = 0, -- ينزل شوية لتحت
		}, outer)
		hwCorner(sh, HW.R.xl + 4 * i)
	end

	local bg, clouds, fogs = hwBackground(inner)
	hwHeader(Library, inner, outer)

	-- مكان المحتوى: سطح واحد هادئ (مو طبقات فوق طبقات)
	local tabBar = inner:FindFirstChild("PrinceTabBar", true)
	local sectionInner = tabBar and tabBar.Parent
	local sectionOuter = sectionInner and sectionInner.Parent
	if sectionOuter and sectionOuter ~= inner then
		sectionOuter.BackgroundTransparency = 1
		sectionOuter.BorderSizePixel = 0
	end
	local container = nil
	if sectionInner then
		sectionInner.BackgroundTransparency = 1
		sectionInner.BorderSizePixel = 0
		for _, ch in ipairs(sectionInner:GetChildren()) do
			if ch.Name == "PrinceTabArrow" then
				ch.BorderSizePixel = 0
				ch.BackgroundTransparency = 0.35
				ch.TextColor3 = C.text2
				hwCorner(ch, HW.R.md)
			elseif ch:IsA("Frame") and ch:FindFirstChild("TabFrame") then
				container = ch
				ch.BackgroundColor3 = C.bg2
				ch.BackgroundTransparency = 0.12
				ch.BorderSizePixel = 0
				pcall(function() Library:RemoveFromRegistry(ch) end)
				hwCorner(ch, HW.R.xl)
				hwStroke(ch, C.line, 1, 0.2)
				local function styleTabFrame(tf)
					if tf.Name ~= "TabFrame" then return end
					for _, side in ipairs(tf:GetChildren()) do
						if side:IsA("ScrollingFrame") then
							for _, box in ipairs(side:GetChildren()) do hwStyleBox(Library, box) end
							side.ChildAdded:Connect(function(box) task.defer(hwStyleBox, Library, box) end)
						end
					end
				end
				for _, tf in ipairs(ch:GetChildren()) do styleTabFrame(tf) end
				ch.ChildAdded:Connect(function(tf) task.defer(styleTabFrame, tf) end)
			end
		end
	end
	if tabBar then
		for _, btn in ipairs(tabBar:GetChildren()) do hwStyleTabButton(btn) end
		tabBar.ChildAdded:Connect(function(btn) task.defer(hwStyleTabButton, btn) end)
	end

	-- التبويب النشط + الانتقال (نلف ShowTab مال كل تبويب)
	if tabBar and Window and type(Window.Tabs) == "table" then
		for name, tab in pairs(Window.Tabs) do
			if type(tab) == "table" and type(tab.ShowTab) == "function" and not tab.HWWrapped then
				local orig = tab.ShowTab
				tab.HWWrapped = true
				tab.ShowTab = function(self, ...)
					orig(self, ...)
					pcall(HW.markTab, tabBar, name)
					if container then pcall(HW.slideIn, container) end
				end
			end
		end
		-- التبويب الظاهر هسه (Linoria يعطيه MainColor)
		for _, btn in ipairs(tabBar:GetChildren()) do
			local l = btn:IsA("Frame") and btn:FindFirstChildOfClass("TextLabel")
			if l and btn.BackgroundColor3 == Library.MainColor then HW.markTab(tabBar, l.Text) end
		end
	end

	-- الإشعارات
	pcall(function()
		local area = Library.NotificationArea
		if area then
			for _, n in ipairs(area:GetChildren()) do hwToast(n) end
			area.ChildAdded:Connect(function(n) task.defer(hwToast, n) end)
		end
	end)

	hwAmbientMotion(bg, outer, clouds, fogs)
	hwMini(Library)
	pcall(hwStats)
end
