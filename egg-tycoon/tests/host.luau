-- tests/host.luau — o Roblox falso usado pelos testes.
-- Um metatable unico resolve props -> metodos -> sinais; tipos de valor
-- (Vector3, CFrame, UDim2, Color3) tem aritmetica de verdade. Vive num arquivo
-- proprio porque os varios testes precisam do MESMO host: se divergirem, o
-- teste passa no editor e quebra no jogo.

local __errors = {}
local __sent = {}

-- ===== host falso do Roblox =================================================
-- Um metatable unico resolve props -> metodos da cadeia -> sinais.
-- Nao tenta imitar o Roblox inteiro: so o que a UI usa.

local SIGNALS = {}
for _, n in ipairs({
	"Activated",
	"Changed",
	"ChildAdded",
	"ChildRemoved",
	"Touched",
	"InputBegan",
	"InputChanged",
	"InputEnded",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseButton1Click",
	"MouseButton2Click",
	"MouseEnter",
	"MouseLeave",
	"MouseMoved",
	"MouseClick",
	"OnClientEvent",
	"OnServerEvent",
	"CharacterAdded",
	"CharacterRemoving",
	"PlayerAdded",
	"PlayerRemoving",
	"AncestryChanged",
	"DescendantAdded",
}) do
	SIGNALS[n] = true
end

local function newSignal()
	local sig = { _fns = {} }
	function sig:Connect(fn)
		self._fns[#self._fns + 1] = fn
		return { Disconnect = function() end, Connected = true }
	end
	sig.Once = sig.Connect
	function sig:Wait() end
	function sig:_fire(...)
		for _, fn in ipairs(self._fns) do
			local ok, err = pcall(fn, ...)
			if not ok then
				__errors[#__errors + 1] = tostring(err)
			end
		end
	end
	return sig
end

local Methods = {}
function Methods:GetChildren()
	local out = {}
	for _, c in ipairs(rawget(self, "__children")) do
		out[#out + 1] = c
	end
	return out
end
function Methods:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(rawget(n, "__children")) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods:FindFirstChild(name, recursive)
	for _, c in ipairs(rawget(self, "__children")) do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in ipairs(self:GetDescendants()) do
			if d.Name == name then
				return d
			end
		end
	end
	return nil
end
function Methods:FindFirstChildOfClass(cls)
	for _, c in ipairs(rawget(self, "__children")) do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function Methods:WaitForChild(name)
	return self:FindFirstChild(name)
end
function Methods:IsA(cls)
	local c = rawget(self, "__chain")
	for _, name in ipairs(c) do
		if name == cls then
			return true
		end
	end
	return false
end
function Methods:Destroy()
	local p = rawget(self, "__props").Parent
	if p then
		local kids = rawget(p, "__children")
		for i, c in ipairs(kids) do
			if c == self then
				table.remove(kids, i)
				break
			end
		end
	end
	rawget(self, "__props").Parent = nil
	rawset(self, "__dead", true)
end
function Methods:SetAttribute(k, v)
	local a = rawget(self, "__attrs")
	a[k] = v
end
function Methods:GetAttribute(k)
	return rawget(self, "__attrs")[k]
end
function Methods:GetPropertyChangedSignal(k)
	return newSignal()
end
function Methods:Clone()
	return self
end
function Methods:ClearAllChildren() end

local mt = {}
mt.__index = function(self, key)
	local props = rawget(self, "__props")
	if props[key] ~= nil then
		return props[key]
	end
	local method = Methods[key]
	if method then
		return method
	end
	if SIGNALS[key] then
		local cache = rawget(self, "__signals")
		if not cache[key] then
			cache[key] = newSignal()
		end
		return cache[key]
	end
	return nil
end
mt.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			local kids = rawget(old, "__children")
			for i, c in ipairs(kids) do
				if c == self then
					table.remove(kids, i)
					break
				end
			end
		end
		props.Parent = value
		if value then
			local kids = rawget(value, "__children")
			kids[#kids + 1] = self
		end
		return
	end
	props[key] = value
end
mt.__tostring = function(self)
	return "[" .. rawget(self, "__props").ClassName .. ":" .. tostring(rawget(self, "__props").Name) .. "]"
end

local vecMt = {
	__add = function(a, b)
		return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, vecMt)
	end,
	__sub = function(a, b)
		return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, vecMt)
	end,
	__mul = function(a, n)
		return setmetatable({ X = a.X * n, Y = a.Y * n }, vecMt)
	end,
	__tostring = function(a)
		return string.format("(%g, %g)", a.X, a.Y)
	end,
}
local function vec(x, y)
	return setmetatable({ X = x, Y = y }, vecMt)
end

local vec3Mt = {}
vec3Mt.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, vec3Mt)
end
vec3Mt.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, vec3Mt)
end
vec3Mt.__mul = function(a, n)
	return setmetatable({ X = a.X * n, Y = a.Y * n, Z = a.Z * n }, vec3Mt)
end
vec3Mt.__div = function(a, n)
	return setmetatable({ X = a.X / n, Y = a.Y / n, Z = a.Z / n }, vec3Mt)
end
vec3Mt.__tostring = function(a)
	return string.format("(%g, %g, %g)", a.X, a.Y, a.Z)
end
vec3Mt.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return setmetatable({ X = 0, Y = 0, Z = 0 }, vec3Mt)
		end
		return setmetatable({ X = v.X / m, Y = v.Y / m, Z = v.Z / m }, vec3Mt)
	end
	return nil
end
local function vec3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vec3Mt)
end

local cframeMt = {
	__mul = function(a, b)
		return setmetatable({ ok = true, pos = a.pos }, cframeMt)
	end,
}
local function cframe(pos)
	return setmetatable({ pos = pos or vec3(0, 0, 0) }, cframeMt)
end

local CHAINS = {
	Instance = { "Instance" },
	Part = { "Part", "BasePart", "PVInstance", "Instance" },
	Frame = { "Frame", "GuiObject", "GuiBase2d", "Instance" },
	TextLabel = { "TextLabel", "GuiObject", "GuiBase2d", "Instance" },
	TextButton = { "TextButton", "GuiObject", "GuiBase2d", "Instance" },
	ScrollingFrame = { "ScrollingFrame", "GuiObject", "GuiBase2d", "Instance" },
	ScreenGui = { "ScreenGui", "LayerCollector", "Instance" },
	Folder = { "Folder", "Instance" },
	Model = { "Model", "PVInstance", "Instance" },
	ClickDetector = { "ClickDetector", "Instance" },
	SurfaceGui = { "SurfaceGui", "LayerCollector", "Instance" },
	BillboardGui = { "BillboardGui", "LayerCollector", "Instance" },
	PointLight = { "PointLight", "Light", "Instance" },
}

-- Props com default != nil, como no Roblox. Sem isso, Part.Position e
-- GuiObject.Visible vem nil e o codigo quebra num lugar que nunca quebraria.
local DEFAULTS = {
	Part = { Position = nil, Visible = true },
	Folder = { Visible = true },
}

Instance = {
	new = function(className)
		local chain = CHAINS[className] or { className, "Instance" }
		local props = { Name = className, ClassName = className }
		-- toda instancia tem Visible = true (GuiObject e BasePart inclusive)
		props.Visible = true
		if className == "Part" then
			props.Position = vec3(0, 0, 0)
			props.Size = vec3(1, 1, 1)
			props.CFrame = cframe(vec3(0, 0, 0))
			props.Transparency = 0
			props.Anchored = false
			props.CanCollide = true
		elseif className == "ScreenGui" then
			props.Enabled = true
		end
		return setmetatable({
			__props = props,
			__children = {},
			__attrs = {},
			__signals = {},
			__chain = chain,
		}, mt)
	end,
}

-- ===== tipos de valor =======================================================
-- UDim/UDim2 com aritmetica de verdade: o Theme soma Position + UDim2.fromOffset.
local udimMt = {
	__add = function(a, b)
		return setmetatable({ Scale = a.Scale + b.Scale, Offset = a.Offset + b.Offset }, udimMt)
	end,
	__sub = function(a, b)
		return setmetatable({ Scale = a.Scale - b.Scale, Offset = a.Offset - b.Offset }, udimMt)
	end,
	__tostring = function(a)
		return string.format("{%g,%d}", a.Scale, a.Offset)
	end,
}
local function axis(s, o)
	return setmetatable({ Scale = s, Offset = o }, udimMt)
end

local udim2Mt = {
	__add = function(a, b)
		return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, udim2Mt)
	end,
	__sub = function(a, b)
		return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, udim2Mt)
	end,
	__tostring = function(a)
		return "{ " .. tostring(a.X) .. ", " .. tostring(a.Y) .. " }"
	end,
}

UDim = { new = axis }
UDim2 = {
	new = function(xs, xo, ys, yo)
		return setmetatable({ X = axis(xs, xo), Y = axis(ys, yo) }, udim2Mt)
	end,
	fromOffset = function(x, y)
		return UDim2.new(0, x, 0, y)
	end,
	fromScale = function(x, y)
		return UDim2.new(x, 0, y, 0)
	end,
}
Vector2 = { new = vec, zero = vec(0, 0) }
Vector3 = { new = vec3 }

-- CFrame.lookAt/new sao chamados com ":" (metodo) no WorldUI, entao recebem self.
CFrame = {}
function CFrame.new(self, x, y, z)
	if type(self) == "number" then
		return cframe(vec3(self, x or 0, y or 0))
	end
	if type(x) == "number" then
		return cframe(vec3(x, y or 0, z or 0))
	end
	return cframe(x)
end
function CFrame.lookAt(_, at, target)
	return cframe(at)
end
function CFrame.Angles()
	return cframe()
end
Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
ColorSequence = {
	new = function(a, b)
		return { a, b }
	end,
}
NumberSequence = {
	new = function(a, b)
		return { a, b }
	end,
}
NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b }
	end,
}
TweenInfo = {
	new = function(...)
		return { ... }
	end,
}

Enum = setmetatable({}, {
	__index = function(t, group)
		local g = setmetatable({}, {
			__index = function(gg, value)
				local v = { Name = value, Value = tostring(value), EnumType = group }
				rawset(gg, value, v)
				return v
			end,
		})
		rawset(t, group, g)
		return g
	end,
})

-- ===== servicos =============================================================
local PlayerGui = Instance.new("Folder")
PlayerGui.Name = "PlayerGui"

local services = {}
local function fakeTween()
	return { Play = function() end, Cancel = function() end, Completed = newSignal() }
end

local function service(name)
	if services[name] then
		return services[name]
	end
	local svc = Instance.new("Folder")
	svc.Name = name
	if name == "Players" then
		svc.LocalPlayer = {
			Name = "He",
			DisplayName = "He",
			UserId = 1,
			Parent = svc,
		}
		svc.LocalPlayer.WaitForChild = function(_, n)
			if n == "PlayerGui" then
				return PlayerGui
			end
			return Instance.new("Folder")
		end
		svc.LocalPlayer.Character = nil
		svc.GetPlayers = function()
			return {}
		end
	elseif name == "TweenService" then
		svc.Create = function()
			return fakeTween()
		end
	elseif name == "RunService" then
		svc.RenderStepped = newSignal()
		svc.Heartbeat = newSignal()
		svc.IsStudio = function()
			return true
		end
	elseif name == "UserInputService" then
		svc.InputBegan = newSignal()
		svc.InputChanged = newSignal()
		svc.InputEnded = newSignal()
		svc.GetMouseLocation = function()
			return vec(0, 0)
		end
	elseif name == "ReplicatedStorage" then
		-- WaitForChild("Shared") devolve uma pasta de verdade; o require do módulo
		-- é removido, então o conteúdo não importa, só existir.
		local shared = Instance.new("Folder")
		shared.Name = "Shared"
		shared.Parent = svc
		local remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = svc
		for _, remoteName in ipairs({ "State", "Action", "Event" }) do
			local r = Instance.new("Folder")
			r.Name = remoteName
			r.FireServer = function(_, kind, payload)
				__sent[#__sent + 1] = { kind = kind, payload = payload }
			end
			r.FireClient = function() end
			r.Parent = remotes
		end
	elseif name == "ContextActionService" then
		svc.BindAction = function() end
		svc.UnbindAction = function() end
	end
	services[name] = svc
	return svc
end
services.PlayerGui = PlayerGui

game = {
	GetService = function(_, n)
		return service(n)
	end,
	BindToClose = function() end,
}

task = {
	wait = function() end,
	delay = function(_, fn) end,
	spawn = function(fn) end,
	defer = function(fn)
		fn()
	end,
	cancel = function() end,
}

Random = {
	new = function()
		local seed = 1234
		return {
			NextNumber = function(_, a, b)
				seed = (seed * 1103515245 + 12345) % 2147483648
				local v = seed / 2147483648
				if a then
					return a + v * (b - a)
				end
				return v
			end,
			NextInteger = function(_, a, b)
				return a + math.floor((b - a + 1) * (seed / 2147483648))
			end,
		}
	end,
}

print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end
	hostprint("[lua] " .. table.concat(parts, " "))
end
warn = print
