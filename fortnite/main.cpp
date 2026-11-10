#include "mem.hpp"
#include "offsets.hpp"
#include "entity.hpp"
#include "overlay.hpp"
#include <windows.h>
#include <thread>
#include <iostream>

int wmain() {
    const std::wstring procName = L"FortniteClient-Win64-Shipping.exe";
    const std::wstring modName = L"FortniteClient-Win64-Shipping.exe";

    Mem mem;
    if (!mem.attach(procName)) {
        std::cerr << "nao conseguiu abrir " << procName << " (o jogo esta aberto? precisa de direitos para abrir processos)\n";
        return 1;
    }
    off::kImageBase = mem.base();
    std::cout << "anexado pid=" << mem.pid() << " base=0x" << std::hex << mem.base() << "\n";

    // janela do jogo (dimensao de tela + overlay por cima)
    HWND gameWnd = FindWindowW(nullptr, L"Fortnite  ");
    if (!gameWnd) gameWnd = FindWindowW(nullptr, L"FortniteClient-Win64-Shipping");
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);

    Entities ents(mem);
    LocalPlayer local{};
    OverlayCfg cfg{};

    // // FILL: resolver o APlayerController local.
    //   receita CE:
    //     1. GWorld = base + 0x1C8E1578  (leia o ponteiro UWorld)
    //     2. GameInstance: UWorld nao expõe OwningGameInstance no dump — acha por pattern
    //        ou pelo dumper de globals do seu build.
    //     3. GameInstance->LocalPlayers (0x38) = TArray<ULocalPlayer*>; pega o [0].
    //     4. ULocalPlayer -> PlayerController: ponteiro não mapeado no dump —
    //        pointer-scan do endereço do controller que tem PlayerCameraManager != 0.
    //   entao:
    //     ents.setLocal(local, <endereco do PlayerController>);
    //
    // sem esse preenchimento, local (camera/time/team) fica invalido e ESP/aimbot nao disparam.
    std::cout << "preencha // FILL: local controller em main.cpp (receita acima)\n";

    std::thread thr(overlayThread, std::ref(mem), std::ref(ents), std::ref(local),
                    std::ref(cfg), gameWnd, screenW, screenH);

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    thr.join();
    return 0;
}
