-- Arrastrar y soltar. El elemento real (que puede ser un botón seguro) nunca se mueve
-- durante el gesto: solo sigue al cursor un "fantasma" sin proteger; al soltar se escribe
-- la nueva colocación en la base de datos y es Layout (ya seguro en combate) quien la aplica.

local ghost = CreateFrame("Frame", "WCDPanelDragGhost", UIParent)
ghost:SetFrameStrata("TOOLTIP")
ghost:SetSize(16, 16)
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
	if barCfg and barCfg.locked then return false end
	return true
end

local function findBarUnderCursor()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	x, y = x / scale, y / scale
	for id, runtime in pairs(WCDPanel.bars) do
		local f = runtime.frame
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

-- Reordena la zona insertando draggedId según la posición horizontal soltada, y renumera
-- el orden de todos sus elementos para que quede una secuencia limpia.
local function reorderZone(barId, zone, draggedId, cursorX)
	local list = {}
	for id, cfg in pairs(WCDPanel.db.profile.elements) do
		if cfg.bar == barId and cfg.zone == zone and id ~= draggedId then
			local runtime = WCDPanel.elements[id]
			if runtime then
				table.insert(list, { id = id, x = runtime.frame:GetLeft() or 0, order = cfg.order })
			end
		end
	end
	table.sort(list, function(a, b) return a.order < b.order end)

	local insertAt = #list + 1
	for i, item in ipairs(list) do
		if cursorX < item.x then
			insertAt = i
			break
		end
	end
	table.insert(list, insertAt, { id = draggedId })

	for i, item in ipairs(list) do
		WCDPanel.db.profile.elements[item.id].order = i
	end
end

function WCDPanel:HandleElementDrop(id)
	local barId, cursorX = findBarUnderCursor()
	if not barId then
		self:PlaceElement(id, false)
		return
	end
	local zone = zoneAt(self.bars[barId].frame, cursorX)
	reorderZone(barId, zone, id, cursorX)
	self:PlaceElement(id, barId, zone)
end

function WCDPanel:AttachElementDrag(id, frame)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not elementDraggable(id) then return end
		draggingId = id
		ghost.icon:SetTexture(self.icon and self.icon:GetTexture())
		ghost:SetSize(WCDPanel.db.profile.general.iconSize, WCDPanel.db.profile.general.iconSize)
		ghost:Show()
		self:SetAlpha(0.3)
	end)
	frame:SetScript("OnDragStop", function(self)
		ghost:Hide()
		self:SetAlpha(1)
		if draggingId == id then
			WCDPanel:HandleElementDrop(id)
			draggingId = nil
		end
	end)
end

-- Las barras nunca son frames protegidos, así que StartMoving/StopMovingOrSizing es seguro
-- incluso con elementos seguros anclados encima: solo se mueve el padre, no el hijo protegido.
function WCDPanel:AttachBarDrag(id, frame)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		local cfg = WCDPanel.db.profile.bars[id]
		if WCDPanel.db.profile.general.locked or cfg.locked or cfg.edge ~= "FREE" then return end
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local cfg = WCDPanel.db.profile.bars[id]
		if cfg.edge ~= "FREE" then return end
		local _, _, _, x, y = self:GetPoint(1)
		cfg.x, cfg.y = x, y
	end)
end
