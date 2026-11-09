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
local Style = require(ReplicatedStorage.Shared.Style)
local Combat = require(ReplicatedStorage.Shared.Combat)

local World = {}

-- forward declaration: a cerca do hub e chamada no comeco de World.build(),
-- antes de buildFence estar definida mais abaixo.
local buildFence

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
	p.Material = props.material or Style.flat
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
	-- Números vindos do render, não do olho no Studio: o preview lê estes
	-- valores do build (tools/preview.py, lighting_gain). Com Brightness 3.1
	-- e Exposure 0.35 a ilha estourava — pedra virava branco puro, grama
	-- virava neon e perdia todo o matiz. Cartoon é cor saturada e legível,
	-- não luz forte.
	-- SATURAÇÃO DE LUZ: o problema que o jogador viu na tela.
	--
	-- Três coisas somavam para lavar tudo em branco:
	--   1. Brightness 2.0 + Exposure 0 = a luz do sol já ia no limite
	--   2. as PointLights dos biomas (corrigidas acima, no buildBiome)
	--   3. o Sol em ClockTime 14.2, quase a pino: face horizontal recebe
	--      incidência máxima e é justamente o chão que o jogador olha.
	--
	-- Agora: sol mais baixo (17.5) e mais fraco, exposição levemente
	-- NEGATIVA. Exposição negativa puxa o branco de volta para a cor, é o
	-- ajuste que faz sombra existir e matiz aparecer. Cartoon não é imagem
	-- estourada; é cor chapada com contraste legível.
	-- O alvo NÃO é escurecer: é manter a cor legível. Escuro demais também é
	-- ruim (some o matiz, vira sopa cinza). O que estourava era a SOMA:
	-- sol forte + ambiente altíssimo + holofote na ilha. Tirei o holofote
	-- (buildBiome), trouxe sol e ambiente para perto do padrão do Roblox.
	Lighting.Ambient = Color3.fromRGB(118, 128, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(156, 170, 196)
	Lighting.Brightness = 1.9
	Lighting.ClockTime = 15.4
	Lighting.GeographicLatitude = -15
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.12
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.55
	Lighting.ExposureCompensation = -0.25
	Lighting.FogColor = Color3.fromRGB(196, 216, 240)
	Lighting.FogStart = 900
	Lighting.FogEnd = 4000

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
	-- Haze alto lava tudo que está longe e Glare cria aquele "borrão de
	-- sol" na tela. Os dois estavam altos demais para um jogo onde a criança
	-- precisa LER o mapa.
	atmosphere.Density = 0.18
	atmosphere.Haze = 0.30
	atmosphere.Glare = 0.0
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
		Material = Style.flat,
		Shape = Enum.PartType.Cylinder,
	}, root)
	hubGrass.CFrame = CFrame.new(hubGrass.Position) * CFrame.Angles(0, 0, math.pi / 2)

	local dirtRing = part({
		Name = "DirtRing",
		Size = Vector3.new(8, hubRadius * 2.06, hubRadius * 2.06),
		Position = Vector3.new(0, -7, 0),
		Color = Color3.fromRGB(170, 110, 70),
		Material = Style.flat,
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
		Material = Style.flat,
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
			Material = Style.flat,
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
			Material = Style.flat,
			CanCollide = false,
		}, root)
		spoke.CFrame = CFrame.new(spoke.Position) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	end

	-- cerca do hub: fica FORA do anel de portais (138) e DENTRO da grama (215).
	-- 190 deixa uma faixa de grama entre a cerca e a praia; em 178 sobrava
	-- praia vazia demais e a ilha parecia ter um "colarinho".
	buildFence(Vector3.new(0, 0, 0), 190, 40, Style.color.wood, Style.color.woodDark, root, 2.2, math.pi / 2)

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
		-- A grama do hub tem o topo em y=1.
		--
		-- Antes: UM bloco de até 26x18x27 por canteiro. De perto lia como
		-- caixote verde jogado no gramado, não vegetação. Agora cada canteiro
		-- é um tufo de 3 esferas achatadas de tamanhos diferentes: a silhueta
		-- irregular é o que faz ler como arbusto, e a variação de tom dá
		-- volume sem textura.
		local GROUND_TOP = 1
		local bush = Instance.new("Model")
		bush.Name = "Bush"
		bush.Parent = root
		local base = Vector3.new(x, GROUND_TOP, z)
		for lobe = 1, 3 do
			local d = (w * 0.42) * (1.15 - lobe * 0.16)
			ball({
				Name = "Leaf",
				Size = Vector3.new(d * 1.25, d * 0.72, d * 1.1),
				Position = base + Vector3.new(
					(lobe - 2) * d * 0.42 + rng:NextNumber() * 2,
					d * 0.34,
					(lobe % 2 == 0 and 1 or -1) * d * 0.3 + rng:NextNumber() * 2
				),
				Color = lobe == 2 and Style.color.grass
					or (lobe == 1 and Style.color.grassDark or Style.color.grassLight),
				Material = Style.flat,
			}, bush)
		end
	end

	World.buildTrees()
	World.buildFountain()
	World.buildFestival()
	World.buildEggStands()
	World.buildShop()
	World.buildGemShop()
	World.buildGoldenCrate()
	World.buildMine()
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
		Material = Style.flat,
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

-- Árvore low-poly cartoon.
--
-- DOIS defeitos corrigidos aqui:
--   1. A copa usava a paleta GLOBAL. Resultado: bola verde idêntica no
--      prado, no deserto e no gelo. Árvore de bioma tem que puxar a cor do
--      bioma, senão a ilha perde a identidade. `colors` é opcional: sem ele
--      cai na paleta global (é o caso das árvores do hub).
--   2. O tronco era um bloco de 3,6x9 — mais largo que alto, lia como
--      caixote embaixo da copa. Agora são três segmentos afinando para
--      cima, que é como um tronco lê de longe.
-- perfis de árvore: sem isto, uma floresta de 54 árvores é a MESMA árvore
-- 54 vezes. A silhueta é o que diferencia uma árvore da outra de longe, então
-- variamos altura do tronco, largura da copa e inclinação.
local TREE_SHAPES = {
	-- alta e esguia (pinheiro de folha larga)
	{ trunk = 1.55, spread = 0.78, lean = 0 },
	-- clássica, redonda
	{ trunk = 1.0, spread = 1.0, lean = 0 },
	-- baixa e gorda (árvore velha)
	{ trunk = 0.72, spread = 1.25, lean = 0 },
	-- inclinada, como quem cresceu brigando com o vento
	{ trunk = 1.1, spread = 0.95, lean = 0.16 },
}

local function tree(position, scale, parent, colors, shapeIndex)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent

	-- `colors` chega como tabela {r, g, b} (é o formato de Biomes.luau),
	-- não como Color3. Precisa converter antes de misturar.
	local function toColor(rgb, fallback)
		if not rgb then
			return fallback
		end
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end

	local leafMain = toColor(colors and colors.grass, Style.color.grass)
	local leafDark = toColor(colors and colors.grassDark, Style.color.grassDark)
	-- `accent` NÃO serve de tom de copa: no prado ele é rosa, e a árvore
	-- ficava com bolas cor-de-rosa. O tom de cima tem que ser o verde
	-- clareado, que é o que o sol bate.
	local leafLight = Style.lighten(leafMain, 0.30)
	local trunkColor = colors and Style.darken(leafDark, 0.32) or Style.color.woodDark

	-- perfil da árvore: escolhido por quem chama (ou sorteado), para a
	-- floresta não ser 54 cópias da mesma silhueta
	local shape = TREE_SHAPES[shapeIndex or 2] or TREE_SHAPES[2]
	local spread = shape.spread
	local lean = shape.lean

	-- tronco: três segmentos, cada um mais fino que o de baixo.
	-- `lean` desloca cada segmento para o lado: tronco torto, não reto.
	local segmentH = 6 * shape.trunk
	for i = 1, 3 do
		local w = 3.4 - (i - 1) * 0.62
		part({
			Name = "Trunk",
			Size = Vector3.new(w, segmentH, w) * scale,
			Position = position + Vector3.new(lean * segmentH * (i - 0.5) * scale, (segmentH * (i - 0.5)) * scale, 0),
			Color = i == 1 and trunkColor or Style.lighten(trunkColor, 0.06),
			Material = Style.flat,
		}, model)
	end

	-- copa: 5 esferas em volta de uma central, cada uma num tom.
	-- A variação de tom é o que dá volume sem precisar de textura.
	local trunkH = segmentH * 3
	local crown = position + Vector3.new(lean * trunkH * scale, trunkH * 1.0 * scale, 0)
	local lobes = {
		{ 0, 0, 0, 1.0, leafLight },
		{ -1.05, -0.18, 0.15, 0.72, leafDark },
		{ 1.05, -0.14, -0.2, 0.78, leafMain },
		{ 0.18, 0.62, 0.55, 0.62, leafLight },
		{ -0.2, 0.5, -0.62, 0.58, leafDark },
	}
	for i, lobe in ipairs(lobes) do
		local d = 11.5 * lobe[4] * spread * scale
		ball({
			Name = "Leaf",
			Size = Vector3.new(d, d * 0.92, d),
			Position = crown + Vector3.new(lobe[1] * 9 * scale, lobe[2] * 7 * scale, lobe[3] * 9 * scale),
			Color = lobe[5],
			Material = Style.flat,
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
		Material = Style.flat,
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
		Material = Style.flat,
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
			Material = Style.flat,
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
		Material = Style.flat,
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
-- [biomeId] = { arena, monster, target, detector } — o init.server liga o clique
local monsterBindings = {}

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

function World.getMonsterBindings()
	return monsterBindings
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
		Material = Style.flat,
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
		Material = Style.flat,
	}, root)

	-- parede de madeira
	part({
		Size = Vector3.new(26, 18, 2),
		Position = origin + Vector3.new(0, 10, -8),
		Color = PALETTE.wood,
		Material = Style.flat,
	}, root)

	-- telhado azul
	local roof = part({
		Size = Vector3.new(30, 2, 20),
		Position = origin + Vector3.new(0, 20, -2),
		Color = PALETTE.blue,
		Material = Style.flat,
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
		Material = Style.flat,
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
		Material = Style.flat,
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
		Material = Style.flat,
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
	light.Brightness = 1.7
	light.Range = 26
	light.Parent = gem

	makeZone(Net.Zones.GemShop, origin + Vector3.new(0, 4, 4), Vector3.new(24, 1, 14), Color3.fromRGB(200, 150, 255))
	makeSign(origin + Vector3.new(0, 25, -7), "MELHORIAS DE GEMAS", Color3.fromRGB(230, 200, 255), root)
end

---------------------------------------------------------------------------
-- CRIAÇÃO DOURADA (o "oven" dourado dos prints)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- ARENA DE COMBATE
---------------------------------------------------------------------------

-- Cada ilha ganha uma arena: um círculo de chão batido com o monstro no meio.
-- A arena existe para o jogador SABER onde a briga acontece sem ler nada.
-- Chão de cor diferente é o sinal mais barato e mais legível que existe.
-- Frações do raio do bioma. Ver buildArena e decorateBiome.
World.ArenaRadiusFraction = 0.46
World.ArenaOffsetFraction = 0.40

-- Deslocamento local (x, z) do centro da arena, relativo ao centro do bioma.
--
-- É a ÚNICA fonte dessa conta. Antes estava repetida em buildArena,
-- decorateBiome e themedDecor, e cada cópia usou um sinal diferente — a
-- arena ia para um lado e o "não plante aqui" para o outro, então nasciam
-- árvores exatamente sobre o monstro.
function World.arenaCenterOffset(biome)
	local center = biome.center
	local toHub = Vector3.new(center.x * -1, 0, center.z * -1)
	if toHub.Magnitude < 0.01 then
		toHub = Vector3.new(1, 0, 0)
	end
	toHub = toHub.Unit
	local d = World.ArenaOffsetFraction * biome.radius
	return Vector3.new(toHub.X * d, 0, toHub.Z * d)
end

function World.buildArena(biome, center, groundY, parent, cells)
	local monsterId = Combat.BiomeMonster[biome.id]
	if not monsterId then
		return nil
	end
	local spec = Combat.monsterById[monsterId]
	if not spec then
		return nil
	end

	-- fica no lado oposto ao portal, para o jogador ver a briga ao chegar.
	-- As frações moram em World.* porque decorateBiome também precisa delas
	-- para não plantar árvore dentro da arena: dois números soltos em dois
	-- lugares divergem na primeira vez que alguém mexer em um só.
	local arenaRadius = World.ArenaRadiusFraction * biome.radius
	local offset = World.ArenaOffsetFraction * biome.radius

	-- A ARENA FICA NO LADO OPOSTO AO SPAWN.
	--
	-- O ArrivalPad (onde o jogador nasce ao entrar no bioma) fica a 0.42 do
	-- raio na direção do hub. A arena ficava a 0.40 na direção +X, então em
	-- meadow as duas caíam praticamente no mesmo lugar (x 422 e x 424): o
	-- jogador nascia dentro da arena. Aqui a arena vai para o lado da
	-- direção do spawn, com o sinal invertido.
	local arenaCenter = World.arenaCenterOffset(biome)
	local arenaOffsetX, arenaOffsetZ = arenaCenter.X, arenaCenter.Z

	-- altura do terreno ONDE a arena fica. Mede num ponto DENTRO do raio
	-- (0.72 do deslocamento): perto da borda o heightAtCell pode cair fora
	-- da célula e devolver o platô.
	local arenaGroundY
	if cells then
		local probe = 0.72
		arenaGroundY = Terrain.heightAtCell(biome, cells, arenaOffsetX * probe, arenaOffsetZ * probe) + 0.12
	else
		arenaGroundY = groundY + 0.12
	end

	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena.Parent = parent

	-- chão batido: círculo achatado, cor de terra
	local floor = ball({
		Name = "ArenaFloor",
		Size = Vector3.new(arenaRadius * 1.9, 1.4, arenaRadius * 1.9),
		-- ALTURA MEDIDA NO LUGAR DA ARENA, não no centro do bioma.
		--
		-- groundY é a altura do topo do terreno em (0,0) — o platô do ovo.
		-- A arena fica a 0.40 do raio de distância, onde o relevo em degraus
		-- já desceu; usar groundY ali deixava a arena flutuando sobre uma
		-- plataforma, ou enterrada, dependendo do bioma.
		--
		-- Soma 0.12: encostada E acima. Coplanar com o terreno dá z-fighting
		-- no Roblox (as duas faces brigam pelo mesmo pixel e piscam).
		Position = center + Vector3.new(arenaOffsetX, arenaGroundY - 0.7, arenaOffsetZ),
		Color = Style.color.dirt,
		Material = Style.flat,
		CanCollide = false,
	}, arena)

	-- anel de pedras em volta: fecha a arena visualmente
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		ball({
			Name = "ArenaStone",
			Size = Vector3.new(3, 2.2, 3),
			Position = center + Vector3.new(
				arenaOffsetX + math.cos(angle) * arenaRadius * 0.95,
				arenaGroundY + 0.2,
				arenaOffsetZ + math.sin(angle) * arenaRadius * 0.95
			),
			Color = i % 2 == 0 and Style.color.rockDark or Style.color.rock,
			Material = Style.rock,
		}, arena)
	end

	-- o MONSTRO. Ele é um modelo solto no mundo (não é NPC com Humanoid:
	-- Humanoid gasta muito e não precisamos de física, só de alvo).
	-- `MonsterTarget` é a peça que o jogador clica.
	local monster = Instance.new("Model")
	monster.Name = "Monster"
	monster.Parent = arena

	local bodyColor = {
		slime = Color3.fromRGB(120, 210, 120),
		bat = Color3.fromRGB(120, 106, 160),
		golem = Color3.fromRGB(150, 140, 128),
		wraith = Color3.fromRGB(150, 120, 200),
		titan = Color3.fromRGB(220, 120, 90),
	}
	local color = bodyColor[monsterId] or Style.color.purple
	-- O MONSTRO PISA NO CHÃO DA ARENA.
	--
	-- `arenaGroundY` é o TOPO do terreno; a arena soma 0.12 e tem 1.4 de
	-- espessura com o centro em arenaGroundY - 0.7, então o piso da arena
	-- fica em arenaGroundY + 0.12 - 0.7 + 0.7 = arenaGroundY + 0.12.
	-- O corpo tem 11 de altura: o centro vai meia altura acima do piso.
	-- Antes era arenaGroundY + 0.2 + 6 = 6 studs acima do chão, e o monstro
	-- flutuava com as patas no ar.
	local MONSTER_HEIGHT = 11
	local arenaFloorY = arenaGroundY + 0.12
	local base = center + Vector3.new(arenaOffsetX, arenaFloorY + MONSTER_HEIGHT * 0.5, arenaOffsetZ)

	local target = ball({
		Name = "MonsterTarget",
		Size = Vector3.new(13, MONSTER_HEIGHT, 13),
		Position = base,
		Color = color,
		Material = Style.flat,
	}, monster)

	-- olhos: dois buracos escuros. Dá personalidade com 2 peças.
	for _, side in ipairs({ -1, 1 }) do
		ball({
			Name = "Eye",
			Size = Vector3.new(2.2, 2.6, 1.4),
			Position = base + Vector3.new(side * 2.6, 2.4, -5.6),
			Color = Style.color.black,
			Material = Style.flat,
			CanCollide = false,
		}, monster)
	end

	-- chifres/espinhos por tier: o monstro do cosmos parece mais perigoso
	for i = 1, math.min(spec.tier + 1, 6) do
		local angle = (i / (math.min(spec.tier + 1, 6))) * math.pi * 2
		part({
			Name = "Horn",
			Size = Vector3.new(1.6, 4.5, 1.6),
			Position = base + Vector3.new(math.cos(angle) * 5, 5.4, math.sin(angle) * 5),
			Color = Style.darken(color, 0.3),
			Material = Style.flat,
			CanCollide = false,
		}, monster)
	end

	-- ClickDetector: clicar no monstro bate nele
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 40
	detector.Parent = target

	return {
		arena = arena,
		monster = monster,
		target = target,
		detector = detector,
		biome = biome.id,
		monsterId = monsterId,
		spec = spec,
	}
end

---------------------------------------------------------------------------
-- MINA DOS PETS
---------------------------------------------------------------------------

-- A mina é o lugar onde o pet TRABALHA (ver server/MineServer.luau).
-- Visual: um poço de pedra com trilho de madeira saindo dele. O trilho é o
-- que faz ler "daqui sai minério" sem nenhum texto — a criança vê o carrinho
-- parado no fim da linha e entende que o pet vai e volta por ali.
function World.buildMine()
	local origin = Vector3.new(-96, 0, -62)

	-- laje de pedra
	part({
		Size = Vector3.new(34, 1, 30),
		Position = origin + Vector3.new(0, 1.6, 0),
		Color = Style.color.rockDark,
		Material = Style.rock,
	}, root)

	-- boca do poço: aro de pedra
	local shaft = ball({
		Name = "MineShaft",
		Size = Vector3.new(18, 4, 18),
		Position = origin + Vector3.new(0, 2.4, 2),
		Color = Style.color.rockDeep,
		Material = Style.rock,
	})
	shaft.Shape = Enum.PartType.Cylinder
	shaft.CFrame = CFrame.new(shaft.Position) * CFrame.Angles(0, 0, math.pi / 2)

	-- aro de pedras em volta da boca
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		ball({
			Name = "ShaftRock",
			Size = Vector3.new(3.4, 3, 3.4),
			Position = origin + Vector3.new(math.cos(angle) * 10, 3, 2 + math.sin(angle) * 10),
			Color = i % 2 == 0 and Style.color.rock or Style.color.rockDark,
			Material = Style.rock,
		})
	end

	-- dois postes de madeira da mina (a "torre" do poço)
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "MinePost",
			Size = Vector3.new(2.4, 22, 2.4),
			Position = origin + Vector3.new(side * 9, 12, -6),
			Color = Style.color.wood,
			Material = Style.flat,
		}, root)
	end
	part({
		Name = "MineBeam",
		Size = Vector3.new(22, 2.4, 2.4),
		Position = origin + Vector3.new(0, 23, -6),
		Color = Style.color.woodDark,
		Material = Style.flat,
	}, root)

	-- trilho saindo do poço até a plataforma
	for i = 0, 5 do
		local z = 10 + i * 5
		part({
			Name = "TrackSleeper",
			Size = Vector3.new(11, 1, 2),
			Position = origin + Vector3.new(0, 2.2, z),
			Color = Style.color.woodDark,
			Material = Style.flat,
		}, root)
		for _, side in ipairs({ -1, 1 }) do
			part({
				Name = "TrackRail",
				Size = Vector3.new(1, 1, 5.4),
				Position = origin + Vector3.new(side * 3.4, 3.1, z),
				Color = Style.color.rock,
				Material = Style.flat,
			}, root)
		end
	end

	-- carrinho de minério no fim do trilho
	local cart = Vector3.new(origin.X, origin.Y + 4.6, origin.Z + 36)
	part({
		Name = "MineCart",
		Size = Vector3.new(9, 5, 7),
		Position = cart,
		Color = Style.color.rock,
		Material = Style.rock,
	}, root)
	-- minério brilhando dentro do carrinho
	ball({
		Name = "CartOre",
		Size = Vector3.new(4.6, 3.4, 4.2),
		Position = cart + Vector3.new(0, 2.6, 0),
		Color = Style.color.cyan,
		Material = Style.glow,
	}, root)
	for _, side in ipairs({ -1, 1 }) do
		for _, back in ipairs({ -1, 1 }) do
			local wheel = ball({
				Name = "CartWheel",
				Size = Vector3.new(3.2, 3.2, 1.2),
				Position = cart + Vector3.new(side * 3.6, -3, back * 2.4),
				Color = Style.color.black,
				Material = Style.flat,
			})
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CFrame = CFrame.new(wheel.Position) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- zona clicável em cima da laje: abre o painel da mina
	local hitbox = makeZone("mine", origin + Vector3.new(0, 8, 6), Vector3.new(30, 16, 26), Style.color.cyan)
	return hitbox
end

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
		Material = Style.flat,
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
		Material = Style.flat,
	}, root)

	for i = -2, 2 do
		part({
			Size = Vector3.new(3, 14, 3),
			Position = origin + Vector3.new(i * 6, 8, -9),
			Color = PALETTE.woodDark,
			Material = Style.flat,
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
			Material = Style.flat,
		}, root)
	end

	-- portal
	local frame = part({
		Size = Vector3.new(26, 30, 3),
		Position = origin + Vector3.new(0, 18, -4),
		Color = PALETTE.woodDark,
		Material = Style.flat,
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
	light.Brightness = 2.2
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
		Material = Style.flat,
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
		Material = Style.flat,
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
				Material = Style.flat,
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
				Material = Style.flat,
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
			light.Brightness = 1.1
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
				Material = Style.flat,
				CanCollide = false,
			}, model)
		end
		part({
			Name = "BalloonString",
			Size = Vector3.new(0.3, 34, 0.3),
			Position = Vector3.new(cx, 24, cz),
			Color = Color3.fromRGB(240, 240, 240),
			Material = Style.flat,
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
		Material = Style.flat,
	}, parent)

	if id == "meadow" then
		-- ARVORE MAE: tronco largo com copa de tres bolas gigantes
		part({
			Name = "MotherTrunk",
			Size = Vector3.new(14, 44, 14),
			Position = base + Vector3.new(0, 30, 0),
			Color = PALETTE.wood,
			Material = Style.flat,
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
				Material = Style.flat,
			}, parent)
		end
		-- balanço pendurado: criança adora
		part({
			Name = "SwingSeat",
			Size = Vector3.new(9, 1.2, 4),
			Position = base + Vector3.new(30, 26, 0),
			Color = PALETTE.woodDark,
			Material = Style.flat,
		}, parent)
		for side = -1, 1, 2 do
			part({
				Name = "SwingRope",
				Size = Vector3.new(0.6, 26, 0.6),
				Position = base + Vector3.new(30 + side * 3.6, 39, 0),
				Color = PALETTE.sand,
				Material = Style.flat,
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
		light.Brightness = 1.3
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
				Material = Style.flat,
			}, parent)
		end
		part({
			Name = "PyramidDoor",
			Size = Vector3.new(14, 18, 2),
			Position = base + Vector3.new(0, 15, 24),
			Color = Color3.fromRGB(120, 84, 50),
			Material = Style.flat,
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
			Material = Style.flat,
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
				Material = Style.flat,
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
			Material = Style.flat,
		}, parent)
		cone(parent, base + Vector3.new(0, 84, 0), 18, 22, Color3.fromRGB(70, 60, 100), Style.flat)
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
			Material = Style.flat,
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
		light.Brightness = 1.8
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
			Material = Style.flat,
		}, parent)
		blob("IconCrown", Vector3.new(0, 13, 0), Vector3.new(13, 11, 13), Color3.fromRGB(96, 200, 84), Style.flat)
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
				Material = Style.flat,
			}, parent)
		end
		blob("IconSun", Vector3.new(0, 17, 0), Vector3.new(8, 8, 1.6), Color3.fromRGB(255, 214, 70), Enum.Material.Neon)
	elseif id == "ice" then
		local spike = part({
			Name = "IconIce",
			Size = Vector3.new(6, 20, 6),
			Position = top + Vector3.new(0, 11, 0),
			Color = Color3.fromRGB(186, 236, 255),
			Material = Style.flat,
			Transparency = 0.25,
		}, parent)
		spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(0.12, 0.5, 0.1)
		blob("IconShard", Vector3.new(-7, 6, 2), Vector3.new(4, 12, 4), Color3.fromRGB(214, 244, 255), Style.flat, 0.3)
		blob(
			"IconShard",
			Vector3.new(6, 5, -3),
			Vector3.new(3.4, 10, 3.4),
			Color3.fromRGB(214, 244, 255),
			Style.flat,
			0.3
		)
	elseif id == "shadow" then
		part({
			Name = "IconObelisk",
			Size = Vector3.new(5.4, 21, 5.4),
			Position = top + Vector3.new(0, 11, 0),
			Color = Color3.fromRGB(52, 44, 78),
			Material = Style.flat,
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
		Material = Style.flat,
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
			Material = Style.flat,
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
		Material = Style.flat,
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
	light.Brightness = 1.2
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
		Material = Style.flat,
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

	-- A ARENA É SAGRADA: nada temático nasce dentro dela.
	--
	-- O desvio do decorateBiome não cobre este bloco: themedDecor sorteia em
	-- outro anel (0.42–0.78 do raio) e estava plantando cerejeira e banco
	-- dentro da arena — a gosma ficava atrás de um tronco. Aqui o filtro é
	-- aplicado no próprio groundAt, então TODO tema herda a regra.
	local arenaOffX = World.arenaCenterOffset(biome).X
	local arenaOffZ = World.arenaCenterOffset(biome).Z
	local clearRadius = World.ArenaRadiusFraction * biome.radius * 1.18

	local function inArena(lx, lz)
		local dx, dz = lx - arenaOffX, lz - arenaOffZ
		return dx * dx + dz * dz < clearRadius * clearRadius
	end

	-- EMPURRA para fora da arena, em vez de descartar.
	--
	-- Descartar quebrava o teste do mundo: forest exige 5 toras caídas
	-- (FallenLog) e algumas caíam dentro da arena, então o bioma ficava com
	-- menos peças do que a especificação pede. Empurrar preserva a
	-- quantidade e ainda tira o obstáculo da frente do monstro.
	local function safeSpot(angle, radius)
		local lx, lz = math.cos(angle) * radius, math.sin(angle) * radius
		local dx, dz = lx - arenaOffX, lz - arenaOffZ
		local d = math.sqrt(dx * dx + dz * dz)
		if d < clearRadius and d > 0.001 then
			local push = (clearRadius - d) + 1
			lx = lx + (dx / d) * push
			lz = lz + (dz / d) * push
		end
		return center + Vector3.new(lx, Terrain.heightAtCell(biome, cells, lx, lz), lz)
	end

	local function meadow()
		-- cerejeiras cor-de-rosa e bancos de madeira
		for i = 1, 7 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.42 + rng:NextNumber() * 0.36)
			local pos = safeSpot(angle, radius)
			local scale = 0.8 + rng:NextNumber() * 0.4
			part({
				Name = "CherryTrunk",
				Size = Vector3.new(3 * scale, 14 * scale, 3 * scale),
				Position = pos + Vector3.new(0, 7 * scale, 0),
				Color = Color3.fromRGB(120, 84, 62),
				Material = Style.flat,
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
			local pos = safeSpot(angle, biome.radius * 0.4)
			part({
				Name = "Bench",
				Size = Vector3.new(10, 1.2, 4),
				Position = pos + Vector3.new(0, 2, 0),
				Color = PALETTE.wood,
				Material = Style.flat,
			}, home)
			for side = -1, 1, 2 do
				part({
					Name = "BenchLeg",
					Size = Vector3.new(1.4, 2.4, 3.4),
					Position = pos + Vector3.new(side * 3.6, 0.8, 0),
					Color = PALETTE.woodDark,
					Material = Style.flat,
				}, home)
			end
		end
	end

	local function forest()
		-- cogumelos luminosos e troncos caídos
		for i = 1, 12 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.3 + rng:NextNumber() * 0.5)
			local pos = safeSpot(angle, radius)
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
			local pos = safeSpot(angle, radius)
			local log = part({
				Name = "FallenLog",
				Size = Vector3.new(4, 4, 18),
				Position = pos + Vector3.new(0, 2, 0),
				Color = Color3.fromRGB(96, 72, 52),
				Material = Style.flat,
			}, home)
			log.CFrame = CFrame.new(log.Position) * CFrame.Angles(0, rng:NextNumber() * 3.14, 0)
		end
	end

	local function desert()
		-- cactos com braços, e ossadas de pedra
		for i = 1, 11 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.3 + rng:NextNumber() * 0.5)
			local pos = safeSpot(angle, radius)
			local scale = 0.7 + rng:NextNumber() * 0.8
			part({
				Name = "Cactus",
				Size = Vector3.new(4 * scale, 14 * scale, 4 * scale),
				Position = pos + Vector3.new(0, 7 * scale, 0),
				Color = Color3.fromRGB(96, 168, 96),
				Material = Style.flat,
			}, home)
			for side = -1, 1, 2 do
				part({
					Name = "CactusArm",
					Size = Vector3.new(6 * scale, 1.6 * scale, 2.4 * scale),
					Position = pos + Vector3.new(side * 2.6 * scale, 8 * scale, 0),
					Color = Color3.fromRGB(96, 168, 96),
					Material = Style.flat,
				}, home)
			end
		end
		for i = 1, 3 do
			local angle = (i / 3) * math.pi * 2
			local pos = safeSpot(angle, biome.radius * 0.55)
			local rib = part({
				Name = "BoneRib",
				Size = Vector3.new(14, 1.2, 1.2),
				Position = pos + Vector3.new(0, 3, 0),
				Color = Color3.fromRGB(246, 238, 214),
				Material = Style.flat,
			}, home)
			rib.CFrame = CFrame.new(rib.Position) * CFrame.Angles(0.3, angle, 0.25)
		end
	end

	local function ice()
		-- boneco de neve e pinheiros pequenos de gelo
		for i = 1, 3 do
			local angle = (i / 3) * math.pi * 2 + 0.5
			local pos = safeSpot(angle, biome.radius * 0.42)
			ball({
				Name = "SnowBase",
				Size = Vector3.new(11, 9, 11),
				Position = pos + Vector3.new(0, 4.5, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Style.flat,
			}, home)
			ball({
				Name = "SnowBelly",
				Size = Vector3.new(8, 7, 8),
				Position = pos + Vector3.new(0, 11.5, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Style.flat,
			}, home)
			ball({
				Name = "SnowHead",
				Size = Vector3.new(5.6, 5.4, 5.6),
				Position = pos + Vector3.new(0, 17, 0),
				Color = Color3.fromRGB(252, 254, 255),
				Material = Style.flat,
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
				Material = Style.flat,
			}, home)
			part({
				Name = "SnowScarf",
				Size = Vector3.new(6.8, 1.4, 6.8),
				Position = pos + Vector3.new(0, 14.6, 0),
				Color = Color3.fromRGB(240, 90, 96),
				Material = Style.flat,
			}, home)
		end
		for i = 1, 8 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.32 + rng:NextNumber() * 0.5)
			local pos = safeSpot(angle, radius)
			local scale = 0.6 + rng:NextNumber() * 0.7
			part({
				Name = "IceTreeTrunk",
				Size = Vector3.new(2.4 * scale, 8 * scale, 2.4 * scale),
				Position = pos + Vector3.new(0, 4 * scale, 0),
				Color = Color3.fromRGB(140, 128, 150),
				Material = Style.flat,
			}, home)
			for tier = 1, 3 do
				local w = (7.5 - tier * 1.6) * scale
				part({
					Name = "IceTreeLeaf",
					Size = Vector3.new(w, 4 * scale, w),
					Position = pos + Vector3.new(0, (6.6 + tier * 2.8) * scale, 0),
					Color = Color3.fromRGB(232, 248, 255),
					Material = Style.flat,
				}, home)
			end
		end
	end

	local function shadow()
		-- lápides tortas e lanternas de alma
		for i = 1, 10 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.28 + rng:NextNumber() * 0.55)
			local pos = safeSpot(angle, radius)
			local stone = part({
				Name = "Grave",
				Size = Vector3.new(5, 9, 1.6),
				Position = pos + Vector3.new(0, 4, 0),
				Color = Color3.fromRGB(88, 84, 110),
				Material = Style.flat,
			}, home)
			stone.CFrame = CFrame.new(stone.Position)
				* CFrame.Angles(0, rng:NextNumber() * 3.14, math.rad(rng:NextNumber() * 14 - 7))
			ball({
				Name = "GraveTop",
				Size = Vector3.new(5, 5, 1.6),
				Position = pos + Vector3.new(0, 8.4, 0),
				Color = Color3.fromRGB(88, 84, 110),
				Material = Style.flat,
			}, home)
		end
		for i = 1, 6 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.34 + rng:NextNumber() * 0.4)
			local pos = safeSpot(angle, radius)
			part({
				Name = "LanternPost",
				Size = Vector3.new(1.2, 9, 1.2),
				Position = pos + Vector3.new(0, 4.5, 0),
				Color = Color3.fromRGB(48, 42, 62),
				Material = Style.flat,
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
			glow.Brightness = 1.0
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
			local pos = safeSpot(angle, radius)
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
				Material = Style.flat,
			}, home)
		end
		for i = 1, 5 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.4 + rng:NextNumber() * 0.35)
			local pos = safeSpot(angle, radius)
			local candle = ball({
				Name = "GhostCandle",
				Size = Vector3.new(3.2, 5, 3.2),
				Position = pos + Vector3.new(0, 6, 0),
				Color = accentColor,
				Material = Enum.Material.Neon,
				Transparency = 0.3,
			}, home)
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.2
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
			local pos = safeSpot(angle, radius)
			local scale = 0.6 + rng:NextNumber() * 1.1
			local rock = ball({
				Name = "Asteroid",
				Size = Vector3.new(6 * scale, 5 * scale, 6.4 * scale),
				Position = pos + Vector3.new(0, 2 * scale, 0),
				Color = Color3.fromRGB(92, 84, 130),
				Material = Style.flat,
			}, home)
			rock.CFrame = CFrame.new(rock.Position)
				* CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
		end
		for i = 1, 7 do
			local angle = rng:NextNumber() * math.pi * 2
			local radius = biome.radius * (0.35 + rng:NextNumber() * 0.45)
			local pos = safeSpot(angle, radius)
			local star = ball({
				Name = "FallenStar",
				Size = Vector3.new(3.6, 3.6, 3.6),
				Position = pos + Vector3.new(0, 4, 0),
				Color = Color3.fromRGB(255, 236, 160),
				Material = Enum.Material.Neon,
			}, home)
			local glow = Instance.new("PointLight")
			glow.Brightness = 0.9
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
	-- A cerca fica em 0.92 do raio. Aqui a conta desconta o RAIO DA COPA, não
	-- só um número mágico: o perfil "gordo" tem spread 1.25 e a copa chega a
	-- ~10 studs, então uma árvore centrada em 0.82 encostava na cerca.
	-- 0.74 deixa folga para a copa mais larga e mais a escala 1.5.
	local placeable = biome.radius * 0.74
	local innerRing = biome.radius * 0.30

	-- ZONA DA ARENA: nada de decoração aqui dentro.
	--
	-- A arena fica centrada em +0.40 do raio no eixo X com 0.46 de raio, então
	-- ocupa de -0.06 a 0.86 do raio. O anel de decoração sorteia de 0.30 a
	-- 0.74 — quase todo dentro da arena. Sem esta exclusão nasciam árvores
	-- em cima do monstro, e o jogador tinha que bater na gosma escondida
	-- atrás de um tronco. (Achado no render: a arena existia no build, mas
	-- ficava coberta pelo mato.)
	local arenaRadius = World.ArenaRadiusFraction * biome.radius
	-- 1.18: a copa mais larga chega a ~10 studs, então a folga tem de ser
	-- generosa. Abaixo disso a árvore nasce fora do disco mas a copa cobre
	-- o monstro do mesmo jeito.
	local clearRadius = arenaRadius * 1.18
	local arenaCenter = World.arenaCenterOffset(biome)
	local arenaOffX, arenaOffZ = arenaCenter.X, arenaCenter.Z

	-- Sorteia uma posição e EMPURRA para fora da arena.
	--
	-- Empurrar em vez de descartar (e em vez de tentar de novo) porque
	-- descartar mudava a QUANTIDADE de peças e quebrava o teste do mundo,
	-- que exige um número mínimo de árvores e enfeites por bioma.
	local function scatter(rng)
		local angle = rng:NextNumber() * math.pi * 2
		local radius = innerRing + (placeable - innerRing) * rng:NextNumber()
		local lx, lz, y = groundAt(angle, radius)
		local dx, dz = lx - arenaOffX, lz - arenaOffZ
		local d = math.sqrt(dx * dx + dz * dz)
		if d < clearRadius and d > 0.001 then
			local push = (clearRadius - d) + 1
			lx, lz = lx + (dx / d) * push, lz + (dz / d) * push
			y = Terrain.heightAtCell(biome, cells, lx, lz)
		end
		return lx, lz, y, angle, radius
	end

	-- árvores (ou pinheiros / abóboras, conforme o tema)
	for i = 1, spec.trees do
		local x, z, y, angle, radius = scatter(rng)
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
				Material = Style.flat,
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
				Material = Style.flat,
			}, home)
			for tier = 1, 3 do
				local w = (8.5 - tier * 1.7) * scale
				part({
					Name = "Leaf",
					Size = Vector3.new(w, 5.2 * scale, w),
					Position = pos + Vector3.new(0, (7 + tier * 3.4) * scale, 0),
					Color = leafColor,
					Material = Style.flat,
				}, home)
			end
		else
			-- sorteia o perfil: 4 silhuetas diferentes na mesma ilha
			local shape = 1 + math.floor(rng:NextNumber() * #TREE_SHAPES)
			tree(center + Vector3.new(x, y, z), scale, home, biome.colors, shape)
		end
	end

	-- pedras
	for i = 1, spec.rocks do
		local x, z, y, angle, radius = scatter(rng)
		local scale = 0.8 + rng:NextNumber() * 1.4
		ball({
			Name = "Rock",
			Size = Vector3.new(5 * scale, 4 * scale, 5.5 * scale),
			Position = center + Vector3.new(x, y + 1.2 * scale, z),
			Color = Color3.fromRGB(biome.colors.rock[1], biome.colors.rock[2], biome.colors.rock[3]),
			Material = Style.flat,
		}, home)
	end

	-- flores (só bioma de grama)
	for i = 1, spec.flowers do
		local x, z, y, angle, radius = scatter(rng)
		flower(center + Vector3.new(x, y, z), home)
	end

	themedDecor(biome, cells, home, center, rng)

	-- cristais brilhantes (gelo, sombrio, cosmos, deserto)
	for i = 1, spec.crystals do
		local x, z, y, angle, radius = scatter(rng)
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

---------------------------------------------------------------------------
-- CERCA (barreira visual em volta da ilha)
---------------------------------------------------------------------------

-- Cerca cartoon: estacas de madeira gordas com ponta arredondada (uma bola
-- no topo, que é o "cap" do desenho) e duas travessas horizontais.
--
-- Por que cerca e não muro: muro de pedra some no casco da ilha e parece
-- terreno. Estaca com cap lê na hora como "aqui acaba o mapa", que é a
-- função de uma barreira. E é o elemento que separa "plataforma solta no
-- mar" de "ilha de verdade" — todo pack low-poly de ilha tem uma.
--
-- `radius` é onde a cerca fica (um pouco dentro da borda), `segments` é
-- quantas estacas. A cerca acompanha a curva, então usa CFrame para girar
-- cada estaca apontando para o centro.
-- `gateAngle` abre um vão na cerca (o portão). Sem ele a cerca fecha a ilha
-- e o jogador não sai — e uma estaca pode nascer em cima do spawn.
buildFence = function(center, radius, segments, color, accent, parent, yOffset, gateAngle)
	local height = 12
	local postW = 2.6
	local y = yOffset or 0

	-- travessas: dois anéis finos, um no meio e um em cima
	for ring = 0, 1 do
		local railY = y + (ring == 0 and height * 0.42 or height * 0.80)
		for i = 1, segments do
			local a1 = ((i - 1) / segments) * math.pi * 2
			local a2 = (i / segments) * math.pi * 2
			local mid = (a1 + a2) / 2
			local chord = 2 * radius * math.sin((a2 - a1) / 2) * 1.06
			local rail = part({
				Name = "FenceRail",
				Size = Vector3.new(0.9, 0.9, chord),
				Position = center + Vector3.new(math.cos(mid) * radius, railY, math.sin(mid) * radius),
				Color = accent,
				Material = Style.flat,
				CanCollide = true,
			}, parent)
			rail.CFrame = CFrame.new(rail.Position) * CFrame.Angles(0, -mid, 0)
		end
	end

	-- estacas com cap arredondado no topo
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		-- vao do portao: pula as estacas que caem dentro do arco
		local skip = false
		if gateAngle then
			local diff = math.abs(((angle - gateAngle + math.pi) % (math.pi * 2)) - math.pi)
			if diff < 0.30 then
				skip = true
			end
		end
		if not skip then
			local post = part({
				Name = "FencePost",
				Size = Vector3.new(postW, height, postW),
				Position = center + Vector3.new(math.cos(angle) * radius, y + height / 2, math.sin(angle) * radius),
				Color = color,
				Material = Style.flat,
				CanCollide = true,
			}, parent)
			post.CFrame = CFrame.new(post.Position) * CFrame.Angles(0, -angle, 0)

			-- cap: bolinha no topo, o "traço" do desenho
			ball({
				Name = "FenceCap",
				Size = Vector3.new(postW * 1.5, postW * 1.5, postW * 1.5),
				Position = center + Vector3.new(math.cos(angle) * radius, y + height, math.sin(angle) * radius),
				Color = Style.lighten(color, 0.12),
				Material = Style.flat,
				CanCollide = false,
			}, parent)
		end
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
			Material = Style.flat,
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
				Material = Style.flat,
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
			Material = Style.flat,
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
	-- `groundY` NÃO é a base do terreno: Terrain.heightAtCell já devolve o
	-- TOPO (y + thickness/2). Este disco é a laje maciça que fecha os vãos
	-- entre as células, então ele fica um pouco ABAIXO do topo — senão tapa
	-- a grama e vira um disco liso.
	--
	-- O disco tem CellThickness*2.2 de espessura, e a posição é o CENTRO:
	-- centro = topo - meia espessura - 0.05 de folga põe a face de cima
	-- logo abaixo do terreno, sem furar e sem sumir.
	local floorTop = groundY - Terrain.CellThickness * 1.1 - 0.05
	local groundDisc = part({
		Name = "GroundDisc",
		Size = Vector3.new(Terrain.CellThickness * 2.2, biome.radius * 1.94, biome.radius * 1.94),
		Position = center + Vector3.new(0, floorTop, 0),
		Color = Color3.fromRGB(
			math.max(0, colors.grassDark[1] - 18),
			math.max(0, colors.grassDark[2] - 18),
			math.max(0, colors.grassDark[3] - 18)
		),
		Material = Style.flat,
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
			Material = cell.kind == "sand" and Enum.Material.Sand or Style.flat,
			CanCollide = true,
		}, cellModel)
		cellPart.TopSurface = Enum.SurfaceType.Smooth
	end

	decorateBiome(biome, cells, home, center)

	-- ARENA: o chão da briga + o monstro. Ver World.buildArena.
	local arena = World.buildArena(biome, center, groundY, home, cells)
	if arena then
		monsterBindings[biome.id] = arena
	end

	-- BARREIRA
	-- A cerca vai na borda da grama (0.92 do raio: dentro do terreno, fora
	-- do caminho do ovo e da decoração, que ocupam até 0.86).
	-- A cor vem do bioma; as travessas são um tom mais claro para dar
	-- contraste sem virar duas cores brigando.
	local fenceRadius = biome.radius * 0.92
	-- portão virado para o hub (caminho de chegada); portal de volta fica dentro
	local toHub = Vector3.new(-center.X, 0, -center.Z)
	local gateAngle = toHub.Magnitude > 1 and math.atan2(toHub.Z, toHub.X) or 0
	-- yOffset é RELATIVO ao centro: buildFence soma center.Y sozinho.
	buildFence(center, fenceRadius, 26, Style.color.wood, Style.color.woodDark, home, groundY + 1.6, gateAngle)

	-- LUZ DO BIOMA
	-- Cada ilha tem a própria luz: sem isso, sombra e ambiente iguais em todo
	-- lugar e a floresta fica com a cara do deserto. São três coisas:
	--   1. uma luz central grande que "aquece" a ilha inteira
	--   2. postes de luz espalhados (visíveis e coloridos, criança adora)
	--   3. um PointLight na placa do bioma, para ler o nome no escuro
	local spec = biome.light
	local ambientColor = Color3.fromRGB(spec.ambience[1], spec.ambience[2], spec.ambience[3])
	local glowColor = Color3.fromRGB(spec.glow[1], spec.glow[2], spec.glow[3])

	-- A LUZ QUE LAVAVA A ILHA.
	--
	-- Antes isto era uma PointLight com Range 220-270 e Brightness 1.2-1.9,
	-- pendurada 46 studs acima do chão. Range de 250 cobre a ilha inteira a
	-- partir de um ponto só: a face virada para ela recebe a luz de frente e
	-- satura em branco. Era EXATAMENTE o "tudo branco" que aparece na tela
	-- do jogador — e no meu render não aparecia porque o preview limitava o
	-- ganho em 1.0, então ele mentia dizendo que estava tudo bem.
	--
	-- Duas correções:
	--   1. Range curto e altura menor: a luz ilumina o chão ao redor em vez
	--      de atravessar a ilha.
	--   2. Brilho baixo. O papel desta luz é dar TOM (a floresta mais verde,
	--      o deserto mais quente), não clarear. Tom se dá com cor e pouca
	--      intensidade; intensidade alta vira branco e apaga o matiz.
	local sun = Instance.new("PointLight")
	sun.Name = "BiomeLight"
	sun.Brightness = math.min(spec.intensity, 0.55)
	-- 0.42 do raio: chega na metade da ilha, não na borda de fora. Ilha de
	-- raio 105 fica com alcance ~44 — luz de ambiente, não holofote.
	sun.Range = math.max(34, biome.radius * 0.42)
	sun.Color = ambientColor
	sun.Shadows = false
	sun.Parent = part({
		Name = "LightAnchor",
		Size = Vector3.new(2, 2, 2),
		Position = center + Vector3.new(0, groundY + 22, 0),
		Color = glowColor,
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
	}, home)

	-- postes: um anel de luzes na borda da ilha, virados para o centro
	--
	-- O anel é a 0.62 do raio, e a arena ocupa de 0.06 a 0.86 — um poste
	-- caía dentro da arena e ficava na frente do monstro. Aqui o poste é
	-- EMPURRADO para fora do círculo da arena, na direção oposta ao centro
	-- dela. Empurrar (em vez de pular) preserva o anel completo de luz.
	local arenaCenter = World.arenaCenterOffset(biome)
	local arenaClear = World.ArenaRadiusFraction * biome.radius * 1.15
	local postCount = biome.id == "cosmos" and 6 or 8
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		local radius = biome.radius * 0.62
		local lx, lz = math.cos(angle) * radius, math.sin(angle) * radius
		local dx, dz = lx - arenaCenter.X, lz - arenaCenter.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist < arenaClear and dist > 0.001 then
			local push = (arenaClear - dist) + 2
			lx = lx + (dx / dist) * push
			lz = lz + (dz / dist) * push
		end
		local gy = Terrain.heightAtCell(biome, cells, lx, lz)
		local base = Vector3.new(center.X + lx, center.Y + gy, center.Z + lz)

		part({
			Name = "Post",
			Size = Vector3.new(1.6, 14, 1.6),
			Position = base + Vector3.new(0, 7, 0),
			Color = PALETTE.stoneDark,
			Material = Style.flat,
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
		bulbLight.Brightness = 0.9
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
			Material = Style.flat,
		}, skyFolder)
		rock.CanCollide = false
		rock.CanQuery = false
		-- uma pedra menor de apoio, para a silhueta não ser uma bola só
		ball({
			Name = "SkyRock",
			Size = Vector3.new(size * 0.9, size * 0.6, size * 0.8),
			Position = Vector3.new(x + size * 0.6, height - size * 0.4, z - size * 0.3),
			Color = PALETTE.rock,
			Material = Style.flat,
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
