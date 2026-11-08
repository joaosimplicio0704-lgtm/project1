-- MinePanel
-- O painel da Mina dos Pets: mostra cada pet equipado trabalhando, o que ele
-- trouxe e o botão de recolher.
--
-- O desenho desta tela é o que explica a mecânica sem texto nenhum:
--   - um trilho de progresso por pet (quanto falta para voltar)
--   - quando volta, o minério aparece com a cor dele
--   - o minério mais raro já achado fica no topo, como um troféu
-- Criança que não lê entende pelo movimento da barrinha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local MinePanel = {}

local refs = { rows = {}, best = nil, total = nil }
local gui

local ROW_H = 66
local ROW_GAP = 8

local function rgb(color)
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function buildRow(parent, index)
	local row = Instance.new("Frame")
	row.Name = "MineRow" .. index
	row.Size = UDim2.new(1, -32, 0, ROW_H)
	row.Position = UDim2.fromOffset(16, 78 + (index - 1) * (ROW_H + ROW_GAP))
	row.BackgroundColor3 = Color3.fromRGB(246, 250, 255)
	row.BorderSizePixel = 0
	row.ZIndex = 26
	row.Parent = parent
	Theme.corner(row, 18)

	-- bolinha do pet
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(30, 30)
	dot.Position = UDim2.fromOffset(14, 18)
	dot.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
	dot.BorderSizePixel = 0
	dot.ZIndex = 27
	dot.Parent = row
	Theme.corner(dot, 15)

	-- barra de progresso: o trilho
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -230, 0, 14)
	track.Position = UDim2.fromOffset(56, 14)
	track.BackgroundColor3 = Color3.fromRGB(214, 224, 236)
	track.BorderSizePixel = 0
	track.ZIndex = 27
	track.Parent = row
	Theme.corner(track, 7)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 28
	fill.Parent = track
	Theme.corner(fill, 7)

	local status = Theme.label(row, {
		text = "escavando...",
		size = UDim2.new(1, -230, 0, 24),
		position = UDim2.fromOffset(56, 32),
		textSize = 17,
		align = Enum.TextXAlignment.Left,
		color = Color3.fromRGB(110, 120, 135),
		zIndex = 28,
	})

	-- botão de ação: "Apressar" enquanto escava, "Recolher" quando volta
	local action = Theme.button(row, {
		text = "⚡",
		size = UDim2.fromOffset(74, 40),
		position = UDim2.new(1, -88, 0, 13),
		color = Color3.fromRGB(255, 200, 90),
		textSize = 24,
		zIndex = 28,
		radius = 20,
	})

	local uid = nil
	action.MouseButton1Click:Connect(function()
		if not uid then
			return
		end
		local trip = refs.rows[index] and refs.rows[index].trip
		if not trip then
			return
		end
		if trip.ready then
			NetClient.action(Net.ActionKind.CollectMine, uid)
		else
			NetClient.action(Net.ActionKind.RushMine, uid)
		end
	end)

	refs.rows[index] = { row = row, dot = dot, fill = fill, status = status, action = action }
	return refs.rows[index]
end

function MinePanel.build(parentGui)
	gui = parentGui

	local root = Theme.panel(gui, {
		name = "MinePanel",
		size = UDim2.fromOffset(620, 600),
		position = UDim2.new(0.5, 0, 0.5, 0),
		color = Theme.white,
		radius = 30,
		zIndex = 25,
	})
	root.Visible = false
	refs.root = root

	-- placa pendurada, como nas referências: o nome fica FORA do painel,
	-- numa plaquinha escura. Dá a sensação de loja/postinho de verdade.
	Theme.titleTag(root, "⛏️ MINA DOS PETS", { width = 300, offset = -26, zIndex = 25 })

	local close = Theme.button(root, {
		text = "✕",
		size = UDim2.fromOffset(52, 52),
		position = UDim2.new(1, -18, 0, 14),
		color = Color3.fromRGB(255, 120, 120),
		textSize = 26,
		zIndex = 28,
		radius = 26,
	})
	close.MouseButton1Click:Connect(function()
		MinePanel.hide()
	end)

	-- troféu: melhor minério já achado + total de viagens
	refs.best = Theme.label(root, {
		text = "melhor achado: —",
		size = UDim2.new(1, -32, 0, 26),
		position = UDim2.fromOffset(16, 44),
		textSize = 20,
		align = Enum.TextXAlignment.Left,
		color = Color3.fromRGB(90, 100, 120),
		zIndex = 27,
	})

	-- botão de recolher tudo
	refs.collectAll = Theme.button(root, {
		text = "RECOLHER TUDO",
		size = UDim2.new(1, -32, 0, 46),
		position = UDim2.new(0, 16, 1, -58),
		color = Color3.fromRGB(120, 220, 160),
		textSize = 22,
		zIndex = 28,
		radius = 23,
	})
	refs.collectAll.MouseButton1Click:Connect(function()
		NetClient.action(Net.ActionKind.CollectMine)
	end)

	-- mensagem de mina vazia
	refs.empty = Theme.label(root, {
		text = "equipe um pet para ele começar a trabalhar",
		size = UDim2.new(1, -80, 0, 80),
		position = UDim2.new(0, 40, 0.42, 0),
		textSize = 22,
		color = Color3.fromRGB(150, 158, 172),
		zIndex = 27,
	})
	refs.empty.Visible = false
end

function MinePanel.update()
	local snapshot = State.snapshot
	if not snapshot or not refs.root then
		return
	end
	local mine = snapshot.mine
	if not mine then
		return
	end

	local trips = mine.trips or {}
	refs.empty.Visible = #trips == 0
	if refs.collectAll then
		refs.collectAll.Visible = #trips > 0
	end

	if refs.best then
		local bestName = "—"
		for _, ore in ipairs(mine.ores or {}) do
			if ore.id == mine.best then
				bestName = ore.name
			end
		end
		refs.best.Text = string.format("🏆 melhor achado: %s   ·   viagens: %d", bestName, mine.dug or 0)
	end

	for index = 1, 7 do
		local view = refs.rows[index]
		if not view then
			view = buildRow(refs.root, index)
		end
		local trip = trips[index]
		-- o tick local precisa saber a duração da viagem para avançar a barra
		if trip then
			trip.tripSeconds = mine.tripSeconds or 7
		end
		view.trip = trip
		if trip then
			view.row.Visible = true
			view.fill.Size = UDim2.new(trip.progress or 0, 0, 1, 0)

			local ore = nil
			for _, entry in ipairs(mine.ores or {}) do
				if entry.id == trip.oreId then
					ore = entry
				end
			end

			if trip.ready and ore then
				view.dot.BackgroundColor3 = rgb(ore.color)
				view.fill.BackgroundColor3 = rgb(ore.color)
				view.status.Text = string.format("%s · +%s moedas", ore.name, Format.number(ore.value))
				view.action.Text = "✔"
				view.action.BackgroundColor3 = Color3.fromRGB(120, 220, 160)
			else
				view.dot.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
				view.fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
				view.status.Text = string.format("escavando... %d%%", math.floor((trip.progress or 0) * 100))
				view.action.Text = "⚡"
				view.action.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
			end
		else
			view.row.Visible = false
		end
	end
end

function MinePanel.isOpen()
	return refs.root ~= nil and refs.root.Visible
end

-- Avança as barras com o tempo local entre um snapshot e outro, para a mina
-- não parecer travada. O servidor manda o valor real e corrige sozinho.
function MinePanel.tick(dt)
	for _, view in pairs(refs.rows) do
		local trip = view.trip
		if trip and not trip.ready and view.row.Visible then
			trip.progress = math.min(1, (trip.progress or 0) + dt / (trip.tripSeconds or 7))
			view.fill.Size = UDim2.new(trip.progress, 0, 1, 0)
			view.status.Text = string.format("escavando... %d%%", math.floor(trip.progress * 100))
			if trip.progress >= 1 then
				-- chegou no fim do trilho: pede o estado real ao servidor
				trip.readyPending = true
			end
		end
	end
end

function MinePanel.show()
	if not refs.root then
		return
	end
	refs.root.Visible = true
	MinePanel.update()
end

function MinePanel.hide()
	if refs.root then
		refs.root.Visible = false
	end
end

function MinePanel.toggle()
	if refs.root and refs.root.Visible then
		MinePanel.hide()
	else
		MinePanel.show()
	end
end

return MinePanel
