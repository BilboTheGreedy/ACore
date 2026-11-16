local A = ACore
local UI = A.UI
local ns = A.New("ACore", {}, {
	db = "ACoreDB",
	defaults = { minimap = { show = true, angle = 215 }, buttons = {} },
})

local button
local extra = {}

local function place(b, store)
	local angle = math.rad(store.angle or 215)
	local radius = (Minimap:GetWidth() / 2) + 6
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function make(name, icon, store, onClick, onEnter)
	local b = CreateFrame("Button", name, Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b.icon = b:CreateTexture(nil, "BACKGROUND")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("CENTER", 0, 0)
	b.icon:SetTexture(icon)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", onEnter)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			store.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			place(self, store)
		end)
	end)
	b:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	return b
end

local function addonIcon(a)
	if a.icon then return a.icon end
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if get then
		local ok, tex = pcall(get, a.name, "IconTexture")
		if ok and type(tex) == "string" and tex ~= "" then return tex end
	end
	return "Interface\\Icons\\INV_Misc_Gear_01"
end

local function find(name)
	for _, a in ipairs(A.addons) do
		if a.name == name then return a end
	end
end

function A.HasButton(name)
	local store = ns.db and ns.db.buttons[name]
	return store and store.show or false
end

function A.SetButton(name, show)
	if not ns.db then return end
	local store = ns.db.buttons[name]
	if not store then
		local n = 0
		for _ in pairs(ns.db.buttons) do n = n + 1 end
		store = { angle = 190 - n * 22 }
		ns.db.buttons[name] = store
	end
	store.show = show and true or false
	A.RefreshButtons()
end

function A.RefreshButtons()
	if not Minimap or not ns.db then return end
	for name, store in pairs(ns.db.buttons) do
		local a = find(name)
		local b = extra[name]
		if store.show and a then
			if not b then
				b = make(name .. "MinimapButton", addonIcon(a), store, function(self, click)
					local info = find(name)
					if not info then return end
					if click == "RightButton" then
						UI.Menu(self, {
							{ text = info.title or name, title = true },
							{ text = "Open", func = function() if info.toggle then info.toggle() end end },
							{ text = "Options", func = function() A.OpenPanel(name) end },
							{ text = "Hide this button", func = function() A.SetButton(name, false) end },
						})
					elseif info.toggle then
						info.toggle()
					end
				end, function(self)
					local info = find(name)
					GameTooltip:SetOwner(self, "ANCHOR_LEFT")
					GameTooltip:AddLine(info and info.title or name, 1, 0.82, 0)
					if info and info.desc then GameTooltip:AddLine(info.desc, 0.9, 0.9, 0.92) end
					GameTooltip:AddLine("Click to open, right-click for more, drag to move", 0.58, 0.6, 0.65)
					GameTooltip:Show()
				end)
				extra[name] = b
			end
			place(b, store)
			b:Show()
		elseif b then
			b:Hide()
		end
	end
end

function A.OpenMenu(anchor)
	local entries = {
		{ text = "A addons", title = true },
		{ text = "Control panel", color = { 0.55, 0.8, 1 }, func = function() A.OpenPanel() end },
		{ text = A.LayoutActive() and "Lock frames" or "Move and resize frames", color = { 0.55, 0.8, 1 }, func = function() A.LayoutMode() end },
		{ text = "Installed", title = true },
	}
	for _, a in ipairs(A.addons) do
		entries[#entries + 1] = { text = a.title or a.name, func = a.toggle }
	end
	if #A.addons == 0 then
		entries[#entries + 1] = { text = "Nothing installed", title = true }
	end
	entries[#entries + 1] = { text = "Hide minimap button", func = function() A.SetMinimap(false) end }
	UI.Menu(anchor, entries)
end

local function build()
	button = make("ACoreMinimapButton", "Interface\\Icons\\INV_Misc_Gear_01", ns.db.minimap, function(self) A.OpenMenu(self) end, function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("A addons", 1, 0.82, 0)
		for _, a in ipairs(A.addons) do
			GameTooltip:AddDoubleLine(a.title or a.name, a.slash or "", 0.9, 0.9, 0.92, 0.58, 0.6, 0.65)
		end
		GameTooltip:AddLine("Click for the list, drag to move", 0.58, 0.6, 0.65)
		GameTooltip:Show()
	end)
end

local function update()
	if not Minimap or not ns.db then return end
	if ns.db.minimap.show then
		if not button then build() end
		place(button, ns.db.minimap)
		button:Show()
	elseif button then
		button:Hide()
	end
	A.RefreshButtons()
end

function A.SetMinimap(show)
	if not ns.db then return end
	ns.db.minimap.show = show and true or false
	update()
end

function A.MinimapShown()
	return ns.db and ns.db.minimap.show
end

ns:Listen("LOGIN", update)

function ACore_OnCompartmentClick(_, _, frame)
	A.OpenMenu(frame or UIParent)
end

SLASH_ACORE1 = "/acore"
SLASH_ACORE2 = "/a"
SlashCmdList["ACORE"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "minimap" then
		A.SetMinimap(not A.MinimapShown())
		return
	elseif msg == "move" or msg == "unlock" or msg == "layout" then
		A.LayoutMode(true)
		return
	elseif msg == "lock" then
		A.LayoutMode(false)
		return
	elseif msg == "" then
		A.TogglePanel()
		return
	end
	for _, a in ipairs(A.addons) do
		if msg ~= "" and a.name:lower():find(msg, 1, true) and a.toggle then
			a.toggle()
			return
		end
	end
	A.OpenPanel()
end
