# roblox-external

Reescrita do base `misery1x/Roblox-External` com o dump de offsets
`version-f0ea5da9412f4e35`, `StealthyOpenProcess` v5 no lugar do `OpenProcess` cru,
**detector de jogo**, **aim assist configurável**, **leitor de memória automático**,
**disciplina de tiro** e **voo**.

Externo, read-only: `ReadProcessMemory` + `SendInput` + overlay D3D11/ImGui.
Nada é escrito em memória do jogo, nada é injetado, nenhum driver.

```
processo   RobloxPlayerBeta.exe
handle     StealthyOpenProcess (HWBP + VEH) — fallback OpenProcess
leitura    ReadProcessMemory em THREAD PROPRIA, snapshot imutavel por quadro
input      SendInput / INPUT_MOUSE / MOUSEEVENTF_MOVE (relativo)
render     D3D11 swapchain + ImGui, janela layered topmost
toolchain  MSVC v143 (C++20) ou zig/clang cross-compile
```

### Arquitetura

```
thread de leitura  ->  ReadProcessMemory + caches  ->  SceneSnapshot (imutavel)
                                                          |
render (60+fps)  -----------------------------------------+-- ESP, aim, trigger, menu
```

O render nunca chama `ReadProcessMemory`. Ele lê o último `shared_ptr<const SceneSnapshot>`
publicado. Antes disso o loop de memória rodava no frame e cada leitura segurava o
menu — era a causa real do "clique meio travado".

Caches por endereço no leitor (todos limpos quando o DataModel muda):

| cache | TTL | o que evita |
|---|---|---|
| filhos de instância | 500ms | reler o `std::vector` de children toda hora |
| nome de instância | 3s | string read por child por frame |
| classe de instância | 3s | 2 RPM por child por frame |
| partes do personagem (`HumanoidRootPart`/`Head`/`Humanoid`) | 2s | varrer o modelo inteiro por player por frame |

`Memory` é serializado por mutex: leitor e voo podem usar o mesmo handle sem
`CloseHandle` no meio de um `ReadProcessMemory`.

## Build

```bat
:: x64 Native Tools Command Prompt
build.bat
```

```sh
# linux/mac cross-compile
pip install ziglang
ZIG="python3 -m ziglang" ./build.sh
```

Saída: `build/RobloxExternal.exe`. Binário pronto em `dist/RobloxExternal.exe`
(x86-64, PE32+, console, estático — sem dependência de runtime do mingw).

## Uso

```
INSERT   abre/fecha o menu e devolve o mouse pro jogo
F1       ESP on/off
F2       caixa on/off
F5       salva config.json + profiles.json
F9       carrega config.json + profiles.json
F10      PANIC: desliga aim/tiro/voo, solta o mouse (salva sozinho depois)
END      sai
Mouse 5  aim assist (segurar; rebindável na aba Aim)
```

Sete abas: **ESP**, **Aim**, **Tiros**, **Voo**, **Jogo**, **Memória**, **Config**.
`config.json` e `profiles.json` ficam ao lado do `.exe`.

### Bind de tecla (aim / tiro / voo)

Cada módulo tem um botão de bind. Clica, aperta **qualquer** tecla ou botão do mouse
e o valor é gravado na hora (`cfg::Save`), com o nome legível (`Mouse 4`, `Space`,
`F7`, `Num 3`, `Esquerda`, `;`…). `ESC` cancela, o `x` ao lado limpa o bind
(`Nenhuma` = módulo não responde a tecla; no tiro ainda existe o modo automático).

Regras da captura, em `menu.cpp`:

| Detalhe | Por quê |
| --- | --- |
| varredura `0x08..0xFF` e só depois `0x01..0x06` | o laço antigo dava `break` no `VK_ESCAPE` (0x1B) e só enxergava VK 0x01..0x1A — na prática, só os botões do mouse. Espaço, letras, números, F1..F12 e setas nunca eram capturadas |
| teclado tem prioridade sobre o mouse | apertar uma tecla junto com um clique não pode virar `Mouse 1` |
| `PrimeKeys()` no clique do botão | a transição que abriu o bind não vira a tecla escolhida |
| aviso em laranja para INSERT/F1/F2/END/F5/F9 | são atalhos globais: a mesma tecla faria as duas coisas |
| bind limpo ao fechar o menu | não fica armado esperando tecla com o menu escondido |

### Input do menu

- DPI awareness **per-monitor v2** ligado antes de criar a janela — sem isso o Windows
  virtualiza as coordenadas e o clique cai alguns pixels fora do widget.
- A janela só vira clicável (sem `WS_EX_TRANSPARENT`) com o menu aberto; ao fechar,
  o foco volta pro processo do jogo.
- `WM_MOUSEACTIVATE` responde `MA_ACTIVATE` — sem isso o primeiro clique só serve
  pra dar foco e o widget não seleciona.
- Nenhuma cor do tema é preto puro: com color-key, pixel preto é buraco de hit-test
  e o clique vazaria pro jogo.
- Menu aberto roda sem vsync com `Sleep(1)`; fechado usa `Present(1,0)` + tick.
- `Config → Input (diagnostico)` mostra cursor do OS vs cursor do ImGui e o DPI —
  se os dois divergirem, o número aparece em laranja.

## Jogos que "não deixam" e jogos que bloqueiam

Três queixas reais, três causas diferentes:

| sintoma | causa | correção |
|---|---|---|
| "não injeta" / não anexa | alguns jogos negam `PROCESS_VM_WRITE` (o anti-cheat derruba o handle de escrita) — e aí o anexo inteiro falhava | se o handle completo falhar, cai pra **leitura** (`VM_READ` + `QUERY_INFORMATION`): ESP/aim seguem, voo/magnet/câmera ficam desabilitados e a aba mostra `read-only`. Tudo logado |
| "não detecta o inimigo" | rig customizado sem `HumanoidRootPart`, `StreamingEnabled` (personagem ainda não carregou), partes renomeadas, `Head` ausente | fallbacks: `Model::PrimaryPart` → `Humanoid::HumanoidRootPart` → `Torso/UpperTorso`; personagem procurado no `Workspace` pelo nome do jogador; sem `Head`, a caixa usa o root deslocado; nome `?` não descarta mais o alvo. Se continuar 0 alvos, o **log** diz o motivo (sem personagem / sem parts / time / morto / longe) |
| voo "bloqueado" em alguns jogos | o motor ou o servidor reverte a posição escrita no mesmo tick | **modo Ancorar**: liga o bit `Anchored` (`Primitive::Flags 0x1BE`) enquanto voa e desliga sozinho ao soltar. Além disso o módulo detecta a reversão (drift > 25 studs por 700 ms) e avisa na aba |

## Testes offline

Parte do projeto é matemática pura e roda sem Windows, sem cliente e sem processo:

```
./tests/run.sh          # g++ -std=c++20, 47 checagens
== testes offline roblox-external ==
[1] WorldToScreen
[2] radianos por pixel
[3] laco do aim
[4] voo
[5] config.json
== 47 checagens, 0 falha(s) ==
```

O que é provado: projeção (centro, fora da tela, atrás da câmera, offset `tan(fov)`),
a escala angular por pixel nos dois eixos, convergência do laço do aim com e sem
calibração, integração do voo + clamp de `dt`, e round-trip do `config.json`
(inclusive string com vírgula).

Duas coisas que **o teste pegou** e que estavam erradas no build anterior:

| bug | correção |
|---|---|
| `rad/px` usava a aproximação linear `fov/altura` | a projeção é tangente: `2*tan(fov/2)/altura`. Em 70° a conta antiga errava **15%** — a mira puxava menos do que devia |
| com a conversão calibrada, o ganho default (`força 0.55 / suavização 6`) ficou 3x mais lento que antes | `suavização` default 4 e `Mira exata` 18 px: converge em ~12 ticks em vez de ~50 |

## Confiabilidade

| coisa | como funciona |
|---|---|
| log | `roblox-external.log` ao lado do `.exe`, com timestamp: attach (base, tamanho, VM_WRITE ou read-only), reattach, handle de escrita devolvido, write recusado, panic, save. Rotação em 4 MB |
| auto-save | qualquer mudança no menu vira `config.json` **800 ms** depois da última mexida (F5/F9 continuam existindo) |
| panic (F10) | desliga aim/tiro/voo, solta o botão esquerdo se o trigger estiver pressionado e devolve o mouse |
| handle de escrita | só existe enquanto o voo está ligado; ao desligar, volta pro read-only (menos exposição) |
| write verificado | o voo checa o retorno de `WriteProcessMemory` e a aba mostra `write ok` / `RECUSADO` em vez de falhar calado |

## Câmera (freecam, mira por câmera, FOV, FPS)

A câmera do Roblox é **100% local** — o servidor nunca a vê. Enquanto o jogo está com
`CameraType = Scriptable` (6), o módulo de câmera dele para de reescrever a CFrame e o
que a gente escreve **fica**. É o pacote mais agressivo que dá pra fazer sem posição
replicada, e por isso o de menor risco.

| feature | o que faz | offset |
|---|---|---|
| **freecam** | câmera desacoplada: tecla solta, `WASD` move, **setas olham**, `Space/Ctrl` sobem/descem. Atravessa parede, enxerga o mapa todo, combina com o ESP de objetos | `Camera::CameraType 0x120`, `Position 0xE4`, `Rotation 0xC0` |
| **mira por câmera** | escreve a rotação exata apontando pro osso no frame do disparo: sem `SendInput`, sem sensibilidade, sem mouse lock. Instantâneo e determinístico | `Camera::Rotation 0xC0` |
| **FOV hack** | 70 → 110 pra ver tudo, ou 25 pra virar luneta | `Camera::FieldOfView 0x128` |
| **FPS unlock** | tira o teto de 60 (com trava: se o campo não for um float plausível, não escreve) | `TaskScheduler::MaxFPS 0xB0` |

Ao desligar (ou no **F10**) tudo volta: `CameraType`, FOV e MaxFPS originais. A câmera
se descola, então o personagem continua onde estava — nada de posição indo pro servidor.

## Puxar item (magnet)

Reusa a varredura do ESP de objetos: os marcadores já vêm com nome, posição e o endereço
do `Primitive`. Aí é só escrever `Primitive::Position` do item pra perto de você.

- **Puxar pra mim** — contínuo, `Itens/s` limita os writes (10/s por default), pega o item
  mais perto primeiro, para a `Distancia final` studs de você.
- **puxar agora** — um empurrão único, sem deixar ligado.
- **ir até o item** — alternativa garantida: em vez de mover o item, move **você** até ele
  (`Primitive::Position` do seu HumanoidRootPart, que o cliente sempre manda).

Funciona em item **desancorado** (loot largado no chão é o caso normal). Item `Anchored`
ou com network ownership do servidor volta pro lugar — a aba conta `puxados / recusados`
em vez de fingir que funcionou.

## Mira na tela e objetos

- **Mira no centro** (opt-in): no jogo o cursor do sistema fica escondido, então sem isso
  não há referência de onde o tiro sai. Cruz + ponto, tamanho ajustável.
- **Destaque do alvo**: a caixa do alvo que o aim está puxando ganha cor própria, traço
  mais grosso e cantos marcados — dá para ver na hora o que a mira escolheu.
- **ESP de objetos por nome** (opt-in): varre o `Workspace` 4x por segundo procurando
  `Part`/`MeshPart` cujo nome bata com o filtro (`coin,cash,crate,ammo,key,loot,…`,
  editável, case-insensitive por trecho) e desenha ponto + `nome 12m`.
  **Não usa offset de jogo**: funciona em qualquer place que nomeie o loot. Custos:
  máximo 1500 instâncias olhadas e 48 marcadores por varredura, nomes/classe com cache.

## Aim assist — e por que o tiro sai na direção do inimigo

Num jogo em primeira/terceira pessoa o projétil sai **da câmera, pelo centro da tela**.
Externo não muda a direção da bala (isso é raycast do servidor); o que dá pra fazer é
**colocar a câmera exatamente em cima do osso no frame do disparo**. É o que este módulo
faz, em três partes:

1. **leitura** — posição do osso (`Head` / peito / `HumanoidRootPart`) projetada com a
   view matrix; erro medido em pixels até o centro da tela;
2. **movimento** — `SendInput(MOUSEEVENTF_MOVE)` relativo. Nada de escrever view angle
   ou estado do player: a câmera gira, a projeção é recalculada, o erro converge;
3. **calibração automática** — lê a matriz da câmera antes e depois de cada `SendInput`
   e mede **quantos radianos a câmera gira por count de mouse**. Com isso o erro em
   pixels vira counts de verdade:

```
rad_por_px  = FOV_vertical_em_rad / altura_da_tela
counts_por_px = rad_por_px / rad_por_count     // medido, não chutado
passo_counts  = erro_px * ganho * counts_por_px + resto_fracionário
```

Sem essa conta, "1 px = 1 count" é chute: se a sensibilidade do jogo gira 3 px por count,
a mira pulava 3x o necessário e oscilava em volta do alvo em vez de encostar nele.

| knob | o que faz |
|---|---|
| `Força` (0.05–1.00) | quanto a mira puxa longe do alvo: fração do erro aplicada por tick |
| `Suavização` (1–20) | divisor do passo. maior = mais lento e mais discreto |
| `Mira exata (px)` | **dentro desse raio a correção é quase total** (0.7 quando calibrado), então o crosshair encosta no osso em 1–2 ticks em vez de gastar 10 |
| `Passo max (px)` | teto de movimento por tick longe do alvo, evita flick |
| `Zona morta (px)` | para de mexer quando já está em cima |
| `Jitter (px)` | ruído no delta |
| `Antecipação (ms)` | projeta o alvo pela velocidade dele (`AssemblyLinearVelocity`) — lead de alvo em movimento |
| `FOV (raio px)` | círculo do alcance, desenhado na tela |
| `Osso` | cabeça / peito / raiz |
| `Tecla` | botão `Bind` captura qualquer tecla; modo segurar ou toggle |
| `Só com o jogo em foco` | compara o PID do `GetForegroundWindow()` — não rouba o mouse fora do jogo |

A aba mostra `calibrado: X.XX counts por pixel` (ou `calibrando...` até colher duas
amostras) e o botão **`Recalibrar mira`** zera a medição.

Alvo é **travado** enquanto você segura a tecla: se outro inimigo passar mais perto do
crosshair no meio da puxada, o aim continua no mesmo. Solta a tecla (ou sai do FOV) e
destrava. Menu aberto = o aim não envia nada.

O que continua impossível sem injeção (e este projeto não injeta): **silent aim**
(bala ignorando a câmera), **wallcheck** (precisa de raycast) e mexer no espalhamento.

## Disciplina de tiro

Espalhamento de bala em Roblox mora no jogo — raycast em Lua ou no servidor. Externo
não mexe nisso sem escrever memória ou hookar o VM. O que dá pra fazer de verdade:

- **portão**: só solta o clique com o crosshair dentro de `Erro max (px)` do osso.
  Tiro sai centrado em vez de sair torto.
- **cadência**: `Intervalo (ms)` limita tiros por segundo — não empilha recoil nem
  transforma hold em spray.
- **rajada**: N tiros por aperto, espaçados pelo intervalo.
- **auto**: dispara sozinho enquanto o portão estiver aberto (sem tecla).

Aba **Tiros** mostra o erro do alvo em px e a contagem de tiros em tempo real, e a
tecla é rebindável igual à do aim. Menu aberto ou jogo fora de foco = não atira.

## Leitor de memória

Três camadas, da mais automática pra mais manual.

### ESP — o que desenha

| opção | nota |
|---|---|
| caixa, nome, barra de vida, distância | base, custo zero extra |
| esqueleto | R15 por nome de parte com fallback R6; **custa 15 leituras por alvo**, por isso é opt-in |
| traçador | linha do centro da tela até o alvo |
| ponto na cabeça | marcador de 3px no osso da cabeça |

### Ao vivo (automático)

Abre a aba e já está tudo lá — nenhum endereço, nenhum comando. O `Esp` resolve a
cadeia do jogador a cada tick e publica em `LocalState`:

```
DataModel, Workspace, Camera, LocalPlayer, Character, Humanoid, RootPart, Primitive
Health, WalkSpeed, JumpPower
Position, Velocity, Camera pos, Camera forward, FOV
```

Se o processo não estiver aberto, mostra "procurando"; se o personagem ainda não
carregou, mostra isso. Reattach é automático.

### Varredura de valor

Acha endereço a partir de um valor: escolhe o tipo (`i32`, `float`, `i64`), digita o
número, **Novo scan** varre o range do módulo (regiões commitadas, respeitando
`PAGE_GUARD`/`PAGE_NOACCESS`), **Filtrar** refina com o valor novo. Teto de 1000
resultados. Cada linha tem `watch` (vira watch ao vivo) e `dump`.

Scan roda na thread de render — num módulo grande pode dar um engasgo de ~1s no
frame em que você clica. É o único trabalho pesado síncrono do projeto.

### Manual

Expressão:

```
base+0x8EB6960          offset do módulo
base+0x8EB6960>0x1F8    cadeia de ponteiro, quantos '>' quiser
0x7FF6A0001234          absoluto
```

Watch tipado (`u8 i32 u32 i64 float double ptr string`), relido a 60Hz, verde quando
muda. Hexdump de 16/32 linhas com **byte alterado em verde** e coluna ascii.

Watches vivem só na sessão — endereço cru envelhece rápido.

## Voo

**Único módulo que escreve em memória.** Não existe voo read-only: voar é mudar a
posição do personagem. `WriteProcessMemory` no `Primitive::Position` do
`HumanoidRootPart` a cada tick, com `AssemblyLinearVelocity`/`AngularVelocity` zeradas
pra gravidade não brigar. O cliente tem network ownership do próprio personagem, então a
posição escrita é aceita na maioria dos jogos — o servidor reconcilia e geralmente deixa.

- `WASD` move no plano da câmera (usa `Camera::Rotation`, look = `-coluna 3`)
- `Space` / `Ctrl` sobem e descem
- `Velocidade` em studs/s, `Zerar velocidade`, `Paira parado`, toggle ou segurar
- ligar o voo reabre o handle com `VM_WRITE | VM_OPERATION`; sem isso o handle é
  estritamente read-only e a aba mostra `read-only (reatacha ao ligar)`

### O que fazia o voo ficar "bugado"

| sintoma | causa na versão anterior | correção |
|---|---|---|
| cair quando você soltava o WASD | o `Tick` só escrevia com direção != 0 — sem tecla, **nada era escrito** e a gravidade agia | `Paira parado`: sem direção zera a velocidade todo tick e mantém a altura |
| andar menos que o slider / tremer | o passo era somado na posição **do snapshot**, que chega 1–2 ticks atrasado: cada tick reaplicava em cima de um valor velho | posição própria (`m_pos`), integrada por `dt` e escrita; o snapshot só é usado pra resync |
| teleporte de 300 studs ao destravar o menu | `dt` sem teto depois de um stall | `dt` limitado a 50 ms |
| continuar planando depois de soltar a tecla | o release não zerava a velocidade | `Stop()` zera `AssemblyLinearVelocity` uma vez |
| brigar com respawn/knockback | mantinha a posição antiga e insistia | resync quando troca de personagem, morre (`Health <= 0`) ou a divergência passa de 40 studs |
| girar feito pião | só a velocidade linear era zerada | `AssemblyAngularVelocity` também |

```cpp
// run in a VM — Handle com VM_WRITE em processo protegido por Hyperion é ban/ crash
```

## Detector de jogo

Lê a identidade do DataModel a cada 1s (e na hora quando o DataModel muda):

```
PlaceId       DataModel+0x180
GameId        DataModel+0x178
CreatorId     DataModel+0x170
PlaceVersion  DataModel+0x19C
JobId         DataModel+0x108  (std::string)
```

Aba **Jogo** mostra tudo, contagem de players, e mantém **perfis por PlaceId**:
`Salvar config atual neste PlaceId` grava FOV/força/suavização/osso do jogo atual
em `profiles.json`; ao entrar num lugar com perfil salvo, o aim ajusta sozinho e
loga no console (`[jogo] place 1234 — perfil aplicado`).

## Estrutura

```
src/
  main.cpp              loop, hotkeys, ciclo de vida, auto-perfil
  config.h/.cpp         knobs + config.json + profiles.json
  offsets.h             dump inteiro em namespace rbx
  sdk/memory.*          handle, leitura validada, base do módulo
  sdk/sdk.h             Vector2/3, Matrix4x4, WorldToScreen
  stealth/StealthyOpenProcess.*   HWBP + VEH (v5)
  stealth/handle_cleanup.*        sweeper de handles de thread órfãos
  stealth/xorstr.h                shim do XorStr.hpp que faltava
  features/esp.*        ActorLoop — leitura da cena + draw
  features/aim.*        seleção de alvo + SendInput
  features/detector.*   PlaceId/GameId/JobId + perfil por jogo
  features/memview.*    automático + varredura de valor + watches + hexdump
  features/fly.*        voo (único módulo com VM_WRITE)
  features/trigger.*    portão de erro + cadência + rajada
  menu/menu.*           menu tabbed
  overlay/overlay.*     janela + D3D11 + ImGui
  imgui/                v1.92.1-WIP vendorizado (upstream, verificado)
```

## Atualizar offsets

Tudo em `src/offsets.h`, dentro de `namespace rbx`. Cola o dump novo por cima, recompila.
Único offset cru fora do arquivo: fallback de nome em `features/esp.cpp`
(`Instance + 0x90`, layout antigo, só usado se o caminho novo falhar).

## Diff contra o original

| original | aqui |
|---|---|
| `OpenProcess(PROCESS_VM_READ)` | `StealthyOpenProcess::Execute` com fallback, `VM_READ\|QUERY_INFORMATION` |
| offsets de novembro/2025 chutados | dump `version-f0ea5da9412f4e35` |
| `WS_EX_TRANSPARENT` fixo, sem menu | toggle de input no INSERT, mouse volta pro jogo ao fechar |
| `WorldToScreen` com `960/540` | dimensões do overlay passadas por parâmetro |
| `Initialize()` sempre `true` | checagem de `HRESULT`, fallback WARP, mensagem de erro |
| `Present(0, DO_NOT_WAIT)` em spin | `Present(1, 0)` sincronizado + `Sleep(tick)` |
| cache de filhos sem evicção | TTL 500ms, limpeza no rejoin e ao passar de 1024 entradas |
| `ReadProcessMemory` sem retorno | `Read()` valida faixa de endereço e bytes lidos |
| `std::string::c_str()` no vetor de draw | `Target` com `std::string` própria |
| duas implementações de W2S | uma, em `sdk/sdk.h` |
| ESP só com nome | caixa, nome, barra de vida, distância, team check, alcance |
| sem reattach | detecta saída do processo e reabre handle a cada 1s |
| — | detector de jogo + aim assist + perfis por PlaceId |
| — | leitor de memória ao vivo + disciplina de tiro |
| — | varredura de valor (primeiro scan + filtro) |
| — | voo via `Primitive::Position` (único write) |

## Limitações

- assume Roblox **fullscreen / borderless no monitor primário** — a matriz de projeção
  é mapeada direto no tamanho do overlay. Janela pequena desalinha ESP e aim.
- transparência por **color-key**: pixel preto é vazado.
- "Melhorar precisão do ponteiro" do Windows afeta `MOUSEEVENTF_MOVE` — desligar
  para o aim ter ganho constante entre sessões.
- overlay cobre o **monitor primário** inteiro; multi-monitor com o jogo no secundário
  não é coberto.
- `Live` protegido por Hyperion: leitura no cliente de produção tende a derrubar
  o processo. **Testar em Studio ou em VM.**

```bat
:: Hyperion mata leitura no cliente live — Studio/VM primeiro
```

## Análise do repositório original

`ANALISE.md` — scan completo, 12 bugs com arquivo:linha, verificação dos hashes do imgui.
