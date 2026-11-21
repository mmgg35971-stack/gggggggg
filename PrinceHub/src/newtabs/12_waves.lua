-- ------------------------------------------------------------
-- Waves start / stop
-- ------------------------------------------------------------
-- يحمّل MODULE: Waves مرة وحدة ويرجع الـ API مالته (getgenv().PrinceWaves)
local function wavesApi()
	if not getgenv().PrinceWaves then
		local ok, err = pcall(Modules.Waves)
		if not ok then
			pcall(function()
				getgenv().Library:Notify("[Waves] error: " .. tostring(err), 10)
			end)
		end
	end
	return getgenv().PrinceWaves
end

-- ينقل إعدادات التبويب للموديول (تتطبق فوراً حتى وهو شغّال)
local function wavesApply()
	local W = getgenv().PrinceWaves
	if not W then return end
	W.targetWave = Waves.targetWave
	W.tweenSpeed = Waves.tween
	W.hoverHeight = Waves.hover
	W.attackRadius = Waves.radius
	W.returnToCenter = Waves.returnCenter
	W.autoBuso = Waves.buso
	W.splitTargets = Waves.split
	if Waves.weapon ~= "" then
		W.weapon = Waves.weapon
	end
end

local function wavesStart(mode)
	local W = wavesApi()
	if not W then return false end
	wavesApply()
	W.start(mode)
	return true
end

local function wavesStop()
	local W = getgenv().PrinceWaves
	if W then W.stop() end
end

local PN_WavesTabBuilt = false -- التبويب ينبني بس خارج المين منيو

