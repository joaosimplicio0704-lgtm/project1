// world.mjs — constrói o mapa inteiro no host falso e confere a estrutura.
// É o teste que responde "o jogo abre com mundo ou com um vazio?".
// Uso: node tests/world.mjs
import { HOST, chunk, createLua, fromLua, run, serverModules, sharedModules } from "./harness.mjs";

const SERVICES = `
services = {}
game = { GetService = function(_, name)
  if not services[name] then
    local i = Instance.new("Folder")
    i.Name = name
    services[name] = i
  end
  return services[name]
end }
`;

const lua = await createLua();
const code = chunk(
	HOST,
	SERVICES,
	sharedModules(["GameConfig", "Format", "Net", "Pets", "Noise", "Biomes", "Terrain", "Style", "Mine", "Combat"]),
	serverModules(["World"]),
	"__World = World",
	"__World.build()",
	// Coleta a estrutura num só lugar: contar depois, fora do Lua, é chato.
	String.raw`
__counts = {}
local function walk(node)
  for _, child in ipairs(node:GetChildren()) do
    __counts[child.ClassName] = (__counts[child.ClassName] or 0) + 1
    walk(child)
  end
end

__root = game:GetService("Workspace"):FindFirstChild("EggTycoon")
assert(__root, "World.build() nao criou Workspace.EggTycoon")
walk(__root)

-- CERCA: conta estacas por ilha e confere que elas BLOQUEIAM.
-- Cerca que nao colide e decoração: o jogador atravessa e a barreira nao
-- existe. Aqui a barreira e funcional, nao enfeite.
-- ARVORE: a copa tem que puxar a cor do bioma.
-- Antes eram bolas verdes identicas no prado, no deserto e no gelo.
-- So meadow/shadow/cosmos usam tree(); deserto, gelo, floresta e halloween
-- tem construtor proprio.
__treeTones = ""

for _, id in ipairs({ "meadow", "shadow", "cosmos" }) do
  for _, inst in ipairs(__root:GetDescendants()) do
    -- a folha fica em Tree/, dentro de Biome_<id>: precisa subir a cadeia.
    -- Comparar so o pai imediato nao acha nada.
    local inBiome = false
    local node = inst.Parent
    for _ = 1, 4 do
      if node and string.find(node.Name, "Biome_" .. id, 1, true) then
        inBiome = true
        break
      end
      node = node and node.Parent
    end
    -- So arvore de verdade (Tree/). O Bush do hub tambem tem Leaf,
    -- e no prado a accent dele e rosa: pegava a peça errada.
    if inst.Name == "Leaf" and inBiome and inst.Parent and inst.Parent.Name == "Tree" then
      local c = inst.Color
      __treeTones = __treeTones .. id .. "=" .. math.floor(c.R * 255) .. "," .. math.floor(c.G * 255) .. "," .. math.floor(c.B * 255) .. " parent=" .. tostring(inst.Parent and inst.Parent.Name) .. " "
      break
    end
  end
end

__fencePosts = 0
__fenceSolid = 0
for _, inst in ipairs(__root:GetDescendants()) do
  if inst.Name == "FencePost" then
    __fencePosts = __fencePosts + 1
    if inst.CanCollide ~= false then __fenceSolid = __fenceSolid + 1 end
  end
end

-- spawn tem que estar LIVRE: nenhuma estaca a menos de 20 studs
__spawnClear = true
__spawnOffender = "nenhuma"
for _, inst in ipairs(__root:GetDescendants()) do
  -- So incomoda se estiver na MESMA altura do jogador. A ilha do cosmos
  -- paira a 212 de altura e a cerca dela passa por cima do spawn: em XZ
  -- bate, em Y esta 200 studs acima da cabeca. Comparar so XZ dava falso
  -- positivo.
  if inst.Name == "FencePost" and math.abs(inst.Position.Y - 5) < 25 then
    local dx = inst.Position.X - 0
    local dz = inst.Position.Z - 62
    local d = math.sqrt(dx*dx + dz*dz)
    if d < 20 then
      __spawnClear = false
      __spawnOffender = inst.Position.X .. "," .. inst.Position.Y .. "," .. inst.Position.Z
    end
  end
end

__biomes = {}
local biomeFolder = __root:FindFirstChild("Biomes")
assert(biomeFolder, "Workspace.EggTycoon.Biomes nao existe")
for _, model in ipairs(biomeFolder:GetChildren()) do
  __biomes[#__biomes + 1] = model.Name
end

-- ovos: um por bioma, com ClickDetector para chocar
__eggs = {}
for _, inst in ipairs(__root:GetDescendants()) do
  if string.sub(inst.Name, 1, 4) == "Egg_" then
    local hasClick = inst:FindFirstChildOfClass("ClickDetector") ~= nil
    __eggs[#__eggs + 1] = inst.Name .. (hasClick and "" or "!semclick")
  end
end

-- partes de tamanho zero são o clássico "invisível e o jogador cai"
__zero = 0
for _, inst in ipairs(__root:GetDescendants()) do
  if inst.ClassName == "Part" then
    local s = inst.Size
    if s and (s.X <= 0 or s.Y <= 0 or s.Z <= 0) then
      __zero = __zero + 1
    end
  end
end

__spawn = nil
__spawnY = nil
for _, inst in ipairs(__root:GetDescendants()) do
  if inst.ClassName == "SpawnLocation" then
    __spawn = inst.Name
    __spawnY = inst.Position.Y
  end
end

-- O SpawnLocation precisa estar SOBRE a praça, não flutuando nem enterrado.
-- Se ele ficar no vazio, o jogador cai no oceano ao entrar no jogo.
-- Num PartType.Cylinder a altura fica no eixo X (o Roblox desenha o cilindro
-- deitado em X), então Size.Y é o DIÂMETRO, não a espessura. Ler a espessura
-- certa evita falso positivo de "spawn fora do chão".
__plazaTop = nil
for _, inst in ipairs(__root:GetChildren()) do
  if inst.Name == "Plaza" then
    local isCylinder = inst.Shape == Enum.PartType.Cylinder
    __plazaTop = inst.Position.Y + (isCylinder and inst.Size.X or inst.Size.Y) / 2
  end
end

-- GEOMETRIA: ovo e pedestal precisam ficar ACIMA do chão.
-- Se o relevo mudar e o pedestal afundar, o jogador vê um ovo meio enterrado
-- e não consegue clicar. Esse teste pega isso antes de abrir no Studio.
__geometry = {}
local biomeFolder = __root:FindFirstChild("Biomes")
for _, model in ipairs(biomeFolder:GetChildren()) do
  local id = string.gsub(model.Name, "^Biome_", "")
  local biome = Biomes.get(id)
  local center = Biomes.centerVector(biome)

  local groundY = -9999
  local pedestalY = nil
  local eggY = nil
  for _, inst in ipairs(model:GetDescendants()) do
    if inst.Name == "CellTop" then
      local dx = inst.Position.X - center.X
      local dz = inst.Position.Z - center.Z
      if math.sqrt(dx * dx + dz * dz) < 32 and inst.Position.Y > groundY then
        groundY = inst.Position.Y
      end
    elseif inst.Name == "Pedestal" then
      pedestalY = inst.Position.Y
    elseif inst.Name == "Egg_" .. biome.eggId then
      eggY = inst.Position.Y
    end
  end
  __geometry[id] = { ground = groundY, pedestal = pedestalY, egg = eggY }
end

-- MARCO E LUZ: cada ilha precisa do icone gigante e de luz propria.
-- Sem o marco a ilha e "grama com arvore" e fica igual as outras; sem luz,
-- a sombra e o ambiente sao identicos e o tema some.
__landmarks = {}
__lights = {}
for _, model in ipairs(biomeFolder:GetChildren()) do
  local id = string.gsub(model.Name, "^Biome_", "")
  local landmark = model:FindFirstChild("Landmark")
  __landmarks[id] = landmark and #landmark:GetChildren() or 0

  local lightParts = 0
  for _, inst in ipairs(model:GetDescendants()) do
    if inst.ClassName == "PointLight" then
      lightParts = lightParts + 1
    end
  end
  __lights[id] = lightParts
end

-- DECORACAO TEMATICA: cada ilha precisa de enfeites que só ela tem.
-- Sem isso tudo vira "grama com árvore" e o tema fica só na cor.
__themed = {}
local THEMED_NAMES = {
  CherryTrunk = "meadow", Bench = "meadow",
  ShroomStem = "forest", FallenLog = "forest",
  Cactus = "desert", BoneRib = "desert",
  SnowBase = "ice", IceTreeTrunk = "ice",
  Grave = "shadow", SoulFlame = "shadow",
  SmallPumpkin = "halloween", GhostCandle = "halloween",
  Asteroid = "cosmos", FallenStar = "cosmos",
}
for _, model in ipairs(biomeFolder:GetChildren()) do
  local id = string.gsub(model.Name, "^Biome_", "")
  local found = {}
  for _, inst in ipairs(model:GetDescendants()) do
    local owner = THEMED_NAMES[inst.Name]
    if owner then
      found[inst.Name] = (found[inst.Name] or 0) + 1
    end
  end
  __themed[id] = found
end

-- PORTAIS DO HUB: nao podem se sobrepor nem sair da praca.
-- Dois portais colados sao invisiveis no codigo e obvios no jogo.
__portals = {}
for _, model in ipairs(__root:GetChildren()) do
  if string.sub(model.Name, 1, 9) == "PortalTo_" then
    local veil = model:FindFirstChild("Veil")
    if veil then
      __portals[#__portals + 1] = {
        biome = string.gsub(model.Name, "^PortalTo_", ""),
        x = veil.Position.X,
        z = veil.Position.Z,
      }
    end
  end
end

-- Colisao real: o portal nao pode invadir loja nem outro portal.
-- (Base do portal sobre a praca e proposital; dois portais no mesmo lugar nao.)
__portalHits = {}
for _, model in ipairs(__root:GetChildren()) do
  if string.sub(model.Name, 1, 9) == "PortalTo_" then
    local base = model:FindFirstChild("Base")
    if base then
      for _, other in ipairs(__root:GetChildren()) do
        if other ~= model and (string.sub(other.Name, 1, 9) == "PortalTo_" or other:FindFirstChild("ShopSign") or other:FindFirstChild("Sign")) then
          local ob = other:FindFirstChild("Base") or other:FindFirstChild("Floor")
          if ob then
            local d = math.sqrt((base.Position.X - ob.Position.X)^2 + (base.Position.Z - ob.Position.Z)^2)
            if d < (base.Size.X + ob.Size.X) / 2 then
              __portalHits[#__portalHits + 1] = model.Name .. " perto de " .. other.Name .. " (" .. math.floor(d) .. ")"
            end
          end
        end
      end
    end
  end
end

-- O spawn nao pode ficar embaixo da estatua: o jogador nasce dentro da pedra.
__statue = nil
for _, inst in ipairs(__root:GetDescendants()) do
  if inst.Name == "StatueBase" then
    __statue = { x = inst.Position.X, z = inst.Position.Z, sx = inst.Size.X, sz = inst.Size.Z }
  end
end

-- ceu: nuvens e ilhotas de enfeite entre as ilhas
__sky = 0
local skyFolder = __root:FindFirstChild("Sky")
if skyFolder then
  __sky = #skyFolder:GetChildren()
end
`,
);
run(lua, code, "world");

const counts = fromLua(lua.globals.get("__counts")) ?? {};
const biomes = fromLua(lua.globals.get("__biomes")) ?? [];
const eggs = fromLua(lua.globals.get("__eggs")) ?? [];
const zero = Number(fromLua(lua.globals.get("__zero")) ?? 0);
const spawn = fromLua(lua.globals.get("__spawn"));

const parts = Number(counts.Part ?? 0);
const total = Object.values(counts).reduce((sum, n) => sum + Number(n), 0);

const problems = [];
if (!parts || parts < 2000) problems.push(`poucas partes: ${parts}`);
if (biomes.length !== 7) problems.push(`biomas: ${biomes.length} (esperado 7)`);
if (eggs.length !== 7) problems.push(`ovos: ${eggs.length} (esperado 7)`);
if (eggs.some((e) => e.includes("!semclick"))) problems.push("ovo sem ClickDetector");
if (!spawn) problems.push("sem SpawnLocation");
const spawnY = Number(fromLua(lua.globals.get("__spawnY")) ?? 0);
const plazaTop = Number(fromLua(lua.globals.get("__plazaTop")) ?? 0);
if (spawn && (spawnY < plazaTop - 0.5 || spawnY > plazaTop + 8)) {
	problems.push(`SpawnLocation fora do chão da praça (spawn ${spawnY.toFixed(1)}, chão ${plazaTop.toFixed(1)})`);
}
if (zero > 0) problems.push(`partes com tamanho zero: ${zero}`);

// COR DAS ARVORES POR BIOMA
const tones = String(fromLua(lua.globals.get("__treeTones")) ?? "");
function parseTone(id) {
	const m = tones.match(new RegExp(`${id}=(\\d+),(\\d+),(\\d+)`));
	return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}
const toneList = ["meadow", "shadow", "cosmos"].map((id) => [id, parseTone(id)]);
const missing = toneList.filter(([, t]) => !t).map(([id]) => id);
if (missing.length > 0) {
	problems.push(`arvore sem cor por bioma: faltou ${missing.join(", ")} (${tones})`);
} else {
	// dois biomas com o mesmo tom = a cor do bioma nao foi aplicada
	for (let i = 0; i < toneList.length; i++) {
		for (let j = i + 1; j < toneList.length; j++) {
			const [ia, a] = toneList[i];
			const [ib, b] = toneList[j];
			const d = Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) + Math.abs(a[2] - b[2]);
			if (d < 40) problems.push(`arvores de ${ia} e ${ib} quase iguais: ${a} vs ${b}`);
		}
	}
	const meadow = parseTone("meadow");
	if (!(meadow[1] > meadow[0] && meadow[1] > meadow[2])) {
		problems.push(`arvore do prado nao e verde: ${meadow}`);
	}
}

// CERCA
const fencePosts = Number(fromLua(lua.globals.get("__fencePosts")) ?? 0);
const fenceSolid = Number(fromLua(lua.globals.get("__fenceSolid")) ?? 0);
const spawnClear = fromLua(lua.globals.get("__spawnClear"));
if (fencePosts < 150) {
	problems.push(`poucas estacas de cerca: ${fencePosts} (esperado 7 ilhas + hub)`);
}
if (fenceSolid !== fencePosts) {
	problems.push(`cerca que nao bloqueia: ${fenceSolid}/${fencePosts} com colisao`);
}
if (spawnClear !== true) {
	problems.push("estaca de cerca em cima do spawn: " + fromLua(lua.globals.get("__spawnOffender")));
}

// geometria: nada enterrado, nada flutuando longe do chão
const geometry = fromLua(lua.globals.get("__geometry")) ?? {};
for (const [id, spot] of Object.entries(geometry)) {
	const ground = Number(spot.ground);
	const pedestal = Number(spot.pedestal);
	const egg = Number(spot.egg);
	if (!Number.isFinite(pedestal)) {
		problems.push(`${id}: sem pedestal de ovo`);
		continue;
	}
	if (pedestal < ground - 0.5) problems.push(`${id}: pedestal enterrado (chão ${ground}, pedestal ${pedestal})`);
	if (pedestal > ground + 12) problems.push(`${id}: pedestal flutuando (chão ${ground}, pedestal ${pedestal})`);
	if (egg <= pedestal) problems.push(`${id}: ovo abaixo do pedestal`);
}

// marco e iluminação
const landmarks = fromLua(lua.globals.get("__landmarks")) ?? {};
const lights = fromLua(lua.globals.get("__lights")) ?? {};
for (const id of Object.keys(landmarks)) {
	if (Number(landmarks[id]) < 3) problems.push(`${id}: marco ausente ou vazio (${landmarks[id]} peças)`);
	if (Number(lights[id]) < 4) problems.push(`${id}: pouca luz (${lights[id]} PointLight)`);
}

const themed = fromLua(lua.globals.get("__themed")) ?? {};
const themedNames = {
	meadow: ["CherryTrunk", "Bench"],
	forest: ["ShroomStem", "FallenLog"],
	desert: ["Cactus", "BoneRib"],
	ice: ["SnowBase", "IceTreeTrunk"],
	shadow: ["Grave", "SoulFlame"],
	halloween: ["SmallPumpkin", "GhostCandle"],
	cosmos: ["Asteroid", "FallenStar"],
};
for (const [id, names] of Object.entries(themedNames)) {
	const found = themed[id] ?? {};
	for (const name of names) {
		if (Number(found[name] ?? 0) < 2) {
			problems.push(`${id}: decoração temática "${name}" ausente ou insuficiente`);
		}
	}
}

const portals = fromLua(lua.globals.get("__portals")) ?? [];
if (portals.length !== 7) problems.push(`portais no hub: ${portals.length} (esperado 7)`);
let closestPortal = Infinity;
for (let i = 0; i < portals.length; i += 1) {
	for (let j = i + 1; j < portals.length; j += 1) {
		const d = Math.hypot(portals[i].x - portals[j].x, portals[i].z - portals[j].z);
		if (d < closestPortal) closestPortal = d;
	}
}
if (portals.length > 1 && closestPortal < 40) {
	problems.push(`portais colados: ${closestPortal.toFixed(0)} studs entre centros`);
}
for (const portal of portals) {
	const radius = Math.hypot(portal.x, portal.z);
	if (radius > 155) problems.push(`portal ${portal.biome} fora da laje (${radius.toFixed(0)})`);
}

const portalHits = fromLua(lua.globals.get("__portalHits")) ?? {};
const hitList = Array.isArray(portalHits) ? portalHits : Object.values(portalHits);
for (const hit of hitList) problems.push("portal invade espaço: " + hit);

const statue = fromLua(lua.globals.get("__statue"));
if (statue && spawn) {
	const spawnZ = 86; // posição do SpawnLocation definida em World.build
	const dz = Math.abs(spawnZ - Number(statue.z));
	if (dz < (18 + Number(statue.sz)) / 2) {
		problems.push(`spawn em cima da estátua (dz=${dz.toFixed(0)})`);
	}
}

const sky = Number(fromLua(lua.globals.get("__sky")) ?? 0);
if (sky < 10) problems.push(`céu vazio: ${sky} enfeites entre as ilhas`);

if (problems.length) {
	console.error("world FALHOU");
	for (const problem of problems) console.error("  - " + problem);
	process.exit(1);
}

console.log(`world ok — ${total} instâncias, ${parts} partes, ${biomes.length} biomas`);
console.log("  biomas: " + biomes.sort().join(", "));
console.log("  ovos:   " + eggs.sort().join(", "));
console.log("  marcos: " + Object.entries(landmarks).map(([k, v]) => `${k}=${v}`).join(" "));
console.log("  luzes:  " + Object.entries(lights).map(([k, v]) => `${k}=${v}`).join(" "));
console.log(`  ceu:    ${sky} enfeites entre as ilhas`);
