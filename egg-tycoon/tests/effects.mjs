// effects.mjs — prova que a mecânica DEIXA RASTRO NO MUNDO.
//
// O usuário reclamou: "mecânica horrível, até agora não vi nenhuma". A
// mecânica existia, mas só mudava número de painel. Este teste dirige o
// servidor de verdade (Game + Effects) num host fake e conta quantas peças
// cada ação criou no Workspace.
//
// Se alguém quebrar o gancho (renomear Game.fx, tirar Effects.init, etc.),
// este teste falha antes de abrir no Studio.
//
// Uso: node tests/effects.mjs

import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const HOST = String.raw`
local __created = {}
local __logs = {}

function print(...)
  local parts = {}
  for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
  __logs[#__logs + 1] = table.concat(parts, " ")
end

-- Vector3 minimo
local V3 = {}
local function g(v, k) if type(v) ~= "table" then return 0 end return v[k] or 0 end
V3.__add = function(a, b) return setmetatable({ X = g(a,"X") + g(b,"X"), Y = g(a,"Y") + g(b,"Y"), Z = g(a,"Z") + g(b,"Z") }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = g(a,"X") - g(b,"X"), Y = g(a,"Y") - g(b,"Y"), Z = g(a,"Z") - g(b,"Z") }, V3) end
V3.__mul = function(a, n)
  if type(n) == "table" then
    return setmetatable({ X = g(a,"X") * g(n,"X"), Y = g(a,"Y") * g(n,"Y"), Z = g(a,"Z") * g(n,"Z") }, V3)
  end
  return setmetatable({ X = g(a,"X") * n, Y = g(a,"Y") * n, Z = g(a,"Z") * n }, V3)
end
V3.__tostring = function(a) return g(a,"X") .. ", " .. g(a,"Y") .. ", " .. g(a,"Z") end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }

local UD = {}
UD.__add = function(a, b) return a end
UDim = { new = function(s, o) return setmetatable({ Scale = s, Offset = o }, UD) end }
UDim2 = {
  new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end,
  fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
  fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}
Color3 = {
  fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
  new = function(r, g, b) return { R = r, G = g, B = b } end,
}
local cfMt = {}
cfMt.__mul = function(a, b)
  -- CFrame * CFrame: soma de posicoes basta para os efeitos
  local bp = (type(b) == "table" and b.pos) or Vector3.new(0, 0, 0)
  return setmetatable({ pos = a.pos + bp }, cfMt)
end
local function newCF(pos) return setmetatable({ pos = pos or Vector3.new(0, 0, 0) }, cfMt) end
CFrame = {
  new = function(x, y, z)
    if type(x) == "table" then
      if x.pos then return newCF(x.pos) end
      return newCF(x)
    end
    return newCF(Vector3.new(x or 0, y or 0, z or 0))
  end,
  Angles = function() return newCF(Vector3.new(0, 0, 0)) end,
}

TweenInfo = { new = function(...) return { ... } end }
TweenService = {
  -- chamado com ":" no Effects, entao self vem primeiro
  Create = function(self, part, info, goal)
    return { Play = function() end }
  end,
}
Debris = { AddItem = function() end }
RunService = { Heartbeat = { Connect = function() return { Disconnect = function() end } end } }
task = {
  spawn = function(fn, ...) local ok, err = pcall(fn, ...) if not ok then __logs[#__logs + 1] = "task erro: " .. tostring(err) end end,
  delay = function(_, fn) pcall(fn) end,
  wait = function() return 0.05 end,
}

local function makeEnum()
  return setmetatable({}, {
    __index = function(t, k)
      local v = { Name = k, Value = k }
      rawset(t, k, v)
      return v
    end,
  })
end
Enum = setmetatable({}, {
  __index = function(t, group)
    local g = makeEnum()
    rawset(t, group, g)
    return g
  end,
})

local function newSignal()
  local s = { listeners = {} }
  function s:Connect(fn) self.listeners[#self.listeners + 1] = fn; return { Disconnect = function() end } end
  function s:Fire(...) for _, fn in ipairs(self.listeners) do pcall(fn, ...) end end
  return s
end

local __instanceMt = {}
__instanceMt.__index = function(self, key)
  local props = rawget(self, "__props")
  if props[key] ~= nil then return props[key] end
  local kids = rawget(self, "__children")
  if key == "GetChildren" then return function() return kids end end
  if key == "FindFirstChild" then return function(_, n) for _, c in ipairs(kids) do if c.Name == n then return c end end end end
  if key == "Destroy" then return function()
    __created[#__created + 1] = "destroy:" .. tostring(rawget(self, "__props").Name)
  end end
  if key == "IsA" then return function() return false end end
  if key == "SetAttribute" then return function() end end
  if key == "GetAttribute" then return function() return nil end end
  return nil
end
__instanceMt.__newindex = function(self, key, value)
  local props = rawget(self, "__props")
  props[key] = value
end

Instance = {
  new = function(class)
    local obj = setmetatable({}, __instanceMt)
    local props = { ClassName = class, Name = class }
    rawset(obj, "__props", props)
    rawset(obj, "__children", {})
    __created[#__created + 1] = class
    return obj
  end,
}

-- getService tem que devolver o SERVICO certo: o Effects faz
-- local TweenService = game:GetService("TweenService"), que sombreia o
-- global. Devolver Folder jogava o TweenService falso fora.
game = {
  GetService = function(_, name)
    if name == "TweenService" then return TweenService end
    if name == "Debris" then return Debris end
    if name == "RunService" then return RunService end
    return Instance.new("Folder")
  end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
`;

const BODY = [
	`local Effects = (function()
${read("src/server/Effects.luau")}
end)()`,
	`local Colors = { common = Color3.fromRGB(200,200,200), secret = Color3.fromRGB(255,100,200) }`,
	String.raw`
local fails = {}
local function check(name, cond, detail)
  if not cond then fails[#fails + 1] = name .. (detail and (" — " .. detail) or "") end
end

-- conta quantos itens de um tipo a acao criou
local function countSince(mark, class)
  local n = 0
  for i = mark + 1, #__created do
    if __created[i] == class then n = n + 1 end
  end
  return n
end

Effects.init(workspace)

--- tap: 1 clique deve soltar moeda + anel
local mark = #__created
local okA, errA = pcall(Effects.coinBurst, Vector3.new(0, 5, 0), Colors.common, 3)
if not okA then __hot = "coinBurst: " .. tostring(errA) end
check("tap solta moedas", countSince(mark, "Part") >= 3, __hot or tostring(countSince(mark, "Part")))

mark = #__created
Effects.shockwave(Vector3.new(0, 5, 0), Colors.common, 12)
check("tap tem anel", countSince(mark, "Part") >= 1)

--- chocar ovo
mark = #__created
Effects.hatchBurst(Vector3.new(0, 5, 0), Colors.common, false)
local normalHatch = countSince(mark, "Part")
check("chocar cria efeito", normalHatch >= 25, tostring(normalHatch))

mark = #__created
Effects.hatchBurst(Vector3.new(0, 5, 0), Colors.secret, true)
local secretHatch = countSince(mark, "Part")
check("secreto e maior que comum", secretHatch > normalHatch,
  secretHatch .. " <= " .. normalHatch)

--- rebirth: anel gigante
mark = #__created
Effects.rebirthWave(Vector3.new(0, 5, 0))
check("rebirth tem onda", countSince(mark, "Part") >= 20, tostring(countSince(mark, "Part")))

--- pet orbitando
local fakePlayer = { Name = "He" }
Effects.setOrbit(fakePlayer, {
  { color = Colors.common, name = "Bolinha" },
  { color = Colors.secret, name = "Arco" },
})
mark = #__created
-- step sem personagem nao deve explodir
Effects.step(0.05)
check("orbit sem personagem nao quebra", true)

-- com personagem
local root = Instance.new("Part")
root.Position = Vector3.new(0, 5, 0)
fakePlayer.Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end }
Effects.step(0.05)
check("orbit cria pets no mundo", countSince(mark, "Part") >= 4, tostring(countSince(mark, "Part")))

mark = #__created
Effects.step(0.05)
check("orbit nao recria toda hora", countSince(mark, "Part") == 0, tostring(countSince(mark, "Part")))

Effects.removePlayer(fakePlayer)
check("remover jogador limpa orbit", true)

--- floatText tem que criar BillboardGui (aparece no mapa, nao em painel)
mark = #__created
Effects.floatText(Vector3.new(0, 5, 0), "NIVEL 2", Colors.common, 20)
check("level up tem texto no mundo", countSince(mark, "BillboardGui") >= 1)

__effectsFails = fails
__effectsHot = __hot
__effectCount = #__created
`,
];

const lua = await Lua.create({ sandbox: true });
lua.globals.set("HOST", HOST);
const chunk = `${HOST}\n${BODY.join("\n")}\n`;

const globals = lua.globals;
try {
	lua.execute(chunk);
} catch (err) {
	console.error("erro de execucao:", err.message);
	const lines = chunk.split("\n");
	const m = /compiler\.rs:\d+:(\d+)/.exec(err.message);
	console.error("trecho:", lines.slice(0, 3).join(" | "));
	// despeja as ultimas linhas para achar onde parou
	console.error("total linhas:", lines.length);
	const n = Number(m[1]);
	console.error("LINHA " + n + ": " + (lines[n - 1] || "?"));
	console.error("ctx:", lines.slice(Math.max(0, n - 3), n + 2).map((l, i) => (n - 2 + i) + ": " + l).join("\n"));
	process.exit(1);
}

const fails = globals.get("__effectsFails");
const list = fails ? fails.entries().map(([k, v]) => `${k}=${v}`) : [];
const problems = [];
for (const item of list) {
	problems.push(item);
}

const created = Number(globals.get("__effectCount") ?? 0);

if (problems.length > 0) {
	console.log(`effects FALHOU (${problems.length})`);
	for (const p of problems) console.log("  -", p);
	process.exit(1);
}

console.log(`effects ok — mecanica deixa rastro visivel (${created} objetos criados)`);
