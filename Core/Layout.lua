-- Orden y colocación de los elementos, con el mismo patrón que TitanPanel: cada zona de cada barra
-- guarda una lista ordenada de ids (profile.bars[n].layout.LEFT/CENTER/RIGHT) y el orden es la
-- posición en esa lista. No hay números de orden sueltos que puedan empatar o quedar intercalados
-- al añadir un plugin nuevo o al arrastrar.
--
-- LEFT y CENTER van de izquierda a derecha; RIGHT, de derecha a izquierda (el 1 es el más pegado
-- al borde derecho). Cada elemento se ancla al anterior de su lista y el primero al borde de la
-- barra. Los botones seguros (profesiones) van en la cadena igual que el resto: eso deja protegida
-- en combate la cadena que tienen delante, así que todo cambio de tamaño se aplaza (mutate en
-- Element.lua) y el reflow entero va fuera de combate.
--
-- cfg.bar y cfg.zone del elemento son un reflejo de la lista donde está; solo los cambian
-- InsertInZone/RemoveFromZones. cfg.defaultOrder (el order del defaultPlacement del plugin) solo
-- sirve para decidir dónde entra un elemento nuevo en su lista.

WCDPanel.LAYOUT_REV = 3

local ZONES = { "LEFT", "CENTER", "RIGHT" }

function WCDPanel:ZoneList(barId, zone)
	local barCfg = self.db.profile.bars[barId]
	if not barCfg then return nil end
	barCfg.layout = barCfg.layout or {}
	barCfg.layout[zone] = barCfg.layout[zone] or {}
	return barCfg.layout[zone]
end

-- Barra, zona y posición de un elemento según las listas (no según cfg).
function WCDPanel:FindInZones(id)
	for barId, barCfg in pairs(self.db.profile.bars) do
		for _, zone in ipairs(ZONES) do
			local list = barCfg.layout and barCfg.layout[zone]
			if list then
				for i, other in ipairs(list) do
					if other == id then return barId, zone, i end
				end
			end
		end
	end
end

function WCDPanel:RemoveFromZones(id)
	for _, barCfg in pairs(self.db.profile.bars) do
		for _, zone in ipairs(ZONES) do
			local list = barCfg.layout and barCfg.layout[zone]
			if list then
				for i = #list, 1, -1 do
					if list[i] == id then table.remove(list, i) end
				end
			end
		end
	end
end

-- Mete un elemento en una zona. index nil: donde le toque por su defaultOrder entre los que ya
-- hay (así un plugin nuevo aparece en su sitio lógico y no al final de todo).
function WCDPanel:InsertInZone(id, barId, zone, index)
	self:RemoveFromZones(id)
	local cfg = self.db.profile.elements[id]
	local list = self:ZoneList(barId, zone)
	if not list then return end
	if not index then
		local mine = cfg and cfg.defaultOrder or math.huge
		index = #list + 1
		for i, other in ipairs(list) do
			local otherCfg = self.db.profile.elements[other]
			if (otherCfg and otherCfg.defaultOrder or math.huge) > mine then
				index = i
				break
			end
		end
	end
	index = math.max(1, math.min(index, #list + 1))
	table.insert(list, index, id)
	if cfg then cfg.bar, cfg.zone = barId, zone end
end

-- Perfiles de antes de las listas: se construyen una vez a partir de cfg.order, y cfg.order pasa
-- a ser el defaultOrder. También repara un elemento con barra en cfg que no esté en ninguna lista.
function WCDPanel:EnsureZoneLists()
	local elements = self.db.profile.elements
	local pending = {}
	for id, cfg in pairs(elements) do
		if cfg.order ~= nil then
			cfg.defaultOrder = cfg.defaultOrder or cfg.order
			cfg.order = nil
			if cfg.bar and self.db.profile.bars[cfg.bar] then
				table.insert(pending, { id = id, cfg = cfg })
			end
		end
	end
	table.sort(pending, function(a, b)
		if a.cfg.defaultOrder ~= b.cfg.defaultOrder then return a.cfg.defaultOrder < b.cfg.defaultOrder end
		return a.id < b.id
	end)
	for _, item in ipairs(pending) do
		if not self:FindInZones(item.id) then
			table.insert(self:ZoneList(item.cfg.bar, item.cfg.zone or "LEFT"), item.id)
		end
	end
	for id, cfg in pairs(elements) do
		if cfg.bar and not self.db.profile.bars[cfg.bar] then cfg.bar = false end
		if cfg.bar and not self:FindInZones(id) then self:InsertInZone(id, cfg.bar, cfg.zone or "LEFT") end
	end
end

function WCDPanel:LayoutMarkDirty(barId)
	if not barId then return end
	self:MarkDirty("layout:" .. barId, function()
		WCDPanel:RunOutOfCombat("layout:" .. barId, function() WCDPanel:Reflow(barId) end)
	end)
end

-- Sin texto que leer, dos iconos consecutivos se juntan más (iconGap) que un icono y una
-- etiqueta (spacing), para aprovechar el hueco que libera el minimapa.
local function isIconOnly(runtime)
	return runtime.foreign or not (runtime.frame.text and runtime.frame.text:IsShown())
end

local reported = {}
local function anchor(self, id, frame, ...)
	frame:ClearAllPoints()
	local ok, err = pcall(frame.SetPoint, frame, ...)
	if not ok and not reported[id] then
		reported[id] = true
		self:Print("no se pudo colocar " .. id .. ": " .. tostring(err))
	end
end

-- Elementos vivos de una zona, en su orden. Los de un plugin desactivado siguen en la lista (al
-- reactivarlo vuelven a su sitio) pero no tienen frame.
local function liveItems(self, barId, zone)
	local items = {}
	for _, id in ipairs(self:ZoneList(barId, zone)) do
		local runtime = self.elements[id]
		if runtime then table.insert(items, runtime) end
	end
	return items
end

local function chain(self, items, bar, zone, spacing, iconGap, startX)
	local sideAnchor, prevAnchor, sign = "LEFT", "RIGHT", 1
	if zone == "RIGHT" then sideAnchor, prevAnchor, sign = "RIGHT", "LEFT", -1 end
	local barPoint = zone == "CENTER" and "CENTER" or sideAnchor
	local prev, prevIconOnly
	for _, runtime in ipairs(items) do
		local frame = runtime.frame
		local iconOnly = isIconOnly(runtime)
		local gap = (prevIconOnly and iconOnly) and iconGap or spacing
		if prev then
			anchor(self, runtime.id, frame, sideAnchor, prev, prevAnchor, sign * gap, 0)
		else
			anchor(self, runtime.id, frame, sideAnchor, bar, barPoint, sign * startX, 0)
		end
		frame:Show()
		prev, prevIconOnly = frame, iconOnly
	end
end

function WCDPanel:Reflow(barId)
	local barRuntime = self.bars[barId]
	if not barRuntime then return end
	local general = self.db.profile.general
	local spacing, iconGap = general.spacing, general.iconGap
	local bar = barRuntime.frame
	local edgeGap = math.floor(spacing / 2)

	local zoneItems = {}
	for _, zone in ipairs(ZONES) do
		zoneItems[zone] = liveItems(self, barId, zone)
		for _, runtime in ipairs(zoneItems[zone]) do self:FitElementWidth(runtime.id) end
	end

	chain(self, zoneItems.LEFT, bar, "LEFT", spacing, iconGap, edgeGap)
	chain(self, zoneItems.RIGHT, bar, "RIGHT", spacing, iconGap, edgeGap)

	local total, prevIconOnly = 0, nil
	for i, runtime in ipairs(zoneItems.CENTER) do
		local iconOnly = isIconOnly(runtime)
		if i > 1 then total = total + ((prevIconOnly and iconOnly) and iconGap or spacing) end
		total = total + runtime.frame:GetWidth()
		prevIconOnly = iconOnly
	end
	chain(self, zoneItems.CENTER, bar, "CENTER", spacing, iconGap, -total / 2)
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
-- ancho, ancho del texto y a qué está anclado).
local function frameName(f)
	if not f then return "nil" end
	if f == UIParent then return "UIParent" end
	local name = f.GetName and f:GetName()
	return name and name:gsub("^WCDPanel", "") or tostring(f)
end

function WCDPanel:DebugLayout(all)
	self:Print(format("colocación v%d, combate: %s", self.LAYOUT_REV, tostring(InCombatLockdown())))
	for barId, barRuntime in pairs(self.bars) do
		local bar = barRuntime.frame
		self:Print(format("barra %d: L=%.1f W=%.1f escala=%.2f", barId, bar:GetLeft() or -1, bar:GetWidth() or -1, bar:GetScale()))
		for _, zone in ipairs(ZONES) do
			if all or zone == "LEFT" then
				for i, id in ipairs(self:ZoneList(barId, zone)) do
					local runtime = self.elements[id]
					if not runtime then
						self:Print(format("%s%d %s (plugin desactivado)", zone:sub(1, 1), i, id))
					else
						local f = runtime.frame
						local _, rel, relPoint, x = f:GetPoint(1)
						self:Print(format("%s%d %s L=%.1f W=%.1f txt=%.1f ancla=%s:%s%+.1f%s", zone:sub(1, 1), i, id,
							f:GetLeft() or -1, f:GetWidth() or -1,
							f.text and f.text:IsShown() and f.text:GetStringWidth() or 0,
							frameName(rel), tostring(relPoint), x or 0, f:IsShown() and "" or " (oculto)"))
					end
				end
			end
		end
	end
end
