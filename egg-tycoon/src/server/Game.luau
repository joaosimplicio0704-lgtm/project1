-- Game
-- Lógica central do servidor: tick de renda, ações do jogador, rebirth.
-- Não desenha nada, não conhece GUI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)
local Pets = require(Shared.Pets)
local Format = require(Shared.Format)

local Sessions = require(script.Parent.Sessions)
local PlayerData = require(script.Parent.PlayerData)
local MineServer = require(script.Parent.MineServer)
local Monsters = require(script.Parent.Monsters)
local Progress = require(script.Parent.Progress)
local Combat = require(Shared.Combat)

local Game = {}

local TICK = 0.25
local remotes
local rng = Random.new(os.time())

function Game.init(remoteSet)
	remotes = remoteSet
	MineServer.init(GameConfig)
end

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

local function toast(session, text, kind)
	remotes.event:FireClient(session.player, Net.EventKind.Toast, { text = text, kind = kind or "info" })
end

local function addCoins(session, amount)
	local data = session.data
	data.coins += amount
	data.stats.coinsEarned += amount
end

local function addGems(session, amount)
	session.data.gems += amount
end

local function bumpQuest(session)
	-- avança quests automaticamente quando o objetivo é atingido
	local data = session.data
	while true do
		local quest = GameConfig.Quests[data.questIndex]
		if not quest then
			break
		end
		if GameConfig.questProgress(data, quest) < quest.target then
			break
		end
		data.questIndex += 1
		addCoins(session, quest.reward)
		toast(session, "✅ " .. quest.text .. "  +🪙" .. string.format("%d", quest.reward), "success")
	end
end

Game.toast = toast
Game.addCoins = addCoins
Game.bumpQuest = bumpQuest

---------------------------------------------------------------------------
-- TICK
---------------------------------------------------------------------------

function Game.tick(dt)
	for player, session in pairs(Sessions.all()) do
		if player.Parent == Players then
			local data = session.data
			Progress.ensure(data)

			-- bônus de nível entra na renda: subir de nível tem que aparecer
			-- no número que o jogador vê crescendo, não só na vida
			local levelBonus = Combat.levelBonus(data.level).income
			local income = Pets.income(data) * levelBonus
			if income > 0 then
				addCoins(session, income * dt)
			end

			-- MONSTRO: nasce de novo e, se o jogador está no bioma dele,
			-- ataca. O ataque é por proximidade do campo (checado no cliente
			-- pelo painel de combate), então aqui só roda quando o jogador
			-- está mesmo naquele bioma.
			Monsters.tick(player, data)
			if session.inCombat then
				session.sinceHit = (session.sinceHit or 0) + dt
				local maxHealth = Combat.playerMaxHealth(data.level)
				if session.sinceHit >= Combat.RegenDelay then
					data.health = Combat.regenerate(data.health or maxHealth, maxHealth, session.sinceHit, dt)
				end
				if (data.health or maxHealth) <= 0 then
					-- morrer não tira pet nem moeda: volta ao spawn com vida
					-- cheia depois de alguns segundos
					data.health = maxHealth
					session.sinceHit = Combat.RegenDelay
					Game.fx.hurt(session, true)
					remotes.event:FireClient(session.player, Net.EventKind.Toast, {
						text = "💀 você caiu! voltando com vida cheia",
						kind = "error",
					})
				end
			else
				-- fora de combate regenera sempre
				local maxHealth = Combat.playerMaxHealth(data.level)
				data.health = Combat.regenerate(data.health or maxHealth, maxHealth, 999, dt)
			end

			bumpQuest(session)
		end
	end
end

function Game.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = math.min(now - last, 2)
			last = now
			Game.tick(dt)
			for player, session in pairs(Sessions.all()) do
				if player.Parent == Players then
					Game.pushSnapshot(session)
				end
			end
		end
	end)

	-- save periódico
	task.spawn(function()
		while true do
			task.wait(30)
			for player, session in pairs(Sessions.all()) do
				if player.Parent == Players then
					PlayerData.markDirty(player.UserId)
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- SNAPSHOT
---------------------------------------------------------------------------

function Game.snapshot(session)
	local data = session.data
	return {
		coins = data.coins,
		gems = data.gems,
		crystals = data.crystals,
		rebirths = data.rebirths,
		pets = data.pets,
		equipped = data.equipped,
		upgrades = data.upgrades,
		gemUpgrades = data.gemUpgrades,
		selectedEgg = data.selectedEgg,
		stats = data.stats,
		questIndex = data.questIndex,
		income = Pets.income(data),
		tapPower = GameConfig.tapPower(data),
		slots = GameConfig.petSlots(data),
		luck = GameConfig.luck(data),
		eggBought = data.eggBought,
		rebirthCost = GameConfig.rebirthCost(GameConfig.rate(data), data.rebirths),
		rate = GameConfig.rate(data),
		-- PROGRESSAO: nível, barra de XP e vida
		progress = Progress.snapshot(data),
		health = data.health or Combat.PlayerMaxHealth,
		maxHealth = Combat.playerMaxHealth(data.level or 1),
		monster = Monsters.snapshot(session.player, data, data.biome or "meadow"),
		mine = MineServer.snapshot(session.player, data),
		mineRate = MineServer.rate(session.player, data),
		biome = data.biome or "meadow",
		biomes = Biomes.unlockedMap({
			hatched = data.stats and data.stats.hatched or 0,
			rebirths = data.rebirths or 0,
		}),
	}
end

function Game.pushSnapshot(session)
	remotes.state:FireClient(session.player, Game.snapshot(session))
end

-- snapshot de estado estático (pets, ovos) — enviado uma vez ao entrar
function Game.staticState()
	local eggs = {}
	for _, egg in ipairs(GameConfig.Eggs) do
		eggs[#eggs + 1] = {
			id = egg.id,
			name = egg.name,
			emoji = egg.emoji,
			cost = egg.cost,
			rarities = egg.drops,
		}
	end
	return {
		eggs = eggs,
		pets = GameConfig.Pets,
		rarities = GameConfig.Rarities,
		upgrades = GameConfig.Upgrades,
		gemUpgrades = GameConfig.GemUpgrades,
		rebirth = GameConfig.Rebirth,
		quests = GameConfig.Quests,
	}
end

---------------------------------------------------------------------------
-- AÇÕES
---------------------------------------------------------------------------

local function fail(session, message)
	toast(session, message, "error")
	return false, message
end

-- Ganchos preenchidos pelo init.server (o Game nao conhece jogador/CFrame).
Game.arrivalFor = function() end
-- Feedback no mundo: cada acao deixa rastro visivel (moeda, anel, pet).
-- Sem isto a mecanica so muda numeros no painel e quem olha o mapa nao ve
-- jogo nenhum acontecendo.
Game.fx = {
	tap = function() end,
	hatch = function() end,
	equip = function() end,
	upgrade = function() end,
	rebirth = function() end,
	mine = function() end,
	hit = function() end,
	levelUp = function() end,
	hurt = function() end,
	offline = function() end,
}

Game.handlers = {}

-- COMBATE
-- Bater no monstro é a ação central do jogo agora. O dano é calculado no
-- SERVIDOR com o nível real do jogador: confiar no número que o cliente
-- manda seria deixar qualquer um matar em um toque.
function Game.handlers.hit(session, payload)
	local data = session.data
	Progress.ensure(data)
	local biomeId = data.biome or "meadow"

	-- jogador + pets equipados: o pet entra no dano, não só na recompensa.
	-- O pet é limitado a uma fração do acerto do jogador (Progress.PetMaxShare),
	-- então a ordem importa: calcula o acerto do jogador primeiro.
	local playerHit = Combat.playerDamage(data.level, GameConfig.tapPower(data))
	local petDamage = Progress.petDamage(data, playerHit)
	local damage = playerHit + petDamage
	local result, reason = Monsters.hit(session.player, data, biomeId, damage)
	if not result then
		return fail(session, reason or "não consegui bater")
	end

	-- todo mundo equipado ganha XP por participar da briga
	local petLevelUps = {}
	if result.killed then
		local rewards = Progress.awardPetKill(data, result.xp)
		for _, r in ipairs(rewards) do
			if r.leveled then
				petLevelUps[#petLevelUps + 1] = r
			end
		end
	end

	local xpInfo = nil
	if result.killed then
		addCoins(session, result.coins)
		xpInfo = Progress.addXp(data, result.xp, "kill")
		if xpInfo.leveled then
			-- subir de nível cura cheio: recompensa que a criança SENTE
			data.health = Combat.playerMaxHealth(data.level)
		end
		Game.fx.hit(session, result, true)
	else
		Game.fx.hit(session, result, false)
	end

	remotes.event:FireClient(session.player, Net.EventKind.Hit, {
		damage = result.damage,
		health = result.health,
		maxHealth = result.maxHealth,
		killed = result.killed,
		coins = result.coins,
		respawnIn = result.respawnIn,
		xp = xpInfo,
		petLevelUps = petLevelUps,
		level = data.level,
	})
	if xpInfo and xpInfo.leveled then
		Game.fx.levelUp(session, xpInfo.level)
	end

	Game.pushSnapshot(session)
	return true
end

-- O cliente avisa que entrou/saiu do raio da arena. O servidor usa isso
-- para saber se o monstro está atacando e se a regeneração está pausada.
-- Vida é do servidor; só a POSIÇÃO vem do cliente.
function Game.handlers.setCombat(session, payload)
	session.inCombat = payload and true or false
	if session.inCombat then
		session.sinceHit = 0
	end
	return true
end

function Game.handlers.tap(session, payload)
	local data = session.data
	local count = math.clamp(tonumber(payload) or 1, 1, 10)
	local gained = GameConfig.tapPower(data) * count
	addCoins(session, gained)
	data.stats.taps += count
	Game.fx.tap(session, gained)
	bumpQuest(session)
	return true
end

function Game.handlers.hatch(session, payload)
	local data = session.data
	local egg = GameConfig.egg(data.selectedEgg)
	if not egg then
		return fail(session, "ovo inválido")
	end
	local bought = data.eggBought[egg.id] or 0
	local price = GameConfig.eggPrice(egg.id, bought)
	if data.coins < price then
		return fail(session, "faltam moedas")
	end
	if Pets.storageFull(data) then
		return fail(session, "inventário cheio — venda alguns pets")
	end
	data.coins -= price
	data.eggBought[egg.id] = bought + 1
	local pet =
		GameConfig.rollPet(egg.id, rng:NextNumber(), rng:NextNumber(), GameConfig.SecretChance / GameConfig.luck(data))
	if not pet then
		return fail(session, "erro ao abrir ovo")
	end
	local instance = Pets.add(data, pet.id, false)

	-- auto-venda: descarta o que é pior que o pior equipado (inventário não trava)
	local soldCount, soldValue = Pets.sellWorseThanEquipped(data)
	Pets.autoEquip(data)
	if soldCount > 0 then
		toast(session, string.format("🪙 %d pets auto-vendidos · +%s", soldCount, Format.number(soldValue)), "info")
	end

	Progress.awardSource(data, "hatch")
	bumpQuest(session)
	remotes.event:FireClient(
		session.player,
		Net.EventKind.Hatch,
		{ petId = pet.id, uid = instance.uid, rarity = pet.rarity }
	)
	Game.fx.hatch(session, pet, instance)
	return true
end

-- MINA DOS PETS
-- Recolhe o minério que os pets trouxeram. Sem uid, recolhe todos os prontos.
function Game.handlers.collectMine(session, uid)
	local data = session.data
	local collected, coins = MineServer.collect(session.player, data, tonumber(uid))
	if #collected == 0 then
		return fail(session, "nenhum pet voltou ainda")
	end

	addCoins(session, coins)

	local best = collected[1].ore
	for _, entry in ipairs(collected) do
		if entry.ore.value > best.value then
			best = entry.ore
		end
	end

	remotes.event:FireClient(session.player, Net.EventKind.Mine, {
		ores = (function()
			local out = {}
			for _, entry in ipairs(collected) do
				out[#out + 1] =
					{ id = entry.ore.id, name = entry.ore.name, color = entry.ore.color, value = entry.ore.value }
			end
			return out
		end)(),
		coins = coins,
		best = { id = best.id, name = best.name, color = best.color },
	})
	Game.fx.mine(session, best)
	Game.pushSnapshot(session)
	return true
end

-- Apressa um pet que está na mina.
function Game.handlers.rushMine(session, uid)
	local ok, reason = MineServer.rush(session.player, session.data, tonumber(uid))
	if not ok then
		return fail(session, reason)
	end
	Game.pushSnapshot(session)
	return true
end

function Game.handlers.equip(session, uid)
	local data = session.data
	uid = tonumber(uid)
	local ok, reason = Pets.equip(data, uid)
	if not ok then
		return fail(session, reason)
	end
	MineServer.sync(session.player, session.data)
	Game.fx.equip(session)
	return true
end

function Game.handlers.unequip(session, uid)
	Pets.unequip(session.data, tonumber(uid))
	MineServer.sync(session.player, session.data)
	Game.fx.equip(session)
	return true
end

function Game.handlers.selectEgg(session, eggId)
	local egg = GameConfig.egg(eggId)
	if not egg then
		return fail(session, "ovo inválido")
	end
	session.data.selectedEgg = eggId
	return true
end

function Game.handlers.buyUpgrade(session, kind)
	local data = session.data
	local tier = data.upgrades[kind]
	if tier == nil then
		return fail(session, "upgrade inválido")
	end
	local cost = GameConfig.upgradeCost(kind, tier)
	if not cost then
		return fail(session, "nível máximo")
	end
	if data.coins < cost then
		return fail(session, "faltam moedas")
	end
	data.coins -= cost
	data.upgrades[kind] = tier + 1
	Game.fx.upgrade(session, kind, tier + 1)
	bumpQuest(session)
	return true
end

function Game.handlers.buyGemUpgrade(session, kind)
	local data = session.data
	local rank = data.gemUpgrades[kind]
	if rank == nil then
		return fail(session, "melhoria inválida")
	end
	local cost = GameConfig.gemCost(kind, rank)
	if not cost then
		return fail(session, "rank máximo")
	end
	if data.gems < cost then
		return fail(session, "faltam gemas")
	end
	data.gems -= cost
	data.gemUpgrades[kind] = rank + 1
	return true
end

function Game.handlers.rebirth(session)
	local data = session.data
	if data.rebirths >= GameConfig.Rebirth.Max then
		return fail(session, "rebirth máximo")
	end
	local cost = GameConfig.rebirthCost(GameConfig.rate(data), data.rebirths)
	if data.coins < cost then
		return fail(session, "faltam " .. Format.number(cost) .. " moedas")
	end

	local crystals = GameConfig.rebirthCrystals(data.rebirths)
	local fresh = GameConfig.defaultData()
	fresh.rebirths = data.rebirths + 1
	fresh.crystals = data.crystals + crystals
	fresh.gems = data.gems
	fresh.gemUpgrades = data.gemUpgrades
	fresh.questIndex = data.questIndex
	fresh.selectedEgg = data.selectedEgg
	fresh.stats = data.stats
	fresh.nextUid = data.nextUid
	-- a coleção de pets é permanente: só moedas, upgrades e ovos comprados resetam
	fresh.pets = data.pets
	fresh.equipped = data.equipped
	fresh.eggBought = {}

	for key, value in pairs(fresh) do
		data[key] = value
	end

	Pets.autoEquip(data)
	remotes.event:FireClient(session.player, Net.EventKind.Rebirth, { rebirths = data.rebirths, crystals = crystals })
	Game.fx.rebirth(session, data.rebirths)
	return true
end

function Game.handlers.sellPet(session, uid)
	local ok, value = Pets.sell(session.data, tonumber(uid))
	if not ok then
		return fail(session, value)
	end
	toast(session, "🪙 +" .. Format.number(value), "success")
	return true
end

function Game.handlers.fuse(session, uids)
	if type(uids) ~= "table" then
		return fail(session, "seleção inválida")
	end
	local ok, result = Pets.fuse(session.data, uids)
	if not ok then
		return fail(session, result)
	end
	toast(session, "✨ " .. GameConfig.pet(result.petId).name, "success")
	return true
end

function Game.handlers.setZone(session, zone)
	-- o servidor informa ao cliente qual UI abrir; usado pelo mundo
	return true
end

-- Viagem entre biomas. O cliente manda o id; o servidor confere o desbloqueio
-- com os dados da sessao e so entao autoriza. Nunca confiar no cliente: sem
-- isso um jogador com 0 rebirths abriria a nebulosa cosmica clicando no portal.
function Game.handlers.travel(session, biomeId)
	local data = session.data
	local biome = Biomes.ById[biomeId]
	if not biome then
		return false, "Mundo desconhecido"
	end

	local unlocked = Biomes.unlockedMap({
		hatched = data.stats and data.stats.hatched or 0,
		rebirths = data.rebirths or 0,
	})

	if not unlocked[biomeId] then
		return false, "🔒 " .. biome.name .. " — " .. Biomes.unlockLabel(biome)
	end

	data.biome = biomeId
	Game.arrivalFor(session, biomeId)
	return true
end

Game.handlers.claimQuest = function(session)
	bumpQuest(session)
	return true
end

-- golden pet event: converte um pet aleatório em dourado
function Game.handlers.golden(session)
	local data = session.data
	local pool = {}
	for _, instance in ipairs(data.pets) do
		if not instance.golden then
			pool[#pool + 1] = instance
		end
	end
	if #pool == 0 then
		return fail(session, "nenhum pet para dourar")
	end
	if data.coins < 50000 then
		return fail(session, "faltam 50K moedas")
	end
	data.coins -= 50000
	local target = pool[rng:NextInteger(1, #pool)]
	target.golden = true
	toast(session, "🌟 " .. GameConfig.pet(target.petId).name .. " ficou dourado!", "success")
	return true
end

function Game.handle(session, kind, payload)
	local handler = Game.handlers[kind]
	if not handler then
		return false, "ação desconhecida"
	end
	local ok, reason = handler(session, payload)
	if ok == nil then
		-- handler antigo sem retorno explicito: trata como sucesso, nunca nil
		return true
	end
	return ok, reason
end

return Game
