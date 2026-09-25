-- Misiones: "Misiones: completas/total". Tooltip con la lista por zona. Clic: registro de misiones.
local Util = WCDPanel.Util

local P = WCDPanel:NewPlugin("Quests", {
	title = "Misiones",
	defaultPlacement = { bar = true, zone = "LEFT", order = 4 },
	events = { "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" },
})

local function questList()
	local groups, current = {}, nil
	local complete, total = 0, 0
	local numEntries = GetNumQuestLogEntries()
	for i = 1, numEntries do
		local title, level, tag, _, isHeader, _, isComplete = GetQuestLogTitle(i)
		if isHeader then
			current = { name = title, quests = {} }
			table.insert(groups, current)
		elseif title then
			total = total + 1
			if isComplete == 1 then complete = complete + 1 end
			if not current then
				current = { name = "", quests = {} }
				table.insert(groups, current)
			end
			table.insert(current.quests, { title = title, level = level, tag = tag, complete = isComplete })
		end
	end
	local _, numQuests = GetNumQuestLogEntries()
	return groups, complete, math.max(total, numQuests or 0)
end

function P:OnEvent() self:Refresh() end

function P:GetText()
	local _, complete, total = questList()
	return "Misiones:", Util.Green(complete) .. Util.Gray("/") .. Util.White(total)
end

function P:GetIcon() return "Interface\\Icons\\INV_Misc_Book_09" end

function P:OnTooltip(_, tooltip)
	local groups, complete, total = questList()
	tooltip:SetText(format("Misiones: %d de %d completas", complete, total))
	for _, group in ipairs(groups) do
		if #group.quests > 0 then
			tooltip:AddLine(group.name, 1, 0.82, 0)
			for _, q in ipairs(group.quests) do
				local c = GetQuestDifficultyColor(q.level)
				local state = q.complete == 1 and Util.Green(" (completa)") or (q.complete == -1 and Util.Red(" (fallida)") or "")
				local tag = q.tag and (" [" .. q.tag .. "]") or ""
				tooltip:AddLine(format("  [%d] %s%s%s", q.level, q.title, tag, state), c.r, c.g, c.b)
			end
		end
	end
	tooltip:AddLine(" ")
	tooltip:AddLine("Clic: registro de misiones.", 0.6, 0.6, 0.6)
end

function P:OnClick(_, button)
	if button == "LeftButton" then ToggleFrame(QuestLogFrame) end
end
