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

local Game = {}

local TICK = 0.25
local remotes
local rng = Random.new(os.time())

function Game.init(remoteSet)
	remotes = remoteSet
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
			local income = Pets.income(data)
			if income > 0 then
				addCoins(session, income * dt)
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

Game.handlers = {}

function Game.handlers.tap(session, payload)
	local data = session.data
	local count = math.clamp(tonumber(payload) or 1, 1, 10)
	addCoins(session, GameConfig.tapPower(data) * count)
	data.stats.taps += count
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

	bumpQuest(session)
	remotes.event:FireClient(
		session.player,
		Net.EventKind.Hatch,
		{ petId = pet.id, uid = instance.uid, rarity = pet.rarity }
	)
	return true
end

function Game.handlers.equip(session, uid)
	local data = session.data
	uid = tonumber(uid)
	local ok, reason = Pets.equip(data, uid)
	if not ok then
		return fail(session, reason)
	end
	return true
end

function Game.handlers.unequip(session, uid)
	Pets.unequip(session.data, tonumber(uid))
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
