-- Utilidades compartidas por el núcleo y los plugins.

local Util = {}
WCDPanel.Util = Util

function Util.Color(text, hex)
	return "|cff" .. hex .. tostring(text) .. "|r"
end

function Util.Gray(text) return Util.Color(text, "9d9d9d") end
function Util.White(text) return Util.Color(text, "ffffff") end
function Util.Gold(text) return Util.Color(text, "ffd200") end
function Util.Green(text) return Util.Color(text, "20ff20") end
function Util.Red(text) return Util.Color(text, "ff2020") end

-- Color de verde a rojo según el porcentaje (1 = bien, 0 = mal).
function Util.RatioColor(ratio)
	ratio = math.max(0, math.min(1, ratio or 0))
	if ratio >= 0.75 then return "20ff20" end
	if ratio >= 0.5 then return "ffff00" end
	if ratio >= 0.25 then return "ff9900" end
	return "ff2020"
end

-- Dinero con los iconos de moneda del propio cliente (GOLD_AMOUNT_TEXTURE, etc.).
function Util.Money(copper, hideZeroParts)
	copper = math.floor(copper or 0)
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local cop = copper % 100
	local parts = {}
	if gold > 0 then table.insert(parts, format(GOLD_AMOUNT_TEXTURE, gold, 0, 0)) end
	if silver > 0 or (gold > 0 and not hideZeroParts) then
		table.insert(parts, format(SILVER_AMOUNT_TEXTURE, silver, 0, 0))
	end
	if cop > 0 or #parts == 0 or not hideZeroParts then
		table.insert(parts, format(COPPER_AMOUNT_TEXTURE, cop, 0, 0))
	end
	return table.concat(parts, " ")
end

function Util.CharKey()
	return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

-- Ancla un frame junto a otro hacia dentro de la pantalla: debajo si el dueño está en la mitad
-- superior (una barra arriba), encima si está abajo; y alineado al lado que quepa.
function Util.AnchorTo(frame, owner)
	frame:ClearAllPoints()
	local x, y = owner:GetCenter()
	local ratio = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
	x, y = (x or 0) * ratio, (y or 0) * ratio
	local vertical = y > UIParent:GetHeight() / 2 and "TOP" or "BOTTOM"
	local horizontal = x > UIParent:GetWidth() / 2 and "RIGHT" or "LEFT"
	local opposite = vertical == "TOP" and "BOTTOM" or "TOP"
	frame:SetPoint(vertical .. horizontal, owner, opposite .. horizontal, 0, vertical == "TOP" and -4 or 4)
end

function Util.AnchorTooltip(tooltip, owner)
	tooltip:SetOwner(owner, "ANCHOR_NONE")
	Util.AnchorTo(tooltip, owner)
end

-- Llama a fn(frame) sobre los hijos con nombre de un frame (GetChildren devuelve varios valores).
function Util.EachNamedChild(parent, fn)
	if not parent then return end
	local children = { parent:GetChildren() }
	for _, child in ipairs(children) do
		if child and child.GetName and child:GetName() then fn(child) end
	end
end

-- Oculta un frame ajeno de forma que su propio addon no lo vuelva a mostrar (le anula Show) y
-- lo devuelve después tal como estaba. Sirve para botones de minimapa, GameTimeFrame, etc.
local hiddenFrames = {}

function Util.HideFrame(frame)
	if not frame or hiddenFrames[frame] ~= nil then return end
	hiddenFrames[frame] = frame:IsShown() and true or false
	frame:Hide()
	frame.Show = function() end
end

function Util.RestoreFrame(frame)
	local wasShown = frame and hiddenFrames[frame]
	if wasShown == nil then return end
	hiddenFrames[frame] = nil
	frame.Show = nil
	if wasShown then frame:Show() end
end

function Util.SetFrameHidden(frame, hide)
	if hide then Util.HideFrame(frame) else Util.RestoreFrame(frame) end
end
