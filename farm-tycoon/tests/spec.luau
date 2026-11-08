-- spec
-- Testes da logica pura do jogo. Roda fora do Roblox via tests/run.mjs.
-- Globals injetados pelo runner: GameConfig, Format.

local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print(string.format("  FAIL  %s  %s", name, detail or ""))
	end
end

-- CONFIG
check("crop count", #GameConfig.Crops == 8, tostring(#GameConfig.Crops))
check(
	"crop ids unicos",
	(function()
		local seen = {}
		for _, c in ipairs(GameConfig.Crops) do
			if seen[c.id] then
				return false
			end
			seen[c.id] = true
		end
		return true
	end)()
)

local crop = GameConfig.getCrop("wheat")
check("getCrop funciona", crop ~= nil and crop.name == "Trigo")
check("getCrop invalido retorna nil", GameConfig.getCrop("nope") == nil)

check("xp sobe com o nivel", GameConfig.xpNeeded(2) < GameConfig.xpNeeded(10))
check("xp nivel maximo = inf", GameConfig.xpNeeded(GameConfig.MaxLevel) == math.huge)

-- PLOTS
check("plot cost 4->5", (GameConfig.plotCost(4)) == GameConfig.Plots.Cost[5])
check("plot max retorna nil", (GameConfig.plotCost(GameConfig.Plots.Max)) == nil)

-- UPGRADES
check("conveyor custo cresce", GameConfig.upgradeCost("conveyor", 1) > GameConfig.upgradeCost("conveyor", 0))
check("conveyor no maximo retorna nil", GameConfig.upgradeCost("conveyor", 15) == nil)
check("conveyor speed cresce", GameConfig.conveyorSpeed(3) > GameConfig.conveyorSpeed(0))

-- MUTATIONS
local weights, total = GameConfig.mutationWeights(1)
check("weights maior que zero", total > 0)
check("quatro mutations", #weights == 4)

local normal = GameConfig.pickMutation(0, 1)
check("roll 0 = normal", normal.id == "normal")

local rainbowHeavy = GameConfig.pickMutation(total - 0.001, 1)
check("roll maximo = rainbow", rainbowHeavy.id == "rainbow")

-- determinismo com rng fake
local fake = { value = 0.9999 }
function fake:NextNumber()
	return self.value
end
local rolled = GameConfig.rollMutation(1, fake)
check("rng alto puxa rainbow", rolled.id == "rainbow", rolled.id)

-- economia
local data = GameConfig.defaultData()
check("cash inicial", data.cash == 60)
check("plots iniciais", data.plots == GameConfig.Plots.Start)
check("sell mult base", GameConfig.sellMultiplier(data) == 1)

data.upgrades.sell = 4
check("sell upgrade aplica", GameConfig.sellMultiplier(data) > 1)

data.rebirths = 2
check("rebirth multiplica", math.abs(GameConfig.sellMultiplier(data) - (1 + 0.25 * 4) * 2) < 1e-9)

local normalMut = GameConfig.getMutation("normal")
local wheatValue = GameConfig.sellValue(GameConfig.defaultData(), crop, normalMut)
check("sell value = sell * amount", wheatValue == crop.sell * crop.amount, tostring(wheatValue))

local golden = GameConfig.getMutation("golden")
check(
	"mutation multiplica valor",
	GameConfig.sellValue(GameConfig.defaultData(), crop, golden) == wheatValue * golden.mult
)

check("grow time base", GameConfig.growTime(GameConfig.defaultData(), crop) == crop.grow)
local fast = GameConfig.defaultData()
fast.crystalUpgrades.growth = 10
check("grow time reduz com upgrade", GameConfig.growTime(fast, crop) < crop.grow)

-- luck
local quiet = GameConfig.defaultData()
local lucky = GameConfig.defaultData()
lucky.upgrades.luck = 10
check("luck sobe", GameConfig.luck(lucky) > GameConfig.luck(quiet))

-- colheita dupla
check("sem tier = 0%", GameConfig.doubleChance(0) == 0)
check("tier 1 da chance", GameConfig.doubleChance(1) > 0)
check("chance acumula", GameConfig.doubleChance(4) == GameConfig.AutoTiers[4].doubleChance)
check("custo final nil", GameConfig.autoCost(#GameConfig.AutoTiers) == nil)

-- FORMAT
check("format 999", Format.number(999) == "999", Format.number(999))
check("format 1500", Format.number(1500) == "1.5K", Format.number(1500))
check("format 1e6", Format.number(1000000) == "1M", Format.number(1000000))
check("format 2.5e9", Format.number(2500000000) == "2.5B", Format.number(2500000000))
check("money prefixo", Format.money(1500) == "$1.5K", Format.money(1500))
check("tempo segundos", Format.time(45) == "45s", Format.time(45))
check("tempo minutos", Format.time(125) == "2m 05s", Format.time(125))
check("tempo horas", Format.time(7300) == "2h 01m", Format.time(7300))

-- LAYOUT (plot nao pode invadir a esteira)
local L = GameConfig.Layout
local plotMaxX = L.plotOriginX + (L.plotCols - 1) * L.plotSpacingX + L.plotSize / 2
local beltMinX = L.beltX - L.beltWidth / 2
check("plot nao invade esteira", plotMaxX < beltMinX, plotMaxX .. " vs " .. beltMinX)

local rows = math.ceil(GameConfig.Plots.Max / L.plotCols)
local plotMinZ = L.plotOriginZ - L.plotSize / 2
local plotMaxZ = L.plotOriginZ + (rows - 1) * L.plotSpacingZ + L.plotSize / 2
check("plots dentro do lote (z)", plotMinZ > -L.lotSize / 2 and plotMaxZ < L.lotSize / 2, plotMinZ .. ".." .. plotMaxZ)

local beltEndZ = L.beltZStart + L.beltLength + L.sellPadDistance
check("caixa cabe no lote", beltEndZ + 7 < L.lotSize / 2, tostring(beltEndZ))

local first = GameConfig.plotLocalOffset(1)
local last = GameConfig.plotLocalOffset(GameConfig.Plots.Max)
check("offset 1 no canto", first.X == L.plotOriginX and first.Z == L.plotOriginZ)
check("offset max avanca linhas", first.X ~= last.X or first.Z ~= last.Z)

-- CODIGOS
check(
	"codigo lowercase normaliza",
	(function()
		local ok = false
		for code in pairs(GameConfig.Codes) do
			if string.upper(code) == "FARMSTART" then
				ok = true
			end
		end
		return ok
	end)()
)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("testes falharam")
end
