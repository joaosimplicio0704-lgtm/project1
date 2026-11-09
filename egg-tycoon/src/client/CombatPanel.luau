-- CombatPanel
-- A barra de vida do MONSTRO, ancorada no topo da tela.
--
-- Por que não desenhar a barra em cima do monstro no mundo:
-- BillboardGui em cima do monstro fica minúscula quando o jogador está
-- longe e some atrás das árvores. Barra fixa no topo é sempre legível e é
-- o que jogo de celular faz — e a maioria dos jogadores de Roblox joga no
-- celular.
--
-- Este painel também é o BOTÃO de ataque: clicar no monstro no mundo
-- funciona, mas no celular é difícil acertar. Um botão grande resolve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local NetClient = require(script.Parent.NetClient)

local CombatPanel = {}

local refs = {}
local gui

local function build()
	local root = Instance.new("Frame")
	root.Name = "CombatPanel"
	root.Size = UDim2.fromOffset(420, 92)
	root.Position = UDim2.new(0.5, 0, 0, 14)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundColor3 = Color3.fromRGB(46, 42, 52)
	root.BorderSizePixel = 0
	root.ZIndex = 18
	root.Parent = gui
	Theme.corner(root, 18)
	Theme.stroke(root, Color3.fromRGB(28, 26, 32), 3)
	refs.root = root

	-- nome do monstro + nível
	refs.name = Theme.label(root, {
		text = "Gosma",
		size = UDim2.new(1, -100, 0, 26),
		position = UDim2.fromOffset(14, 6),
		textSize = 20,
		align = Enum.TextXAlignment.Left,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 0.2,
		zIndex = 20,
	})

	-- barra de vida
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -130, 0, 22)
	track.Position = UDim2.fromOffset(14, 34)
	track.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
	track.BorderSizePixel = 0
	track.ZIndex = 19
	track.Parent = root
	Theme.corner(track, 11)
	Theme.stroke(track, Color3.fromRGB(16, 14, 20), 2)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	fill.BorderSizePixel = 0
	fill.ZIndex = 20
	fill.Parent = track
	Theme.corner(fill, 11)
	refs.fill = fill

	refs.hp = Theme.label(root, {
		text = "40 / 40",
		size = UDim2.new(1, -130, 0, 22),
		position = UDim2.fromOffset(14, 34),
		textSize = 15,
		color = Color3.fromRGB(255, 255, 255),
		strokeTransparency = 0.15,
		zIndex = 21,
	})

	-- botão GRANDE de bater: no celular, mirar no monstro é chato
	refs.hitButton = Theme.button(root, {
		text = "⚔️ BATER",
		size = UDim2.fromOffset(110, 66),
		position = UDim2.new(1, -122, 0, 12),
		color = Color3.fromRGB(235, 96, 96),
		textSize = 19,
		radius = 16,
		zIndex = 21,
		strokeThickness = 3,
	})
	refs.hitButton.MouseButton1Click:Connect(function()
		NetClient.action(Net.ActionKind.Hit)
	end)

	-- respawn: quando o monstro está morto, o botão vira contagem
	refs.respawn = Theme.label(root, {
		text = "",
		size = UDim2.new(1, -130, 0, 20),
		position = UDim2.fromOffset(14, 60),
		textSize = 14,
		align = Enum.TextXAlignment.Left,
		color = Color3.fromRGB(255, 200, 120),
		strokeTransparency = 0.4,
		zIndex = 21,
	})

	root.Visible = false
end

function CombatPanel.build(parentGui)
	gui = parentGui
	build()
end

function CombatPanel.update()
	local snapshot = State.snapshot
	if not snapshot or not refs.root then
		return
	end
	local monster = snapshot.monster
	if not monster then
		refs.root.Visible = false
		return
	end

	refs.root.Visible = true
	local maxHealth = math.max(1, monster.maxHealth or 1)
	local health = math.clamp(monster.health or 0, 0, maxHealth)
	refs.name.Text =
		string.format("%s  (Nv %d)", monster.name or "Monstro", snapshot.progress and snapshot.progress.level or 1)
	refs.fill.Size = UDim2.fromScale(health / maxHealth, 1)
	refs.hp.Text = string.format("%d / %d", math.floor(health), math.floor(maxHealth))

	if monster.alive then
		refs.hitButton.Text = "⚔️ BATER"
		refs.hitButton.BackgroundColor3 = Color3.fromRGB(235, 96, 96)
		refs.respawn.Text = ""
	else
		refs.hitButton.Text = "💀"
		refs.hitButton.BackgroundColor3 = Color3.fromRGB(120, 116, 126)
		refs.respawn.Text = string.format("renasce em %.0fs", monster.respawnIn or 0)
	end
end

-- Detecta se o jogador está no raio da arena do bioma atual e avisa o
-- servidor quando MUDA (não manda a cada frame: seria tráfego inútil).
local inCombat = false
local lastSent = 0
local Players = game:GetService("Players")

function CombatPanel.step(dt)
	local snapshot = State.snapshot
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not snapshot or not root or not snapshot.monster then
		return
	end

	-- a arena fica deslocada do centro do bioma; o cliente lê a posição do
	-- próprio mundo para não precisar chutar a conta de novo
	local arena = workspace:FindFirstChild("EggTycoon")
		and workspace.EggTycoon:FindFirstChild("Biomes")
		and workspace.EggTycoon.Biomes:FindFirstChild("Biome_" .. (snapshot.biome or "meadow"))
	if not arena then
		return
	end
	local floor = arena:FindFirstChild("Arena") and arena.Arena:FindFirstChild("ArenaFloor")
	if not floor then
		return
	end

	local distance = (root.Position - floor.Position).Magnitude
	local nowInCombat = distance < 34
	if nowInCombat ~= inCombat then
		inCombat = nowInCombat
		CombatPanel.setInCombat(inCombat)
		NetClient.action(Net.ActionKind.SetCombat, inCombat)
	elseif nowInCombat and os.clock() - lastSent > 2 then
		-- enquanto está no combate, confirma de vez em quando: se um pacote
		-- se perder, o servidor não fica achando que o jogador está apanhando
		lastSent = os.clock()
		NetClient.action(Net.ActionKind.SetCombat, true)
	end
end

-- O monstro ataca quando o jogador está dentro da arena. O cliente avisa o
-- servidor que está em combate: só o cliente sabe onde o jogador está com
-- precisão, e vida não é informação que dê para trapacear valioso o
-- suficiente para justificar calcular no servidor a cada tick.
function CombatPanel.setInCombat(active)
	if refs.root then
		refs.root.BackgroundColor3 = active and Color3.fromRGB(60, 40, 40) or Color3.fromRGB(46, 42, 52)
	end
end

return CombatPanel
