-- Desplaza los frames de Blizzard que se solaparían con las barras ancladas a TOP/BOTTOM.
--
-- Algunos (MultiBarRight...) los recoloca la propia Blizzard cada vez que corre
-- UIParent_ManageFramePositions, así que no vale capturar su posición una sola vez: por frame se
-- recuerda la base y el valor que aplicamos. Si al volver el frame sigue en nuestro valor, la base
-- es la de antes; si no, alguien lo ha recolocado y su posición actual es la nueva base.
-- Los frames que el jugador ha movido a mano (IsUserPlaced) no se tocan.

local TOP_FRAMES = {
	"PlayerFrame", "TargetFrame", "FocusFrame", "PartyMemberFrame1", "MinimapCluster",
	"BuffFrame", "TemporaryEnchantFrame", "ConsolidatedBuffs", "TicketStatusFrame",
	"WorldStateAlwaysUpFrame",
}
local BOTTOM_FRAMES = { "MainMenuBar", "MultiBarRight", "VehicleMenuBar", "ChatFrame1", "ChatFrame2" }

local tracked = {}

local function adjustFrame(self, name, offset, sign)
	local frame = _G[name]
	if not frame or not frame.GetPoint then return end
	if self.db.profile.general.adjust[name] == false then return end
	if frame.IsUserPlaced and frame:IsUserPlaced() then return end
	local point, relTo, relPoint, x, y = frame:GetPoint(1)
	if not point then return end

	local state = tracked[name]
	local base = y
	if state and state.point == point and state.applied == y then base = state.base end
	local target = base + sign * offset
	tracked[name] = { point = point, base = base, applied = target }
	if target ~= y then
		frame:ClearAllPoints()
		frame:SetPoint(point, relTo or UIParent, relPoint, x, target)
	end
end

local function edgeHeight(self, edge)
	local total = 0
	for _, cfg in pairs(self.db.profile.bars) do
		if cfg.enabled and cfg.edge == edge and cfg.screenAdjust then
			total = total + cfg.height * (cfg.scale or 1)
		end
	end
	return total
end

function WCDPanel:ScreenAdjustAll()
	if not self.db then return end
	self:RunOutOfCombat("screenadjust", function()
		local top, bottom = edgeHeight(WCDPanel, "TOP"), edgeHeight(WCDPanel, "BOTTOM")
		for _, name in ipairs(TOP_FRAMES) do adjustFrame(WCDPanel, name, top, -1) end
		for _, name in ipairs(BOTTOM_FRAMES) do adjustFrame(WCDPanel, name, bottom, 1) end
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_EXITED_VEHICLE")
frame:SetScript("OnEvent", function() WCDPanel:ScreenAdjustAll() end)

if UIParent_ManageFramePositions then
	hooksecurefunc("UIParent_ManageFramePositions", function() WCDPanel:ScreenAdjustAll() end)
end
