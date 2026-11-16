local A = ACore
local UI = A.UI

UI.colors = {
	bg = { 0.06, 0.065, 0.08, 0.97 },
	panel = { 0.09, 0.095, 0.115, 1 },
	bar = { 0.12, 0.125, 0.15, 1 },
	line = { 0.22, 0.23, 0.27, 1 },
	hover = { 1, 1, 1, 0.07 },
	select = { 1, 0.82, 0, 0.16 },
	accent = { 1, 0.82, 0 },
	text = { 0.9, 0.9, 0.92 },
	dim = { 0.58, 0.6, 0.65 },
}
local C = UI.colors

function UI.Tex(parent, layer, color)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	local c = color or C.panel
	t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return t
end

function UI.Fill(frame, color, layer)
	local t = UI.Tex(frame, layer or "BACKGROUND", color)
	t:SetAllPoints(frame)
	return t
end

function UI.Border(frame, color)
	local c = color or C.line
	local edges = {}
	for i = 1, 4 do edges[i] = UI.Tex(frame, "BORDER", c) end
	edges[1]:SetPoint("TOPLEFT") edges[1]:SetPoint("TOPRIGHT") edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT") edges[2]:SetPoint("BOTTOMRIGHT") edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT") edges[3]:SetPoint("BOTTOMLEFT") edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT") edges[4]:SetPoint("BOTTOMRIGHT") edges[4]:SetWidth(1)
	return edges
end

function UI.Text(parent, font, justify, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	local c = color or C.text
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

function UI.Button(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(22)
	b.bg = UI.Fill(b, C.bar)
	b.edges = UI.Border(b)
	b.hl = UI.Fill(b, C.hover, "HIGHLIGHT")
	b.label = UI.Text(b, "GameFontHighlightSmall", "CENTER")
	b.label:SetPoint("CENTER")
	function b:SetLabel(t)
		self.label:SetText(t)
		self:SetWidth(math.max(40, (self.label:GetStringWidth() or 40) + 18))
	end
	function b:SetActive(on)
		local c = on and C.select or C.bar
		self.bg:SetColorTexture(c[1], c[2], c[3], on and 0.35 or 1)
		local t = on and C.accent or C.text
		self.label:SetTextColor(t[1], t[2], t[3])
	end
	b:SetLabel(text or "")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, button)
		if onClick then onClick(self, button) end
	end)
	return b
end

function UI.EditBox(parent, placeholder, onChange)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(24)
	UI.Fill(holder, { 0.03, 0.03, 0.04, 1 })
	UI.Border(holder)
	local eb = CreateFrame("EditBox", nil, holder)
	eb:SetPoint("TOPLEFT", 8, 0)
	eb:SetPoint("BOTTOMRIGHT", -22, 0)
	eb:SetAutoFocus(false)
	eb:SetFontObject("GameFontHighlight")
	eb:SetMaxLetters(60)
	local hint = UI.Text(holder, "GameFontDisable")
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(placeholder or "")
	local clear = CreateFrame("Button", nil, holder)
	clear:SetSize(18, 18)
	clear:SetPoint("RIGHT", -3, 0)
	clear.label = UI.Text(clear, "GameFontDisable", "CENTER")
	clear.label:SetPoint("CENTER")
	clear.label:SetText("x")
	clear:Hide()
	clear:SetScript("OnClick", function()
		eb:SetText("")
		eb:ClearFocus()
	end)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	eb:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		if text == "" then hint:Show() clear:Hide() else hint:Hide() clear:Show() end
		if onChange then onChange(text) end
	end)
	holder.box = eb
	return holder
end

function UI.List(parent, rowHeight, create, update)
	local list = CreateFrame("Frame", nil, parent)
	list.rows = {}
	list.data = {}
	list.offset = 0
	list.rowHeight = rowHeight
	if list.SetClipsChildren then list:SetClipsChildren(true) end

	local track = UI.Tex(list, "ARTWORK", { 1, 1, 1, 0.04 })
	track:SetPoint("TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", 0, 0)
	track:SetWidth(6)
	local thumb = CreateFrame("Button", nil, list)
	thumb:SetWidth(6)
	thumb.tex = UI.Fill(thumb, { 1, 1, 1, 0.28 }, "OVERLAY")

	function list:Visible()
		local h = self:GetHeight() or 0
		return math.max(0, math.floor(h / self.rowHeight))
	end

	function list:MaxOffset()
		return math.max(0, #self.data - self:Visible())
	end

	function list:Refresh()
		local visible = self:Visible()
		local maxOffset = self:MaxOffset()
		if self.offset > maxOffset then self.offset = maxOffset end
		if self.offset < 0 then self.offset = 0 end
		for i = 1, visible do
			local row = self.rows[i]
			if not row then
				row = create(self)
				row:SetHeight(self.rowHeight)
				row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1) * self.rowHeight)
				row:SetPoint("RIGHT", self, "RIGHT", -8, 0)
				self.rows[i] = row
			end
			local d = self.data[self.offset + i]
			if d then
				row.data = d
				update(row, d, self.offset + i)
				row:Show()
			else
				row.data = nil
				row:Hide()
			end
		end
		for i = visible + 1, #self.rows do self.rows[i]:Hide() end
		local total = #self.data
		if total > visible and visible > 0 then
			local h = self:GetHeight()
			local th = math.max(24, h * visible / total)
			local frac = maxOffset > 0 and self.offset / maxOffset or 0
			thumb:SetHeight(th)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(h - th) * frac)
			thumb:Show()
			track:Show()
		else
			thumb:Hide()
			track:Hide()
		end
	end

	function list:SetData(data, keep)
		self.data = data or {}
		if not keep then self.offset = 0 end
		self:Refresh()
	end

	function list:Scroll(delta)
		self.offset = self.offset + delta
		self:Refresh()
		local focus = self.hovered
		if focus and focus:IsShown() and focus.data and focus:GetScript("OnEnter") then
			focus:GetScript("OnEnter")(focus)
		end
	end

	function list:ScrollTo(index)
		self.offset = math.max(0, index - 1)
		self:Refresh()
	end

	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		self:Scroll(-delta * 3)
	end)
	list:SetScript("OnSizeChanged", function(self) self:Refresh() end)
	list:SetScript("OnShow", function(self) self:Refresh() end)

	thumb:SetScript("OnMouseDown", function(self)
		local _, y = GetCursorPosition()
		self.startY = y
		self.startOffset = list.offset
		self:SetScript("OnUpdate", function(t)
			local _, cy = GetCursorPosition()
			local scale = list:GetEffectiveScale()
			local h = list:GetHeight() - t:GetHeight()
			if h <= 0 then return end
			local moved = (t.startY - cy) / scale
			local target = t.startOffset + math.floor(moved / h * list:MaxOffset() + 0.5)
			if target ~= list.offset then
				list.offset = target
				list:Refresh()
			end
		end)
	end)
	thumb:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	thumb:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	return list
end

local menu
local function buildMenu()
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:RegisterForClicks("AnyUp")
	catcher:Hide()
	local m = CreateFrame("Frame", nil, catcher)
	m:SetFrameStrata("TOOLTIP")
	UI.Fill(m, { 0.05, 0.05, 0.065, 0.98 })
	UI.Border(m, { 0.35, 0.36, 0.42, 1 })
	m.items = {}
	m.catcher = catcher
	catcher:SetScript("OnClick", function() catcher:Hide() end)
	return m
end

function UI.CloseMenu()
	if menu then menu.catcher:Hide() end
end

function UI.Menu(anchor, entries)
	if not menu then menu = buildMenu() end
	local width = 120
	local y = -4
	for i, e in ipairs(entries) do
		local item = menu.items[i]
		if not item then
			item = CreateFrame("Button", nil, menu)
			item:SetHeight(20)
			item.hl = UI.Fill(item, C.hover, "HIGHLIGHT")
			item.check = UI.Text(item, "GameFontHighlightSmall", "CENTER", C.accent)
			item.check:SetPoint("LEFT", 6, 0)
			item.check:SetWidth(10)
			item.label = UI.Text(item, "GameFontHighlightSmall")
			item.label:SetPoint("LEFT", 20, 0)
			item:SetScript("OnClick", function(self)
				local entry = self.entry
				if not entry or entry.title then return end
				if not entry.keep then UI.CloseMenu() end
				if entry.func then entry.func() end
			end)
			menu.items[i] = item
		end
		item.entry = e
		item.label:SetText(e.text)
		item.check:SetText(e.checked and "+" or "")
		if e.title then
			item.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
			item.hl:Hide()
		elseif e.color then
			item.label:SetTextColor(e.color[1], e.color[2], e.color[3])
			item.hl:Show()
		else
			item.label:SetTextColor(C.text[1], C.text[2], C.text[3])
			item.hl:Show()
		end
		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, y)
		item:SetPoint("RIGHT", menu, "RIGHT", -2, 0)
		item:Show()
		y = y - 20
		width = math.max(width, (item.label:GetStringWidth() or 0) + 40)
	end
	for i = #entries + 1, #menu.items do menu.items[i]:Hide() end
	menu:SetSize(width, -y + 4)
	menu:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu.catcher:Show()
end

function UI.Prompt(title, default, onAccept)
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	StaticPopupDialogs["ACORE_PROMPT"] = {
		text = title,
		button1 = ACCEPT or "Accept",
		button2 = CANCEL or "Cancel",
		hasEditBox = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(self)
			local eb = (self.GetEditBox and self:GetEditBox()) or self.EditBox or self.editBox
			if eb then
				eb:SetText(default or "")
				eb:HighlightText()
			end
		end,
		OnAccept = function(self)
			local eb = (self.GetEditBox and self:GetEditBox()) or self.EditBox or self.editBox
			if eb then onAccept(eb:GetText()) end
		end,
		EditBoxOnEnterPressed = function(self)
			local parent = self:GetParent()
			onAccept(self:GetText())
			parent:Hide()
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
	}
	StaticPopup_Show("ACORE_PROMPT")
end

function UI.Confirm(text, onAccept)
	if not StaticPopupDialogs or not StaticPopup_Show then
		onAccept()
		return
	end
	StaticPopupDialogs["ACORE_CONFIRM"] = {
		text = text,
		button1 = YES or "Yes",
		button2 = NO or "No",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function() onAccept() end,
	}
	StaticPopup_Show("ACORE_CONFIRM")
end

function UI.Bar(parent, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(height or 18)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar.bg = UI.Fill(bar, { 0, 0, 0, 0.45 })
	bar.left = UI.Text(bar, "GameFontHighlightSmall", "LEFT")
	bar.left:SetPoint("LEFT", 5, 0)
	bar.right = UI.Text(bar, "GameFontHighlightSmall", "RIGHT")
	bar.right:SetPoint("RIGHT", -5, 0)
	bar.left:SetPoint("RIGHT", bar.right, "LEFT", -4, 0)
	function bar:SetColor(r, g, b, a)
		self:SetStatusBarColor(r, g, b, a or 1)
	end
	bar:SetColor(C.accent[1], C.accent[2], C.accent[3], 0.85)
	return bar
end

function UI.Movable(frame, db, onMoved, plain)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	function frame:Restore()
		local pos = db.pos
		self:ClearAllPoints()
		if pos and pos[1] then
			self:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
		elseif db.default then
			local d = db.default
			self:SetPoint(d[1], UIParent, d[2] or d[1], d[3] or 0, d[4] or 0)
		else
			self:SetPoint("CENTER")
		end
		self:SetScale(db.scale or 1)
	end
	function frame:StartDrag()
		if db.locked then return end
		self:StartMoving()
	end
	function frame:StopDrag()
		self:StopMovingOrSizing()
		local point, _, rel, x, y = self:GetPoint(1)
		db.pos = { point, rel, x, y }
		if onMoved then onMoved() end
	end
	frame:Restore()
	if not plain and A.RegisterMover then A.RegisterMover(frame, db, onMoved) end
	return frame
end

function UI.Window(name, title, width, height, db)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetSize(width, height)
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:Hide()
	UI.Fill(frame, C.bg)
	UI.Border(frame)
	UI.Movable(frame, db, nil, true)
	if name and UISpecialFrames then table.insert(UISpecialFrames, name) end

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(34)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() frame:StartDrag() end)
	bar:SetScript("OnDragStop", function() frame:StopDrag() end)
	UI.Fill(bar, C.bar)
	frame.bar = bar

	local text = UI.Text(bar, "GameFontNormalLarge", "LEFT", C.accent)
	text:SetPoint("LEFT", 14, 0)
	text:SetText(title or "")
	frame.title = text

	local close = UI.Button(bar, "x", function() frame:Hide() end)
	close:SetPoint("RIGHT", -8, 0)
	close:SetWidth(24)
	frame.close = close

	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", 0, -34)
	body:SetPoint("BOTTOMRIGHT")
	frame.body = body
	return frame
end

function UI.ScaleEntries(db, apply)
	local entries = { { text = "Size", title = true } }
	for _, s in ipairs({ 0.8, 0.9, 1, 1.1, 1.2, 1.35 }) do
		entries[#entries + 1] = {
			text = math.floor(s * 100 + 0.5) .. "%", checked = math.abs((db.scale or 1) - s) < 0.01,
			func = function()
				db.scale = s
				if apply then apply(s) end
			end,
		}
	end
	return entries
end

function UI.Toggle(db, key, text, after)
	return {
		text = text, checked = db[key],
		func = function()
			db[key] = not db[key]
			if after then after(db[key]) end
		end,
	}
end

UI.Check = UI.Toggle
