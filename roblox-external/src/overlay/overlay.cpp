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

bool Overlay::Initialize() {
    m_width = GetSystemMetrics(SM_CXSCREEN);
    m_height = GetSystemMetrics(SM_CYSCREEN);

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
    style.WindowRounding = 4.f;
    style.FrameRounding = 3.f;
    style.WindowBorderSize = 1.f;
    ImGui::StyleColorsDark();

    ImGui_ImplWin32_Init(m_window);
    ImGui_ImplDX11_Init(m_device, m_context);

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
        0, 0, m_width, m_height,
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
        levels, static_cast<UINT>(kLevelCount), D3D11_SDK_VERSION,
        &desc, &m_swapchain, &m_device, &obtained, &m_context);

    if (FAILED(hr) || !m_device || !m_swapchain) {
        // tenta WARP antes de desistir (VM / driver quebrado)
        if (FAILED(D3D11CreateDeviceAndSwapChain(
                nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
                levels, static_cast<UINT>(kLevelCount), D3D11_SDK_VERSION,
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

    // sync 1: casa com o refresh, sem queimar core em spin
    if (FAILED(m_swapchain->Present(1, 0))) {
        CreateRenderTarget(); // device perdido/alt-tab: recria o RTV
    }

    // fps
    ++m_framesSinceSample;
    const ULONGLONG now = GetTickCount64();
    if (now - m_lastFpsSample >= 500) {
        m_fps = static_cast<float>(m_framesSinceSample) * 1000.f / static_cast<float>(now - m_lastFpsSample);
        m_framesSinceSample = 0;
        m_lastFpsSample = now;
    }
}

void Overlay::SetInteractive(bool interactive) {
    if (!m_window || interactive == m_interactive)
        return;

    m_interactive = interactive;

    LONG_PTR style = GetWindowLongPtrW(m_window, GWL_EXSTYLE);
    if (interactive) {
        style &= ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT | WS_EX_NOACTIVATE);
        SetWindowLongPtrW(m_window, GWL_EXSTYLE, style);
        ShowWindow(m_window, SW_SHOW);
        SetForegroundWindow(m_window);
        ImGui::GetIO().MouseDrawCursor = true;
    } else {
        style |= WS_EX_TRANSPARENT | WS_EX_NOACTIVATE;
        SetWindowLongPtrW(m_window, GWL_EXSTYLE, style);
        ImGui::GetIO().MouseDrawCursor = false;
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
}

LRESULT CALLBACK Overlay::WindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    if (ImGui::GetCurrentContext() && ImGui_ImplWin32_WndProcHandler(hwnd, msg, wparam, lparam))
        return 1;

    switch (msg) {
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
