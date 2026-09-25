-- Arrastrar y soltar. El elemento real (que puede ser un botón seguro) nunca se mueve
-- durante el gesto: solo sigue al cursor un "fantasma" sin proteger; al soltar se escribe
-- la nueva colocación y es Layout (aplazado fuera de combate) quien la aplica.

local ghost = CreateFrame("Frame", "WCDPanelDragGhost", UIParent)
ghost:SetFrameStrata("TOOLTIP")
ghost:SetWidth(20)
ghost:SetHeight(20)
ghost.icon = ghost:CreateTexture(nil, "OVERLAY")
ghost.icon:SetAllPoints(ghost)
ghost:Hide()
ghost:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

local draggingId

local function elementDraggable(id)
	if WCDPanel.db.profile.general.locked then return false end
	local cfg = WCDPanel.db.profile.elements[id]
	local barCfg = cfg and cfg.bar and WCDPanel.db.profile.bars[cfg.bar]
	return not (barCfg and barCfg.locked)
end

-- Devuelve la barra bajo el cursor y la x del cursor en las coordenadas de esa barra.
local function findBarUnderCursor()
	local cx, cy = GetCursorPosition()
	for id, runtime in pairs(WCDPanel.bars) do
		local f = runtime.frame
		local scale = f:GetEffectiveScale()
		local x, y = cx / scale, cy / scale
		local left, right, top, bottom = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
		if left and x >= left and x <= right and y >= bottom and y <= top then
			return id, x
		end
	end
end

local function zoneAt(barFrame, x)
	local left, right = barFrame:GetLeft(), barFrame:GetRight()
	if not left or not right or right <= left then return "LEFT" end
	local third = (right - left) / 3
	if x < left + third then return "LEFT" end
	if x > right - third then return "RIGHT" end
	return "CENTER"
end

-- Inserta draggedId en la zona según la x soltada y renumera el orden de toda la zona.
local function reorderZone(barId, zone, draggedId, cursorX)
	local list = {}
	for id, cfg in pairs(WCDPanel.db.profile.elements) do
		local runtime = WCDPanel.elements[id]
		if runtime and cfg.bar == barId and cfg.zone == zone and id ~= draggedId then
			local left, right = runtime.frame:GetLeft(), runtime.frame:GetRight()
			local center = left and right and (left + right) / 2 or 0
			table.insert(list, { id = id, center = center })
		end
	end
	table.sort(list, function(a, b) return a.center < b.center end)

	local insertAt = #list + 1
	for i, item in ipairs(list) do
		if cursorX < item.center then insertAt = i break end
	end
	table.insert(list, insertAt, { id = draggedId })

	-- En RIGHT el orden 1 es el más pegado al borde derecho: se numera de derecha a izquierda.
	local count = #list
	for i, item in ipairs(list) do
		WCDPanel.db.profile.elements[item.id].order = zone == "RIGHT" and (count - i + 1) or i
	end
end

function WCDPanel:HandleElementDrop(id)
	local barId, cursorX = findBarUnderCursor()
	if not barId then return end -- soltado fuera de toda barra: se queda donde estaba
	local zone = zoneAt(self.bars[barId].frame, cursorX)
	reorderZone(barId, zone, id, cursorX)
	self:PlaceElement(id, barId, zone)
end

function WCDPanel:AttachElementDrag(id, frame)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not elementDraggable(id) then return end
		draggingId = id
		local texture = self.icon and self.icon:IsShown() and self.icon:GetTexture()
		ghost.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
		ghost:Show()
		self:SetAlpha(0.4)
	end)
	frame:SetScript("OnDragStop", function(self)
		ghost:Hide()
		self:SetAlpha(1)
		if draggingId == id then
			draggingId = nil
			WCDPanel:HandleElementDrop(id)
		end
	end)
end

-- Las barras libres se mueven arrastrando su fondo. StartMoving sobre la barra es seguro
-- fuera de combate; en combate no se permite (puede tener botones seguros anclados).
function WCDPanel:AttachBarDrag(id, frame)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		local cfg = WCDPanel.db.profile.bars[id]
		if InCombatLockdown() or WCDPanel.db.profile.general.locked or cfg.locked or cfg.edge ~= "FREE" then return end
		self.moving = true
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		if not self.moving then return end
		self.moving = nil
		self:StopMovingOrSizing()
		local cfg = WCDPanel.db.profile.bars[id]
		cfg.x, cfg.y = self:GetLeft(), self:GetTop()
		WCDPanel:PositionBar(id)
	end)
end
