-- ------------------------------------------------------------
-- HALLOWEEN UI  [PRINCE HUB v20]
-- ------------------------------------------------------------
-- ثيم هالوين مبني على Halloween_Fantasy_UI: نفس الألوان (بنفسجي/برتقالي/غامق)،
-- خلفية gradient، زوايا مدورة، إطار gradient يدور، عنوان 🎃 بخط Fantasy، قمر،
-- بطاقة اللاعب (👑 الاسم + اللفل)، جزيئات طايرة (✦ 🎃 👻 🦇)، وزر 🎃 بدل P.
-- محرك الواجهة (Linoria) نفسه، فكل التبويبات والأزرار والحفظ تشتغل مثل ما هي.
-- الثيم ينختار من Config > Prince Hub > Theme (Halloween / Classic)، ويتطبق بالتحميل الجاي.
US.theme = (US.theme == "Classic") and "Classic" or "Halloween"
PrinceNewTabs.theme = US.theme

local PN_Halloween = {
	PURPLE = Color3.fromRGB(120, 25, 190),
	DARK = Color3.fromRGB(16, 8, 28),
	ORANGE = Color3.fromRGB(255, 125, 20),
	PINK = Color3.fromRGB(210, 60, 255),
	WHITE = Color3.fromRGB(255, 240, 255),
	BG_TOP = Color3.fromRGB(12, 4, 25),
	BG_BOTTOM = Color3.fromRGB(55, 10, 80),
	SYMBOLS = { "✦", "✦", "✦", "🎃", "👻", "🦇", "🕸" },
	maxParticles = 14,
	applied = false,
}

function PN_Halloween.on()
	return PrinceNewTabs.theme == "Halloween"
end

local function hwMake(className, props, parent)
	local obj = Instance.new(className)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function hwCorner(obj, r)
	if obj:FindFirstChild("HWCorner") then return end
	hwMake("UICorner", { Name = "HWCorner", CornerRadius = UDim.new(0, r or 8) }, obj)
end

local function hwStroke(obj, color, thickness, transparency)
	local s = obj:FindFirstChild("HWStroke") or hwMake("UIStroke", { Name = "HWStroke" }, obj)
	s.Color = color or PN_Halloween.PURPLE
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function hwGradient(obj, c1, c2, rotation)
	return hwMake("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 45,
	}, obj)
end

-- groupbox: إطار مدور بلون وردي وخلفية شبه شفافة
local function hwStyleBox(box)
	if not box:IsA("Frame") or box:GetAttribute("HWStyled") then return end
	box:SetAttribute("HWStyled", true)
	box.BorderSizePixel = 0
	box.BackgroundTransparency = 0.12
	hwCorner(box, 8)
	hwStroke(box, PN_Halloween.PINK, 1, 0.35)
	local inner = box:FindFirstChildOfClass("Frame")
	if inner then
		inner.BorderSizePixel = 0
		inner.BackgroundTransparency = 1
		hwCorner(inner, 8)
	end
end

local function hwStyleTabButton(btn)
	if not btn:IsA("Frame") or btn:GetAttribute("HWStyled") then return end
	btn:SetAttribute("HWStyled", true)
	btn.BorderSizePixel = 0
	hwCorner(btn, 6)
	hwStroke(btn, PN_Halloween.PURPLE, 1, 0.2)
end

function PN_Halloween.palette(Library)
	Library.FontColor = PN_Halloween.WHITE
	Library.MainColor = Color3.fromRGB(26, 11, 46)
	Library.BackgroundColor = PN_Halloween.DARK
	Library.AccentColor = PN_Halloween.ORANGE
	Library.OutlineColor = PN_Halloween.PURPLE
	pcall(function() Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor) end)
end

-- جزيئات تطلع من جوة لفوك وتختفي (بس والقائمة مفتوحة)
local function hwParticles(bg, outer)
	local alive = 0
	task.spawn(function()
		local TweenService = game:GetService("TweenService")
		while bg.Parent and outer.Parent do
			if outer.Visible and alive < PN_Halloween.maxParticles then
				alive = alive + 1
				local sym = PN_Halloween.SYMBOLS[math.random(1, #PN_Halloween.SYMBOLS)]
				local size = math.random(12, 22)
				local p = hwMake("TextLabel", {
					Name = "HWParticle",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(size, size),
					Position = UDim2.new(math.random(5, 95) / 100, 0, 1, 0),
					Text = sym,
					TextColor3 = (sym == "✦") and PN_Halloween.ORANGE or PN_Halloween.WHITE,
					TextTransparency = 0.25,
					TextScaled = true,
					Font = Enum.Font.GothamBold,
					ZIndex = 1,
				}, bg)
				local tw = TweenService:Create(p, TweenInfo.new(math.random(5, 9), Enum.EasingStyle.Linear), {
					Position = UDim2.new(p.Position.X.Scale + (math.random(-8, 8) / 100), 0, -0.1, 0),
					TextTransparency = 1,
					Rotation = math.random(-40, 40),
				})
				tw.Completed:Connect(function()
					alive = alive - 1
					p:Destroy()
				end)
				tw:Play()
			end
			task.wait(0.45)
		end
	end)
end

-- الهب يستدعيها قبل ما يبني النافذة (حتى العناصر تنخلق بالألوان الجديدة)
PrinceNewTabs.applyPalette = function(Library) PN_Halloween.palette(Library) end

function PN_Halloween.apply(Library)
	if not PN_Halloween.on() or PN_Halloween.applied then return end
	local outer = Library.MainWindowFrame
	local inner = outer and outer:FindFirstChildOfClass("Frame")
	if not inner then return end
	PN_Halloween.applied = true
	local TweenService = game:GetService("TweenService")

	-- الإطار: مدور + gradient بنفسجي/وردي/برتقالي يدور
	outer.BackgroundTransparency = 1
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	hwCorner(inner, 14)
	local frameStroke = hwStroke(inner, Color3.new(1, 1, 1), 2, 0)
	local strokeGrad = hwMake("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PN_Halloween.PURPLE),
			ColorSequenceKeypoint.new(0.5, PN_Halloween.ORANGE),
			ColorSequenceKeypoint.new(1, PN_Halloween.PINK),
		}),
	}, frameStroke)
	pcall(function()
		TweenService:Create(strokeGrad, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	end)

	-- الخلفية: gradient مثل الكونسبت
	local bg = hwMake("Frame", {
		Name = "HalloweenBG",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 0,
		ClipsDescendants = true,
	}, inner)
	hwCorner(bg, 14)
	hwGradient(bg, PN_Halloween.BG_TOP, PN_Halloween.BG_BOTTOM, 45)

	-- العنوان: 🎃 بخط Fantasy برتقالي ويا حافة بنفسجية
	for _, ch in ipairs(inner:GetChildren()) do
		if ch:IsA("TextLabel") and ch.Position.Y.Offset == 0 and ch.Name ~= "HWProfile" then
			ch.Text = "🎃 PRINCE HUB"
			ch.Font = Enum.Font.Fantasy
			ch.TextSize = 18
			ch.TextColor3 = PN_Halloween.ORANGE
			ch.TextStrokeColor3 = Color3.fromRGB(70, 0, 100)
			ch.TextStrokeTransparency = 0
			pcall(function() Library.RegistryMap[ch].Properties.TextColor3 = "AccentColor" end)
			break
		end
	end

	-- القمر (جنب زر X)
	local moon = hwMake("Frame", {
		Name = "HWMoon",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -60, 0, 5), -- بعيد عن زر X (بالهاتف X يكبر)
		BackgroundColor3 = Color3.fromRGB(255, 180, 90),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, inner)
	hwCorner(moon, 100)
	hwStroke(moon, PN_Halloween.ORANGE, 2, 0.1)

	-- بطاقة اللاعب: 👑 الاسم • LV
	local profile = hwMake("TextLabel", {
		Name = "HWProfile",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.45, 0, 0, 1),
		Size = UDim2.new(0.55, -68, 0, 23),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = PN_Halloween.WHITE,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "👑 " .. PN_LocalPlayer.DisplayName,
		ZIndex = 3,
	}, inner)
	task.spawn(function()
		while profile.Parent do
			local lv = PN_statValue("Level")
			profile.Text = "👑 " .. PN_LocalPlayer.DisplayName .. (lv and ("  •  LV. " .. tostring(lv)) or "")
			task.wait(5)
		end
	end)

	-- الأقسام: شفافية حتى تبين الخلفية + زوايا مدورة
	local tabBar = inner:FindFirstChild("PrinceTabBar", true)
	local sectionInner = tabBar and tabBar.Parent
	local sectionOuter = sectionInner and sectionInner.Parent
	if sectionOuter and sectionOuter ~= inner then
		sectionOuter.BackgroundTransparency = 1
		sectionOuter.BorderSizePixel = 0
	end
	if sectionInner then
		sectionInner.BackgroundTransparency = 0.45
		sectionInner.BorderSizePixel = 0
		hwCorner(sectionInner, 10)
		for _, ch in ipairs(sectionInner:GetChildren()) do
			if ch.Name == "PrinceTabArrow" then
				ch.BorderSizePixel = 0
				hwCorner(ch, 5)
				hwStroke(ch, PN_Halloween.PINK, 1, 0.3)
			elseif ch:IsA("Frame") and ch:FindFirstChild("TabFrame") then
				-- مكان محتوى التبويب
				ch.BackgroundTransparency = 0.3
				ch.BorderSizePixel = 0
				hwCorner(ch, 10)
				hwStroke(ch, PN_Halloween.PURPLE, 1, 0.25)
				local function styleTabFrame(tf)
					if tf.Name ~= "TabFrame" then return end
					for _, side in ipairs(tf:GetChildren()) do
						if side:IsA("ScrollingFrame") then
							for _, box in ipairs(side:GetChildren()) do hwStyleBox(box) end
							side.ChildAdded:Connect(function(box) task.defer(hwStyleBox, box) end)
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

	hwParticles(bg, outer)

	-- زر X وزر 🎃 (بدل P)
	local close = outer:FindFirstChild("PrinceClose", true)
	if close then
		close.BackgroundColor3 = PN_Halloween.PURPLE
		close.Position = UDim2.new(1, -24, 0, 3)
		hwStroke(close, PN_Halloween.PINK, 1, 0.1)
	end
	local mini = Library.ScreenGui and Library.ScreenGui:FindFirstChild("PrinceMini")
	if mini then
		mini.Text = "🎃"
		mini.TextScaled = true
		mini.BackgroundColor3 = PN_Halloween.DARK
		local c = mini:FindFirstChildOfClass("UICorner")
		if c then c.CornerRadius = UDim.new(1, 0) end
		local s = mini:FindFirstChildOfClass("UIStroke")
		if s then s.Color = PN_Halloween.ORANGE; s.Thickness = 3 end
		hwGradient(mini, Color3.new(1, 1, 1), Color3.fromRGB(150, 110, 190), 90)
	end

	-- نافذة الـ stats
	pcall(function()
		local gui = getgenv().PrinceStatsGui
		local frame = gui and gui:FindFirstChild("PrinceStats")
		if not frame then return end
		local s = frame:FindFirstChildOfClass("UIStroke")
		if s then s.Color = PN_Halloween.ORANGE; s.Thickness = 2 end
		local top = frame:FindFirstChild("Top")
		if top then
			top.BackgroundColor3 = Color3.new(1, 1, 1)
			hwGradient(top, PN_Halloween.PURPLE, PN_Halloween.BG_BOTTOM, 0)
			for _, l in ipairs(top:GetChildren()) do
				if l:IsA("TextLabel") and l.Text == "Prince Stats" then
					l.Text = "🎃 Prince Stats"
					l.Font = Enum.Font.Fantasy
					l.TextSize = 16
				end
			end
		end
	end)
end
