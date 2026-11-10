#pragma once
#include <cmath>

struct Vector2 {
    float x = 0.f, y = 0.f;
};

struct Vector3 {
    float x = 0.f, y = 0.f, z = 0.f;

    Vector3 operator-(const Vector3& o) const { return { x - o.x, y - o.y, z - o.z }; }
    float Length() const { return std::sqrt(x * x + y * y + z * z); }
    bool Finite() const { return std::isfinite(x) && std::isfinite(y) && std::isfinite(z); }
    bool NonZero() const { return x != 0.f || y != 0.f || z != 0.f; }
};

struct Matrix4x4 {
    float m[4][4]{};
};

// Row-major 4x4, w na linha 3 — convencao do RenderView do Roblox.
// NDC (y up) -> pixels (y down), com o viewport do overlay.
inline bool WorldToScreen(const Vector3& world, Vector2& screen,
                          const Matrix4x4& vm, float width, float height) {
    const float w = vm.m[3][0] * world.x + vm.m[3][1] * world.y + vm.m[3][2] * world.z + vm.m[3][3];
    if (w <= 0.001f)
        return false;

    const float inv = 1.f / w;
    const float x = (vm.m[0][0] * world.x + vm.m[0][1] * world.y + vm.m[0][2] * world.z + vm.m[0][3]) * inv;
    const float y = (vm.m[1][0] * world.x + vm.m[1][1] * world.y + vm.m[1][2] * world.z + vm.m[1][3]) * inv;

    screen.x = (x + 1.f) * 0.5f * width;
    screen.y = (1.f - y) * 0.5f * height;
    return std::isfinite(screen.x) && std::isfinite(screen.y);
}
