-- init.server
-- Bootstrap do servidor: mundo -> remotes -> sessoes -> loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local World = require(script.World)
local Remotes = require(script.Remotes)
local PlayerData = require(script.PlayerData)
local Sessions = require(script.Sessions)
local Game = require(script.Game)

World.build()
local remotes = Remotes.setup()
Game.init(remotes)
PlayerData.start()
Game.start()

---------------------------------------------------------------------------
-- SESSAO
---------------------------------------------------------------------------

local function startSession(player)
	local data = PlayerData.load(player.UserId)
	local session = {
		player = player,
		data = data,
		dirty = false,
		tapWindow = {},
		lastSnapshot = 0,
		pendingToast = nil,
	}
	Sessions.byPlayer[player] = session

	-- auto-equipa o melhor em slot livre ao entrar
	require(Shared.Pets).autoEquip(data)

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character and character:WaitForChild("HumanoidRootPart", 10)
	if root and World.spawnCFrame then
		root.CFrame = World.spawnCFrame()
	end
end

local function endSession(player)
	local session = Sessions.get(player)
	if not session then
		return
	end
	Sessions.byPlayer[player] = nil
	PlayerData.release(player.UserId)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and World.spawnCFrame then
			task.wait(0.2)
			root.CFrame = World.spawnCFrame()
		end
	end)
	task.spawn(startSession, player)
end)

Players.PlayerRemoving:Connect(endSession)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(startSession, player)
end

---------------------------------------------------------------------------
-- ACOES
---------------------------------------------------------------------------

local A = Net.ActionKind

remotes.action.OnServerEvent:Connect(function(player, kind, payload)
	local session = Sessions.get(player)
	if not session then
		return
	end

	local ok, err = Game.handle(session, kind, payload)
	if not ok and err then
		remotes.event:FireClient(player, Net.EventKind.Toast, { text = err, kind = "error" })
	end
end)

print(string.format("[EggTycoon] Servidor pronto · %d pets · %d ovos", #GameConfig.Pets, #GameConfig.Eggs))
