-- Recoge los botones de minimapa de addons SIN LibDataBroker (como BotCommander) y los mete
-- en la barra. Los que tienen LDB los lleva el plugin LDB, que además oculta su botón de minimapa.
--
-- Cada botón adoptado va dentro del contenedor de su elemento (un frame del tamaño de un icono),
-- escalado para caber; su SetPoint/ClearAllPoints se anula para que el addon original no lo
-- devuelva al minimapa, pero su OnClick/OnEnter/icono no se tocan. Un botón sin barra asignada
-- queda oculto; desactivar el plugin (o desmarcar el botón) lo devuelve tal como estaba.

local P = WCDPanel:NewPlugin("MinimapButtons", {
	title = "Botones del minimapa",
	description = "Recoge en la barra los botones de minimapa de addons que no usan LDB. Un botón " ..
		"sin barra asignada queda oculto; desmárcalo aquí o desactiva el plugin para devolverlo al minimapa.",
	dynamicElements = true,
	events = { "PLAYER_ENTERING_WORLD", "ADDON_LOADED" },
	defaults = { profile = { ignore = {} } },
})

-- Botones propios de Blizzard.
local BLIZZARD = {
	MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapWorldMapButton = true,
	MinimapZoomIn = true, MinimapZoomOut = true, MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, MiniMapVoiceChatFrame = true,
	GameTimeFrame = true, TimeManagerClockButton = true, MiniMapInstanceDifficulty = true,
	MinimapBackdrop = true, MinimapZoneTextButton = true, MinimapPing = true,
	MiniMapCompassRing = true, MinimapNorthTag = true, MinimapBorder = true, MinimapBorderTop = true,
}

-- Pines y marcadores de addons de mapa: no son botones y hay decenas.
local PATTERNS = { "pin", "note", "poi", "questie", "tomtom", "arrow", "cartographer",
	"handynotes", "astrolabe", "route", "blip", "gatherer", "nodes" }

local known = {}   -- nombre -> true: todos los candidatos vistos (para la lista de opciones)
local saved = {}   -- nombre -> estado original del botón adoptado
local count = 0

local function hasScript(frame, name)
	return frame.HasScript and frame:HasScript(name) and frame:GetScript(name) ~= nil
end

local function isCandidate(frame)
	local name = frame:GetName()
	if not name or BLIZZARD[name] or name:find("^LibDBIcon10_") then return false end
	local lname = name:lower()
	for _, pattern in ipairs(PATTERNS) do
		if lname:find(pattern, 1, true) then return false end
	end
	if not frame:IsShown() or (frame.IsProtected and frame:IsProtected()) then return false end
	local kind = frame:GetObjectType()
	if kind ~= "Button" and kind ~= "Frame" then return false end
	if not (hasScript(frame, "OnClick") or hasScript(frame, "OnMouseUp") or hasScript(frame, "OnMouseDown")) then
		return false
	end
	local w, h = frame:GetWidth(), frame:GetHeight()
	if not w or w < 14 or w > 48 or not h or h < 14 or h > 48 then return false end
	local ldbPlugin = WCDPanel.plugins.LDB
	if ldbPlugin and ldbPlugin.enabled and ldbPlugin:IsMinimapDuplicate(frame) then return false end
	return true
end

local function adopt(name, el)
	local runtime = WCDPanel.elements[el]
	local frame = _G[name]
	if not runtime or not frame then return end
	local container = runtime.frame
	local s = saved[name]
	if not s then
		s = {
			parent = frame:GetParent(), scale = frame:GetScale(),
			strata = frame:GetFrameStrata(), level = frame:GetFrameLevel(),
			point = { frame:GetPoint(1) },
			setPoint = frame.SetPoint, clearAllPoints = frame.ClearAllPoints,
			dragStart = hasScript(frame, "OnDragStart") and frame:GetScript("OnDragStart"),
			dragStop = hasScript(frame, "OnDragStop") and frame:GetScript("OnDragStop"),
		}
		saved[name] = s
		frame.SetPoint = function() end
		frame.ClearAllPoints = function() end
		frame:SetScript("OnDragStart", nil)
		frame:SetScript("OnDragStop", nil)
		WCDPanel:AttachElementDrag(el, frame)
	end
	frame:SetParent(container)
	s.clearAllPoints(frame)
	s.setPoint(frame, "CENTER", container, "CENTER", 0, 0)
	frame:SetScale(WCDPanel.db.profile.general.iconSize / math.max(frame:GetHeight(), 1))
	frame:SetFrameStrata(container:GetFrameStrata())
	frame:SetFrameLevel(container:GetFrameLevel() + 1)
	frame:Show()
end

local function release(name)
	local s, frame = saved[name], _G[name]
	if not s or not frame then return end
	saved[name] = nil
	frame.SetPoint = nil
	frame.ClearAllPoints = nil
	frame:SetParent(s.parent)
	frame:SetScale(s.scale)
	frame:SetFrameStrata(s.strata)
	frame:SetFrameLevel(s.level)
	frame:ClearAllPoints()
	if s.point[1] then frame:SetPoint(unpack(s.point)) end
	frame:SetScript("OnDragStart", s.dragStart or nil)
	frame:SetScript("OnDragStop", s.dragStop or nil)
	frame:Show()
end

function P:Collect(name)
	if self.db.profile.ignore[name] then return end
	count = count + 1
	self:AddElement(name, {
		foreign = true,
		title = name,
		defaultPlacement = { bar = true, zone = "RIGHT", order = 40 + count },
		onPlace = function(el) adopt(name, el) end,
		onUnplace = function(el) adopt(name, el) end,
		onRelease = function() release(name) end,
	})
end

function P:Scan()
	if not self.enabled then return end
	WCDPanel.Util.EachNamedChild(Minimap, function(child)
		local name = child:GetName()
		if not saved[name] and not WCDPanel.elements[self:ElementId(name)] and isCandidate(child) then
			known[name] = true
			self:Collect(name)
		end
	end)
end

function P:OnEnable()
	for name in pairs(known) do
		if _G[name] then self:Collect(name) end
	end
	self:Scan()
	-- Muchos addons crean su botón un poco después de entrar en el mundo.
	local tries = 0
	WCDPanel:StartTicker("minimapbuttons", 3, function()
		tries = tries + 1
		P:Scan()
		if tries >= 4 then WCDPanel:StopTicker("minimapbuttons") end
	end)
end

function P:OnDisable()
	WCDPanel:StopTicker("minimapbuttons")
end

function P:OnEvent()
	self:Scan()
end

function P:GetOptions()
	local args = {}
	local names = {}
	for name in pairs(known) do table.insert(names, name) end
	table.sort(names)
	for i, name in ipairs(names) do
		args["collect" .. i] = {
			type = "toggle", order = i, name = "Recoger " .. name, width = "full",
			get = function() return not P.db.profile.ignore[name] end,
			set = function(_, v)
				P.db.profile.ignore[name] = (not v) or nil
				if v then P:Collect(name) else P:RemoveElement(name) end
				WCDPanel.RefreshOptions()
			end,
		}
	end
	return args
end
