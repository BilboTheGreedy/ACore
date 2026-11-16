local A = ACore
local UI = A.UI
local C = UI.colors

local frame
local selected = "general"

local function general()
	local current = A.Profile()
	local rows = {
		{ text = "Layout", title = true },
		{ text = A.LayoutActive() and "Lock frames" or "Unlock frames to move and resize", func = function()
			if A.LayoutMode() and A.LayoutActive() then frame:Hide() end
		end },
		{ text = "Minimap button", checked = A.MinimapShown(), func = function() A.SetMinimap(not A.MinimapShown()) end },
		{ text = "Profile  (applies to every A addon, switching reloads the interface)", title = true },
	}
	for _, name in ipairs(A.Profiles()) do
		rows[#rows + 1] = {
			text = name, checked = name == current,
			func = function()
				if name ~= current then A.SetProfile(name) end
			end,
		}
	end
	rows[#rows + 1] = { text = "New profile copied from " .. current .. "...", func = function()
		UI.Prompt("Name of the new profile", "", function(text) A.NewProfile(text, current) end)
	end }
	rows[#rows + 1] = { text = "New empty profile...", func = function()
		UI.Prompt("Name of the new profile", "", function(text) A.NewProfile(text) end)
	end }
	rows[#rows + 1] = { text = "Reset " .. current .. " to defaults", func = function()
		UI.Confirm("Reset the profile " .. current .. " for every A addon?", function() A.ResetProfile(current) end)
	end }
	if current ~= "Default" then
		rows[#rows + 1] = { text = "Delete " .. current, func = function()
			UI.Confirm("Delete the profile " .. current .. "?", function() A.DeleteProfile(current) end)
		end }
	end
	rows[#rows + 1] = { text = "Own minimap buttons", title = true }
	for _, a in ipairs(A.addons) do
		if a.toggle then
			rows[#rows + 1] = {
				text = a.title or a.name, checked = A.HasButton(a.name),
				func = function() A.SetButton(a.name, not A.HasButton(a.name)) end,
			}
		end
	end
	rows[#rows + 1] = { text = "Installed", title = true }
	for _, a in ipairs(A.addons) do
		rows[#rows + 1] = { text = (a.title or a.name) .. "   " .. (a.slash or "") .. "   " .. (a.desc or ""), note = true }
	end
	return rows
end

local function addonRows(a)
	local rows = {
		{ text = a.title or a.name, title = true },
	}
	if a.desc then rows[#rows + 1] = { text = a.desc, note = true } end
	if a.toggle then
		rows[#rows + 1] = { text = "Open " .. (a.title or a.name), func = function()
			frame:Hide()
			a.toggle()
		end }
	end
	if a.toggle then
		rows[#rows + 1] = {
			text = "Own minimap button", checked = A.HasButton(a.name),
			func = function() A.SetButton(a.name, not A.HasButton(a.name)) end,
		}
	end
	if a.options then
		local ok, entries = pcall(a.options)
		if ok and type(entries) == "table" then
			for _, e in ipairs(entries) do rows[#rows + 1] = e end
		end
	elseif a.slash then
		rows[#rows + 1] = { text = "More settings: " .. a.slash, note = true }
	end
	return rows
end

local function rows()
	if selected == "general" then return general() end
	for _, a in ipairs(A.addons) do
		if a.name == selected then return addonRows(a) end
	end
	selected = "general"
	return general()
end

local function nav()
	local list = { { key = "general", text = "General" } }
	for _, a in ipairs(A.addons) do
		list[#list + 1] = { key = a.name, text = a.title or a.name }
	end
	return list
end

local function refresh(keep)
	if not frame or not frame:IsShown() then return end
	frame.navList:SetData(nav(), true)
	frame.list:SetData(rows(), keep)
end

local function build()
	ACoreDB.panel = ACoreDB.panel or {}
	frame = UI.Window("ACorePanel", "A addons", 760, 520, ACoreDB.panel)
	local body = frame.body
	local left = CreateFrame("Frame", nil, body)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(170)
	UI.Fill(left, C.panel)

	frame.navList = UI.List(left, 22, function(list)
		local row = CreateFrame("Button", nil, list)
		row.sel = UI.Fill(row, C.select)
		row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
		row.text = UI.Text(row, "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", 12, 0)
		row:SetScript("OnClick", function(self)
			if not self.data then return end
			selected = self.data.key
			refresh()
		end)
		return row
	end, function(row, d)
		row.text:SetText(d.text)
		local on = d.key == selected
		row.sel:SetShown(on)
		local c = on and C.accent or C.text
		row.text:SetTextColor(c[1], c[2], c[3])
	end)
	frame.navList:SetPoint("TOPLEFT", 0, -4)
	frame.navList:SetPoint("BOTTOMRIGHT", 0, 4)

	frame.list = UI.List(body, 24, function(list)
		local row = CreateFrame("Button", nil, list)
		row.band = UI.Fill(row, { 1, 1, 1, 0.05 })
		row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
		row.box = UI.Tex(row, "ARTWORK", { 0.03, 0.03, 0.04, 1 })
		row.box:SetSize(14, 14)
		row.box:SetPoint("LEFT", 12, 0)
		row.tick = UI.Tex(row, "OVERLAY", C.accent)
		row.tick:SetSize(8, 8)
		row.tick:SetPoint("CENTER", row.box, "CENTER")
		row.text = UI.Text(row, "GameFontHighlight")
		row.text:SetPoint("RIGHT", -8, 0)
		row:SetScript("OnClick", function(self)
			local d = self.data
			if not d or d.title or d.note or not d.func then return end
			d.func()
			refresh(true)
		end)
		return row
	end, function(row, d)
		local check = d.checked ~= nil and not d.title
		row.band:SetShown(d.title and true or false)
		row.hl:SetShown(not d.title and not d.note and d.func ~= nil)
		row.box:SetShown(check)
		row.tick:SetShown(check and d.checked and true or false)
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", check and 34 or 12, 0)
		row.text:SetPoint("RIGHT", -8, 0)
		row.text:SetText(d.text or "")
		local c = C.text
		if d.title then
			c = C.accent
		elseif d.note then
			c = C.dim
		elseif d.color then
			c = d.color
		elseif d.func and d.checked == nil then
			c = { 0.55, 0.8, 1 }
		end
		row.text:SetTextColor(c[1], c[2], c[3])
	end)
	frame.list:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, -4)
	frame.list:SetPoint("BOTTOMRIGHT", 0, 4)
end

function A.OpenPanel(name)
	if not ACoreDB then return end
	if not frame then build() end
	if name then selected = name end
	frame:Show()
	refresh()
end

function A.TogglePanel()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		A.OpenPanel()
	end
end
