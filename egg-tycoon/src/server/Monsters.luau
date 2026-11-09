-- Monsters.luau — monstros vivos no mapa.
--
-- Cada ilha tem UM monstro. Ele nasce no centro do campo de batalha, tem
-- vida própria por jogador (cada jogador vê o próprio progresso, senão um
-- jogador forte mata o monstro do novato) e renasce depois de um tempo.
--
-- Por que vida por jogador e não uma barra global:
-- jogo de pet é jogo de progresso SOLO mesmo quando tem gente no servidor.
-- Se a barra fosse global, o novato nunca mataria nada porque o veterano
-- chega antes. Isso é o erro mais comum de tycoon com combate.
--
-- O servidor manda o estado; o cliente desenha. Sem isso o jogador bate e
-- não vê nada acontecer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)

local Monsters = {}

-- [player] = { [biomeId] = { monsterId, health, maxHealth, respawnAt, lastHitAt } }
local state = {}

Monsters.RespawnSeconds = 6

local function now()
	return os.clock()
end

local function blankFor(biomeId, playerLevel)
	local monsterId = Combat.BiomeMonster[biomeId]
	if not monsterId then
		return nil
	end
	local maxHealth = Combat.monsterMaxHealth(monsterId, playerLevel)
	return {
		monsterId = monsterId,
		maxHealth = maxHealth,
		health = maxHealth,
		respawnAt = 0,
		lastHitAt = 0,
	}
end

-- Garante que o jogador tenha estado em todos os biomas que ele abriu.
-- Sem isto, entrar num bioma novo e bater no monstro daria erro de índice.
function Monsters.sync(player, playerLevel, unlockedBiomes)
	local own = state[player]
	if not own then
		own = {}
		state[player] = own
	end
	for biomeId in pairs(unlockedBiomes or {}) do
		if not own[biomeId] and Combat.BiomeMonster[biomeId] then
			own[biomeId] = blankFor(biomeId, playerLevel)
		end
	end
	return own
end

-- Estado para o cliente. Só o bioma atual: mandar os 7 é desperdício.
function Monsters.snapshot(player, data, biomeId)
	local own = state[player] or {}
	local entry = own[biomeId]
	if not entry then
		return nil
	end
	return {
		biome = biomeId,
		monsterId = entry.monsterId,
		health = entry.health,
		maxHealth = entry.maxHealth,
		alive = entry.health > 0,
		respawnIn = entry.health > 0 and 0 or math.max(0, entry.respawnAt - now()),
		-- tipo de monstro do bioma, para o cliente desenhar certo
		tier = (Combat.monsterById[entry.monsterId] or {}).tier or 1,
		name = (Combat.monsterById[entry.monsterId] or {}).name or "Monstro",
	}
end

-- Bate no monstro. Devolve:
--   result = { hit, damage, killed, xp, coins, health, maxHealth, respawnIn }
--   ou nil, motivo quando não pode bater (morto/renascendo).
function Monsters.hit(player, data, biomeId, damage)
	local own = state[player] or {}
	local entry = own[biomeId]

	-- jogador entrou no bioma sem passar pelo sync: cria agora
	if not entry then
		entry = blankFor(biomeId, data.level or 1)
		if not entry then
			return nil, "este bioma não tem monstro"
		end
		if not own[biomeId] then
			own[biomeId] = entry
		end
		state[player] = own
	end

	if entry.health <= 0 then
		local wait = math.max(0, entry.respawnAt - now())
		if wait > 0 then
			return nil, string.format("o monstro volta em %.0fs", math.ceil(wait))
		end
		-- renasceu
		local fresh = blankFor(biomeId, data.level or 1)
		entry.health = fresh.health
		entry.maxHealth = fresh.maxHealth
	end

	entry.lastHitAt = now()
	local newHealth, killed = Combat.applyDamage(entry.health, damage)
	local dealt = entry.health - newHealth
	entry.health = newHealth

	local result = {
		hit = true,
		damage = dealt,
		health = entry.health,
		maxHealth = entry.maxHealth,
		killed = killed,
		xp = 0,
		coins = 0,
		respawnIn = 0,
	}

	if killed then
		local reward = Combat.monsterReward(entry.monsterId, data.level or 1)
		result.xp = reward.xp
		result.coins = reward.coins
		entry.respawnAt = now() + Monsters.RespawnSeconds
		result.respawnIn = Monsters.RespawnSeconds
	end

	return result
end

-- Dano que o monstro faz no jogador (chamado pelo tick quando o jogador
-- está perto do campo). Vida por baixo de zero não existe.
function Monsters.attackPlayer(player, biomeId, playerHealth)
	local own = state[player] or {}
	local entry = own[biomeId]
	if not entry or entry.health <= 0 then
		return playerHealth
	end
	local monster = Combat.monsterById[entry.monsterId]
	if not monster then
		return playerHealth
	end
	local newHealth = math.max(0, playerHealth - monster.damage)
	return newHealth
end

-- Renasce todos os monstros cujo tempo acabou. Chamado no tick.
function Monsters.tick(player, data)
	local own = state[player]
	if not own then
		return
	end
	local t = now()
	for biomeId, entry in pairs(own) do
		if entry.health <= 0 and t >= entry.respawnAt then
			local fresh = blankFor(biomeId, data.level or 1)
			entry.health = fresh.health
			entry.maxHealth = fresh.maxHealth
		end
	end
end

function Monsters.forget(player)
	state[player] = nil
end

return Monsters
