-- Un elemento es un botón colocable en una barra. Vive en WCDPanel.elements[id] (frame, plugin)
-- y su configuración persistida en WCDPanel.db.profile.elements[id] (bar/zone/order/...).

WCDPanel.elements = WCDPanel.elements or {}

local ICON_LABEL_GAP = 4

local function defaultElementConfig(placement)
	placement = placement or {}
	return {
		bar = placement.bar or false,
		zone = placement.zone or "LEFT",
		order = placement.order or 1,
		showIcon = true,
		showLabel = true,
		showText = true,
		colored = true,
	}
end

function WCDPanel:EnsureElementConfig(id, defaultPlacement)
	local elements = self.db.profile.elements
	if not elements[id] then
		elements[id] = defaultElementConfig(defaultPlacement)
	end
	return elements[id]
end

local function coloredText(text, colored)
	if text == nil or text == "" then return "" end
	if colored then
		return (GREEN_FONT_COLOR_CODE or "") .. text .. (FONT_COLOR_CODE_CLOSE or "")
	end
	return (HIGHLIGHT_FONT_COLOR_CODE or "") .. text .. (FONT_COLOR_CODE_CLOSE or "")
end

local function CreateElementFrame(id, plugin)
	local template = plugin.opts.secure and "SecureActionButtonTemplate" or nil
	local frame = CreateFrame("Button", "WCDPanel" .. id, UIParent, template)
	frame:SetHeight(16)
	frame:EnableMouse(true)
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	frame.icon = frame:CreateTexture(frame:GetName() .. "Icon", "ARTWORK")
	frame.icon:SetSize(16, 16)
	frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)

	frame.text = frame:CreateFontString(frame:GetName() .. "Text", "ARTWORK", "GameFontNormalSmall")
	frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)

	frame:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			WCDPanel:ShowElementMenu(id, self)
			return
		end
		if plugin.OnClick then plugin:OnClick(id, button) end
	end)
	frame:SetScript("OnEnter", function(self)
		if WCDPanel.db.profile.general.hideTooltipsInCombat and InCombatLockdown() then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if plugin.OnTooltip then plugin:OnTooltip(id, GameTooltip) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

	if WCDPanel.AttachElementDrag then WCDPanel:AttachElementDrag(id, frame) end

	return frame
end

function WCDPanel:RegisterElement(id, plugin, subId, info)
	if self.elements[id] then return self.elements[id] end

	local placement = (info and info.defaultPlacement) or plugin.opts.defaultPlacement
	local cfg = self:EnsureElementConfig(id, placement)
	local frame = CreateElementFrame(id, plugin)

	local runtime = { id = id, plugin = plugin, subId = subId, info = info, frame = frame }
	self.elements[id] = runtime
	plugin._elements[id] = true

	self:UpdateElementDisplay(id)
	if cfg.bar then
		self:LayoutMarkDirty(cfg.bar)
	else
		frame:Hide()
	end
	return runtime
end

function WCDPanel:UnregisterElement(id)
	local runtime = self.elements[id]
	if not runtime then return end
	local cfg = self.db.profile.elements[id]
	runtime.frame:Hide()
	runtime.frame:SetParent(nil)
	self.elements[id] = nil
	runtime.plugin._elements[id] = nil
	if cfg then self:LayoutMarkDirty(cfg.bar) end
end

function WCDPanel:RefreshElement(id)
	self:MarkDirty("element:" .. id, function() WCDPanel:UpdateElementDisplay(id) end)
end

-- Mueve un elemento a otra barra/zona/orden. false en barId = ocultarlo.
-- Único punto de entrada para reasignar un elemento: lo usan tanto los comandos de prueba
-- de esta fase como (más adelante) DragDrop y las opciones.
function WCDPanel:PlaceElement(id, barId, zone, order)
	local cfg = self.db.profile.elements[id]
	local runtime = self.elements[id]
	if not cfg or not runtime then return end

	local oldBar = cfg.bar
	cfg.bar = barId or false
	if zone then cfg.zone = zone end
	if order then cfg.order = order end

	if not cfg.bar then
		runtime.frame:Hide()
	end
	if oldBar and oldBar ~= cfg.bar then
		self:LayoutMarkDirty(oldBar)
	end
	if cfg.bar then
		self:LayoutMarkDirty(cfg.bar)
	end
end

-- Recalcula icono/texto/ancho de un elemento. No lo posiciona: eso lo hace Layout.
function WCDPanel:UpdateElementDisplay(id)
	local runtime = self.elements[id]
	if not runtime then return end
	local plugin, frame = runtime.plugin, runtime.frame
	local cfg = self.db.profile.elements[id]
	local general = self.db.profile.general

	local label, value = "", ""
	if plugin.GetText then label, value = plugin:GetText(id) end
	label = label or ""
	value = value or ""

	local showIcon = cfg.showIcon and plugin.GetIcon ~= nil
	local showText = (cfg.showLabel and label ~= "") or (cfg.showText and value ~= "")

	if showIcon then
		local texture, coords = plugin:GetIcon(id)
		frame.icon:SetTexture(texture)
		if coords then frame.icon:SetTexCoord(unpack(coords)) end
		frame.icon:SetSize(general.iconSize, general.iconSize)
		frame.icon:Show()
	else
		frame.icon:Hide()
	end

	if showText then
		local text = ""
		if cfg.showLabel and label ~= "" then text = coloredText(label, false) end
		if cfg.showText and value ~= "" then text = text .. coloredText(value, cfg.colored) end
		frame.text:SetText(text)
		frame.text:ClearAllPoints()
		if showIcon then
			frame.text:SetPoint("LEFT", frame.icon, "RIGHT", ICON_LABEL_GAP, 0)
		else
			frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
		end
		frame.text:Show()
	else
		frame.text:Hide()
	end

	local width = 0
	if showIcon then width = width + general.iconSize end
	if showText then
		if showIcon then width = width + ICON_LABEL_GAP end
		width = width + (frame.text:GetStringWidth() or 0)
	end
	frame:SetWidth(math.max(width, 1))

	if runtime.plugin.opts.tooltipTitle then
		frame.tooltipTitle = runtime.plugin.opts.tooltipTitle
	end
end
