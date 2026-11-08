-- Pets
-- Estado dos pets de UM jogador: inventário, equipar, renda passiva, fusão.
-- Puro: não conhece `game`, recebe data e devolve resultados.

local GameConfig = require(script.Parent.GameConfig)

local Pets = {}

local MAX_EQUIPPED = 99

function Pets.new(data)
	return data
end

function Pets.find(data, uid)
	for index, instance in ipairs(data.pets) do
		if instance.uid == uid then
			return instance, index
		end
	end
	return nil
end

function Pets.isEquipped(data, uid)
	for _, id in ipairs(data.equipped) do
		if id == uid then
			return true
		end
	end
	return false
end

-- Adiciona um pet novo. Retorna a instância criada.
function Pets.add(data, petId, golden)
	local pet = GameConfig.pet(petId)
	if not pet then
		return nil
	end

	local instance = {
		uid = data.nextUid,
		petId = petId,
		golden = golden or false,
	}
	data.nextUid += 1
	table.insert(data.pets, instance)

	-- raridade maxima já obtida (para a UI mostrar progresso)
	local order = GameConfig.rarity(pet.rarity).order
	if order > (data.stats.bestRarity or 0) then
		data.stats.bestRarity = order
	end
	data.stats.hatched += 1

	return instance
end

-- Equipa se houver slot livre. Retorna ok, motivo.
function Pets.equip(data, uid)
	local instance = Pets.find(data, uid)
	if not instance then
		return false, "pet não encontrado"
	end
	if Pets.isEquipped(data, uid) then
		return false, "já equipado"
	end
	if #data.equipped >= GameConfig.petSlots(data) then
		return false, "sem espaço — compre mais slots"
	end
	table.insert(data.equipped, uid)
	return true
end

function Pets.unequip(data, uid)
	for index, id in ipairs(data.equipped) do
		if id == uid then
			table.remove(data.equipped, index)
			return true
		end
	end
	return false
end

-- Valor efetivo de um pet (renda com bônus dourado)
local function petValue(instance)
	local pet = GameConfig.pet(instance.petId)
	if not pet then
		return 0
	end
	return pet.income * (instance.golden and 1.5 or 1)
end
Pets.value = petValue

-- Equipa o MELHOR conjunto possível: monta a lista do zero e não só preenche
-- slot vazio. Sem isso, o jogador fica preso com os primeiros pets para sempre.
function Pets.autoEquip(data)
	local slots = GameConfig.petSlots(data)
	local ranked = {}
	for _, instance in ipairs(data.pets) do
		if petValue(instance) > 0 then
			ranked[#ranked + 1] = instance
		end
	end
	table.sort(ranked, function(a, b)
		return petValue(a) > petValue(b)
	end)

	local equipped = {}
	for index = 1, math.min(slots, #ranked) do
		equipped[index] = ranked[index].uid
	end
	data.equipped = equipped
end

-- Auto-venda: pets piores que o pior equipado viram moedas.
-- Retorna quantos foram vendidos e quanto rendeu.
function Pets.sellWorseThanEquipped(data)
	if #data.pets == 0 then
		return 0, 0
	end

	local weakest = math.huge
	for _, uid in ipairs(data.equipped) do
		local instance = Pets.find(data, uid)
		if instance then
			weakest = math.min(weakest, petValue(instance))
		end
	end
	if weakest == math.huge then
		return 0, 0
	end

	local count, total = 0, 0
	for index = #data.pets, 1, -1 do
		local instance = data.pets[index]
		if not Pets.isEquipped(data, instance.uid) and petValue(instance) < weakest then
			total += Pets.sellValue(instance)
			table.remove(data.pets, index)
			count += 1
		end
	end

	data.coins += total
	data.stats.coinsEarned += total
	return count, total
end

function Pets.income(data)
	return GameConfig.equippedIncome(data)
end

-- Vende um pet por moedas (proporcional à renda).
function Pets.sellValue(instance)
	local pet = GameConfig.pet(instance.petId)
	if not pet then
		return 0
	end
	return math.floor(pet.income * 120 * (instance.golden and 1.5 or 1))
end

function Pets.sell(data, uid)
	local instance, index = Pets.find(data, uid)
	if not instance then
		return false, "pet não encontrado"
	end
	local value = Pets.sellValue(instance)
	Pets.unequip(data, uid)
	table.remove(data.pets, index)
	data.coins += value
	data.stats.coinsEarned += value
	return true, value
end

-- Fusão: junta 3 pets do mesmo raro+ e devolve 1 do próximo tier.
-- Retorna ok, petResultante | motivo
function Pets.fuse(data, uids)
	if #uids ~= 3 then
		return false, "precisa de 3 pets"
	end

	local targetId, targetGolden
	local rarityOrder = -1

	for _, uid in ipairs(uids) do
		local instance = Pets.find(data, uid)
		if not instance then
			return false, "pet não encontrado"
		end
		local pet = GameConfig.pet(instance.petId)
		if not pet then
			return false, "pet inválido"
		end
		local order = GameConfig.rarity(pet.rarity).order
		if order < 3 then
			return false, "só pets Raro+ podem ser fundidos"
		end
		if targetId then
			if pet.id ~= targetId then
				return false, "os 3 pets precisam ser iguais"
			end
		else
			targetId = pet.id
			targetGolden = instance.golden
			rarityOrder = order
		end
	end

	-- Fusão: escolhe o pet de menor renda com raridade ESTRITAMENTE acima.
	-- Sempre existe um tier acima, então a fusão nunca morre num pet de topo de ovo.
	local base = GameConfig.pet(targetId)
	local upgrade
	local bestIncome = math.huge
	for _, pet in ipairs(GameConfig.Pets) do
		if not pet.secret and GameConfig.rarity(pet.rarity).order > rarityOrder then
			if pet.income < bestIncome then
				bestIncome = pet.income
				upgrade = pet
			end
		end
	end

	-- segurança extra: se o resultado for pior que a base, não funde
	if upgrade and upgrade.income <= base.income then
		upgrade = nil
	end

	if not upgrade then
		return false, "não há tier acima para fundir"
	end

	-- consome os 3
	for _, uid in ipairs(uids) do
		local _, index = Pets.find(data, uid)
		if index then
			Pets.unequip(data, uid)
			table.remove(data.pets, index)
		end
	end

	local created = Pets.add(data, upgrade.id, targetGolden)
	return true, created
end

-- Capacidade total de pets no inventário
Pets.MAX_STORAGE = 200

function Pets.storageFull(data)
	return #data.pets >= Pets.MAX_STORAGE
end

return Pets
