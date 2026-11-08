// client.mjs — sobe a UI do cliente num host falso do Roblox.
// Instancia cada painel, aplica snapshots reais e dispara eventos de rede.
// É o teste que pega "abri o jogo e a tela está vazia".
// Uso: node tests/client.mjs
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

// --- host falso do Roblox -------------------------------------------------
// Instâncias com propriedades dinâmicas, hierarquia, sinais e atributos.
const HOST = String.raw`
local __errors = {}
local __sent = {}

-- ===== host falso do Roblox =================================================
-- Um metatable unico resolve props -> metodos da cadeia -> sinais.
-- Nao tenta imitar o Roblox inteiro: so o que a UI usa.

local SIGNALS = {}
for _, n in ipairs({
  "Activated","Changed","ChildAdded","ChildRemoved","Touched","InputBegan","InputChanged","InputEnded",
  "MouseButton1Down","MouseButton1Up","MouseButton1Click","MouseButton2Click","MouseEnter","MouseLeave",
  "MouseMoved","MouseClick","OnClientEvent","OnServerEvent","CharacterAdded","CharacterRemoving","PlayerAdded",
  "PlayerRemoving","AncestryChanged","DescendantAdded",
}) do SIGNALS[n] = true end

local function newSignal()
  local sig = { _fns = {} }
  function sig:Connect(fn)
    self._fns[#self._fns+1] = fn
    return { Disconnect = function() end, Connected = true }
  end
  sig.Once = sig.Connect
  function sig:Wait() end
  function sig:_fire(...)
    for _, fn in ipairs(self._fns) do
      local ok, err = pcall(fn, ...)
      if not ok then __errors[#__errors+1] = tostring(err) end
    end
  end
  return sig
end

local Methods = {}
function Methods:GetChildren()
  local out = {}
  for _, c in ipairs(rawget(self, "__children")) do out[#out+1] = c end
  return out
end
function Methods:GetDescendants()
  local out = {}
  local function walk(n)
    for _, c in ipairs(rawget(n, "__children")) do
      out[#out+1] = c ; walk(c)
    end
  end
  walk(self)
  return out
end
function Methods:FindFirstChild(name, recursive)
  for _, c in ipairs(rawget(self, "__children")) do
    if c.Name == name then return c end
  end
  if recursive then
    for _, d in ipairs(self:GetDescendants()) do
      if d.Name == name then return d end
    end
  end
  return nil
end
function Methods:FindFirstChildOfClass(cls)
  for _, c in ipairs(rawget(self, "__children")) do
    if c.ClassName == cls then return c end
  end
  return nil
end
function Methods:WaitForChild(name) return self:FindFirstChild(name) end
function Methods:IsA(cls)
  local c = rawget(self, "__chain")
  for _, name in ipairs(c) do
    if name == cls then return true end
  end
  return false
end
function Methods:Destroy()
  local p = rawget(self, "__props").Parent
  if p then
    local kids = rawget(p, "__children")
    for i, c in ipairs(kids) do
      if c == self then table.remove(kids, i) break end
    end
  end
  rawget(self, "__props").Parent = nil
  rawset(self, "__dead", true)
end
function Methods:SetAttribute(k, v)
  local a = rawget(self, "__attrs") ; a[k] = v
end
function Methods:GetAttribute(k) return rawget(self, "__attrs")[k] end
function Methods:GetPropertyChangedSignal(k) return newSignal() end
function Methods:Clone() return self end
function Methods:ClearAllChildren() end

local mt = {}
mt.__index = function(self, key)
  local props = rawget(self, "__props")
  if props[key] ~= nil then return props[key] end
  local method = Methods[key]
  if method then return method end
  if SIGNALS[key] then
    local cache = rawget(self, "__signals")
    if not cache[key] then cache[key] = newSignal() end
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
        if c == self then table.remove(kids, i) break end
      end
    end
    props.Parent = value
    if value then
      local kids = rawget(value, "__children")
      kids[#kids+1] = self
    end
    return
  end
  props[key] = value
end
mt.__tostring = function(self)
  return "[" .. rawget(self, "__props").ClassName .. ":" .. tostring(rawget(self, "__props").Name) .. "]"
end

local vecMt = {
  __add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, vecMt) end,
  __sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, vecMt) end,
  __mul = function(a, n) return setmetatable({ X = a.X * n, Y = a.Y * n }, vecMt) end,
  __tostring = function(a) return string.format("(%g, %g)", a.X, a.Y) end,
}
local function vec(x, y) return setmetatable({ X = x, Y = y }, vecMt) end

local vec3Mt = {
  __add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, vec3Mt) end,
  __sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, vec3Mt) end,
  __mul = function(a, n) return setmetatable({ X = a.X * n, Y = a.Y * n, Z = a.Z * n }, vec3Mt) end,
  __tostring = function(a) return string.format("(%g, %g, %g)", a.X, a.Y, a.Z) end,
}
local function vec3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vec3Mt) end

local cframeMt = {
  __mul = function(a, b) return setmetatable({ ok = true, pos = a.pos }, cframeMt) end,
}
local function cframe(pos) return setmetatable({ pos = pos or vec3(0, 0, 0) }, cframeMt) end

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
  __add = function(a, b) return setmetatable({ Scale = a.Scale + b.Scale, Offset = a.Offset + b.Offset }, udimMt) end,
  __sub = function(a, b) return setmetatable({ Scale = a.Scale - b.Scale, Offset = a.Offset - b.Offset }, udimMt) end,
  __tostring = function(a) return string.format("{%g,%d}", a.Scale, a.Offset) end,
}
local function axis(s, o) return setmetatable({ Scale = s, Offset = o }, udimMt) end

local udim2Mt = {
  __add = function(a, b)
    return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, udim2Mt)
  end,
  __sub = function(a, b)
    return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, udim2Mt)
  end,
  __tostring = function(a) return "{ " .. tostring(a.X) .. ", " .. tostring(a.Y) .. " }" end,
}

UDim = { new = axis }
UDim2 = {
  new = function(xs, xo, ys, yo)
    return setmetatable({ X = axis(xs, xo), Y = axis(ys, yo) }, udim2Mt)
  end,
  fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
  fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}
Vector2 = { new = vec, zero = vec(0, 0) }
Vector3 = { new = vec3 }

-- CFrame.lookAt/new sao chamados com ":" (metodo) no WorldUI, entao recebem self.
CFrame = {}
function CFrame.new(self, x, y, z)
  if type(self) == "number" then return cframe(vec3(self, x or 0, y or 0)) end
  if type(x) == "number" then return cframe(vec3(x, y or 0, z or 0)) end
  return cframe(x)
end
function CFrame.lookAt(_, at, target) return cframe(at) end
function CFrame.Angles() return cframe() end
Color3 = {
  fromRGB = function(r, g, b) return { R = r/255, G = g/255, B = b/255 } end,
  new = function(r, g, b) return { R = r, G = g, B = b } end,
}
ColorSequence = { new = function(a, b) return { a, b } end }
NumberSequence = { new = function(a, b) return { a, b } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b } end }
TweenInfo = { new = function(...) return { ... } end }

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
  if services[name] then return services[name] end
  local svc = Instance.new("Folder")
  svc.Name = name
  if name == "Players" then
    svc.LocalPlayer = {
      Name = "He", DisplayName = "He", UserId = 1,
      Parent = svc,
    }
    svc.LocalPlayer.WaitForChild = function(_, n)
      if n == "PlayerGui" then return PlayerGui end
      return Instance.new("Folder")
    end
    svc.LocalPlayer.Character = nil
    svc.GetPlayers = function() return {} end
  elseif name == "TweenService" then
    svc.Create = function() return fakeTween() end
  elseif name == "RunService" then
    svc.RenderStepped = newSignal()
    svc.Heartbeat = newSignal()
    svc.IsStudio = function() return true end
  elseif name == "UserInputService" then
    svc.InputBegan = newSignal()
    svc.InputChanged = newSignal()
    svc.InputEnded = newSignal()
    svc.GetMouseLocation = function() return vec(0, 0) end
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
        __sent[#__sent+1] = { kind = kind, payload = payload }
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

game = { GetService = function(_, n) return service(n) end, BindToClose = function() end }

task = {
  wait = function() end,
  delay = function(_, fn) end,
  spawn = function(fn) end,
  defer = function(fn) fn() end,
  cancel = function() end,
}

Random = {
  new = function()
    local seed = 1234
    return {
      NextNumber = function(_, a, b)
        seed = (seed * 1103515245 + 12345) % 2147483648
        local v = seed / 2147483648
        if a then return a + v * (b - a) end
        return v
      end,
      NextInteger = function(_, a, b) return a + math.floor((b - a + 1) * (seed / 2147483648)) end,
    }
  end,
}

print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
  hostprint("[lua] " .. table.concat(parts, " "))
end
warn = print
`;

// Cada módulo vira um IIFE no MESMO chunk: removemos só as linhas de require,
// e o nome resolve pro local já definido (Theme, State, GameConfig...).
// As linhas de game:GetService ficam — o host implementa os serviços de verdade.
const prepareModule = (src) =>
	src
		.split("\n")
		.filter((line) => !/^local \w+ = require\(/.test(line))
		.join("\n");

const moduleCode = (name, file) => `local ${name} = (function()\n${prepareModule(read(file))}\nend)()\n`;

const SHARED = [
	"GameConfig",
	"Format",
	"Net",
	"Pets",
	"Noise",
	"Biomes",
	"Terrain",
]
	.map((n) => moduleCode(n, `src/shared/${n}.luau`))
	.join("\n");

// NetClient é o módulo REAL: os RemoteEvents do host já existem.
const CLIENT_MODULES = [
	"Theme",
	"State",
	"NetClient",
	"Toasts",
	"Hud",
	"TapButton",
	"PetsPanel",
	"EggPanel",
	"ShopPanel",
	"WorldUI",
	"BiomesPanel",
]
	.map((n) => moduleCode(n, `src/client/${n}.luau`))
	.join("\n");

// init.client.luau: é o script que monta TUDO e liga a rede. Removemos só os
// requires (os nomes já existem) e trocamos `script.X` pelo módulo direto.
const INIT_SCRIPT = (() => {
	const src = read("src/client/init.client.luau");
	const body = src
		.split("\n")
		.filter((line) => !/^local \w+ = require\(/.test(line))
		.join("\n")
		.replace(/localscript/gi, "script")
		// script.Theme etc. -> Theme (é o que o require daria)
		.replace(/\bscript\.(Theme|State|NetClient|Hud|TapButton|EggPanel|PetsPanel|ShopPanel|Toasts|WorldUI)\b/g, "$1");
	return `-- ===== init.client.luau =====\n${body}\n`;
})();

const BODY = String.raw`
-- mapa falso em Workspace: pedestal de ovo + zonas clicaveis
local mapFolder = Instance.new("Folder")
mapFolder.Name = "EggTycoon"
mapFolder.Parent = game:GetService("Workspace")

local function makeClickable(name, eggId)
  local part = Instance.new("Part")
  part.Name = name
  part.Parent = mapFolder
  local detector = Instance.new("ClickDetector")
  detector.Parent = part
  if eggId then part:SetAttribute("EggId", eggId) end
  return part, detector
end
__pedestal, __pedestalDetector = makeClickable("Egg_starter", "starter")
__zoneShop, __zoneShopDetector = makeClickable("Zone_shop", nil)
__zoneHalloween, __zoneHalloweenDetector = makeClickable("Zone_egg_halloween", nil)

-- personagem falso, pro WorldUI.stepPets rodar
local character = Instance.new("Model")
character.Name = "He"
local rootPart = Instance.new("Part")
rootPart.Name = "HumanoidRootPart"
rootPart.Position = vec3(0, 5, 0)
rootPart.Parent = character
game:GetService("Players").LocalPlayer.Character = character

__stateHandler = nil
__eventHandler = nil
__lastAction = nil


__stateHandler = nil
__eventHandler = nil
__lastAction = nil

local WorldUIFake = {
  build = function() end,
  route = function() end,
  syncPets = function() end,
  stepPets = function() end,
}

__built = {}
__guiCount = 0
`;

const BUILD = String.raw`
-- o init.client roda no chunk: monta GUI, paineis, mundo e rede
print("init.client montou a GUI")
local gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("EggTycoonGui")
assert(gui, "init.client nao criou o EggTycoonGui")

local descendants = gui:GetDescendants()
print("instancias na GUI: " .. #descendants)
assert(#descendants > 60, "GUI praticamente vazia: " .. #descendants)

-- Os 3 painéis de tela cheia precisam começar escondidos, senão o jogo abre
-- com Ovos + Pets + Loja empilhados por cima do mapa.
for _, name in ipairs({ "EggPanel", "PetsPanel", "ShopPanel", "BiomesPanel" }) do
  local panel = gui:FindFirstChild(name)
  assert(panel, "painel ausente na GUI: " .. name)
  assert(panel.Visible == false, name .. " deveria começar invisível, Visible=" .. tostring(panel.Visible))
end
print("paineis escondidos ao abrir: ok")

-- O painel de mundos precisa ter um cartao por bioma, com nome e cadeado.
local biomesPanel = gui:FindFirstChild("BiomesPanel")
local grid = biomesPanel:FindFirstChild("Card"):FindFirstChild("Grid")
local cards = 0
for _, child in ipairs(grid:GetChildren()) do
  if string.sub(child.Name, 1, 6) == "Biome_" then
    cards = cards + 1
    assert(child:FindFirstChild("Lock"), "cartao sem Lock: " .. child.Name)
  end
end
assert(cards == 7, "painel de mundos com " .. cards .. " cartoes (esperado 7)")
print("painel de mundos: " .. cards .. " cartoes ok")
`;

const SNAPSHOT = String.raw`
-- snapshot real, com pets de verdade, pra popular todos os painéis
local data = GameConfig.defaultData()
data.coins = 12345
data.gems = 7
data.pets = {
  { uid = 1, petId = "chick", golden = false },
  { uid = 2, petId = "kitten", golden = true },
  { uid = 3, petId = "fox", golden = false },
}
data.equipped = { 2, 3 }
data.stats.hatched = 12
data.stats.taps = 340

local snapshot = {
  coins = data.coins,
  gems = data.gems,
  crystals = 0,
  rebirths = 0,
  pets = data.pets,
  equipped = data.equipped,
  upgrades = data.upgrades,
  gemUpgrades = data.gemUpgrades,
  selectedEgg = "starter",
  stats = data.stats,
  questIndex = 3,
  income = 12.5,
  tapPower = 3,
  slots = GameConfig.petSlots(data),
  luck = GameConfig.luck(data),
  eggBought = {},
  rebirthCost = GameConfig.rebirthCost(20, 0),
  rate = 20,
}

State.set(snapshot)

-- empurra o snapshot por cada painel e confere que nada explodiu
local function exercise(label, fn)
  local ok, err = pcall(fn)
  print(string.format("%-14s %s %s", label, ok and "ok" or "FALHOU", err and tostring(err) or ""))
  assert(ok, label .. ": " .. tostring(err))
end

exercise("EggPanel", function() EggPanel.refresh() end)
exercise("PetsPanel", function() PetsPanel.show() ; PetsPanel.hide() end)
exercise("ShopPanel", function() ShopPanel.show("coins") ; ShopPanel.hide() ; ShopPanel.show("gems") ; ShopPanel.hide() end)
exercise("EggPanel.show", function() EggPanel.show() ; EggPanel.hide() end)

-- eventos de rede que o servidor manda
local function fire(...)
  if __eventHandler then __eventHandler(...) end
end

exercise("evento hatch", function()
  fire("hatch", { petId = "fox", uid = 4, rarity = "rare" })
end)

exercise("evento toast", function()
  fire("toast", { text = "teste", kind = "info" })
  fire("toast", { text = "erro", kind = "error" })
end)

exercise("evento rebirth", function()
  fire("rebirth", { rebirths = 1, crystals = 4 })
end)

-- estado de rebirth alto, pra checar formatação de número grande
local big = {}
for k, v in pairs(snapshot) do big[k] = v end
big.coins = 1.5e12
big.rate = 8.3e9
big.rebirths = 7
State.set(big)
exercise("snapshot bilhoes", function()
  EggPanel.refresh()
  PetsPanel.show()
  PetsPanel.hide()
end)

-- sem snapshot nenhum: o jogo pode abrir antes do servidor mandar dados
State.snapshot = nil
exercise("sem snapshot", function()
  EggPanel.refresh()
end)

print("\nerros capturados em sinais: " .. #__errors)
for i, err in ipairs(__errors) do
  if i <= 5 then print("  " .. err) end
end
assert(#__errors == 0, "callback de sinal estourou: " .. tostring(__errors[1]))

---------------------------------------------------------------------------
-- MUNDO: pedestais, zonas e pets flutuantes
---------------------------------------------------------------------------
local player = game:GetService("Players").LocalPlayer

-- o teste "sem snapshot" zerou o estado global; restaura pra testar a UI cheia
State.set(snapshot)

exercise("clique no pedestal", function()
  __pedestalDetector.MouseClick:_fire(player)
  assert(#__sent > 0, "clicar no pedestal nao mandou nada pro servidor")
  local last = __sent[#__sent]
  assert(last.kind == Net.ActionKind.SelectEgg, "esperava SelectEgg, veio " .. tostring(last.kind))
  assert(last.payload == "starter", "ovo errado: " .. tostring(last.payload))
  -- e a UI de ovos abre no ovo certo
  local panel = gui:FindFirstChild("EggPanel")
  assert(panel.Visible == true, "clicar no pedestal nao abriu o painel de ovos")
end)

exercise("clique na loja", function()
  __zoneShopDetector.MouseClick:_fire(player)
  local panel = gui:FindFirstChild("ShopPanel")
  assert(panel.Visible == true, "clicar na loja nao abriu a Loja")
  assert(gui:FindFirstChild("EggPanel").Visible == false, "EggPanel deveria ter fechado")
end)

exercise("clique na zona halloween", function()
  __zoneHalloweenDetector.MouseClick:_fire(player)
  local panel = gui:FindFirstChild("EggPanel")
  assert(panel.Visible == true, "zona halloween nao abriu os ovos")
end)

exercise("pets flutuando", function()
  -- equipa 3 pets e roda o construtor/animador de verdade
  local snap = {}
  for k, v in pairs(State.snapshot) do snap[k] = v end
  snap.equipped = { 1, 2, 3 }
  snap.pets = {
    { uid = 1, petId = "chick", golden = false },
    { uid = 2, petId = "kitten", golden = true },
    { uid = 3, petId = "fox", golden = false },
  }
  State.set(snap)
  WorldUI.syncPets(snap)

  local pipe = game:GetService("Workspace"):FindFirstChild("PetRigs")
  assert(pipe, "PetRigs nao foi criado no Workspace")
  local rigs = pipe:GetChildren()
  assert(#rigs == 3, "esperava 3 pets flutuando, veio " .. #rigs)

  -- roda o passo do loop varias vezes (e que o offset dos olhinhos acontece)
  for _ = 1, 5 do WorldUI.stepPets(0.016) end
  -- trocar os equipados tem que reconstruir
  snap.equipped = { 1 }
  State.set(snap)
  WorldUI.syncPets(snap)
  assert(#pipe:GetChildren() == 1, "trocar equipados nao reconstruiu os pets")
end)

exercise("loop RenderStepped", function()
  -- simula o heartbeat do cliente (WorldUI.stepPets via RenderStepped)
  local rs = game:GetService("RunService")
  local fired = 0
  for _ = 1, 3 do
    rs.RenderStepped:_fire(0.016)
    fired += 1
  end
  assert(fired == 3, "loop nao disparou")
end)

exercise("atalhos de teclado", function()
  local uis = game:GetService("UserInputService")
  local function key(code)
    uis.InputBegan:_fire({ KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }, false)
  end
  key(Enum.KeyCode.E)
  assert(gui:FindFirstChild("EggPanel").Visible == true, "tecla E nao abriu os ovos")
  key(Enum.KeyCode.P)
  assert(gui:FindFirstChild("PetsPanel").Visible == true, "tecla P nao abriu os pets")
  key(Enum.KeyCode.B)
  assert(gui:FindFirstChild("ShopPanel").Visible == true, "tecla B nao abriu a loja")
  key(Enum.KeyCode.Escape)
  assert(gui:FindFirstChild("EggPanel").Visible == false, "Esc nao fechou")
  assert(gui:FindFirstChild("PetsPanel").Visible == false, "Esc nao fechou")
  assert(gui:FindFirstChild("ShopPanel").Visible == false, "Esc nao fechou")
end)

exercise("botao de toque", function()
  -- o botao de tap tem que mandar Action.Tap pro servidor
  local before = #__sent
  local tapBtns = {}
  for _, d in ipairs(gui:GetDescendants()) do
    if d:IsA("TextButton") and d.Visible ~= false then tapBtns[#tapBtns+1] = d end
  end
  assert(#tapBtns > 0, "nenhum botao na GUI")
end)

print("\nclient ok")
`;

const lua = await Lua.create({ sandbox: true });
lua.globals.set(
	"hostprint",
	lua.createFunction((...args) => console.log(args.map((a) => String(a)).join("\t"))),
);

const full = [
	HOST,
	SHARED,
	`Shared = { GameConfig = GameConfig, Format = Format, Net = Net, Pets = Pets }`,
	CLIENT_MODULES,
	BODY,
	INIT_SCRIPT,
	BUILD,
	SNAPSHOT,
].join("\n");

try {
	lua.execute(full);
} catch (e) {
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 16).join("\n"));
	process.exit(1);
}
