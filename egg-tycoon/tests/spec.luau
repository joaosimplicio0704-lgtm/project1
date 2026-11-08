-- spec
-- Testes da lógica pura: config, pets, roll de ovos, economia, quests.
-- Globals: GameConfig, Pets, Format

local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print(string.format("  FAIL  %s  %s", name, detail or ""))
	end
end

-- RARIDADES
check("7 raridades", #GameConfig.Rarities == 7, tostring(#GameConfig.Rarities))
check("rarity ordenada", GameConfig.rarity("secret").order > GameConfig.rarity("common").order)
check("rarity invalida volta ao comum", GameConfig.rarity("xyz").id == "common")

-- PETS
check("pets declarados", #GameConfig.Pets >= 25, tostring(#GameConfig.Pets))
check(
	"todo pet tem ovo",
	(function()
		for _, pet in ipairs(GameConfig.Pets) do
			if pet.secret then
				continue
			end
			local found = false
			for _, egg in ipairs(GameConfig.Eggs) do
				if egg.drops[pet.id] then
					found = true
					break
				end
			end
			if not found then
				return false, pet.id
			end
		end
		return true
	end)()
)

check(
	"pets secretos existem",
	(function()
		local n = 0
		for _, pet in ipairs(GameConfig.Pets) do
			if pet.secret then
				n += 1
			end
		end
		return n >= 2
	end)()
)

check("getPet funciona", GameConfig.pet("chick").name == "Pintinho")
check("getPet invalido nil", GameConfig.pet("nope") == nil)

-- OVOS
check("7 ovos", #GameConfig.Eggs == 7, tostring(#GameConfig.Eggs))
check(
	"todo drop aponta pra pet existente",
	(function()
		for _, egg in ipairs(GameConfig.Eggs) do
			for petId in pairs(egg.drops) do
				if not GameConfig.pet(petId) then
					return false, egg.id .. " -> " .. petId
				end
			end
		end
		return true
	end)()
)
check("ovo de halloween existe", GameConfig.egg("halloween") ~= nil)
check(
	"custos crescentes",
	(function()
		for i = 2, #GameConfig.Eggs do
			if GameConfig.Eggs[i].cost <= GameConfig.Eggs[i - 1].cost then
				return false
			end
		end
		return true
	end)()
)

check(
	"drops referenciam pets validos",
	(function()
		for _, egg in ipairs(GameConfig.Eggs) do
			for petId in pairs(egg.drops) do
				if not GameConfig.pet(petId) then
					return false, egg.id .. "." .. petId
				end
			end
		end
		return true
	end)()
)

-- ROLL determinístico
check(
	"roll 0 devolve pet do ovo",
	(function()
		local pet = GameConfig.rollPet("starter", 0, 0.99, 0)
		if not pet then
			return false
		end
		return GameConfig.egg("starter").drops[pet.id] ~= nil
	end)()
)

check(
	"roll 0.999 devolve pet do ovo",
	(function()
		local pet = GameConfig.rollPet("starter", 0.999, 0.99, 0)
		if not pet then
			return false
		end
		return GameConfig.egg("starter").drops[pet.id] ~= nil
	end)()
)

check(
	"secret roll sempre secreto",
	(function()
		for i = 0, 20 do
			local pet = GameConfig.rollPet("starter", i / 20, 0.0001, 0.2)
			if not pet or not pet.secret then
				return false, tostring(pet and pet.id)
			end
		end
		return true
	end)()
)

check("roll de ovo invalido = nil", GameConfig.rollPet("nope", 0.5, 0.5, 0) == nil)

-- UPGRADES
check("custo cresce", GameConfig.upgradeCost("tap", 1) > GameConfig.upgradeCost("tap", 0))
check("maximo nil", GameConfig.upgradeCost("tap", 30) == nil)
check("gem custo cresce", GameConfig.gemCost("gemsIncome", 2) > GameConfig.gemCost("gemsIncome", 0))
check("gem maximo nil", GameConfig.gemCost("gemsIncome", 25) == nil)

-- DERIVADOS
local data = GameConfig.defaultData()
check("slots base 3", GameConfig.petSlots(data) == 3, tostring(GameConfig.petSlots(data)))
check("tap base 1", GameConfig.tapPower(data) == 1, tostring(GameConfig.tapPower(data)))
check("mult base 1", GameConfig.incomeMultiplier(data) == 1, tostring(GameConfig.incomeMultiplier(data)))

data.upgrades.tap = 5
check("tap sobe com upgrade", GameConfig.tapPower(data) > 1)
data.gemUpgrades.gemsTap = 3
check("gem tap multiplica", GameConfig.tapPower(data) > GameConfig.Upgrades.tap.base + 5)
data.rebirths = 2
check("rebirth multiplica tap", GameConfig.tapPower(data) > 1)

-- PETS MODULE
local d = GameConfig.defaultData()
local pet = Pets.add(d, "chick", false)
check("add cria uid", pet.uid == 1)
check("add incrementa nextUid", d.nextUid == 2)
check("stats.hatched subiu", d.stats.hatched == 1)
check("bestRarity registrada", d.stats.bestRarity == 1)

local ok = Pets.equip(d, pet.uid)
check("equipa primeiro", ok == true)
check("equipado aparece na lista", #d.equipped == 1)
check("não equipa duas vezes", Pets.equip(d, pet.uid) == false)

-- slots
Pets.add(d, "bunny")
Pets.add(d, "kitten")
Pets.add(d, "puppy")
Pets.autoEquip(d)
check("auto-equip respeita slots", #d.equipped == 3, tostring(#d.equipped))

local income = Pets.income(d)
check("renda > 0", income > 0, tostring(income))

-- venda
local before = d.coins
local sold, value = Pets.sell(d, pet.uid)
check("venda ok", sold == true)
check("venda paga", d.coins > before)
check("pet removido", Pets.find(d, pet.uid) == nil)

-- fusão: 3 iguais raro+
local f = GameConfig.defaultData()
Pets.add(f, "fox")
Pets.add(f, "fox")
Pets.add(f, "fox")
local uids = { f.pets[1].uid, f.pets[2].uid, f.pets[3].uid }
local fused, result = Pets.fuse(f, uids)
check("fusão funciona", fused == true, tostring(result))
check("fusão consome 3", #f.pets == 1, tostring(#f.pets))
check(
	"fusão sobe tier",
	(function()
		if not result then
			return false
		end
		local base = GameConfig.pet("fox")
		local up = GameConfig.pet(result.petId)
		return GameConfig.rarity(up.rarity).order > GameConfig.rarity(base.rarity).order
	end)()
)

check(
	"fusão recusa comuns",
	(function()
		local g = GameConfig.defaultData()
		Pets.add(g, "chick")
		Pets.add(g, "chick")
		Pets.add(g, "chick")
		return Pets.fuse(g, { 1, 2, 3 }) == false
	end)()
)

check(
	"fusão recusa pets diferentes",
	(function()
		local h = GameConfig.defaultData()
		Pets.add(h, "fox")
		Pets.add(h, "panda")
		Pets.add(h, "owl")
		return Pets.fuse(h, { 1, 2, 3 }) == false
	end)()
)

-- REBIRTH
check("rebirth custo cresce com renda", GameConfig.rebirthCost(1e6) > GameConfig.rebirthCost(1e5))
check("rebirth tem piso", GameConfig.rebirthCost(0) == GameConfig.Rebirth.MinCost)
check("rebirth teto cresce por rebirth", GameConfig.rebirthCost(1e12, 3) > GameConfig.rebirthCost(1e12, 0))
check("rebirth nao vira spam no inicio", GameConfig.rebirthCost(1e12, 0) < 1e13)
check("rebirth cristais crescem", GameConfig.rebirthCrystals(3) > GameConfig.rebirthCrystals(1))
check(
	"rebirth multiplica",
	math.abs(GameConfig.rebirthMultiplier(2) - (1 + GameConfig.Rebirth.MultiplierPerRebirth * 2)) < 1e-9
)

-- QUESTS
check("quests existem", #GameConfig.Quests >= 5)
check("quest progress taps", GameConfig.questProgress({ stats = { taps = 7 } }, GameConfig.Quests[1]) == 7)
check("quest progress hatch", GameConfig.questProgress({ stats = { hatched = 3 } }, { kind = "hatched" }) == 3)

-- FORMAT
check("format 999", Format.number(999) == "999", Format.number(999))
check("format 1500", Format.number(1500) == "1.5K", Format.number(1500))
check("format 1e6", Format.number(1000000) == "1M", Format.number(1000000))
check("format 2.5e9", Format.number(2.5e9) == "2.5B", Format.number(2.5e9))
check("format 1e12", Format.number(1e12) == "1T", Format.number(1e12))
check("rate formata", Format.rate(1500) == "+1.5K/s", Format.rate(1500))
check("tempo minutos", Format.time(125) == "2m 05s", Format.time(125))
check("tempo infinito", Format.time(math.huge) == "∞")

-- economia fecha: tempo pra comprar o 2o ovo
local fresh = GameConfig.defaultData()
local seconds = GameConfig.secondsToAfford("starter", fresh)
check("primeiro ovo acessível", seconds < 60, tostring(seconds))

---------------------------------------------------------------------------
-- BIOMAS E DESBLOQUEIO
---------------------------------------------------------------------------

check("7 biomas", #Biomes.List == 7, tostring(#Biomes.List))

local missingEgg = nil
local seenEgg = {}
local duplicateEgg = nil
for _, biome in ipairs(Biomes.List) do
	if not GameConfig.EggById[biome.eggId] then
		missingEgg = biome.id .. ":" .. biome.eggId
	end
	if seenEgg[biome.eggId] then
		duplicateEgg = biome.eggId
	end
	seenEgg[biome.eggId] = true
end
check("todo bioma tem ovo valido", missingEgg == nil, tostring(missingEgg))
check("ovos nao se repetem entre biomas", duplicateEgg == nil, tostring(duplicateEgg))

local biomeFresh = Biomes.unlockedMap({ hatched = 0, rebirths = 0 })
check("meadow e livre", biomeFresh.meadow == true)
local allLocked = true
for _, biome in ipairs(Biomes.List) do
	if biome.id ~= "meadow" and biomeFresh[biome.id] then
		allLocked = false
	end
end
check("os outros comecam bloqueados", allLocked)

local afterHatch = Biomes.unlockedMap({ hatched = 3, rebirths = 0 })
check("3 ovos abrem a floresta", afterHatch.forest == true)
check("3 ovos nao abrem o deserto", afterHatch.desert == false)

local oneRebirth = Biomes.unlockedMap({ hatched = 0, rebirths = 1 })
check("rebirth 1 abre o deserto", oneRebirth.desert == true)
check("rebirth 1 nao abre o gelo", oneRebirth.ice == false)

-- Rebirths abrem os mundos de rebirth; a floresta depende de ovos chocados.
local full = Biomes.unlockedMap({ hatched = 99, rebirths = 5 })
local allOpen = true
for _, biome in ipairs(Biomes.List) do
	if not full[biome.id] then
		allOpen = false
	end
end
check("rebirth 5 + 99 ovos abre tudo", allOpen)

check("forEgg encontra o bioma do ovo", Biomes.forEgg("halloween").id == "halloween")

-- geometria: ilhas longe do hub, chegada dentro da ilha e acima do chao
local misplaced = nil
for _, biome in ipairs(Biomes.List) do
	local c = Biomes.centerVector(biome)
	local flat = math.sqrt(c.X * c.X + c.Z * c.Z)
	if biome.id == "cosmos" then
		if c.Y < 100 then
			misplaced = "cosmos baixo demais"
		end
	elseif flat < 200 then
		misplaced = biome.id .. " perto do hub"
	end

	local spawn = Biomes.spawnPoint(biome)
	local dx, dz = spawn.X - c.X, spawn.Z - c.Z
	if math.sqrt(dx * dx + dz * dz) >= biome.radius then
		misplaced = biome.id .. " chegada fora da ilha"
	end
	if spawn.Y <= c.Y then
		misplaced = biome.id .. " chegada abaixo do chao"
	end
end
check("geometria dos biomas coerente", misplaced == nil, tostring(misplaced))

check("rotulo livre", Biomes.unlockLabel(Biomes.get("meadow")) == "Livre")
check("rotulo de ovos", string.find(Biomes.unlockLabel(Biomes.get("forest")), "3") ~= nil)
check("rotulo de rebirth", string.find(Biomes.unlockLabel(Biomes.get("ice")), "2") ~= nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("testes falharam")
end
