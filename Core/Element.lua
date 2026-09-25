-- Un elemento es un botón colocable en una barra. Vive en WCDPanel.elements[id] (frame, plugin)
-- y su configuración persistida en WCDPanel.db.profile.elements[id] (bar/zone/order/...).
--
-- Tipos de frame:
--   * normal: Button nuestro con icono + texto;
--   * seguro (plugin.opts.secure): igual pero con SecureActionButtonTemplate. Su OnClick es el
--     de Blizzard (lanza el hechizo), así que el nuestro va con HookScript, nunca SetScript; y
--     todo lo que lo mueve/oculta/reemparenta pasa por RunOutOfCombat;
--   * contenedor (info.foreign): Frame vacío del tamaño de un icono donde un plugin mete el
--     botón de otro addon (ver Plugins/MinimapButtons).

WCDPanel.elements = WCDPanel.elements or {}

local ICON_LABEL_GAP = 3

local function defaultElementConfig(placement)
	placement = placement or {}
	local bar = placement.bar
	if bar == true then bar = WCDPanel:DefaultBarId() end
	return {
		bar = bar or false,
		zone = placement.zone or "LEFT",
		order = placement.order or 1,
		showIcon = true,
		showLabel = placement.showLabel ~= false,
		showText = placement.showText ~= false,
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

local function mutate(runtime, key, fn)
	if runtime.secure then
		WCDPanel:RunOutOfCombat("el:" .. runtime.id .. ":" .. key, fn)
	else
		fn()
	end
end

local function onClick(id, frame, button)
	local runtime = WCDPanel.elements[id]
	if not runtime then return end
	local plugin = runtime.plugin
	if button == "RightButton" and (not plugin.opts.ownRightClick or IsControlKeyDown()) then
		WCDPanel:ShowElementMenu(id, frame)
		return
	end
	if plugin.OnClick then plugin:OnClick(id, button) end
end

local function onEnter(id, frame)
	local runtime = WCDPanel.elements[id]
	if not runtime then return end
	if WCDPanel.db.profile.general.hideTooltipsInCombat and InCombatLockdown() then return end
	local plugin = runtime.plugin
	if plugin.OnEnterElement then
		plugin:OnEnterElement(id, frame)
		return
	end
	if not plugin.OnTooltip then return end
	WCDPanel.Util.AnchorTooltip(GameTooltip, frame)
	plugin:OnTooltip(id, GameTooltip)
	GameTooltip:Show()
end

local function onLeave(id, frame)
	local runtime = WCDPanel.elements[id]
	if runtime and runtime.plugin.OnLeaveElement then
		runtime.plugin:OnLeaveElement(id, frame)
		return
	end
	GameTooltip:Hide()
end

local function createButton(id, plugin)
	local secure = plugin.opts.secure
	local frame = CreateFrame("Button", "WCDPanel" .. id, UIParent, secure and "SecureActionButtonTemplate" or nil)
	frame:SetHeight(16)
	frame:EnableMouse(true)
	frame:RegisterForClicks("AnyUp")

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
	frame.highlight = frame:CreateTexture(nil, "HIGHLIGHT")
	frame.highlight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	frame.highlight:SetVertexColor(1, 1, 1, 0.15)
	frame.highlight:SetAllPoints(frame)

	local handler = function(self, button) onClick(id, self, button) end
	if secure then
		frame:HookScript("OnClick", handler)
	else
		frame:SetScript("OnClick", handler)
	end
	frame:SetScript("OnEnter", function(self) onEnter(id, self) end)
	frame:SetScript("OnLeave", function(self) onLeave(id, self) end)
	if plugin.OnMouseWheel then
		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", function(_, delta) plugin:OnMouseWheel(id, delta) end)
	end

	if WCDPanel.AttachElementDrag then WCDPanel:AttachElementDrag(id, frame) end
	return frame
end

local function createContainer(id)
	local frame = CreateFrame("Frame", "WCDPanel" .. id, UIParent)
	local size = WCDPanel.db.profile.general.iconSize
	frame:SetWidth(size)
	frame:SetHeight(size)
	return frame
end

local function attachToBar(frame, barRuntime)
	frame:SetParent(barRuntime.frame)
	frame:SetFrameStrata(barRuntime.frame:GetFrameStrata())
	frame:SetFrameLevel(barRuntime.frame:GetFrameLevel() + 2)
end

-- Aplica la colocación guardada: en una barra activa lo engancha a ella (Layout lo posiciona y
-- lo muestra); si no, lo oculta. Los ganchos info.onPlace/onUnplace avisan al plugin.
local function applyPlacement(self, runtime)
	local cfg = self.db.profile.elements[runtime.id]
	local barRuntime = cfg.bar and self.bars[cfg.bar]
	local info = runtime.info
	mutate(runtime, "place", function()
		if barRuntime then
			attachToBar(runtime.frame, barRuntime)
			if info and info.onPlace then info.onPlace(runtime.id, cfg.bar) end
		else
			runtime.frame:Hide()
			runtime.frame:SetParent(UIParent)
			if info and info.onUnplace then info.onUnplace(runtime.id) end
		end
	end)
	if barRuntime then self:LayoutMarkDirty(cfg.bar) end
end

function WCDPanel:RegisterElement(id, plugin, subId, info)
	if self.elements[id] then return self.elements[id] end
	if plugin.opts.secure and InCombatLockdown() then
		self:RunOutOfCombat("register:" .. id, function() WCDPanel:RegisterElement(id, plugin, subId, info) end)
		return
	end

	local placement = (info and info.defaultPlacement) or plugin.opts.defaultPlacement
	self:EnsureElementConfig(id, placement)
	local frame = (info and info.foreign) and createContainer(id) or createButton(id, plugin)

	local runtime = { id = id, plugin = plugin, subId = subId, info = info, frame = frame,
		secure = plugin.opts.secure, foreign = info and info.foreign }
	self.elements[id] = runtime
	plugin._elements[id] = true

	self:UpdateElementDisplay(id)
	applyPlacement(self, runtime)
	return runtime
end

function WCDPanel:UnregisterElement(id)
	local runtime = self.elements[id]
	if not runtime then return end
	local cfg = self.db.profile.elements[id]
	self.elements[id] = nil
	runtime.plugin._elements[id] = nil
	mutate(runtime, "unregister", function()
		runtime.frame:Hide()
		runtime.frame:SetParent(UIParent)
	end)
	if runtime.info and runtime.info.onRelease then runtime.info.onRelease(id) end
	if cfg and cfg.bar then self:LayoutMarkDirty(cfg.bar) end
end

function WCDPanel:RefreshElement(id)
	self:MarkDirty("element:" .. id, function()
		WCDPanel:UpdateElementDisplay(id)
		local cfg = WCDPanel.db.profile.elements[id]
		if cfg and cfg.bar then WCDPanel:LayoutMarkDirty(cfg.bar) end
	end)
end

-- Mueve un elemento a otra barra/zona/orden. false en barId = quitarlo de las barras.
-- Único punto de entrada para reasignar: lo usan las opciones, el menú y arrastrar y soltar.
function WCDPanel:PlaceElement(id, barId, zone, order)
	local cfg = self.db.profile.elements[id]
	local runtime = self.elements[id]
	if not cfg or not runtime then return end

	local oldBar = cfg.bar
	cfg.bar = barId or false
	if zone then cfg.zone = zone end
	if order then cfg.order = order end

	applyPlacement(self, runtime)
	if oldBar and oldBar ~= cfg.bar then self:LayoutMarkDirty(oldBar) end
end

-- Recalcula icono/texto/ancho de un elemento. No lo posiciona: eso lo hace Layout.
function WCDPanel:UpdateElementDisplay(id)
	local runtime = self.elements[id]
	if not runtime then return end
	local general = self.db.profile.general
	local frame = runtime.frame

	if runtime.foreign then
		frame:SetWidth(general.iconSize)
		frame:SetHeight(general.iconSize)
		return
	end

	local plugin = runtime.plugin
	local cfg = self.db.profile.elements[id]
	local label, value = "", ""
	if plugin.GetText then label, value = plugin:GetText(id) end
	label, value = label or "", value or ""

	local texture, coords, r, g, b
	if plugin.GetIcon then texture, coords, r, g, b = plugin:GetIcon(id) end
	local showIcon = cfg.showIcon and texture ~= nil
	local showLabel = cfg.showLabel and label ~= ""
	local showValue = cfg.showText and value ~= ""

	if showIcon then
		frame.icon:SetTexture(texture)
		if coords then frame.icon:SetTexCoord(unpack(coords)) else frame.icon:SetTexCoord(0, 1, 0, 1) end
		frame.icon:SetVertexColor(r or 1, g or 1, b or 1)
		frame.icon:SetWidth(general.iconSize)
		frame.icon:SetHeight(general.iconSize)
		frame.icon:Show()
	else
		frame.icon:Hide()
	end

	local text = ""
	if showLabel then text = WCDPanel.Util.Gold(label) end
	if showValue then
		if text ~= "" then text = text .. " " end
		text = text .. (cfg.colored and value or WCDPanel.Util.White(value))
	end
	frame.text:SetText(text)
	frame.text:ClearAllPoints()
	if showIcon then
		frame.text:SetPoint("LEFT", frame.icon, "RIGHT", ICON_LABEL_GAP, 0)
	else
		frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
	end
	if text ~= "" then frame.text:Show() else frame.text:Hide() end
	self:FitElementWidth(id)
end

-- Ajusta el ancho del elemento al icono + texto que ya tiene puestos. El cliente no maqueta un
-- FontString hasta que su frame tiene posición (antes GetStringWidth da 0), así que Layout lo
-- vuelve a llamar tras colocar cada elemento. Devuelve true si el ancho cambió.
function WCDPanel:FitElementWidth(id)
	local runtime = self.elements[id]
	if not runtime or runtime.foreign then return false end
	local general = self.db.profile.general
	local frame = runtime.frame
	local showIcon = frame.icon:IsShown()
	local hasText = frame.text:IsShown()
	local width = 0
	if showIcon then width = general.iconSize end
	if hasText then
		if showIcon then width = width + ICON_LABEL_GAP end
		width = width + (frame.text:GetStringWidth() or 0)
	end
	width = math.max(math.floor(width + 0.5), general.iconSize)
	if math.abs(frame:GetWidth() - width) < 0.5 then return false end
	mutate(runtime, "width", function()
		frame:SetWidth(width)
		frame:SetHeight(math.max(general.iconSize, 16))
	end)
	return true
end
