-- Coloca los elementos de una barra en sus 3 zonas mediante anclaje encadenado: cada
-- elemento se ancla al anterior, así un cambio de ancho solo desplaza a los siguientes.
--
-- Los botones seguros (profesiones) también van encadenados: anclarlos a una distancia fija de la
-- barra obligaba a que esa cuenta cuadrara siempre con la cadena real, y en el cliente no lo hacía
-- (se montaban encima de los anteriores). A cambio, todo lo que tienen delante en la cadena queda
-- protegido en combate, así que cualquier cambio de tamaño se aplaza (mutate en Element.lua) y el
-- reflow entero va fuera de combate.

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
