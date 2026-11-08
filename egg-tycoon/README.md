# 🥚 Egg Tycoon — 7 Mundos

Simulador de ovos/pets para Roblox: hub central com portais, **7 biomas 3D** com
relevo procedural próprio, ovo no pedestal de cada mundo, pets girando atrás de
você e renascimento.

**Luau + Rojo.** O mapa inteiro é construído em código — nada de asset pago.

---

## Baixar e jogar (o jeito rápido)

1. Baixe **[`build/EggTycoon.rbxlx`](./build/EggTycoon.rbxlx)** (clique em *Download*)
2. Abra o arquivo no **Roblox Studio**
3. Aperte **Play** (F5)

O arquivo já vem com o **mundo construído dentro**: 7.000 partes, os 7 biomas,
os portais, os ovos nos pedestais e todos os scripts. Não precisa instalar nada.
Não precisa apertar Play para "gerar" o mapa — ele já está lá, visível no editor.

---

## Os 7 mundos

Cada bioma é uma ilha com paleta, relevo e ovo próprios. Todos ficam ligados ao
hub por portais, e cada um tem sua regra de desbloqueio:

| Mundo | Ovo | Desbloqueia com | Relevo |
| --- | --- | --- | --- |
| 🌷 Vale Verdejante | 🥚 Ovo Inicial (30) | livre | colinas suaves |
| 🌲 Floresta Densa | 🟢 Ovo Verde (600) | chocar 3 ovos | encosta alta, pinheiros |
| 🏜️ Deserto Dourado | 🟡 Criação Dourada (12K) | renascimento 1 | dunas e obeliscos |
| ❄️ Picos Congelados | 🔵 Ovo de Gelo (250K) | renascimento 2 | montanhas nevadas (até 45 studs) |
| 🌑 Vale Sombrio | 🟣 Ovo Sombrio (6M) | renascimento 3 | picos escuros, cristais |
| 🎃 Ilha Abóbora | 🎃 Ovo de Halloween (25M) | renascimento 4 | abóboras gigantes |
| 🌌 Nebulosa Cósmica | 🏆 Ovo de 30M Visitas (150M) | renascimento 5 | ilha flutuante a 300 studs |

As ilhas ficam a **520 studs** do centro e a **276 studs** umas das outras — dá para
ver a próxima do outro lado da água, sem parecer que estão coladas.

### Cada ilha tem a própria cara

Cada bioma tem um **marco gigante** feito de peças — dá para reconhecer de longe:

| Ilha | Marco | Enfeites só dela |
| --- | --- | --- |
| Vale Verdejante | Árvore Mãe com balanço | cerejeiras cor-de-rosa, bancos |
| Floresta Densa | Cogumelo gigante brilhante | cogumelos neon, troncos caídos |
| Deserto Dourado | Pirâmide com sol dourado | cactos, ossadas |
| Picos Congelados | Cristal de gelo + nuvens | bonecos de neve, pinheiros |
| Vale Sombrio | Obelisco com runas | lápides tortas, lanternas de alma |
| Ilha Abóbora | Abóbora gigante com cara | abóboras pequenas, velas fantasma |
| Nebulosa Cósmica | Planeta com anel de Saturno | asteroides, estrelas caídas |

### Iluminação

- **Ambiente global** claro (ambiente 150/164/186, sombra suave, névoa a partir de 700) — o mapa parece desenho, não sombra preta
- **Luz própria por bioma**: cada ilha tem uma luz central grande + 8 postes coloridos. A Floresta é verde, o Deserto é dourado, o Sombrio é roxo, o Cosmos é violeta
- **126 fontes de luz** no arquivo, todas com cor e alcance definidos
- O `Lighting` já vem configurado **no arquivo**: abrir no editor mostra o mesmo que o Play

### O hub

Praça com fonte, 5 lojas, portal de renascimento, **estátua do ovo gigante** na
entrada (girando), **bandeirinhas** cruzando a praça, **balões** em 6 grupos,
dois anéis de postes de luz, e os **7 portais** — cada um com uma miniatura do
marco do destino flutuando em cima, para a criança ver onde vai entrar.

**O bloqueio é do servidor.** `Game.handlers.travel` confere o desbloqueio com os
dados da sessão antes de autorizar. O painel só mostra o cadeado; clicar não
abre nada se faltar requisito.

---

## Controles

| Ação | Como |
| --- | --- |
| Ganhar moeda | botão gigante embaixo, ou clique no mundo |
| Abrir ovo | `E`, botão 🥚 Ovos, ou clicar no ovo do bioma |
| Pets | `P` ou 🐾 Pets |
| **Mundos** | **`M`** ou clicar num portal |
| Loja | `B` (moedas) / `G` (gemas) |
| Renascer | `♻️` na barra ou portal no mapa |
| Fechar painel | `Esc` |

---

## O que tem no jogo

- **7 ovos**, cada um no seu bioma, com tabela de drop própria e preço crescente
- **7 raridades**: Comum → Incomum → Raro → Épico → Lendário → Mítico → **Secreto** (1/500 por ovo, melhorado pela sorte)
- Cada ovo fica **1.18× mais caro** a cada compra e reseta no rebirth
- **Pets** dão moedas/s e ficam girando atrás do personagem
- **Auto-equipar** pega os melhores pets nos slots livres
- **Auto-venda** descarta o que é pior que o pior equipado — inventário nunca trava
- **Fusão** de 3 pets Raro+ vira um pet melhor
- **Dourado**: 50K moedas transformam um pet (×1.5 de renda)
- **Gemas** compram melhorias permanentes (não resetam no rebirth)
- **Rebirth**: reseta moedas/upgrades, mantém a coleção, dá cristais e +30% de renda

---

## Como o mapa é gerado

Três peças, todas em código puro e determinístico (mesma seed = mesmo mundo):

- **`src/shared/Noise.luau`** — ruído de valor + fBm + *ridged*, sem `Random`
- **`src/shared/Terrain.luau`** — transforma o ruído numa grade de células
  cúbicas: platô plano no miolo (para o ovo e o spawn), encosta com relevo e
  praia caindo na borda
- **`src/shared/Biomes.luau`** — a tabela dos 7 mundos: paleta, altura, ovo e
  regra de desbloqueio. **Cliente e servidor leem a mesma tabela** — o painel de
  mundos não tem uma cópia dos dados

`src/server/World.luau` monta tudo no `Workspace`: oceano, praça, lojas, portais,
e para cada bioma a base rochosa, a praia, o terreno em grade, a decoração
apoiada na altura real do chão, o pedestal do ovo e o portal de volta.

---

## Rodar no Studio a partir do código

```bash
cd egg-tycoon
npm install
npm run build      # gera build/EggTycoon.rbxlx com o mapa dentro
```

Ou live-sync enquanto edita:

```bash
npm run serve      # depois: Plugins → Rojo → Connect no Studio
```

### Como o build funciona

O mapa é construído em Lua (no host de teste), serializado para
`build/EggTycoonMap.rbxmx` e então o **Rojo** monta o `.rbxlx` final juntando o
mapa com os scripts. O Rojo é o parser oficial: se o XML estiver errado, o build
falha em vez de gerar um lugar quebrado.

---

## Estrutura

```
egg-tycoon/
├── default.project.json     # Workspace + mapa + serviços + scripts
├── build/EggTycoon.rbxlx    # O JOGO (committed: é o que você baixa)
├── src/
│   ├── shared/
│   │   ├── Biomes.luau      # os 7 mundos, desbloqueio, geometria
│   │   ├── Terrain.luau     # relevo em grade por bioma
│   │   ├── Noise.luau       # ruído determinístico
│   │   ├── GameConfig.luau  # ovos, pets, raridades, upgrades, rebirth
│   │   ├── Pets.luau        # inventário, equipar, fusão, renda
│   │   ├── Net.luau         # contrato de rede
│   │   └── Format.luau      # 1.2K / 3.4M / 1.1B
│   ├── server/
│   │   ├── init.server.luau # bootstrap + clique dos portais
│   │   ├── World.luau       # hub + 7 biomas em código
│   │   ├── Game.luau        # renda, ações, rebirth, viagem
│   │   ├── PlayerData.luau  # DataStore com retry
│   │   ├── Remotes.luau
│   │   └── Sessions.luau
│   └── client/
│       ├── init.client.luau # monta a UI, liga a rede
│       ├── BiomesPanel.luau # mapa-múndi (tecla M)
│       ├── Hud.luau
│       ├── TapButton.luau
│       ├── EggPanel.luau
│       ├── PetsPanel.luau
│       ├── ShopPanel.luau
│       ├── WorldUI.luau     # ClickDetector → painel, pets flutuando
│       ├── Theme.luau
│       ├── Toasts.luau
│       └── State.luau
└── tests/
    ├── host.luau            # Roblox falso (Instances, Vector3, CFrame…)
    ├── harness.mjs          # carrega host + módulos
    ├── check.mjs            # parse de todos os .luau
    ├── run.mjs + spec.luau  # 77 asserts de lógica pura
    ├── boot.mjs             # servidor inteiro, 2 jogadores, 10 min
    ├── client.mjs           # instancia a UI, confere os painéis
    ├── world.mjs            # constrói o mapa e valida a geometria
    ├── build-map.mjs        # Lua → .rbxmx
    ├── mapfile.mjs          # valida o .rbxlx final
    └── simulate.mjs         # 8h de progressão
```

---

## Verificação

```bash
npm run verify
```

Roda, em ordem:

| comando | o que faz |
| --- | --- |
| `npm run check` | parse dos 27 arquivos `.luau` |
| `npm test` | 77 asserts: drops, preços, slots, fusão, rebirth, biomas |
| `npm run boot` | servidor completo, 2 jogadores, 10 min, testa viagem entre mundos |
| `npm run client` | instancia a UI inteira; confere os 7 cartões de mundo |
| `npm run world` | constrói o mapa: 7.065 partes, 7 biomas, nada enterrado |
| `npm run sim` | 8h de um bot jogando |
| `npm run build` | gera o `.rbxlx` final |
| `npm run mapfile` | lê o arquivo gerado: partes, biomas, ovos, spawn |

O `mapfile` é o teste mais importante para quem baixa o jogo: ele abre o
`.rbxlx` de verdade e falha se faltar `SpawnLocation`, se algum bioma não
existir, ou se houver parte de tamanho zero.

Curva de rebirth medida (jogador tocando 3×/s):

| marco | tempo |
| --- | --- |
| Rebirth 1 | 27 min |
| Rebirth 2 | 27 min |
| Rebirth 3 | 30 min |
| Rebirth 4 | 55 min |
| Rebirth 5 | 4h 30 |

---

## Bugs pegos pelos testes

Nenhum dava erro de sintaxe — todos passavam no `stylua` e no build:

1. `fail()` não retornava nada → toda recusa do servidor virava `nil` silencioso
2. **Rebirth apagava a coleção de pets** (o comentário dizia que mantinha)
3. Clicar no ovo no mapa só mudava o painel — o servidor nunca sabia
4. **Clicar em qualquer placa não abria nada**: o `WorldUI` roteava o próprio
   `ClickDetector` (nome `"ClickDetector"`) em vez da placa
5. Nenhum `SpawnLocation` — o jogador nascia no ponto padrão, longe de tudo
6. Slots travavam em 9 com a renda congelada por horas
7. Custo de rebirth escalava junto com a renda = loop fechado

E os que apareceram ao construir os mundos:

8. **`terrain` com o miolo mais alto que a borda** — o ruído fazia uma colina
   exatamente onde o ovo e o spawn precisam de chão plano. O pedestal nascia
   enterrado. Corrigido com um platô real e altura lida da célula central.
9. **`decorateBiome` somava `Model + Vector3`** — `home` era o Model do bioma,
   não um ponto. O build do mundo inteiro morria em `attempt to perform
   arithmetic on nil`.
10. **Serializar o mapa como JSON** — o `string.format("%q")` do Luau não é JSON
    válido; 138 KB de tabela viravam lixo e o erro real ficava escondido atrás
    de um dump gigante. Agora o XML é montado no próprio Lua.
11. **`Color3uint8` é um inteiro**, não `R G B` separados: errar isso fazia o
    Rojo recusar o arquivo.
12. **Ilhas a 68 studs uma da outra** — pareciam coladas. Agora 276.
13. **Terreno com célula fixa de 14.95** — quando as ilhas cresceram, sobrava um
    anel de ilha sem chão nenhum. Agora o tamanho da célula vem do raio.
14. **`FogStart` só existia no script**, não no `.rbxlx`: o editor ficava sem
    névoa. Configuração de atmosfera agora vive no `project.json`.
15. **Estátua do hub em cima do spawn** — o jogador nascia dentro da pedra.

---

MIT.
