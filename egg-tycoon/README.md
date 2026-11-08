# 🥚 Egg Tycoon — Ilha dos Ovos

Simulador de ovos/pets para Roblox no estilo dos prints: ilha cartoon, ovo no pedestal, toque pra ganhar, pets girando atrás de você dando renda passiva, gema, renascimento.

**Luau + Rojo.** Todo o mapa é construído em código — nada de asset pago, nada de `.rbxm`.

---

## Rodar no Studio

```bash
cd egg-tycoon
npm install
npm run build      # gera build/EggTycoon.rbxlx
```

Abre o `build/EggTycoon.rbxlx` no **Roblox Studio** → **Play** (F5).

Ou live-sync enquanto edita:

```bash
npm run serve      # depois: Plugins → Rojo → Connect no Studio
```

Download direto: [`build/EggTycoon.rbxlx`](./build/EggTycoon.rbxlx)

---

## Controles

| Ação | Como |
| --- | --- |
| Ganhar moeda | botão gigante de seta embaixo, ou clique no mundo |
| Abrir ovo | `E` ou botão 🥚 Ovos, ou clicar no ovo no mapa |
| Pets | `P` ou 🐾 Pets |
| Loja | `B` (moedas) / `G` (gemas) |
| Renascer | `♻️` no toolbar ou portal no mapa |
| Fechar painel | `Esc` |

---

## O que tem no jogo

**6 ovos** com preço crescente e tabela de drop própria:

| Ovo | Custo | Pets |
| --- | --- | --- |
| 🥚 Ovo Inicial | 30 | Pintinho → Filhote Dourado |
| 🟢 Ovo Verde | 600 | Sapinho → Ursinho |
| 🟡 Criação Dourada | 12K | Hamster → Filhote Dourado |
| 🔵 Ovo de Gelo | 250K | Pinguim → Frost |
| 🟣 Ovo Sombrio | 6M | Morcego → Ceifador |
| 🎃 Ovo de Halloween | 25M | evento |
| 🏆 Ovo de 30M Visitas | 150M | Dragão → Voidcat |

- **7 raridades**: Comum → Incomum → Raro → Épico → Lendário → Mítico → **Secreto** (1/500 por ovo, melhorado pela sorte)
- Cada ovo fica **1.18× mais caro** a cada compra e reseta no rebirth. É isso que impede a renda de crescer de graça.
- **Pets** dão moedas/s quando equipados, e ficam girando atrás do personagem no mapa
- **Auto-equipar** pega sempre os melhores pets nos slots disponíveis
- **Auto-venda** descarta o que é pior que o pior equipado — inventário nunca trava
- **Fusão** de 3 pets Raro+ vira um pet melhor
- **Dourado**: 50K moedas pra transformar um pet (×1.5 de renda)
- **Gemas** compram melhorias permanentes (não resetam no rebirth)
- **Rebirth**: reseta moedas/upgrades/ovos comprados, mantém a coleção de pets, dá cristais e +30% de renda por rebirth

---

## Mapa

Tudo em `src/server/World.luau`, ~820 linhas de `Instance.new`:

- ilha de grama com borda de terra e oceano
- praça central de tijolinho + fonte com bichinho dourado no topo
- plataforma de pedra com **6 pedestais de ovo** (ovo = esfera com pintinhas, igual print)
- loja com telhado azul, loja de gemas com gema neon, criação dourada (dois fornos), fusão secreta (tubos rosa), portal de renascimento, loja de Halloween
- árvores, flores, colinas na borda
- placas 3D com `SurfaceGui` em FredokaOne

---

## Estrutura

```
egg-tycoon/
├── default.project.json
├── src/
│   ├── shared/
│   │   ├── GameConfig.luau   # ovos, pets, raridades, upgrades, rebirth, quests
│   │   ├── Pets.luau         # inventário, equipar, fusão, renda
│   │   ├── Net.luau          # contrato de rede
│   │   └── Format.luau       # 1.2K / 3.4M / 1.1B
│   ├── server/
│   │   ├── init.server.luau  # bootstrap + handlers
│   │   ├── World.luau        # mapa inteiro em código
│   │   ├── Game.luau         # tick de renda, ações, rebirth
│   │   ├── PlayerData.luau   # DataStore com retry
│   │   ├── Remotes.luau
│   │   └── Sessions.luau
│   └── client/
│       ├── init.client.luau  # monta UI, liga rede
│       ├── Hud.luau          # renascimentos / moedas +1/s / gemas, barra de quest
│       ├── TapButton.luau    # botão gigante com "+1"
│       ├── EggPanel.luau     # painel de ovos
│       ├── PetsPanel.luau    # inventário/equipar/fusão
│       ├── ShopPanel.luau    # moedas e gemas
│       ├── WorldUI.luau      # ClickDetector → painel, pets flutuando
│       ├── Theme.luau        # visual cartoon (contorno grosso, FredokaOne)
│       ├── Toasts.luau
│       └── State.luau
└── tests/
    ├── check.mjs             # parse de todos os .luau
    ├── run.mjs               # 62 asserts da lógica pura
    ├── boot.mjs              # servidor inteiro em host fake, 10 min de jogo
    └── simulate.mjs          # 8h de progressão
```

---

## Verificação

```bash
npm run check    # parse dos 22 arquivos .luau
npm test         # 62 asserts: drops, preços, slots, fusão, rebirth
npm run boot     # sobe o servidor completo, 2 jogadores, 10 min, testa toda ação
npm run sim      # 8h de progressão simulada
npm run build    # .rbxlx
npm run verify   # tudo acima
```

Curva de rebirth medida (simulando um jogador que toca 3×/s):

| marco | tempo |
| --- | --- |
| Rebirth 1 | 27 min |
| Rebirth 2 | 27 min |
| Rebirth 3 | 30 min |
| Rebirth 4 | 55 min |
| Rebirth 5 | 4h 30 |

### Bugs pegos pelos testes

O jogo tinha 5 defeitos que só apareciam rodando de verdade:

1. `fail()` não retornava nada → toda recusa do servidor virava `nil` silencioso e o handler `equip` dava sucesso falso
2. `require(Shared.Format)` chamado no meio de funções em vez de no topo
3. **Rebirth apagava a coleção de pets** (o comentário dizia que mantinha)
4. Clicar no ovo no mapa só mudava o painel do cliente — o servidor nunca sabia, então sempre abria o ovo padrão
5. Clique na Loja de Halloween apontava pra `eggId = "halloween"` que não existia no config

E 2 de balanceamento:

6. Slots travavam em 9 com a renda congelada por horas → maxTier 6 → 12
7. Custo de rebirth escalava junto com a renda = loop fechado: 6h+ pro primeiro rebirth; com teto fixo = 4 rebirths em 13s. Solução: teto que cresce por rebirth

---

MIT.
