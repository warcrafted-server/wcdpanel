-- Coloca los elementos de una barra en sus 3 zonas mediante anclaje encadenado: cada
-- elemento se ancla al anterior, así un cambio de ancho solo desplaza a los siguientes.
--
-- Los elementos seguros (plugin.opts.secure) son la excepción: se anclan a la propia barra
-- con un offset absoluto en vez de al elemento anterior, para no depender de un frame
-- protegido ni obligar a moverlo cuando cambia un vecino (ver Core/Combat.lua).
-- Todo el reflow se aplaza fuera de combate: una barra con botones seguros queda protegida.

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

local function place(self, list, bar, anchorPoint, growPoint, sign, spacing, startOffset, relPointForBar)
	local cursor = startOffset
	local prevFrame
	for _, item in ipairs(list) do
		local runtime = self.elements[item.id]
		local frame = runtime.frame
		frame:ClearAllPoints()
		if prevFrame and not runtime.secure then
			frame:SetPoint(anchorPoint, prevFrame, growPoint, sign * spacing, 0)
		else
			frame:SetPoint(anchorPoint, bar, relPointForBar, sign * cursor, 0)
		end
		frame:Show()
		cursor = cursor + frame:GetWidth() + spacing
		prevFrame = frame
	end
end

function WCDPanel:Reflow(barId)
	local barRuntime = self.bars[barId]
	if not barRuntime then return end

	local spacing = self.db.profile.general.spacing
	local zones = collectZones(self, barId)
	local bar = barRuntime.frame
	local edgeGap = math.floor(spacing / 2)

	place(self, zones.LEFT, bar, "LEFT", "RIGHT", 1, spacing, edgeGap, "LEFT")
	place(self, zones.RIGHT, bar, "RIGHT", "LEFT", -1, spacing, edgeGap, "RIGHT")

	local total = 0
	for i, item in ipairs(zones.CENTER) do
		total = total + self.elements[item.id].frame:GetWidth()
		if i > 1 then total = total + spacing end
	end
	place(self, zones.CENTER, bar, "LEFT", "RIGHT", 1, spacing, -total / 2, "CENTER")
end

function WCDPanel:ReflowAll()
	for id in pairs(self.bars) do self:LayoutMarkDirty(id) end
end
