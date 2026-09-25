-- Puente con LibDataBroker: un elemento por cada data object (Questie, GatherMate, RecipeRadar,
-- _NPCScanGold, BugSack...), también los que se crean después de iniciar sesión.
-- Mientras un objeto está en una barra, su botón de minimapa (LibDBIcon10_<nombre>, o uno
-- propio cuyo nombre empiece igual, como RecipeRadarMinimapButtonFrame) se oculta: el objetivo
-- es dejar libre el minimapa.
local ldb = LibStub("LibDataBroker-1.1", true)

local P = WCDPanel:NewPlugin("LDB", {
	title = "Addons (LDB)",
	description = "Iconos de los addons que publican un objeto LibDataBroker. Clic y clic derecho van " ..
		"al propio addon; Ctrl+clic derecho abre el menú de wcdpanel.",
	dynamicElements = true,
	ownRightClick = true,
	events = { "PLAYER_ENTERING_WORLD" },
})

local ATTRS = { "label", "text", "value", "suffix", "icon", "iconCoords", "iconR", "iconG", "iconB" }
local objects = {}
local order = 0

local function obj(el) return objects[WCDPanel.elements[el].subId] end

local hideButton, restoreButton = WCDPanel.Util.HideFrame, WCDPanel.Util.RestoreFrame

local function minimapButtonsFor(name)
	local found = {}
	local dbicon = _G["LibDBIcon10_" .. name]
	if dbicon then table.insert(found, dbicon) end
	local prefix = name:lower()
	if #prefix >= 4 then
		WCDPanel.Util.EachNamedChild(Minimap, function(child)
			if child ~= dbicon and child:GetName():lower():sub(1, #prefix) == prefix then
				table.insert(found, child)
			end
		end)
	end
	return found
end

local function applyMinimap(name)
	local el = WCDPanel.elements["LDB:" .. name]
	local cfg = WCDPanel.db.profile.elements["LDB:" .. name]
	local onBar = el and cfg and cfg.bar and WCDPanel.bars[cfg.bar]
	for _, frame in ipairs(minimapButtonsFor(name)) do
		if onBar then hideButton(frame) else restoreButton(frame) end
	end
end

function P:IsMinimapDuplicate(frame)
	for name in pairs(objects) do
		for _, f in ipairs(minimapButtonsFor(name)) do
			if f == frame then return true end
		end
	end
	return false
end

function P:Track(name, dataobj)
	if not objects[name] then
		objects[name] = dataobj
		for _, attr in ipairs(ATTRS) do
			ldb.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. name .. "_" .. attr, "OnAttributeChanged")
		end
	end
	if not self.enabled then return end
	order = order + 1
	self:AddElement(name, {
		title = dataobj.label or name,
		defaultPlacement = { bar = true, zone = "RIGHT", order = 10 + order },
		onPlace = function() applyMinimap(name) end,
		onUnplace = function() applyMinimap(name) end,
		onRelease = function() for _, f in ipairs(minimapButtonsFor(name)) do restoreButton(f) end end,
	})
	applyMinimap(name)
end

function P:OnAttributeChanged(_, name)
	local id = "LDB:" .. name
	if WCDPanel.elements[id] then WCDPanel:RefreshElement(id) end
end

function P:OnObjectCreated(_, name, dataobj)
	self:Track(name, dataobj)
end

function P:OnEnable()
	if not ldb then return end
	ldb.RegisterCallback(self, "LibDataBroker_DataObjectCreated", "OnObjectCreated")
	for name, dataobj in ldb:DataObjectIterator() do self:Track(name, dataobj) end
end

-- Muchos addons crean su botón de LibDBIcon después de su objeto LDB: se reaplica al entrar.
function P:OnEvent()
	for name in pairs(objects) do applyMinimap(name) end
end

function P:GetText(el)
	local o = obj(el)
	if o.type == "launcher" and WCDPanel.db.profile.general.ldbLaunchersIconOnly then return "", "" end
	local value = o.text
	if o.value ~= nil then value = tostring(o.value) .. (o.suffix and (" " .. o.suffix) or "") end
	local label = o.label
	if label == value then label = nil end
	return label or "", value or ""
end

function P:GetIcon(el)
	local o = obj(el)
	return o.icon, o.iconCoords, o.iconR, o.iconG, o.iconB
end

function P:OnClick(el, button)
	local o = obj(el)
	if o.OnClick then o.OnClick(WCDPanel.elements[el].frame, button) end
end

function P:OnEnterElement(el, frame)
	local o = obj(el)
	if WCDPanel.db.profile.general.hideTooltipsInCombat and InCombatLockdown() then return end
	if o.tooltip then
		local tip = o.tooltip
		tip:ClearAllPoints()
		if tip.SetOwner then
			WCDPanel.Util.AnchorTooltip(tip, frame)
		else
			tip:SetPoint("TOP", frame, "BOTTOM", 0, -4)
		end
		tip:Show()
	elseif o.OnTooltipShow then
		WCDPanel.Util.AnchorTooltip(GameTooltip, frame)
		o.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	elseif o.OnEnter then
		o.OnEnter(frame)
	else
		WCDPanel.Util.AnchorTooltip(GameTooltip, frame)
		GameTooltip:SetText(o.label or WCDPanel.elements[el].subId)
		GameTooltip:Show()
	end
end

function P:OnLeaveElement(el, frame)
	local o = obj(el)
	if o.tooltip then
		o.tooltip:Hide()
	elseif o.OnLeave then
		o.OnLeave(frame)
	else
		GameTooltip:Hide()
	end
end

function P:OnDisable()
	for name in pairs(objects) do
		for _, f in ipairs(minimapButtonsFor(name)) do restoreButton(f) end
	end
end

function P:GetOptions()
	return {
		iconOnly = {
			type = "toggle", name = "Lanzadores solo con icono", width = "full",
			desc = "Los objetos de tipo lanzador muestran solo su icono, sin texto.",
			get = function() return WCDPanel.db.profile.general.ldbLaunchersIconOnly end,
			set = function(_, v) WCDPanel.db.profile.general.ldbLaunchersIconOnly = v P:Refresh() end,
		},
	}
end
