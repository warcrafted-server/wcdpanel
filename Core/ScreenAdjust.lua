-- Desplaza los frames de Blizzard que se solaparían con las barras ancladas a TOP/BOTTOM.
-- Captura la posición natural de cada frame la primera vez que lo toca (antes de moverlo) y
-- siempre reaplica offset natural + altura de barras, nunca offsets acumulados.

local TOP_FRAMES = {
	"PlayerFrame", "TargetFrame", "PartyMemberFrame1", "TicketStatusFrame",
	"TemporaryEnchantFrame", "ConsolidatedBuffs", "BuffFrame", "MinimapCluster",
	"WorldStateAlwaysUpFrame",
}
local BOTTOM_FRAMES = { "MainMenuBar", "MultiBarRight", "VehicleMenuBar" }

local natural = {}

local function captureNatural(name)
	if natural[name] then return natural[name] end
	local frame = _G[name]
	if not frame then return nil end
	local point, relTo, relPoint, x, y = frame:GetPoint(1)
	if not point then return nil end
	natural[name] = { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y }
	return natural[name]
end

local function adjustFrame(self, name, offset, sign)
	if self.db.profile.general.adjust[name] == false then return end
	local frame = _G[name]
	if not frame then return end
	local base = captureNatural(name)
	if not base then return end
	frame:ClearAllPoints()
	frame:SetPoint(base.point, base.relTo or UIParent, base.relPoint, base.x, base.y + sign * offset)
end

local function totalHeight(self, edge)
	local total = 0
	for id, cfg in pairs(self.db.profile.bars) do
		if cfg.enabled and cfg.edge == edge and cfg.screenAdjust then
			total = total + cfg.height
		end
	end
	return total
end

function WCDPanel:ScreenAdjustAll()
	self:RunOutOfCombat("screenadjust", function()
		local topOffset = totalHeight(self, "TOP")
		local bottomOffset = totalHeight(self, "BOTTOM")
		for _, name in ipairs(TOP_FRAMES) do adjustFrame(self, name, topOffset, -1) end
		for _, name in ipairs(BOTTOM_FRAMES) do adjustFrame(self, name, bottomOffset, 1) end
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function() WCDPanel:ScreenAdjustAll() end)

-- Defensivo: si Blizzard renombra o quita esta función en algún parche 3.3.5, que no
-- rompa la carga del addon entero por un hooksecurefunc contra un nombre inexistente.
if UIParent_ManageFramePositions then
	hooksecurefunc("UIParent_ManageFramePositions", function() WCDPanel:ScreenAdjustAll() end)
end
