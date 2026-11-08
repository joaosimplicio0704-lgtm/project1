-- init.server
-- Bootstrap: mundo -> remotes -> sessoes -> loop economico.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local World = require(script.World)
local Remotes = require(script.Remotes)
local PlayerData = require(script.PlayerData)
local Sessions = require(script.Sessions)
local Farm = require(script.Farm)
local Economy = require(script.Economy)

World.buildEnvironment()
local remotes = Remotes.setup()
Economy.init(remotes)
PlayerData.start()
Economy.start()

---------------------------------------------------------------------------
-- SESSAO
---------------------------------------------------------------------------

local function startSession(player)
	local data = PlayerData.load(player.UserId)

	local lotIndex = World.freeLot()
	if not lotIndex then
		warn("[FarmTycoon] Sem lotes livres para", player.Name)
		player:Kick("Servidor cheio. Tente outro servidor.")
		return
	end

	local lot = World.buildLot(lotIndex, player.UserId, player.DisplayName)
	World.refreshLot(lotIndex, data.plots, "")

	local session = {
		player = player,
		data = data,
		farm = Farm.new(data),
		lotIndex = lotIndex,
		plantTimer = 0,
		saleBuffer = 0,
	}
	Sessions.byPlayer[player] = session

	-- nasce perto do lote
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		root.CFrame = CFrame.new(lot.origin + Vector3.new(-20, 6, 24))
	end
end

local function endSession(player)
	local session = Sessions.get(player)
	if not session then
		return
	end
	Sessions.byPlayer[player] = nil
	PlayerData.release(player.UserId)
	World.releaseLot(session.lotIndex)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local session = Sessions.get(player)
		if not session then
			return
		end
		local lot = World.getLot(session.lotIndex)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if lot and root then
			root.CFrame = CFrame.new(lot.origin + Vector3.new(-20, 6, 24))
		end
	end)
	task.spawn(startSession, player)
end)

Players.PlayerRemoving:Connect(endSession)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(startSession, player)
end

---------------------------------------------------------------------------
-- ACOES DO CLIENTE
---------------------------------------------------------------------------

local handlers = {
	[Net.ActionKind.SelectCrop] = function(player, payload)
		Economy.selectCrop(player, payload)
	end,
	[Net.ActionKind.BuyPlot] = function(player)
		Economy.buyPlot(player)
	end,
	[Net.ActionKind.BuyUpgrade] = function(player, payload)
		Economy.buyUpgrade(player, payload)
	end,
	[Net.ActionKind.BuyCrystal] = function(player, payload)
		Economy.buyCrystalUpgrade(player, payload)
	end,
	[Net.ActionKind.BuyAuto] = function(player)
		Economy.buyUpgrade(player, "auto")
	end,
	[Net.ActionKind.Rebirth] = function(player)
		Economy.rebirth(player)
	end,
	[Net.ActionKind.Redeem] = function(player, payload)
		Economy.redeemCode(player, payload)
	end,
	[Net.ActionKind.Harvest] = function(player)
		local session = Sessions.get(player)
		if not session then
			return
		end
		local rushed = Economy.rushBelt(session)
		if rushed == 0 then
			Economy.notify(player, "Esteira vazia — espera a próxima colheita", Color3.fromRGB(255, 190, 90))
		end
	end,
}

remotes.action.OnServerEvent:Connect(function(player, kind, payload)
	local handler = handlers[kind]
	if handler then
		handler(player, payload)
	end
end)

---------------------------------------------------------------------------
-- REFRESH VISUAL DOS LOTES (barato, 2 Hz)
---------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(0.5)
		for player, session in pairs(Sessions.all()) do
			local data = session.data
			local pending = session.farm:pendingValue()
			World.refreshLot(
				session.lotIndex,
				data.plots,
				string.format("Nv %d  •  $%s", data.level, tostring(math.floor(data.cash)))
			)
			local lot = World.getLot(session.lotIndex)
			if lot then
				-- brilho da esteira reage a valor pendente
				local intensity = math.clamp(pending / 100000, 0, 1)
				lot.sellPad.Color = Color3.fromRGB(30, 34, 42):Lerp(Color3.fromRGB(40, 120, 80), intensity)
			end
		end
	end
end)

print(string.format("[FarmTycoon] Servidor pronto. %d crops, %d niveis.", #GameConfig.Crops, GameConfig.MaxLevel))
