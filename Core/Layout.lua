-- Coloca los elementos de una barra en sus 3 zonas mediante anclaje encadenado: cada
-- elemento se ancla al anterior, así un cambio de ancho solo desplaza a los siguientes.
--
-- Los botones seguros (profesiones) también van encadenados: anclarlos a una distancia fija de la
-- barra obligaba a que esa cuenta cuadrara siempre con la cadena real, y en el cliente no lo hacía
-- (se montaban encima de los anteriores). A cambio, todo lo que tienen delante en la cadena queda
-- protegido en combate, así que cualquier cambio de tamaño se aplaza (mutate en Element.lua) y el
-- reflow entero va fuera de combate.

WCDPanel.LAYOUT_REV = 2 -- 2: todo encadenado (también los botones seguros)

function WCDPanel:LayoutMarkDirty(barId)
	if not barId then return end
	self:MarkDirty("layout:" .. barId, function()
		WCDPanel:RunOutOfCombat("layout:" .. barId, function() WCDPanel:Reflow(barId) end)
	end)
end

-- Solo elementos vivos: un plugin desactivado conserva su configuración (bar = X) pero ya no
-- tiene frame.
local function collectZones(self, barId)
	local zones = { LEFT = {}, CENTER = {}, RIGHT = {} }
	for id, cfg in pairs(self.db.profile.elements) do
		if cfg.bar == barId and self.elements[id] then
			local list = zones[cfg.zone] or zones.LEFT
			table.insert(list, { id = id, order = cfg.order or 1 })
		end
	end
	for _, list in pairs(zones) do
		table.sort(list, function(a, b)
			if a.order ~= b.order then return a.order < b.order end
			return a.id < b.id
		end)
	end
	return zones
end

-- Sin texto que leer, dos iconos consecutivos se juntan más (iconGap) que un icono y una
-- etiqueta (spacing), para aprovechar el hueco que libera el minimapa.
local function isIconOnly(runtime)
	return runtime.foreign or not (runtime.frame.text and runtime.frame.text:IsShown())
end

local function place(self, list, bar, anchorPoint, growPoint, sign, spacing, iconGap, startOffset, relPointForBar)
	local cursor = startOffset
	local prevFrame, prevIconOnly
	for _, item in ipairs(list) do
		local runtime = self.elements[item.id]
		local frame = runtime.frame
		local iconOnly = isIconOnly(runtime)
		local gap = (prevIconOnly and iconOnly) and iconGap or spacing
		frame:ClearAllPoints()
		if prevFrame then
			frame:SetPoint(anchorPoint, prevFrame, growPoint, sign * gap, 0)
		else
			frame:SetPoint(anchorPoint, bar, relPointForBar, sign * cursor, 0)
		end
		frame:Show()
		self:FitElementWidth(item.id)
		cursor = cursor + frame:GetWidth() + gap
		prevFrame, prevIconOnly = frame, iconOnly
	end
end

function WCDPanel:Reflow(barId)
	local barRuntime = self.bars[barId]
	if not barRuntime then return end

	local general = self.db.profile.general
	local spacing, iconGap = general.spacing, general.iconGap
	local zones = collectZones(self, barId)
	local bar = barRuntime.frame
	local edgeGap = math.floor(spacing / 2)

	place(self, zones.LEFT, bar, "LEFT", "RIGHT", 1, spacing, iconGap, edgeGap, "LEFT")
	place(self, zones.RIGHT, bar, "RIGHT", "LEFT", -1, spacing, iconGap, edgeGap, "RIGHT")

	local total = 0
	for i, item in ipairs(zones.CENTER) do
		total = total + self.elements[item.id].frame:GetWidth()
		if i > 1 then total = total + spacing end
	end
	place(self, zones.CENTER, bar, "LEFT", "RIGHT", 1, spacing, iconGap, -total / 2, "CENTER")
end

function WCDPanel:ReflowAll()
	for id in pairs(self.bars) do self:LayoutMarkDirty(id) end
end

-- Red de seguridad: si un texto cambia de ancho sin pasar por RefreshElement (otro addon cambia
-- la fuente, el cliente termina de cargarla...), el elemento se queda corto y su texto pisa al
-- siguiente. Cada 2 s se vuelve a medir todo y se recoloca la barra que haya cambiado.
function WCDPanel:CheckElementWidths()
	if not self.db then return end
	local changed = {}
	for id in pairs(self.elements) do
		local cfg = self.db.profile.elements[id]
		if cfg and cfg.bar and self:FitElementWidth(id) then changed[cfg.bar] = true end
	end
	for barId in pairs(changed) do self:LayoutMarkDirty(barId) end
end

WCDPanel:StartTicker("layout:widths", 2, function() WCDPanel:CheckElementWidths() end)

-- /wcd debug: cómo está colocada de verdad cada barra en el cliente (posición real con GetLeft,
-- ancho, ancho del texto y a qué está anclado), más los elementos hijos de la barra que ningún
-- reflow coloca (restos con un ancla vieja).
local function frameName(f)
	if not f then return "nil" end
	if f == UIParent then return "UIParent" end
	local name = f.GetName and f:GetName()
	return name and name:gsub("^WCDPanel", "") or tostring(f)
end

function WCDPanel:DebugLayout(all)
	self:Print(format("diseño rev %d, combate: %s", self.LAYOUT_REV or 0, tostring(InCombatLockdown())))
	for barId, barRuntime in pairs(self.bars) do
		local bar = barRuntime.frame
		self:Print(format("barra %d: L=%.1f W=%.1f escala=%.2f", barId, bar:GetLeft() or -1, bar:GetWidth() or -1, bar:GetScale()))
		local listed = {}
		local zones = collectZones(self, barId)
		for _, zone in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
			for _, item in ipairs(zones[zone]) do
				listed[item.id] = true
				if all or zone == "LEFT" then
				local f = self.elements[item.id].frame
				local point, rel, relPoint, x = f:GetPoint(1)
				self:Print(format("%s %s %s L=%.1f W=%.1f txt=%.1f ancla=%s:%s%+.1f %s", zone:sub(1, 1),
					tostring(item.order), item.id, f:GetLeft() or -1, f:GetWidth() or -1,
					f.text and f.text:IsShown() and f.text:GetStringWidth() or 0,
					frameName(rel), tostring(relPoint), x or 0, f:IsShown() and "" or "(oculto)"))
				end
			end
		end
		for id, runtime in pairs(self.elements) do
			if not listed[id] and runtime.frame:GetParent() == bar and runtime.frame:IsShown() then
				local _, rel, _, x = runtime.frame:GetPoint(1)
				self:Print(format("|cffff4040SIN COLOCAR|r %s L=%.1f ancla=%s%+.1f bar=%s zona=%s", id,
					runtime.frame:GetLeft() or -1, frameName(rel), x or 0,
					tostring(self.db.profile.elements[id] and self.db.profile.elements[id].bar),
					tostring(self.db.profile.elements[id] and self.db.profile.elements[id].zone)))
			end
		end
	end
end
