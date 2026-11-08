-- Farm
-- Estado da fazenda de UM jogador e a simulacao da esteira.
--
-- Loop: cada plot plantado gera uma unidade quando amadurece. A unidade anda
-- pela esteira (posicao 0..1), chega no ponto de venda e vira caixa. Toda a
-- fisica e cinematica e roda no servidor a 10 Hz dentro de Economy.step.
--
-- Nenhuma renderizacao aqui. O cliente le o snapshot e desenha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Farm = {}
Farm.__index = Farm

local CONVEYOR_LENGTH = 18 -- studs, comprimento visual da esteira

function Farm.new(data, rng)
	local self = setmetatable({}, Farm)
	self.data = data
	self.rng = rng or Random.new()
	self.plots = {} -- [i] = { cropId, mutationId, value, ready, progress } | false
	self.items = {} -- [id] = { id, cropId, mutationId, value, pos }
	self.nextItemId = 1
	for i = 1, GameConfig.Plots.Max do
		self.plots[i] = false
	end
	return self
end

---------------------------------------------------------------------------
-- PLOTS
---------------------------------------------------------------------------

function Farm:plant(index, cropId, mutationId)
	local crop = GameConfig.getCrop(cropId)
	if not crop then
		return false
	end
	self.plots[index] = {
		cropId = cropId,
		mutationId = mutationId or "normal",
		value = GameConfig.sellValue(self.data, crop, GameConfig.getMutation(mutationId or "normal")),
		ready = false,
		progress = 0,
		growTime = GameConfig.growTime(self.data, crop),
	}
	return true
end

function Farm:harvest(index)
	local slot = self.plots[index]
	if not slot or not slot.ready then
		return nil
	end

	local item = {
		id = self.nextItemId,
		cropId = slot.cropId,
		mutationId = slot.mutationId,
		value = slot.value,
		pos = 0,
	}
	self.nextItemId += 1
	self.items[item.id] = item
	self.plots[index] = false

	return item
end

---------------------------------------------------------------------------
-- ESTEIRA
---------------------------------------------------------------------------

function Farm:speed()
	return GameConfig.conveyorSpeed(self.data.upgrades.conveyor)
end

-- Retorna a lista de itens vendidos neste step (quem chama aplica cash/xp).
-- Cultura madura vai SOZINHA pra esteira: e o coracao do loop de tycoon.
function Farm:step(dt)
	local speed = self:speed()
	local traveled = (speed / CONVEYOR_LENGTH) * dt
	local sold

	for id, item in pairs(self.items) do
		item.pos += traveled
		if item.pos >= 1 then
			self.items[id] = nil
			sold = sold or {}
			sold[#sold + 1] = item
		end
	end

	local doubleChance = GameConfig.doubleChance(self.data.upgrades.auto or 0)
	for i = 1, self.data.plots do
		local slot = self.plots[i]
		if slot and not slot.ready then
			slot.progress += dt / slot.growTime
			if slot.progress >= 1 then
				slot.progress = 1
				slot.ready = true
				-- Colheita Dupla: chance de sair um item extra na mesma colheita
				local extra = doubleChance > 0 and self.rng:NextNumber() < doubleChance
				local mutationId, value = slot.mutationId, slot.value
				self:harvest(i)
				if extra then
					local bonus = {
						id = self.nextItemId,
						cropId = slot.cropId,
						mutationId = mutationId,
						value = value,
						pos = 0,
					}
					self.nextItemId += 1
					self.items[bonus.id] = bonus
				end
			end
		end
	end

	return sold
end

function Farm:pendingValue()
	local total = 0
	for _, item in pairs(self.items) do
		total += item.value
	end
	return total
end

function Farm:dump()
	local plots = {}
	for i = 1, GameConfig.Plots.Max do
		local slot = self.plots[i]
		if slot then
			plots[i] = {
				cropId = slot.cropId,
				mutationId = slot.mutationId,
				progress = slot.progress,
				ready = slot.ready,
				value = slot.value,
			}
		end
	end

	local items = {}
	for _, item in pairs(self.items) do
		items[#items + 1] = {
			id = item.id,
			cropId = item.cropId,
			mutationId = item.mutationId,
			value = item.value,
			pos = item.pos,
		}
	end
	table.sort(items, function(a, b)
		return a.pos > b.pos
	end)

	return {
		plots = plots,
		items = items,
		activePlots = self.data.plots,
		speed = self:speed(),
		pending = self:pendingValue(),
	}
end

return Farm
