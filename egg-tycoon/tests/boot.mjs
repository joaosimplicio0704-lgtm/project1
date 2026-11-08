// boot.mjs — sobe o SERVIDOR inteiro do Egg Tycoon num host fake:
// init.server + World + Game + Pets, 2 jogadores, 10 minutos de jogo.
// Pega erro que só aparece em runtime (require faltando, campo nil, loop travado).
// Uso: node tests/boot.mjs
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

// Tira só as linhas que pegam service do DataModel e os require de módulo.
const prepare = (src) =>
	src
		.split("\n")
		.filter((line) => !/^local \w+ = game:GetService\(/.test(line))
		.filter((line) => !/^local Shared = /.test(line))
		.filter(
			(line) =>
				!/^local (Sessions|PlayerData|World|Remotes|Game|Net|GameConfig|Pets|Format) = require\(/.test(line),
		)
		.join("\n");

const mod = (name, file) => `local ${name} = (function()\n${prepare(read(file))}\nend)()\n`;

const HOST = String.raw`
local __logs = {}
local __remoteLog = {}

Color3 = {
  fromRGB = function(r,g,b) return {r=r,g=g,b=b} end,
}
Vector3 = {
  new = function(x,y,z) return {X=x,Y=y,Z=z} end,
}
CFrame = { new = function() return {} end }
Enum = { Material = {}, SurfaceType = {}, PartType = {} }

Random = {
  new = function()
    local seed = 424242
    return {
      NextNumber = function(self, a, b)
        seed = (seed * 1103515245 + 12345) % 2147483648
        local v = seed / 2147483648
        if a then return a + v * (b - a) end
        return v
      end,
      NextInteger = function(self, a, b)
        return a + math.floor(self:NextNumber() * (b - a + 1))
      end,
    }
  end,
}

Players = {}
Instance = { new = function() error("servidor nao deveria criar Instance aqui") end }

print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
  local line = table.concat(parts, " ")
  __logs[#__logs+1] = line
  hostprint(line)
end

local function newRemote(name)
  return {
    Name = name,
    FireClient = function(self, player, kind, payload)
      __remoteLog[#__remoteLog+1] = { kind = kind, payload = payload }
    end,
    FireServer = function() end,
    OnServerEvent = { Connect = function() end },
    OnClientEvent = { Connect = function() end },
  }
end
__remoteSet = { state = newRemote("State"), action = newRemote("Action"), event = newRemote("Event") }
`;

const BODY = [
	mod("GameConfig", "src/shared/GameConfig.luau"),
	mod("Format", "src/shared/Format.luau"),
	mod("Net", "src/shared/Net.luau"),
	mod("Pets", "src/shared/Pets.luau"),
	`local Sessions = { byPlayer = {} }
function Sessions.get(p) return Sessions.byPlayer[p] end
function Sessions.all() return Sessions.byPlayer end`,
	`local PlayerData = {
  start = function() end,
  load = function() return GameConfig.defaultData() end,
  release = function() end,
  markDirty = function() end,
  save = function() end,
}`,
	mod("Game", "src/server/Game.luau"),
	String.raw`
Game.init(__remoteSet)

local function makePlayer(name, id)
  return { Name = name, UserId = id, DisplayName = name, Parent = Players }
end

local p1 = makePlayer("He", 1)
local p2 = makePlayer("Visitor", 2)

for _, player in ipairs({ p1, p2 }) do
  local data = PlayerData.load(player.UserId)
  Sessions.byPlayer[player] = {
    player = player,
    data = data,
    tapWindow = {},
  }
  Pets.autoEquip(data)
end

-- forja um save ja com pets, pra exercitar renda/equipar
local s1 = Sessions.byPlayer[p1]
for i = 1, 12 do
  Pets.add(s1.data, "chick", false)
end
Pets.autoEquip(s1.data)

print(string.format("slots=%d equipados=%d renda/s=%s tap=%s",
  GameConfig.petSlots(s1.data), #s1.data.equipped,
  Format.number(Pets.income(s1.data)), Format.number(GameConfig.tapPower(s1.data))))

-- roda 10 minutos a 4 Hz (o tick real do servidor)
local dt = 0.25
local steps = 10 * 60 * 4
for i = 1, steps do
  Game.tick(dt)
end

local d = s1.data
print("--- resultado 10 min ---")
print("moedas: " .. Format.number(d.coins))
print("renda/s: " .. Format.number(Pets.income(d)))
print("pets: " .. #d.pets .. "  equipados: " .. #d.equipped)
print("quest index: " .. d.questIndex)
print("eventos remotos: " .. #__remoteLog)

assert(d.coins > 100, "renda passiva nao somou")
-- a quest 1 e "toque 10 vezes": renda passiva nao avanca quest de toque,
-- entao o avanco e testado depois de chamar o handler de tap.
print("quest antes do tap: " .. d.questIndex)

-- acoes do jogador
local function act(kind, payload)
  local ok, err = Game.handle(s1, kind, payload)
  return ok, err
end

s1.data.coins = 1e9
local A = Net.ActionKind

for _ = 1, 12 do act(A.Tap, 1) end
print("quest depois de 12 taps: " .. s1.data.questIndex)
assert(s1.data.questIndex > 1, "handler de tap nao avancou a quest")

local okHatch, errHatch = act(A.Hatch)
print("hatch: " .. tostring(okHatch) .. " " .. tostring(errHatch or ""))
assert(okHatch, "hatch falhou: " .. tostring(errHatch))
assert(#s1.data.pets >= 13, "pet nao entrou no inventario")

local okUp, errUp = act(A.BuyUpgrade, "tap")
print("upgrade tap: " .. tostring(okUp) .. " " .. tostring(errUp or ""))

local okSlot, errSlot = act(A.BuyUpgrade, "slots")
print("upgrade slots: " .. tostring(okSlot) .. " " .. tostring(errSlot or ""))

local okEq, errEq = act(A.Equip, s1.data.pets[#s1.data.pets].uid)
print("equipar: " .. tostring(okEq) .. " " .. tostring(errEq or ""))

local okGold, errGold = act(A.Golden)
print("dourado: " .. tostring(okGold) .. " " .. tostring(errGold or ""))

local okSell, errSell = act(A.SellPet, s1.data.pets[1].uid)
print("vender: " .. tostring(okSell) .. " " .. tostring(errSell or ""))

-- fusao precisa de 3 iguais nao equipados
local ids = {}
for _, inst in ipairs(s1.data.pets) do
  if #ids < 3 then ids[#ids+1] = inst.uid end
end
local okFuse, errFuse = act(A.Fuse, ids)
print("fusao: " .. tostring(okFuse) .. " " .. tostring(errFuse or ""))

-- rebirth
s1.data.coins = 1e15
local okR, errR = act(A.Rebirth)
print("rebirth: " .. tostring(okR) .. " " .. tostring(errR or ""))
assert(okR, "rebirth falhou: " .. tostring(errR))
print("rebirths agora: " .. s1.data.rebirths .. "  pets mantidos: " .. #s1.data.pets)
assert(#s1.data.pets > 0, "rebirth apagou a colecao de pets")
assert(s1.data.rebirths == 1, "rebirth nao incrementou")
assert(s1.data.upgrades.tap == 0, "rebirth nao resetou upgrades de moeda")

-- depois do rebirth o jogo tem que continuar jogavel: renda volta a somar
local before = s1.data.coins
for _ = 1, 40 do Game.tick(0.25) end
assert(s1.data.coins > before, "renda parou depois do rebirth")
print("renda pos-rebirth: +" .. Format.number(s1.data.coins - before))

-- o snapshot que vai pro cliente tem que serializar sem campo quebrado
local snap = Game.snapshot(s1)
local required = { "coins","gems","crystals","rebirths","pets","equipped","upgrades","gemUpgrades","selectedEgg","stats","questIndex","income","tapPower","slots","luck","rate","rebirthCost" }
for _, key in ipairs(required) do
  assert(snap[key] ~= nil, "snapshot sem campo: " .. key)
end
assert(type(snap.coins) == "number", "coins nao numerico")
assert(type(snap.rebirthCost) == "number", "rebirthCost nao numerico")

local static = Game.staticState()
assert(#static.eggs == #GameConfig.Eggs, "staticState nao mandou todos os ovos")
assert(#static.pets > 0, "staticState sem pets")

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
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 14).join("\n"));
	process.exit(1);
}
