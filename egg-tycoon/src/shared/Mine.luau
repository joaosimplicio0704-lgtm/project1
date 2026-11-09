-- Mine.luau — a Mina dos Pets.
--
-- A mecânica que faltava: até agora o pet só multiplicava renda passiva
-- (Pets.income) e ficava boiando em volta do jogador. Bonito, mas o jogador
-- não FAZIA nada com ele.
--
-- Na mina o pet TRABALHA. Cada pet equipado tem uma vaga. Ele desce, some
-- por alguns segundos e volta carregando um minério — e a QUALIDADE do
-- minério vem da raridade do pet: pet melhor acha coisa melhor. O jogador
-- pode esperar o pet voltar (passivo) ou clicar nele para recolher na hora
-- (ativo, pagando uma taxa para apressar).
--
-- O que isto ensina sem tutorial: pet bom = minério bom. Criança entende em
-- duas voltas.

local Mine = {}

-- Minérios, do mais comum ao mais raro.
-- `weight` é o peso base do sorteio: 100 é o comum, 1 é o lendário.
-- `value` é em moedas quando recolhido.
Mine.ores = {
	{ id = "stone", name = "Pedra", color = { 132, 138, 148 }, value = 240, weight = 100 },
	{ id = "coal", name = "Carvão", color = { 62, 62, 74 }, value = 680, weight = 58 },
	{ id = "iron", name = "Ferro", color = { 196, 152, 120 }, value = 1900, weight = 32 },
	{ id = "gold", name = "Ouro", color = { 248, 200, 74 }, value = 5400, weight = 14 },
	{ id = "emerald", name = "Esmeralda", color = { 78, 216, 132 }, value = 15000, weight = 5 },
	{ id = "diamond", name = "Diamante", color = { 140, 226, 255 }, value = 44000, weight = 2 },
	{ id = "crystal", name = "Cristal", color = { 210, 150, 255 }, value = 130000, weight = 1 },
}

Mine.byId = {}
for _, ore in ipairs(Mine.ores) do
	Mine.byId[ore.id] = ore
end

-- Quanto tempo o pet passa na mina. Curto de propósito: a mecânica é o
-- ciclo (sai, volta, recolhe), não a espera.
Mine.TripSeconds = 7

-- Custo em moedas para apressar o pet que ainda está na mina. É uma
-- porcentagem do valor do minério que ele já achou: apressar nunca é de
-- graça, mas também nunca custa mais do que o próprio minério.
Mine.RushCostRatio = 0.45

-- Peso da raridade no sorteio.
-- Pet comum acha pedra na maioria das vezes. Pet raro multiplica os pesos
-- dos minérios raros — sem isso todo mundo teria diamante no começo e a
-- progressão sumiria.
Mine.RarityBonus = {
	common = { stone = 1.0, coal = 1.0, iron = 1.0, gold = 1.0, emerald = 1.0, diamond = 1.0, crystal = 1.0 },
	uncommon = { stone = 0.7, coal = 1.3, iron = 1.5, gold = 1.2, emerald = 1.1, diamond = 1.0, crystal = 1.0 },
	rare = { stone = 0.4, coal = 0.8, iron = 1.6, gold = 2.0, emerald = 1.8, diamond = 1.4, crystal = 1.2 },
	epic = { stone = 0.2, coal = 0.4, iron = 0.9, gold = 2.0, emerald = 2.6, diamond = 2.2, crystal = 1.8 },
	legendary = { stone = 0.05, coal = 0.15, iron = 0.4, gold = 1.1, emerald = 2.4, diamond = 3.2, crystal = 2.8 },
	secret = { stone = 0.0, coal = 0.05, iron = 0.15, gold = 0.6, emerald = 2.0, diamond = 3.6, crystal = 4.5 },
}

-- Sorteia um minério. `roll` é 0..1 (vem do servidor, para ser testável).
-- Devolve o minério e o peso acumulado usado, para o teste conferir que
-- pet melhor realmente acha coisa melhor.
function Mine.rollOre(rarity, roll)
	local bonus = Mine.RarityBonus[rarity] or Mine.RarityBonus.common

	local total = 0
	for _, ore in ipairs(Mine.ores) do
		total = total + ore.weight * (bonus[ore.id] or 1)
	end
	if total <= 0 then
		return Mine.ores[1], 0
	end

	local target = math.clamp(roll, 0, 1) * total
	local acc = 0
	for _, ore in ipairs(Mine.ores) do
		acc = acc + ore.weight * (bonus[ore.id] or 1)
		if target <= acc then
			return ore, acc
		end
	end
	return Mine.ores[#Mine.ores], total
end

-- Probabilidade de sair cada minério, por raridade. Usado pelo painel
-- ("o que seu pet pode achar") e pelos testes.
function Mine.chances(rarity)
	local bonus = Mine.RarityBonus[rarity] or Mine.RarityBonus.common
	local total = 0
	for _, ore in ipairs(Mine.ores) do
		total = total + ore.weight * (bonus[ore.id] or 1)
	end
	local out = {}
	for _, ore in ipairs(Mine.ores) do
		out[ore.id] = total > 0 and (ore.weight * (bonus[ore.id] or 1) / total) or 0
	end
	return out
end

-- Quanto custa apressar um pet (em moedas).
function Mine.rushCost(ore)
	if not ore then
		return 0
	end
	return math.floor(ore.value * Mine.RushCostRatio)
end

-- Progresso da viagem, 0..1. `elapsed` em segundos.
function Mine.progress(elapsed)
	return math.clamp(elapsed / Mine.TripSeconds, 0, 1)
end

return Mine
