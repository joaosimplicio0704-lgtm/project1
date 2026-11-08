-- Render
-- Desenha a fazenda a partir do snapshot do servidor.
-- Nada de estado de jogo aqui: o cliente so le e pinta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local Render = {}

local folder
local plotVisuals = {} -- [index] = { model, base, crop, ring }
local itemVisuals = {} -- [id] = { model, lastPos }
local lot
local beltStart, beltLength

local function newModel(name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	return model
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

function Render.init()
	folder = Instance.new("Folder")
	folder.Name = "FarmTycoonClient"
	folder.Parent = Workspace
end

-- Recebe o modelo do lote pelo nome (o servidor ja criou).
-- Sem yielded calls: se o modelo ainda nao replicou, tenta de novo no proximo frame.
function Render.syncLot(snapshot)
	if not snapshot or snapshot.lotIndex == nil then
		return
	end
	if lot and lot.index == snapshot.lotIndex then
		return
	end

	local world = Workspace:FindFirstChild("FarmTycoon")
	local model = world and world:FindFirstChild("Lot_" .. snapshot.lotIndex)
	if not model then
		return
	end

	Render.clear()
	lot = { index = snapshot.lotIndex, model = model }

	local platform = model:FindFirstChild("Platform")
	local conveyor = model:FindFirstChild("Conveyor")
	if platform then
		-- o servidor usa o centro do lote no chao (y=0); a plataforma tem 2 de altura
		lot.origin = platform.Position - Vector3.new(0, 0.5, 0)
	end
	if conveyor then
		beltStart = conveyor:GetAttribute("BeltStart")
		beltLength = conveyor:GetAttribute("BeltLength") or 30
	end
end

function Render.clear()
	for _, visual in pairs(plotVisuals) do
		if visual.model then
			visual.model:Destroy()
		end
	end
	plotVisuals = {}
	for _, visual in pairs(itemVisuals) do
		if visual.model then
			visual.model:Destroy()
		end
	end
	itemVisuals = {}
	lot = nil
end

---------------------------------------------------------------------------
-- PLOTS
---------------------------------------------------------------------------

local function buildPlotVisual(index, surface)
	local size = GameConfig.Layout.plotSize
	local model = newModel("PlotVisual_" .. index)

	local base = part({
		Name = "Base",
		Size = Vector3.new(size - 0.6, 0.2, size - 0.6),
		Position = surface + Vector3.new(0, 0.12, 0),
		Color = Color3.fromRGB(96, 68, 46),
		Material = Enum.Material.Ground,
		Transparency = 0.15,
	})
	base.Parent = model

	local ring = part({
		Name = "Ring",
		Size = Vector3.new(size - 0.2, 0.08, size - 0.2),
		Position = surface + Vector3.new(0, 0.02, 0),
		Color = Color3.fromRGB(96, 235, 148),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
	})
	ring.Parent = model

	return { model = model, base = base, ring = ring, cropModel = nil, cropId = nil }
end

local function buildCropVisual(cropId, center)
	local crop = GameConfig.getCrop(cropId)
	local model = newModel("Crop_" .. cropId)

	local count = 5
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local radius = (GameConfig.Layout.plotSize - 0.6) * 0.3
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local stem = part({
			Size = Vector3.new(0.35, 1.4, 0.35),
			Position = center + offset + Vector3.new(0, 0.8, 0),
			Color = Color3.fromRGB(78, 150, 78),
			Material = Enum.Material.Grass,
		})
		stem.Parent = model

		local head = part({
			Size = Vector3.new(1.5, 1.5, 1.5),
			Position = center + offset + Vector3.new(0, 1.9, 0),
			Color = crop and crop.color or Color3.fromRGB(230, 230, 230),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		})
		head.Parent = model
		head.Name = "Head"
	end

	return model
end

local function updatePlot(index, info, surface, unlocked)
	local visual = plotVisuals[index]
	if not visual then
		visual = buildPlotVisual(index, surface)
		plotVisuals[index] = visual
	end

	if not unlocked then
		visual.base.Transparency = 0.9
		visual.ring.Transparency = 1
		if visual.cropModel then
			visual.cropModel:Destroy()
			visual.cropModel = nil
			visual.cropId = nil
		end
		return
	end

	visual.base.Transparency = 0.15
	visual.ring.Transparency = 0.55

	if not info then
		if visual.cropModel then
			visual.cropModel:Destroy()
			visual.cropModel = nil
			visual.cropId = nil
		end
		visual.ring.Color = Color3.fromRGB(96, 235, 148)
		return
	end

	if visual.cropId ~= info.cropId then
		if visual.cropModel then
			visual.cropModel:Destroy()
		end
		visual.cropModel = buildCropVisual(info.cropId, surface)
		visual.cropId = info.cropId
	end

	-- escala pelo progresso
	local progress = info.ready and 1 or math.clamp(info.progress or 0, 0.08, 1)
	local scale = 0.35 + progress * 0.65
	if visual.cropModel then
		for _, child in ipairs(visual.cropModel:GetChildren()) do
			if child:IsA("BasePart") and child.Name == "Head" then
				local base = Vector3.new(1.5, 1.5, 1.5)
				local target = base * scale
				child.Size = child.Size:Lerp(target, 0.35)
			end
		end
	end

	local mutation = GameConfig.getMutation(info.mutationId)
	if mutation.color then
		visual.ring.Color = mutation.color
		visual.ring.Transparency = info.ready and 0.25 or 0.6
	elseif info.ready then
		visual.ring.Color = Color3.fromRGB(255, 224, 102)
		visual.ring.Transparency = 0.3
	else
		visual.ring.Color = Color3.fromRGB(96, 235, 148)
		visual.ring.Transparency = 0.6
	end
end

---------------------------------------------------------------------------
-- ITENS NA ESTEIRA
---------------------------------------------------------------------------

local function spawnItemVisual(item)
	local crop = GameConfig.getCrop(item.cropId)
	local mutation = GameConfig.getMutation(item.mutationId)

	local model = newModel("Item_" .. item.id)
	local body = part({
		Size = Vector3.new(1.9, 1.9, 1.9),
		Position = beltStart + Vector3.new(0, 1.35, item.pos * beltLength),
		Color = mutation.color or (crop and crop.color) or Color3.fromRGB(240, 240, 240),
		Material = mutation.color and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
	})
	body.Parent = model

	if mutation.color then
		local light = Instance.new("PointLight")
		light.Color = mutation.color
		light.Brightness = 1.4
		light.Range = 9
		light.Parent = body
	end

	return { model = model, body = body }
end

function Render.step(snapshot, dt)
	if not snapshot or not snapshot.lotIndex then
		return
	end
	Render.syncLot(snapshot)
	if not lot or not beltStart then
		return
	end

	local farm = snapshot.farm
	if not farm then
		return
	end

	-- plots: geometria vem do GameConfig.Layout, igual ao servidor
	local origin = lot.origin
	for i = 1, GameConfig.Plots.Max do
		local surface = origin + GameConfig.plotLocalOffset(i)
		updatePlot(i, farm.plots[i], surface, i <= (farm.activePlots or 0))
	end

	-- itens: posicao vem do servidor a 10 Hz; interpola localmente pra nao tremer
	local speed = farm.speed or 20
	local rate = speed / beltLength
	local seen = {}
	for _, item in ipairs(farm.items or {}) do
		seen[item.id] = true
		local visual = itemVisuals[item.id]
		if not visual then
			visual = spawnItemVisual(item)
			visual.pos = item.pos
			itemVisuals[item.id] = visual
		end

		-- extrapola a partir do ultimo pos conhecido e suaviza na direcao do servidor
		visual.pos += rate * dt
		local target = item.pos
		if target > visual.pos then
			visual.pos = visual.pos + (target - visual.pos) * math.min(dt * 24, 1)
		else
			visual.pos = target -- reconciliou: servidor vendeu ou resetou
		end

		local worldPos = beltStart + Vector3.new(0, 1.35, math.min(visual.pos, 1.02) * beltLength)
		visual.spin = (visual.spin or 0) + dt * 2.4
		visual.body.CFrame = CFrame.new(worldPos) * CFrame.Angles(visual.spin, visual.spin * 1.4, 0)
	end

	for id, visual in pairs(itemVisuals) do
		if not seen[id] then
			visual.model:Destroy()
			itemVisuals[id] = nil
		end
	end
end

return Render
