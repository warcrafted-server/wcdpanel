-- Recoge los botones de minimapa de addons SIN LibDataBroker (con LDB ya los coge el plugin
-- LDB). Es más heurístico que LDB: escanea los hijos del minimapa y anula el SetPoint del
-- botón para que el addon original no se recoloque solo, sin tocar su OnClick/OnEnter/icono.
local P = WCDPanel:NewPlugin("MinimapButtons", {
	title = "Botones del minimapa",
	category = "Núcleo",
	dynamicElements = true,
	events = { "PLAYER_ENTERING_WORLD", "ADDON_LOADED" },
})

-- Botones propios de Blizzard: no son "de otro addon", no los toques.
local IGNORE = {
	MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapWorldMapButton = true,
	MinimapZoomIn = true, MinimapZoomOut = true, MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapVoiceChatFrame = true,
	GameTimeFrame = true, TimeManagerClockButton = true, MiniMapInstanceDifficulty = true,
	MinimapBackdrop = true, MinimapCluster = true, MinimapZoneTextButton = true,
	MinimapBorder = true, MinimapBorderTop = true, MinimapNorthTag = true,
	MinimapToggleButton = true, MinimapCompassTexture = true,
}

local adopted = {}

local function isHandledByLDB(name)
	-- Los botones de LibDBIcon-1.0 suelen llamarse "LibDBIcon10_<nombre del data object>";
	-- si ese data object ya lo gestiona el plugin LDB, no lo dupliques aquí.
	local ldbName = name and name:match("^LibDBIcon10_(.+)$")
	return ldbName and WCDPanel.elements["LDB:" .. ldbName] ~= nil
end

local function adopt(frame)
	if not frame then return end
	local name = frame.GetName and frame:GetName()
	if not name or adopted[name] or IGNORE[name] or isHandledByLDB(name) then return end
	adopted[name] = true

	local realSetPoint, realClearAllPoints = frame.SetPoint, frame.ClearAllPoints
	frame._wcdRealSetPoint = realSetPoint
	frame._wcdRealClearAllPoints = realClearAllPoints
	-- El addon original suele recolocarse solo en su propio OnUpdate/eventos; al anular
	-- esto dejamos de competir con él por la posición del botón.
	frame.SetPoint = function() end
	frame.ClearAllPoints = function() end
	frame:SetScript("OnDragStart", nil)
	frame:SetScript("OnDragStop", nil)

	P:AddElement(name, { foreignFrame = frame, defaultPlacement = { bar = false, zone = "RIGHT", order = 60 } })
end

local function scan()
	if Minimap then
		local children = { Minimap:GetChildren() }
		for _, child in ipairs(children) do adopt(child) end
	end
	if MinimapBackdrop then
		local children = { MinimapBackdrop:GetChildren() }
		for _, child in ipairs(children) do adopt(child) end
	end
end

function P:OnEvent()
	scan()
end

function P:OnEnable()
	scan()
	WCDPanel:StartTicker("minimapscan", 2, function()
		scan()
		WCDPanel:StopTicker("minimapscan")
		WCDPanel:StartTicker("minimapscan2", 8, function()
			scan()
			WCDPanel:StopTicker("minimapscan2")
		end)
	end)
end
