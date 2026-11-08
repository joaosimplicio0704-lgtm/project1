-- init.client
-- Monta a UI inteira e liga a rede. Nenhuma regra de jogo aqui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)

local Theme = require(script.Theme)
local State = require(script.State)
local NetClient = require(script.NetClient)
local Hud = require(script.Hud)
local TapButton = require(script.TapButton)
local EggPanel = require(script.EggPanel)
local PetsPanel = require(script.PetsPanel)
local ShopPanel = require(script.ShopPanel)
local Toasts = require(script.Toasts)
local WorldUI = require(script.WorldUI)
local BiomesPanel = require(script.BiomesPanel)

---------------------------------------------------------------------------
-- GUI RAIZ
---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "EggTycoonGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 20
gui.Parent = playerGui

Toasts.init(gui)

---------------------------------------------------------------------------
-- PAINEIS
---------------------------------------------------------------------------

EggPanel.build(gui)
PetsPanel.build(gui)
ShopPanel.build(gui)
BiomesPanel.build(gui)

local function closeAll()
	EggPanel.hide()
	PetsPanel.hide()
	ShopPanel.hide()
	BiomesPanel.hide()
end

local function openEggs(eggId)
	PetsPanel.hide()
	ShopPanel.hide()
	if eggId then
		EggPanel.select(eggId)
	end
	EggPanel.show()
end

Hud.build(gui, {
	shop = function()
		closeAll()
		ShopPanel.show("coins")
	end,
	trade = function()
		closeAll()
		PetsPanel.show()
	end,
	settings = function()
		Toasts.push("⚙️ em breve", "info")
	end,
	ranks = function()
		local snapshot = State.snapshot
		if snapshot then
			Toasts.push(string.format("🏆 Rebirths: %d · Pets: %d", snapshot.rebirths, #snapshot.pets), "info")
		end
	end,
})

TapButton.build(gui, function()
	NetClient.action(Net.ActionKind.Tap, 1)
	local snapshot = State.snapshot
	TapButton.showReward(snapshot and snapshot.tapPower or 1)
end)

---------------------------------------------------------------------------
-- BOTÕES EXTRAS (OVOS / PETS / REBIRTH) no canto superior esquerdo
---------------------------------------------------------------------------

local topLeft = Instance.new("Frame")
topLeft.BackgroundTransparency = 1
topLeft.Size = UDim2.fromOffset(430, 62)
topLeft.Position = UDim2.fromOffset(18, 16)
topLeft.Parent = gui
Theme.list(topLeft, {
	direction = Enum.FillDirection.Horizontal,
	padding = 10,
	hAlign = Enum.HorizontalAlignment.Left,
})

local function toolbarButton(text, icon, color, order, onClick)
	local btn = Theme.button(topLeft, {
		text = icon .. "  " .. text,
		size = UDim2.fromOffset(136, 56),
		color = color,
		textSize = 19,
		layoutOrder = order,
		radius = 28,
	})
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

toolbarButton("Ovos", "🥚", Color3.fromRGB(255, 196, 90), 1, function()
	openEggs()
end)

toolbarButton("Pets", "🐾", Color3.fromRGB(160, 210, 255), 2, function()
	closeAll()
	PetsPanel.show()
end)

toolbarButton("Rebirth", "♻️", Color3.fromRGB(150, 235, 190), 3, function()
	local snapshot = State.snapshot
	if not snapshot then
		return
	end
	if snapshot.coins >= snapshot.rebirthCost then
		NetClient.action(Net.ActionKind.Rebirth)
	else
		Toasts.push("Ainda não dá pra renascer 💪", "error")
	end
end)

---------------------------------------------------------------------------
-- MUNDO
---------------------------------------------------------------------------

WorldUI.build({
	selectEgg = function(eggId)
		-- o servidor precisa saber qual ovo foi escolhido, senão o hatch
		-- sempre usa o selectedEgg antigo
		NetClient.action(Net.ActionKind.SelectEgg, eggId)
		openEggs(eggId)
	end,
	zone = function(zone)
		if zone == Net.Zones.Shop then
			closeAll()
			ShopPanel.show("coins")
		elseif zone == Net.Zones.GemShop then
			closeAll()
			ShopPanel.show("gems")
		elseif zone == Net.Zones.Golden then
			NetClient.action(Net.ActionKind.Golden)
		elseif zone == Net.Zones.Fusion then
			closeAll()
			PetsPanel.show()
		elseif zone == Net.Zones.Rebirth then
			local snapshot = State.snapshot
			if snapshot then
				local cost = snapshot.rebirthCost
				if snapshot.coins >= cost then
					NetClient.action(Net.ActionKind.Rebirth)
				else
					Toasts.push("Faltam " .. Format.number(cost - snapshot.coins) .. " moedas", "error")
				end
			end
		elseif zone == Net.Zones.Trade then
			closeAll()
			PetsPanel.show()
		elseif zone == "egg_halloween" then
			openEggs()
		end
	end,
	-- Portal: o servidor valida o desbloqueio e devolve erro se faltar.
	travel = function(biomeId)
		NetClient.action(Net.ActionKind.Travel, biomeId)
	end,
})

---------------------------------------------------------------------------
-- REDE
---------------------------------------------------------------------------

NetClient.state.OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
	WorldUI.syncPets(snapshot)
	if EggPanel and EggPanel.refresh then
		EggPanel.refresh()
	end
	if BiomesPanel and BiomesPanel.refresh then
		BiomesPanel.refresh()
	end
end)

NetClient.on(function(kind, payload)
	if kind == Net.EventKind.Toast then
		Toasts.push(payload.text, payload.kind)
	elseif kind == Net.EventKind.Hatch then
		EggPanel.onHatch(payload)
	elseif kind == Net.EventKind.Rebirth then
		Toasts.push(string.format("♻️ Rebirth %d! +%d 💎", payload.rebirths, payload.crystals), "success")
	elseif kind == Net.EventKind.Zone then
		-- servidor abrindo UI remotamente
	end
end)

---------------------------------------------------------------------------
-- LOOP
---------------------------------------------------------------------------

local last = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(now - last, 0.2)
	last = now
	WorldUI.stepPets(dt)
end)

---------------------------------------------------------------------------
-- ATAJOS
---------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode

	if key == Enum.KeyCode.M then
		BiomesPanel.toggle()
	elseif key == Enum.KeyCode.E then
		openEggs()
	elseif key == Enum.KeyCode.P then
		closeAll()
		PetsPanel.show()
	elseif key == Enum.KeyCode.B then
		closeAll()
		ShopPanel.show("coins")
	elseif key == Enum.KeyCode.G then
		closeAll()
		ShopPanel.show("gems")
	elseif key == Enum.KeyCode.Escape then
		closeAll()
	end
end)

task.delay(1.5, function()
	Toasts.push("👆 Toque pra ganhar  ·  🥚 abra ovos  ·  🐾 equipe pets", "info")
end)

print("[EggTycoon] Cliente pronto ·", player.Name)
