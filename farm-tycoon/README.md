# 🌾 Farm Tycoon

Jogo de fazenda + tycoon para Roblox — **Luau**, projeto **Rojo**, sem assets externos.
Todo o mapa, UI e lógica nascem em código: clona, builda, abre no Studio e roda.

Inspirado em dois projetos que abri como referência:

- [LuciooF/roblox-farming-game](https://github.com/LuciooF/roblox-farming-game) — loop de plantio, crescimento por timer, mutações de colheita, configuração de crops declarativa.
- [Andrew-Kitzan/Tycoon-Sim-Tools](https://github.com/Andrew-Kitzan/Tycoon-Sim-Tools) — curva de progressão de tycoon: upgrades, desbloqueio por nível, rebirth com multiplicador permanente.

Aqui as duas ideias são um jogo só: você **planta → colhe → a esteira vende → dinheiro compra mais terreno, velocidade e sorte → rebirth**.

---

## Jogar agora

### No Studio (30 segundos)

1. `npm install` — instala Rojo + ferramentas de teste (nada além de Node).
2. `npm run build` — gera `build/FarmTycoon.rbxlx`.
3. Abre o arquivo no Roblox Studio e dá **Play**.

### Modo live (edita e vê na hora)

```bash
npm run serve      # sobe o servidor Rojo
```

No Studio: **Plugins → Rojo → Connect** (o plugin Rojo é grátis no Toolbox). Salvar arquivo = mudança na hora.

### Publicar

Studio → **File → Publish to Roblox** → cria o place → **Game Settings → Permissions** pra deixar público.

---

## Controles

| Tecla | Ação |
| --- | --- |
| `M` ou `☰` | abre/fecha o menu |
| `F` | manda a esteira inteira pro caixa agora |
| arrastar `⠿ FARMTYCOON` | move o painel |

---

## O loop

```
semente ($) ──> terra cresce ──> madura => vai SOZINHA pra esteira ──> caixa
                    ▲                                                   │
                    └──────────── replanta sozinho ──────────── cash ($) + XP
```

Sem clique: planta, cresce, colhe e vende no automático. O jogador decide **o que** plantar e **onde gastar**. `F` só adianta a esteira pro caixa.

- **4 terrenos** iniciais, até **12** comprando com cash (cada um exige nível).
- **8 culturas**: Trigo → Cenoura → Tomate → Milho → Morango → Abóbora → Uva → Carambola. Desbloqueiam por nível, cada uma ~2× melhor que a anterior.
- **Mutações** por colheita: Normal, Reluzente (x2), Dourado (x5), Arco-Íris (x25). Sorte aumenta a chance das raras.
- **Esteira** leva o item até o caixa; velocidade é upgrade.
- **Colheita Dupla** (upgrade em 4 tiers): 18% de chance de item extra por tier.
- **Nível 40 + $250K** libera **Rebirth**: reseta cash/nível/upgrades, dá **cristais** e **+50% permanente** no multiplicador.

### Progressão medida (simulação real do servidor)

`npm run boot` sobe o servidor real (init, sessões, economia, compras) num host fake e roda 8 min. `npm run sim` roda `Farm` + `GameConfig` por 6 horas e imprime a curva:

| tempo | nível | terreno |
| --- | --- | --- |
| 2m 18s | 5 | 4 |
| 11m 36s | 10 | 4 |
| 26m 07s | 15 | 4 |
| 47m 24s | 20 | 6 |
| 1h 15m | 25 | 6 |
| 1h 45m | 30 | 6 |
| 2h 23m | 35 | 6 |
| 3h 07m | **40 (rebirth pronto)** | 7 |

Primeiro rebirth em ~3h de jogo ativo, não em 30 segundos.

---

## Estrutura

```
farm-tycoon/
├── default.project.json      # árvore Rojo (Shared → ReplicatedStorage, etc.)
├── src/
│   ├── shared/
│   │   ├── GameConfig.luau   # TODA a balanceagem: crops, custos, rebirth, mutações
│   │   ├── Format.luau       # números (1.2K, 3.4M) e tempo
│   │   └── Net.luau          # nomes de remotes + kinds
│   ├── server/
│   │   ├── init.server.luau  # bootstrap + handlers de ação
│   │   ├── World.luau        # mapa, lotes por jogador, esteira, caixa
│   │   ├── Farm.luau         # estado da fazenda + simulação da esteira
│   │   ├── Economy.luau      # loop 10 Hz, vendas, compras, rebirth, códigos
│   │   ├── PlayerData.luau   # DataStore com retry + fallback em memória
│   │   ├── Remotes.luau
│   │   └── Sessions.luau
│   └── client/
│       ├── init.client.luau  # monta a UI e o loop de render
│       ├── Render.luau       # desenha plots/itens a partir do snapshot
│       ├── Hud.luau          # cash, cristais, nível, XP
│       ├── Panels.luau       # menu tabulado (Sementes/Melhorias/Rebirth/Códigos)
│       ├── Effects.luau      # +$ flutuante, level up, rebirth
│       ├── Toasts.luau
│       ├── Theme.luau        # paleta + fábricas de UI + drag
│       └── State.luau        # snapshot mais recente
└── tests/
    ├── run.mjs               # npm test  — 44 asserts da lógica pura
    ├── boot.mjs              # npm run boot — servidor completo em host fake
    ├── simulate.mjs          # npm run sim  — 6h de progressão
    └── check.mjs             # npm run check — parse de todos os .luau
```

---

## Onde mexer

**Balanceagem:** `src/shared/GameConfig.luau` é o único arquivo. Muda `grow`/`sell`/`seed` de uma crop e o jogo inteiro acompanha (preço, XP, valor na esteira, UI).

**Nova crop:** adiciona uma entrada em `GameConfig.Crops` com `id`, `name`, `emoji`, `grow`, `seed`, `sell`, `amount`, `xp`, `level`, `color`. Aparece na loja, na simulação e na esteira automaticamente — nada mais precisa ser tocado.

**Novo upgrade:** adiciona em `GameConfig.Upgrades` e trata o `kind` em `Economy.buyUpgrade` + `Panels.rowBuilders.upgrades`.

**Códigos:** `GameConfig.Codes`. Pra resgatar no jogo: aba 🎁 Códigos. Os ativos: `FARMSTART`, `TYCOON`, `BLOX`, `REBIRTH`.

---

## Arquitetura

- **Servidor autoritativo.** Cliente nunca calcula dinheiro, XP ou valor de venda — só desenha o snapshot.
- **Snapshot a 10 Hz** (`Remotes.State`). Estado da fazenda (`plots`, `items`, `pending`) vem pronto, então a UI nunca "adivinha".
- **Simulação desacoplada de render.** `Farm:step(dt)` é cinemático e testável fora do Roblox — é o que roda no `npm run sim`.
- **Sem injeção, sem asset pago.** Nenhum `.rbxm`; o mapa é `Instance.new` em `World.buildEnvironment` / `World.buildLot`.
- **Save:** `DataStoreService` com 4 tentativas de retry, autosave a cada 90s e `BindToClose`. Em Studio sem API, cai pra memória e o jogo continua funcionando.
- **Anti-trapaça básico:** todo preço é revalidado no servidor; o cliente só manda intenção (`selectCrop`, `buyPlot`, ...) e o servidor confere nível/cash/cristais.

---

## Comandos

```bash
npm install       # deps (rojo + tooling de teste)
npm run build     # gera build/FarmTycoon.rbxlx
npm run serve     # Rojo live sync pro Studio
npm test          # 38 asserts da lógica pura
npm run sim       # 6h de jogo simuladas + curva de progressão
npm run boot      # sobe o servidor inteiro num host fake, 2 jogadores, 8 min de jogo
npm run check     # parse de todos os .luau
npm run fmt       # stylua
npm run verify    # check + test + boot + sim + build
```

Não rodar `npm run build` com `npm run serve` ativo no mesmo arquivo de saída — Rojo reclama do lock.

---

## Roadmap

- [ ] Gamepasses (auto-colheita permanente, +sorte, slot extra)
- [ ] Terrenos privados com portão e visitante
- [ ] Leaderboard global de rebirth
- [ ] Pets que andam pela base
- [ ] Eventos de clima alterando `growTime`

---

## Créditos

Ideias e estrutura de referência dos dois repositórios citados no topo. Código deste projeto é original, MIT.
