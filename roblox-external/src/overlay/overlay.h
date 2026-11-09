#pragma once
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>

// Janela layered topmost + swapchain D3D11 + ImGui.
// Transparente por color-key (preto = vazio). Sem input por padrao:
// SetInteractive() tira o WS_EX_TRANSPARENT pra poder clicar no menu.
class Overlay {
public:
    Overlay() = default;
    ~Overlay() { Shutdown(); }

    Overlay(const Overlay&) = delete;
    Overlay& operator=(const Overlay&) = delete;

    bool Initialize();
    void Shutdown();

    // bombeia a fila de mensagens; false = pediu pra sair
    bool Pump();

    void BeginFrame();
    void EndFrame();

    void SetInteractive(bool interactive);
    void ToggleInteractive() { SetInteractive(!m_interactive); }
    bool IsInteractive() const { return m_interactive; }

    // pid do jogo — usado pra devolver o foco quando o menu fecha
    void SetGamePid(DWORD pid) { m_gamePid = pid; }

    HWND  Window() const { return m_window; }
    float Width() const { return static_cast<float>(m_width); }
    float Height() const { return static_cast<float>(m_height); }
    float Fps() const { return m_fps; }
    float DpiScale() const;

    static LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM);

private:
    bool CreateWindowClass();
    bool CreateDevice();
    void CreateRenderTarget();
    void DestroyRenderTarget();
    void KeepOnTop();
    void RestoreGameFocus();

    HWND                    m_window = nullptr;
    ID3D11Device*           m_device = nullptr;
    ID3D11DeviceContext*    m_context = nullptr;
    IDXGISwapChain*         m_swapchain = nullptr;
    ID3D11RenderTargetView* m_target = nullptr;

    int   m_width = 0;
    int   m_height = 0;
    int   m_originX = 0;
    int   m_originY = 0;
    bool  m_interactive = false;
    bool  m_quit = false;
    float m_dpiScale = 1.f;
    float m_fps = 0.f;

    DWORD     m_gamePid = 0;
    ULONGLONG m_lastTopmost = 0;
    ULONGLONG m_lastFpsSample = 0;
    int       m_framesSinceSample = 0;
};
