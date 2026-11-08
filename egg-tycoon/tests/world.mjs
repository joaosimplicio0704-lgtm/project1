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
	sharedModules(["GameConfig", "Format", "Net", "Pets", "Noise", "Biomes", "Terrain"]),
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
for _, inst in ipairs(__root:GetDescendants()) do
  if inst.ClassName == "SpawnLocation" then
    __spawn = inst.Name
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
if (zero > 0) problems.push(`partes com tamanho zero: ${zero}`);

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

if (problems.length) {
	console.error("world FALHOU");
	for (const problem of problems) console.error("  - " + problem);
	process.exit(1);
}

console.log(`world ok — ${total} instâncias, ${parts} partes, ${biomes.length} biomas`);
console.log("  biomas: " + biomes.sort().join(", "));
console.log("  ovos:   " + eggs.sort().join(", "));
