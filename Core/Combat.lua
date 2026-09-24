-- Aplaza acciones que tocan frames protegidos hasta salir de combate.
-- key deduplica: si se llama varias veces con la misma key antes de salir de combate,
-- solo se ejecuta la última función encolada.

local queue = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function()
	local pending = queue
	queue = {}
	for _, fn in pairs(pending) do
		fn()
	end
end)

function WCDPanel:RunOutOfCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	queue[key or fn] = fn
end
