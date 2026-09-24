-- Puente con LibDataBroker: un elemento por cada data object (Questie, GatherMate,
-- RecipeRadar, _NPCScanGold, BugSack...), aunque se cree después de iniciar sesión.
local ldb = LibStub("LibDataBroker-1.1", true)

local P = WCDPanel:NewPlugin("LDB", {
	title = "Objetos LDB",
	category = "Núcleo",
	dynamicElements = true,
})

local WATCHED_ATTRS = { "label", "text", "value", "suffix", "icon" }
local seen = {}

local function isLauncher(obj)
	return obj.type == "launcher"
end

local function firstBarId()
	local min
	for id in pairs(WCDPanel.db.profile.bars) do
		if not min or id < min then min = id end
	end
	return min or false
end

local function objectText(obj)
	local label = obj.label or ""
	local value = obj.text or ""
	if obj.suffix then
		value = (obj.value or "") .. " " .. obj.suffix
	end
	return label, value
end

function P:TrackObject(name, obj)
	if seen[name] then return end
	seen[name] = obj
	self:AddElement(name, { obj = obj, defaultPlacement = { bar = firstBarId(), zone = "RIGHT", order = 50 } })
	for _, attr in ipairs(WATCHED_ATTRS) do
		ldb.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. name .. "_" .. attr, "OnLDBAttributeChanged")
	end
end

function P:OnLDBAttributeChanged(event, name)
	WCDPanel:RefreshElement("LDB:" .. name)
end

function P:OnLDBObjectCreated(event, name, obj)
	self:TrackObject(name, obj)
end

function P:OnEnable()
	if not ldb then return end
	for name, obj in ldb:DataObjectIterator() do
		self:TrackObject(name, obj)
	end
	ldb.RegisterCallback(self, "LibDataBroker_DataObjectCreated", "OnLDBObjectCreated")
end

function P:GetText(el)
	local obj = WCDPanel.elements[el].info.obj
	if isLauncher(obj) and WCDPanel.db.profile.general.ldbLaunchersRight then return "", "" end
	return objectText(obj)
end

function P:GetIcon(el)
	local obj = WCDPanel.elements[el].info.obj
	return obj.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function P:OnClick(el, button)
	local obj = WCDPanel.elements[el].info.obj
	if obj.OnClick then
		obj.OnClick(WCDPanel.elements[el].frame, button)
	end
end

function P:OnTooltip(el, tooltip)
	local obj = WCDPanel.elements[el].info.obj
	if obj.OnTooltipShow then
		obj.OnTooltipShow(tooltip)
	elseif obj.OnEnter then
		obj.OnEnter(WCDPanel.elements[el].frame)
	else
		tooltip:SetText(obj.label or el)
	end
end
