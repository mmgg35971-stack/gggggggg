-- ------------------------------------------------------------
-- STATS WINDOW: نافذة صغيرة (ScreenGui خاص بيها) تطلع لما يشتغل فارم (Dungeon / Cupid / Waves / Impel / Sea 1 / Sea 2)
-- تتسحب، "-" يصغّرها للعنوان بس، "X" يخفيها (ترجعها من زر Stats window بالتبويب)
-- ------------------------------------------------------------
local OS = PN_Saved.Overlay
if OS.show == nil then OS.show = true end

local PN_Overlay = { gui = nil, syncing = false, toggles = {} }

local function PN_fmtTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

local function PN_fmtNum(n)
	n = tonumber(n)
	if not n then return "?" end
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (n < 0 and "-" or "") .. out
end

local function PN_statValue(name)
	local ok, v = pcall(function()
		local root = game:GetService("ReplicatedStorage"):FindFirstChild("Stats" .. PN_LocalPlayer.Name)
		local stats = root and root:FindFirstChild("Stats")
		local value = stats and stats:FindFirstChild(name)
		return value and value.Value
	end)
	return ok and tonumber(v) or nil
end

-- كل فارم: هل شغّال + سطور الإحصائيات
local PN_Farms = {
	{
		id = "ImpelTest", title = "Auto Impel (test)",
		active = function()
			local T = getgenv().PrinceImpelTest
			return T ~= nil and T.enabled == true
		end,
		lines = function()
			local T = getgenv().PrinceImpelTest
			local D = T.diag
			local where = tostring(T.place)
			if T.floor then where = where .. " - " .. tostring(T.floor) end
			return {
				{ "State", PN_cut(tostring(T.state), 22) },
				{ "Where", PN_cut(where, 22) },
				{ "Stage", PN_cut(tostring(T.stage or "-"), 22) },
				{ "Target", PN_cut(tostring(T.targetName or "-"), 22) },
				{ "Kills", tostring(T.kills or 0) },
				{ "Health", tostring(D and D.overall or "?") .. " (" .. tostring(D and D.recentErrors(60) or 0) .. " err/60s)" },
			}
		end,
	},
	{
		id = "ImpelZyph", title = "Impel Down Zyph",
		active = function()
			local Z = getgenv().PrinceZyph
			return Z ~= nil and Z.running == true
		end,
		lines = function()
			local Z = getgenv().PrinceZyph
			local env = Z.env or {}
			local place = "?"
			local ids = { [1730877806] = "Main menu", [6360478118] = "Universe", [7465136166] = "Second Sea", [11424731604] = "Dungeon" }
			place = ids[game.PlaceId] or tostring(game.PlaceId)
			local fl = rawget(env, "floor")
			if place == "Dungeon" and fl then place = "Dungeon - Floor " .. tostring(fl) end
			if place == "Dungeon" and workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild("Impel Base - Finished") then
				place = "Dungeon - Finished (shop)"
			end
			local npc = rawget(env, "Npc")
			local npcName = "-"
			pcall(function()
				if npc and npc.Parent then npcName = npc:GetAttribute("RealName") or npc.Name end
			end)
			local points, lives, myth = "?", "?", "?"
			pcall(function()
				local g = PN_LocalPlayer.PlayerGui:FindFirstChild("BattleReportGui")
				if g and g:FindFirstChild("Points") then points = g.Points.Text end
			end)
			pcall(function()
				local ls = PN_LocalPlayer:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Lives") then lives = tostring(ls.Lives.Value) end
			end)
			pcall(function()
				local root = game:GetService("ReplicatedStorage"):FindFirstChild("Stats" .. PN_LocalPlayer.Name)
				local inv = root.Inventory.Inventory.Value
				myth = inv:match('"Mythical Fruit Chest":(%d+)') or "0"
			end)
			return {
				{ "State", PN_cut(Z.error and ("Error: " .. Z.error) or Z.status, 22) },
				{ "Place", PN_cut(place, 22) },
				{ "NPC", PN_cut(npcName, 22) },
				{ "Mythical", tostring(myth) },
				{ "Points", PN_cut(tostring(points), 22) },
				{ "Lives", lives },
			}
		end,
	},
	{
		id = "Impel", title = "Impel Down",
		active = function()
			local I = getgenv().PrinceImpel
			return I ~= nil and I.enabled == true
		end,
		lines = function()
			local I = getgenv().PrinceImpel
			local where = tostring(I.place)
			if I.place == "Dungeon" and I.floor then where = "Floor " .. tostring(I.floor) end
			return {
				{ "State", PN_cut(I.status, 22) },
				{ "Place", where },
				{ "NPC", PN_cut(I.npcName or "-", 22) },
				{ "Mythical", tostring(I.mythical or 0) },
				{ "Points", PN_cut(tostring(I.points or "?"), 22) },
				{ "Run time", tostring(I.farmTime or "-") },
			}
		end,
	},
	{
		id = "Waves", title = "Waves",
		active = function()
			local W = getgenv().PrinceWaves
			return W ~= nil and W.enabled == true
		end,
		lines = function()
			local W = getgenv().PrinceWaves
			return {
				{ "State", PN_cut(W.status, 22) },
				{ "Mode", tostring(W.mode) },
				{ "Wave", tostring(W.wave or "?") .. " / " .. tostring(W.targetWave) },
				{ "Kills", PN_fmtNum(W.kills) },
				{ "Runs", tostring(W.runs) .. "   Deaths: " .. tostring(W.deaths) },
			}
		end,
	},
	{
		id = "Sea1Farm", title = "Auto Farm Sea 1",
		active = function() return getgenv().LevelFarm == true end,
		lines = function() return {} end,
	},
	{
		id = "Sea2Farm", title = "Auto Farm Sea 2",
		active = function() return getgenv().Sea2Farm == true end,
		lines = function() return {} end,
	},
	{
		id = "HubDungeon", title = "Auto Dungeon",
		active = function()
			local AD = getgenv().PrinceHubAD
			return AD ~= nil and AD.enabled == true
		end,
		lines = function()
			local AD = getgenv().PrinceHubAD
			return {
				{ "State", PN_cut(AD.status or "-", 22) },
				{ "Kills", PN_fmtNum(AD.kills) },
				{ "Waypoint", tostring(AD.waypointIdx or "-") },
			}
		end,
	},
	{
		id = "Cupid", title = "Cupid Dungeon",
		active = function()
			return Cupid.enabled == true and not PN_NoAuto
		end,
		lines = function()
			local AD = getgenv().PrinceCupidAD
			return {
				{ "State", PN_cut(AD and AD.status or "-", 22) },
				{ "Kills", AD and PN_fmtNum(AD.kills) or "?" },
				{ "Waypoint", AD and tostring(AD.waypointIdx or "-") or "-" },
			}
		end,
	},
}

local function PN_setOverlayShown(v)
	OS.show = v == true
	PN_save()
	if PN_Overlay.syncing then return end
	PN_Overlay.syncing = true
	for _, t in ipairs(PN_Overlay.toggles) do
		if t.Value ~= OS.show then
			pcall(function() t:SetValue(OS.show) end)
		end
	end
	PN_Overlay.syncing = false
end

-- زر "Stats window" بالتبويب (كل التبويبات مربوطة بنفس الإعداد)
local function PN_addOverlayToggle(groupbox, idx)
	local t = groupbox:AddToggle(idx, {
		Text = "Stats window",
		Default = OS.show,
		Tooltip = "Small window with the farm stats while a dungeon farm is ON",
		Callback = function(v) PN_setOverlayShown(v) end,
	})
	PN_Overlay.toggles[#PN_Overlay.toggles + 1] = t
	return t
end

local function PN_buildOverlay(Library)
	-- ScreenGui خاص بيها (مستقلة عن واجهة الهب)
	if getgenv().PrinceStatsGui then
		pcall(function() getgenv().PrinceStatsGui:Destroy() end)
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PrinceStatsGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(screenGui) end end)
	local okParent = pcall(function()
		local hui = gethui and gethui()
		screenGui.Parent = (typeof(hui) == "Instance" and hui) or game:GetService("CoreGui")
	end)
	if not okParent or not screenGui.Parent then
		screenGui.Parent = PN_LocalPlayer:WaitForChild("PlayerGui")
	end
	getgenv().PrinceStatsGui = screenGui
	local accent = Library.AccentColor or Color3.fromRGB(245, 189, 230)
	local mainColor = Library.MainColor or Color3.fromRGB(28, 28, 34)
	local bgColor = Library.BackgroundColor or Color3.fromRGB(20, 20, 26)
	local fontColor = Library.FontColor or Color3.fromRGB(235, 235, 240)

	local frame = Instance.new("Frame")
	frame.Name = "PrinceStats"
	frame.Size = UDim2.fromOffset(230, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Position = UDim2.fromOffset(tonumber(OS.x) or 20, tonumber(OS.y) or 140)
	frame.BackgroundColor3 = bgColor
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Visible = false
	frame.ZIndex = 90
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1
	stroke.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, 0, 0, 24)
	top.BackgroundColor3 = mainColor
	top.BorderSizePixel = 0
	top.LayoutOrder = 0
	top.Active = true
	top.ZIndex = 91
	top.Parent = frame
	Instance.new("UICorner", top).CornerRadius = UDim.new(0, 6)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Font = Enum.Font.Code
	title.Text = "Prince Stats"
	title.TextColor3 = accent
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 92
	title.Parent = top

	local function topButton(text, x)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(20, 18)
		b.Position = UDim2.new(1, x, 0, 3)
		b.BackgroundColor3 = bgColor
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Code
		b.Text = text
		b.TextColor3 = fontColor
		b.TextSize = 14
		b.ZIndex = 93
		b.Parent = top
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end
	local minBtn = topButton("-", -46)
	local closeBtn = topButton("X", -24)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 1
	body.ZIndex = 91
	body.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = body
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 1)
	bodyLayout.Parent = body

	-- سطور جاهزة (تنعاد استخدامها كل تحديث)
	local rows = {}
	local function getRow(i)
		local row = rows[i]
		if row then return row end
		row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 16)
		row.Font = Enum.Font.Code
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = fontColor
		row.RichText = true
		row.LayoutOrder = i
		row.ZIndex = 92
		row.Parent = body
		rows[i] = row
		return row
	end

	local collapsed = OS.collapsed == true
	local function applyCollapsed()
		body.Visible = not collapsed
		minBtn.Text = collapsed and "+" or "-"
	end
	applyCollapsed()
	minBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		OS.collapsed = collapsed
		PN_save()
		applyCollapsed()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		PN_setOverlayShown(false)
		frame.Visible = false
		pcall(function() Library:Notify("Stats window hidden (turn it back on with 'Stats window' in the tab)", 4) end)
	end)

	-- السحب (ماوس + لمس)
	local dragging, dragStart, startPos = false, nil, nil
	local function clampToScreen(x, y)
		local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
		if ok and vp and vp.X > 0 then
			local size = frame.AbsoluteSize
			x = math.clamp(x, 0, math.max(0, vp.X - size.X))
			y = math.clamp(y, 0, math.max(0, vp.Y - 24))
		end
		return x, y
	end
	frame.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		dragging, dragStart, startPos = true, input.Position, frame.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				dragging = false
				OS.x, OS.y = frame.Position.X.Offset, frame.Position.Y.Offset
				PN_save()
			end
		end)
	end)
	Library:GiveSignal(PN_UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
		local d = input.Position - dragStart
		local x, y = clampToScreen(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
		frame.Position = UDim2.fromOffset(x, y)
	end))

	PN_Overlay.gui = frame

	-- التحديث
	local sessionStart = {}
	local startPeli, startLevel = nil, nil
	task.spawn(function()
		while screenGui.Parent and frame.Parent do
			pcall(function()
				local lines = {}
				local anyActive = false
				for _, farm in ipairs(PN_Farms) do
					local okA, isActive = pcall(farm.active)
					if okA and isActive then
						anyActive = true
						sessionStart[farm.id] = sessionStart[farm.id] or tick()
						lines[#lines + 1] = { header = farm.title }
						lines[#lines + 1] = { "Time", PN_fmtTime(tick() - sessionStart[farm.id]) }
						local okL, farmLines = pcall(farm.lines)
						if okL and type(farmLines) == "table" then
							for _, l in ipairs(farmLines) do lines[#lines + 1] = l end
						end
					else
						sessionStart[farm.id] = nil
					end
				end

				if anyActive then
					local peli, level = PN_statValue("Peli"), PN_statValue("Level")
					startPeli = startPeli or peli
					startLevel = startLevel or level
					lines[#lines + 1] = { header = "Player" }
					if level then
						local gained = startLevel and level - startLevel or 0
						lines[#lines + 1] = { "Level", tostring(level) .. (gained > 0 and ("  (+" .. gained .. ")") or "") }
					end
					if peli then
						local gained = startPeli and peli - startPeli or 0
						lines[#lines + 1] = { "Peli", PN_fmtNum(peli) .. (gained ~= 0 and ("  (" .. (gained > 0 and "+" or "") .. PN_fmtNum(gained) .. ")") or "") }
					end
				else
					startPeli, startLevel = nil, nil
				end

				frame.Visible = anyActive and OS.show == true
				if not frame.Visible then return end

				for i, l in ipairs(lines) do
					local row = getRow(i)
					local text
					if l.header then
						text = string.format('<b><font color="#%s">%s</font></b>', accent:ToHex(), l.header)
					else
						text = string.format('%s: <font color="#%s">%s</font>', l[1], accent:ToHex(), tostring(l[2]))
					end
					if row.Text ~= text then row.Text = text end
					row.Visible = true
				end
				for i = #lines + 1, #rows do
					rows[i].Visible = false
				end
			end)
			task.wait(0.5)
		end
	end)
end

