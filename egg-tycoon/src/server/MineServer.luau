-- MineServer.luau — o ciclo da Mina dos Pets no servidor.
--
-- Cada pet EQUIPADO tem uma viagem em andamento. O ciclo é:
--   1. o pet sai (estado "away"), com um minério já sorteado no embarque
--   2. depois de Mine.TripSeconds ele fica "ready" — o minério está na mão
--   3. o jogador recolhe (ou o auto-recolhe faz sozinho, se comprado)
--   4. o pet sai de novo
--
-- O minério é sorteado no EMBARQUE, não na volta. Parece detalhe, mas não é:
-- assim o jogador pode clicar para apressar sabendo o que vai receber, e o
-- valor da taxa é honesto.
--
-- Tudo aqui é determinístico dado o timestamp: o teste consegue rodar o
-- ciclo inteiro sem esperar 7 segundos de verdade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mine = require(ReplicatedStorage.Shared.Mine)

local MineServer = {}

-- [player] = { [uid] = { ore = <ore>, startedAt = <clock>, readyAt = <clock> } }
local trips = {}

-- Raridade do pet, para o sorteio. Vem do GameConfig, que é a fonte única.
local config
function MineServer.init(gameConfig)
	config = gameConfig
end

local function now()
	return os.clock()
end

local function newTrip(rarity, rng)
	local ore = Mine.rollOre(rarity, rng())
	return {
		ore = ore,
		startedAt = now(),
		readyAt = now() + Mine.TripSeconds,
	}
end

-- Garante que todo pet equipado tenha uma viagem. Chamar sempre que o jogador
-- equipa, desequipa, entra ou troca de pet: assim a mina nunca fica com vaga
-- fantasma nem com pet trabalhando sem estar equipado.
function MineServer.sync(player, data)
	-- Chave de tabela NÃO pode ser nil em Lua: `trips[nil] = x` é erro de
	-- execução, não de lógica. No jogo player nunca é nil, mas isto aqui é
	-- chamado por snapshot/rate/collect em cadeia, e uma chamada sem player
	-- derrubava o servidor inteiro em silêncio.
	local key = player or "anon"
	local own = trips[key]
	if not own then
		own = {}
		trips[key] = own
	end

	local equipped = {}
	for _, uid in ipairs(data.equipped or {}) do
		equipped[uid] = true
	end

	-- pet que saiu do equipamento perde a vaga
	for uid in pairs(own) do
		if not equipped[uid] then
			own[uid] = nil
		end
	end

	-- pet equipado sem viagem ganha uma
	local rng = Random.new(#data.equipped * 7919 + (data.stats and data.stats.hatched or 0))
	for _, uid in ipairs(data.equipped or {}) do
		if not own[uid] then
			local instance = nil
			for _, pet in ipairs(data.pets or {}) do
				if pet.uid == uid then
					instance = pet
					break
				end
			end
			if instance then
				local pet = config.pet(instance.petId)
				if pet then
					own[uid] = newTrip(pet.rarity, function()
						return rng:NextNumber()
					end)
				end
			end
		end
	end
end

-- Estado atual da mina para o cliente. `progress` é 0..1; `ore` só vai
-- quando o pet já voltou (senão o cliente saberia o prêmio antes da hora).
function MineServer.snapshot(player, data)
	MineServer.sync(player, data)
	local own = trips[player or "anon"] or {}
	local t = now()
	local out = {}

	for _, uid in ipairs(data.equipped or {}) do
		local trip = own[uid]
		if trip then
			local ready = t >= trip.readyAt
			out[#out + 1] = {
				uid = uid,
				progress = Mine.progress(t - trip.startedAt),
				ready = ready,
				oreId = ready and trip.ore.id or nil,
				oreName = ready and trip.ore.name or nil,
				-- o que o pet está buscando: pode mostrar, é o que dá vontade
				-- de esperar. O VALOR é que fica escondido até voltar.
				oreColor = ready and trip.ore.color or nil,
				rushCost = ready and 0 or Mine.rushCost(trip.ore),
			}
		end
	end

	return {
		trips = out,
		best = (data.mine and data.mine.best) or "",
		dug = (data.mine and data.mine.total) or 0,
		tripSeconds = Mine.TripSeconds,
		ores = Mine.ores,
	}
end

-- Recolhe o que o pet trouxe. `uid` nil = recolhe todos os prontos.
-- Devolve uma lista de { ore = <ore>, uid = <uid> } recolhidos e o total.
function MineServer.collect(player, data, uid)
	MineServer.sync(player, data)
	local own = trips[player or "anon"] or {}
	local t = now()
	local collected = {}
	local coins = 0

	local function take(u)
		local trip = own[u]
		if not trip or t < trip.readyAt then
			return
		end
		collected[#collected + 1] = { ore = trip.ore, uid = u }
		coins = coins + trip.ore.value
		data.mine.dug[u] = (data.mine.dug[u] or 0) + 1
		data.mine.total = (data.mine.total or 0) + 1
		-- melhor minério já achado: guarda o de maior valor
		local best = Mine.byId[data.mine.best]
		if not best or trip.ore.value > best.value then
			data.mine.best = trip.ore.id
		end
		-- o pet já sai para a próxima: sem isso o jogador recolhe uma vez e
		-- a mina morre até ele sair e voltar do bioma
		local instance = nil
		for _, pet in ipairs(data.pets or {}) do
			if pet.uid == u then
				instance = pet
				break
			end
		end
		if instance then
			local pet = config.pet(instance.petId)
			if pet then
				local rng = Random.new(t * 1000 + u)
				own[u] = newTrip(pet.rarity, function()
					return rng:NextNumber()
				end)
			end
		end
	end

	if uid then
		take(uid)
	else
		-- BUG que isto evita: `take` recria a viagem (own[u] = newTrip...),
		-- então iterar `pairs(own)` enquanto ele escreve na tabela pode
		-- pular pet ou rodar para sempre. Coleta a lista ANTES.
		local uids = {}
		for u in pairs(own) do
			uids[#uids + 1] = u
		end
		for _, u in ipairs(uids) do
			take(u)
		end
	end

	return collected, coins
end

-- Apressa um pet: cobra o custo e libera o minério na hora.
-- Devolve ok, motivo.
function MineServer.rush(player, data, uid)
	MineServer.sync(player, data)
	local own = trips[player or "anon"] or {}
	local trip = own[uid]
	if not trip then
		return false, "esse pet não está na mina"
	end
	if now() >= trip.readyAt then
		return false, "já voltou — recolha"
	end
	local cost = Mine.rushCost(trip.ore)
	if data.coins < cost then
		return false, "faltam moedas para apressar"
	end
	data.coins = data.coins - cost
	trip.readyAt = now()
	return true
end

-- Quanto a mina rende por segundo no total (todos os pets prontos ou não).
-- Serve para o painel mostrar "isto vale X por minuto" e o jogador comparar
-- com a renda passiva.
function MineServer.rate(player, data)
	MineServer.sync(player, data)
	local own = trips[player or "anon"] or {}
	local total = 0
	for _, trip in pairs(own) do
		total = total + trip.ore.value
	end
	if total <= 0 then
		return 0
	end
	return total / Mine.TripSeconds
end

function MineServer.forget(player)
	trips[player or "anon"] = nil
end

return MineServer
