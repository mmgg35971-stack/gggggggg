-- ------------------------------------------------------------
-- Impel start / stop
-- ------------------------------------------------------------
local function impelApi()
	if not getgenv().PrinceImpel then
		-- globals مال zephyron (Npc, floor, ...) ببيئة خاصة حتى ما تتعارض ويه الهب
		pcall(function()
			if setfenv and getfenv then
				setfenv(Modules.Impel, setmetatable({}, { __index = getfenv(1) }))
			end
		end)
		local ok, err = pcall(Modules.Impel)
		if not ok then
			pcall(function()
				getgenv().Library:Notify("[Impel] error: " .. tostring(err), 10)
			end)
		end
	end
	return getgenv().PrinceImpel
end

local function impelApply()
	local I = getgenv().PrinceImpel
	if not I then return end
	I.tweenSpeed = Impel.tween
	I.errorKick = Impel.errorKick
	I.noclip = Impel.noclip
	I.raycast = Impel.raycast
	I.tpFloor = { [1] = Impel.tpF1, [2] = Impel.tpF2, [3] = Impel.tpF3, [4] = Impel.tpF4 }
	local misc = I.config.Misc
	misc.PsCode = Impel.psCode
	misc.WebhookURL = Impel.webhook
	misc.FpsCap = Impel.fpsCap
	misc.FastMode = Impel.fastMode
	if Impel.webhook ~= "" then
		getgenv().WebHook = Impel.webhook
	end
	local order = {}
	for name in string.gmatch(Impel.circleOrder or "", "[^,%s]+") do
		order[#order + 1] = name
	end
	I.config.CircleQueue.Enabled = Impel.circleOn
	I.config.CircleQueue.Order = order
end

local PN_ImpelTabBuilt = false

