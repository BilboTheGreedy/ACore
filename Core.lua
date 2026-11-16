ACore = {}
local A = ACore

A.UI = {}
A.addons = {}

function A.Fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			A.Fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function A.IsSecret(v)
	if issecretvalue then
		local ok, secret = pcall(issecretvalue, v)
		return ok and secret
	end
	return false
end

function A.After(delay, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, fn)
	else
		fn()
	end
end

function A.Money(copper)
	copper = math.floor(copper or 0)
	local g = math.floor(copper / 10000)
	local s = math.floor(copper / 100) % 100
	local c = copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = "|cffffd100" .. g .. "g|r" end
	if s > 0 or g > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
	if c > 0 or #out == 0 then out[#out + 1] = "|cffeda55f" .. c .. "c|r" end
	return table.concat(out, " ")
end

function A.Short(n)
	if n >= 1000000 then return string.format("%.2fm", n / 1000000) end
	if n >= 10000 then return string.format("%.1fk", n / 1000) end
	return tostring(math.floor(n + 0.5))
end

function A.New(name, ns, opts)
	opts = opts or {}
	ns.name = name
	ns.UI = setmetatable({}, { __index = A.UI })
	ns.IsSecret = A.IsSecret
	ns.After = A.After
	ns.playerFaction = "Alliance"
	ns.playerClass = "WARRIOR"

	local listeners = {}
	function ns:Listen(msg, fn)
		listeners[msg] = listeners[msg] or {}
		table.insert(listeners[msg], fn)
	end

	function ns:Fire(msg, ...)
		local l = listeners[msg]
		if not l then return end
		for i = 1, #l do l[i](...) end
	end

	local frame = CreateFrame("Frame")
	local handlers = {}
	ns.events = frame
	function ns:On(event, fn)
		if not handlers[event] then
			handlers[event] = {}
			pcall(frame.RegisterEvent, frame, event)
		end
		table.insert(handlers[event], fn)
	end

	frame:SetScript("OnEvent", function(_, event, ...)
		local l = handlers[event]
		if not l then return end
		for i = 1, #l do l[i](...) end
	end)

	function ns.Print(msg)
		print("|cffffd100" .. name .. "|r: " .. tostring(msg))
	end

	local pending = {}
	function ns.Debounce(key, delay, fn)
		if pending[key] then
			pending[key] = fn
			return
		end
		pending[key] = fn
		A.After(delay, function()
			local f = pending[key]
			pending[key] = nil
			if f then f() end
		end)
	end

	ns:On("ADDON_LOADED", function(loaded)
		if loaded ~= name then return end
		if opts.db then
			_G[opts.db] = A.Fill(_G[opts.db] or {}, opts.defaults or {})
			ns.db = _G[opts.db]
		end
		if opts.char then
			_G[opts.char] = A.Fill(_G[opts.char] or {}, opts.charDefaults or {})
			ns.chardb = _G[opts.char]
		end
		ns:Fire("READY")
	end)

	ns:On("PLAYER_LOGIN", function()
		local faction = UnitFactionGroup and UnitFactionGroup("player")
		if faction == "Horde" or faction == "Alliance" then ns.playerFaction = faction end
		local _, class = UnitClass("player")
		if class then ns.playerClass = class end
		ns:Fire("LOGIN")
	end)

	return ns
end

function A.Register(info)
	for i, a in ipairs(A.addons) do
		if a.name == info.name then
			A.addons[i] = info
			return
		end
	end
	A.addons[#A.addons + 1] = info
	table.sort(A.addons, function(x, y) return x.name < y.name end)
end
