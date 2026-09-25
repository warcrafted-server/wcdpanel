-- Hermandad: "Hermandad: conectados/total". Tooltip con los conectados; clic abre la pestaña
-- de hermandad; el menú permite susurrar o invitar.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Guild", {
	title = "Hermandad",
	defaults = { profile = { sameZone = false, maxLines = 30 } },
	defaultPlacement = { bar = true, zone = "LEFT", order = 8 },
	events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD" },
	interval = 30,
})

local function members()
	local list, total = {}, GetNumGuildMembers(true) or 0
	for i = 1, total do
		local name, rank, _, level, class, zone, note, _, online, status, classFile = GetGuildRosterInfo(i)
		if name and online then
			table.insert(list, { name = name, rank = rank, level = level, class = class, zone = zone,
				note = note, status = status, classFile = classFile })
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list, total
end

-- GuildRoster pide la lista al servidor; el cliente ignora peticiones seguidas, se pide cada 30 s.
function P:OnTick() if IsInGuild() then GuildRoster() end end
function P:OnEnable() if IsInGuild() then GuildRoster() end end
function P:OnEvent() self:Refresh() end

function P:GetText()
	if not IsInGuild() then return "Hermandad:", Util.Gray("—") end
	local online, total = members()
	return "Hermandad:", Util.Green(#online) .. Util.Gray("/" .. total)
end

function P:GetIcon() return "Interface\\Icons\\INV_Shirt_GuildTabard_01" end

function P:OnTooltip(_, tooltip)
	if not IsInGuild() then
		tooltip:SetText("Sin hermandad")
		return
	end
	local guildName = GetGuildInfo("player")
	local online, total = members()
	tooltip:SetText(format("%s (%d/%d)", guildName or "Hermandad", #online, total))
	local motd = GetGuildRosterMOTD()
	if motd and motd ~= "" then tooltip:AddLine(motd, 0.1, 1, 0.1, true) end
	local myZone = GetRealZoneText()
	local shown = 0
	for _, m in ipairs(online) do
		if not self.db.profile.sameZone or m.zone == myZone then
			shown = shown + 1
			if shown > self.db.profile.maxLines then
				tooltip:AddLine(format("… y %d más", #online - self.db.profile.maxLines), 0.6, 0.6, 0.6)
				break
			end
			local color = RAID_CLASS_COLORS[m.classFile] or { r = 1, g = 1, b = 1 }
			local left = format("%s |cff9d9d9d%d %s|r", m.name, m.level, m.status or "")
			tooltip:AddDoubleLine(left, (m.zone or "") .. Util.Gray(" · " .. (m.rank or "")), color.r, color.g, color.b, 1, 1, 1)
		end
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: ventana de hermandad. Clic derecho: susurrar o invitar.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button == "LeftButton" and IsInGuild() then ToggleFriendsFrame(3) end
end

function P:BuildMenu(_, menu)
	if not IsInGuild() then return end
	local whisper, invite = {}, {}
	local me = UnitName("player")
	for _, m in ipairs((members())) do
		if m.name ~= me then
			table.insert(whisper, { text = m.name, notCheckable = true, func = function() ChatFrame_SendTell(m.name) end })
			table.insert(invite, { text = m.name, notCheckable = true, func = function() InviteUnit(m.name) end })
		end
	end
	if #whisper > 0 then
		table.insert(menu, { text = "Susurrar", notCheckable = true, hasArrow = true, menuList = whisper })
		table.insert(menu, { text = "Invitar al grupo", notCheckable = true, hasArrow = true, menuList = invite })
	end
end

function P:GetOptions()
	local db = self.db.profile
	return {
		sameZone = {
			type = "toggle", order = 1, name = "Tooltip: solo los que están en mi zona", width = "full",
			get = function() return db.sameZone end,
			set = function(_, v) db.sameZone = v end,
		},
		maxLines = {
			type = "range", order = 2, name = "Máximo de nombres en el tooltip", min = 5, max = 60, step = 5,
			get = function() return db.maxLines end,
			set = function(_, v) db.maxLines = v end,
		},
	}
end
