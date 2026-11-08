// simulate.mjs — joga 8h usando o GameConfig REAL do jogo (sem duplicar números).
// Simula um jogador que toca 3x/s, abre o melhor ovo disponível e compra slots.
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const SHIM = `
Color3 = { fromRGB = function(r,g,b) return {r=r,g=g,b=b} end, new = function(r,g,b) return {r=r,g=g,b=b} end }
Vector3 = { new = function(x,y,z) return {X=x,Y=y,Z=z} end }
Random = {
  new = function()
    local seed = 987654
    return {
      NextNumber = function() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end,
      NextInteger = function(self,a,b) return a + math.floor(self:NextNumber()*(b-a+1)) end,
    }
  end,
}
print = hostprint
`;

const stripRequire = (source) =>
	source
		.split("\n")
		.filter((line) => !/^local \w+ = require\(/.test(line))
		.join("\n");

const module = (name, file) => `${name} = (function()\n${stripRequire(read(file))}\nend)()\n`;

const SIM = String.raw`
local rng = Random.new()
local data = GameConfig.defaultData()
local t, dt = 0, 0.1
local log = {}
local marks = {}
local nextLog, nextBuy = 0, 0
local TAPS_PER_SEC = 3

local function rate()
	return Pets.income(data) + GameConfig.tapPower(data) * TAPS_PER_SEC
end

local function rollPet(eggId)
	return GameConfig.rollPet(eggId, rng:NextNumber(), rng:NextNumber(),
		GameConfig.SecretChance / GameConfig.luck(data))
end

local function buySlot()
	local cost = GameConfig.upgradeCost("slots", data.upgrades.slots)
	if cost and data.coins >= cost then
		data.coins -= cost
		data.upgrades.slots += 1
		Pets.autoEquip(data)
		return true
	end
	return false
end

-- Modo economia: perto do custo de rebirth o jogador para de comprar ovo.
-- Sem isso o simulador gasta tudo em ovo e nunca renasce (jogador burro).
local saving = false

local function shouldSave()
	local cost = GameConfig.rebirthCost(rate(), data.rebirths)
	if data.rebirths >= GameConfig.Rebirth.Max then
		return false
	end
	if saving then
		if data.coins >= cost then
			saving = false
			return false
		end
		return true
	end
	if data.upgrades.slots >= 3 and data.coins >= cost * 0.55 then
		saving = true
		return true
	end
	return false
end

local function buyEgg()
	-- melhor ovo do jogo que dá pra pagar, considerando o preço atual dele
	local best, bestTier
	for tier, egg in ipairs(GameConfig.Eggs) do
		local bought = data.eggBought[egg.id] or 0
		local price = GameConfig.eggPrice(egg.id, bought)
		if data.coins >= price then
			best, bestTier = egg, tier
		end
	end
	if not best then return false end

	-- segura a compra se o próximo tier chega em <20s
	local nextEgg = GameConfig.Eggs[bestTier + 1]
	if nextEgg then
		local nextBought = data.eggBought[nextEgg.id] or 0
		local gap = GameConfig.eggPrice(nextEgg.id, nextBought) - data.coins
		if gap > 0 and gap <= rate() * 20 then return false end
	end

	data.coins -= GameConfig.eggPrice(best.id, data.eggBought[best.id] or 0)
	data.eggBought[best.id] = (data.eggBought[best.id] or 0) + 1
	local pet = rollPet(best.id)
	if pet and not Pets.storageFull(data) then
		Pets.add(data, pet.id, false)
		Pets.sellWorseThanEquipped(data)
		Pets.autoEquip(data)
	end
	return true
end

local function tryRebirth()
	local cost = GameConfig.rebirthCost(rate(), data.rebirths)
	if data.rebirths < GameConfig.Rebirth.Max and data.upgrades.slots >= 3 and data.coins >= cost then
		data.coins -= cost
		data.rebirths += 1
		data.eggBought = {}
		Pets.autoEquip(data)
		marks[#marks + 1] = { t = t, text = "REBIRTH " .. data.rebirths }
		return true
	end
	return false
end

print(string.format("%-8s %-5s %-12s %-12s %-7s %-4s %s",
	"tempo", "slots", "moedas", "renda/s", "rebirth", "tier", "pets"))
print(string.rep("-", 70))

while t < 8 * 3600 do
	data.coins += rate() * dt
	data.stats.coinsEarned += rate() * dt
	data.stats.taps += TAPS_PER_SEC * dt

	nextBuy -= dt
	if nextBuy <= 0 then
		nextBuy = 0.25
		if not shouldSave() then
			while buySlot() do end
			buyEgg()
		end
		tryRebirth()
	end

	t += dt
	if t >= nextLog then
		nextLog = t + 600
		local tier = 0
		for i, egg in ipairs(GameConfig.Eggs) do
			if data.coins >= GameConfig.eggPrice(egg.id, data.eggBought[egg.id] or 0) then tier = i end
		end
		print(string.format("%-8s %-5d %-12s %-12s %-7d %-4d %d",
			Format.time(t), GameConfig.petSlots(data), Format.number(data.coins),
			Format.number(Pets.income(data)), data.rebirths, tier, #data.pets))
	end
end

print()
print("Marcos:")
for _, m in ipairs(marks) do
	print(string.format("  %-9s %s", Format.time(m.t), m.text))
end
print()
print("Ovos abertos: " .. data.stats.hatched)
print("Slots: " .. GameConfig.petSlots(data))
print("Rebirths: " .. data.rebirths)
print("Renda final: " .. Format.number(Pets.income(data)) .. "/s")
print("Total ganho: " .. Format.number(data.stats.coinsEarned))

-- sanidade: o jogo tem que progredir, mas não explodir
assert(data.stats.hatched > 50, "poucos ovos abertos: " .. data.stats.hatched)
assert(Pets.income(data) > 1000, "renda não cresceu: " .. Pets.income(data))
assert(data.rebirths >= 1, "nunca renasceu")
assert(data.rebirths <= 12, "rebirth explodindo: " .. data.rebirths)
print("\nsim ok")
`;

const script = [
	SHIM,
	module("GameConfig", "src/shared/GameConfig.luau"),
	module("Format", "src/shared/Format.luau"),
	module("Pets", "src/shared/Pets.luau"),
	SIM,
].join("\n");

const lua = await Lua.create({ sandbox: true });
lua.globals.set("hostprint", lua.createFunction((...a) => console.log(a.map((v) => (v === undefined ? "nil" : String(v))).join("\t"))));

try {
	lua.execute(script);
} catch (e) {
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 10).join("\n"));
	process.exit(1);
}
