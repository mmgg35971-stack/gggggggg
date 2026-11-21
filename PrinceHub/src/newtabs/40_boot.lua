-- يشغّل الموديولات المفعّلة بعد ما الهب يحمّل
function PrinceNewTabs.boot()
	-- [PRINCE HUB v19] Prince AI: يحلل بس (Advise) إلا إذا اخترت Auto-fix، فيشتغل حتى ويا PrinceHubAutoStart = false
	if PrinceAI.enabled then PH_try("Prince AI start", PrinceAI.start) end
	if PN_NoAuto then return end
	if Kaitun.enabled then kaitunStart() end
	if Cupid.enabled then cupidStart() end
	if Waves.enabled and PN_WavesTabBuilt then wavesStart(Waves.mode) end
	if Zyph.enabled then
		zyphStart() -- السكربت الأصلي: يشتغل بكل الأماكن (مين منيو / Universe / سي 2 / الدنجن)
	elseif ImpelTest.enabled then
		itStart() -- Auto Impel (test): يشتغل بكل الأماكن
	elseif Impel.enabled and PN_ImpelTabBuilt then
		local I = impelApi()
		if I then impelApply(); I.start() end
	end
end

