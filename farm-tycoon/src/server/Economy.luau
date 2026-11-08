-- Economy
-- Loop autoritativo: fazenda avanca, itens vendem, cash/xp/level sobem.
-- Tambem concentra as compras (upgrades, plots, rebirth, codes) para que
-- toda validacao de custo aconteca num lugar so.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local Farm = require(script.Parent.Farm)
local Sessions = require(script.Parent.Sessions)
local PlayerData = require(script.Parent.PlayerData)

local Economy = {}

local TICK = 0.1

local remotes
local rng = Random.new(os.clock() * 1000)

function Economy.init(remoteSet)
	remotes = remoteSet
end

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

local function toast(player, text, color)
	remotes.event:FireClient(player, Net.EventKind.Toast, { text = text, color = color })
end

function Economy.notify(player, text, color)
	toast(player, text, color)
end

local function grantXp(session, amount)
	local data = session.data
	if data.level >= GameConfig.MaxLevel then
		return
	end

	data.xp += amount
	while data.level < GameConfig.MaxLevel do
		local need = GameConfig.xpNeeded(data.level)
		if data.xp < need then
			break
		end
		data.xp -= need
		data.level += 1
		remotes.event:FireClient(session.player, Net.EventKind.LevelUp, { level = data.level })
	end
	if data.level >= GameConfig.MaxLevel then
		data.xp = 0
	end
end

function Economy.autoplant(session)
	local data = session.data
	local farm = session.farm
	local crop = GameConfig.getCrop(data.selectedCrop) or GameConfig.bestCropForLevel(data.level)
	if crop.level > data.level then
		crop = GameConfig.bestCropForLevel(data.level)
		data.selectedCrop = crop.id
	end

	for i = 1, data.plots do
		if not farm.plots[i] then
			-- bailout: sem cash, sem nada plantado e sem item na esteira -> trigo de graca
			local broke = data.cash < crop.seed
			local empty = next(farm.items) == nil
			if broke then
				local anyPlanted = false
				for p = 1, data.plots do
					if farm.plots[p] then
						anyPlanted = true
						break
					end
				end
				if not anyPlanted and empty then
					crop = GameConfig.getCrop("wheat")
					farm:plant(i, crop.id, GameConfig.rollMutation(GameConfig.luck(data), rng).id)
					continue
				end
				return
			end
			data.cash -= crop.seed
			local mutation = GameConfig.rollMutation(GameConfig.luck(data), rng)
			farm:plant(i, crop.id, mutation.id)
		end
	end
end

-- Manda tudo que esta na esteira direto pro caixa (tecla F / botao).
-- Reaproveita o mesmo caminho de venda do step, entao cash/xp/eventos batem.
function Economy.rushBelt(session)
	local farm = session.farm
	local total = 0
	local xp = 0
	local count = 0
	for id, item in pairs(farm.items) do
		farm.items[id] = nil
		total += item.value
		count += 1
		local crop = GameConfig.getCrop(item.cropId)
		xp += crop and crop.xp or 0
	end
	if count == 0 then
		return 0
	end
	Economy.creditSale(session, total, xp, count)
	return count
end

-- Aplica uma venda: cash, xp, stats, evento pro cliente.
function Economy.creditSale(session, total, xp, count)
	local data = session.data
	data.cash += total
	data.stats.earned += total
	data.stats.harvests += (count or 1)
	if total > data.stats.bestSale then
		data.stats.bestSale = total
	end
	remotes.event:FireClient(session.player, Net.EventKind.Sale, { amount = total })
	session.saleBuffer += total
	grantXp(session, xp)
	PlayerData.markDirty(session.player.UserId)
end

---------------------------------------------------------------------------
-- STEP
---------------------------------------------------------------------------

local function stepSession(session, dt)
	local data = session.data
	local farm = session.farm

	local sold = farm:step(dt)

	if sold then
		local total = 0
		local xp = 0
		for _, item in ipairs(sold) do
			total += item.value
			local crop = GameConfig.getCrop(item.cropId)
			xp += crop and crop.xp or 0
		end
		Economy.creditSale(session, total, xp, #sold)
	end
end

---------------------------------------------------------------------------
-- COMPRAS
---------------------------------------------------------------------------

function Economy.buyUpgrade(player, kind)
	local session = Sessions.get(player)
	if not session then
		return false, "sessao invalida"
	end
	local data = session.data

	if kind == "auto" then
		local cost = GameConfig.autoCost(data.upgrades.auto)
		if not cost then
			return false, "maximo"
		end
		if data.cash < cost then
			return false, "sem dinheiro"
		end
		data.cash -= cost
		data.upgrades.auto += 1
		toast(player, "Colheita Dupla nivel " .. data.upgrades.auto, nil)
		PlayerData.markDirty(player.UserId)
		return true
	end

	local tier = data.upgrades[kind]
	if tier == nil then
		return false, "upgrade invalido"
	end
	local cost = GameConfig.upgradeCost(kind, tier)
	if not cost then
		return false, "maximo"
	end
	if data.cash < cost then
		return false, "sem dinheiro"
	end
	data.cash -= cost
	data.upgrades[kind] = tier + 1
	PlayerData.markDirty(player.UserId)
	return true
end

function Economy.buyCrystalUpgrade(player, kind)
	local session = Sessions.get(player)
	if not session then
		return false, "sessao invalida"
	end
	local data = session.data
	local rank = data.crystalUpgrades[kind]
	if rank == nil then
		return false, "upgrade invalido"
	end
	local cost = GameConfig.crystalCost(kind, rank)
	if not cost then
		return false, "maximo"
	end
	if data.crystals < cost then
		return false, "sem cristais"
	end
	data.crystals -= cost
	data.crystalUpgrades[kind] = rank + 1
	PlayerData.markDirty(player.UserId)
	return true
end

function Economy.buyPlot(player)
	local session = Sessions.get(player)
	if not session then
		return false, "sessao invalida"
	end
	local data = session.data
	local cost, levelReq = GameConfig.plotCost(data.plots)
	if not cost then
		return false, "maximo"
	end
	if data.level < levelReq then
		return false, "requer nivel " .. levelReq
	end
	if data.cash < cost then
		return false, "sem dinheiro"
	end
	data.cash -= cost
	data.plots += 1
	PlayerData.markDirty(player.UserId)
	return true
end

function Economy.selectCrop(player, cropId)
	local session = Sessions.get(player)
	if not session then
		return false
	end
	local crop = GameConfig.getCrop(cropId)
	if not crop then
		return false
	end
	if crop.level > session.data.level then
		return false
	end
	session.data.selectedCrop = cropId
	PlayerData.markDirty(player.UserId)
	return true
end

function Economy.rebirth(player)
	local session = Sessions.get(player)
	if not session then
		return false, "sessao invalida"
	end
	local data = session.data

	if data.rebirths >= GameConfig.Rebirth.Max then
		return false, "rebirth maximo"
	end
	if data.level < GameConfig.Rebirth.RequiredLevel then
		return false, "requer nivel " .. GameConfig.Rebirth.RequiredLevel
	end
	if data.cash < GameConfig.Rebirth.RequiredCash then
		return false, "requer " .. GameConfig.Rebirth.RequiredCash
	end

	local crystals = GameConfig.rebirthCrystals(data.rebirths)
	local fresh = GameConfig.defaultData()
	fresh.rebirths = data.rebirths + 1
	fresh.cash = 60
	fresh.crystals = data.crystals + crystals
	fresh.crystalUpgrades = data.crystalUpgrades
	fresh.redeemedCodes = data.redeemedCodes
	fresh.stats = data.stats
	fresh.level = 1
	fresh.xp = 0
	fresh.plots = GameConfig.Plots.Start
	fresh.selectedCrop = "wheat"

	for key, value in pairs(fresh) do
		data[key] = value
	end

	session.farm = Farm.new(data)
	PlayerData.markDirty(player.UserId)

	remotes.event:FireClient(player, Net.EventKind.Rebirth, { rebirths = data.rebirths, crystals = crystals })
	return true
end

function Economy.redeemCode(player, rawCode)
	local session = Sessions.get(player)
	if not session then
		return false, "sessao invalida"
	end
	local data = session.data
	if type(rawCode) ~= "string" then
		return false
	end

	local code = string.upper(string.gsub(rawCode, "^%s*(.-)%s*$", "%1"))
	local entry = GameConfig.Codes[code]
	if not entry then
		return false, "codigo invalido"
	end
	if data.redeemedCodes[code] then
		return false, "ja resgatado"
	end
	if entry.minLevel and data.level < entry.minLevel then
		return false, "requer nivel " .. entry.minLevel
	end

	data.redeemedCodes[code] = true
	if entry.cash then
		data.cash += entry.cash
	end
	if entry.crystals then
		data.crystals += entry.crystals
	end
	PlayerData.markDirty(player.UserId)
	toast(player, "Resgatado: " .. entry.label, Color3.fromRGB(120, 255, 190))
	return true
end

---------------------------------------------------------------------------
-- SNAPSHOT
---------------------------------------------------------------------------

local function snapshot(session)
	local data = session.data
	local crop = GameConfig.getCrop(data.selectedCrop) or GameConfig.bestCropForLevel(data.level)

	return {
		cash = data.cash,
		crystals = data.crystals,
		rebirths = data.rebirths,
		level = data.level,
		xp = data.xp,
		xpNeed = data.level >= GameConfig.MaxLevel and -1 or GameConfig.xpNeeded(data.level),
		plots = data.plots,
		selectedCrop = crop.id,
		upgrades = data.upgrades,
		crystalUpgrades = data.crystalUpgrades,
		luck = GameConfig.luck(data),
		sellMult = GameConfig.sellMultiplier(data),
		growMult = GameConfig.growthMultiplier(data),
		conveyorSpeed = GameConfig.conveyorSpeed(data.upgrades.conveyor),
		stats = data.stats,
		lotIndex = session.lotIndex,
		sale = session.saleBuffer,
		farm = session.farm:dump(),
	}
end

---------------------------------------------------------------------------
-- LOOP
---------------------------------------------------------------------------

-- Um passo do jogo para todas as sessoes. Separado do while pra ser testavel.
function Economy.tick(dt)
	for player, session in pairs(Sessions.all()) do
		if player.Parent == Players then
			stepSession(session, dt)

			-- replanta sozinho o que foi colhido
			session.plantTimer += dt
			if session.plantTimer >= 0.5 then
				session.plantTimer = 0
				Economy.autoplant(session)
			end

			remotes.state:FireClient(player, snapshot(session))
			session.saleBuffer = 0
		end
	end
end

function Economy.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = math.min(now - last, 1)
			last = now
			Economy.tick(dt)
		end
	end)
end

return Economy
