// build-map.mjs — constrói o mapa no host falso e exporta como .rbxmx.
//
// O XML é montado DENTRO do Lua e devolvido como uma string só. Tentar passar
// a árvore como JSON quebrava (o `string.format("%q")` do Luau não é JSON), e
// escrever o XML no Node exigia reimplementar o formato binário do Roblox.
//
// Depois o Rojo lê esse .rbxmx e monta o lugar final: o parser oficial valida
// o formato, então nada de XML torto chegar no Studio.
//
// Uso: node tests/build-map.mjs
import fs from "node:fs";
import path from "node:path";
import { HOST, chunk, createLua, root, run, serverModules, sharedModules } from "./harness.mjs";

const SERVICES = String.raw`
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

// --- serializador XML, rodando dentro do Lua ------------------------------
// Uma passada na árvore, concatenando strings. Cores vão como inteiro
// (R + G*256 + B*65536), que é o formato que o Roblox guarda Color3uint8.
const XML_BUILDER = String.raw`
local MATERIALS = {
  SmoothPlastic = 256, Neon = 288, Wood = 512, WoodPlanks = 528,
  Marble = 784, Slate = 800, Basalt = 788, Brick = 816,
  Sandstone = 864, Cobblestone = 880, Ground = 1024, Grass = 1280,
  LeafyGrass = 1284, Sand = 1296, Fabric = 1312, Snow = 1328,
  Ice = 1536, Water = 2048, Metal = 1088, Concrete = 816, Rock = 896,
}
local SHAPES = { Ball = 0, Block = 1, Cylinder = 2, Wedge = 3, CornerWedge = 4 }

local out = {}
local refs = 0

local function esc(text)
  text = tostring(text or "")
  text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
  return text
end

-- Indentacao de 1 espaco por nivel (era 2). O arquivo tem ~12 mil itens e
-- 15 propriedades cada: so espaco em branco dava mais de 3 MB. O Rojo nao
-- liga para formatacao, e o .rbxlx fica legivel mesmo assim.
local INDENT = " "
local function write(level, line)
  out[#out + 1] = string.rep(INDENT, level) .. line
end

local function vec3Tag(name, v, level)
  if type(v) ~= "table" or type(v.X) ~= "number" then return end
  write(level, '<Vector3 name="' .. name .. '">')
  write(level + 1, "<X>" .. string.format("%.4f", v.X or 0) .. "</X>")
  write(level + 1, "<Y>" .. string.format("%.4f", v.Y or 0) .. "</Y>")
  write(level + 1, "<Z>" .. string.format("%.4f", v.Z or 0) .. "</Z>")
  write(level, "</Vector3>")
end

-- A matriz de rotacao vem do host como lista de 9 numeros (linha maior).
-- Se nao vier, e identidade — mas se vier e for ignorada, pecas giradas
-- (cilindro deitado, letreiro, espuma) nascem todas viradas pro mesmo lado.
local function cfTag(v, rot, level)
  if type(v) ~= "table" or type(v.X) ~= "number" then return end
  local m = (type(rot) == "table" and #rot == 9) and rot
    or { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
  write(level, '<CoordinateFrame name="CFrame">')
  write(level + 1, "<X>" .. string.format("%.4f", v.X) .. "</X>")
  write(level + 1, "<Y>" .. string.format("%.4f", v.Y or 0) .. "</Y>")
  write(level + 1, "<Z>" .. string.format("%.4f", v.Z or 0) .. "</Z>")
  local tags = { "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" }
  for i = 1, 9 do
    write(level + 1, "<" .. tags[i] .. ">" .. string.format("%.4f", m[i] or 0) .. "</" .. tags[i] .. ">")
  end
  write(level, "</CoordinateFrame>")
end

-- Color3 chega do host como {R=0..1, G=..., B=...}; o Roblox grava inteiro.
local function colorTag(c, level)
  if type(c) ~= "table" or type(c.R) ~= "number" then return end
  local r = math.floor(c.R * 255 + 0.5)
  local g = math.floor((c.G or 0) * 255 + 0.5)
  local b = math.floor((c.B or 0) * 255 + 0.5)
  local packed = r + g * 256 + b * 65536
  write(level, '<Color3uint8 name="Color3uint8">' .. packed .. "</Color3uint8>")
end

local function vec2Tag(name, v, level)
  if type(v) ~= "table" or type(v.X) ~= "number" then return end
  write(level, '<Vector2 name="' .. name .. '">')
  write(level + 1, "<X>" .. string.format("%.0f", v.X) .. "</X>")
  write(level + 1, "<Y>" .. string.format("%.0f", v.Y or 0) .. "</Y>")
  write(level, "</Vector2>")
end

-- UDim2 -> { scale, offset } nos dois eixos, que e como o Roblox grava.
local function udim2Tag(name, v, level)
  if type(v) ~= "table" or type(v.X) ~= "table" then return end
  write(level, '<UDim2 name="' .. name .. '">')
  write(level + 1, "<XS>" .. string.format("%.4f", v.X.Scale or 0) .. "</XS>")
  write(level + 1, "<XO>" .. string.format("%.0f", v.X.Offset or 0) .. "</XO>")
  write(level + 1, "<YS>" .. string.format("%.4f", v.Y.Scale or 0) .. "</YS>")
  write(level + 1, "<YO>" .. string.format("%.0f", v.Y.Offset or 0) .. "</YO>")
  write(level, "</UDim2>")
end

-- Enum -> numero. O .rbxlx grava o valor inteiro do enum, nao o nome.
-- NormalId: Front=5, Back=2, Right=0, Left=1, Top=4, Bottom=3.
local NORMAL_IDS = { Front = 5, Back = 2, Right = 0, Left = 1, Top = 4, Bottom = 3 }
local FONT_NAMES = { Legacy = 0, Arial = 1, SourceSans = 3, FredokaOne = 20, GothamBold = 25 }

local function uidTag(e)
  if e == nil then return 0 end
  local n = e.Name or (e.Value and tostring(e.Value)) or tostring(e)
  if type(n) ~= "string" then return 0 end
  return NORMAL_IDS[n] or FONT_NAMES[n] or 0
end

local function emit(instance, level)
  local class = instance.ClassName
  refs = refs + 1
  write(level, string.format('<Item class="%s" referent="RBX%d">', class, refs))
  write(level + 1, "<Properties>")
  write(level + 2, '<string name="Name">' .. esc(instance.Name) .. "</string>")

  if class == "Part" or class == "SpawnLocation" or class == "WedgePart" then
    vec3Tag("size", instance.Size, level + 2)
    cfTag(
      instance.Position or (instance.CFrame and instance.CFrame.pos),
      instance.CFrame and instance.CFrame.rot,
      level + 2
    )
    colorTag(instance.Color, level + 2)
    if instance.Material and MATERIALS[instance.Material.Name] then
      write(level + 2, '<token name="Material">' .. MATERIALS[instance.Material.Name] .. "</token>")
    end
    if instance.Shape and SHAPES[instance.Shape.Name] then
      write(level + 2, '<token name="Shape">' .. SHAPES[instance.Shape.Name] .. "</token>")
    end
    write(level + 2, '<float name="Transparency">' .. string.format("%.3f", instance.Transparency or 0) .. "</float>")
    write(level + 2, '<bool name="Anchored">' .. tostring(instance.Anchored == true) .. "</bool>")
    write(level + 2, '<bool name="CanCollide">' .. tostring(instance.CanCollide ~= false) .. "</bool>")
    -- TopSurface/BottomSurface nao sao gravados: Smooth(0) ja e o padrao do
    -- Roblox. Eram ~90 bytes x 12 mil itens de informacao redundante.
    if class == "SpawnLocation" then
      write(level + 2, '<bool name="Neutral">' .. tostring(instance.Neutral == true) .. "</bool>")
      write(level + 2, '<int name="Duration">' .. tostring(math.floor(tonumber(instance.Duration) or 0)) .. "</int>")
    end
  elseif class == "PointLight" then
    write(level + 2, '<float name="Brightness">' .. string.format("%.2f", instance.Brightness or 1) .. "</float>")
    write(level + 2, '<float name="Range">' .. string.format("%.1f", instance.Range or 16) .. "</float>")
    colorTag(instance.Color, level + 2)
  elseif class == "ClickDetector" then
    write(level + 2, '<float name="MaxActivationDistance">' .. string.format("%.1f", instance.MaxActivationDistance or 32) .. "</float>")
  elseif class == "BillboardGui" then
    write(level + 2, '<bool name="AlwaysOnTop">' .. tostring(instance.AlwaysOnTop == true) .. "</bool>")
    vec3Tag("StudsOffsetWorldSpace", instance.StudsOffsetWorldSpace, level + 2)
  elseif class == "SurfaceGui" then
    -- Sem Face a SurfaceGui nao sabe em qual lado desenhar e a placa fica
    -- em branco no Studio. Era o caso de TODAS as placas e letreiros.
    write(level + 2, '<token name="Face">' .. uidTag(instance.Face) .. "</token>")
    -- CanvasSize e Vector2, nao UDim2.
    vec2Tag("CanvasSize", instance.CanvasSize, level + 2)
    write(level + 2, '<float name="LightInfluence">'
      .. string.format("%.2f", instance.LightInfluence or 0) .. "</float>")
  elseif class == "TextLabel" or class == "TextButton" then
    write(level + 2, '<string name="Text">' .. esc(instance.Text) .. "</string>")
    write(level + 2, '<bool name="TextScaled">' .. tostring(instance.TextScaled == true) .. "</bool>")
    write(level + 2, '<float name="TextSize">' .. string.format("%.1f", instance.TextSize or 14) .. "</float>")
    colorTag(instance.TextColor3, level + 2)
    -- Posicao/tamanho/fundo/fonte: sem isso todo texto nasce em (0,0) com
    -- 1x1 e fundo branco solido, empilhado no canto da placa.
    udim2Tag("Size", instance.Size, level + 2)
    udim2Tag("Position", instance.Position, level + 2)
    write(level + 2, '<float name="BackgroundTransparency">'
      .. string.format("%.2f", instance.BackgroundTransparency or 0) .. "</float>")
    write(level + 2, '<float name="TextStrokeTransparency">'
      .. string.format("%.2f", instance.TextStrokeTransparency or 0) .. "</float>")
    colorTag(instance.TextStrokeColor3, level + 2)
    -- Fonte: sem isso o Roblox usa Legacy e o texto fica com cara de debug.
    if instance.Font then
      write(level + 2, '<token name="Font">' .. uidTag(instance.Font) .. "</token>")
    end
  end

  write(level + 1, "</Properties>")
  for _, child in ipairs(instance:GetChildren()) do
    emit(child, level + 1)
  end
  write(level, "</Item>")
end

local ok, err = pcall(function()
  local mapRoot = game:GetService("Workspace"):FindFirstChild("EggTycoon")
  assert(mapRoot, "World.build() nao criou o mapa")
  write(0, '<roblox version="4">')
  write(1, "<External>null</External>")
  write(1, "<External>nil</External>")
  emit(mapRoot, 1)
  write(0, "</roblox>")
end)
if not ok then
  error("falha ao serializar o mapa: " .. tostring(err), 0)
end

__xml = table.concat(out, "\n")
`;

const lua = await createLua();
const code = chunk(
	HOST,
	SERVICES,
	sharedModules(["GameConfig", "Format", "Net", "Pets", "Noise", "Biomes", "Terrain", "Style", "Mine"]),
	serverModules(["World"]),
	"__World = World\n__World.build()",
	XML_BUILDER,
);
run(lua, code, "build-map");

const xml = String(lua.globals.get("__xml"));
const OUT = path.join(root, "build", "EggTycoonMap.rbxmx");
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, xml, "utf8");

const items = (xml.match(/<Item /g) || []).length;
const mb = (Buffer.byteLength(xml) / 1024 / 1024).toFixed(1);
console.log(`mapa -> ${path.relative(root, OUT)} · ${items} itens · ${mb} MB`);
