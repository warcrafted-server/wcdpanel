-- CRUD de barras. Cada barra es un frame de fondo con 3 zonas lógicas (LEFT/CENTER/RIGHT,
-- ver Layout.lua); TOP/BOTTOM ocupan el ancho completo y se apilan por "stack", FREE tiene
-- su propia posición y ancho guardados.

WCDPanel.bars = WCDPanel.bars or {}

local function defaultBarConfig(opts)
	opts = opts or {}
	return {
		name = opts.name or "Barra",
		enabled = true,
		edge = opts.edge or "TOP",
		stack = opts.stack or 1,
		height = opts.height or 24,
		scale = 1,
		alpha = 1,
		bg = { r = 0, g = 0, b = 0, a = 0.5 },
		strata = "DIALOG",
		autoHide = false,
		screenAdjust = (opts.edge or "TOP") ~= "FREE",
		hideInCombat = false,
		locked = false,
		x = opts.x or 200,
		y = opts.y or 200,
		width = opts.width or 200,
	}
end

local function nextBarId(self)
	local max = 0
	for id in pairs(self.db.profile.bars) do
		if id > max then max = id end
	end
	return max + 1
end

local function createBarFrame(id)
	local frame = CreateFrame("Frame", "WCDPanelBar" .. id, UIParent)
	frame:EnableMouse(true)
	frame.bg = frame:CreateTexture(frame:GetName() .. "Bg", "BACKGROUND")
	frame.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
	frame.bg:SetAllPoints(frame)
	if WCDPanel.AttachBarDrag then WCDPanel:AttachBarDrag(id, frame) end
	return frame
end

function WCDPanel:GetBarStackOffset(id)
	local cfg = self.db.profile.bars[id]
	local offset = 0
	for otherId, otherCfg in pairs(self.db.profile.bars) do
		if otherId ~= id and otherCfg.edge == cfg.edge and otherCfg.enabled and otherCfg.stack < cfg.stack then
			offset = offset + otherCfg.height
		end
	end
	return offset
end

function WCDPanel:PositionBar(id)
	local cfg = self.db.profile.bars[id]
	local runtime = self.bars[id]
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
	else -- TOP
		local offset = self:GetBarStackOffset(id)
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -offset)
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, -offset)
	end
	frame:SetHeight(cfg.height)
end

function WCDPanel:ApplyBarAppearance(id)
	local cfg = self.db.profile.bars[id]
	local runtime = self.bars[id]
	if not cfg or not runtime then return end
	local frame = runtime.frame
	frame:SetScale(cfg.scale)
	frame:SetAlpha(cfg.alpha)
	frame:SetFrameStrata(cfg.strata)
	frame.bg:SetVertexColor(cfg.bg.r, cfg.bg.g, cfg.bg.b, cfg.bg.a)
end

-- Autoocultar: en vez de deslizar la barra fuera de pantalla (que en combate necesitaría
-- SetPoint sobre ella), se desvanece con SetAlpha, que no está restringido en combate.
function WCDPanel:ApplyBarAutoHide(id)
	local cfg = self.db.profile.bars[id]
	local runtime = self.bars[id]
	if not cfg or not runtime then return end
	local frame = runtime.frame

	if cfg.autoHide then
		if not frame._autoHideHooked then
			frame:SetScript("OnEnter", function() WCDPanel:RevealBar(id) end)
			frame:SetScript("OnLeave", function() WCDPanel:ConcealBar(id) end)
			frame._autoHideHooked = true
		end
		self:ConcealBar(id)
	else
		frame:SetAlpha(cfg.alpha)
	end
end

function WCDPanel:RevealBar(id)
	local cfg, runtime = self.db.profile.bars[id], self.bars[id]
	if cfg and runtime then runtime.frame:SetAlpha(cfg.alpha) end
end

function WCDPanel:ConcealBar(id)
	local cfg, runtime = self.db.profile.bars[id], self.bars[id]
	if cfg and runtime and cfg.autoHide then runtime.frame:SetAlpha(0.15) end
end

function WCDPanel:SetBarAutoHide(id, enabled)
	local cfg = self.db.profile.bars[id]
	if not cfg then return end
	cfg.autoHide = enabled
	self:ApplyBarAutoHide(id)
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
	if self.ScreenAdjustAll then self:ScreenAdjustAll() end
	return self.bars[id]
end

function WCDPanel:DestroyBarFrame(id)
	local runtime = self.bars[id]
	if not runtime then return end
	runtime.frame:Hide()
	self.bars[id] = nil
end

function WCDPanel:CreateBar(opts)
	local id = nextBarId(self)
	self.db.profile.bars[id] = defaultBarConfig(opts)
	self:ActivateBar(id)
	for _, fn in ipairs(self.barCreatedHooks) do fn(id) end
	return id
end

function WCDPanel:DeleteBar(id)
	self:DestroyBarFrame(id)
	self.db.profile.bars[id] = nil
	for elId, cfg in pairs(self.db.profile.elements) do
		if cfg.bar == id then
			cfg.bar = false
			local runtime = self.elements[elId]
			if runtime then
				runtime.frame:Hide()
				runtime.frame:SetParent(UIParent)
			end
		end
	end
	if self.ScreenAdjustAll then self:ScreenAdjustAll() end
end

function WCDPanel:ActivateBars()
	for id, cfg in pairs(self.db.profile.bars) do
		if cfg.enabled then self:ActivateBar(id) end
	end
end
