-- ------------------------------------------------------------
-- حجم الواجهة (للهاتف): Auto = تصغير حسب الشاشة (مثلاً عرض 320)، أو نسبة يدوية
-- ------------------------------------------------------------
local US = PN_Saved.UI
local UISize = {
	auto    = PN_pick(US.auto, true),
	percent = PN_pick(tonumber(US.percent), 100),
}

-- أكبر حجم تتسع بيه القائمة بالشاشة (مثلاً شاشة عرضها 320 => تقريباً 0.48)
local function PN_fitScale(Library)
	local outer = Library.MainWindowFrame
	local cam = workspace.CurrentCamera
	if not outer or not cam then
		return 1
	end
	local vp = cam.ViewportSize
	local w, h = outer.Size.X.Offset, outer.Size.Y.Offset
	if w <= 0 or h <= 0 or vp.X <= 0 or vp.Y <= 0 then
		return 1
	end
	return math.clamp(math.min((vp.X - 10) / w, (vp.Y - 50) / h), 0.3, 1)
end

local function PN_scaleOf(obj, name)
	local sc = obj:FindFirstChild(name)
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = name
		sc.Parent = obj
	end
	return sc
end

local function PN_applyUIScale(Library)
	if not Library.SetUIScale then
		return 1
	end
	local scale = UISize.auto and PN_fitScale(Library) or (UISize.percent / 100)
	Library:SetUIScale(scale)
	scale = Library.UIScale or scale

	-- زر X بالقائمة: يظل حجمه مناسب للمس حتى لو القائمة صغرت
	pcall(function()
		local outer = Library.MainWindowFrame
		local closeBtn = outer and outer:FindFirstChild("PrinceClose")
		if closeBtn then
			closeBtn.AnchorPoint = Vector2.new(1, 0)
			closeBtn.Position = UDim2.new(1, -4, 0, 3)
			PN_scaleOf(closeBtn, "PrinceCloseScale").Scale = math.max(1, 0.8 / scale)
		end
	end)

	-- نافذة الـ Stats (ScreenGui خاصة بيها): تصغر ويا الشاشة بس مو أقل من 70%، وتبقى داخل الشاشة
	pcall(function()
		local frame = PN_Overlay and PN_Overlay.gui
		if not frame then return end
		PN_scaleOf(frame, "PrinceUIScale").Scale = math.clamp(scale, 0.7, 1)
		task.defer(function()
			local vp = workspace.CurrentCamera.ViewportSize
			local size = frame.AbsoluteSize
			local x = math.clamp(frame.Position.X.Offset, 0, math.max(0, vp.X - size.X))
			local y = math.clamp(frame.Position.Y.Offset, 0, math.max(0, vp.Y - 24))
			frame.Position = UDim2.fromOffset(x, y)
		end)
	end)
	return scale
end

