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

-- PLAYER_REGEN_ENABLED es el aviso normal de "ya no estás en combate", pero algunos servidores
-- lo dejan de mandar alguna vez (p.ej. tras un bug de aggro fantasma): sin este respaldo, lo
-- que quedó en cola (el ancho de un botón de profesión, por ejemplo) no se aplicaría nunca y
-- los elementos de después se quedarían amontonados unos sobre otros.
local watchdog = CreateFrame("Frame")
watchdog:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed
	if self.t < 2 then return end
	self.t = 0
	if next(queue) and not InCombatLockdown() then
		local pending = queue
		queue = {}
		for _, fn in pairs(pending) do fn() end
	end
end)
