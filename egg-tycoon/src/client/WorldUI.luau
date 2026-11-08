-- WorldUI
-- Liga as placas do mapa aos paineis: clicar num ovo abre OVOS,
-- clicar na loja abre LOJA, no portal abre RENASCIMENTO, etc.
-- Também desenha o pet equipado flutuando atrás do jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local WorldUI = {}

local handlers = {}

function WorldUI.build(handlerMap)
	handlers = handlerMap
	local folder = Workspace:WaitForChild("EggTycoon", 15)
	if not folder then
		warn("[WorldUI] pasta do mapa não encontrada")
		return
	end

	-- Itera os ClickDetectors e roteia o PAI deles. Roteando o detector, o nome
	-- seria "ClickDetector" e nenhuma zona abriria.
	for _, detector in ipairs(folder:GetDescendants()) do
		if detector:IsA("ClickDetector") then
			local target = detector.Parent or detector
			detector.MouseClick:Connect(function(player)
				if player ~= Players.LocalPlayer then
					return
				end
				WorldUI.route(target)
			end)
		end
	end
end

function WorldUI.route(instance)
	local name = instance.Name
	local eggId = instance:GetAttribute("EggId")

	if eggId then
		if handlers.selectEgg then
			handlers.selectEgg(eggId)
		end
		return
	end

	if name:sub(1, 5) == "Zone_" then
		local zone = name:sub(6)
		if zone:sub(1, 4) == "egg_" then
			local id = zone:sub(5)
			-- "egg_halloween" e zona de loja; ovo normal abre a UI ja no ovo certo
			if GameConfig.egg(id) then
				if handlers.selectEgg then
					handlers.selectEgg(id)
				end
			elseif handlers.zone then
				handlers.zone(zone)
			end
		elseif handlers.zone then
			handlers.zone(zone)
		end
	end
end

---------------------------------------------------------------------------
-- PET FLUTUANTE ATRÁS DO JOGADOR
---------------------------------------------------------------------------

local rigs = {} -- [player] = { models = {}, lastKey }

local function buildPetModel(pet)
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id

	local body = Instance.new("Part")
	body.Size = Vector3.new(3.2, 3.2, 3.2)
	body.Shape = Enum.PartType.Ball
	body.Color = pet.color
	body.Material = pet.rarity == "secret" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	-- olhinhos
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Size = Vector3.new(0.62, 0.62, 0.62)
		eye.Shape = Enum.PartType.Ball
		eye.Color = Color3.fromRGB(30, 30, 40)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Position = body.Position + Vector3.new(side * 0.85, 0.7, -1.35)
		eye.Parent = model
	end

	-- orelhinhas
	local ears = Instance.new("Part")
	ears.Size = Vector3.new(2.6, 1.2, 0.7)
	ears.Color = pet.color
	ears.Material = Enum.Material.SmoothPlastic
	ears.Anchored = true
	ears.CanCollide = false
	ears.CanQuery = false
	ears.Position = body.Position + Vector3.new(0, 1.7, 0)
	ears.Parent = model

	return model, body
end

local PIPE = Instance.new("Folder")
PIPE.Name = "PetRigs"
PIPE.Parent = Workspace

local function ensureRig(player)
	if not rigs[player] then
		rigs[player] = { models = {}, key = "" }
	end
	return rigs[player]
end

function WorldUI.syncPets(snapshot)
	local player = Players.LocalPlayer
	local rig = ensureRig(player)

	local equipped = snapshot.equipped or {}
	local ids = {}
	for _, uid in ipairs(equipped) do
		ids[#ids + 1] = tostring(uid)
	end
	local key = table.concat(ids, ",")
	if key == rig.key then
		return
	end
	rig.key = key

	for _, model in ipairs(rig.models) do
		model:Destroy()
	end
	rig.models = {}

	local petsById = {}
	for _, instance in ipairs(snapshot.pets or {}) do
		petsById[instance.uid] = instance
	end

	local limit = math.min(#equipped, 8) -- visual: no máximo 8 flutuando
	for index = 1, limit do
		local uid = equipped[index]
		local instance = petsById[uid]
		if instance then
			local pet = GameConfig.pet(instance.petId)
			if pet then
				local model, body = buildPetModel(pet)
				model.Parent = PIPE
				rig.models[index] = model
			end
		end
	end
end

function WorldUI.stepPets(dt)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local rig = rigs[player]
	if not rig then
		return
	end

	local now = os.clock()
	local total = #rig.models
	for index, model in pairs(rig.models) do
		if model.Parent then
			local angle = (index - 1) / math.max(total, 1) * math.pi * 2 + now * 0.8
			local radius = 5.5
			local bob = math.sin(now * 2 + index) * 0.45
			local base = root.Position + Vector3.new(math.cos(angle) * radius, 3 + bob, math.sin(angle) * radius)
			local look = CFrame.lookAt(base, root.Position + Vector3.new(0, 3, 0))

			local body = model:FindFirstChildOfClass("Part")
			if body then
				-- guarda o offset de cada filho relativo ao corpo pra acompanhar
				for _, child in ipairs(model:GetChildren()) do
					if child:IsA("BasePart") and child ~= body then
						if not child:GetAttribute("Offset") then
							child:SetAttribute("Offset", child.Position - body.Position)
						end
					end
				end
				body.CFrame = look
				for _, child in ipairs(model:GetChildren()) do
					if child:IsA("BasePart") and child ~= body then
						local offset = child:GetAttribute("Offset")
						if offset then
							child.CFrame = look * CFrame.new(offset)
						end
					end
				end
			end
		end
	end
end

return WorldUI
