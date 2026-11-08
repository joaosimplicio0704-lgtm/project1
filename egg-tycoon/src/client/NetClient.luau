-- NetClient
-- Fio de rede do cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local NetClient = {}

local folder = ReplicatedStorage:WaitForChild(Net.FolderName)
local state = folder:WaitForChild(Net.State)
local action = folder:WaitForChild(Net.Action)
local event = folder:WaitForChild(Net.Event)

NetClient.state = state
NetClient.event = event

function NetClient.action(kind, payload)
	action:FireServer(kind, payload)
end

function NetClient.on(callback)
	return event.OnClientEvent:Connect(callback)
end

return NetClient
