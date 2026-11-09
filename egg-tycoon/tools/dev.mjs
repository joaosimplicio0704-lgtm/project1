#!/usr/bin/env node
/**
 * dev.mjs — o ciclo completo, sem Ctrl+S.
 *
 * Problema que isto resolve:
 *   O mapa do jogo (Workspace/Map) não é arquivo versionado. Ele é GERADO por
 *   tests/build-map.mjs a partir dos módulos Luau. Então editar World.luau e
 *   salvar não mudava nada no Studio: era preciso rodar `npm run build` na mão
 *   e ainda apertar Ctrl+S no Rojo.
 *
 * O que este script faz:
 *   1. gera o mapa uma vez (para o Studio já receber algo válido)
 *   2. sobe o `rojo serve` no 34872
 *   3. observa src/ e tests/ — ao salvar um .luau, regenera o mapa
 *   4. o próprio rojo detecta o mapa novo e reenvia ao Studio
 *
 * Ou seja: salvar o arquivo é o único gesto. Nada de Ctrl+S no plugin.
 *
 * Uso:
 *   npm run dev
 */

import { spawn } from "node:child_process";
import { watch } from "node:fs";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const MAP = path.join(root, "build", "EggTycoonMap.rbxmx");
const WATCH_DIRS = ["src", "tests"].map((d) => path.join(root, d));
const PORT = process.env.PORT ?? "34872";
const USE_ROJO = !process.argv.includes("--no-rojo");

const stamp = () => new Date().toTimeString().slice(0, 8);
const ok = (s) => console.log(s);
const warn = (s) => console.log(s);

let building = false;
let queued = false;
let timer = null;

function build(then) {
  if (building) {
    queued = true;
    return;
  }
  building = true;
  const started = Date.now();
  const child = spawn(process.execPath, [path.join(root, "tests", "build-map.mjs")], {
    cwd: root,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let out = "";
  child.stdout.on("data", (d) => (out += d));
  child.stderr.on("data", (d) => (out += d));

  child.on("close", (code) => {
    building = false;
    const ms = Date.now() - started;
    if (code === 0) {
      const line = out.trim().split("\n").pop() ?? "";
      ok(`[${stamp()}] ${line} (${ms}ms)`);
    } else {
      // Erro de sintaxe no meio da digitação é normal: não derruba o servidor.
      warn(`[${stamp()}] build falhou (${ms}ms)\n${out.split("\n").slice(-14).join("\n")}`);
    }
    then?.(code === 0);
    if (queued) {
      queued = false;
      build();
    }
  });
}

function schedule() {
  clearTimeout(timer);
  // Espera o editor terminar de gravar: sem isso o build lê arquivo pela metade.
  timer = setTimeout(() => build(), 120);
}

function startRojo() {
  const bin = path.join(root, "node_modules", ".bin", process.platform === "win32" ? "rojo.cmd" : "rojo");
  const rojo = spawn(bin, ["serve", "default.project.json", "--port", PORT], {
    cwd: root,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let announced = false;
  const relay = (d) => {
    const text = String(d).trim();
    if (!text) return;
    if (!announced && /listening|serve/i.test(text)) {
      announced = true;
      ok(`[${stamp()}] rojo no ar — no Studio: plugin Rojo > Connect (porta ${PORT})`);
    } else if (!announced) {
      ok(text);
    }
  };
  rojo.stdout.on("data", relay);
  rojo.stderr.on("data", relay);
  rojo.on("close", (code) => warn(`[${stamp()}] rojo encerrou (${code})`));
  return rojo;
}

let rojo = null;

build((good) => {
  if (!good) return warn("mapa inicial falhou; corrigindo o erro o servidor sobe");
  if (USE_ROJO && !rojo) rojo = startRojo();
});

for (const dir of WATCH_DIRS) {
  if (!fs.existsSync(dir)) continue;
  watch(dir, { recursive: true }, (_e, filename) => {
    if (!filename || !/\.(luau|lua)$/.test(filename)) return;
    schedule();
  });
}

ok("observando src/ e tests/ — salve um .luau e o mapa regenera sozinho");
if (USE_ROJO) ok("o rojo reenvia o mapa novo ao Studio; não precisa apertar Ctrl+S");

const stop = () => {
  rojo?.kill();
  process.exit(0);
};
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
