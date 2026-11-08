// simulate.mjs — roda a lógica do servidor fora do Roblox e imprime a curva de progressão.
// Prova que Farm + Economy + GameConfig funcionam juntos. Uso: npm run sim
import { Lua } from "@luau-rs/luau";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");

const HOST = `
-- shims do host Roblox
Color3 = { fromRGB = function(r,g,b) return {r=r,g=g,b=b} end }
Vector3 = { new = function(x,y,z) return {X=x,Y=y,Z=z} end }

local __realRequire = nil

-- remote fake: coleta eventos no lugar de enviar
local fired = {}
local fakeRemote = {
	FireClient = function(self, player, kind, payload)
		fired[#fired + 1] = { kind = kind, payload = payload }
	end,
	FireServer = function() end,
	OnClientEvent = { Connect = function() return { Disconnect = function() end } end },
	OnServerEvent = { Connect = function() return { Disconnect = function() end } end },
}

local fakePlayer = setmetatable({ UserId = 1, Name = "sim", DisplayName = "sim", Parent = "Players" }, {
	__index = function() return nil end,
})

-- injeta as dependencias antes de carregar os modulos
local function stub(name, value) _G[name] = value end
`;

const wrap = (name, source) => `local ${name} = (function()\n${source}\nend)()\n`;

// O servidor real usa game:GetService; aqui trocamos por uma tabela estatica
// e injetamos Sessions/PlayerData/World/Remotes fake nos modulos.
const script = [
	HOST,
	wrap("GameConfig", read("src/shared/GameConfig.luau")),
	wrap("Format", read("src/shared/Format.luau")),
	wrap(
		"Farm",
		read("src/server/Farm.luau")
			.replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")', "")
			.replace("local GameConfig = require(ReplicatedStorage.Shared.GameConfig)", ""),
	),
	read("tests/sim.luau"),
].join("\n");

const lua = await Lua.create({ sandbox: true });
lua.globals.set(
	"hostprint",
	lua.createFunction((...args) => console.log(args.map((a) => (a === undefined ? "nil" : String(a))).join("\t"))),
);

try {
	lua.execute(script);
} catch (e) {
	console.error("\n" + String((e && e.message) || e).split("\n").slice(0, 10).join("\n"));
	process.exit(1);
}
