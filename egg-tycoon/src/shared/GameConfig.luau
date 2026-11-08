-- GameConfig
-- Toda a balanceagem: pets, ovos, raridades, upgrades e rebirth.
-- Modulo puro (sem `game`) pra rodar em teste fora do Roblox.

local GameConfig = {}

GameConfig.DataVersion = 1
GameConfig.SaveStore = "EggTycoon_Save_v1"

---------------------------------------------------------------------------
-- RARIDADES
---------------------------------------------------------------------------

GameConfig.Rarities = {
	{ id = "common", name = "Comum", color = Color3.fromRGB(190, 200, 215), order = 1 },
	{ id = "uncommon", name = "Incomum", color = Color3.fromRGB(105, 220, 140), order = 2 },
	{ id = "rare", name = "Raro", color = Color3.fromRGB(90, 170, 255), order = 3 },
	{ id = "epic", name = "Épico", color = Color3.fromRGB(190, 120, 255), order = 4 },
	{ id = "legendary", name = "Lendário", color = Color3.fromRGB(255, 190, 60), order = 5 },
	{ id = "mythic", name = "Mítico", color = Color3.fromRGB(255, 110, 160), order = 6 },
	{ id = "secret", name = "Secreto", color = Color3.fromRGB(60, 255, 235), order = 7 },
}

GameConfig.RarityById = {}
for _, rarity in ipairs(GameConfig.Rarities) do
	GameConfig.RarityById[rarity.id] = rarity
end

function GameConfig.rarity(id)
	return GameConfig.RarityById[id] or GameConfig.Rarities[1]
end

---------------------------------------------------------------------------
-- PETS
---------------------------------------------------------------------------
-- income = moedas por segundo quando equipado
-- Pet e imutavel: instancias ficam em data.pets com um uid proprio.

GameConfig.Pets = {
	-- Ovo Inicial
	{
		id = "chick",
		name = "Pintinho",
		emoji = "🐤",
		rarity = "common",
		income = 1,
		color = Color3.fromRGB(255, 225, 120),
	},
	{
		id = "bunny",
		name = "Coelhinho",
		emoji = "🐰",
		rarity = "common",
		income = 2,
		color = Color3.fromRGB(245, 240, 235),
	},
	{
		id = "kitten",
		name = "Gatinho",
		emoji = "🐱",
		rarity = "uncommon",
		income = 4.4,
		color = Color3.fromRGB(255, 175, 110),
	},
	{
		id = "fox",
		name = "Raposinha",
		emoji = "🦊",
		rarity = "rare",
		income = 10,
		color = Color3.fromRGB(255, 140, 70),
	},
	{
		id = "puppy",
		name = "Cachorrinho Dourado",
		emoji = "🐶",
		rarity = "epic",
		income = 24,
		color = Color3.fromRGB(255, 205, 60),
	},

	-- Ovo Verde
	{
		id = "frog",
		name = "Sapinho",
		emoji = "🐸",
		rarity = "common",
		income = 15,
		color = Color3.fromRGB(120, 210, 100),
	},
	{
		id = "turtle",
		name = "Tartaruga",
		emoji = "🐢",
		rarity = "common",
		income = 30,
		color = Color3.fromRGB(110, 190, 130),
	},
	{
		id = "panda",
		name = "Panda",
		emoji = "🐼",
		rarity = "uncommon",
		income = 66,
		color = Color3.fromRGB(240, 240, 240),
	},
	{
		id = "parrot",
		name = "Papagaio",
		emoji = "🦜",
		rarity = "rare",
		income = 150,
		color = Color3.fromRGB(120, 230, 120),
	},
	{
		id = "bear",
		name = "Ursinho",
		emoji = "🧸",
		rarity = "epic",
		income = 360,
		color = Color3.fromRGB(200, 155, 110),
	},

	-- Ovo Dourado
	{
		id = "hamster",
		name = "Hamster",
		emoji = "🐹",
		rarity = "common",
		income = 250,
		color = Color3.fromRGB(255, 200, 140),
	},
	{
		id = "lion",
		name = "Leãozinho",
		emoji = "🦁",
		rarity = "common",
		income = 500,
		color = Color3.fromRGB(255, 190, 90),
	},
	{
		id = "seal",
		name = "Foquinha",
		emoji = "🦭",
		rarity = "uncommon",
		income = 1100,
		color = Color3.fromRGB(190, 215, 235),
	},
	{
		id = "owl",
		name = "Coruja",
		emoji = "🦉",
		rarity = "rare",
		income = 2500,
		color = Color3.fromRGB(200, 175, 140),
	},
	{
		id = "goldenpup",
		name = "Filhote Dourado",
		emoji = "🐕",
		rarity = "legendary",
		income = 6000,
		color = Color3.fromRGB(255, 205, 60),
	},

	-- Ovo de Gelo
	{
		id = "penguin",
		name = "Pinguim",
		emoji = "🐧",
		rarity = "common",
		income = 4000,
		color = Color3.fromRGB(70, 90, 120),
	},
	{
		id = "icewolf",
		name = "Lobo de Gelo",
		emoji = "🐺",
		rarity = "common",
		income = 8000,
		color = Color3.fromRGB(150, 220, 255),
	},
	{
		id = "yeti",
		name = "Yeti",
		emoji = "❄️",
		rarity = "uncommon",
		income = 17600,
		color = Color3.fromRGB(220, 240, 255),
	},
	{
		id = "snowfox",
		name = "Raposa da Neve",
		emoji = "🦊",
		rarity = "rare",
		income = 40000,
		color = Color3.fromRGB(200, 230, 255),
	},
	{
		id = "frost",
		name = "Dragão de Gelo",
		emoji = "🐲",
		rarity = "legendary",
		income = 96000,
		color = Color3.fromRGB(120, 200, 255),
	},

	-- Ovo Sombrio
	{
		id = "bat",
		name = "Morceguinho",
		emoji = "🦇",
		rarity = "common",
		income = 65000,
		color = Color3.fromRGB(110, 105, 140),
	},
	{
		id = "spider",
		name = "Aranha",
		emoji = "🕷️",
		rarity = "common",
		income = 130000,
		color = Color3.fromRGB(90, 80, 100),
	},
	{
		id = "ghost",
		name = "Fantasma",
		emoji = "👻",
		rarity = "uncommon",
		income = 286000,
		color = Color3.fromRGB(230, 240, 255),
	},
	{
		id = "demon",
		name = "Demoninho",
		emoji = "😈",
		rarity = "rare",
		income = 650000,
		color = Color3.fromRGB(220, 80, 90),
	},
	{
		id = "reaper",
		name = "Ceifador",
		emoji = "💀",
		rarity = "mythic",
		income = 1560000,
		color = Color3.fromRGB(160, 170, 200),
	},

	-- Ovo de 30M
	{
		id = "dragon",
		name = "Dragãozinho",
		emoji = "🐲",
		rarity = "common",
		income = 1000000,
		color = Color3.fromRGB(90, 200, 130),
	},
	{
		id = "unicorn",
		name = "Unicórnio",
		emoji = "🦄",
		rarity = "common",
		income = 2000000,
		color = Color3.fromRGB(255, 180, 240),
	},
	{
		id = "phoenix",
		name = "Fênix",
		emoji = "🔥",
		rarity = "uncommon",
		income = 4400000,
		color = Color3.fromRGB(255, 140, 60),
	},
	{
		id = "galaxy",
		name = "Gatinho Galáxia",
		emoji = "🌌",
		rarity = "rare",
		income = 10000000,
		color = Color3.fromRGB(130, 110, 255),
	},
	{
		id = "voidcat",
		name = "Gato do Vazio",
		emoji = "🕳️",
		rarity = "mythic",
		income = 24000000,
		color = Color3.fromRGB(80, 40, 140),
	},

	-- Secretos (qualquer ovo, chance mínima)
	{
		id = "rainbowcat",
		name = "Gato Arco-Íris",
		emoji = "🌈",
		rarity = "secret",
		income = 250000000,
		color = Color3.fromRGB(255, 120, 220),
		secret = true,
	},
	{
		id = "cosmicdog",
		name = "Cão Cósmico",
		emoji = "✨",
		rarity = "secret",
		income = 400000000,
		color = Color3.fromRGB(140, 200, 255),
		secret = true,
	},
}

GameConfig.PetById = {}
for _, pet in ipairs(GameConfig.Pets) do
	GameConfig.PetById[pet.id] = pet
end

function GameConfig.pet(id)
	return GameConfig.PetById[id]
end

---------------------------------------------------------------------------
-- OVOS
---------------------------------------------------------------------------
-- cost em moedas. weight = peso relativo dentro do ovo.

GameConfig.Eggs = {
	{
		id = "starter",
		name = "Ovo Inicial",
		emoji = "🥚",
		cost = 30,
		color = Color3.fromRGB(255, 240, 200),
		spot = Color3.fromRGB(215, 175, 120),
		drops = { chick = 450, bunny = 300, kitten = 175, fox = 70, puppy = 5 },
	},
	{
		id = "green",
		name = "Ovo Verde",
		emoji = "🟢",
		cost = 600,
		color = Color3.fromRGB(180, 240, 175),
		spot = Color3.fromRGB(90, 170, 90),
		drops = { frog = 450, turtle = 300, panda = 175, parrot = 70, bear = 5 },
	},
	{
		id = "golden",
		name = "Criação Dourada",
		emoji = "🟡",
		cost = 12000,
		color = Color3.fromRGB(255, 220, 110),
		spot = Color3.fromRGB(230, 160, 40),
		drops = { hamster = 450, lion = 300, seal = 175, owl = 70, goldenpup = 5 },
	},
	{
		id = "ice",
		name = "Ovo de Gelo",
		emoji = "🔵",
		cost = 250000,
		color = Color3.fromRGB(200, 240, 255),
		spot = Color3.fromRGB(110, 190, 245),
		drops = { penguin = 450, icewolf = 300, yeti = 175, snowfox = 70, frost = 5 },
	},
	{
		id = "shadow",
		name = "Ovo Sombrio",
		emoji = "🟣",
		cost = 6000000,
		color = Color3.fromRGB(150, 120, 200),
		spot = Color3.fromRGB(70, 50, 110),
		drops = { bat = 450, spider = 300, ghost = 175, demon = 70, reaper = 5 },
	},
	{
		id = "halloween",
		name = "Ovo de Halloween",
		emoji = "🎃",
		cost = 25000000,
		color = Color3.fromRGB(255, 150, 60),
		spot = Color3.fromRGB(120, 60, 30),
		event = true,
		drops = { bat = 450, spider = 300, ghost = 175, demon = 70, reaper = 5 },
	},
	{
		id = "visits",
		name = "Ovo de 30M Visitas",
		emoji = "🏆",
		cost = 150000000,
		color = Color3.fromRGB(255, 200, 240),
		spot = Color3.fromRGB(200, 110, 200),
		drops = { dragon = 450, unicorn = 300, phoenix = 175, galaxy = 70, voidcat = 5 },
	},
}

GameConfig.EggById = {}
for _, egg in ipairs(GameConfig.Eggs) do
	GameConfig.EggById[egg.id] = egg
end

function GameConfig.egg(id)
	return GameConfig.EggById[id]
end

-- Chance de pet secreto por ovo (fora da tabela de drops)
GameConfig.SecretChance = 1 / 500

-- Preço do ovo sobe a cada compra e reseta no rebirth.
-- É o que impede a renda de crescer sem custo (o erro clássico de idle game).
GameConfig.EggPriceGrowth = 1.18

function GameConfig.eggPrice(eggId, boughtCount)
	local egg = GameConfig.egg(eggId)
	if not egg then
		return 0
	end
	return math.floor(egg.cost * (GameConfig.EggPriceGrowth ^ (boughtCount or 0)))
end

local SECRETS = {}
for _, pet in ipairs(GameConfig.Pets) do
	if pet.secret then
		SECRETS[#SECRETS + 1] = pet
	end
end

-- roll: numero em [0,1). Retorna a definicao do pet.
function GameConfig.rollPet(eggId, roll, secretRoll, secretChance)
	local egg = GameConfig.egg(eggId)
	if not egg then
		return nil
	end

	if secretRoll and secretRoll < (secretChance or GameConfig.SecretChance) then
		local index = math.floor(roll * #SECRETS) % #SECRETS + 1
		return SECRETS[index]
	end

	local total = 0
	for _, weight in pairs(egg.drops) do
		total += weight
	end

	local pointer = roll * total
	for petId, weight in pairs(egg.drops) do
		pointer -= weight
		if pointer <= 0 then
			return GameConfig.pet(petId)
		end
	end

	-- hash map nao garante ordem; fallback deterministico
	local first = next(egg.drops)
	return GameConfig.pet(first)
end

---------------------------------------------------------------------------
-- UPGRADES DE MOEDA
---------------------------------------------------------------------------

GameConfig.Upgrades = {
	tap = { name = "Força do Toque", baseCost = 200, growth = 1.75, maxTier = 30, step = 1, base = 1 },
	-- 3 -> 15 slots na moeda, 15 -> 19 com gemas. Com 9 slots a renda trava
	-- por horas (medido na simulação), então esse upgrade precisa ir mais longe.
	slots = { name = "Espaço de Pet", baseCost = 400, growth = 6.2, maxTier = 12, step = 1, base = 3 },
	mult = { name = "Multiplicador", baseCost = 500000, growth = 3.2, maxTier = 20, step = 0.15, base = 1 },
}

function GameConfig.upgradeCost(kind, tier)
	local u = GameConfig.Upgrades[kind]
	if not u or tier >= u.maxTier then
		return nil
	end
	return math.floor(u.baseCost * (u.growth ^ tier))
end

---------------------------------------------------------------------------
-- MELHORIAS DE GEMAS (permanentes, nao resetam)
---------------------------------------------------------------------------

GameConfig.GemUpgrades = {
	gemsIncome = { name = "Renda de Pets", baseCost = 3, costStep = 2, step = 0.12, maxRank = 25 },
	gemsLuck = { name = "Sorte", baseCost = 4, costStep = 3, step = 0.1, maxRank = 20 },
	gemsTap = { name = "Toque", baseCost = 2, costStep = 1, step = 0.2, maxRank = 20 },
	gemsSlots = { name = "Espaço Extra", baseCost = 8, costStep = 8, step = 1, maxRank = 4 },
}

function GameConfig.gemCost(kind, rank)
	local u = GameConfig.GemUpgrades[kind]
	if not u or rank >= u.maxRank then
		return nil
	end
	return u.baseCost + u.costStep * rank
end

---------------------------------------------------------------------------
-- REBIRTH (Rensamentos)
---------------------------------------------------------------------------

GameConfig.Rebirth = {
	Max = 25,
	CrystalBase = 4,
	CrystalStep = 3,
	MultiplierPerRebirth = 0.3,
	-- Custo = 600s de renda, limitado por um teto que CRESCE a cada rebirth.
	-- Teto fixo = spam infinito (medido: 4 rebirths em 13s).
	-- Sem teto = custo acompanha a renda pra sempre e nunca renasce (6h+).
	SecondsOfIncome = 600,
	MinCost = 100000,
	CapBase = 5e8,
	CapGrowth = 6,
}

function GameConfig.rebirthCost(rate, rebirths)
	local cfg = GameConfig.Rebirth
	local cap = cfg.CapBase * (cfg.CapGrowth ^ (rebirths or 0))
	local raw = (rate or 0) * cfg.SecondsOfIncome
	return math.clamp(raw, cfg.MinCost, cap)
end

function GameConfig.rebirthCrystals(rebirths)
	return GameConfig.Rebirth.CrystalBase + GameConfig.Rebirth.CrystalStep * rebirths
end

function GameConfig.rebirthMultiplier(rebirths)
	return 1 + GameConfig.Rebirth.MultiplierPerRebirth * rebirths
end

---------------------------------------------------------------------------
-- DERIVADOS
---------------------------------------------------------------------------

function GameConfig.petSlots(data)
	local base = GameConfig.Upgrades.slots.base
		+ GameConfig.Upgrades.slots.step * (data.upgrades and data.upgrades.slots or 0)
	local gems = GameConfig.GemUpgrades.gemsSlots.step * (data.gemUpgrades and data.gemUpgrades.gemsSlots or 0)
	return base + gems
end

function GameConfig.tapPower(data)
	local base = GameConfig.Upgrades.tap.base
		+ GameConfig.Upgrades.tap.step * (data.upgrades and data.upgrades.tap or 0)
	local gems = 1 + GameConfig.GemUpgrades.gemsTap.step * (data.gemUpgrades and data.gemUpgrades.gemsTap or 0)
	return base * gems * GameConfig.rebirthMultiplier(data.rebirths or 0)
end

function GameConfig.incomeMultiplier(data)
	local m = GameConfig.Upgrades.mult.base
		+ GameConfig.Upgrades.mult.step * (data.upgrades and data.upgrades.mult or 0)
	local gems = 1 + GameConfig.GemUpgrades.gemsIncome.step * (data.gemUpgrades and data.gemUpgrades.gemsIncome or 0)
	return m * gems * GameConfig.rebirthMultiplier(data.rebirths or 0)
end

function GameConfig.luck(data)
	local gems = 1 + GameConfig.GemUpgrades.gemsLuck.step * (data.gemUpgrades and data.gemUpgrades.gemsLuck or 0)
	return gems
end

-- Ritmo total: renda passiva + toques estimados (3/s)
function GameConfig.rate(data)
	return GameConfig.equippedIncome(data) + GameConfig.tapPower(data) * 3
end

-- Soma a renda dos pets equipados (com multiplicadores)
function GameConfig.equippedIncome(data)
	local total = 0
	for _, uid in ipairs(data.equipped or {}) do
		for _, instance in ipairs(data.pets or {}) do
			if instance.uid == uid then
				local pet = GameConfig.pet(instance.petId)
				if pet then
					total += pet.income * (instance.golden and 1.5 or 1)
				end
				break
			end
		end
	end
	return total * GameConfig.incomeMultiplier(data)
end

---------------------------------------------------------------------------
-- TAP VALUE e PROGRESSAO DE OVOS
---------------------------------------------------------------------------

-- Quanto tempo (s) para comprar o proximo ovo, no ritmo atual
function GameConfig.secondsToAfford(eggId, data)
	local egg = GameConfig.egg(eggId)
	if not egg then
		return 0
	end
	local passive = GameConfig.equippedIncome(data)
	local tap = GameConfig.tapPower(data)
	local coins = (data.coins or 0)
	local remaining = math.max(0, egg.cost - coins)
	if remaining <= 0 then
		return 0
	end
	local tapRate = tap * 3 -- ~3 toques/s
	local rate = passive + tapRate
	if rate <= 0 then
		return math.huge
	end
	return remaining / rate
end

---------------------------------------------------------------------------
-- SAVE DEFAULT
---------------------------------------------------------------------------

function GameConfig.defaultData()
	return {
		version = GameConfig.DataVersion,
		coins = 0,
		gems = 0,
		crystals = 0,
		rebirths = 0,
		pets = {}, -- { uid, petId, golden, level }
		equipped = {},
		upgrades = { tap = 0, slots = 0, mult = 0 },
		gemUpgrades = { gemsIncome = 0, gemsLuck = 0, gemsTap = 0, gemsSlots = 0 },
		nextUid = 1,
		eggBought = {},
		selectedEgg = "starter",
		stats = { taps = 0, hatched = 0, bestRarity = 0, coinsEarned = 0 },
		questIndex = 1,
		-- Mina dos pets (ver shared/Mine.luau). `dug` guarda quantas
		-- viagens cada pet já completou: é o que dá a sensação de "meu pet
		-- trabalha há um tempo". `best` guarda o melhor minério já achado.
		mine = { dug = {}, best = "", total = 0 },
	}
end

---------------------------------------------------------------------------
-- QUESTS (a barra "PRÓXIMO!" do topo)
---------------------------------------------------------------------------

GameConfig.Quests = {
	{ id = "tap10", text = "Toque 10 vezes", kind = "taps", target = 10, reward = 25 },
	{ id = "hatch1", text = "Abra seu primeiro ovo!", kind = "hatched", target = 1, reward = 50 },
	{ id = "equip1", text = "Equipe um pet", kind = "equipped", target = 1, reward = 100 },
	{ id = "tap100", text = "Toque 100 vezes", kind = "taps", target = 100, reward = 250 },
	{ id = "hatch5", text = "Abra 5 ovos", kind = "hatched", target = 5, reward = 1000 },
	{ id = "coins10k", text = "Junte 10K moedas", kind = "coinsEarned", target = 10000, reward = 5000 },
	{ id = "hatch25", text = "Abra 25 ovos", kind = "hatched", target = 25, reward = 25000 },
}

function GameConfig.questProgress(data, quest)
	if quest.kind == "taps" then
		return data.stats.taps
	elseif quest.kind == "hatched" then
		return data.stats.hatched
	elseif quest.kind == "equipped" then
		return #data.equipped
	end
	return data.stats.coinsEarned
end

return GameConfig
