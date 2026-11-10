#include "overlay.h"

#include <dwmapi.h>

#include "../imgui/imgui.h"
#include "../imgui/imgui_impl_dx11.h"
#include "../imgui/imgui_impl_win32.h"

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dwmapi.lib")

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND, UINT, WPARAM, LPARAM);

static constexpr wchar_t kClassName[] = L"roblox-external-overlay";
static constexpr wchar_t kTitle[] = L"roblox-external";

#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 ((HANDLE)-4)
#endif

static Overlay* g_overlay = nullptr;

// ============================================================
// DPI: sem isso o Windows virtualiza coordenadas e a janela e
// esticada — o cursor some do widget por alguns pixels.
// ============================================================
static void EnableDpiAwareness() {
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (!user32)
        return;

    typedef BOOL(WINAPI* SetContextFn)(HANDLE);
    if (auto setContext = reinterpret_cast<SetContextFn>(GetProcAddress(user32, "SetProcessDpiAwarenessContext"))) {
        if (setContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2))
            return;
    }

    typedef BOOL(WINAPI* SetAwareFn)(void);
    if (auto setAware = reinterpret_cast<SetAwareFn>(GetProcAddress(user32, "SetProcessDPIAware")))
        setAware();
}

// janela principal (visivel) de um pid
static HWND FindMainWindow(DWORD pid) {
    struct Search { DWORD pid; HWND found; } search{ pid, nullptr };

    EnumWindows([](HWND hwnd, LPARAM param) -> BOOL {
        auto* s = reinterpret_cast<Search*>(param);
        DWORD owner = 0;
        GetWindowThreadProcessId(hwnd, &owner);
        if (owner != s->pid || !IsWindowVisible(hwnd))
            return TRUE;
        if (!GetWindow(hwnd, GW_OWNER) && GetWindowTextLengthW(hwnd) > 0) {
            s->found = hwnd;
            return FALSE;
        }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&search));

    return search.found;
}

bool Overlay::Initialize() {
    EnableDpiAwareness();

    // cobre o monitor inteiro (nao a work area) — taskbar inclusive
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (GetMonitorInfoW(MonitorFromPoint(POINT{ 0, 0 }, MONITOR_DEFAULTTOPRIMARY), &monitor)) {
        m_originX = monitor.rcMonitor.left;
        m_originY = monitor.rcMonitor.top;
        m_width = monitor.rcMonitor.right - monitor.rcMonitor.left;
        m_height = monitor.rcMonitor.bottom - monitor.rcMonitor.top;
    } else {
        m_width = GetSystemMetrics(SM_CXSCREEN);
        m_height = GetSystemMetrics(SM_CYSCREEN);
    }

    if (!CreateWindowClass())
        return false;
    if (!CreateDevice()) {
        Shutdown();
        return false;
    }

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;

    ImGuiStyle& style = ImGui::GetStyle();
    ImGui::StyleColorsDark();
    style.WindowRounding = 4.f;
    style.FrameRounding = 3.f;
    style.GrabRounding = 3.f;
    style.WindowBorderSize = 1.f;
    style.WindowPadding = ImVec2(12.f, 12.f);
    style.FramePadding = ImVec2(8.f, 5.f);   // alvo de clique maior
    style.ItemSpacing = ImVec2(8.f, 8.f);
    style.ItemInnerSpacing = ImVec2(6.f, 6.f);
    style.GrabMinSize = 14.f;
    style.ScrollbarSize = 14.f;

    // nada de preto puro dentro do painel: pixel preto = buraco de hit-test
    // (color-key), e o clique vazaria pro jogo
    style.Colors[ImGuiCol_WindowBg] = ImVec4(0.09f, 0.09f, 0.10f, 0.97f);
    style.Colors[ImGuiCol_PopupBg] = ImVec4(0.09f, 0.09f, 0.10f, 0.97f);
    style.Colors[ImGuiCol_ChildBg] = ImVec4(0.07f, 0.07f, 0.08f, 0.97f);
    style.Colors[ImGuiCol_FrameBg] = ImVec4(0.14f, 0.14f, 0.17f, 1.00f);
    style.Colors[ImGuiCol_Tab] = ImVec4(0.11f, 0.11f, 0.13f, 1.00f);
    style.Colors[ImGuiCol_TabHovered] = ImVec4(0.26f, 0.36f, 0.50f, 1.00f);
    style.Colors[ImGuiCol_TitleBg] = ImVec4(0.07f, 0.07f, 0.09f, 1.00f);
    style.Colors[ImGuiCol_TitleBgActive] = ImVec4(0.12f, 0.14f, 0.19f, 1.00f);

    ImGui_ImplWin32_Init(m_window);
    ImGui_ImplDX11_Init(m_device, m_context);

    g_overlay = this;
    m_lastFpsSample = GetTickCount64();
    return true;
}

bool Overlay::CreateWindowClass() {
    WNDCLASSEX wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.lpszClassName = kClassName;

    if (!RegisterClassExW(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS)
        return false;

    // layered + color-key: preto vira transparente, sem DWM composition manual
    m_window = CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        kClassName, kTitle, WS_POPUP,
        m_originX, m_originY, m_width, m_height,
        nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);

    if (!m_window)
        return false;

    SetLayeredWindowAttributes(m_window, RGB(0, 0, 0), 0, LWA_COLORKEY);
    ShowWindow(m_window, SW_SHOW);
    UpdateWindow(m_window);
    return true;
}

bool Overlay::CreateDevice() {
    DXGI_SWAP_CHAIN_DESC desc{};
    desc.BufferCount = 1;
    desc.BufferDesc.Width = m_width;
    desc.BufferDesc.Height = m_height;
    desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.BufferDesc.RefreshRate.Numerator = 60;
    desc.BufferDesc.RefreshRate.Denominator = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.OutputWindow = m_window;
    desc.SampleDesc.Count = 1;
    desc.Windowed = TRUE;
    desc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    desc.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;

    D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
    constexpr UINT kLevelCount = sizeof(levels) / sizeof(levels[0]);
    D3D_FEATURE_LEVEL obtained{};

    const HRESULT hr = D3D11CreateDeviceAndSwapChain(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
        levels, kLevelCount, D3D11_SDK_VERSION,
        &desc, &m_swapchain, &m_device, &obtained, &m_context);

    if (FAILED(hr) || !m_device || !m_swapchain) {
        // tenta WARP antes de desistir (VM / driver quebrado)
        if (FAILED(D3D11CreateDeviceAndSwapChain(
                nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
                levels, kLevelCount, D3D11_SDK_VERSION,
                &desc, &m_swapchain, &m_device, &obtained, &m_context)))
            return false;
    }

    if (IDXGIDevice* dxgiDevice = nullptr;
        SUCCEEDED(m_device->QueryInterface(__uuidof(IDXGIDevice), reinterpret_cast<void**>(&dxgiDevice)))) {
        if (IDXGIAdapter* adapter = nullptr; SUCCEEDED(dxgiDevice->GetAdapter(&adapter))) {
            if (IDXGIFactory* factory = nullptr; SUCCEEDED(adapter->GetParent(__uuidof(IDXGIFactory), reinterpret_cast<void**>(&factory)))) {
                factory->MakeWindowAssociation(m_window, DXGI_MWA_NO_ALT_ENTER);
                factory->Release();
            }
            adapter->Release();
        }
        dxgiDevice->Release();
    }

    CreateRenderTarget();
    return m_target != nullptr;
}

void Overlay::CreateRenderTarget() {
    DestroyRenderTarget();

    ID3D11Texture2D* backBuffer = nullptr;
    if (FAILED(m_swapchain->GetBuffer(0, IID_PPV_ARGS(&backBuffer))) || !backBuffer)
        return;

    m_device->CreateRenderTargetView(backBuffer, nullptr, &m_target);
    backBuffer->Release();
}

void Overlay::DestroyRenderTarget() {
    if (m_target) {
        m_target->Release();
        m_target = nullptr;
    }
}

bool Overlay::Pump() {
    MSG msg{};
    while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) {
            m_quit = true;
            break;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return !m_quit;
}

void Overlay::BeginFrame() {
    if (!m_target || !m_swapchain)
        return;

    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    ImGui::NewFrame();

    m_context->OMSetRenderTargets(1, &m_target, nullptr);
}

void Overlay::EndFrame() {
    if (!m_target || !m_swapchain)
        return;

    ImGui::Render();

    const float clear[4] = { 0.f, 0.f, 0.f, 1.f }; // preto = color-key
    m_context->ClearRenderTargetView(m_target, clear);
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());

    // menu aberto: sem vsync, frame curto — slider/checkbox respondem na hora.
    // fechado: sync 1 pra nao queimar core a toa.
    const HRESULT hr = m_swapchain->Present(m_interactive ? 0u : 1u, 0);

    if (hr == DXGI_ERROR_DEVICE_REMOVED || hr == DXGI_ERROR_DEVICE_RESET)
        CreateRenderTarget();

    if (m_interactive)
        KeepOnTop();

    ++m_framesSinceSample;
    const ULONGLONG now = GetTickCount64();
    if (now - m_lastFpsSample >= 500) {
        m_fps = static_cast<float>(m_framesSinceSample) * 1000.f / static_cast<float>(now - m_lastFpsSample);
        m_framesSinceSample = 0;
        m_lastFpsSample = now;
    }
}

void Overlay::KeepOnTop() {
    // o jogo costuma se reafirmar topmost; devolve a frente a cada 500ms
    const ULONGLONG now = GetTickCount64();
    if (now - m_lastTopmost < 500)
        return;

    m_lastTopmost = now;
    SetWindowPos(m_window, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
}

void Overlay::RestoreGameFocus() {
    if (!m_gamePid)
        return;

    if (HWND game = FindMainWindow(m_gamePid))
        SetForegroundWindow(game);
}

float Overlay::DpiScale() const {
    if (!m_window)
        return 1.f;

    HDC dc = GetDC(m_window);
    if (!dc)
        return 1.f;

    const int dpi = GetDeviceCaps(dc, LOGPIXELSX);
    ReleaseDC(m_window, dc);
    return dpi > 0 ? static_cast<float>(dpi) / 96.f : 1.f;
}

void Overlay::SetInteractive(bool interactive) {
    if (!m_window || interactive == m_interactive)
        return;

    m_interactive = interactive;

    LONG_PTR style = GetWindowLongPtrW(m_window, GWL_EXSTYLE);
    if (interactive) {
        style &= ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT | WS_EX_NOACTIVATE);
        SetWindowLongPtrW(m_window, GWL_EXSTYLE, style);
        SetWindowPos(m_window, HWND_TOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        m_lastTopmost = GetTickCount64();

        // foco de verdade: sem isso o ImGui trata a janela como nao-focada
        // e alguns widgets ficam com estado de hover pela metade
        SetForegroundWindow(m_window);
        SetFocus(m_window);
        ImGui::GetIO().MouseDrawCursor = false;
    } else {
        style |= WS_EX_TRANSPARENT | WS_EX_NOACTIVATE;
        SetWindowLongPtrW(m_window, GWL_EXSTYLE, style);
        SetWindowPos(m_window, HWND_TOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        ImGui::GetIO().MouseDrawCursor = false;
        RestoreGameFocus();
    }
}

void Overlay::Shutdown() {
    if (ImGui::GetCurrentContext()) {
        ImGui_ImplDX11_Shutdown();
        ImGui_ImplWin32_Shutdown();
        ImGui::DestroyContext();
    }

    DestroyRenderTarget();

    if (m_context) { m_context->Release(); m_context = nullptr; }
    if (m_swapchain) { m_swapchain->Release(); m_swapchain = nullptr; }
    if (m_device) { m_device->Release(); m_device = nullptr; }

    if (m_window) {
        DestroyWindow(m_window);
        m_window = nullptr;
    }
    UnregisterClassW(kClassName, GetModuleHandleW(nullptr));
    g_overlay = nullptr;
}

LRESULT CALLBACK Overlay::WindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    // sem handler do ImGui a janela nao recebe hover/clique direito
    if (ImGui::GetCurrentContext() && ImGui_ImplWin32_WndProcHandler(hwnd, msg, wparam, lparam))
        return 1;

    switch (msg) {
    case WM_MOUSEACTIVATE:
        // deixa ativar no clique (default MA_ACTIVATE); sem isso o primeiro
        // clique so serve pra dar foco e o widget nao seleciona
        return g_overlay && g_overlay->m_interactive ? MA_ACTIVATE : MA_NOACTIVATE;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_ERASEBKGND:
        return 1;
    default:
        break;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}
