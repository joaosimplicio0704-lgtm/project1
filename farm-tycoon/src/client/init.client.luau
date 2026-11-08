-- init.client
-- Cria a UI, liga a rede e roda o loop de render a 60 FPS.
-- Zero logica de jogo aqui: tudo vem do snapshot do servidor.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Theme = require(script.Theme)
local State = require(script.State)
local NetClient = require(script.NetClient)
local Render = require(script.Render)
local Hud = require(script.Hud)
local Panels = require(script.Panels)
local Toasts = require(script.Toasts)
local Effects = require(script.Effects)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.GameConfig)

---------------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FarmTycoonGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

Render.init()
Toasts.init(gui)
Hud.build(gui)
Panels.build(gui)
Effects.init(gui)

---------------------------------------------------------------------------
-- REDE
---------------------------------------------------------------------------

NetClient.state.OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

NetClient.on(function(kind, payload)
	if kind == Net.EventKind.Toast then
		Toasts.push(payload.text, payload.color)
	elseif kind == Net.EventKind.LevelUp then
		Toasts.push("⬆️  Nível " .. payload.level .. "!", Theme.cyan)
		Effects.levelUp()
	elseif kind == Net.EventKind.Rebirth then
		Toasts.push("♻️  Rebirth " .. payload.rebirths .. "!  +" .. payload.crystals .. " 💎", Theme.gold)
		Effects.rebirth()
	elseif kind == Net.EventKind.Sale then
		Effects.sale(payload.amount)
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
	local snapshot = State.snapshot
	if snapshot then
		Render.step(snapshot, dt)
	end
end)

---------------------------------------------------------------------------
-- ATAJOS
---------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- F = colher tudo (cliente pede, servidor valida)
ContextActionService:BindAction("FarmHarvest", function(_, state)
	if state == Enum.UserInputState.Begin then
		NetClient.action(Net.ActionKind.Harvest)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		Panels.toggle()
	end
end)

-- dica inicial
task.delay(1.5, function()
	Toasts.push("F = colher tudo   ·   M = abrir/fechar menu   ·   arraste o painel", Theme.dim)
end)

print("[FarmTycoon] Cliente pronto ·", #GameConfig.Crops, "crops ·", player.Name)
