-- ------------------------------------------------------------
-- زر X + المربع الصغير P
-- ------------------------------------------------------------
local function PN_buildMiniToggle(Library)
	local outer = Library.MainWindowFrame
	local screenGui = Library.ScreenGui
	if not outer or not screenGui then return end

	local accent = Library.AccentColor or Color3.fromRGB(245, 189, 230)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "PrinceClose"
	closeBtn.Size = UDim2.fromOffset(20, 20)
	closeBtn.Position = UDim2.new(1, -24, 0, 3)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 13
	closeBtn.ZIndex = 100
	closeBtn.Parent = outer
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

	local mini = Instance.new("TextButton")
	mini.Name = "PrinceMini"
	mini.Size = UDim2.fromOffset(46, 46)
	mini.Position = UDim2.new(0, 20, 0.35, 0)
	mini.BackgroundColor3 = Library.MainColor or Color3.fromRGB(36, 39, 58)
	mini.BorderSizePixel = 0
	mini.Font = Enum.Font.GothamBlack
	mini.Text = "P"
	mini.TextColor3 = accent
	mini.TextSize = 22
	mini.ZIndex = 100
	mini.Visible = false
	mini.Parent = screenGui
	Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Color = accent
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = mini

	-- سحب المربع (ماوس + لمس)، والضغط بدون سحب يرجّع القائمة
	local dragging, moved, dragStart, startPos = false, false, nil, nil
	mini.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		dragging, moved = true, false
		dragStart, startPos = input.Position, mini.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				if dragging then
					dragging = false
					if not moved then Library:Toggle() end
				end
			end
		end)
	end)
	Library:GiveSignal(PN_UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
		local d = input.Position - dragStart
		if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
		if moved then
			mini.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	closeBtn.MouseButton1Click:Connect(function()
		-- المربع يطلع بمكان القائمة
		local p = outer.AbsolutePosition
		mini.Position = UDim2.fromOffset(p.X, p.Y)
		Library:Toggle()
	end)

	-- المربع يبين كل ما القائمة مخفية (X أو الكيبايند أو Auto Hide)
	task.spawn(function()
		while screenGui.Parent and mini.Parent do
			mini.Visible = not outer.Visible
			task.wait(0.15)
		end
	end)
end

