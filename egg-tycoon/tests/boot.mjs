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
				!/^local (Sessions|PlayerData|World|Remotes|Game|Effects|Net|GameConfig|Pets|Format|Mine|MineServer) = require\(/.test(line),
		)
		.join("\n");

const mod = (name, file) => `local ${name} = (function()\n${prepare(read(file))}\nend)()\n`;

const HOST = String.raw`
local __logs = {}
local __remoteLog = {}

Color3 = {
  fromRGB = function(r,g,b) return {r=r,g=g,b=b} end,
}
local V3 = {}
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3) end
V3.__mul = function(a, n) return setmetatable({ X = a.X * n, Y = a.Y * n, Z = a.Z * n }, V3) end
V3.__index = function(v, key)
  if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
  if key == "Unit" then
    local m = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
    if m == 0 then return setmetatable({ X = 0, Y = 0, Z = 0 }, V3) end
    return setmetatable({ X = v.X/m, Y = v.Y/m, Z = v.Z/m }, V3)
  end
  return nil
end
Vector3 = {
  new = function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V3) end,
}
local cfMt = {}
cfMt.__mul = function(a, b) return setmetatable({ pos = (a.pos or {X=0,Y=0,Z=0}) }, cfMt) end
CFrame = {
  new = function(x, y, z)
    if type(x) == "table" then return setmetatable({ pos = x.pos or x }, cfMt) end
    return setmetatable({ pos = Vector3.new(x or 0, y or 0, z or 0) }, cfMt)
  end,
  Angles = function() return setmetatable({ pos = Vector3.new(0,0,0) }, cfMt) end,
}
-- Enum generico: qualquer grupo devolve um valor com Name
Enum = setmetatable({}, {
  __index = function(t, group)
    local g = setmetatable({}, { __index = function(tt, k)
      local v = { Name = k }
      rawset(tt, k, v)
      return v
    end })
    rawset(t, group, g)
    return g
  end,
})

-- Servicos usados pelo Effects. Precisam existir ANTES do modulo ser lido.
TweenInfo = { new = function(...) return { ... } end }
TweenService = {
  Create = function(self, part, info, goal) return { Play = function() end } end,
}
Debris = { AddItem = function() end }
RunService = { Heartbeat = { Connect = function() return { Disconnect = function() end } end } }
UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end }

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

-- Instance minimalista o suficiente para o Effects rodar. Antes este host
-- dava error() de proposito ("servidor nao deveria criar Instance aqui"),
-- o que impedia testar qualquer coisa que fabrique objeto no mundo.
local __imt = {}
__imt.__index = function(self, key)
  local props = rawget(self, "__props")
  if props[key] ~= nil then return props[key] end
  local kids = rawget(self, "__children")
  if key == "GetChildren" then return function() return kids end end
  if key == "FindFirstChild" then
    return function(_, n)
      for _, c in ipairs(kids) do if c.Name == n then return c end end
      return nil
    end
  end
  if key == "Destroy" then return function() end end
  if key == "SetAttribute" then return function() end end
  if key == "GetAttribute" then return function() return nil end end
  if key == "IsA" then return function() return false end end
  return nil
end
__imt.__newindex = function(self, key, value)
  rawget(self, "__props")[key] = value
end
Instance = {
  new = function(class)
    local o = setmetatable({}, __imt)
    rawset(o, "__props", { ClassName = class, Name = class })
    rawset(o, "__children", {})
    return o
  end,
}
workspace = Instance.new("Folder")
workspace.Name = "Workspace"
game = {
  GetService = function(_, name)
    if name == "TweenService" then return TweenService end
    if name == "Debris" then return Debris end
    if name == "RunService" then return RunService end
    return Instance.new("Folder")
  end,
}

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
	mod("Biomes", "src/shared/Biomes.luau"),
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
	mod("Mine", "src/shared/Mine.luau"),
	`local MineServer = {
  init = function() end,
  sync = function() end,
  forget = function() end,
  rate = function() return 0 end,
  snapshot = function() return { trips = {}, ores = {}, best = "", dug = 0, tripSeconds = 7 } end,
  collect = function() return {}, 0 end,
  rush = function() return false, "stub" end,
}`,
	mod("Game", "src/server/Game.luau"),
	mod("Effects", "src/server/Effects.luau"),
	String.raw`
-- Wiring dos efeitos, igual ao init.server. O boot antigo montava os modulos
-- na mao e NUNCA passava por isto: um gancho quebrado (Game.fx.tap virando
-- nil) passava batido. Agora qualquer acao que chame os ganchos exercita o
-- caminho real.
Effects.init(workspace)
local __fxCalls = { tap = 0, hatch = 0, equip = 0, upgrade = 0, rebirth = 0 }
Game.fx.tap = function() __fxCalls.tap += 1 end
Game.fx.hatch = function() __fxCalls.hatch += 1 end
Game.fx.equip = function() __fxCalls.equip += 1 end
Game.fx.upgrade = function() __fxCalls.upgrade += 1 end
Game.fx.rebirth = function() __fxCalls.rebirth += 1 end
Game.fx.mine = function() __fxCalls.mine = (__fxCalls.mine or 0) + 1 end

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

-- VIAGEM ENTRE BIOMAS
-- s2 é um jogador novo (0 rebirths): os mundos de rebirth tem que fechar.
-- Não existe player2 real: forjamos o mínimo que o handler usa (Name).
local fakePlayer = { Name = "Novato", UserId = 999 }
local s2 = { player = fakePlayer, data = GameConfig.defaultData(), dirty = false, tapWindow = {}, lastSnapshot = 0 }
s2.data = GameConfig.defaultData()
s2.data.stats.hatched = 0
s2.data.rebirths = 0
s2.data.biome = "meadow"

local arrived = nil
Game.arrivalFor = function(session, biomeId) arrived = session.player.Name .. "->" .. biomeId end

local okMeadow = Game.handle(s2, A.Travel, "meadow")
print("travel meadow: " .. tostring(okMeadow))
assert(okMeadow, "bioma livre deveria ser acessivel")

local okIce, errIce = Game.handle(s2, A.Travel, "ice")
print("travel ice (bloqueado): " .. tostring(okIce) .. " " .. tostring(errIce or ""))
assert(not okIce, "jogador com 0 rebirths NAO pode entrar no gelo")
assert(errIce and string.find(errIce, "Renascimento"), "erro de bloqueio sem requisito: " .. tostring(errIce))

local okBad, errBad = Game.handle(s2, A.Travel, "nao_existe")
assert(not okBad and errBad, "bioma inexistente deveria falhar")

-- com rebirths, o gelo abre de verdade
s2.data.rebirths = 2
local okIce2 = Game.handle(s2, A.Travel, "ice")
print("travel ice (liberado): " .. tostring(okIce2) .. " bioma atual: " .. tostring(s2.data.biome))
assert(okIce2, "rebirth 2 deveria abrir o gelo")
assert(s2.data.biome == "ice", "bioma atual nao mudou")
assert(arrived ~= nil, "arrivalFor nao foi chamado — o jogador nao seria teleportado")

-- o snapshot precisa carregar o bioma atual e o mapa de desbloqueio
local snapTravel = Game.snapshot(s2)
assert(snapTravel.biome == "ice", "snapshot com bioma errado")
assert(snapTravel.biomes and snapTravel.biomes.meadow == true, "snapshot sem mapa de desbloqueio")

-- o snapshot que vai pro cliente tem que serializar sem campo quebrado
local snap = Game.snapshot(s1)
local required = { "coins","gems","crystals","rebirths","pets","equipped","upgrades","gemUpgrades","selectedEgg","stats","questIndex","income","tapPower","slots","luck","rate","rebirthCost","biome","biomes" }
for _, key in ipairs(required) do
  assert(snap[key] ~= nil, "snapshot sem campo: " .. key)
end
assert(type(snap.coins) == "number", "coins nao numerico")
assert(type(snap.rebirthCost) == "number", "rebirthCost nao numerico")

local static = Game.staticState()
assert(#static.eggs == #GameConfig.Eggs, "staticState nao mandou todos os ovos")
assert(#static.pets > 0, "staticState sem pets")

-- ---------------------------------------------------------------------------
-- GANCHOS DE FEEDBACK
-- Cada acao do jogador tem que chamar o gancho correspondente. Sem isto a
-- mecanica roda mas o mundo fica mudo: foi exatamente a reclamacao do
-- usuario ("ate agora nao vi mecanica nenhuma").
-- ---------------------------------------------------------------------------
s1.data.coins = 1e9
act(A.Tap, 1)
act(A.Hatch, nil)
-- precisa ser um pet NAO equipado: Pets.equip devolve "ja equipado" e nao
-- dispara o gancho. Escolhe o primeiro fora da lista.
local freeUid = nil
for _, pet in ipairs(s1.data.pets) do
  local taken = false
  for _, uid in ipairs(s1.data.equipped) do
    if uid == pet.uid then taken = true end
  end
  if not taken then freeUid = pet.uid break end
end
if not freeUid then
  -- todos equipados pelo autoEquip: cria um sobrando para exercitar o gancho
  local extra = Pets.add(s1.data, "chick", false)
  freeUid = extra and extra.uid
end
assert(freeUid, "nao consegui preparar um pet para equipar")

-- Slots cheios e o caso normal (autoEquip preenche tudo ao entrar), entao
-- "equipar" um pet sobrando falha por design. O caminho que SEMPRE passa e
-- desequipar: tira um e o gancho roda. Depois equipa de volta.
local equippedUid = s1.data.equipped[1]
act(A.Unequip, equippedUid)
assert(#s1.data.equipped < GameConfig.petSlots(s1.data), "unequip nao liberou slot")
act(A.Equip, freeUid)
act(A.BuyUpgrade, "tap")

print(string.format("ganchos: tap=%d hatch=%d equip=%d upgrade=%d",
  __fxCalls.tap, __fxCalls.hatch, __fxCalls.equip, __fxCalls.upgrade))

assert(__fxCalls.tap > 0, "tap nao disparou efeito no mundo")
assert(__fxCalls.hatch > 0, "chocar ovo nao disparou efeito no mundo")
assert(__fxCalls.upgrade > 0, "upgrade nao disparou efeito no mundo")
assert(__fxCalls.equip > 0, "equipar pet nao disparou efeito no mundo")

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
