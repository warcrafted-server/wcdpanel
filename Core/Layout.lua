-- Coloca los elementos de una barra en sus 3 zonas mediante anclaje encadenado: cada
-- elemento se ancla al anterior, así un cambio de ancho solo desplaza a los siguientes.
--
-- Los elementos seguros (plugin.opts.secure) son la excepción: se anclan a la propia barra
-- con un offset absoluto en vez de al elemento anterior, para no depender de un frame
-- protegido ni obligar a moverlo cuando cambia un vecino (ver Core/Combat.lua).

function WCDPanel:LayoutMarkDirty(barId)
	if not barId then return end
	self:MarkDirty("layout:" .. barId, function()
		WCDPanel:RunOutOfCombat("layout:" .. barId, function() WCDPanel:Reflow(barId) end)
	end)
end

local function collectZones(elements, barId)
	local zones = { LEFT = {}, CENTER = {}, RIGHT = {} }
	for id, cfg in pairs(elements) do
		if cfg.bar == barId then
			table.insert(zones[cfg.zone or "LEFT"], { id = id, order = cfg.order or 1 })
		end
	end
	for _, list in pairs(zones) do
		table.sort(list, function(a, b) return a.order < b.order end)
	end
	return zones
end

local function layoutEdgeZone(self, list, bar, anchorPoint, growPoint, sign, spacing)
	local cursor = spacing / 2
	local prevFrame
	for _, item in ipairs(list) do
		local runtime = self.elements[item.id]
		local frame = runtime.frame
		frame:ClearAllPoints()
		if runtime.plugin.opts.secure then
			frame:SetPoint(anchorPoint, bar, anchorPoint, sign * cursor, 0)
		elseif prevFrame then
			frame:SetPoint(anchorPoint, prevFrame, growPoint, sign * spacing, 0)
		else
			frame:SetPoint(anchorPoint, bar, anchorPoint, sign * cursor, 0)
		end
		frame:Show()
		cursor = cursor + frame:GetWidth() + spacing
		prevFrame = frame
	end
end

local function layoutCenterZone(self, list, bar, spacing)
	if #list == 0 then return end
	local totalWidth = 0
	for i, item in ipairs(list) do
		totalWidth = totalWidth + self.elements[item.id].frame:GetWidth()
		if i > 1 then totalWidth = totalWidth + spacing end
	end

	local cursor = -totalWidth / 2
	local prevFrame
	for _, item in ipairs(list) do
		local runtime = self.elements[item.id]
		local frame = runtime.frame
		frame:ClearAllPoints()
		if runtime.plugin.opts.secure then
			frame:SetPoint("LEFT", bar, "CENTER", cursor, 0)
		elseif prevFrame then
			frame:SetPoint("LEFT", prevFrame, "RIGHT", spacing, 0)
		else
			frame:SetPoint("LEFT", bar, "CENTER", cursor, 0)
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
	local zones = collectZones(self.db.profile.elements, barId)
	local bar = barRuntime.frame

	layoutEdgeZone(self, zones.LEFT, bar, "LEFT", "RIGHT", 1, spacing)
	layoutEdgeZone(self, zones.RIGHT, bar, "RIGHT", "LEFT", -1, spacing)
	layoutCenterZone(self, zones.CENTER, bar, spacing)
end
