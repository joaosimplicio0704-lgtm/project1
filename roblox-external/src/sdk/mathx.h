#pragma once

// ============================================================
// Matematica pura do projeto (sem Windows, sem memoria, sem ImGui).
//
// Fica separada de proposito: e a unica parte que da pra provar fora do
// cliente, e o harness em tests/ compila exatamente este header com g++.
// Se aim.cpp ou fly.cpp divergirem daqui, o teste quebra.
// ============================================================

#include <algorithm>
#include <cmath>

#include "sdk.h"

namespace mathx {

inline constexpr float kPi = 3.14159265358979f;

inline float DegToRad(float deg) {
    return deg * kPi / 180.f;
}

// normaliza um angulo pra (-pi, pi]
inline float WrapPi(float a) {
    while (a > kPi) a -= 2.f * kPi;
    while (a < -kPi) a += 2.f * kPi;
    return a;
}

// yaw/pitch a partir da matriz de rotacao da camera (row-major, colunas = eixos).
// LookVector = -coluna 3 => lx = -r[2], ly = -r[5], lz = -r[8].
inline bool CameraAngles(const float r[9], float& yaw, float& pitch) {
    const float lx = -r[2], ly = -r[5], lz = -r[8];

    const float len = std::sqrt(lx * lx + ly * ly + lz * lz);
    if (!(len > 0.5f) || !std::isfinite(len))
        return false;

    yaw = std::atan2(-lx, -lz);
    pitch = std::asin(std::clamp(ly / len, -1.f, 1.f));
    return std::isfinite(yaw) && std::isfinite(pitch);
}

// radianos de giro que 1 pixel de tela representa, no centro da tela.
//
// NAO e fovY/altura (aproximacao linear): a projecao e tangente. Saindo de
// x_ndc = (x_view/w) * (1/tan(fovY/2)) / aspect, a derivada no centro e
//
//     d(theta)/d(px) = 2 * tan(fovY/2) / altura
//
// e da EXATAMENTE o mesmo valor na horizontal e na vertical (o aspect cancela),
// que e o que permite usar uma conversao unica pros dois eixos.
// Em 70 graus a versao linear errava 15% pra baixo.
inline float RadiansPerPixel(float fovDeg, float height) {
    if (!(fovDeg > 1.f) || !(fovDeg < 179.f) || !(height > 0.f))
        return 0.f;
    return 2.f * std::tan(DegToRad(fovDeg) * 0.5f) / height;
}

// counts de mouse por pixel de tela, dada a sensibilidade medida (rad/count).
// Depende do FOV ATUAL: entrar em mira ADS/zoom muda a conta.
inline float CountsPerPixel(float fovDeg, float height, float radPerCount) {
    if (!(radPerCount > 0.f))
        return 0.f;
    const float radPerPx = RadiansPerPixel(fovDeg, height);
    if (!(radPerPx > 0.f))
        return 0.f;
    return std::clamp(radPerPx / radPerCount, 0.02f, 40.f);
}

// passo do voo: posicao + direcao normalizada * velocidade * dt
inline Vector3 FlyStep(const Vector3& from, const Vector3& dir, float speed, float dt) {
    return Vector3{
        from.x + dir.x * speed * dt,
        from.y + dir.y * speed * dt,
        from.z + dir.z * speed * dt
    };
}

// dt de um frame travado nao pode virar teleporte
inline float ClampDt(float dt, float maxDt) {
    if (!(dt > 0.f))
        return 0.004f;
    return dt > maxDt ? maxDt : dt;
}

} // namespace mathx
