-- CRUD de barras. Cada barra es un frame de fondo con 3 zonas lógicas (LEFT/CENTER/RIGHT,
-- ver Layout.lua); TOP/BOTTOM ocupan el ancho completo y se apilan por "stack", FREE tiene
-- su propia posición y ancho guardados.

WCDPanel.bars = WCDPanel.bars or {}

local BG_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"
local BORDER_TEXTURE = "Interface\\Tooltips\\UI-Tooltip-Border"
local BORDER_COLOR = { 0.55, 0.55, 0.6, 0.8 }
local SHINE_COLOR = { 1, 1, 1, 0.08 }
local CONCEALED_ALPHA = 0.1
local CONCEAL_DELAY = 0.6

local function defaultBarConfig(id, opts)
	opts = opts or {}
	local edge = opts.edge or "TOP"
	return {
		name = opts.name or ("Barra " .. id),
		enabled = true,
		edge = edge,
		stack = opts.stack or 1,
		height = opts.height or 22,
		scale = 1,
		alpha = 1,
		bg = { r = 0, g = 0, b = 0, a = 0.6 },
		strata = "DIALOG",
		autoHide = false,
		screenAdjust = edge ~= "FREE",
		hideInCombat = false,
		locked = false,
		x = opts.x or 300,
		y = opts.y or 400,
		width = opts.width or 300,
	}
end

local function nextBarId(self)
	local max = 0
	for id in pairs(self.db.profile.bars) do
		if id > max then max = id end
	end
	return max + 1
end

-- Barra donde caen los elementos nuevos: la de id más bajo que esté activa.
function WCDPanel:DefaultBarId()
	local best
	for id, cfg in pairs(self.db.profile.bars) do
		if cfg.enabled and (not best or id < best) then best = id end
	end
	return best or false
end

function WCDPanel:GetBarStackOffset(id)
	local cfg = self.db.profile.bars[id]
	local offset = 0
	for otherId, other in pairs(self.db.profile.bars) do
		if otherId ~= id and other.enabled and other.edge == cfg.edge
			and (other.stack < cfg.stack or (other.stack == cfg.stack and otherId < id)) then
			offset = offset + other.height
		end
	end
	return offset
end

function WCDPanel:PositionBar(id)
	local cfg, runtime = self.db.profile.bars[id], self.bars[id]
	if not cfg or not runtime then return end
	local frame = runtime.frame
	frame:ClearAllPoints()
	if cfg.edge == "FREE" then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
		frame:SetWidth(cfg.width)
	elseif cfg.edge == "BOTTOM" then
		local offset = self:GetBarStackOffset(id)
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, offset)
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, offset)
	else
		local offset = self:GetBarStackOffset(id)
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -offset)
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, -offset)
	end
	frame:SetHeight(cfg.height)
end

-- Recoloca todas las barras (cambiar el borde, la altura o el apilado de una afecta a las demás).
function WCDPanel:PositionAllBars()
	self:RunOutOfCombat("positionbars", function()
		for id in pairs(WCDPanel.bars) do WCDPanel:PositionBar(id) end
		WCDPanel:ScreenAdjustAll()
	end)
end

-- Opacidad efectiva: la configurada, o casi transparente si está autoocultada sin el ratón
-- encima, o 0 si se oculta en combate. SetAlpha no está restringido en combate.
local function updateAlpha(id)
	local cfg, runtime = WCDPanel.db.profile.bars[id], WCDPanel.bars[id]
	if not cfg or not runtime then return end
	local alpha = cfg.alpha
	if cfg.hideInCombat and InCombatLockdown() then
		alpha = 0
	elseif cfg.autoHide and runtime.concealed then
		alpha = CONCEALED_ALPHA
	end
	runtime.frame:SetAlpha(alpha)
end

-- OnEnter/OnLeave no sirven para autoocultar: el foco del ratón es un único frame, así que al
-- pasar a un icono de la barra ésta recibe OnLeave. Se consulta IsMouseOver cada décima.
local function autoHideOnUpdate(frame, elapsed)
	frame.ahElapsed = (frame.ahElapsed or 0) + elapsed
	if frame.ahElapsed < 0.1 then return end
	frame.ahElapsed = 0
	local runtime = WCDPanel.bars[frame.barId]
	if not runtime then return end
	local over = frame:IsMouseOver() or (DropDownList1 and DropDownList1:IsShown() and runtime.menuOpen)
	if over then
		runtime.lastOver = GetTime()
		if runtime.concealed then
			runtime.concealed = false
			updateAlpha(frame.barId)
		end
	elseif not runtime.concealed and GetTime() - (runtime.lastOver or 0) > CONCEAL_DELAY then
		runtime.concealed = true
		updateAlpha(frame.barId)
	end
end

function WCDPanel:ApplyBarAutoHide(id)
	local cfg, runtime = self.db.profile.bars[id], self.bars[id]
	if not cfg or not runtime then return end
	if cfg.autoHide then
		runtime.concealed = true
		runtime.frame:SetScript("OnUpdate", autoHideOnUpdate)
	else
		runtime.concealed = false
		runtime.frame:SetScript("OnUpdate", nil)
	end
	updateAlpha(id)
end

function WCDPanel:SetBarAutoHide(id, enabled)
	local cfg = self.db.profile.bars[id]
	if not cfg then return end
	cfg.autoHide = enabled and true or false
	self:ApplyBarAutoHide(id)
end

function WCDPanel:ApplyBarAppearance(id)
	local cfg, runtime = self.db.profile.bars[id], self.bars[id]
	if not cfg or not runtime then return end
	local frame = runtime.frame
	frame:SetScale(cfg.scale)
	frame:SetFrameStrata(cfg.strata)
	frame:SetBackdropColor(cfg.bg.r, cfg.bg.g, cfg.bg.b, cfg.bg.a)
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	updateAlpha(id)
end

local function createBarFrame(id)
	local frame = CreateFrame("Frame", "WCDPanelBar" .. id, UIParent)
	frame.barId = id
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetBackdrop({
		bgFile = BG_TEXTURE, edgeFile = BORDER_TEXTURE, tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})

	-- Franja superior más clara: le da algo de volumen sin depender de más texturas.
	frame.shine = frame:CreateTexture(nil, "ARTWORK")
	frame.shine:SetTexture(BG_TEXTURE)
	frame.shine:SetVertexColor(unpack(SHINE_COLOR))
	frame.shine:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	frame.shine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	frame.shine:SetHeight(1)

	frame:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then WCDPanel:ShowBarMenu(id, self) end
	end)
	if WCDPanel.AttachBarDrag then WCDPanel:AttachBarDrag(id, frame) end
	return frame
end

WCDPanel.barCreatedHooks = WCDPanel.barCreatedHooks or {}
function WCDPanel:OnBarCreatedHook(fn)
	table.insert(self.barCreatedHooks, fn)
end

function WCDPanel:ActivateBar(id)
	if self.bars[id] then return self.bars[id] end
	local cfg = self.db.profile.bars[id]
	if not cfg or not cfg.enabled then return end

	local frame = createBarFrame(id)
	self.bars[id] = { id = id, frame = frame }
	self:ApplyBarAppearance(id)
	self:PositionBar(id)
	self:ApplyBarAutoHide(id)
	self:ScreenAdjustAll()
	return self.bars[id]
end

function WCDPanel:DestroyBarFrame(id)
	local runtime = self.bars[id]
	if not runtime then return end
	runtime.frame:SetScript("OnUpdate", nil)
	runtime.frame:Hide()
	self.bars[id] = nil
end

function WCDPanel:CreateBar(opts)
	local id = nextBarId(self)
	local cfg = defaultBarConfig(id, opts)
	if not (opts and opts.stack) and cfg.edge ~= "FREE" then
		-- Nueva barra en un borde: se apila por fuera de las que ya hay en ese borde.
		for _, other in pairs(self.db.profile.bars) do
			if other.edge == cfg.edge and other.stack >= cfg.stack then cfg.stack = other.stack + 1 end
		end
	end
	self.db.profile.bars[id] = cfg
	self:ActivateBar(id)
	for _, fn in ipairs(self.barCreatedHooks) do fn(id) end
	return id
end

-- Una barra con botones seguros anclados queda protegida en combate, así que borrarla (ocultar
-- su frame) se aplaza hasta salir de combate.
function WCDPanel:DeleteBar(id)
	self:RunOutOfCombat("deletebar:" .. id, function()
		for elId, cfg in pairs(WCDPanel.db.profile.elements) do
			if cfg.bar == id then
				if WCDPanel.elements[elId] then WCDPanel:PlaceElement(elId, false) else cfg.bar = false end
			end
		end
		WCDPanel:DestroyBarFrame(id)
		WCDPanel.db.profile.bars[id] = nil
		WCDPanel:PositionAllBars()
	end)
end

function WCDPanel:ActivateBars()
	for id, cfg in pairs(self.db.profile.bars) do
		if cfg.enabled then self:ActivateBar(id) end
	end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
	for id in pairs(WCDPanel.bars) do updateAlpha(id) end
end)
