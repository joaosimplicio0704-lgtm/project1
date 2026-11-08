-- Style
-- A linguagem visual do jogo, num lugar só.
--
-- Referência: packs low-poly/cartoon de Roblox (o padrão do gênero) usam
-- COR CHAPADA + superfície lisa, sem material texturizado. Grass/Slate/Rock
-- do Roblox têm ruído fotográfico: de perto parece foto colada no bloco, e
-- de longe o ruído some e vira lama cinza. Trocar por SmoothPlastic com
-- cores saturadas é o que faz a peça ler como "desenho animado".
--
-- Regra: material texturizado só onde o texto É o assunto (areia da praia,
-- água do mar). O resto é cor chapada.

local Style = {}

---------------------------------------------------------------------------
-- MATERIAIS
---------------------------------------------------------------------------

-- Superfície padrão de tudo: cor chapada, sem ruído.
Style.flat = Enum.Material.SmoothPlastic
-- Pedra em bloco: ainda lisa, só que a cor já vem escura/dura.
Style.rock = Enum.Material.SmoothPlastic
-- Brilho (luz, ovo raro, portal): emissivo.
Style.glow = Enum.Material.Neon
-- Água e areia mantêm textura de propósito: são o único lugar onde o
-- material ajuda a ler o que é.
Style.water = Enum.Material.Water
Style.sand = Enum.Material.Sand

---------------------------------------------------------------------------
-- PALETA
-- Saturação alta e valor médio-alto: é assim que o cartoon funciona. Cor
-- pastel demais lava, cor escura demais parece sujeira.
---------------------------------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Style.color = {
	grass = rgb(124, 214, 96),
	grassLight = rgb(150, 232, 118),
	grassDark = rgb(92, 176, 74),
	dirt = rgb(196, 138, 92),
	dirtDark = rgb(158, 104, 66),
	sand = rgb(250, 228, 168),
	sandDark = rgb(232, 202, 140),
	rock = rgb(176, 190, 208),
	rockDark = rgb(134, 148, 170),
	rockDeep = rgb(96, 110, 134),
	wood = rgb(178, 122, 74),
	woodDark = rgb(136, 90, 54),
	white = rgb(252, 252, 255),
	black = rgb(48, 44, 60),
	gold = rgb(255, 200, 60),
	goldDark = rgb(228, 160, 30),
	pink = rgb(255, 158, 202),
	purple = rgb(172, 126, 240),
	blue = rgb(96, 168, 250),
	cyan = rgb(120, 232, 244),
	red = rgb(248, 104, 104),
	orange = rgb(255, 156, 74),
}

-- Escurece uma cor mantendo o matiz. Usado para a "cara de baixo" das peças
-- (a sombra chapada do cartoon) sem virar cinza.
function Style.darken(color, amount)
	amount = amount or 0.18
	return Color3.new(
		math.max(0, color.R * (1 - amount)),
		math.max(0, color.G * (1 - amount)),
		math.max(0, color.B * (1 - amount))
	)
end

function Style.lighten(color, amount)
	amount = amount or 0.18
	return Color3.new(
		math.min(1, color.R + (1 - color.R) * amount),
		math.min(1, color.G + (1 - color.G) * amount),
		math.min(1, color.B + (1 - color.B) * amount)
	)
end

-- Contorno: o "traço preto" do desenho. Um tom bem escuro do próprio matiz
-- funciona melhor que preto puro, que fica cru no 3D.
function Style.outline(color)
	return Color3.new(color.R * 0.42, color.G * 0.40, color.B * 0.48)
end

return Style
