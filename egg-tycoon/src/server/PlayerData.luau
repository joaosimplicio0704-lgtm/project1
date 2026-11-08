-- PlayerData
-- Persistencia com DataStoreService + fallback em memoria (Studio sem API).
-- Toda escrita passa por aqui, com retry e BindToClose.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PlayerData = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.SaveStore)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore indisponivel, salvando apenas em memoria:", result)
	end
end

local cache = {} -- [userId] = data
local dirty = {} -- [userId] = true

local function reconcile(defaults, saved)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(saved[key]) ~= "table" then
				saved[key] = {}
			end
			reconcile(value, saved[key])
		elseif saved[key] == nil or type(saved[key]) ~= type(value) then
			saved[key] = value
		end
	end
	return saved
end

local function key(userId)
	return "u_" .. tostring(userId)
end

local function read(userId)
	if not store then
		return nil
	end
	local ok, result = pcall(function()
		return store:GetAsync(key(userId))
	end)
	if ok then
		return result
	end
	warn("[PlayerData] GetAsync falhou:", result)
	return nil
end

local function write(userId, data)
	if not store then
		return true
	end
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			store:SetAsync(key(userId), data)
		end)
		if ok then
			return true
		end
		warn(string.format("[PlayerData] SetAsync tentativa %d falhou: %s", attempt, tostring(err)))
		task.wait(1 + attempt)
	end
	return false
end

function PlayerData.load(userId)
	if cache[userId] then
		return cache[userId]
	end

	local saved = read(userId)
	local data = reconcile(GameConfig.defaultData(), type(saved) == "table" and saved or {})
	cache[userId] = data
	return data
end

function PlayerData.get(userId)
	return cache[userId]
end

function PlayerData.markDirty(userId)
	dirty[userId] = true
end

function PlayerData.save(userId)
	local data = cache[userId]
	if not data then
		return
	end
	if write(userId, data) then
		dirty[userId] = nil
	end
end

function PlayerData.release(userId)
	PlayerData.save(userId)
	cache[userId] = nil
	dirty[userId] = nil
end

function PlayerData.start()
	task.spawn(function()
		while true do
			task.wait(90)
			for userId in pairs(dirty) do
				PlayerData.save(userId)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for userId in pairs(cache) do
			PlayerData.save(userId)
		end
	end)
end

return PlayerData
