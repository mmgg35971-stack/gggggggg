-- ------------------------------------------------------------
-- Impel Down Zyph: يشغّل السكربت الأصلي (Modules.ImpelZyph) مثل ما هو
-- ------------------------------------------------------------
local ZS = PN_Saved.Zyph
-- القيم الافتراضية = نفس getgenv().Config اللي بأول السكربت الأصلي
local Zyph = {
	enabled     = ZS.enabled == true,
	psCode      = PN_pick(ZS.psCode, ""),
	fastMode    = PN_pick(ZS.fastMode, false),
	webhook     = PN_pick(ZS.webhook, ""),
	fpsCap      = PN_pick(tonumber(ZS.fpsCap), 25),
	circleOn    = PN_pick(ZS.circleOn, true),
	circleOrder = PN_pick(ZS.circleOrder, ""),
}

local function zyphOrderList()
	local list = {}
	for name in string.gmatch(tostring(Zyph.circleOrder or ""), "[^,%s]+") do
		list[#list + 1] = name
	end
	if #list == 0 then
		list = { "", "", "", "" } -- نفس الأصل
	end
	return list
end

-- يندمج ويه الـ Config اللي يسويه السكربت الأصلي (القيم الفاضية = نفس الأصل)
local function zyphMergeConfig(cfg)
	cfg.Misc = type(cfg.Misc) == "table" and cfg.Misc or {}
	cfg.Misc.PsCode = Zyph.psCode
	cfg.Misc.FastMode = Zyph.fastMode == true
	cfg.Misc.WebhookURL = Zyph.webhook
	cfg.Misc.FpsCap = tonumber(Zyph.fpsCap) or 25
	cfg.CircleQueue = type(cfg.CircleQueue) == "table" and cfg.CircleQueue or {}
	cfg.CircleQueue.Enabled = Zyph.circleOn ~= false
	cfg.CircleQueue.Order = zyphOrderList()
	return cfg
end

