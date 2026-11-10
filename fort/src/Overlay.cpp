#include "Config.h"
#include "Game.h"
#include "Input.h"
#include "Types.h"

#include <windows.h>
#include <d3d11.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstring>
#include <string>
#include <thread>

#include "imgui.h"
#include "imgui_impl_dx11.h"
#include "imgui_impl_win32.h"

// ------------------------- launch configuration -------------------------
inline constexpr int kAimKey = VK_RBUTTON;
inline constexpr int kAimToggleKey = VK_F1;
inline constexpr int kEspToggleKey = VK_F2;
inline constexpr int kMenuKey = VK_INSERT;
inline constexpr int kExitKey = VK_END;
inline constexpr int kSaveKey = VK_F5;
inline constexpr int kLoadKey = VK_F9;
inline constexpr DWORD kTickMs = 4;
inline constexpr float kFovPx = 180.0f;
inline constexpr float kSmoothing = 4.0f;
inline constexpr int kHeadBone = 110;
inline constexpr bool kTeamCheck = true;
inline constexpr bool kVisibleOnly = true;
// -----------------------------------------------------------------------

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(
    HWND window, UINT message, WPARAM wParam, LPARAM lParam);

namespace {
    ID3D11Device* g_device = nullptr;
    ID3D11DeviceContext* g_deviceContext = nullptr;
    IDXGISwapChain* g_swapChain = nullptr;
    ID3D11RenderTargetView* g_renderTarget = nullptr;
    UINT g_resizeWidth = 0;
    UINT g_resizeHeight = 0;

    void CreateRenderTarget() {
        ID3D11Texture2D* backBuffer = nullptr;
        if (SUCCEEDED(g_swapChain->GetBuffer(0, IID_PPV_ARGS(&backBuffer)))) {
            g_device->CreateRenderTargetView(backBuffer, nullptr, &g_renderTarget);
            backBuffer->Release();
        }
    }

    void CleanupRenderTarget() {
        if (g_renderTarget) {
            g_renderTarget->Release();
            g_renderTarget = nullptr;
        }
    }

    bool CreateDeviceD3D(HWND window) {
        DXGI_SWAP_CHAIN_DESC description{};
        description.BufferCount = 2;
        description.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        description.OutputWindow = window;
        description.SampleDesc.Count = 1;
        description.Windowed = TRUE;
        description.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

        constexpr D3D_FEATURE_LEVEL featureLevels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0 };
        D3D_FEATURE_LEVEL selectedLevel;
        HRESULT result = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
            featureLevels, static_cast<UINT>(std::size(featureLevels)), D3D11_SDK_VERSION,
            &description, &g_swapChain, &g_device, &selectedLevel, &g_deviceContext);

        if (FAILED(result)) {
            description.BufferCount = 1;
            result = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0,
                featureLevels, static_cast<UINT>(std::size(featureLevels)), D3D11_SDK_VERSION,
                &description, &g_swapChain, &g_device, &selectedLevel, &g_deviceContext);
        }
        if (FAILED(result)) return false;

        CreateRenderTarget();
        return g_renderTarget != nullptr;
    }

    void CleanupDeviceD3D() {
        CleanupRenderTarget();
        if (g_swapChain) {
            g_swapChain->Release();
            g_swapChain = nullptr;
        }
        if (g_deviceContext) {
            g_deviceContext->Release();
            g_deviceContext = nullptr;
        }
        if (g_device) {
            g_device->Release();
            g_device = nullptr;
        }
    }

    LRESULT WINAPI WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
        const LONG_PTR style = ::GetWindowLongPtrW(window, GWL_EXSTYLE);
        if (message == WM_NCHITTEST && (style & WS_EX_TRANSPARENT)) return HTTRANSPARENT;
        if (message == WM_LBUTTONDOWN && !(style & WS_EX_TRANSPARENT)) {
            if (::GetForegroundWindow() != window) ::SetForegroundWindow(window);
            ::SetFocus(window);
        }
        if (ImGui_ImplWin32_WndProcHandler(window, message, wParam, lParam)) return 1;

        switch (message) {
        case WM_SIZE:
            if (g_device && wParam != SIZE_MINIMIZED) {
                g_resizeWidth = LOWORD(lParam);
                g_resizeHeight = HIWORD(lParam);
            }
            return 0;
        case WM_SYSCOMMAND:
            if ((wParam & 0xFFF0) == SC_KEYMENU) return 0;
            break;
        case WM_DESTROY:
            ::PostQuitMessage(0);
            return 0;
        default:
            break;
        }
        return ::DefWindowProcW(window, message, wParam, lParam);
    }

    HWND FindGameWindow(DWORD processId) {
        struct Search {
            DWORD Pid;
            HWND Result;
        } search{ processId, nullptr };

        ::EnumWindows([](HWND window, LPARAM parameter) -> BOOL {
            auto& search = *reinterpret_cast<Search*>(parameter);
            if (!::IsWindowVisible(window)) return TRUE;
            DWORD pid = 0;
            ::GetWindowThreadProcessId(window, &pid);
            if (pid == search.Pid) {
                search.Result = window;
                return FALSE;
            }
            return TRUE;
        }, reinterpret_cast<LPARAM>(&search));
        return search.Result;
    }

    bool Pressed(int key) {
        return (::GetAsyncKeyState(key) & 1) != 0;
    }

    bool Down(int key) {
        return (::GetAsyncKeyState(key) & 0x8000) != 0;
    }

    void SetClickThrough(HWND overlay, bool clickThrough) {
        LONG_PTR style = ::GetWindowLongPtrW(overlay, GWL_EXSTYLE);
        constexpr LONG_PTR inputStyles = WS_EX_TRANSPARENT | WS_EX_NOACTIVATE;
        const LONG_PTR desired = clickThrough ? (style | inputStyles) : (style & ~inputStyles);
        if (style == desired) return;
        ::SetWindowLongPtrW(overlay, GWL_EXSTYLE, desired);
        ::SetWindowPos(overlay, HWND_TOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    }

    void FitToGame(HWND overlay, HWND game, int& width, int& height) {
        RECT client{};
        POINT origin{};
        if (!::GetClientRect(game, &client) || !::ClientToScreen(game, &origin)) return;
        const int newWidth = client.right - client.left;
        const int newHeight = client.bottom - client.top;
        if (newWidth <= 0 || newHeight <= 0) return;

        RECT current{};
        ::GetWindowRect(overlay, &current);
        if (current.left != origin.x || current.top != origin.y || newWidth != width || newHeight != height) {
            ::SetWindowPos(overlay, HWND_TOPMOST, origin.x, origin.y, newWidth, newHeight, SWP_NOACTIVATE);
        }
        width = newWidth;
        height = newHeight;
    }

    ImU32 HealthColor(float health, float maximum) {
        const float fraction = maximum > 0.0f ? std::clamp(health / maximum, 0.0f, 1.0f) : 0.0f;
        const int red = static_cast<int>(255.0f * (1.0f - fraction));
        const int green = static_cast<int>(255.0f * fraction);
        return IM_COL32(red, green, 45, 235);
    }

    void CenteredText(ImDrawList* draw, ImVec2 bottomCenter, const std::string& text, ImU32 color) {
        const ImVec2 size = ImGui::CalcTextSize(text.c_str());
        const ImVec2 position(bottomCenter.x - size.x * 0.5f, bottomCenter.y);
        draw->AddText(ImVec2(position.x + 1.0f, position.y + 1.0f), IM_COL32(0, 0, 0, 220), text.c_str());
        draw->AddText(position, color, text.c_str());
    }

    const BonePoint* FindBone(const PlayerSnapshot& player, const char* name) {
        for (const BonePoint& bone : player.Bones) {
            if (bone.Name == name) return &bone;
        }
        return nullptr;
    }

    void BoneLine(ImDrawList* draw, const PlayerSnapshot& player, const char* first, const char* second, ImU32 color) {
        const BonePoint* a = FindBone(player, first);
        const BonePoint* b = FindBone(player, second);
        if (a && b && a->Projected && b->Projected) {
            draw->AddLine(ImVec2(a->Screen.X, a->Screen.Y), ImVec2(b->Screen.X, b->Screen.Y), color, 1.35f);
        }
    }

    void DrawSkeleton(ImDrawList* draw, const PlayerSnapshot& player, ImU32 color) {
        BoneLine(draw, player, "head", "neck_02", color);
        BoneLine(draw, player, "neck_02", "neck_01", color);
        BoneLine(draw, player, "neck_01", "spine_05", color);
        BoneLine(draw, player, "spine_05", "spine_04", color);
        BoneLine(draw, player, "spine_04", "spine_03", color);
        BoneLine(draw, player, "spine_03", "spine_02", color);
        BoneLine(draw, player, "spine_02", "spine_01", color);
        BoneLine(draw, player, "spine_01", "pelvis", color);
        BoneLine(draw, player, "spine_05", "clavicle_l", color);
        BoneLine(draw, player, "clavicle_l", "upperarm_l", color);
        BoneLine(draw, player, "upperarm_l", "lowerarm_l", color);
        BoneLine(draw, player, "lowerarm_l", "hand_l", color);
        BoneLine(draw, player, "spine_05", "clavicle_r", color);
        BoneLine(draw, player, "clavicle_r", "upperarm_r", color);
        BoneLine(draw, player, "upperarm_r", "lowerarm_r", color);
        BoneLine(draw, player, "lowerarm_r", "hand_r", color);
        BoneLine(draw, player, "pelvis", "thigh_l", color);
        BoneLine(draw, player, "thigh_l", "lowerleg_l", color);
        BoneLine(draw, player, "lowerleg_l", "foot_l", color);
        BoneLine(draw, player, "pelvis", "thigh_r", color);
        BoneLine(draw, player, "thigh_r", "lowerleg_r", color);
        BoneLine(draw, player, "lowerleg_r", "foot_r", color);
    }

    void DrawPlayer(ImDrawList* draw, const PlayerSnapshot& player, const Config& config,
                    int screenWidth, int screenHeight) {
        if (!player.HeadProjected || !player.FeetProjected) return;

        float top = std::min(player.HeadScreen.Y, player.FeetScreen.Y);
        float bottom = std::max(player.HeadScreen.Y, player.FeetScreen.Y);
        for (const BonePoint& bone : player.Bones) {
            top = std::min(top, bone.Screen.Y);
            bottom = std::max(bottom, bone.Screen.Y);
        }
        const float height = bottom - top;
        if (height < 4.0f || height > screenHeight * 2.0f) return;
        const float width = std::clamp(height * 0.44f, 10.0f, static_cast<float>(screenWidth));
        const float centerX = (player.HeadScreen.X + player.FeetScreen.X) * 0.5f;
        const float left = centerX - width * 0.5f;
        const float right = centerX + width * 0.5f;
        const ImU32 color = player.IsBot ? IM_COL32(255, 190, 65, 255) : IM_COL32(95, 205, 255, 255);

        if (config.drawBoxes) {
            draw->AddRect(ImVec2(left - 1.0f, top - 1.0f), ImVec2(right + 1.0f, bottom + 1.0f),
                IM_COL32(0, 0, 0, 180), 0.0f, 0, 2.5f);
            draw->AddRect(ImVec2(left, top), ImVec2(right, bottom), color, 0.0f, 0, 1.25f);
        }

        DrawSkeleton(draw, player, IM_COL32(240, 240, 240, 220));

        if (config.drawNames) {
            CenteredText(draw, ImVec2(centerX, top - 17.0f), player.Name, color);
        }
        if (config.drawDistance) {
            CenteredText(draw, ImVec2(centerX, bottom + 3.0f),
                std::to_string(static_cast<int>(player.DistanceM)) + "m", IM_COL32(230, 230, 230, 240));
        }
        if (config.drawHealth) {
            const float healthFraction = std::clamp(player.Health / player.MaxHealth, 0.0f, 1.0f);
            const float barLeft = left - 7.0f;
            draw->AddRectFilled(ImVec2(barLeft - 1.0f, top - 1.0f), ImVec2(barLeft + 4.0f, bottom + 1.0f),
                IM_COL32(0, 0, 0, 190));
            draw->AddRectFilled(ImVec2(barLeft, bottom - height * healthFraction),
                ImVec2(barLeft + 3.0f, bottom), HealthColor(player.Health, player.MaxHealth));
            if (player.Shield > 0.0f) {
                const float shieldFraction = std::clamp(player.Shield / 100.0f, 0.0f, 1.0f);
                draw->AddRectFilled(ImVec2(right + 3.0f, bottom - height * shieldFraction),
                    ImVec2(right + 6.0f, bottom), IM_COL32(65, 145, 255, 230));
            }
        }
        if (config.snaplines) {
            draw->AddLine(ImVec2(screenWidth * 0.5f, static_cast<float>(screenHeight)),
                ImVec2(player.FeetScreen.X, player.FeetScreen.Y), IM_COL32(210, 210, 210, 140), 1.0f);
        }
    }

    void ProcessAim(const WorldSnapshot& snapshot, const Config& config, int width, int height, HWND gameWindow) {
        if (!config.aimEnabled || !snapshot.Valid || !Down(kAimKey) || ::GetForegroundWindow() != gameWindow) return;

        const float centerX = width * 0.5f;
        const float centerY = height * 0.5f;
        const PlayerSnapshot* target = nullptr;
        float bestDistance = config.fovPx;
        for (const PlayerSnapshot& player : snapshot.Players) {
            if (!player.HeadProjected || (config.teamCheck && player.Team == snapshot.LocalTeam) ||
                (config.visibleOnly && !player.RecentlyRendered)) {
                continue;
            }
            const float deltaX = player.HeadScreen.X - centerX;
            const float deltaY = player.HeadScreen.Y - centerY;
            const float distance = std::hypot(deltaX, deltaY);
            if (distance < bestDistance) {
                bestDistance = distance;
                target = &player;
            }
        }
        if (!target) return;

        const fn::FRotator desired = fn::LookAt(snapshot.CameraLocation, target->Head);
        const double yawDelta = fn::NormalizeAngle(desired.Yaw - snapshot.CameraRotation.Yaw);
        const double pitchDelta = fn::NormalizeAngle(desired.Pitch - snapshot.CameraRotation.Pitch);
        const float smoothing = std::max(1.0f, config.smoothing);
        const long mouseX = std::lround(yawDelta * config.pixelsPerDegree / smoothing);
        const long mouseY = std::lround(-pitchDelta * config.pixelsPerDegree / smoothing);
        SendMouseDelta(mouseX, mouseY);
    }

    void DrawMenu(Config& config, Game& game, const WorldSnapshot& snapshot,
                  bool& menuOpen, std::string& message) {
        if (!menuOpen) return;
        ImGui::SetNextWindowSize(ImVec2(440.0f, 390.0f), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(60.0f, 60.0f), ImGuiCond_FirstUseEver);
        if (!ImGui::Begin("Fortnite external", &menuOpen, ImGuiWindowFlags_NoCollapse)) {
            ImGui::End();
            return;
        }

        if (ImGui::BeginTabBar("main_tabs")) {
            if (ImGui::BeginTabItem("Aim")) {
                ImGui::Checkbox("Enabled (F1)", &config.aimEnabled);
                ImGui::Checkbox("Team check", &config.teamCheck);
                ImGui::Checkbox("Recently rendered only", &config.visibleOnly);
                ImGui::Checkbox("Include bots", &config.includeBots);
                ImGui::SliderFloat("FOV pixels", &config.fovPx, 10.0f, 800.0f, "%.0f");
                ImGui::SliderFloat("Smoothing", &config.smoothing, 1.0f, 50.0f, "%.1f");
                ImGui::SliderFloat("Pixels / degree", &config.pixelsPerDegree, 0.01f, 10.0f, "%.2f");
                ImGui::SliderFloat("Maximum distance (m)", &config.maxDistanceM, 1.0f, 500.0f, "%.0f");
                ImGui::InputInt("Head bone", &config.headBone);
                config.headBone = std::max(0, config.headBone);
                ImGui::TextDisabled("Hold right mouse to aim. Recently rendered is not an occlusion trace.");
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("ESP")) {
                ImGui::Checkbox("Enabled (F2)", &config.espEnabled);
                ImGui::Checkbox("Boxes", &config.drawBoxes);
                ImGui::Checkbox("Names", &config.drawNames);
                ImGui::Checkbox("Health / shield", &config.drawHealth);
                ImGui::Checkbox("Distance", &config.drawDistance);
                ImGui::Checkbox("Snaplines", &config.snaplines);
                ImGui::TextDisabled("Skeleton lines are always drawn while ESP is enabled.");
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Settings")) {
                ImGui::Text("F1 aim | F2 ESP | INSERT menu | END exit");
                ImGui::Text("F5 save | F9 load (manual, disabled at launch)");
                if (ImGui::Button("Save JSON")) (void)SaveConfig(config, message);
                ImGui::SameLine();
                if (ImGui::Button("Load JSON")) (void)LoadConfig(config, message);
                if (!message.empty()) ImGui::TextWrapped("%s", message.c_str());
                ImGui::Separator();
                ImGui::TextWrapped("%s", game.Status().c_str());
                ImGui::Text("PID: %lu", game.Pid());
                ImGui::Text("Auto read: %s", game.Ready() ? "ON (4 ms)" : "RECONNECTING");
                ImGui::Text("Snapshot: %s", snapshot.Valid ? "valid" : "waiting");
                if (snapshot.Valid) {
                    ImGui::Text("Players read: %zu", snapshot.Players.size());
                    ImGui::Text("Local pawn: 0x%llX", static_cast<unsigned long long>(snapshot.LocalPawn));
                    ImGui::Text("Camera: %.1f / %.1f / %.1f", snapshot.CameraLocation.X,
                        snapshot.CameraLocation.Y, snapshot.CameraLocation.Z);
                }
                ImGui::TextDisabled("Automatic attach, reconnect and RPM snapshots; no file monitoring.");
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        ImGui::End();
    }
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE, LPSTR commandLine, int) {
    WNDCLASSEXW windowClass{};
    windowClass.cbSize = sizeof(windowClass);
    windowClass.style = CS_CLASSDC;
    windowClass.lpfnWndProc = WindowProcedure;
    windowClass.hInstance = instance;
    windowClass.lpszClassName = L"FortniteExternalOverlay";
    if (!::RegisterClassExW(&windowClass)) return 1;

    const HWND overlay = ::CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        windowClass.lpszClassName, L"Fortnite external", WS_POPUP,
        0, 0, 100, 100, nullptr, nullptr, instance, nullptr);
    if (!overlay || !CreateDeviceD3D(overlay)) {
        ::MessageBoxW(nullptr, L"Could not initialize D3D11.", L"Fortnite external", MB_ICONERROR);
        if (overlay) ::DestroyWindow(overlay);
        ::UnregisterClassW(windowClass.lpszClassName, instance);
        return 1;
    }

    ::SetLayeredWindowAttributes(overlay, RGB(0, 0, 0), 0, LWA_COLORKEY);
    ::ShowWindow(overlay, SW_SHOWNA);
    ::UpdateWindow(overlay);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui_ImplWin32_Init(overlay);
    ImGui_ImplDX11_Init(g_device, g_deviceContext);

    Config config;
    config.fovPx = kFovPx;
    config.smoothing = kSmoothing;
    config.headBone = kHeadBone;
    config.teamCheck = kTeamCheck;
    config.visibleOnly = kVisibleOnly;

    Game game;
    bool running = true;
    bool menuOpen = true;
    bool visibleLastFrame = true;
    bool clickThroughLastFrame = false;
    int width = 100;
    int height = 100;
    std::string message = "read-only process access; no injection or memory writes";
    if (commandLine && std::strstr(commandLine, "--load-config")) {
        std::string loadMessage;
        if (LoadConfig(config, loadMessage)) {
            message = loadMessage + "; aim and ESP remain disabled at launch";
        } else {
            std::string saveMessage;
            if (SaveConfig(config, saveMessage)) {
                message = "created default fortnite-config.json; aim and ESP remain disabled";
            } else {
                message = loadMessage + "; " + saveMessage + "; using defaults";
            }
        }
    }
    config.aimEnabled = false;
    config.espEnabled = false;

    // The menu starts open, so the overlay must not retain the initial
    // click-through/no-activate styles for even its first interactive frame.
    SetClickThrough(overlay, false);
    clickThroughLastFrame = false;
    ::SetForegroundWindow(overlay);
    ::SetFocus(overlay);

    while (running) {
        MSG messageRecord;
        while (::PeekMessageW(&messageRecord, nullptr, 0, 0, PM_REMOVE)) {
            ::TranslateMessage(&messageRecord);
            ::DispatchMessageW(&messageRecord);
            if (messageRecord.message == WM_QUIT) running = false;
        }
        if (!running || Pressed(kExitKey)) break;

        if (Pressed(kMenuKey)) {
            menuOpen = !menuOpen;
            SetClickThrough(overlay, !menuOpen);
            clickThroughLastFrame = !menuOpen;
            if (menuOpen) {
                ::ShowWindow(overlay, SW_SHOWNA);
                ::SetForegroundWindow(overlay);
                ::SetFocus(overlay);
            }
        }
        if (Pressed(kAimToggleKey)) config.aimEnabled = !config.aimEnabled;
        if (Pressed(kEspToggleKey)) config.espEnabled = !config.espEnabled;
        if (Pressed(kSaveKey)) (void)SaveConfig(config, message);
        if (Pressed(kLoadKey)) (void)LoadConfig(config, message);

        (void)game.RefreshProcess();
        const HWND gameWindow = game.Pid() ? FindGameWindow(game.Pid()) : nullptr;
        const bool gameForeground = gameWindow && ::GetForegroundWindow() == gameWindow;
        const bool overlayForeground = ::GetForegroundWindow() == overlay;
        const bool visible = gameWindow && !::IsIconic(gameWindow) && (gameForeground || overlayForeground);
        if (visible != visibleLastFrame) {
            ::ShowWindow(overlay, visible ? SW_SHOWNA : SW_HIDE);
            visibleLastFrame = visible;
        }

        if (!visible) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            continue;
        }

        FitToGame(overlay, gameWindow, width, height);
        if (g_resizeWidth != 0 && g_resizeHeight != 0) {
            CleanupRenderTarget();
            g_swapChain->ResizeBuffers(0, g_resizeWidth, g_resizeHeight, DXGI_FORMAT_UNKNOWN, 0);
            g_resizeWidth = g_resizeHeight = 0;
            CreateRenderTarget();
        }

        const WorldSnapshot snapshot = game.Capture(config, width, height);
        if (!menuOpen && gameForeground) ProcessAim(snapshot, config, width, height, gameWindow);

        const bool clickThrough = !menuOpen;
        if (clickThrough != clickThroughLastFrame) {
            SetClickThrough(overlay, clickThrough);
            clickThroughLastFrame = clickThrough;
        }

        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();

        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        if (config.aimEnabled) {
            draw->AddCircle(ImVec2(width * 0.5f, height * 0.5f), config.fovPx,
                IM_COL32(255, 255, 255, 80), 64, 1.0f);
        }
        if (config.espEnabled && snapshot.Valid) {
            for (const PlayerSnapshot& player : snapshot.Players) {
                if (config.teamCheck && player.Team == snapshot.LocalTeam) continue;
                if (config.visibleOnly && !player.RecentlyRendered) continue;
                DrawPlayer(draw, player, config, width, height);
            }
        }

        if (!menuOpen) {
            ImGui::SetNextWindowPos(ImVec2(12.0f, 12.0f));
            ImGui::SetNextWindowBgAlpha(0.45f);
            ImGui::Begin("status", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs |
                ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings);
            ImGui::Text("AIM %s | ESP %s | INSERT menu | END exit",
                config.aimEnabled ? "ON" : "OFF", config.espEnabled ? "ON" : "OFF");
            ImGui::End();
        }
        DrawMenu(config, game, snapshot, menuOpen, message);

        ImGui::Render();
        constexpr float clearColor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        g_deviceContext->OMSetRenderTargets(1, &g_renderTarget, nullptr);
        g_deviceContext->ClearRenderTargetView(g_renderTarget, clearColor);
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
        g_swapChain->Present(0, 0);

        std::this_thread::sleep_for(std::chrono::milliseconds(kTickMs));
    }

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();
    CleanupDeviceD3D();
    ::DestroyWindow(overlay);
    ::UnregisterClassW(windowClass.lpszClassName, instance);
    return 0;
}
