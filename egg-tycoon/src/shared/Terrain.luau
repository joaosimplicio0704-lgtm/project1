-- Terrain
-- Gera o relevo de cada ilha: uma grade de células cúbicas empilhadas.
-- Puro e determinístico (usa Noise), então o mesmo mapa sai em qualquer lugar.
--
-- A grade é local ao bioma, centrada em (0,0); quem chama posiciona as células
-- somando o centro do bioma. Assim o mesmo bioma pode ser desenhado em qualquer
-- bioma sem recalcular ruído.

local Noise = require(script.Parent.Noise)

local Terrain = {}

Terrain.GridSize = 17
-- Tamanho da célula é derivado do raio do bioma: a grade SEMPRE cobre a
-- ilha inteira. Antes era fixo em 14.95 e, quando as ilhas cresceram, sobrava
-- um anel de ilha sem terreno — chão nenhum, só a base de pedra.
Terrain.CellSize = 14.95
Terrain.CellThickness = 3.2
Terrain.SeaLevel = 0
Terrain.PlateauFloor = 3
Terrain.PlateauRadius = 0.34 -- fração do raio: miolo plano para o ovo

-- Altura do platô central: o miolo da ilha é plano para o ovo e o spawn.
-- Sem isso o ruído faz uma colina no centro e o pedestal afunda no chão.
function Terrain.plateauHeight(biome)
	return biome.height.base + biome.height.amp * 0.3
end

-- Nível da praia na borda da ilha (um pouco abaixo do mar).
Terrain.BeachLevel = -1

-- Altura do relevo (em studs) num ponto normalizado (-1..1 no raio da ilha).
-- Forma: platô plano no miolo, ruído só na encosta, praia caindo na borda.
function Terrain.heightAt(biome, nx, nz)
	local spec = biome.height
	local distance = math.min(1, math.sqrt(nx * nx + nz * nz))
	local plateau = Terrain.plateauHeight(biome)

	-- 1 no centro, 0 na borda. Cúbico para a encosta não cair de repente.
	local blend = 1 - distance * distance * distance

	-- o ruído some dentro do platô e cresce na encosta
	local noiseFade = 0
	if distance > Terrain.PlateauRadius then
		noiseFade = (distance - Terrain.PlateauRadius) / (1 - Terrain.PlateauRadius)
		noiseFade = math.min(1, noiseFade)
	end

	local sample
	if spec.ridged then
		sample = Noise.ridged(nx * 2.4, nz * 2.4, biome.seed or 7, spec.detail)
	else
		sample = Noise.fbm(nx * 2.4, nz * 2.4, biome.seed or 7, spec.detail)
	end

	local relief = plateau + (sample - 0.5) * spec.amp * noiseFade
	-- mistura com a praia: em distance = 1 a altura é BeachLevel
	return Terrain.BeachLevel + (relief - Terrain.BeachLevel) * blend
end

-- Deslocamento do bioma para o centro do mundo, para quem só quer ler posição.
function Terrain.offsetFor(biome)
	return Vector3.new(biome.center.x, biome.center.y, biome.center.z)
end

-- Lista de células: { x, y, z, size, material, color, kind }
-- `kind` é "top" (superfície andável) ou "fill" (enchimento interno).
function Terrain.generate(biome)
	local cells = {}
	local half = math.floor(Terrain.GridSize / 2)
	local thickness = Terrain.CellThickness
	-- cobre 96% do raio do bioma; os 4% restantes viram a praia que já existe
	local radiusCells = biome.radius * 0.96
	local cell = (radiusCells * 2) / (half * 2 + 1)

	for gx = -half, half do
		for gz = -half, half do
			local lx = gx * cell
			local lz = gz * cell
			local distance = math.sqrt(lx * lx + lz * lz) / radiusCells
			if distance <= 1 then
				local height = Terrain.heightAt(biome, lx / radiusCells, lz / radiusCells)
				local topY = math.floor(height / thickness) * thickness
				local columnBase = Terrain.SeaLevel - thickness

				-- praia quando a coluna é rasa
				local kind, color
				if topY < Terrain.BeachLevel + thickness then
					kind = "sand"
					color = biome.colors.sand
				elseif distance > 0.72 then
					kind = "grass"
					color = biome.colors.grassDark
				else
					kind = "grass"
					color = biome.colors.grass
				end

				-- superfície
				cells[#cells + 1] = {
					x = lx,
					y = topY,
					z = lz,
					sx = cell,
					sy = thickness,
					sz = cell,
					color = color,
					kind = kind,
					top = true,
				}

				-- enchimento até a base, limitado para não criar 40 partes por coluna
				local fillSteps = math.min(4, math.floor((topY - columnBase) / thickness))
				for step = 1, fillSteps do
					cells[#cells + 1] = {
						x = lx,
						y = topY - step * thickness,
						z = lz,
						sx = cell,
						sy = thickness,
						sz = cell,
						color = biome.colors.grassDark,
						kind = "fill",
						top = false,
					}
				end
			end
		end
	end

	Terrain.lastCellSize = cell
	return cells
end

-- Altura jogável (topo das células) num ponto local do bioma, para apoiar
-- objetos de decoração sem flutuar. Varre a célula mais próxima.
function Terrain.heightAtCell(biome, cells, lx, lz)
	local best, bestDistance = nil, math.huge
	for _, c in ipairs(cells) do
		if c.top then
			local dx, dz = c.x - lx, c.z - lz
			local d = dx * dx + dz * dz
			if d < bestDistance then
				bestDistance, best = d, c
			end
		end
	end
	local reach = (Terrain.lastCellSize or Terrain.CellSize) * 1.6
	if best and bestDistance < reach * reach then
		return best.y + Terrain.CellThickness / 2
	end
	return Terrain.PlateauFloor + Terrain.CellThickness / 2
end

return Terrain
