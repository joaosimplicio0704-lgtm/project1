-- World
-- Mapa cartoon low-poly construído em código, no estilo dos tycoons de ovo:
-- palco central, ilhas de ovo, lojas, portal de rebirth e a fonte.
-- Nada de asset externo: tudo Instance.new com cores chapadas.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Terrain = require(ReplicatedStorage.Shared.Terrain)

local World = {}

local PALETTE = {
	grass = Color3.fromRGB(104, 196, 90),
	grassDark = Color3.fromRGB(76, 160, 70),
	path = Color3.fromRGB(238, 196, 141),
	pathLight = Color3.fromRGB(252, 222, 176),
	pathEdge = Color3.fromRGB(214, 166, 110),
	wood = Color3.fromRGB(150, 100, 62),
	woodDark = Color3.fromRGB(110, 72, 44),
	rock = Color3.fromRGB(178, 190, 205),
	rockDark = Color3.fromRGB(140, 155, 175),
	water = Color3.fromRGB(90, 205, 235),
	sand = Color3.fromRGB(240, 226, 190),
	flower = Color3.fromRGB(255, 150, 190),
	stem = Color3.fromRGB(70, 150, 65),
	white = Color3.fromRGB(250, 250, 250),
	gold = Color3.fromRGB(255, 190, 50),
	goldDark = Color3.fromRGB(230, 150, 30),
	purple = Color3.fromRGB(150, 110, 220),
	purpleDark = Color3.fromRGB(105, 70, 175),
	pink = Color3.fromRGB(255, 170, 210),
	blue = Color3.fromRGB(90, 150, 240),
	portal = Color3.fromRGB(150, 235, 255),
	portalDark = Color3.fromRGB(70, 150, 200),
	stone = Color3.fromRGB(205, 210, 220),
	stoneDark = Color3.fromRGB(150, 158, 172),
	cosmic = Color3.fromRGB(180, 150, 255),
}

World.palette = PALETTE

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "material" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function ball(props, parent)
	local p = part(props, parent)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	return p
end

local function wedge(props, parent)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- INFRA
---------------------------------------------------------------------------

local root

function World.build()
	-- LUZ AMBIENTE GLOBAL
	-- O ambiente do Roblox é escuro por padrão: sombra quase preta, e as ilhas
	-- longe do sol somem. Aqui a luz é lavada de propósito, para o mapa parecer
	-- um desenho: ambiente alto, sombra suave, névoa leve no horizonte.
	Lighting.Ambient = Color3.fromRGB(150, 164, 186)
	Lighting.OutdoorAmbient = Color3.fromRGB(196, 210, 232)
	Lighting.Brightness = 3.1
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = -15
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.75
	Lighting.ExposureCompensation = 0.35
	Lighting.FogColor = Color3.fromRGB(198, 220, 246)
	Lighting.FogStart = 700
	Lighting.FogEnd = 3400

	-- O céu não é opcional: sem um Sky o horizonte fica cinza e as ilhas
	-- distantes somem. Nada de asset pago — o Sky padrão do Roblox já serve.
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
		sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
		sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
		sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
		sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
		sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
		sky.Parent = Lighting
	end

	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphere = existing or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 0.9
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(210, 226, 245)
	atmosphere.Decay = Color3.fromRGB(130, 150, 175)
	atmosphere.Parent = Lighting

	local old = Workspace:FindFirstChild("EggTycoon")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "EggTycoon"
	root.Parent = Workspace

	-- MAR
	-- MAR ORGÂNICO — anéis concêntricos
	-- Histórico das tentativas, porque cada uma falhou por um motivo:
	--   1. quadrado de 760  -> desenhava um QUADRADO em volta das ilhas redondas
	--   2. fatias em anel   -> virou RODA DE BICICLETA (costura entre fatias)
	--   3. placas fora de grade -> cheio de LINHA DE COSTURA onde as bordas se
	--      sobrepunham em degraus
	-- A que funciona: poucos anéis concêntricos, cada um um único cilindro
	-- enorme. Um cilindro não tem costura; e como cada anel tem raio e Y
	-- próprios, não há briga de pixel entre eles.
	local function seaRing(name, radius, y, color, transparency, material)
		local disc = part({
			Name = name,
			Size = Vector3.new(2.4, radius * 2, radius * 2),
			Position = Vector3.new(0, y, 0),
			Color = color,
			Material = material,
			Transparency = transparency,
			CanCollide = false,
			Shape = Enum.PartType.Cylinder,
		}, root)
		disc.CFrame = CFrame.new(disc.Position) * CFrame.Angles(0, 0, math.pi / 2)
		return disc
	end

	-- degraus de água: do centro para fora, cada anel mais escuro
	seaRing("SeaFloor", 596, -34, Color3.fromRGB(56, 132, 150), 0, Enum.Material.Sand)
	seaRing("ShallowWater", 580, -6.0, Color3.fromRGB(126, 228, 238), 0.28, Enum.Material.Water)
	-- halo: a borda do primeiro anel, um tom acima, para a transição não ser
	-- um corte seco de círculo perfeito
	seaRing("SeaHalo", 604, -6.6, Color3.fromRGB(146, 236, 244), 0.52, Enum.Material.Water)

	-- mar fundo: escuro, cobre o horizonte até a névoa
	part({
		Name = "Ocean",
		Size = Vector3.new(4000, 6, 4000),
		Position = Vector3.new(0, -10, 0),
		Color = Color3.fromRGB(44, 132, 186),
		Material = Enum.Material.Water,
		Transparency = 0.18,
		CanCollide = false,
	}, root)

	-- espuma na borda do arquipélago: um anel branco que quebra a linha reta
	for i = 1, 44 do
		local angle = (i / 44) * math.pi * 2
		local wobble = 1 + math.sin(i * 2.7) * 0.06
		local radius = 610 * wobble
		local foam = part({
			Name = "Foam",
			Size = Vector3.new(30, 1.2, 16),
			Position = Vector3.new(math.cos(angle) * radius, -3.4, math.sin(angle) * radius),
			Color = Color3.fromRGB(238, 252, 255),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
		}, root)
		foam.CFrame = CFrame.new(foam.Position) * CFrame.Angles(0, -angle, 0)
	end

	-- ILHA DO HUB — redonda, como as ilhas dos biomas.
	-- Antes era um quadrado de 430 com uma praça quadrada de 300 por cima:
	-- visto de cima parecia uma piscina. Redondo lê como "ilha".
	local hubRadius = 215

	local hubGrass = part({
		Name = "Island",
		Size = Vector3.new(10, hubRadius * 2, hubRadius * 2),
		Position = Vector3.new(0, -4, 0),
		Color = PALETTE.grass,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Cylinder,
	}, root)
	hubGrass.CFrame = CFrame.new(hubGrass.Position) * CFrame.Angles(0, 0, math.pi / 2)

	local dirtRing = part({
		Name = "DirtRing",
		Size = Vector3.new(8, hubRadius * 2.06, hubRadius * 2.06),
		Position = Vector3.new(0, -7, 0),
		Color = Color3.fromRGB(170, 110, 70),
		Material = Enum.Material.Ground,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	}, root)
	dirtRing.CFrame = CFrame.new(dirtRing.Position) * CFrame.Angles(0, 0, math.pi / 2)

	-- Praia ABAIXO da grama: com o topo dela no mesmo y da grama, ela cobria
	-- a ilha inteira de areia (era isso o "losango marrom" do render).
	local hubBeach = part({
		Name = "Beach",
		Size = Vector3.new(6, hubRadius * 2.12, hubRadius * 2.12),
		Position = Vector3.new(0, -4.2, 0),
		Color = Color3.fromRGB(240, 220, 170),
		Material = Enum.Material.Sand,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	}, root)
	hubBeach.CFrame = CFrame.new(hubBeach.Position) * CFrame.Angles(0, 0, math.pi / 2)

	-- praça central redonda
	local plaza = part({
		Name = "Plaza",
		Size = Vector3.new(3, 190, 190),
		Position = Vector3.new(0, 1.6, 0),
		Color = PALETTE.path,
		Material = Enum.Material.Brick,
		Shape = Enum.PartType.Cylinder,
	}, root)
	plaza.CFrame = CFrame.new(plaza.Position) * CFrame.Angles(0, 0, math.pi / 2)

	-- ANEL DE CAMINHOS — a roda dentada ligando praça e portais.
	-- É o que faz o hub se ler como "mapa de jogo" e não como um pátio.
	local PORTAL_RING = 138
	local PATH_W = 26
	for i = 1, 56 do
		local angle = (i / 56) * math.pi * 2
		local seg = part({
			Name = "Path",
			Size = Vector3.new(PATH_W, 1.2, 30),
			Position = Vector3.new(math.cos(angle) * PORTAL_RING, 2.2, math.sin(angle) * PORTAL_RING),
			Color = PALETTE.pathLight,
			Material = Enum.Material.Brick,
			CanCollide = false,
		}, root)
		seg.CFrame = CFrame.new(seg.Position) * CFrame.Angles(0, -angle, 0)
	end

	-- raios: da praça até o anel, um para cada portal
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		local mid = (95 + PORTAL_RING) / 2
		local spoke = part({
			Name = "Spoke",
			Size = Vector3.new(22, 1.1, PORTAL_RING - 95 + 20),
			Position = Vector3.new(math.cos(angle) * mid, 2.15, math.sin(angle) * mid),
			Color = PALETTE.pathLight,
			Material = Enum.Material.Brick,
			CanCollide = false,
		}, root)
		spoke.CFrame = CFrame.new(spoke.Position) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	end

	-- canteiros de grama alta na borda (silhueta cartoon)
	local rng = Random.new(31)
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		-- Canteiros na borda do hub. O raio sozinho nao basta: com 21 de
		-- largura, um bloco centrado em r=200 avanca ate r=210.5 e passa do
		-- raio 215 da ilha — sobrava um canto flutuando no mar. O raio tem
		-- de descontar a meia-largura.
		local w = 16 + rng:NextNumber() * 10
		local radius = 215 - w / 2 - 6 - rng:NextNumber() * 10
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local h = 8 + rng:NextNumber() * 10
		-- A grama do hub tem o topo em y=1. Com base em -1 os canteiros
		-- afundavam 2 studs e so a pontinha aparecia: de longe pareciam
		-- quadradinhos verdes soltos no mar.
		local GROUND_TOP = 1
		part({
			Size = Vector3.new(w, h, w * 0.9 + 4),
			Position = Vector3.new(x, GROUND_TOP + h / 2 - 1.5, z),
			Color = i % 2 == 0 and PALETTE.grass or PALETTE.grassDark,
			Material = Enum.Material.Grass,
		}, root)
	end

	World.buildTrees()
	World.buildFountain()
	World.buildFestival()
	World.buildEggStands()
	World.buildShop()
	World.buildGemShop()
	World.buildGoldenCrate()
	World.buildFusion()
	World.buildRebirthPortal()
	World.buildTradePost()
	World.buildHalloween()
	World.buildBiomes()

	-- SpawnLocation: sem isso o Roblox joga o jogador no vazio/default do template
	local spawnPad = part({
		Name = "SpawnLocation",
		Size = Vector3.new(18, 1, 18),
		Position = Vector3.new(0, 3.2, 62),
		Color = PALETTE.path,
		Material = Enum.Material.Brick,
	}, root)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(16, 0.4, 16)
	spawn.Position = Vector3.new(0, 3.9, 62)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = root

	-- anel neon marcando o spawn
	part({
		Name = "SpawnRing",
		Size = Vector3.new(17, 0.25, 17),
		Position = Vector3.new(0, 3.75, 62),
		Color = Color3.fromRGB(96, 240, 235),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	World.spawnPoint = Vector3.new(0, 5, 62)
end

function World.spawnCFrame()
	return CFrame.new(World.spawnPoint or Vector3.new(0, 5, 60)) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------------------
-- DECORACAO
---------------------------------------------------------------------------

local function tree(position, scale, parent)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent

	part({
		Size = Vector3.new(4, 14, 4) * scale,
		Position = position + Vector3.new(0, 6 * scale, 0),
		Color = PALETTE.woodDark,
		Material = Enum.Material.Wood,
	}, model)

	for i, offset in ipairs({ Vector3.new(0, 15, 0), Vector3.new(0, 20, 0), Vector3.new(0, 24, 0) }) do
		local size = (10 - i * 2) * scale
		part({
			Size = Vector3.new(size, size * 0.9, size),
			Position = position + offset * scale,
			Color = i == 3 and Color3.fromRGB(92, 186, 96) or PALETTE.grass,
			Material = Enum.Material.Grass,
		}, model)
	end
	return model
end

local function flower(position, parent)
	local model = Instance.new("Model")
	model.Name = "Flower"
	model.Parent = parent

	part({
		Size = Vector3.new(0.5, 3, 0.5),
		Position = position + Vector3.new(0, 1.5, 0),
		Color = PALETTE.stem,
		Material = Enum.Material.Grass,
		CanCollide = false,
	}, model)

	ball({
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 3.4, 0),
		Color = PALETTE.flower,
		Material = Enum.Material.SmoothPlastic,
	}, model)
	return model
end

function World.buildTrees()
	local rng = Random.new(77)
	for i = 1, 22 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 100 + rng:NextNumber() * 62
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		tree(Vector3.new(x, 0, z), 1 + rng:NextNumber() * 0.55, root)
	end

	for i = 1, 40 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 88 + rng:NextNumber() * 70
		flower(Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), root)
	end
end

---------------------------------------------------------------------------
-- FONTE CENTRAL
---------------------------------------------------------------------------

function World.buildFountain()
	local model = Instance.new("Model")
	model.Name = "Fountain"
	model.Parent = root

	part({
		Size = Vector3.new(30, 2, 30),
		Position = Vector3.new(0, 1.6, 0),
		Color = PALETTE.white,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Size = Vector3.new(26, 1.2, 26),
		Position = Vector3.new(0, 2.5, 0),
		Color = PALETTE.water,
		Material = Enum.Material.Water,
		Transparency = 0.2,
		CanCollide = false,
	}, model)

	for i = 1, 2 do
		local size = 26 - i * 7
		part({
			Size = Vector3.new(size, 1.4, size),
			Position = Vector3.new(0, 3 + i * 3.4, 0),
			Color = PALETTE.white,
			Material = Enum.Material.Marble,
			CanCollide = false,
		}, model)
		part({
			Size = Vector3.new(size - 3, 1, size - 3),
			Position = Vector3.new(0, 3.4 + i * 3.4, 0),
			Color = PALETTE.water,
			Material = Enum.Material.Water,
			Transparency = 0.25,
			CanCollide = false,
		}, model)
	end

	-- bichinho dourado no topo
	ball({
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(0, 15, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, model)

	ball({
		Size = Vector3.new(4.5, 4.5, 4.5),
		Position = Vector3.new(0, 19.5, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, model)
end

---------------------------------------------------------------------------
-- UI DE MUNDO (placa + click detector)
---------------------------------------------------------------------------

-- `facing` e o ponto para onde a placa OLHA (por padrao: o centro do mapa).
-- Sem isso todas as 15 placas nasciam viradas para -Z: a placa do bioma que
-- fica do lado oposto do arquipelago mostrava as costas para quem chegava.
local function makeSign(position, text, color, parent, facing)
	local board = part({
		Name = "Sign_" .. text,
		Size = Vector3.new(16, 6, 0.8),
		Position = position,
		Color = PALETTE.wood,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	}, parent)

	local target = facing or Vector3.new(0, position.Y, 0)
	local dx = target.X - position.X
	local dz = target.Z - position.Z
	if math.sqrt(dx * dx + dz * dz) > 0.5 then
		-- NormalId.Front aponta para -Z local: apontamos o -Z para o alvo
		-- olhando PARA TRAS do alvo.
		local from = Vector3.new(position.X, position.Y, position.Z)
		local to = Vector3.new(from.X - dx, from.Y, from.Z - dz)
		board.CFrame = CFrame.lookAt(from, to)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 150)
	gui.LightInfluence = 0.2
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(60, 40, 20)
	label.Text = text
	label.Parent = gui

	return board
end

local zoneBindings = {}

local function makeZone(name, position, size, color)
	local hitbox = part({
		Name = "Zone_" .. name,
		Size = size,
		Position = position,
		Color = color or PALETTE.pink,
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		CanCollide = false,
		CanQuery = true,
	}, root)

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 32
	detector.CursorIcon = "rbxasset://textures/GunCursor.png"
	detector.Parent = hitbox

	zoneBindings[name] = { part = hitbox, detector = detector, color = color }
	return hitbox
end

function World.getZoneBindings()
	return zoneBindings
end

---------------------------------------------------------------------------
-- OVOS
---------------------------------------------------------------------------

function World.buildEggStands()
	-- O hub nao guarda mais os ovos: cada ovo mora no seu bioma. No lugar
	-- fica a arcada de portais, que e o que o jogador ve ao nascer.
	local deck = part({
		Name = "PortalDeck",
		Size = Vector3.new(150, 2, 40),
		Position = Vector3.new(0, 2.2, -44),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, root)
	deck.CanCollide = true

	part({
		Name = "PortalDeckTrim",
		Size = Vector3.new(152, 0.6, 42),
		Position = Vector3.new(0, 1.4, -44),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	makeSign(Vector3.new(0, 26, -52), "MUNDOS", Color3.fromRGB(255, 255, 255), root)
end

---------------------------------------------------------------------------
-- LOJAS
---------------------------------------------------------------------------

function World.buildShop()
	local origin = Vector3.new(-104, 0, -14)

	part({
		Size = Vector3.new(28, 1, 24),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	-- parede de madeira
	part({
		Size = Vector3.new(26, 18, 2),
		Position = origin + Vector3.new(0, 10, -8),
		Color = PALETTE.wood,
		Material = Enum.Material.WoodPlanks,
	}, root)

	-- telhado azul
	local roof = part({
		Size = Vector3.new(30, 2, 20),
		Position = origin + Vector3.new(0, 20, -2),
		Color = PALETTE.blue,
		Material = Enum.Material.Slate,
	}, root)
	roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(math.rad(-18), 0, 0)

	-- vitrine
	part({
		Size = Vector3.new(18, 9, 1),
		Position = origin + Vector3.new(0, 8, -7),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	-- balcão
	part({
		Size = Vector3.new(22, 4, 5),
		Position = origin + Vector3.new(0, 4, -3),
		Color = PALETTE.woodDark,
		Material = Enum.Material.WoodPlanks,
	}, root)

	for i = -2, 2 do
		ball({
			Size = Vector3.new(3.4, 3.4, 3.4),
			Position = origin + Vector3.new(i * 4, 7.5, -3),
			Color = i % 2 == 0 and PALETTE.gold or PALETTE.pink,
			Material = Enum.Material.Neon,
		}, root)
	end

	makeZone(Net.Zones.Shop, origin + Vector3.new(0, 4, 4), Vector3.new(24, 1, 14), Color3.fromRGB(120, 220, 255))
	makeSign(origin + Vector3.new(0, 25, -7), "LOJA", Color3.fromRGB(255, 255, 255), root)
end

function World.buildGemShop()
	local origin = Vector3.new(104, 0, -14)

	part({
		Size = Vector3.new(28, 1, 24),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	part({
		Size = Vector3.new(26, 18, 2),
		Position = origin + Vector3.new(0, 10, -8),
		Color = PALETTE.white,
		Material = Enum.Material.SmoothPlastic,
	}, root)

	local roof = part({
		Size = Vector3.new(30, 2, 20),
		Position = origin + Vector3.new(0, 20, -2),
		Color = PALETTE.purple,
		Material = Enum.Material.Slate,
	}, root)
	roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(math.rad(-18), 0, 0)

	-- gema gigante na frente
	local gem = part({
		Size = Vector3.new(7, 9, 7),
		Position = origin + Vector3.new(0, 9, -1),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	}, root)
	gem.CFrame = CFrame.new(gem.Position) * CFrame.Angles(0, math.rad(45), 0)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 230, 255)
	light.Brightness = 3
	light.Range = 26
	light.Parent = gem

	makeZone(Net.Zones.GemShop, origin + Vector3.new(0, 4, 4), Vector3.new(24, 1, 14), Color3.fromRGB(200, 150, 255))
	makeSign(origin + Vector3.new(0, 25, -7), "MELHORIAS DE GEMAS", Color3.fromRGB(230, 200, 255), root)
end

---------------------------------------------------------------------------
-- CRIAÇÃO DOURADA (o "oven" dourado dos prints)
---------------------------------------------------------------------------

function World.buildGoldenCrate()
	local origin = Vector3.new(-96, 0, 62)

	part({
		Size = Vector3.new(26, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
	}, root)

	-- dois "fornos" brancos com painel azul
	for i, offset in ipairs({ Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0) }) do
		local body = part({
			Size = Vector3.new(9, 12, 8),
			Position = origin + offset + Vector3.new(0, 8, 0),
			Color = PALETTE.white,
			Material = Enum.Material.SmoothPlastic,
		}, root)

		part({
			Size = Vector3.new(5.5, 4.5, 0.6),
			Position = body.Position + Vector3.new(0, 0.5, -4.2),
			Color = Color3.fromRGB(90, 200, 245),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, root)

		part({
			Size = Vector3.new(9.4, 1.2, 8.4),
			Position = body.Position + Vector3.new(0, 6.6, 0),
			Color = PALETTE.gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, root)

		ball({
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = body.Position + Vector3.new(0, 8.2, 0),
			Color = PALETTE.gold,
			Material = Enum.Material.Neon,
		}, root)
	end

	part({
		Size = Vector3.new(14, 1, 14),
		Position = origin + Vector3.new(0, 3.2, 9),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.15,
		CanCollide = false,
	}, root)

	makeZone(Net.Zones.Golden, origin + Vector3.new(0, 4, 10), Vector3.new(16, 1, 16), PALETTE.gold)
	makeSign(origin + Vector3.new(0, 20, -1), "CRIAÇÃO DOURADA", PALETTE.gold, root)
end

---------------------------------------------------------------------------
-- FUSÃO SECRETA
---------------------------------------------------------------------------

function World.buildFusion()
	local origin = Vector3.new(96, 0, 62)

	part({
		Size = Vector3.new(26, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.purpleDark,
		Material = Enum.Material.Marble,
	}, root)

	-- tubos rosa neon
	for i, offset in ipairs({ Vector3.new(-8, 0, -3), Vector3.new(0, 0, -5), Vector3.new(8, 0, -3) }) do
		local height = i == 2 and 14 or 11
		part({
			Size = Vector3.new(5, height, 5),
			Position = origin + offset + Vector3.new(0, height / 2 + 2, 0),
			Color = PALETTE.pink,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, root)

		part({
			Size = Vector3.new(6, 1.2, 6),
			Position = origin + offset + Vector3.new(0, height + 2.4, 0),
			Color = PALETTE.white,
			Material = Enum.Material.SmoothPlastic,
		}, root)
	end

	part({
		Size = Vector3.new(12, 1, 10),
		Position = origin + Vector3.new(0, 3.2, 8),
		Color = PALETTE.pink,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, root)

	makeZone(Net.Zones.Fusion, origin + Vector3.new(0, 4, 9), Vector3.new(16, 1, 16), PALETTE.pink)
	makeSign(origin + Vector3.new(0, 22, -4), "FUSÃO SECRETA", Color3.fromRGB(255, 220, 245), root)
end

---------------------------------------------------------------------------
-- LOJA DE HALLOWEEN
---------------------------------------------------------------------------

function World.buildHalloween()
	local origin = Vector3.new(-168, 0, 118)

	part({
		Size = Vector3.new(30, 1, 22),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(255, 140, 60),
		Material = Enum.Material.Neon,
	}, root)

	part({
		Size = Vector3.new(28, 2, 22),
		Position = origin + Vector3.new(0, 16, 0),
		Color = Color3.fromRGB(110, 70, 180),
		Material = Enum.Material.Slate,
	}, root)

	for i = -2, 2 do
		part({
			Size = Vector3.new(3, 14, 3),
			Position = origin + Vector3.new(i * 6, 8, -9),
			Color = PALETTE.woodDark,
			Material = Enum.Material.Wood,
		}, root)
	end

	part({
		Size = Vector3.new(28, 8, 1),
		Position = origin + Vector3.new(0, 10, -9),
		Color = Color3.fromRGB(60, 40, 90),
		Material = Enum.Material.SmoothPlastic,
	}, root)

	ball({
		Size = Vector3.new(5, 5, 5),
		Position = origin + Vector3.new(-6, 12, -8),
		Color = Color3.fromRGB(255, 130, 40),
		Material = Enum.Material.Neon,
	}, root)

	-- zona de compra do ovo de halloween (usa o mesmo fluxo de ovo)
	makeZone("egg_halloween", origin + Vector3.new(0, 4, 7), Vector3.new(18, 1, 14), Color3.fromRGB(255, 150, 60))
	zoneBindings["egg_halloween"].eggId = "halloween"
	makeSign(origin + Vector3.new(0, 22, -9), "LOJA DE HALLOWEEN", Color3.fromRGB(255, 200, 120), root)
end

---------------------------------------------------------------------------
-- PORTAL DE REBIRTH
---------------------------------------------------------------------------

function World.buildRebirthPortal()
	local origin = Vector3.new(0, 0, -108)

	-- escadaria
	for i = 1, 6 do
		part({
			Size = Vector3.new(24, 1.6, 5),
			Position = origin + Vector3.new(0, i * 1.4, 20 - i * 4.4),
			Color = PALETTE.wood,
			Material = Enum.Material.WoodPlanks,
		}, root)
	end

	-- portal
	local frame = part({
		Size = Vector3.new(26, 30, 3),
		Position = origin + Vector3.new(0, 18, -4),
		Color = PALETTE.woodDark,
		Material = Enum.Material.Wood,
	}, root)

	local glow = part({
		Size = Vector3.new(20, 24, 1),
		Position = origin + Vector3.new(0, 18, -2.4),
		Color = Color3.fromRGB(120, 240, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	}, root)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(130, 255, 210)
	light.Brightness = 4
	light.Range = 40
	light.Parent = glow

	frame:SetAttribute("Portal", true)

	makeZone(Net.Zones.Rebirth, origin + Vector3.new(0, 5, 12), Vector3.new(22, 1, 14), Color3.fromRGB(120, 240, 200))
	makeSign(origin + Vector3.new(0, 38, -4), "RENASCIMENTO", Color3.fromRGB(150, 255, 215), root)
end

---------------------------------------------------------------------------
-- POSTO DE TROCA (placeholder de trade)
---------------------------------------------------------------------------

function World.buildTradePost()
	local origin = Vector3.new(178, 0, 60)

	part({
		Size = Vector3.new(20, 1, 18),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = PALETTE.pathEdge,
		Material = Enum.Material.Brick,
	}, root)

	part({
		Size = Vector3.new(10, 12, 10),
		Position = origin + Vector3.new(0, 8, 0),
		Color = Color3.fromRGB(255, 120, 90),
		Material = Enum.Material.SmoothPlastic,
	}, root)

	part({
		Size = Vector3.new(12, 2, 12),
		Position = origin + Vector3.new(0, 15, 0),
		Color = PALETTE.white,
		Material = Enum.Material.SmoothPlastic,
	}, root)

	makeZone(Net.Zones.Trade, origin + Vector3.new(0, 4, 9), Vector3.new(16, 1, 12), Color3.fromRGB(255, 150, 120))
	makeSign(origin + Vector3.new(0, 20, 0), "TROCA", Color3.fromRGB(255, 200, 180), root)
end

---------------------------------------------------------------------------
-- FESTA DO HUB
---------------------------------------------------------------------------

-- A praça é o primeiro lugar que a criança vê. Aqui entram bandeirinhas
-- coloridas, balões, estátua do ovo gigante e postes de luz — tudo primitivo,
-- tudo colorido, nada pago. É o que separa "um mapa" de "um lugar".
function World.buildFestival()
	local model = Instance.new("Model")
	model.Name = "Festival"
	model.Parent = root

	-- ESTATUA DO OVO: o mascote do jogo, girando na entrada
	local statue = Instance.new("Model")
	statue.Name = "EggStatue"
	statue.Parent = model

	part({
		Name = "StatueBase",
		Size = Vector3.new(26, 6, 26),
		Position = Vector3.new(0, 3, 150),
		Color = PALETTE.white,
		Material = Enum.Material.Marble,
	}, statue)

	part({
		Name = "StatueRing",
		Size = Vector3.new(22, 1, 22),
		Position = Vector3.new(0, 6.6, 150),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, statue)

	local bigEgg = ball({
		Name = "EggStatueBody",
		Size = Vector3.new(20, 27, 20),
		Position = Vector3.new(0, 21, 150),
		Color = Color3.fromRGB(255, 244, 214),
		Material = Enum.Material.SmoothPlastic,
	}, statue)
	bigEgg:SetAttribute("Spin", true)

	local rng = Random.new(99)
	for i = 1, 12 do
		local theta = rng:NextNumber() * math.pi * 2
		local phi = math.acos(2 * rng:NextNumber() - 1)
		ball({
			Name = "StatueSpot",
			Size = Vector3.new(3.4, 3.4, 3.4),
			Position = Vector3.new(0, 21, 150) + Vector3.new(
				math.sin(phi) * math.cos(theta) * 10,
				math.cos(phi) * 13,
				math.sin(phi) * math.sin(theta) * 10
			),
			Color = Color3.fromRGB(255, 178, 96),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, statue)
	end

	-- BANDEIRINHAS: dois arcos de linha colorida cruzando a praça
	local flagColors = {
		Color3.fromRGB(255, 96, 108),
		Color3.fromRGB(255, 206, 61),
		Color3.fromRGB(126, 217, 87),
		Color3.fromRGB(96, 186, 255),
		Color3.fromRGB(178, 130, 255),
	}
	for arc = 1, 2 do
		local angle = arc == 1 and 0.35 or math.pi - 0.35
		local ax = math.cos(angle)
		local az = math.sin(angle)
		for i = -9, 9 do
			local t = i / 9
			local px = ax * t * 150
			local pz = az * t * 150
			local height = 46 + math.cos(t * math.pi / 2) * 16
			local flag = part({
				Name = "Bunting",
				Size = Vector3.new(5.5, 7, 0.5),
				Position = Vector3.new(px, height, pz),
				Color = flagColors[(i % #flagColors) + 1],
				Material = Enum.Material.Fabric,
				CanCollide = false,
			}, model)
			flag.CFrame = CFrame.new(flag.Position) * CFrame.Angles(0, angle, math.rad(180))
		end
	end

	-- POSTES: dois anéis de luz, um na praça e um na borda do hub
	for ring = 1, 2 do
		local count = ring == 1 and 6 or 12
		local radius = ring == 1 and 128 or 220
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			part({
				Name = "HubPost",
				Size = Vector3.new(2.4, 22, 2.4),
				Position = Vector3.new(x, 12, z),
				Color = PALETTE.stoneDark,
				Material = Enum.Material.Metal,
			}, model)
			local lamp = ball({
				Name = "HubLamp",
				Size = Vector3.new(7, 7, 7),
				Position = Vector3.new(x, 25, z),
				Color = ring == 1 and Color3.fromRGB(255, 236, 170) or Color3.fromRGB(170, 226, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.1,
			}, model)
			local light = Instance.new("PointLight")
			light.Brightness = 2
			light.Range = 60
			light.Color = ring == 1 and Color3.fromRGB(255, 226, 160) or Color3.fromRGB(160, 220, 255)
			light.Parent = lamp
		end
	end

	-- BALÕES: sobem em espiral nas laterais, presos por um fio
	local balloonColors = {
		Color3.fromRGB(255, 110, 120),
		Color3.fromRGB(255, 214, 90),
		Color3.fromRGB(120, 220, 130),
		Color3.fromRGB(120, 180, 255),
		Color3.fromRGB(200, 150, 255),
	}
	for cluster = 1, 6 do
		local angle = (cluster / 6) * math.pi * 2 + 0.4
		local cx = math.cos(angle) * 168
		local cz = math.sin(angle) * 168
		for b = 1, 5 do
			local lift = 26 + b * 9
			local spread = 3 + b * 1.2
			ball({
				Name = "Balloon",
				Size = Vector3.new(8, 9.4, 8),
				Position = Vector3.new(cx + math.cos(b * 1.7) * spread, lift, cz + math.sin(b * 1.7) * spread),
				Color = balloonColors[(b % #balloonColors) + 1],
				Material = Enum.Material.Fabric,
				CanCollide = false,
			}, model)
		end
		part({
			Name = "BalloonString",
			Size = Vector3.new(0.3, 34, 0.3),
			Position = Vector3.new(cx, 24, cz),
			Color = Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, model)
	end
end

---------------------------------------------------------------------------
-- MARCOS (o icone gigante de cada ilha)
---------------------------------------------------------------------------

-- Cada bioma ganha um objeto grande e inconfundível, feito só de peças primitivas.
-- Nada de asset: esfera, cilindro, bloco e cunha em cores chapadas — o mesmo
-- vocabulário visual do resto do mapa, só em escala de "dá pra ver de longe".

-- Nuvem fofa: 4 esferas achatadas. Não colide, só decora.
local function cloud(parent, position, scale, color)
	-- Nuvem fofa de verdade: 7 esferas achatadas em arco, a maior no meio.
	-- Antes eram 4 esferas pequenas e de longe pareciam pedras de gelo.
	local puff = color or Color3.fromRGB(255, 255, 255)
	local lobes = {
		{ -1.55, -0.12, 0.0, 0.72 },
		{ -0.75, 0.16, 0.18, 0.95 },
		{ 0.05, 0.30, -0.10, 1.18 },
		{ 0.85, 0.14, 0.12, 0.92 },
		{ 1.60, -0.14, -0.05, 0.68 },
		{ -0.30, -0.20, 0.55, 0.62 },
		{ 0.45, -0.18, -0.52, 0.58 },
	}
	for i, lobe in ipairs(lobes) do
		local d = lobe[4] * 13 * scale
		part({
			Name = "CloudPuff" .. i,
			Size = Vector3.new(d, d * 0.72, d * 0.86),
			Position = position + Vector3.new(lobe[1] * 13 * scale, lobe[2] * 9 * scale, lobe[3] * 10 * scale),
			Color = puff,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.02,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
		}, parent)
	end
end

-- Solta nuvens em círculo ao redor de um ponto, em alturas diferentes.
local function cloudRing(parent, center, radius, height, count, scale, color)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local wobble = (i % 3) * 6
		cloud(
			parent,
			center + Vector3.new(math.cos(angle) * radius, height + wobble, math.sin(angle) * radius),
			scale,
			color
		)
	end
end

local function cone(parent, position, width, height, color, material)
	-- cone feito de cilindro invertido não existe no Roblox; empilhamos blocos
	-- decrescentes. Barato, e a silhueta fica triangular de longe.
	for tier = 1, 5 do
		local t = tier / 5
		local w = width * (1 - t * 0.78)
		part({
			Name = "Cone",
			Size = Vector3.new(w, height / 5 + 0.1, w),
			Position = position + Vector3.new(0, height * t - height / 10, 0),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
		}, parent)
	end
end

function World.buildLandmark(biome, parent, base)
	local accent = biome.colors.accent
	local accentColor = Color3.fromRGB(accent[1], accent[2], accent[3])
	local grassColor = Color3.fromRGB(biome.colors.grass[1], biome.colors.grass[2], biome.colors.grass[3])
	local rockColor = Color3.fromRGB(biome.colors.rock[1], biome.colors.rock[2], biome.colors.rock[3])
	local id = biome.id

	-- pedestal comum: um morrinho de terra que assenta o marco
	part({
		Name = "LandmarkBase",
		Size = Vector3.new(46, 8, 46),
		Position = base + Vector3.new(0, 2, 0),
		Color = grassColor,
		Material = Enum.Material.Grass,
	}, parent)

	if id == "meadow" then
		-- ARVORE MAE: tronco largo com copa de tres bolas gigantes
		part({
			Name = "MotherTrunk",
			Size = Vector3.new(14, 44, 14),
			Position = base + Vector3.new(0, 30, 0),
			Color = PALETTE.wood,
			Material = Enum.Material.Wood,
		}, parent)
		for i, offset in ipairs({
			{ 0, 58, 0, 30 },
			{ -18, 50, 6, 20 },
			{ 17, 52, -7, 22 },
		}) do
			ball({
				Name = "MotherCrown" .. i,
				Size = Vector3.new(offset[4], offset[4] * 0.82, offset[4]),
				Position = base + Vector3.new(offset[1], offset[2], offset[3]),
				Color = i == 1 and Color3.fromRGB(96, 200, 84) or Color3.fromRGB(74, 176, 70),
				Material = Enum.Material.Grass,
			}, parent)
		end
		-- balanço pendurado: criança adora
		part({
			Name = "SwingSeat",
			Size = Vector3.new(9, 1.2, 4),
			Position = base + Vector3.new(30, 26, 0),
			Color = PALETTE.woodDark,
			Material = Enum.Material.WoodPlanks,
		}, parent)
		for side = -1, 1, 2 do
			part({
				Name = "SwingRope",
				Size = Vector3.new(0.6, 26, 0.6),
				Position = base + Vector3.new(30 + side * 3.6, 39, 0),
				Color = PALETTE.sand,
				Material = Enum.Material.Fabric,
			}, parent)
		end
	elseif id == "forest" then
		-- COGUMELO GIGANTE BRILHANTE
		part({
			Name = "ShroomStem",
			Size = Vector3.new(18, 40, 18),
			Position = base + Vector3.new(0, 28, 0),
			Color = Color3.fromRGB(255, 246, 232),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
		ball({
			Name = "ShroomCap",
			Size = Vector3.new(52, 26, 52),
			Position = base + Vector3.new(0, 52, 0),
			Color = Color3.fromRGB(255, 96, 108),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
		-- pintas do chapéu
		local spots = { { 0, 62, 0 }, { 18, 56, 8 }, { -17, 57, 6 }, { 6, 56, -18 }, { -8, 58, -14 } }
		for i, spot in ipairs(spots) do
			ball({
				Name = "ShroomSpot" .. i,
				Size = Vector3.new(7, 4, 7),
				Position = base + Vector3.new(spot[1], spot[2], spot[3]),
				Color = Color3.fromRGB(255, 255, 245),
				Material = Enum.Material.SmoothPlastic,
			}, parent)
		end
		local glow = ball({
			Name = "ShroomGlow",
			Size = Vector3.new(20, 14, 20),
			Position = base + Vector3.new(0, 56, 0),
			Color = Color3.fromRGB(168, 255, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
		}, parent)
		local light = Instance.new("PointLight")
		light.Brightness = 2.4
		light.Range = 90
		light.Color = Color3.fromRGB(150, 255, 170)
		light.Parent = glow
	elseif id == "desert" then
		-- PIRAMIDE com porta e sol dourado no topo
		for step = 0, 6 do
			local width = 60 - step * 7.4
			part({
				Name = "PyramidStep",
				Size = Vector3.new(width, 6, width),
				Position = base + Vector3.new(0, 8 + step * 6, 0),
				Color = Color3.fromRGB(240, 206, 140),
				Material = Enum.Material.Sandstone,
			}, parent)
		end
		part({
			Name = "PyramidDoor",
			Size = Vector3.new(14, 18, 2),
			Position = base + Vector3.new(0, 15, 24),
			Color = Color3.fromRGB(120, 84, 50),
			Material = Enum.Material.Wood,
		}, parent)
		ball({
			Name = "SunDisc",
			Size = Vector3.new(22, 22, 4),
			Position = base + Vector3.new(0, 64, 0),
			Color = Color3.fromRGB(255, 214, 70),
			Material = Enum.Material.Neon,
		}, parent)
	elseif id == "ice" then
		-- CRISTAL DE GELO gigante + flocos suspensos
		local spike = part({
			Name = "IceSpike",
			Size = Vector3.new(20, 70, 20),
			Position = base + Vector3.new(0, 40, 0),
			Color = Color3.fromRGB(186, 236, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.25,
		}, parent)
		spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(0.1, 0.6, 0.08)
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2
			local px = math.cos(angle) * 26
			local pz = math.sin(angle) * 26
			local small = part({
				Name = "IceShard",
				Size = Vector3.new(9, 34, 9),
				Position = base + Vector3.new(px, 24, pz),
				Color = Color3.fromRGB(214, 244, 255),
				Material = Enum.Material.Ice,
				Transparency = 0.3,
			}, parent)
			small.CFrame = CFrame.new(small.Position) * CFrame.Angles(0.16, angle, -0.2)
		end
		cloudRing(parent, base, 44, 66, 5, 1.5, Color3.fromRGB(240, 252, 255))
	elseif id == "shadow" then
		-- OBELISCO escuro com runas roxas flutuando
		part({
			Name = "Obelisk",
			Size = Vector3.new(18, 78, 18),
			Position = base + Vector3.new(0, 43, 0),
			Color = Color3.fromRGB(52, 44, 78),
			Material = Enum.Material.Basalt,
		}, parent)
		cone(parent, base + Vector3.new(0, 84, 0), 18, 22, Color3.fromRGB(70, 60, 100), Enum.Material.Basalt)
		for i = 1, 5 do
			local rune = part({
				Name = "Rune" .. i,
				Size = Vector3.new(6, 6, 1.6),
				Position = base + Vector3.new(0, 22 + i * 11, 9.4),
				Color = Color3.fromRGB(190, 130, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, parent)
			local light = Instance.new("PointLight")
			light.Brightness = 1.4
			light.Range = 28
			light.Color = Color3.fromRGB(190, 130, 255)
			light.Parent = rune
		end
	elseif id == "halloween" then
		-- ABOBORA GIGANTE com cara esculpida e vela dentro
		ball({
			Name = "GreatPumpkin",
			Size = Vector3.new(70, 54, 70),
			Position = base + Vector3.new(0, 36, 0),
			Color = Color3.fromRGB(250, 138, 40),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
		part({
			Name = "PumpkinStemLandmark",
			Size = Vector3.new(7, 14, 7),
			Position = base + Vector3.new(0, 66, 0),
			Color = Color3.fromRGB(96, 132, 62),
			Material = Enum.Material.Grass,
		}, parent)
		-- olhos triangulares (dois blocos girados formam um X) e boca
		for side = -1, 1, 2 do
			local eye = part({
				Name = "Eye",
				Size = Vector3.new(10, 10, 2),
				Position = base + Vector3.new(side * 15, 44, 33),
				Color = Color3.fromRGB(255, 240, 130),
				Material = Enum.Material.Neon,
			}, parent)
			eye.CFrame = CFrame.new(eye.Position) * CFrame.Angles(0, 0, math.pi / 4)
		end
		for i = -2, 2 do
			part({
				Name = "MouthTooth",
				Size = Vector3.new(5, 9, 2),
				Position = base + Vector3.new(i * 7, 22, 34),
				Color = Color3.fromRGB(255, 240, 130),
				Material = Enum.Material.Neon,
			}, parent)
		end
		local fire = ball({
			Name = "PumpkinFire",
			Size = Vector3.new(16, 16, 16),
			Position = base + Vector3.new(0, 28, 0),
			Color = Color3.fromRGB(255, 170, 60),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		}, parent)
		local light = Instance.new("PointLight")
		light.Brightness = 3.2
		light.Range = 110
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Parent = fire
	else
		-- COSMOS: anel de Saturno com planetinha flutuante
		local ring1 = Instance.new("Part")
		ring1.Name = "Planet"
		ring1.Shape = Enum.PartType.Ball
		ring1.Size = Vector3.new(52, 52, 52)
		ring1.Position = base + Vector3.new(0, 48, 0)
		ring1.Color = Color3.fromRGB(150, 120, 230)
		ring1.Material = Enum.Material.Neon
		ring1.Anchored = true
		ring1.CanCollide = false
		ring1.Parent = parent

		for i = 1, 16 do
			local angle = (i / 16) * math.pi * 2
			local ringPart = part({
				Name = "Ring",
				Size = Vector3.new(7, 0.8, 4),
				Position = base + Vector3.new(math.cos(angle) * 42, 48, math.sin(angle) * 42),
				Color = i % 2 == 0 and Color3.fromRGB(255, 220, 130) or Color3.fromRGB(190, 160, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, parent)
			ringPart.CFrame = CFrame.new(ringPart.Position) * CFrame.Angles(0, -angle, 0)
		end

		for i, spot in ipairs({ { -34, 70, 14 }, { 30, 26, -18 }, { 16, 78, -26 } }) do
			ball({
				Name = "Moon" .. i,
				Size = Vector3.new(9 + i * 2, 9 + i * 2, 9 + i * 2),
				Position = base + Vector3.new(spot[1], spot[2], spot[3]),
				Color = Color3.fromRGB(220, 210, 255),
				Material = Enum.Material.Neon,
			}, parent)
		end
	end
end

---------------------------------------------------------------------------
-- ICONE DE PREVIA DO PORTAL
---------------------------------------------------------------------------

-- Versão em miniatura do marco de cada ilha, flutuando acima do portal no hub.
-- É a "vitrine" do mundo: quem está na praça vê os 7 destinos sem viajar.
function World.buildPortalIcon(biome, parent, top)
	local accent = biome.colors.accent
	local accentColor = Color3.fromRGB(accent[1], accent[2], accent[3])
	local id = biome.id

	local function blob(name, offset, size, color, material, transparency)
		return ball({
			Name = name,
			Size = size,
			Position = top + offset,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Transparency = transparency or 0,
		}, parent)
	end

	if id == "meadow" then
		part({
			Name = "IconTrunk",
			Size = Vector3.new(4, 12, 4),
			Position = top + Vector3.new(0, 5, 0),
			Color = PALETTE.wood,
			Material = Enum.Material.Wood,
		}, parent)
		blob(
			"IconCrown",
			Vector3.new(0, 13, 0),
			Vector3.new(13, 11, 13),
			Color3.fromRGB(96, 200, 84),
			Enum.Material.Grass
		)
		blob(
			"IconCrown",
			Vector3.new(-5, 11, 3),
			Vector3.new(8, 7, 8),
			Color3.fromRGB(255, 186, 214),
			Enum.Material.SmoothPlastic
		)
	elseif id == "forest" then
		part({
			Name = "IconStem",
			Size = Vector3.new(5, 9, 5),
			Position = top + Vector3.new(0, 4, 0),
			Color = Color3.fromRGB(255, 248, 236),
			Material = Enum.Material.SmoothPlastic,
		}, parent)
		blob(
			"IconCap",
			Vector3.new(0, 10, 0),
			Vector3.new(16, 8, 16),
			Color3.fromRGB(255, 96, 108),
			Enum.Material.SmoothPlastic
		)
		local glow = blob(
			"IconGlow",
			Vector3.new(0, 11, 0),
			Vector3.new(14, 9, 14),
			Color3.fromRGB(170, 255, 190),
			Enum.Material.Neon,
			0.55
		)
		local light = Instance.new("PointLight")
		light.Brightness = 1.6
		light.Range = 40
		light.Color = Color3.fromRGB(160, 255, 180)
		light.Parent = glow
	elseif id == "desert" then
		for step = 0, 3 do
			part({
				Name = "IconPyramid",
				Size = Vector3.new(15 - step * 3.2, 3.2, 15 - step * 3.2),
				Position = top + Vector3.new(0, 2 + step * 3.2, 0),
				Color = Color3.fromRGB(240, 206, 140),
				Material = Enum.Material.Sandstone,
			}, parent)
		end
		blob("IconSun", Vector3.new(0, 17, 0), Vector3.new(8, 8, 1.6), Color3.fromRGB(255, 214, 70), Enum.Material.Neon)
	elseif id == "ice" then
		local spike = part({
			Name = "IconIce",
			Size = Vector3.new(6, 20, 6),
			Position = top + Vector3.new(0, 11, 0),
			Color = Color3.fromRGB(186, 236, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.25,
		}, parent)
		spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(0.12, 0.5, 0.1)
		blob(
			"IconShard",
			Vector3.new(-7, 6, 2),
			Vector3.new(4, 12, 4),
			Color3.fromRGB(214, 244, 255),
			Enum.Material.Ice,
			0.3
		)
		blob(
			"IconShard",
			Vector3.new(6, 5, -3),
			Vector3.new(3.4, 10, 3.4),
			Color3.fromRGB(214, 244, 255),
			Enum.Material.Ice,
			0.3
		)
	elseif id == "shadow" then
		part({
			Name = "IconObelisk",
			Size = Vector3.new(5.4, 21, 5.4),
			Position = top + Vector3.new(0, 11, 0),
			Color = Color3.fromRGB(52, 44, 78),
			Material = Enum.Material.Basalt,
		}, parent)
		local rune = part({
			Name = "IconRune",
			Size = Vector3.new(2.6, 2.6, 0.8),
			Position = top + Vector3.new(0, 13, 3),
			Color = Color3.fromRGB(190, 130, 255),
			Material = Enum.Material.Neon,
		}, parent)
		local light = Instance.new("PointLight")
		light.Brightness = 1.4
		light.Range = 34
		light.Color = Color3.fromRGB(190, 130, 255)
		light.Parent = rune
	elseif id == "halloween" then
		blob(
			"IconPumpkin",
			Vector3.new(0, 9, 0),
			Vector3.new(17, 13, 17),
			Color3.fromRGB(250, 138, 40),
			Enum.Material.SmoothPlastic
		)
		local eye = part({
			Name = "IconEye",
			Size = Vector3.new(2.6, 2.6, 0.8),
			Position = top + Vector3.new(-2.6, 10.5, 8),
			Color = Color3.fromRGB(255, 240, 130),
			Material = Enum.Material.Neon,
		}, parent)
		eye.CFrame = CFrame.new(eye.Position) * CFrame.Angles(0, 0, math.pi / 4)
		local eye2 = part({
			Name = "IconEye",
			Size = Vector3.new(2.6, 2.6, 0.8),
			Position = top + Vector3.new(2.6, 10.5, 8),
			Color = Color3.fromRGB(255, 240, 130),
			Material = Enum.Material.Neon,
		}, parent)
		eye2.CFrame = CFrame.new(eye2.Position) * CFrame.Angles(0, 0, math.pi / 4)
	else
		blob(
			"IconPlanet",
			Vector3.new(0, 10, 0),
			Vector3.new(15, 15, 15),
			Color3.fromRGB(150, 120, 230),
			Enum.Material.Neon
		)
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local dot = part({
				Name = "IconRing",
				Size = Vector3.new(2.4, 0.4, 1.4),
				Position = top + Vector3.new(math.cos(angle) * 12, 10, math.sin(angle) * 12),
				Color = i % 2 == 0 and Color3.fromRGB(255, 220, 130) or Color3.fromRGB(190, 160, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, parent)
			dot.CFrame = CFrame.new(dot.Position) * CFrame.Angles(0, -angle, 0)
		end
	end

	-- brilho embaixo do ícone: separa do céu
	local halo =
		blob("IconHalo", Vector3.new(0, -3, 0), Vector3.new(18, 1.4, 18), accentColor, Enum.Material.Neon, 0.35)
	halo.Shape = Enum.PartType.Cylinder
end

---------------------------------------------------------------------------
-- BIOMAS
---------------------------------------------------------------------------

-- Toda ilha de bioma e feita dos mesmos ingredientes: base rochosa, praia,
-- relevo em grade, decoracao, portal, pedestal do ovo e area de spawn.
-- O que muda vem de Biomes.List (paleta, relevo, quantidades).

local biomeRoot

local function rgb(triple, transparency)
	local c = Color3.fromRGB(triple[1], triple[2], triple[3])
	return c, transparency
end

-- Portais: dois pilares + arco neon + plataforma de ativacao.
-- `targetBiome == nil` significa "portal de volta pro hub".
local function buildPortal(position, look, targetBiome, parent, name)
	local model = Instance.new("Model")
	model.Name = name or ("Portal_" .. (targetBiome and targetBiome.id or "hub"))
	model.Parent = parent

	local accent = look.accent

	-- base
	part({
		Name = "Base",
		Size = Vector3.new(38, 3, 38),
		Position = position + Vector3.new(0, 1.5, 0),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "BaseGlow",
		Size = Vector3.new(33, 0.6, 33),
		Position = position + Vector3.new(0, 3.3, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	-- pilares
	for side = -1, 1, 2 do
		part({
			Name = "Pillar",
			Size = Vector3.new(6, 34, 6),
			Position = position + Vector3.new(side * 15.5, 19, 0),
			Color = PALETTE.stone,
			Material = Enum.Material.Marble,
		}, model)

		part({
			Name = "PillarCap",
			Size = Vector3.new(8.6, 2, 8.6),
			Position = position + Vector3.new(side * 15.5, 36.4, 0),
			Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end

	-- arco
	part({
		Name = "Arch",
		Size = Vector3.new(37, 5.4, 6),
		Position = position + Vector3.new(0, 36.4, 0),
		Color = PALETTE.stone,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "ArchGlow",
		Size = Vector3.new(34, 1, 6.4),
		Position = position + Vector3.new(0, 38.6, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	-- veu do portal (nao colide: o jogador atravessa andando)
	local veil = part({
		Name = "Veil",
		Size = Vector3.new(29, 30, 0.8),
		Position = position + Vector3.new(0, 20, 0),
		Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Brightness = 2.2
	light.Range = 52
	light.Color = Color3.fromRGB(accent[1], accent[2], accent[3])
	light.Parent = veil

	-- detector de clique para teletransporte
	local detector = Instance.new("ClickDetector")
	detector.Name = "PortalClick"
	detector.MaxActivationDistance = 36
	detector.Parent = veil

	veil:SetAttribute("BiomeId", targetBiome and targetBiome.id or "meadow")
	veil:SetAttribute("Portal", true)

	local zoneName = targetBiome and ("portal_" .. targetBiome.id) or "portal_hub"
	zoneBindings[zoneName] = {
		part = veil,
		detector = detector,
		biomeId = targetBiome and targetBiome.id or nil,
		portal = true,
	}

	-- placa com o nome do destino
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(22, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 44, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = veil

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 60)
	label.Text = targetBiome and (targetBiome.emoji .. " " .. targetBiome.name) or "🏠 HUB"
	label.Parent = billboard

	-- Prévia do destino: um ícone flutuante grande acima do portal, feito de
	-- peças. A criança vê o que tem do outro lado antes de entrar, e o hub
	-- ganha 7 "estátuas" que dá vontade de visitar.
	if targetBiome then
		local iconModel = Instance.new("Model")
		iconModel.Name = "PortalIcon"
		iconModel.Parent = model
		local top = position + Vector3.new(0, 56, 0)
		World.buildPortalIcon(targetBiome, iconModel, top)
	end

	return model
end

-- Pedestal do ovo: base, anel neon e o ovo com pintinhas + placa.
local function buildEggPedestal(egg, position, parent)
	local model = Instance.new("Model")
	model.Name = "EggStand_" .. egg.id
	model.Parent = parent

	part({
		Name = "Pedestal",
		Size = Vector3.new(14, 3.6, 14),
		Position = position + Vector3.new(0, 1.8, 0),
		Color = PALETTE.white,
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "PedestalRing",
		Size = Vector3.new(11.5, 1, 11.5),
		Position = position + Vector3.new(0, 3.9, 0),
		Color = PALETTE.gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, model)

	local eggPart = ball({
		Name = "Egg_" .. egg.id,
		Size = Vector3.new(9.6, 13.2, 9.6),
		Position = position + Vector3.new(0, 10.6, 0),
		Color = egg.color,
		Material = Enum.Material.SmoothPlastic,
	}, model)

	local rng = Random.new(#egg.id * 977 + 13)
	for i = 1, 9 do
		local theta = rng:NextNumber() * math.pi * 2
		local phi = math.acos(2 * rng:NextNumber() - 1)
		local radius = 4.8
		ball({
			Name = "Spot",
			Size = Vector3.new(1.9, 1.9, 1.9),
			Position = eggPart.Position + Vector3.new(
				math.sin(phi) * math.cos(theta) * radius,
				math.cos(phi) * radius * 1.38,
				math.sin(phi) * math.sin(theta) * radius
			),
			Color = egg.spot,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, model)
	end

	-- ovo balanca de leve: o cliente anima pela atributo Spin
	eggPart:SetAttribute("EggId", egg.id)
	eggPart:SetAttribute("Spin", true)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(15, 6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = eggPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.55)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 55, 90)
	label.Text = egg.name
	label.Parent = billboard

	local price = Instance.new("TextLabel")
	price.Size = UDim2.fromScale(1, 0.4)
	price.Position = UDim2.fromScale(0, 0.58)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.FredokaOne
	price.TextScaled = true
	price.TextColor3 = PALETTE.gold
	price.TextStrokeTransparency = 0
	price.TextStrokeColor3 = Color3.fromRGB(70, 45, 10)
	price.Text = "🪙 " .. require(ReplicatedStorage.Shared.Format).number(egg.cost)
	price.Parent = billboard

	local detector = Instance.new("ClickDetector")
	detector.Name = "EggClick"
	detector.MaxActivationDistance = 26
	detector.Parent = eggPart

	zoneBindings["egg_" .. egg.id] = { part = eggPart, detector = detector, eggId = egg.id }
	return model
end

-- Decoração por tema, apoiada na altura real do relevo.
-- Enfeites que só aquele bioma tem. É aqui que a ilha deixa de ser "grama com
-- árvore" e vira um lugar com cara própria: flor de cerejeira no vale, cogumelo
-- na floresta, cacto no deserto, boneco de neve no gelo, lápide no sombrio,
-- abóbora no halloween e asteroide no cosmos.
local function themedDecor(biome, cells, home, center, rng)
	local accent = biome.colors.accent
	local accentColor = Color3.fromRGB(accent[1], accent[2], accent[3])
	local id = biome.id

	local function groundAt(angle, radius)
		local lx = math.cos(angle) * radius
		local lz = math.sin(angle) * radius
		return center + Vector3.new(lx, Terrain.heightAtCell(biome, cells, lx, lz), lz)
	end

	local function meadow()
		-- cerejeiras cor-de-rosa e bancos de madeira
		for i = 1, 7 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.42 + rng:NextNumber() * 0.36)
			local pos = groundAt(angle, radius)
			local scale = 0.8 + rng:NextNumber() * 0.4
			part({
				Name = "CherryTrunk",
				Size = Vector3.new(3 * scale, 14 * scale, 3 * scale),
				Position = pos + Vector3.new(0, 7 * scale, 0),
				Color = Color3.fromRGB(120, 84, 62),
				Material = Enum.Material.Wood,
			}, home)
			for k = 1, 3 do
				ball({
					Name = "CherryBloom",
					Size = Vector3.new((11 - k) * scale, (7 - k * 0.6) * scale, (11 - k) * scale),
					Position = pos + Vector3.new((k - 2) * 4, (14 + k * 2.4) * scale, (k % 2) * 3),
					Color = k == 2 and Color3.fromRGB(255, 196, 220) or Color3.fromRGB(255, 168, 200),
					Material = Enum.Material.SmoothPlastic,
				}, home)
			end
		end
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2 + 0.4
			local pos = groundAt(angle, biome.radius * 0.4)
			part({
				Name = "Bench",
				Size = Vector3.new(10, 1.2, 4),
				Position = pos + Vector3.new(0, 2, 0),
				Color = PALETTE.wood,
				Material = Enum.Material.WoodPlanks,
			}, home)
			for side = -1, 1, 2 do
				part({
					Name = "BenchLeg",
					Size = Vector3.new(1.4, 2.4, 3.4),
					Position = pos + Vector3.new(side * 3.6, 0.8, 0),
					Color = PALETTE.woodDark,
					Material = Enum.Material.Wood,
				}, home)
			end
		end
	end

	local function forest()
		-- cogumelos luminosos e troncos caídos
		for i = 1, 12 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.3 + rng:NextNumber() * 0.5)
			local pos = groundAt(angle, radius)
			local scale = 0.5 + rng:NextNumber() * 0.9
			part({
				Name = "ShroomStem",
				Size = Vector3.new(2.4 * scale, 5 * scale, 2.4 * scale),
				Position = pos + Vector3.new(0, 2.5 * scale, 0),
				Color = Color3.fromRGB(255, 248, 236),
				Material = Enum.Material.SmoothPlastic,
			}, home)
			local cap = ball({
				Name = "ShroomCap",
				Size = Vector3.new(7 * scale, 3.4 * scale, 7 * scale),
				Position = pos + Vector3.new(0, 5.4 * scale, 0),
				Color = i % 3 == 0 and Color3.fromRGB(255, 120, 140) or Color3.fromRGB(180, 140, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.15,
			}, home)
			if i % 3 == 0 then
				local glow = Instance.new("PointLight")
				glow.Brightness = 1.1
				glow.Range = 22
				glow.Color = Color3.fromRGB(190, 255, 190)
				glow.Parent = cap
			end
		end
		for i = 1, 5 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.35 + rng:NextNumber() * 0.45)
			local pos = groundAt(angle, radius)
			local log = part({
				Name = "FallenLog",
				Size = Vector3.new(4, 4, 18),
				Position = pos + Vector3.new(0, 2, 0),
				Color = Color3.fromRGB(96, 72, 52),
				Material = Enum.Material.Wood,
			}, home)
			log.CFrame = CFrame.new(log.Position) * CFrame.Angles(0, rng:NextNumber() * 3.14, 0)
		end
	end

	local function desert()
		-- cactos com braços, e ossadas de pedra
		for i = 1, 11 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.3 + rng:NextNumber() * 0.5)
			local pos = groundAt(angle, radius)
			local scale = 0.7 + rng:NextNumber() * 0.8
			part({
				Name = "Cactus",
				Size = Vector3.new(4 * scale, 14 * scale, 4 * scale),
				Position = pos + Vector3.new(0, 7 * scale, 0),
				Color = Color3.fromRGB(96, 168, 96),
				Material = Enum.Material.Grass,
			}, home)
			for side = -1, 1, 2 do
				part({
					Name = "CactusArm",
					Size = Vector3.new(6 * scale, 1.6 * scale, 2.4 * scale),
					Position = pos + Vector3.new(side * 2.6 * scale, 8 * scale, 0),
					Color = Color3.fromRGB(96, 168, 96),
					Material = Enum.Material.Grass,
				}, home)
			end
		end
		for i = 1, 3 do
			local angle = (i / 3) * math.pi * 2
			local pos = groundAt(angle, biome.radius * 0.55)
			local rib = part({
				Name = "BoneRib",
				Size = Vector3.new(14, 1.2, 1.2),
				Position = pos + Vector3.new(0, 3, 0),
				Color = Color3.fromRGB(246, 238, 214),
				Material = Enum.Material.Marble,
			}, home)
			rib.CFrame = CFrame.new(rib.Position) * CFrame.Angles(0.3, angle, 0.25)
		end
	end

	local function ice()
		-- boneco de neve e pinheiros pequenos de gelo
		for i = 1, 3 do
			local angle = (i / 3) * math.pi * 2 + 0.5
			local pos = groundAt(angle, biome.radius * 0.42)
			ball({
				Name = "SnowBase",
				Size = Vector3.new(11, 9, 11),
				Position = pos + Vector3.new(0, 4.5, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Enum.Material.Snow,
			}, home)
			ball({
				Name = "SnowBelly",
				Size = Vector3.new(8, 7, 8),
				Position = pos + Vector3.new(0, 11.5, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Enum.Material.Snow,
			}, home)
			ball({
				Name = "SnowHead",
				Size = Vector3.new(5.6, 5.4, 5.6),
				Position = pos + Vector3.new(0, 17, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Enum.Material.Snow,
			}, home)
			-- cenoura do nariz
			local nose = part({
				Name = "SnowNose",
				Size = Vector3.new(3, 1.2, 1.2),
				Position = pos + Vector3.new(0, 17, 3),
				Color = Color3.fromRGB(255, 150, 60),
				Material = Enum.Material.SmoothPlastic,
			}, home)
			nose.CFrame = CFrame.new(nose.Position) * CFrame.Angles(0, 0, math.rad(-8))
			part({
				Name = "SnowHat",
				Size = Vector3.new(4.4, 3.4, 4.4),
				Position = pos + Vector3.new(0, 20.4, 0),
				Color = Color3.fromRGB(60, 60, 76),
				Material = Enum.Material.Fabric,
			}, home)
			part({
				Name = "SnowScarf",
				Size = Vector3.new(6.8, 1.4, 6.8),
				Position = pos + Vector3.new(0, 14.6, 0),
				Color = Color3.fromRGB(240, 90, 96),
				Material = Enum.Material.Fabric,
			}, home)
		end
		for i = 1, 8 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.32 + rng:NextNumber() * 0.5)
			local pos = groundAt(angle, radius)
			local scale = 0.6 + rng:NextNumber() * 0.7
			part({
				Name = "IceTreeTrunk",
				Size = Vector3.new(2.4 * scale, 8 * scale, 2.4 * scale),
				Position = pos + Vector3.new(0, 4 * scale, 0),
				Color = Color3.fromRGB(140, 128, 150),
				Material = Enum.Material.Wood,
			}, home)
			for tier = 1, 3 do
				local w = (7.5 - tier * 1.6) * scale
				part({
					Name = "IceTreeLeaf",
					Size = Vector3.new(w, 4 * scale, w),
					Position = pos + Vector3.new(0, (6.6 + tier * 2.8) * scale, 0),
					Color = Color3.fromRGB(232, 248, 255),
					Material = Enum.Material.Snow,
				}, home)
			end
		end
	end

	local function shadow()
		-- lápides tortas e lanternas de alma
		for i = 1, 10 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.28 + rng:NextNumber() * 0.55)
			local pos = groundAt(angle, radius)
			local stone = part({
				Name = "Grave",
				Size = Vector3.new(5, 9, 1.6),
				Position = pos + Vector3.new(0, 4, 0),
				Color = Color3.fromRGB(88, 84, 110),
				Material = Enum.Material.Slate,
			}, home)
			stone.CFrame = CFrame.new(stone.Position)
				* CFrame.Angles(0, rng:NextNumber() * 3.14, math.rad(rng:NextNumber() * 14 - 7))
			ball({
				Name = "GraveTop",
				Size = Vector3.new(5, 5, 1.6),
				Position = pos + Vector3.new(0, 8.4, 0),
				Color = Color3.fromRGB(88, 84, 110),
				Material = Enum.Material.Slate,
			}, home)
		end
		for i = 1, 6 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.34 + rng:NextNumber() * 0.4)
			local pos = groundAt(angle, radius)
			part({
				Name = "LanternPost",
				Size = Vector3.new(1.2, 9, 1.2),
				Position = pos + Vector3.new(0, 4.5, 0),
				Color = Color3.fromRGB(48, 42, 62),
				Material = Enum.Material.Metal,
			}, home)
			local flame = ball({
				Name = "SoulFlame",
				Size = Vector3.new(3.6, 4.4, 3.6),
				Position = pos + Vector3.new(0, 10.4, 0),
				Color = accentColor,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			}, home)
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.6
			glow.Range = 30
			glow.Color = accentColor
			glow.Parent = flame
		end
	end

	local function halloween()
		-- abóboras pequenas e velas flutuantes
		for i = 1, 14 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.28 + rng:NextNumber() * 0.5)
			local pos = groundAt(angle, radius)
			local scale = 0.5 + rng:NextNumber() * 0.8
			ball({
				Name = "SmallPumpkin",
				Size = Vector3.new(7 * scale, 5.4 * scale, 7 * scale),
				Position = pos + Vector3.new(0, 2.7 * scale, 0),
				Color = i % 4 == 0 and Color3.fromRGB(255, 190, 70) or Color3.fromRGB(246, 140, 46),
				Material = Enum.Material.SmoothPlastic,
			}, home)
			part({
				Name = "SmallStem",
				Size = Vector3.new(1.2 * scale, 2 * scale, 1.2 * scale),
				Position = pos + Vector3.new(0, 5.6 * scale, 0),
				Color = Color3.fromRGB(96, 132, 62),
				Material = Enum.Material.Grass,
			}, home)
		end
		for i = 1, 5 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.4 + rng:NextNumber() * 0.35)
			local pos = groundAt(angle, radius)
			local candle = ball({
				Name = "GhostCandle",
				Size = Vector3.new(3.2, 5, 3.2),
				Position = pos + Vector3.new(0, 6, 0),
				Color = accentColor,
				Material = Enum.Material.Neon,
				Transparency = 0.3,
			}, home)
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.8
			glow.Range = 26
			glow.Color = accentColor
			glow.Parent = candle
		end
	end

	local function cosmos()
		-- asteroides girando e estrelas caídas
		for i = 1, 10 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.3 + rng:NextNumber() * 0.55)
			local pos = groundAt(angle, radius)
			local scale = 0.6 + rng:NextNumber() * 1.1
			local rock = ball({
				Name = "Asteroid",
				Size = Vector3.new(6 * scale, 5 * scale, 6.4 * scale),
				Position = pos + Vector3.new(0, 2 * scale, 0),
				Color = Color3.fromRGB(92, 84, 130),
				Material = Enum.Material.Slate,
			}, home)
			rock.CFrame = CFrame.new(rock.Position)
				* CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
		end
		for i = 1, 7 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.35 + rng:NextNumber() * 0.45)
			local pos = groundAt(angle, radius)
			local star = ball({
				Name = "FallenStar",
				Size = Vector3.new(3.6, 3.6, 3.6),
				Position = pos + Vector3.new(0, 4, 0),
				Color = Color3.fromRGB(255, 236, 160),
				Material = Enum.Material.Neon,
			}, home)
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.4
			glow.Range = 24
			glow.Color = Color3.fromRGB(255, 236, 160)
			glow.Parent = star
		end
	end

	local themes = {
		meadow = meadow,
		forest = forest,
		desert = desert,
		ice = ice,
		shadow = shadow,
		halloween = halloween,
		cosmos = cosmos,
	}
	local build = themes[id]
	if build then
		build()
	end
end

local function decorateBiome(biome, cells, home, center)
	local spec = biome.decor
	local accent = biome.colors.accent
	local rng = Random.new(biome.seed or 11)

	local function groundAt(angle, radius)
		local lx = math.cos(angle) * radius
		local lz = math.sin(angle) * radius
		return lx, lz, Terrain.heightAtCell(biome, cells, lx, lz)
	end

	-- anel onde a decoração pode nascer: fora do platô do ovo, dentro da ilha
	local placeable = biome.radius * 0.86
	local innerRing = biome.radius * 0.30

	-- árvores (ou pinheiros / abóboras, conforme o tema)
	for i = 1, spec.trees do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local scale = 0.7 + rng:NextNumber() * 0.8

		if biome.id == "halloween" then
			-- abóbora gigante
			local pos = center + Vector3.new(x, y + 3 * scale, z)
			local pumpkin = ball({
				Name = "Pumpkin",
				Size = Vector3.new(9 * scale, 7 * scale, 9 * scale),
				Position = pos,
				Color = Color3.fromRGB(250, 140, 40),
				Material = Enum.Material.SmoothPlastic,
			}, home)
			ball({
				Name = "PumpkinShade",
				Size = Vector3.new(9.6 * scale, 5 * scale, 9.6 * scale),
				Position = pos,
				Color = Color3.fromRGB(214, 104, 26),
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.55,
				CanCollide = false,
			}, home)
			part({
				Name = "PumpkinStem",
				Size = Vector3.new(1.6, 3 * scale, 1.6),
				Position = pos + Vector3.new(0, 5 * scale, 0),
				Color = Color3.fromRGB(90, 130, 60),
				Material = Enum.Material.Grass,
			}, home)
		elseif biome.id == "ice" or biome.id == "forest" then
			-- pinheiro: tronco + 3 cones empilhados
			local pos = center + Vector3.new(x, y, z)
			local trunkColor = biome.id == "ice" and Color3.fromRGB(150, 140, 150) or Color3.fromRGB(110, 80, 55)
			local leafColor = biome.id == "ice" and Color3.fromRGB(226, 244, 255) or Color3.fromRGB(52, 140, 88)
			part({
				Name = "Trunk",
				Size = Vector3.new(2.6 * scale, 9 * scale, 2.6 * scale),
				Position = pos + Vector3.new(0, 4.5 * scale, 0),
				Color = trunkColor,
				Material = Enum.Material.Wood,
			}, home)
			for tier = 1, 3 do
				local w = (8.5 - tier * 1.7) * scale
				part({
					Name = "Leaf",
					Size = Vector3.new(w, 5.2 * scale, w),
					Position = pos + Vector3.new(0, (7 + tier * 3.4) * scale, 0),
					Color = leafColor,
					Material = Enum.Material.Grass,
				}, home)
			end
		else
			tree(center + Vector3.new(x, y, z), scale, home)
		end
	end

	-- pedras
	for i = 1, spec.rocks do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local scale = 0.8 + rng:NextNumber() * 1.4
		ball({
			Name = "Rock",
			Size = Vector3.new(5 * scale, 4 * scale, 5.5 * scale),
			Position = center + Vector3.new(x, y + 1.2 * scale, z),
			Color = Color3.fromRGB(biome.colors.rock[1], biome.colors.rock[2], biome.colors.rock[3]),
			Material = Enum.Material.Slate,
		}, home)
	end

	-- flores (só bioma de grama)
	for i = 1, spec.flowers do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		flower(center + Vector3.new(x, y, z), home)
	end

	themedDecor(biome, cells, home, center, rng)

	-- cristais brilhantes (gelo, sombrio, cosmos, deserto)
	for i = 1, spec.crystals do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local x, z, y = groundAt(angle, radius)
		local height = 4 + rng:NextNumber() * 9
		local crystal = part({
			Name = "Crystal",
			Size = Vector3.new(2.4, height, 2.4),
			Position = center + Vector3.new(x, y + height / 2, z),
			Color = Color3.fromRGB(accent[1], accent[2], accent[3]),
			Material = Enum.Material.Neon,
		}, home)
		crystal.CFrame = CFrame.new(crystal.Position) * CFrame.Angles(0.18, rng:NextNumber() * 6.28, -0.14)
	end
end

-- Constroi um bioma inteiro e devolve as referências que o servidor precisa.
function World.buildBiome(biome, portalPosition, parent)
	local home = Instance.new("Model")
	home.Name = "Biome_" .. biome.id
	home.Parent = parent

	local center = Biomes.centerVector(biome)
	local colors = biome.colors

	-- CASCO DA ILHA
	-- Uma laje quadrada de 26 studs vira uma "plaquinha" vista de longe. O
	-- casco é feito de camadas cilíndricas que afunilam para baixo, com rocha
	-- irregular na borda: a silhueta fica orgânica e a ilha ganha peso.
	local rockColor = Color3.fromRGB(colors.rock[1], colors.rock[2], colors.rock[3])
	local rockDeep = Color3.fromRGB(colors.rock[1] - 42, colors.rock[2] - 42, colors.rock[3] - 42)
	local rockUnder = Color3.fromRGB(colors.rock[1] - 70, colors.rock[2] - 70, colors.rock[3] - 70)

	for tier = 1, 4 do
		local t = (tier - 1) / 3
		local diameter = biome.radius * (2.24 - t * 0.95)
		local thickness = 11
		local tierPart = part({
			Name = tier == 1 and "Base" or "BaseTier",
			Size = Vector3.new(thickness, diameter, diameter),
			Position = center + Vector3.new(0, -8 - (tier - 1) * 10.2, 0),
			Color = tier == 1 and rockColor or (tier == 2 and rockDeep or rockUnder),
			Material = Enum.Material.Slate,
			Shape = Enum.PartType.Cylinder,
			CanCollide = tier == 1,
		}, home)
		-- PartType.Cylinder cresce no eixo X: deitar para virar disco
		tierPart.CFrame = CFrame.new(tierPart.Position) * CFrame.Angles(0, 0, math.pi / 2)
	end

	-- ponta cônica embaixo: fecha a ilha com uma agulha de pedra
	for tier = 1, 5 do
		local t = tier / 5
		local diameter = biome.radius * (1.25 - t * 1.05)
		if diameter > 2 then
			local spike = part({
				Name = "BaseSpike",
				Size = Vector3.new(12, diameter, diameter),
				Position = center + Vector3.new(0, -50 - tier * 9, 0),
				Color = rockUnder,
				Material = Enum.Material.Slate,
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
			}, home)
			spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- rochas na borda: quebram o círculo perfeito do cilindro
	local edgeRng = Random.new((biome.seed or 7) + 91)
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + edgeRng:NextNumber() * 0.2
		local radius = biome.radius * (1.04 + edgeRng:NextNumber() * 0.12)
		local scale = 0.5 + edgeRng:NextNumber() * 0.9
		local rock = part({
			Name = "EdgeRock",
			Size = Vector3.new(14 * scale, 11 * scale, 14 * scale),
			Position = center
				+ Vector3.new(math.cos(angle) * radius, -16 - edgeRng:NextNumber() * 14, math.sin(angle) * radius),
			Color = rockDeep,
			Material = Enum.Material.Rock,
		}, home)
		rock.CFrame = CFrame.new(rock.Position)
			* CFrame.Angles(edgeRng:NextNumber() * 0.6, edgeRng:NextNumber() * 6.28, edgeRng:NextNumber() * 0.6)
	end

	-- PRAIA: disco circular (cilindro achatado) em vez de quadrado
	local beach = part({
		Name = "Beach",
		Size = Vector3.new(3.2, biome.radius * 2.16, biome.radius * 2.16),
		Position = center + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(colors.sand[1], colors.sand[2], colors.sand[3]),
		Material = Enum.Material.Sand,
		Shape = Enum.PartType.Cylinder,
	}, home)
	beach.CFrame = CFrame.new(beach.Position) * CFrame.Angles(0, 0, math.pi / 2)

	-- relevo em grade
	local cells = Terrain.generate(biome)
	-- Altura do chão no miolo. Serve para assentar ovo, placa, pad e luz: se o
	-- relevo mudar, tudo acompanha em vez de afundar.
	local groundY = Terrain.heightAtCell(biome, cells, 0, 0)
	local cellModel = Instance.new("Model")
	cellModel.Name = "Terrain"
	cellModel.Parent = home

	-- CHÃO CONTÍNUO
	-- As células são blocos de alturas diferentes empilhados em degraus.
	-- Vistos de cima, cada bloco é um quadrado com vão em volta: o chão
	-- parecia um xadrez flutuando sobre a praia, não terreno maciço.
	-- Esta laje única, logo abaixo do relevo, fecha todos os vãos de uma vez.
	-- Material "Ground" e cor da terra: se aparecer em alguma fresta, lê
	-- como solo, não como buraco.
	local floorTop = groundY - Terrain.CellThickness * 0.6
	local groundDisc = part({
		Name = "GroundDisc",
		Size = Vector3.new(Terrain.CellThickness * 2.2, biome.radius * 1.94, biome.radius * 1.94),
		Position = center + Vector3.new(0, floorTop, 0),
		Color = Color3.fromRGB(
			math.max(0, colors.grassDark[1] - 18),
			math.max(0, colors.grassDark[2] - 18),
			math.max(0, colors.grassDark[3] - 18)
		),
		Material = Enum.Material.Ground,
		CanCollide = true,
		Shape = Enum.PartType.Cylinder,
	}, cellModel)
	groundDisc.CFrame = CFrame.new(groundDisc.Position) * CFrame.Angles(0, 0, math.pi / 2)

	for _, cell in ipairs(cells) do
		local cellPart = part({
			Name = cell.top and "CellTop" or "CellFill",
			Size = Vector3.new(cell.sx, cell.sy, cell.sz),
			Position = center + Vector3.new(cell.x, cell.y, cell.z),
			Color = Color3.fromRGB(cell.color[1], cell.color[2], cell.color[3]),
			Material = cell.kind == "sand" and Enum.Material.Sand or Enum.Material.Grass,
			CanCollide = true,
		}, cellModel)
		cellPart.TopSurface = Enum.SurfaceType.Smooth
	end

	decorateBiome(biome, cells, home, center)

	-- LUZ DO BIOMA
	-- Cada ilha tem a própria luz: sem isso, sombra e ambiente iguais em todo
	-- lugar e a floresta fica com a cara do deserto. São três coisas:
	--   1. uma luz central grande que "aquece" a ilha inteira
	--   2. postes de luz espalhados (visíveis e coloridos, criança adora)
	--   3. um PointLight na placa do bioma, para ler o nome no escuro
	local spec = biome.light
	local ambientColor = Color3.fromRGB(spec.ambience[1], spec.ambience[2], spec.ambience[3])
	local glowColor = Color3.fromRGB(spec.glow[1], spec.glow[2], spec.glow[3])

	local sun = Instance.new("PointLight")
	sun.Name = "BiomeLight"
	sun.Brightness = spec.intensity
	sun.Range = spec.range
	sun.Color = ambientColor
	sun.Shadows = false
	sun.Parent = part({
		Name = "LightAnchor",
		Size = Vector3.new(2, 2, 2),
		Position = center + Vector3.new(0, groundY + 46, 0),
		Color = glowColor,
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
	}, home)

	-- postes: um anel de luzes na borda da ilha, virados para o centro
	local postCount = biome.id == "cosmos" and 6 or 8
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		local radius = biome.radius * 0.62
		local lx, lz = math.cos(angle) * radius, math.sin(angle) * radius
		local gy = Terrain.heightAtCell(biome, cells, lx, lz)
		local base = Vector3.new(center.X + lx, center.Y + gy, center.Z + lz)

		part({
			Name = "Post",
			Size = Vector3.new(1.6, 14, 1.6),
			Position = base + Vector3.new(0, 7, 0),
			Color = PALETTE.stoneDark,
			Material = Enum.Material.Metal,
		}, home)

		local bulb = ball({
			Name = "PostBulb",
			Size = Vector3.new(4.6, 4.6, 4.6),
			Position = base + Vector3.new(0, 15, 0),
			Color = glowColor,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		}, home)

		local bulbLight = Instance.new("PointLight")
		bulbLight.Brightness = 1.8
		bulbLight.Range = 46
		bulbLight.Color = glowColor
		bulbLight.Parent = bulb
	end

	-- pedestal do ovo no miolo plano, na altura real do chão
	local egg = GameConfig.EggById[biome.eggId]
	local eggSpot = Vector3.new(center.X, center.Y + groundY, center.Z)
	if egg then
		buildEggPedestal(egg, eggSpot, home)
	end

	-- ICONE GIGANTE DO BIOMA
	-- Peça central que a criança identifica de longe: cada ilha tem um objeto
	-- grande, na altura, virado para o hub. Serve de ponto de referência ao
	-- viajar e dá personalidade — antes todas as ilhas eram "grama + árvore".
	local iconBase = Vector3.new(
		center.X,
		center.Y + Terrain.heightAtCell(biome, cells, biome.radius * 0.34, 0),
		center.Z + biome.radius * 0.02
	)
	local iconModel = Instance.new("Model")
	iconModel.Name = "Landmark"
	iconModel.Parent = home
	World.buildLandmark(biome, iconModel, iconBase)

	-- portal de volta para o hub
	local spawn = Biomes.spawnPoint(biome)
	local portal = buildPortal(portalPosition, {
		accent = colors.accent,
	}, nil, home, "Portal_Return")

	-- placa do bioma
	makeSign(Vector3.new(center.X, center.Y + groundY + 34, center.Z), biome.name, Color3.fromRGB(255, 255, 255), home)

	-- area de chegada: plataforma discreta onde o jogador aparece
	part({
		Name = "ArrivalPad",
		Size = Vector3.new(30, 1, 30),
		Position = Vector3.new(spawn.X, center.Y + groundY + 0.6, spawn.Z),
		Color = Color3.fromRGB(colors.accent[1], colors.accent[2], colors.accent[3]),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	}, home)

	return {
		biome = biome,
		model = home,
		center = center,
		eggSpot = eggSpot,
		spawn = spawn,
		portal = portal,
	}
end

-- Portais do hub: um por bioma, no anel externo da praça, alinhados com a
-- direção real da ilha. Assim o jogador vê para onde o portal leva.
local biomeRefs = {}

function World.buildBiomes()
	biomeRoot = Instance.new("Folder")
	biomeRoot.Name = "Biomes"
	biomeRoot.Parent = root

	-- Céu do arquipélago: nuvens altas entre as ilhas. Dão a sensação de
	-- distância (sem elas o vazio parece fim do mapa) e são o tipo de enfeite
	-- que criança nota na hora.
	local skyFolder = Instance.new("Folder")
	skyFolder.Name = "Sky"
	skyFolder.Parent = root

	cloudRing(root, Vector3.new(0, 0, 0), 620, 230, 11, 2.6)
	cloudRing(root, Vector3.new(0, 0, 0), 980, 300, 13, 3.4)
	cloudRing(root, Vector3.new(0, 0, 0), 1450, 380, 15, 4.4)
	cloudRing(skyFolder, Vector3.new(0, Biomes.SkyHeight, 0), 190, 70, 7, 1.6, Color3.fromRGB(226, 214, 255))

	-- Ilhas flutuantes de enfeite no caminho entre o hub e os biomas. Não
	-- colidem e não têm função: existem para o percurso parecer um mundo.
	-- Ilhas flutuantes de enfeite no caminho entre o hub e os biomas.
	--
	-- Antes elas tinham a MESMA assinatura visual de uma ilha de verdade:
	-- topo plano de grama sobre um bloco de pedra. Algumas nasciam altas
	-- (height ate +80) e de longe pareciam pedaços arrancados do mapa
	-- boiando no céu — foi a origem dos "quadrados verdes" no render.
	-- Agora são rochas flutuantes de verdade: pedra pura, sem grama, em
	-- altura baixa. Ninguém confunde com uma ilha jogável.
	local rngIslets = Random.new(4711)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + 0.3
		local distance = 320 + rngIslets:NextNumber() * 460
		-- altura baixa: entre a linha d'água e pouco acima dela
		local height = -18 + rngIslets:NextNumber() * 34
		local size = 14 + rngIslets:NextNumber() * 22
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		local rock = ball({
			Name = "SkyRock",
			Size = Vector3.new(size * 1.7, size * 0.9, size * 1.5),
			Position = Vector3.new(x, height, z),
			Color = PALETTE.rockDark,
			Material = Enum.Material.Slate,
		}, skyFolder)
		rock.CanCollide = false
		rock.CanQuery = false
		-- uma pedra menor de apoio, para a silhueta não ser uma bola só
		ball({
			Name = "SkyRock",
			Size = Vector3.new(size * 0.9, size * 0.6, size * 0.8),
			Position = Vector3.new(x + size * 0.6, height - size * 0.4, z - size * 0.3),
			Color = PALETTE.rock,
			Material = Enum.Material.Slate,
			CanCollide = false,
		}, skyFolder)
	end

	for _, biome in ipairs(Biomes.List) do
		local center = Biomes.centerVector(biome)

		-- direção no plano entre o hub e a ilha
		local flat = Vector3.new(center.X, 0, center.Z)
		if flat.Magnitude < 1 then
			flat = Vector3.new(0, 0, -1) -- cosmos fica no alto (centro do hub)
		end

		-- portal do hub
		local portalPosition = Vector3.new(0, 0, 0)
		if flat.Magnitude > 1 then
			portalPosition = flat.Unit * 138
		end
		buildPortal(portalPosition, { accent = biome.colors.accent }, biome, root, "PortalTo_" .. biome.id)

		-- Portal de volta: na encosta, virado para o hub. A altura vem do
		-- próprio relevo — o portal fica em cima do chão, não afundado na base.
		local direction = flat.Magnitude < 1 and Vector3.new(0, 0, 1) or flat.Unit
		local portalRadius = biome.radius * 0.66
		local portalX = center.X + direction.X * portalRadius
		local portalZ = center.Z + direction.Z * portalRadius
		local cells = Terrain.generate(biome)
		local localX = portalX - center.X
		local localZ = portalZ - center.Z
		local backPosition =
			Vector3.new(portalX, center.Y + Terrain.heightAtCell(biome, cells, localX, localZ), portalZ)

		biomeRefs[biome.id] = World.buildBiome(biome, backPosition, biomeRoot)
	end
end

function World.getBiomeRefs()
	return biomeRefs
end

function World.biomeArrival(biomeId)
	local ref = biomeRefs[biomeId]
	if not ref then
		return nil
	end
	return CFrame.new(ref.spawn)
		* CFrame.Angles(0, math.atan2(ref.center.X - ref.spawn.X, ref.center.Z - ref.spawn.Z), 0)
end

function World.centerOf(biomeId)
	local ref = biomeRefs[biomeId]
	return ref and ref.center or nil
end

return World
