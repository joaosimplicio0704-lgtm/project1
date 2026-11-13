#include "overlay.hpp"
#include "aimbot.hpp"
#include <d3d11.h>
#include <dxgi.h>
#include <tchar.h>
#include <imgui.h>
#include <imgui_impl_win32.h>
#include <imgui_impl_dx11.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

static ID3D11Device* g_pd3dDevice = nullptr;
static ID3D11DeviceContext* g_pd3dDeviceContext = nullptr;
static IDXGISwapChain* g_pSwapChain = nullptr;
static ID3D11RenderTargetView* g_mainRenderTargetView = nullptr;

static bool CreateRenderTarget() {
    ID3D11Texture2D* pBackBuffer = nullptr;
    if (g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer)) < 0) return false;
    g_pd3dDevice->CreateRenderTargetView(pBackBuffer, nullptr, &g_mainRenderTargetView);
    pBackBuffer->Release();
    return true;
}

static void CleanupRenderTarget() { if (g_mainRenderTargetView) { g_mainRenderTargetView->Release(); g_mainRenderTargetView = nullptr; } }
static void CleanupDevice() {
    CleanupRenderTarget();
    if (g_pSwapChain) { g_pSwapChain->Release(); g_pSwapChain = nullptr; }
    if (g_pd3dDeviceContext) { g_pd3dDeviceContext->Release(); g_pd3dDeviceContext = nullptr; }
    if (g_pd3dDevice) { g_pd3dDevice->Release(); g_pd3dDevice = nullptr; }
}

static bool CreateDevice(HWND hWnd) {
    DXGI_SWAP_CHAIN_DESC sd{}; sd.BufferCount = 2; sd.BufferDesc.Width = 0; sd.BufferDesc.Height = 0;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM; sd.BufferDesc.RefreshRate.Numerator = 60; sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT; sd.OutputWindow = hWnd; sd.SampleDesc.Count = 1; sd.Windowed = TRUE; sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD; sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    UINT flags = 0;
    if (D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags, nullptr, 0, D3D11_SDK_VERSION, &sd, &g_pSwapChain, &g_pd3dDevice, nullptr, &g_pd3dDeviceContext) < 0)
        return false;
    CreateRenderTarget();
    return true;
}

static LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam)) return true;
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

void overlayThread(Mem& mem, Entities& ents, LocalPlayer& local, OverlayCfg& cfg,
                   HWND gameWnd, int screenW, int screenH) {
    // janela overlay transparente, topmost, por cima do jogo
    WNDCLASSEXW wc{}; wc.cbSize = sizeof(wc); wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = L"FortniteOverlayClass";
    RegisterClassExW(&wc);

    HWND hwnd = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TRANSPARENT | WS_EX_LAYERED, wc.lpszClassName, L"FortniteOverlay",
                                WS_POPUP, 0, 0, screenW, screenH, nullptr, nullptr, wc.hInstance, nullptr);
    SetLayeredWindowAttributes(hwnd, RGB(0, 0, 0), 0, ULW_COLORKEY);
    SetWindowLongW(hwnd, GWL_EXSTYLE, GetWindowLongW(hwnd, GWL_EXSTYLE) | WS_EX_TRANSPARENT);
    ShowWindow(hwnd, SW_SHOW);

    if (!CreateDevice(hwnd)) { CleanupDevice(); return; }
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    ImGui::StyleColorsDark();
    ImGui_ImplWin32_Init(hwnd);
    ImGui_ImplDX11_Init(g_pd3dDevice, g_pd3dDeviceContext);

    MSG msg{}; ZeroMemory(&msg, sizeof(msg));
    bool running = true;
    while (running && msg.message != WM_QUIT) {
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg); DispatchMessageW(&msg);
            if (msg.message == WM_QUIT) running = false;
        }
        if (!running) break;

        // toggle menu com INSERT
        if (GetAsyncKeyState(VK_INSERT) & 0x8000) {
            static bool last = false;
            if (!last) cfg.menuOpen = !cfg.menuOpen;
            last = true;
        } else {
            last = false;
        }

        // sincroniza aimbot com config do menu
        aim::kTeamCheck = cfg.teamCheck;
        aim::kVisibleOnly = cfg.visibleOnly;
        aim::kFovPx = cfg.showFOV ? 140.f : 0.f;

        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();

        if (cfg.menuOpen) {
            ImGui::SetNextWindowSize(ImVec2(420, 300), ImGuiCond_FirstUseEver);
            ImGui::Begin("fortnite external", &cfg.menuOpen, ImGuiWindowFlags_NoCollapse);
            ImGui::Text("stack: externo, RPM read-only, mouse via SendInput");
            ImGui::Separator();
            ImGui::Checkbox("ESP", &cfg.esp);
            ImGui::Checkbox("Aimbot (hold XBUTTON2)", &cfg.aimbot);
            ImGui::Checkbox("Team check", &cfg.teamCheck);
            ImGui::Checkbox("Visible only (// FILL: trace)", &cfg.visibleOnly);
            ImGui::Checkbox("Show distance", &cfg.showDistance);
            ImGui::Checkbox("Show health/shield", &cfg.showHealth);
            ImGui::Checkbox("Show FOV circle", &cfg.showFOV);
            ImGui::Separator();
            ImGui::Text("END = sair");
            ImGui::End();
        }

        // leitura de entidades + W2S + desenho do ESP
        static std::vector<Entity> entsBuf;
        static LocalPlayer localBuf;
        ents.update(localBuf, entsBuf);
        local = localBuf;

        if (cfg.esp && local.valid) {
            ImDrawList* d = ImGui::GetBackgroundDrawList();
            ImVec2 center(screenW / 2.f, screenH / 2.f);

            if (cfg.showFOV) {
                d->AddCircle(center, aim::kFovPx, IM_COL32(255, 255, 255, 60), 64, 1.f);
            }

            for (const auto& e : entsBuf) {
                if (!e.valid || e.addr == local.pawn) continue;
                if (cfg.teamCheck && e.teamIndex >= 0 && local.teamIndex >= 0 && e.teamIndex == local.teamIndex) continue;

                FVector screen{};
                if (!w2s(e.head, local.camLoc, local.camRot, local.fov, screenW, screenH, screen)) continue;
                if (screen.X < 0 || screen.X > screenW || screen.Y < 0 || screen.Y > screenH) continue;

                ImVec2 top(screen.X, screen.Y - 90.f);
                ImVec2 bot(screen.X, screen.Y + 10.f);
                float w = 60.f;
                ImColor col = (e.teamIndex == local.teamIndex) ? IM_COL32(0, 255, 0, 255) : IM_COL32(255, 0, 0, 255);
                d->AddRect(ImVec2(top.x - w / 2, top.y), ImVec2(bot.x + w / 2, bot.y), col, 0.f, 0, 1.5f);

                ImVec2 labelPos(top.x - w / 2, top.y - 18.f);
                std::wstring label = e.name.empty() ? L"ent" : e.name;
                if (cfg.showDistance) {
                    float dist = (float)vecDist(local.camLoc, e.feet);
                    label += L"  [" + std::to_wstring((int)dist) + L"m]";
                }
                if (cfg.showHealth) {
                    label += L"  HP:" + std::to_wstring((int)e.health) + L" SH:" + std::to_wstring((int)e.shield);
                }
                std::string narrow(label.begin(), label.end());
                d->AddText(labelPos, col, narrow.c_str());
            }
        }

        // aimbot: só dispara com a tecla segurada
        if (cfg.aimbot && local.valid && (GetAsyncKeyState(aim::kAimKey) & 0x8000)) {
            if (const Entity* t = aim::pickTarget(entsBuf, local, screenW, screenH)) {
                aim::aimAt(*t, local, screenW, screenH);
            }
        }

        ImGui::EndFrame();
        g_pd3dDeviceContext->OMSetRenderTargets(1, &g_mainRenderTargetView, nullptr);
        g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView, reinterpret_cast<const float*>(&ImVec4(0, 0, 0, 0)));
        ImGui::Render();
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
        g_pSwapChain->Present(1, 0);
    }

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();
    CleanupDevice();
    DestroyWindow(hwnd);
}
