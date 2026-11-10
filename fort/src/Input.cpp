#include "Input.h"

#include <windows.h>

void SendMouseDelta(long deltaX, long deltaY) noexcept {
    if (deltaX == 0 && deltaY == 0) return;

    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.dx = deltaX;
    input.mi.dy = deltaY;
    input.mi.dwFlags = MOUSEEVENTF_MOVE;
    input.mi.time = 0;
    input.mi.dwExtraInfo = 0;
    ::SendInput(1, &input, sizeof(input));
}
