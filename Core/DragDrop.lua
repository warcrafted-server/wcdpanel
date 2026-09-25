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

-- Posición en la lista de la zona donde cae el elemento soltado: delante del primero (en el orden
-- de la lista) cuyo centro queda más allá del cursor. En RIGHT la lista va de derecha a izquierda.
-- Los que no tienen posición en pantalla (plugin desactivado, aún sin colocar) no cuentan.
local function dropIndex(barId, zone, draggedId, cursorX)
	WCDPanel:RemoveFromZones(draggedId)
	local list = WCDPanel:ZoneList(barId, zone)
	for i, id in ipairs(list) do
		local runtime = WCDPanel.elements[id]
		local left, right = runtime and runtime.frame:GetLeft(), runtime and runtime.frame:GetRight()
		if left and right then
			local center = (left + right) / 2
			if (zone == "RIGHT" and cursorX > center) or (zone ~= "RIGHT" and cursorX < center) then
				return i
			end
		end
	end
	return #list + 1
end

function WCDPanel:HandleElementDrop(id)
	local barId, cursorX = findBarUnderCursor()
	if not barId then return end -- soltado fuera de toda barra: se queda donde estaba
	local zone = zoneAt(self.bars[barId].frame, cursorX)
	self:PlaceElement(id, barId, zone, dropIndex(barId, zone, id, cursorX))
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
