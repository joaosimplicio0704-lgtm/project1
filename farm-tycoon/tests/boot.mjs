// boot.mjs — sobe o SERVIDOR inteiro (init.server + todos os modulos) num host fake,
// simula 2 jogadores entrando, roda 8 minutos de jogo e verifica que nada explode.
// Uso: node tests/boot.mjs
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

// Remove apenas as linhas que pegam services do DataModel; o resto roda igual.
const stripServices = (src) =>
	src
		.split("\n")
		.filter((line) => !/^local \w+ = game:GetService\(/.test(line))
		.join("\n");

const stripRequire = (src) =>
	src
		.split("\n")
		.filter((line) => !/^local \w+ = require\(/.test(line))
		.filter((line) => !/^local Shared = /.test(line))
		.join("\n");

const mod = (name, file) =>
	`local ${name} = (function()\n${stripRequire(stripServices(read(file)))}\nend)()\n`;

const HOST = String.raw`
local __logs = {}
local __remoteLog = {}

-- game:GetService("Players") foi removido do modulo; o global assume.
-- player.Parent tem que ser ESTE table: Economy checa player.Parent == Players.
Players = {}


Color3 = {
  fromRGB = function(r,g,b) return {r=r,g=g,b=b, Lerp=function(self) return self end} end,
}
Vector3 = { new = function(x,y,z) return {X=x,Y=y,Z=z} end }
CFrame = { new = function() return {} end }
UDim2 = {}
Instance = { new = function() error("server nao deveria criar Instances neste harness") end }

-- LCG deterministico no lugar de Random.new
Random = {
  new = function()
    local seed = 987654321
    return {
      NextNumber = function()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
      end,
      NextInteger = function(self, a, b)
        return a + math.floor(self:NextNumber() * (b - a + 1))
      end,
    }
  end,
}

print = function(...) 
  local parts = {}
  for i=1,select("#",...) do parts[#parts+1] = tostring(select(i,...)) end
  local line = table.concat(parts, " ")
  __logs[#__logs+1] = line
  hostprint(line)
end

local function newRemote(name)
  return {
    Name = name,
    FireClient = function(self, player, kind, payload)
      __remoteLog[#__remoteLog+1] = { player = player.Name, kind = kind, payload = payload }
    end,
    FireServer = function() end,
    OnServerEvent = { Connect = function(self, fn) self._fn = fn end },
    OnClientEvent = { Connect = function() end },
  }
end
local __remoteFns = {}
local __remoteSet = {
  state = newRemote("State"),
  action = newRemote("Action"),
  event = newRemote("Event"),
}
`;

const BODY = [
	mod("GameConfig", "src/shared/GameConfig.luau"),
	mod("Format", "src/shared/Format.luau"),
	mod("Net", "src/shared/Net.luau"),
	// World/Remotes/Sessions/PlayerData: substituidos por versoes fake minimas
	String.raw`
local World = {
  buildEnvironment = function() end,
  buildLot = function(index, userId, name)
    return { index = index, origin = { X = index * 100, Y = 0, Z = 0 }, plots = {} }
  end,
  freeLot = function() return 1 end,
  releaseLot = function() end,
  getLot = function(i) return { origin = { X = 0, Y = 0, Z = 0 }, sellPad = { Color = Color3.fromRGB(0,0,0) }, statusLabel = { Text = "" } } end,
  refreshLot = function() end,
}
local Remotes = { setup = function() return __remoteSet end }
local PlayerData = {
  start = function() end,
  load = function(userId) return GameConfig.defaultData() end,
  release = function() end,
  markDirty = function() end,
  save = function() end,
}
`,
	mod("Sessions", "src/server/Sessions.luau"),
	mod("Farm", "src/server/Farm.luau"),
	mod("Economy", "src/server/Economy.luau"),
	`Economy.init(__remoteSet)`,
	// harness: cria jogadores, roda ticks
	String.raw`
local sessions = Sessions.byPlayer
-- NAO declarar local Players aqui: sombrearia o global que Economy compara.
Players.PlayerAdded = { Connect = function() end }
Players.PlayerRemoving = { Connect = function() end }
Players.GetPlayers = function() return {} end

local function makePlayer(name, id)
  return setmetatable({ Name = name, UserId = id, DisplayName = name, Parent = Players }, {
    __index = function() return { WaitForChild = function() return nil end } end,
  })
end

local p1 = makePlayer("He", 1)
local p2 = makePlayer("Visitor", 2)

for _, entry in ipairs({ { p1, 1 }, { p2, 2 } }) do
  local player, lot = entry[1], entry[2]
  local data = PlayerData.load(player.UserId)
  sessions[player] = {
    player = player,
    data = data,
    farm = Farm.new(data),
    lotIndex = lot,
    plantTimer = 0,
    saleBuffer = 0,
  }
end

-- roda 8 minutos de jogo a 10 Hz
local dbg = sessions[p1]
local dt = 0.1
local steps = 8 * 60 * 10
local t = 0
for i = 1, steps do
  Economy.tick(dt)
  t += dt
  if i % 600 == 0 then
    local s = sessions[p1]
    local onBelt = 0
    for _ in pairs(s.farm.items) do onBelt += 1 end
    print(string.format("t=%s nivel=%d cash=%s plots=%d esteira=%d itens",
      Format.time(t), s.data.level, Format.money(s.data.cash), s.data.plots, onBelt))
  end
end

local s = sessions[p1]
print("--- resultado ---")
print("nivel: " .. s.data.level)
print("cash: " .. Format.money(s.data.cash))
print("colheitas: " .. s.data.stats.harvests)
print("eventos remotos: " .. #__remoteLog)
print("logs do servidor: " .. #__logs)

assert(s.data.stats.harvests > 50, "sem colheitas, o loop nao esta rodando")
assert(s.data.level > 3, "progressao travada no nivel " .. s.data.level)
assert(#__remoteLog > 100, "cliente nao recebeu snapshots")

-- o teste tem que pegar o bug classico: cultura madura sem ir pra esteira
local first = sessions[p1].farm.plots[1]
assert(first == nil or first.progress < 1, "cultura travou madura na terra sem colher")

-- compras
local ok = Economy.buyPlot(p1)
print("comprou terreno 5: " .. tostring(ok) .. " (plots=" .. s.data.plots .. ")")
Economy.buyUpgrade(p1, "conveyor")
print("upgrade esteira: " .. s.data.upgrades.conveyor)
local okCode = Economy.redeemCode(p1, " FARMSTART ")
print("codigo normalizado: " .. tostring(okCode))
local dup = Economy.redeemCode(p1, "FARMSTART")
print("codigo duplicado bloqueado: " .. tostring(dup == false))

print("\nboot ok")
`,
].join("\n");

const lua = await Lua.create({ sandbox: true });
lua.globals.set(
	"hostprint",
	lua.createFunction((...args) => console.log(args.map((a) => String(a)).join("\t"))),
);

try {
	lua.execute(HOST + BODY);
} catch (e) {
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 12).join("\n"));
	process.exit(1);
}
