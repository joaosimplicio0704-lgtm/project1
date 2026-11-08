-- GameConfig
-- Toda a balanceagem do jogo mora aqui. Muda numero aqui, muda no jogo inteiro.
-- Modulo puro: nenhuma referencia a `game`, roda em qualquer sandbox.

local GameConfig = {}

GameConfig.DataVersion = 1
GameConfig.SaveStore = "FarmTycoon_Save_v1"

GameConfig.MaxLevel = 40

---------------------------------------------------------------------------
-- CROPS
---------------------------------------------------------------------------
-- grow  = segundos base para amadurecer
-- seed  = custo da semente
-- sell  = preco de venda por unidade colhida
-- amount = unidades por colheita
-- xp    = xp por colheita
-- level = nivel minimo para desbloquear

GameConfig.Crops = {
	{
		id = "wheat",
		name = "Trigo",
		emoji = "🌾",
		grow = 6,
		seed = 5,
		sell = 5,
		amount = 3,
		xp = 6,
		level = 1,
		color = Color3.fromRGB(232, 216, 168),
	},
	{
		id = "carrot",
		name = "Cenoura",
		emoji = "🥕",
		grow = 10,
		seed = 16,
		sell = 16,
		amount = 3,
		xp = 10,
		level = 2,
		color = Color3.fromRGB(255, 140, 66),
	},
	{
		id = "tomato",
		name = "Tomate",
		emoji = "🍅",
		grow = 16,
		seed = 46,
		sell = 46,
		amount = 3,
		xp = 18,
		level = 4,
		color = Color3.fromRGB(226, 59, 59),
	},
	{
		id = "corn",
		name = "Milho",
		emoji = "🌽",
		grow = 22,
		seed = 120,
		sell = 120,
		amount = 3,
		xp = 28,
		level = 6,
		color = Color3.fromRGB(255, 212, 0),
	},
	{
		id = "strawberry",
		name = "Morango",
		emoji = "🍓",
		grow = 32,
		seed = 330,
		sell = 330,
		amount = 3,
		xp = 44,
		level = 9,
		color = Color3.fromRGB(255, 77, 109),
	},
	{
		id = "pumpkin",
		name = "Abóbora",
		emoji = "🎃",
		grow = 46,
		seed = 900,
		sell = 900,
		amount = 3,
		xp = 64,
		level = 12,
		color = Color3.fromRGB(255, 122, 24),
	},
	{
		id = "grape",
		name = "Uva",
		emoji = "🍇",
		grow = 62,
		seed = 2400,
		sell = 2400,
		amount = 3,
		xp = 88,
		level = 16,
		color = Color3.fromRGB(139, 92, 246),
	},
	{
		id = "starfruit",
		name = "Carambola",
		emoji = "⭐",
		grow = 85,
		seed = 6500,
		sell = 6500,
		amount = 3,
		xp = 120,
		level = 20,
		color = Color3.fromRGB(255, 224, 102),
	},
}

GameConfig.CropById = {}
for _, crop in ipairs(GameConfig.Crops) do
	GameConfig.CropById[crop.id] = crop
end

function GameConfig.getCrop(id)
	return GameConfig.CropById[id]
end

-- Primeira crop liberada no nivel informado (usada para auto-select no rebirth)
function GameConfig.bestCropForLevel(level)
	local best = GameConfig.Crops[1]
	for _, crop in ipairs(GameConfig.Crops) do
		if crop.level <= level then
			best = crop
		end
	end
	return best
end

---------------------------------------------------------------------------
-- XP / LEVEL
---------------------------------------------------------------------------

function GameConfig.xpNeeded(level)
	if level >= GameConfig.MaxLevel then
		return math.huge
	end
	return math.floor(45 * level ^ 1.18)
end

---------------------------------------------------------------------------
-- LAYOUT DO LOTE
---------------------------------------------------------------------------
-- Fonte unica da geometria. World (servidor) e Render (cliente) leem daqui,
-- entao plot e esteira nunca desalinham.

GameConfig.Layout = {
	lotSize = 64,
	-- grade de terrenos: 4 colunas x 3 linhas, no lado esquerdo do lote
	plotCols = 4,
	plotSize = 9,
	plotSpacingX = 9,
	plotSpacingZ = 10,
	plotOriginX = -25,
	plotOriginZ = -13,
	plotSurfaceY = 2.4, -- topo da terra, relativo ao centro do lote
	-- esteira: lado direito, correndo no eixo Z ate o caixa
	beltX = 16,
	beltY = 2.1,
	beltWidth = 6,
	beltLength = 30,
	beltZStart = -14,
	sellPadDistance = 8, -- distancia do fim da esteira ate o centro do caixa
}

-- Posicao local do terreno i (relativa ao centro do lote).
function GameConfig.plotLocalOffset(i)
	local layout = GameConfig.Layout
	local col = (i - 1) % layout.plotCols
	local row = (i - 1) // layout.plotCols
	return Vector3.new(
		layout.plotOriginX + col * layout.plotSpacingX,
		layout.plotSurfaceY,
		layout.plotOriginZ + row * layout.plotSpacingZ
	)
end

-- Ponto de inicio da esteira (relativo ao centro do lote).
function GameConfig.beltLocalStart()
	local layout = GameConfig.Layout
	return Vector3.new(layout.beltX, layout.beltY, layout.beltZStart)
end

---------------------------------------------------------------------------
-- PLOTS (terrenos do jogador)
---------------------------------------------------------------------------

GameConfig.Plots = {
	Start = 4,
	Max = 12,
	Cost = {
		[5] = 2500,
		[6] = 15000,
		[7] = 90000,
		[8] = 400000,
		[9] = 1500000,
		[10] = 6000000,
		[11] = 25000000,
		[12] = 100000000,
	},
	LevelReq = {
		[5] = 3,
		[6] = 5,
		[7] = 8,
		[8] = 11,
		[9] = 14,
		[10] = 17,
		[11] = 21,
		[12] = 25,
	},
}

function GameConfig.plotCost(current)
	local nextPlot = current + 1
	if nextPlot > GameConfig.Plots.Max then
		return nil
	end
	return GameConfig.Plots.Cost[nextPlot], GameConfig.Plots.LevelReq[nextPlot]
end

---------------------------------------------------------------------------
-- UPGRADES (custos em cash, resetam no rebirth)
---------------------------------------------------------------------------

GameConfig.Upgrades = {
	conveyor = { name = "Velocidade da Esteira", baseCost = 500, growth = 1.9, maxTier = 15, step = 6, base = 20 },
	sell = { name = "Multiplicador de Venda", baseCost = 3000, growth = 2.1, maxTier = 12, step = 0.25, base = 1 },
	luck = { name = "Sorte", baseCost = 1500, growth = 1.8, maxTier = 15, step = 1, base = 1 },
}

-- Colheita Dupla: compra unica por tier, cada tier soma chance de item extra
GameConfig.AutoTiers = {
	{ cost = 25000, doubleChance = 0.18 },
	{ cost = 250000, doubleChance = 0.18 },
	{ cost = 2500000, doubleChance = 0.18 },
	{ cost = 25000000, doubleChance = 0.18 },
}

-- chance acumulada de item extra na colheita para um dado tier
function GameConfig.doubleChance(tier)
	local t = GameConfig.AutoTiers[tier]
	return t and t.doubleChance or 0
end

function GameConfig.autoCost(tier)
	local t = GameConfig.AutoTiers[tier + 1]
	return t and t.cost or nil
end

function GameConfig.upgradeCost(kind, tier)
	local u = GameConfig.Upgrades[kind]
	if not u or tier >= u.maxTier then
		return nil
	end
	return math.floor(u.baseCost * (u.growth ^ tier))
end

function GameConfig.conveyorSpeed(tier)
	local u = GameConfig.Upgrades.conveyor
	return u.base + u.step * tier
end

function GameConfig.sellUpgradeMult(tier)
	local u = GameConfig.Upgrades.sell
	return u.base + u.step * tier
end

---------------------------------------------------------------------------
-- CRYSTAL UPGRADES (custos em cristais, NAO resetam no rebirth)
---------------------------------------------------------------------------

GameConfig.CrystalUpgrades = {
	growth = { name = "Crescimento", baseCost = 2, costStep = 2, step = 0.04, maxRank = 25 },
	sell = { name = "Venda Permanente", baseCost = 3, costStep = 3, step = 0.1, maxRank = 25 },
	luck = { name = "Sorte Permanente", baseCost = 4, costStep = 4, step = 1, maxRank = 15 },
}

function GameConfig.crystalCost(kind, rank)
	local u = GameConfig.CrystalUpgrades[kind]
	if not u or rank >= u.maxRank then
		return nil
	end
	return u.baseCost + u.costStep * rank
end

---------------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------------

GameConfig.Rebirth = {
	Max = 10,
	RequiredLevel = GameConfig.MaxLevel,
	RequiredCash = 250000,
	MultiplierPerRebirth = 0.5,
	CrystalBase = 3,
	CrystalStep = 1,
}

function GameConfig.rebirthMultiplier(rebirths)
	return 1 + GameConfig.Rebirth.MultiplierPerRebirth * rebirths
end

function GameConfig.rebirthCrystals(rebirths)
	return GameConfig.Rebirth.CrystalBase + GameConfig.Rebirth.CrystalStep * rebirths
end

---------------------------------------------------------------------------
-- MUTATIONS
---------------------------------------------------------------------------
-- weight normalizado. luck aumenta o peso das raras (luckWeight > 0).

GameConfig.Mutations = {
	{ id = "normal", name = "Normal", weight = 1000, mult = 1, luckWeight = 0 },
	{ id = "shiny", name = "Reluzente", weight = 90, mult = 2, luckWeight = 1, color = Color3.fromRGB(120, 220, 255) },
	{ id = "golden", name = "Dourado", weight = 22, mult = 5, luckWeight = 1, color = Color3.fromRGB(255, 205, 60) },
	{
		id = "rainbow",
		name = "Arco-Íris",
		weight = 4,
		mult = 25,
		luckWeight = 1,
		color = Color3.fromRGB(190, 110, 255),
	},
}

GameConfig.MutationById = {}
for _, mutation in ipairs(GameConfig.Mutations) do
	GameConfig.MutationById[mutation.id] = mutation
end

function GameConfig.getMutation(id)
	return GameConfig.MutationById[id] or GameConfig.Mutations[1]
end

-- weights/total para um dado luck. Puro, testavel fora do Roblox.
function GameConfig.mutationWeights(luck)
	local weights = {}
	local total = 0
	for i, m in ipairs(GameConfig.Mutations) do
		local w = m.weight * (1 + m.luckWeight * (luck - 1) * 0.5)
		weights[i] = w
		total += w
	end
	return weights, total
end

function GameConfig.pickMutation(roll, luck)
	local weights, total = GameConfig.mutationWeights(luck)
	local acc = 0
	for i, w in ipairs(weights) do
		acc += w
		if roll < acc then
			return GameConfig.Mutations[i]
		end
	end
	return GameConfig.Mutations[1], total
end

-- roll precisa de um objeto com :NextNumber() (Random.new() no server, fake nos testes)
function GameConfig.rollMutation(luck, rng)
	local _, total = GameConfig.mutationWeights(luck)
	local roll = rng:NextNumber() * total
	local mutation = GameConfig.pickMutation(roll, luck)
	return mutation
end

---------------------------------------------------------------------------
-- MULTIPLICADORES DERIVADOS
---------------------------------------------------------------------------

function GameConfig.luck(data)
	local base = GameConfig.Upgrades.luck.base
		+ GameConfig.Upgrades.luck.step * (data.upgrades and data.upgrades.luck or 0)
	local cry = GameConfig.CrystalUpgrades.luck.step * (data.crystalUpgrades and data.crystalUpgrades.luck or 0)
	return base + cry
end

function GameConfig.sellMultiplier(data)
	local base = GameConfig.sellUpgradeMult(data.upgrades and data.upgrades.sell or 0)
	local cry = 1 + GameConfig.CrystalUpgrades.sell.step * (data.crystalUpgrades and data.crystalUpgrades.sell or 0)
	return base * cry * GameConfig.rebirthMultiplier(data.rebirths or 0)
end

function GameConfig.growthMultiplier(data)
	local cry = 1 + GameConfig.CrystalUpgrades.growth.step * (data.crystalUpgrades and data.crystalUpgrades.growth or 0)
	return cry
end

function GameConfig.sellValue(data, crop, mutation)
	local value = crop.sell * crop.amount
	value *= mutation.mult
	value *= GameConfig.sellMultiplier(data)
	return math.floor(value)
end

function GameConfig.growTime(data, crop)
	return crop.grow / GameConfig.growthMultiplier(data)
end

---------------------------------------------------------------------------
-- CODIGOS
---------------------------------------------------------------------------

GameConfig.Codes = {
	FARMSTART = { cash = 750, label = "$750" },
	TYCOON = { cash = 2500, crystals = 1, label = "$2.5K + 1 💎" },
	BLOX = { cash = 1000, label = "$1K" },
	REBIRTH = { crystals = 3, label = "3 💎", minLevel = 5 },
}

---------------------------------------------------------------------------
-- SAVE DEFAULT
---------------------------------------------------------------------------

function GameConfig.defaultData()
	return {
		version = GameConfig.DataVersion,
		cash = 60,
		crystals = 0,
		rebirths = 0,
		level = 1,
		xp = 0,
		plots = GameConfig.Plots.Start,
		selectedCrop = "wheat",
		upgrades = { conveyor = 0, sell = 0, luck = 0, auto = 0 },
		crystalUpgrades = { growth = 0, sell = 0, luck = 0 },
		redeemedCodes = {},
		stats = { harvests = 0, earned = 0, bestSale = 0 },
	}
end

return GameConfig
