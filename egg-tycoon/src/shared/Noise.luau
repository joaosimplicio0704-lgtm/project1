-- Noise
-- Ruído determinístico puro (sem Random.new) para gerar terreno.
-- Hash inteiro -> [0,1), interpolação suave e fractal. Tudo função pura:
-- mesma seed + mesmas coordenadas = mesmo mundo em qualquer máquina.

local Noise = {}

local function fract(x)
	return x - math.floor(x)
end

-- Hash 2D barato e estável. Evita `~` (Luau não tem xor) e usa só mul/mod.
local function hash2(ix, iy, seed)
	local h = ix * 374761393 + iy * 668265263 + seed * 1442695040888963407
	h = fract(h / 4294967296) * 4294967296
	h = fract(h * 1103515245 / 65536) * 65536
	return fract(h / 65536)
end

local function smooth(t)
	return t * t * (3 - 2 * t)
end

function Noise.value(x, y, seed)
	seed = seed or 0
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	local fx = smooth(x - x0)
	local fy = smooth(y - y0)

	local a = hash2(x0, y0, seed)
	local b = hash2(x0 + 1, y0, seed)
	local c = hash2(x0, y0 + 1, seed)
	local d = hash2(x0 + 1, y0 + 1, seed)

	local top = a + (b - a) * fx
	local bottom = c + (d - c) * fx
	return top + (bottom - top) * fy
end

-- Soma de oitavas: relevo grande + detalhe fino. Retorna ~[0,1].
function Noise.fbm(x, y, seed, octaves)
	octaves = octaves or 4
	local total, amplitude, frequency, maxValue = 0, 1, 1, 0
	for i = 1, octaves do
		total += Noise.value(x * frequency, y * frequency, (seed or 0) + i * 37) * amplitude
		maxValue += amplitude
		amplitude *= 0.5
		frequency *= 2
	end
	return total / maxValue
end

-- Cume: valor alto vira pico afiado. Bom para montanha nevada.
function Noise.ridged(x, y, seed, octaves)
	local n = Noise.fbm(x, y, seed, octaves)
	return 1 - math.abs(n * 2 - 1)
end

-- Escolhe um item de uma lista ponderada {peso, item} de forma determinística.
function Noise.pick(weighted, t)
	local total = 0
	for _, entry in ipairs(weighted) do
		total += entry[1]
	end
	local target = (t or 0) * total
	local cursor = 0
	for _, entry in ipairs(weighted) do
		cursor += entry[1]
		if target <= cursor then
			return entry[2]
		end
	end
	return weighted[#weighted][2]
end

return Noise
