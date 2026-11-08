-- sim.luau
-- Roda Farm + a matematica de progressao do GameConfig num loop de 6 horas
-- e imprime os marcos. Nao usa Roblox: tudo aqui e puro.

print = hostprint

local data = GameConfig.defaultData()

-- replica exatamente a logica de Economy.autoplant + stepSession, sem rede.
local seed = 12345
local function nextNumber()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local rngObject = {
	NextNumber = function()
		return nextNumber()
	end,
}

local farm = Farm.new(data, rngObject)

local function luck()
	return GameConfig.luck(data)
end

local function selectedCrop()
	local crop = GameConfig.getCrop(data.selectedCrop)
	if not crop or crop.level > data.level then
		crop = GameConfig.bestCropForLevel(data.level)
		data.selectedCrop = crop.id
	end
	return crop
end

local function plantAll()
	local crop = selectedCrop()
	for i = 1, data.plots do
		if not farm.plots[i] then
			if data.cash < crop.seed then
				return
			end
			data.cash -= crop.seed
			local m = GameConfig.rollMutation(luck(), rngObject)
			farm:plant(i, crop.id, m.id)
		end
	end
end

local function buyBestAffordable()
	-- prioridade: plot > conveyor > sell > luck
	local cost, levelReq = GameConfig.plotCost(data.plots)
	if cost and data.cash >= cost and data.level >= levelReq then
		data.cash -= cost
		data.plots += 1
		return "plot"
	end
	for _, kind in ipairs({ "conveyor", "sell", "luck" }) do
		local c = GameConfig.upgradeCost(kind, data.upgrades[kind])
		if c and data.cash >= c then
			data.cash -= c
			data.upgrades[kind] += 1
			return kind
		end
	end
	return nil
end

local function grantXp(amount)
	data.xp += amount
	while data.level < GameConfig.MaxLevel do
		local need = GameConfig.xpNeeded(data.level)
		if data.xp < need then
			break
		end
		data.xp -= need
		data.level += 1
	end
	if data.level >= GameConfig.MaxLevel then
		data.xp = 0
	end
end

local function step(dt)
	local sold = farm:step(dt)
	if sold then
		for _, item in ipairs(sold) do
			local crop = GameConfig.getCrop(item.cropId)
			data.cash += item.value
			data.stats.earned += item.value
			data.stats.harvests += 1
			grantXp(crop and crop.xp or 0)
		end
	end
	plantAll()
end

print(string.format("%-8s %-6s %-12s %-8s %-8s %s", "tempo", "nivel", "cash", "plots", "sorte", "venda"))
print(string.rep("-", 64))

local t = 0
local dt = 0.1
local nextLog = 0
local milestones = {}
local lastLevel = data.level
local lastPlots = data.plots

while t < 6 * 3600 do
	step(dt)
	t += dt
	if math.floor(t) % 2 == 0 then
		buyBestAffordable()
	end

	if data.level ~= lastLevel then
		lastLevel = data.level
		milestones[#milestones + 1] = { t = t, text = "Nível " .. data.level }
	end
	if data.plots ~= lastPlots then
		lastPlots = data.plots
		milestones[#milestones + 1] = { t = t, text = "Terreno " .. data.plots }
	end

	if t >= nextLog then
		nextLog = t + 600
		print(
			string.format(
				"%-8s %-6d %-12s %-8d %-8.1f x%.1f",
				Format.time(t),
				data.level,
				Format.money(data.cash),
				data.plots,
				luck(),
				GameConfig.sellMultiplier(data)
			)
		)
	end
end

print()
print("Marcos:")
for _, m in ipairs(milestones) do
	if m.text:find("Terreno") or tonumber(m.text:match("%d+")) % 5 == 0 then
		print(string.format("  %-8s %s", Format.time(m.t), m.text))
	end
end

print()
print(string.format("Colheitas: %s", Format.number(data.stats.harvests)))
print(string.format("Total ganho: %s", Format.money(data.stats.earned)))
print(string.format("Velocidade esteira: %.0f studs/s", GameConfig.conveyorSpeed(data.upgrades.conveyor)))

-- sanidade: a fazenda nao pode travar
assert(data.stats.harvests > 100, "loop nao produziu colheitas")
assert(data.level >= 20, "progressao travou no nivel " .. data.level)
assert(data.cash > 1000, "economia nao cresceu")
print("\nsim ok")
