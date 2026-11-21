-- ------------------------------------------------------------
-- بناء التبويبات
-- ------------------------------------------------------------
function PrinceNewTabs.build(Library, Tabs, Window, SaveManager)
	PN_HubConfig = getgenv().Config

	pcall(PN_buildMiniToggle, Library)
	pcall(PN_buildOverlay, Library)

	-- حجم الواجهة: يتطبق هسه، ويتحدث إذا تغيّر حجم الشاشة (تدوير الهاتف)
	pcall(PN_applyUIScale, Library)
	pcall(function()
		local cam = workspace.CurrentCamera
		Library:GiveSignal(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if UISize.auto then
				pcall(PN_applyUIScale, Library)
			end
		end))
	end)

	if Tabs.Dungeon then
		pcall(function()
			PN_addOverlayToggle(Tabs.Dungeon:AddRightGroupbox("Stats"), "PN_DungeonOverlay")
		end)
	end
	if Tabs.Sea2 then
		pcall(function()
			PN_addOverlayToggle(Tabs.Sea2:AddRightGroupbox("Stats"), "PN_FarmOverlay")
		end)
	end

	local Toggles = getgenv().Toggles
	local Options = getgenv().Options
	local function notify(text, t) pcall(function() Library:Notify(text, t or 3) end) end

	-- ================= Config: UI Size =================
	if Tabs.Config and Library.SetUIScale then
		pcall(function()
			local Box = Tabs.Config:AddRightGroupbox("UI Size (phone)")
			local scaleLabel = Box:AddLabel("Current: " .. math.floor((Library.UIScale or 1) * 100 + 0.5) .. "%")
			local function refresh()
				local scale = PN_applyUIScale(Library)
				scaleLabel:SetText("Current: " .. math.floor((scale or 1) * 100 + 0.5) .. "%")
			end
			Box:AddToggle("PN_UIAuto", {
				Text = "Auto fit screen",
				Default = UISize.auto,
				Tooltip = "Shrinks the menu so it fits your screen (phone)",
				Callback = function(v) UISize.auto = v; US.auto = v; PN_save(); refresh() end,
			})
			Box:AddSlider("PN_UIScale", {
				Text = "Manual size % (Auto OFF)", Default = UISize.percent, Min = 30, Max = 100, Rounding = 0,
				Callback = function(v) UISize.percent = v; US.percent = v; PN_save(); if not UISize.auto then refresh() end end,
			})
			refresh()
		end)
	end

	-- ================= Config: Prince Hub (النسخة + سجل الأخطاء) [PRINCE HUB v18] =================
	if Tabs.Config then
		pcall(function()
			local Box = Tabs.Config:AddRightGroupbox("Prince Hub")
			Box:AddLabel("Version: " .. PRINCE_HUB_VERSION)
			Box:AddDropdown("PN_UITheme", { -- [PRINCE HUB v20]
				Values = { "Halloween", "Classic" }, Default = PrinceNewTabs.theme, Multi = false,
				Text = "Theme (next load)",
				Callback = function(v)
					if v ~= "Halloween" and v ~= "Classic" then return end
					if US.theme ~= v then
						US.theme = v
						PN_save()
						notify("Theme " .. v .. ": re-execute the script to apply", 5)
					end
				end,
			})
			local errLabel = Box:AddLabel("Errors: 0")
			Box:AddButton({
				Text = "Copy error log",
				Func = function()
					local text = PH_Log.report()
					local copy = setclipboard or toclipboard
					if copy then
						pcall(copy, text)
						notify("Error log copied (" .. #PH_Log.entries .. ")", 3)
					else
						print(text)
						notify("No clipboard: log printed in console (F9)", 4)
					end
				end,
			})
			Box:AddButton({
				Text = "Clear error log",
				Func = function()
					table.clear(PH_Log.entries)
					notify("Error log cleared", 2)
				end,
			})
			task.spawn(function()
				while Library.ScreenGui and Library.ScreenGui.Parent do
					pcall(function() errLabel:SetText("Errors: " .. #PH_Log.entries) end)
					task.wait(2)
				end
			end)
		end)
	end

	-- ================= TAB: PRINCE AI [PRINCE HUB v19] =================
	if Tabs.PrinceAI then
		local okAI = PH_try("Prince AI tab", PrinceAI.buildTab, Tabs.PrinceAI, Library)
		if not okAI then notify("Prince AI tab error (see Config > Prince Hub)", 6) end
	end

	-- ================= TAB: KAITUN =================
	if Tabs.NewKaitun then
		local T = Tabs.NewKaitun
		local Box = T:AddLeftGroupbox("Auto Kaitun (New)")
		Box:AddLabel("Sea 1: Fishman 425 > Geppo > Haki")
		Box:AddLabel("> World Scroll > Main Menu")
		Box:AddLabel("> Sea 2 PS > target level")
		Box:AddDivider()

		Box:AddToggle("PN_KaitunEnabled", {
			Text = "Auto Kaitun",
			Default = Kaitun.enabled and not PN_NoAuto,
			Tooltip = "Runs the new Kaitun. Stays ON after teleports.",
			Callback = function(v)
				Kaitun.enabled = v
				KS.enabled = v
				PN_save()
				if v then
					kaitunStart()
					notify("Kaitun started", 3)
				else
					kaitunStop()
					notify("Kaitun stopped", 3)
				end
			end,
		})

		Box:AddToggle("PN_KaitunJoinSea2", {
			Text = "Auto Join Sea 2 PS",
			Default = Kaitun.joinSea2,
			Tooltip = "Join your private server in Sea 2 after the Sea 1 phases",
			Callback = function(v)
				Kaitun.joinSea2 = v; KS.joinSea2 = v; PN_save(); kaitunApplyLive()
			end,
		})

		Box:AddInput("PN_KaitunPSCode", {
			Text = "PS Code (optional)",
			Default = Kaitun.psCode,
			Placeholder = "empty = use PS_CODE from config",
			Numeric = false,
			Finished = true,
			Callback = function(v)
				kaitunSetPSCode(v); KS.psCode = Kaitun.psCode; PN_save()
			end,
		})

		Box:AddDivider()
		local statusLabel = Box:AddLabel("Status: -")
		local levelLabel = Box:AddLabel("Level: -")
		local psLabel = Box:AddLabel("PS: -")
		Box:AddLabel("Keep old Kaitun (Main tab) OFF")

		local Set = T:AddRightGroupbox("Kaitun Settings")
		Set:AddSlider("PN_KaitunLevel", {
			Text = "Target Level (Sea 2)", Default = Kaitun.level, Min = 425, Max = 1000, Rounding = 0,
			Callback = function(v) Kaitun.level = v; KS.level = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddSlider("PN_KaitunTween", {
			Text = "Tween Speed", Default = Kaitun.tween, Min = 30, Max = 200, Rounding = 0,
			Callback = function(v) Kaitun.tween = v; KS.tween = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddSlider("PN_KaitunStr", {
			Text = "Strength Cap", Default = Kaitun.strCap, Min = 0, Max = 2000, Rounding = 0,
			Callback = function(v) Kaitun.strCap = v; KS.strCap = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddSlider("PN_KaitunDef", {
			Text = "Defense Cap", Default = Kaitun.defCap, Min = 0, Max = 2000, Rounding = 0,
			Callback = function(v) Kaitun.defCap = v; KS.defCap = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddDivider()
		Set:AddToggle("PN_KaitunGeppo", {
			Text = "Get Geppo", Default = Kaitun.geppo,
			Callback = function(v) Kaitun.geppo = v; KS.geppo = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddToggle("PN_KaitunBuso", {
			Text = "Get Buso Haki", Default = Kaitun.buso,
			Callback = function(v) Kaitun.buso = v; KS.buso = v; PN_save(); kaitunApplyLive() end,
		})
		Set:AddToggle("PN_KaitunScroll", {
			Text = "Get World Scroll", Default = Kaitun.scroll,
			Callback = function(v) Kaitun.scroll = v; KS.scroll = v; PN_save(); kaitunApplyLive() end,
		})

		task.spawn(function()
			while Library.ScreenGui and Library.ScreenGui.Parent do
				pcall(function()
					local stats = game:GetService("ReplicatedStorage"):FindFirstChild("Stats" .. PN_LocalPlayer.Name)
					local lv = stats and stats:FindFirstChild("Stats") and stats.Stats:FindFirstChild("Level")
					local state = "Off"
					if Kaitun.enabled then
						if getgenv().Sea2Farm then state = "Sea 2 farm"
						elseif getgenv().KaitunFarm then state = "Farming"
						elseif getgenv().KaitunSea2Pending then state = "Joining Sea 2"
						else state = "On" end
					end
					local code = tostring(getgenv().KaitunSea2Code or "")
					statusLabel:SetText("Status: " .. state)
					levelLabel:SetText("Level: " .. tostring(lv and lv.Value or "?"))
					psLabel:SetText("PS: " .. PN_cut(code ~= "" and code or "none", 28))
				end)
				task.wait(1)
			end
		end)
	end

	-- ================= TAB: CUPID =================
	if Tabs.NewCupid then
		local T = Tabs.NewCupid
		local Box = T:AddLeftGroupbox("Cupid Dungeon")
		Box:AddLabel("Menu > Universe Hub > Cupid queue")
		Box:AddLabel("> Dungeon > Store / Replay")
		Box:AddDivider()

		Box:AddToggle("PN_CupidEnabled", {
			Text = "Auto Cupid Dungeon",
			Default = Cupid.enabled and not PN_NoAuto,
			Tooltip = "Runs the Cupid Dungeon script. Stays ON after teleports.",
			Callback = function(v)
				Cupid.enabled = v
				CS.enabled = v
				PN_save()
				if v then
					cupidStart()
					notify("Cupid started", 3)
				else
					cupidStop()
					notify("Cupid stopped", 3)
				end
			end,
		})

		Box:AddInput("PN_CupidWeapon", {
			Text = "Weapon",
			Default = Cupid.weapon,
			Placeholder = "e.g. Kraken Blade (Red)",
			Numeric = false,
			Finished = true,
			Callback = function(v)
				Cupid.weapon = tostring(v or ""); CS.weapon = Cupid.weapon; PN_save(); cupidApplyLive()
			end,
		})

		Box:AddSlider("PN_CupidTween", {
			Text = "Tween Speed", Default = Cupid.tween, Min = 50, Max = 300, Rounding = 0,
			Callback = function(v) Cupid.tween = v; CS.tween = v; PN_save(); cupidApplyLive() end,
		})

		Box:AddDivider()
		local statusLabel = Box:AddLabel("Status: -")
		PN_addOverlayToggle(Box, "PN_CupidOverlay")

		local Opt = T:AddRightGroupbox("Cupid Options")
		local function opt(idx, text, key, tip)
			Opt:AddToggle(idx, {
				Text = text, Default = Cupid[key], Tooltip = tip,
				Callback = function(v) Cupid[key] = v; CS[key] = v; PN_save(); cupidApplyLive() end,
			})
		end
		opt("PN_CupidJoinUniverse", "Auto Join Universe Hub", "joinUniverse")
		opt("PN_CupidJoinQueue",    "Auto Join Cupid Queue",  "joinCupid")
		opt("PN_CupidAutoDungeon",  "Auto Dungeon",           "autoDungeon")
		opt("PN_CupidAutoStore",    "Auto Store",             "autoStore")
		opt("PN_CupidAutoReplay",   "Auto Replay",            "autoReplay")
		opt("PN_CupidAutoEquip",    "Auto Equip Items",       "autoEquip")
		Opt:AddDivider()
		opt("PN_CupidPrivacyCam",   "Privacy Camera (sky view)", "privacyCam")
		opt("PN_CupidHideGui",      "Hide Player GUI",        "hidePlayerGui")
		Opt:AddLabel("Join/camera options: next start")

		task.spawn(function()
			while Library.ScreenGui and Library.ScreenGui.Parent do
				pcall(function()
					local AD = getgenv().PrinceCupidAD
					local state = Cupid.enabled and "On" or "Off"
					if Cupid.enabled and AD and AD.status then state = tostring(AD.status) end
					statusLabel:SetText("Status: " .. PN_cut(state, 26))
				end)
				task.wait(1)
			end
		end)
	end

	-- ================= TAB: WAVES =================
	if Tabs.NewWaves then
		local okWaves, errWaves = pcall(function()
			local T = Tabs.NewWaves
			wavesApi()
			wavesApply()
			PN_WavesTabBuilt = true

			-- Solo و Party مفصولين: كل واحد زر، وما يشتغلون سوه
			local lastMode = nil
			local function wavesSync()
				local solo = Toggles.PN_WavesSolo and Toggles.PN_WavesSolo.Value
				local party = Toggles.PN_WavesParty and Toggles.PN_WavesParty.Value
				local mode = (solo and "Solo") or (party and "Party") or nil
				if mode then
					Waves.enabled = true
					Waves.mode = mode
					wavesStart(mode)
				else
					Waves.enabled = false
					wavesStop()
				end
				WS.enabled = Waves.enabled
				WS.mode = Waves.mode
				PN_save()
				if mode ~= lastMode then
					lastMode = mode
					notify(mode and ("Waves (" .. mode .. ") started") or "Waves stopped", 3)
					if mode and Toggles.PN_CupidEnabled and Toggles.PN_CupidEnabled.Value then
						notify("Cupid tab is ON too: turn it off while farming waves", 6)
					end
				end
			end

			local SoloBox = T:AddLeftGroupbox("Solo")
			SoloBox:AddToggle("PN_WavesSolo", {
				Text = "Auto Waves (Solo)",
				Default = Waves.enabled and Waves.mode == "Solo" and not PN_NoAuto,
				Tooltip = "Kills every NPC in the wave dungeon, then respawns at the target wave",
				Callback = function(v)
					if v and Toggles.PN_WavesParty and Toggles.PN_WavesParty.Value then
						Toggles.PN_WavesParty:SetValue(false)
					end
					wavesSync()
				end,
			})

			local PartyBox = T:AddLeftGroupbox("Party")
			PartyBox:AddToggle("PN_WavesParty", {
				Text = "Auto Waves (Party)",
				Default = Waves.enabled and Waves.mode == "Party" and not PN_NoAuto,
				Tooltip = "Same farm, but shares the NPCs with your party members",
				Callback = function(v)
					if v and Toggles.PN_WavesSolo and Toggles.PN_WavesSolo.Value then
						Toggles.PN_WavesSolo:SetValue(false)
					end
					wavesSync()
				end,
			})
			PartyBox:AddToggle("PN_WavesSplit", {
				Text = "Split targets with team",
				Default = Waves.split,
				Tooltip = "Skip the NPC a teammate is already on and take another one",
				Callback = function(v) Waves.split = v; WS.split = v; PN_save(); wavesApply() end,
			})
			local teamLabel = PartyBox:AddLabel("Team in arena: -")

			local Stat = T:AddLeftGroupbox("Status")
			local stateLabel = Stat:AddLabel("State: -")
			local waveLabel = Stat:AddLabel("Wave: -")
			local npcLabel = Stat:AddLabel("NPCs: -")
			local runLabel = Stat:AddLabel("Runs: -")
			local weaponLabel = Stat:AddLabel("Weapon: -")
			local noteLabel = Stat:AddLabel(" ")
			PN_addOverlayToggle(Stat, "PN_WavesOverlay")
			Stat:AddDivider()
			Stat:AddLabel("Enter the dungeon yourself,")
			Stat:AddLabel("the bot starts when you arrive.")

			local Set = T:AddRightGroupbox("Waves Settings")

			-- السلاح: اختيار من اللي بإيدك وبالباكباك ("--" = تلقائي)
			local function weaponValues()
				local list = {}
				pcall(function()
					for _, name in ipairs(wavesApi().listWeapons()) do
						list[#list + 1] = name
					end
				end)
				if Waves.weapon ~= "" and not PN_indexOf(list, Waves.weapon) then
					table.insert(list, 1, Waves.weapon)
				end
				return list
			end

			local firstValues = weaponValues()
			local lastWeaponKey = table.concat(firstValues, "|")
			Set:AddDropdown("PN_WavesWeapon", {
				Values = firstValues,
				Default = (Waves.weapon ~= "") and Waves.weapon or nil,
				AllowNull = true,
				Multi = false,
				Text = "Weapon (from backpack)",
				Tooltip = "Pick one of your tools. Leave it on -- to use the equipped / first weapon",
				Callback = function(v)
					Waves.weapon = (type(v) == "string") and v or ""
					WS.weapons[PN_LocalPlayer.Name] = (Waves.weapon ~= "") and Waves.weapon or nil
					PN_save()
					local W = getgenv().PrinceWaves
					if W then W.weapon = Waves.weapon end
				end,
			})

			local function refreshWeapons(force)
				local dropdown = Options.PN_WavesWeapon
				if not dropdown then return end
				local list = weaponValues()
				local key = table.concat(list, "|")
				if key == lastWeaponKey and not force then return end
				lastWeaponKey = key
				dropdown:SetValues(list)
			end

			Set:AddButton({
				Text = "Refresh weapons",
				Func = function()
					refreshWeapons(true)
					notify("Weapons list updated", 2)
				end,
				Tooltip = "Reload the list from your backpack",
			})

			Set:AddInput("PN_WavesTarget", {
				Text = "Respawn at wave",
				Default = tostring(Waves.targetWave),
				Placeholder = "25",
				Numeric = true,
				Finished = true,
				Callback = function(v)
					local n = tonumber(v)
					if not n then return end
					n = math.max(2, math.floor(n))
					Waves.targetWave = n; WS.targetWave = n; PN_save(); wavesApply()
				end,
			})
			Set:AddSlider("PN_WavesTween", {
				Text = "Tween Speed", Default = Waves.tween, Min = 20, Max = 200, Rounding = 0,
				Callback = function(v) Waves.tween = v; WS.tween = v; PN_save(); wavesApply() end,
			})
			Set:AddSlider("PN_WavesHover", {
				Text = "Hover Height", Default = Waves.hover, Min = 4, Max = 20, Rounding = 1,
				Callback = function(v) Waves.hover = v; WS.hover = v; PN_save(); wavesApply() end,
			})
			Set:AddSlider("PN_WavesRadius", {
				Text = "Attack Radius", Default = Waves.radius, Min = 15, Max = 150, Rounding = 0,
				Callback = function(v) Waves.radius = v; WS.radius = v; PN_save(); wavesApply() end,
			})
			Set:AddDivider()
			Set:AddToggle("PN_WavesCenter", {
				Text = "Return to center when idle",
				Default = Waves.returnCenter,
				Tooltip = "Between waves, go back to where you spawned in the arena",
				Callback = function(v) Waves.returnCenter = v; WS.returnCenter = v; PN_save(); wavesApply() end,
			})
			Set:AddToggle("PN_WavesBuso", {
				Text = "Auto Buso Haki (J key)",
				Default = Waves.buso,
				Tooltip = "Presses J once, 3s after the weapon is equipped (same as the Cupid script)",
				Callback = function(v) Waves.buso = v; WS.buso = v; PN_save(); wavesApply() end,
			})

			-- يحدّث الـ label بس إذا النص تغير
			local shown = {}
			local function setLabel(label, text)
				if shown[label] ~= text then
					shown[label] = text
					label:SetText(text)
				end
			end

			task.spawn(function()
				local tickCount = 0
				while Library.ScreenGui and Library.ScreenGui.Parent do
					pcall(function()
						local W = getgenv().PrinceWaves
						if not W then return end
						setLabel(stateLabel, "State: " .. PN_cut(W.status, 26))
						setLabel(waveLabel, "Wave: " .. tostring(W.wave or "?") .. " / " .. tostring(W.targetWave))
						setLabel(npcLabel, "NPCs: " .. tostring(W.npcCount) .. "   Kills: " .. tostring(W.kills))
						setLabel(runLabel, "Runs: " .. tostring(W.runs) .. "   Deaths: " .. tostring(W.deaths))
						setLabel(weaponLabel, "Weapon: " .. PN_cut((W.weapon ~= "" and W.weapon) or "auto", 24))
						setLabel(noteLabel, PN_cut(W.note or " ", 34))
						setLabel(teamLabel, "Team in arena: " .. ((W.enabled and W.mode == "Party") and tostring(W.teammates) or "-"))
					end)
					-- قائمة الأسلحة تتحدث وحدها إذا تغير الباكباك
					tickCount = tickCount + 1
					if tickCount % 4 == 0 then
						pcall(refreshWeapons, false)
					end
					task.wait(0.5)
				end
			end)
		end)
		if not okWaves then
			notify("Waves tab error: " .. tostring(errWaves), 10)
		end
	end

	-- ================= TAB: IMPEL =================
	if Tabs.NewImpel then
		local okImpel, errImpel = pcall(function()
			local T = Tabs.NewImpel
			local I = impelApi()
			impelApply()
			PN_ImpelTabBuilt = true

			local Box = T:AddLeftGroupbox("Impel Down (zephyron)")
			Box:AddLabel("Menu > Universe > Sea 2 circle")
			Box:AddLabel("Dungeon: floors 1-5 > shop")
			Box:AddLabel("Movement = Kaitun (new) flight")
			Box:AddDivider()
			Box:AddToggle("PN_ImpelEnabled", {
				Text = "Auto Impel Down",
				Default = Impel.enabled and not PN_NoAuto,
				Tooltip = "Runs the zephyron Impel Down script. Stays ON after teleports.",
				Callback = function(v)
					-- [PRINCE HUB] ما يشتغل ويه Auto Impel (test) بنفس الوقت
					if v and Toggles.PN_ITEnabled and Toggles.PN_ITEnabled.Value then
						pcall(function() Toggles.PN_ITEnabled:SetValue(false) end)
						notify("Auto Impel (test) turned OFF (cannot run both)", 4)
					end
					-- [PRINCE HUB] ما يشتغل ويه Impel Down Zyph بنفس الوقت
					if v and getgenv().PrinceZyph and getgenv().PrinceZyph.running then
						notify("Impel Down Zyph is running: turn it OFF and rejoin first", 5)
						task.defer(function() pcall(function() Toggles.PN_ImpelEnabled:SetValue(false) end) end)
						return
					end
					Impel.enabled = v
					IS.enabled = v
					PN_save()
					local api = impelApi()
					if not api then return end
					if v then
						impelApply()
						api.start()
						notify("Impel Down started", 3)
						local others = (Toggles.PN_WavesSolo and Toggles.PN_WavesSolo.Value)
							or (Toggles.PN_WavesParty and Toggles.PN_WavesParty.Value)
							or (Toggles.PN_CupidEnabled and Toggles.PN_CupidEnabled.Value)
							or (Toggles.PN_KaitunEnabled and Toggles.PN_KaitunEnabled.Value)
						if others then
							notify("Kaitun/Cupid/Waves is ON too: turn it off", 6)
						end
					else
						api.stop()
						notify("Impel Down stopped", 3)
					end
				end,
			})

			local Stat = T:AddLeftGroupbox("Status")
			local stateLabel = Stat:AddLabel("State: -")
			local placeLabel = Stat:AddLabel("Place: -")
			local npcLabel = Stat:AddLabel("NPC: -")
			local mythLabel = Stat:AddLabel("Mythical: -")
			local pointsLabel = Stat:AddLabel("Points: -")
			local timeLabel = Stat:AddLabel("Time: -")
			PN_addOverlayToggle(Stat, "PN_ImpelOverlay")

			local Set = T:AddRightGroupbox("Impel Settings")
			Set:AddSlider("PN_ImpelTween", {
				Text = "Flight Speed", Default = Impel.tween, Min = 20, Max = 200, Rounding = 0,
				Callback = function(v) Impel.tween = v; IS.tween = v; PN_save(); impelApply() end,
			})
			Set:AddToggle("PN_ImpelNoclip", {
				Text = "Noclip",
				Default = Impel.noclip,
				Tooltip = "Original noClip + noclip of the Kaitun flight",
				Callback = function(v)
					Impel.noclip = v; IS.noclip = v; PN_save(); impelApply()
					local I2 = getgenv().PrinceImpel
					if not v and I2 and I2.noclipOff then
						pcall(I2.noclipOff)
					end
				end,
			})
			Set:AddToggle("PN_ImpelRaycast", {
				Text = "Raycast walls",
				Default = Impel.raycast,
				Tooltip = "Checks the whole body ahead; wall found -> TP behind it (or over it / to the target)",
				Callback = function(v) Impel.raycast = v; IS.raycast = v; PN_save(); impelApply() end,
			})
			-- [PRINCE HUB] ارتفاع TP الـ Impel: بار خاص لكل طابق (1 - 5000)، كل بار يبدي على ارتفاع الأصل
			--   TP الـ raycast ما يتأثر (يبقى على ارتفاع الأصل)
			local TPH = Set
			pcall(function() TPH = T:AddLeftGroupbox("Impel TP Height (per floor)") end)
			local TPF_DEFAULTS = { 2600, 2800, 3000, 1500 }
			local tpfControls = {}
			local function tpfSet(f, v, from)
				v = tonumber(v)
				if not v then return end
				v = math.clamp(math.floor(v + 0.5), 1, 5000)
				Impel["tpF" .. f] = v; IS["tpF" .. f] = v; PN_save(); impelApply()
				local c = tpfControls[f]
				if not c then return end
				pcall(function()
					c.label:SetText("Floor " .. f .. ": " .. v .. ((v == TPF_DEFAULTS[f]) and "  (default)" or ("  (default " .. TPF_DEFAULTS[f] .. ")")))
				end)
				c.syncing = true
				pcall(function()
					if from ~= "slider" and c.slider then c.slider:SetValue(v) end
					if from ~= "input" and c.input then c.input:SetValue(tostring(v)) end
				end)
				c.syncing = false
			end
			for f = 1, 4 do
				local c = { syncing = false }
				tpfControls[f] = c
				local cur = math.clamp(tonumber(Impel["tpF" .. f]) or TPF_DEFAULTS[f], 1, 5000)
				c.label = TPH:AddLabel("Floor " .. f .. ": " .. cur)
				c.slider = TPH:AddSlider("PN_ImpelTPF" .. f, {
					Text = "Floor " .. f .. " TP height", Default = cur, Min = 1, Max = 5000, Rounding = 0,
					Callback = function(v) if not c.syncing then tpfSet(f, v, "slider") end end,
				})
				c.input = TPH:AddInput("PN_ImpelTPF" .. f .. "Exact", {
					Text = "Floor " .. f .. " exact",
					Default = tostring(cur),
					Placeholder = tostring(TPF_DEFAULTS[f]),
					Numeric = true,
					Finished = true,
					Callback = function(v) if not c.syncing then tpfSet(f, v, "input") end end,
				})
				TPH:AddButton({
					Text = "Reset floor " .. f .. " (" .. TPF_DEFAULTS[f] .. ")",
					Func = function() tpfSet(f, TPF_DEFAULTS[f]) end,
				})
				tpfSet(f, cur, "init")
			end
			TPH:AddButton({
				Text = "Reset all floors",
				Func = function() for f = 1, 4 do tpfSet(f, TPF_DEFAULTS[f]) end end,
			})
			Set:AddInput("PN_ImpelPS", {
				Text = "PS Code (main menu)",
				Default = Impel.psCode,
				Placeholder = "Misc.PsCode",
				Numeric = false,
				Finished = true,
				Callback = function(v) Impel.psCode = tostring(v or ""); IS.psCode = Impel.psCode; PN_save(); impelApply() end,
			})
			Set:AddInput("PN_ImpelWebhook", {
				Text = "Discord Webhook",
				Default = Impel.webhook,
				Placeholder = "https://discord.com/api/webhooks/...",
				Numeric = false,
				Finished = true,
				Callback = function(v) Impel.webhook = tostring(v or ""); IS.webhook = Impel.webhook; PN_save(); impelApply() end,
			})
			Set:AddInput("PN_ImpelFps", {
				Text = "FPS Cap (0 = off)",
				Default = tostring(Impel.fpsCap),
				Placeholder = "25",
				Numeric = true,
				Finished = true,
				Callback = function(v)
					local n = tonumber(v)
					if not n then return end
					Impel.fpsCap = math.max(0, math.floor(n)); IS.fpsCap = Impel.fpsCap; PN_save(); impelApply()
				end,
			})
			Set:AddToggle("PN_ImpelFast", {
				Text = "Fast Mode (low graphics)",
				Default = Impel.fastMode,
				Tooltip = "Applied when Auto Impel starts. Cannot be undone without rejoining.",
				Callback = function(v) Impel.fastMode = v; IS.fastMode = v; PN_save(); impelApply() end,
			})
			Set:AddToggle("PN_ImpelErrorKick", {
				Text = "Auto DC on script error",
				Default = Impel.errorKick,
				Tooltip = "Original anti-ban: kicks you on any script error (Seliware/Potassium/Wave/Velocity only)",
				Callback = function(v) Impel.errorKick = v; IS.errorKick = v; PN_save(); impelApply() end,
			})

			local Circle = T:AddRightGroupbox("Circle Queue (Sea 2)")
			Circle:AddToggle("PN_ImpelCircle", {
				Text = "Use queue order",
				Default = Impel.circleOn,
				Tooltip = "Accounts wait for higher-priority accounts at the Impel circle",
				Callback = function(v) Impel.circleOn = v; IS.circleOn = v; PN_save(); impelApply() end,
			})
			Circle:AddInput("PN_ImpelOrder", {
				Text = "Order (names, comma)",
				Default = Impel.circleOrder,
				Placeholder = "acc1,acc2,acc3",
				Numeric = false,
				Finished = true,
				Callback = function(v) Impel.circleOrder = tostring(v or ""); IS.circleOrder = Impel.circleOrder; PN_save(); impelApply() end,
			})

			local shown = {}
			local function setLabel(label, text)
				if shown[label] ~= text then
					shown[label] = text
					label:SetText(text)
				end
			end
			task.spawn(function()
				while Library.ScreenGui and Library.ScreenGui.Parent do
					pcall(function()
						local placeText = tostring(I.place)
						if I.place == "Dungeon" and I.floor then
							placeText = "Dungeon   Floor: " .. tostring(I.floor)
						end
						setLabel(stateLabel, "State: " .. PN_cut(I.status, 26))
						setLabel(placeLabel, "Place: " .. PN_cut(placeText, 27))
						setLabel(npcLabel, "NPC: " .. PN_cut(I.npcName or "-", 29))
						setLabel(mythLabel, "Mythical this session: " .. tostring(I.mythical or 0))
						setLabel(pointsLabel, "Points: " .. PN_cut(tostring(I.points or "?"), 26))
						setLabel(timeLabel, "Time: " .. tostring(I.farmTime or "-"))
					end)
					task.wait(0.5)
				end
			end)
		end)
		if not okImpel then
			notify("Impel tab error: " .. tostring(errImpel), 10)
		end
	end

	-- ================= TAB: IMPEL DOWN ZYPH (السكربت الأصلي) =================
	if Tabs.NewZyph then
		local okZyph, errZyph = pcall(function()
			local T = Tabs.NewZyph

			local Box = T:AddLeftGroupbox("Auto Impel Down Zyph")
			Box:AddLabel("Original zephyron script, 100% unchanged", true)
			Box:AddLabel("Menu > PS code > Universe queue > Sea 2 circle > Dungeon floors 1-5 > shop", true)
			Box:AddDivider()
			Box:AddToggle("PN_ZyphEnabled", {
				Text = "Auto Impel Down Zyph",
				Default = Zyph.enabled and not PN_NoAuto,
				Tooltip = "Runs the original zyph script. Stays ON after teleports (auto execute).",
				Callback = function(v)
					Zyph.enabled = v
					ZS.enabled = v
					PN_save()
					if v then
						if Toggles.PN_ITEnabled and Toggles.PN_ITEnabled.Value then
							pcall(function() Toggles.PN_ITEnabled:SetValue(false) end)
							notify("Auto Impel (test) turned OFF (cannot run both)", 4)
						end
						-- ما يصير يشتغل ويه تبويب Impel بنفس الوقت
						if Toggles.PN_ImpelEnabled and Toggles.PN_ImpelEnabled.Value then
							pcall(function() Toggles.PN_ImpelEnabled:SetValue(false) end)
							notify("Impel tab turned OFF (cannot run both)", 4)
						end
						local Z = getgenv().PrinceZyph
						if Z and Z.running then
							notify("Impel Down Zyph already running", 3)
						else
							zyphStart()
							notify("Impel Down Zyph started", 3)
						end
					else
						local Z = getgenv().PrinceZyph
						if Z and Z.running then
							-- السكربت الأصلي ما بيه زر وقف، فيوقف بالسيرفر الجاي
							notify("Zyph saved OFF: it stops after the next teleport / rejoin", 6)
						end
					end
				end,
			})
			local zStatus = Box:AddLabel("Status: " .. ((getgenv().PrinceZyph and getgenv().PrinceZyph.running) and "running" or "off"), true)

			local Stat = T:AddLeftGroupbox("Stats")
			PN_addOverlayToggle(Stat, "PN_ZyphOverlay")

			local Set = T:AddRightGroupbox("Config (getgenv().Config)")
			Set:AddLabel("Empty / default = same as the original", true)
			Set:AddInput("PN_ZyphPS", {
				Text = "PS Code (Misc.PsCode)",
				Default = Zyph.psCode,
				Placeholder = "private server code",
				Numeric = false,
				Finished = true,
				Callback = function(v) Zyph.psCode = tostring(v or ""); ZS.psCode = Zyph.psCode; PN_save() end,
			})
			Set:AddInput("PN_ZyphWebhook", {
				Text = "Webhook (Misc.WebhookURL)",
				Default = Zyph.webhook,
				Placeholder = "https://discord.com/api/webhooks/...",
				Numeric = false,
				Finished = true,
				Callback = function(v) Zyph.webhook = tostring(v or ""); ZS.webhook = Zyph.webhook; PN_save() end,
			})
			Set:AddToggle("PN_ZyphFast", {
				Text = "Fast Mode (Misc.FastMode)",
				Default = Zyph.fastMode == true,
				Callback = function(v) Zyph.fastMode = v; ZS.fastMode = v; PN_save() end,
			})
			Set:AddSlider("PN_ZyphFps", {
				Text = "FPS Cap (Misc.FpsCap)", Default = math.clamp(tonumber(Zyph.fpsCap) or 25, 5, 240), Min = 5, Max = 240, Rounding = 0,
				Callback = function(v) Zyph.fpsCap = v; ZS.fpsCap = v; PN_save() end,
			})
			Set:AddToggle("PN_ZyphCircle", {
				Text = "Circle Queue (CircleQueue.Enabled)",
				Default = Zyph.circleOn ~= false,
				Callback = function(v) Zyph.circleOn = v; ZS.circleOn = v; PN_save() end,
			})
			Set:AddInput("PN_ZyphOrder", {
				Text = "Queue order (names, comma)",
				Default = Zyph.circleOrder,
				Placeholder = "Account1,Account2,Account3",
				Numeric = false,
				Finished = true,
				Callback = function(v) Zyph.circleOrder = tostring(v or ""); ZS.circleOrder = Zyph.circleOrder; PN_save() end,
			})
			Set:AddLabel("Config changes apply on the next start (next server / execute)", true)

			task.spawn(function()
				while task.wait(1) do
					pcall(function()
						local Z = getgenv().PrinceZyph
						local txt = "off"
						if Z and Z.running then
							txt = (Z.error and ("error: " .. PN_cut(Z.error, 40))) or ("running " .. PN_fmtTime(tick() - Z.startTick))
						end
						if Zyph.enabled == false and Z and Z.running then
							txt = txt .. " (OFF next server)"
						end
						zStatus:SetText("Status: " .. txt)
					end)
				end
			end)
		end)
		if not okZyph then
			notify("Impel Down Zyph tab error: " .. tostring(errZyph), 10)
		end
	end

	-- ================= TAB: AUTO IMPEL (TEST) =================
	if Tabs.NewImpelTest then
		local okIT, errIT = pcall(function()
			local T = Tabs.NewImpelTest
			local function setOpt(key, v)
				ImpelTest[key] = v
				ITS[key] = v
				PN_save()
				itApply()
			end

			-- ---------- control ----------
			local Box = T:AddLeftGroupbox("Auto Impel (test)")
			Box:AddLabel("New engine written from scratch + checking system", true)
			Box:AddToggle("PN_ITEnabled", {
				Text = "Auto Impel (test)",
				Default = ImpelTest.enabled and not PN_NoAuto,
				Tooltip = "Menu > Universe queue > floors 1-5 > shop. Stays ON after teleports.",
				Callback = function(v)
					if v and getgenv().PrinceZyph and getgenv().PrinceZyph.running then
						notify("Impel Down Zyph is running: turn it OFF and rejoin first", 5)
						task.defer(function() pcall(function() Toggles.PN_ITEnabled:SetValue(false) end) end)
						return
					end
					ImpelTest.enabled = v
					ITS.enabled = v
					PN_save()
					if v then
						if Toggles.PN_ImpelEnabled and Toggles.PN_ImpelEnabled.Value then
							pcall(function() Toggles.PN_ImpelEnabled:SetValue(false) end)
							notify("Impel tab turned OFF (cannot run both)", 4)
						end
						if itStart() then notify("Auto Impel (test) started", 3) end
					else
						itStop()
					end
				end,
			})
			local lState = Box:AddLabel("State: off", true)
			local lWhere = Box:AddLabel("Where: -", true)
			local lTarget = Box:AddLabel("Target: -", true)

			local Stat = T:AddLeftGroupbox("Stats")
			PN_addOverlayToggle(Stat, "PN_ITOverlay")

			-- ---------- diagnostics (نظام المعالجة) ----------
			local Diag = T:AddLeftGroupbox("Diagnostics (checks everything)")
			local lOverall = Diag:AddLabel("Health: -", true)
			local CHECKS = { "Settings", "Place", "Character", "Position", "Remotes", "Map", "Weapon", "Haki", "Movement", "Combat", "Errors", "Progress", "Performance" }
			local checkLabels = {}
			for _, name in ipairs(CHECKS) do
				checkLabels[name] = Diag:AddLabel(name .. ": -", true)
			end
			local lLastErr = Diag:AddLabel("Last error: none", true)
			local lLastRec = Diag:AddLabel("Last fix: none", true)
			local function getReport()
				local api = itApi()
				if not api then return "Auto Impel (test) not loaded" end
				return api.runChecksNow()
			end
			Diag:AddButton({
				Text = "Run full check now",
				Func = function()
					local rep = getReport()
					print(rep)
					local api = getgenv().PrinceImpelTest
					notify("Check done: " .. tostring(api and api.diag and api.diag.overall or "?") .. " (full report in console F9)", 5)
				end,
			})
			Diag:AddButton({
				Text = "Copy report",
				Func = function()
					local rep = getReport()
					if type(setclipboard) == "function" then
						pcall(setclipboard, rep)
						notify("Report copied", 3)
					else
						print(rep)
						notify("No clipboard here: report printed in console (F9)", 4)
					end
				end,
			})
			Diag:AddButton({
				Text = "Reset errors",
				Func = function()
					local api = getgenv().PrinceImpelTest
					if api then api.resetErrors() end
					notify("Errors cleared", 2)
				end,
			})

			-- ---------- settings ----------
			local Set = T:AddRightGroupbox("Settings")
			Set:AddSlider("PN_ITSpeed", { Text = "Fly speed", Default = math.clamp(ImpelTest.speed, 20, 300), Min = 20, Max = 300, Rounding = 0,
				Callback = function(v) setOpt("speed", v) end })
			Set:AddToggle("PN_ITVertTP", { Text = "TP up/down to safe height", Default = ImpelTest.verticalTP ~= false,
				Tooltip = "ON = like the original (instant TP for the vertical part). OFF = fly it.",
				Callback = function(v) setOpt("verticalTP", v) end })
			Set:AddSlider("PN_ITLowHP", { Text = "Retreat under HP", Default = math.clamp(ImpelTest.lowHP, 0, 3000), Min = 0, Max = 3000, Rounding = 0,
				Callback = function(v) setOpt("lowHP", v) end })
			Set:AddSlider("PN_ITRadius", { Text = "Hit radius", Default = math.clamp(ImpelTest.attackRadius, 5, 30), Min = 5, Max = 30, Rounding = 0,
				Callback = function(v) setOpt("attackRadius", v) end })
			Set:AddSlider("PN_ITRange", { Text = "Target range", Default = math.clamp(ImpelTest.targetRange, 100, 1500), Min = 100, Max = 1500, Rounding = 0,
				Callback = function(v) setOpt("targetRange", v) end })
			Set:AddToggle("PN_ITMyth", { Text = "Buy Mythical Fruit Chest", Default = ImpelTest.buyMythical ~= false,
				Callback = function(v) setOpt("buyMythical", v) end })
			Set:AddInput("PN_ITDiff", { Text = "Difficulty button", Default = ImpelTest.difficulty, Placeholder = "Nightmare", Numeric = false, Finished = true,
				Callback = function(v) setOpt("difficulty", (tostring(v or "") ~= "" and tostring(v)) or "Nightmare") end })
			Set:AddDivider()
			Set:AddToggle("PN_ITQueue", { Text = "Auto queue in Universe", Default = ImpelTest.autoQueue ~= false,
				Callback = function(v) setOpt("autoQueue", v) end })
			Set:AddInput("PN_ITPS", { Text = "PS code (main menu)", Default = ImpelTest.psCode, Placeholder = "empty = public", Numeric = false, Finished = true,
				Callback = function(v) setOpt("psCode", tostring(v or "")) end })
			Set:AddToggle("PN_ITLeave", { Text = "Other places -> Universe", Default = ImpelTest.leaveOtherPlaces ~= false,
				Callback = function(v) setOpt("leaveOtherPlaces", v) end })
			Set:AddDivider()
			Set:AddToggle("PN_ITRejoin", { Text = "Auto rejoin if stuck (no progress)", Default = ImpelTest.autoRejoinOnStall == true,
				Callback = function(v) setOpt("autoRejoinOnStall", v) end })
			Set:AddSlider("PN_ITStall", { Text = "No progress limit (min)", Default = math.clamp(ImpelTest.stallMinutes, 1, 30), Min = 1, Max = 30, Rounding = 0,
				Callback = function(v) setOpt("stallMinutes", v) end })
			Set:AddToggle("PN_ITDebug", { Text = "Debug log in console", Default = ImpelTest.debug == true,
				Callback = function(v) setOpt("debug", v) end })

			local Hgt = T:AddRightGroupbox("Safe height per floor")
			for f = 1, 5 do
				Hgt:AddSlider("PN_ITH" .. f, {
					Text = "Floor " .. f .. " (default " .. IT_DEFAULT_HEIGHTS[f] .. ")",
					Default = math.clamp(ImpelTest.heights[f], 1, 5000), Min = 1, Max = 5000, Rounding = 0,
					Callback = function(v)
						ImpelTest.heights[f] = v
						ITS["h" .. f] = v
						PN_save()
						itApply()
					end,
				})
			end
			Hgt:AddButton({ Text = "Reset heights", Func = function()
				for f = 1, 5 do pcall(function() Options["PN_ITH" .. f]:SetValue(IT_DEFAULT_HEIGHTS[f]) end) end
			end })

			-- ---------- live refresh ----------
			local ICON = { OK = "OK", WARN = "WARN", FAIL = "FAIL" }
			task.spawn(function()
				while task.wait(1) do
					pcall(function()
						local api = getgenv().PrinceImpelTest
						if not api then
							lState:SetText("State: not loaded")
							return
						end
						local D = api.diag
						lState:SetText("State: " .. tostring(api.state) .. (api.detail ~= "" and (" | " .. tostring(api.detail)) or ""))
						lWhere:SetText("Where: " .. tostring(api.place) .. " / floor " .. tostring(api.floor or "-") .. " / stage " .. tostring(api.stage or "-"))
						lTarget:SetText("Target: " .. tostring(api.targetName or "-") .. " | kills " .. tostring(api.kills or 0))
						lOverall:SetText("Health: " .. tostring(D.overall) .. " | errors " .. D.errorCount .. " (" .. D.recentErrors(60) .. "/60s)")
						for _, name in ipairs(CHECKS) do
							local r = D.results[name]
							if r then
								checkLabels[name]:SetText("[" .. (ICON[r.status] or r.status) .. "] " .. name .. ": " .. PN_cut(tostring(r.msg), 40))
							end
						end
						local e = D.errors[#D.errors]
						if e then
							lLastErr:SetText("Last error: " .. PN_cut(e.where .. ": " .. (e.msg:gsub("\n.*", "")), 60))
						end
						local rc = D.recoveries[#D.recoveries]
						if rc then
							lLastRec:SetText("Last fix: " .. PN_cut(rc.name .. ": " .. tostring(rc.msg), 60))
						end
					end)
				end
			end)
		end)
		if not okIT then
			notify("Auto Impel (test) tab error: " .. tostring(errIT), 10)
		end
	end

	-- إعدادات التبويبات الجديدة محفوظة بملفها (PrinceHubNewTabs.json)،
	-- فنخلي كونفكات الهب تتجاهلها.
	pcall(function()
		if not (SaveManager and SaveManager.SetIgnoreIndexes) then return end
		local ids = {}
		for _, registry in ipairs({ Toggles or {}, Options or {} }) do
			for idx in pairs(registry) do
				if type(idx) == "string" and string.sub(idx, 1, 3) == "PN_" then
					ids[#ids + 1] = idx
				end
			end
		end
		SaveManager:SetIgnoreIndexes(ids)
	end)

	-- [PRINCE HUB v20] Halloween look (after every tab and groupbox exists)
	PH_try("Halloween UI", PN_Halloween.apply, Library)
end

