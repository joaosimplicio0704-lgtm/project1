-- Remotes
-- Cria/lê os RemoteEvents. Servidor cria, cliente espera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Remotes = {}

local function ensure(className, name, parent)
	local instance = parent:FindFirstChild(name)
	if not instance then
		instance = Instance.new(className)
		instance.Name = name
		instance.Parent = parent
	end
	return instance
end

function Remotes.setup()
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = ReplicatedStorage
	end
	return {
		folder = folder,
		state = ensure("RemoteEvent", Net.State, folder),
		action = ensure("RemoteEvent", Net.Action, folder),
		event = ensure("RemoteEvent", Net.Event, folder),
	}
end

return Remotes
