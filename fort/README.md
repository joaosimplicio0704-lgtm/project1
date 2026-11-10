# fort

Ferramenta externa Windows x64 em C++17: leitura por `ReadProcessMemory`, aim por deltas relativos de `SendInput` e overlay D3D11 + Dear ImGui. Não injeta DLL, não escreve na memória do jogo e não altera `ControlRotation`.

## Executar

Os binários já incluídos estão juntos em `build/`:

- `build/FortLoader.exe`: launcher que localiza e inicia o programa.
- `build/FortniteExternal.exe`: programa principal.

Deixe os dois juntos dentro de `build/`, abra o jogo e execute `build\FortLoader.exe`. Se o jogo estiver elevado, execute o loader como administrador. Não é necessário instalar ImGui nem compilar para usar os binários.

O loader procura `build/fortnite-config.json`, ao lado dos executáveis, e sempre inicia o programa com `--load-config`. Quando o arquivo não existe, o external cria um JSON com os valores padrão; a mensagem do console não indica erro. O carregamento restaura os valores do JSON, mas **aim e ESP sempre permanecem desligados no lançamento**.

O loader usa somente `CreateProcess`: não baixa arquivos, não injeta código, não altera permissões e não cria processo oculto. Para fechar o programa principal, pressione `END`.

## Teclas

| Tecla | Função |
|---|---|
| `INSERT` | abre/fecha o menu em abas |
| `F1` | liga/desliga o aim |
| botão direito | segura para atuar com o aim ligado |
| `F2` | liga/desliga o ESP |
| `F5` | salva `fortnite-config.json` no diretório atual |
| `F9` | carrega manualmente o JSON |
| `END` | encerra |

Para preparar o carregamento pelo loader, abra o programa, ajuste o menu e pressione `F5` enquanto o diretório de trabalho for a pasta dos executáveis. O arquivo será encontrado na próxima abertura pelo `FortLoader.exe`.

O menu permite ajustar FOV, smoothing, pixels por grau, distância, time, bots, osso da cabeça e elementos visuais. Ele abre em modo interativo, com foco e cliques habilitados; somente com o menu fechado o overlay fica click-through. A aba `Settings` mostra o estado da reconexão e dos snapshots automáticos de RPM a cada 4 ms, incluindo PID, jogadores e câmera. Não há monitoramento de arquivos.

## Compilar novamente

Requisitos: Windows 10/11 x64, Visual Studio 2022 com **Desktop development with C++**, CMake e Git.

No Prompt de Comando, dentro desta pasta:

```bat
build.cmd
```

Comando CMake equivalente:

```bat
cmake -S . -B cmake-build -G "Visual Studio 17 2022" -A x64 && cmake --build cmake-build --config Release --parallel
```

O `build.cmd` compila em `cmake-build\` e copia os dois executáveis novos para `build\`. O CMake baixa Dear ImGui `v1.91.5` do repositório oficial durante a configuração. `build/SHA256SUMS.txt` contém os hashes dos binários publicados.

## Pontos que precisam de redump

Os offsets presentes vieram do dump fornecido. Estes pontos não estavam completos nele e estão marcados com `// FILL:` no código:

- `Offsets.h`: `UPlayer::PlayerController`, inicialmente `0x30`. Exporte `UPlayer` no SDK e substitua se necessário.
- `Game.cpp`: nomes/índices de `kBodyBones`. Exporte `USkeletalMesh::RefSkeleton` e faça `GetBoneName(index)` para o mesh real; ajuste também o valor padrão de `kHeadBone` em `Overlay.cpp`.
- `Offsets.h`: `FFortGameplayAttributeData::CurrentValue`, inicialmente `0x4`. Confirme o layout do struct no redump.
- O código usa `SkinnedMeshComponent::CachedWorldToLocalTransform` em `0x870` e a máscara de recently rendered em `0x7E1`; confirme esses campos no redump.

Sem essa conferência, câmera, ossos ou atributos podem falhar de forma segura, mas não há garantia de funcionamento em outra build.

## Implementação e validação

- Cadeia: `UWorld -> OwningGameInstance -> LocalPlayers -> PlayerController -> PlayerCameraManager`.
- Jogadores: `GameState -> PlayerArray -> PawnPrivate`, sem depender do layout de `ActorCluster`.
- O osso component-space é convertido para world-space invertendo `CachedWorldToLocalTransform`.
- O alvo é o osso projetado mais próximo do crosshair dentro do FOV configurado.
- O delta angular vira `MOUSEEVENTF_MOVE`, dividido por smoothing; não há escrita de view angles.
- `visibleOnly` usa `bRecentlyRendered`; isso **não** é um trace de oclusão nem prova de linha de visão.
- `ProcessHandle` tenta o `StealthyOpenProcess` enviado (VEH/HWBP em thread efêmera local) e usa `OpenProcess` read-only como fallback. O acesso continua limitado a `PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`.
- `closehandle.cpp` foi adaptado para finalizar somente a thread efêmera pertencente ao módulo. A varredura global por heurística e as dependências ausentes `Cheat/Globals.hpp`, `DynamicStub` e `XorStr` não são usadas.

Os binários foram compilados por toolchain cruzada para Windows x64 e os testes matemáticos de câmera/matriz passaram. Eles **não foram executados em Windows nem testados contra o jogo** neste ambiente Linux.

Contas podem ser punidas pelo anti-cheat e pela política do jogo. Use apenas onde você tem autorização; não há promessa de compatibilidade ou não detecção.
