-- Zona y coordenadas: "Loc: Molino Tarren (62, 19)". Clic: mapa del mundo.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Coords", {
	title = "Localización",
	defaults = { profile = { decimals = 0, showZone = true } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 1 },
	events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" },
	interval = 0.2,
})

local PVP_COLORS = {
	sanctuary = "68ccef", friendly = "20ff20", hostile = "ff2020",
	contested = "ffb300", combat = "ff2020", arena = "ff2020",
}

local lastText

-- GetPlayerMapPosition da la posición en el mapa que esté seleccionado: con el mapa del mundo
-- cerrado se fija a la zona actual; abierto no se toca, que el jugador puede estar mirando otra.
local function position()
	if WorldMapFrame and not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
	local x, y = GetPlayerMapPosition("player")
	if not x or (x == 0 and y == 0) then return nil end
	return x * 100, y * 100
end

local function coordsText(decimals)
	local x, y = position()
	if not x then return nil end
	local f = "%." .. decimals .. "f"
	return format(f .. ", " .. f, x, y)
end

local function zoneColor()
	return PVP_COLORS[GetZonePVPInfo() or ""] or "ffd200"
end

function P:OnEvent() self:Refresh() end

function P:OnTick()
	local text = coordsText(self.db.profile.decimals)
	if text ~= lastText then
		lastText = text
		self:Refresh()
	end
end

function P:GetText()
	local zone = self.db.profile.showZone and Util.Color(GetMinimapZoneText() or "", zoneColor()) or ""
	local coords = coordsText(self.db.profile.decimals)
	local value = zone
	if coords then value = value .. (value ~= "" and " " or "") .. Util.White("(" .. coords .. ")") end
	return "Loc:", value
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_Map_01" end

function P:OnTooltip(_, tooltip)
	tooltip:SetText(GetZoneText() or "")
	local sub = GetSubZoneText()
	if sub and sub ~= "" then tooltip:AddLine(sub, 1, 1, 1) end
	local pvpType, _, faction = GetZonePVPInfo()
	if pvpType then tooltip:AddLine(Util.Color(faction or pvpType, zoneColor())) end
	local coords = coordsText(1)
	if coords then tooltip:AddDoubleLine("Coordenadas", coords, 1, 0.82, 0, 1, 1, 1) end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: mapa del mundo.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button == "LeftButton" then ToggleFrame(WorldMapFrame) end
end

function P:GetOptions()
	local db = self.db.profile
	return {
		showZone = {
			type = "toggle", order = 1, name = "Mostrar la zona",
			get = function() return db.showZone end,
			set = function(_, v) db.showZone = v P:Refresh() end,
		},
		decimals = {
			type = "range", order = 2, name = "Decimales", min = 0, max = 2, step = 1,
			get = function() return db.decimals end,
			set = function(_, v) db.decimals = v P:Refresh() end,
		},
	}
end
