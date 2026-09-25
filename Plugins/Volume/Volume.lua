-- Volumen: icono de altavoz. Clic: panel con los volúmenes; rueda del ratón: volumen general;
-- clic derecho: silenciar todo.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Volume", {
	title = "Volumen",
	defaultPlacement = { bar = true, zone = "RIGHT", order = 2, showText = false },
	events = { "CVAR_UPDATE" },
})

local CHANNELS = {
	{ cvar = "Sound_MasterVolume", name = "General" },
	{ cvar = "Sound_SFXVolume", name = "Efectos" },
	{ cvar = "Sound_MusicVolume", name = "Música" },
	{ cvar = "Sound_AmbienceVolume", name = "Ambiente" },
}

local function volume(cvar) return tonumber(GetCVar(cvar)) or 0 end
local function soundOn() return GetCVar("Sound_EnableAllSound") ~= "0" end

local panel

local function buildPanel()
	panel = CreateFrame("Frame", "WCDPanelVolumePanel", UIParent)
	panel:SetFrameStrata("TOOLTIP")
	panel:SetWidth(190)
	panel:SetHeight(28 + #CHANNELS * 40)
	panel:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:SetBackdropColor(0, 0, 0, 0.9)
	panel:EnableMouse(true)
	panel:Hide()
	table.insert(UISpecialFrames, "WCDPanelVolumePanel")

	panel.sliders = {}
	for i, channel in ipairs(CHANNELS) do
		local slider = CreateFrame("Slider", "WCDPanelVolumeSlider" .. i, panel, "OptionsSliderTemplate")
		slider:SetWidth(160)
		slider:SetPoint("TOP", panel, "TOP", 0, -24 - (i - 1) * 40)
		slider:SetMinMaxValues(0, 1)
		slider:SetValueStep(0.05)
		_G[slider:GetName() .. "Low"]:SetText("")
		_G[slider:GetName() .. "High"]:SetText("")
		slider:SetScript("OnValueChanged", function(self, value)
			SetCVar(channel.cvar, value)
			_G[self:GetName() .. "Text"]:SetText(format("%s: %d%%", channel.name, value * 100 + 0.5))
		end)
		panel.sliders[i] = slider
	end
end

local function togglePanel(anchor)
	if not panel then buildPanel() end
	if panel:IsShown() then panel:Hide() return end
	for i, channel in ipairs(CHANNELS) do panel.sliders[i]:SetValue(volume(channel.cvar)) end
	Util.AnchorTo(panel, anchor)
	panel:Show()
end

function P:OnEvent() self:Refresh() end

function P:GetText()
	return "", Util.White(format("%d%%", volume("Sound_MasterVolume") * 100 + 0.5))
end

function P:GetIcon()
	if not soundOn() then return "Interface\\Common\\VoiceChat-Speaker", nil, 0.5, 0.2, 0.2 end
	return "Interface\\Common\\VoiceChat-Speaker"
end

function P:OnTooltip(_, tooltip)
	tooltip:SetText("Volumen" .. (soundOn() and "" or Util.Red(" (silenciado)")))
	for _, channel in ipairs(CHANNELS) do
		tooltip:AddDoubleLine(channel.name, format("%d%%", volume(channel.cvar) * 100 + 0.5), 1, 0.82, 0, 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: ajustar. Rueda: volumen general.", 0.6, 0.6, 0.6)
end

function P:OnClick(el, button)
	if button == "LeftButton" then
		GameTooltip:Hide()
		togglePanel(WCDPanel.elements[el].frame)
	end
end

function P:OnMouseWheel(_, delta)
	local value = math.max(0, math.min(1, volume("Sound_MasterVolume") + delta * 0.05))
	SetCVar("Sound_MasterVolume", value)
	self:Refresh()
end

function P:BuildMenu(_, menu)
	table.insert(menu, { text = "Silenciar todo", checked = not soundOn(), func = function()
		SetCVar("Sound_EnableAllSound", soundOn() and 0 or 1)
		P:Refresh()
	end })
end
