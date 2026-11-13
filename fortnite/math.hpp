#pragma once
#include <cmath>
#include <windows.h>

struct FVector { double X = 0, Y = 0, Z = 0; };
struct FRotator { double Pitch = 0, Yaw = 0, Roll = 0; };

inline FVector operator+(const FVector& a, const FVector& b) { return {a.X + b.X, a.Y + b.Y, a.Z + b.Z}; }
inline FVector operator-(const FVector& a, const FVector& b) { return {a.X - b.X, a.Y - b.Y, a.Z - b.Z}; }
inline FVector operator*(const FVector& v, double s) { return {v.X * s, v.Y * s, v.Z * s}; }

inline double vecDist(const FVector& a, const FVector& b) {
    double dx = a.X - b.X, dy = a.Y - b.Y, dz = a.Z - b.Z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

// Convenção Unreal: matriz de rotação a partir do rotator + projeção com FOV do PlayerCameraManager.
// W2S do Source (row-major, Y invertida) NÃO se aplica aqui — é a convenção Unreal/POV.
struct FMatrix {
    double m[4][4];
    FVector operator*(const FVector& v) const {
        return {
            m[0][0] * v.X + m[0][1] * v.Y + m[0][2] * v.Z + m[0][3],
            m[1][0] * v.X + m[1][1] * v.Y + m[1][2] * v.Z + m[1][3],
            m[2][0] * v.X + m[2][1] * v.Y + m[2][2] * v.Z + m[2][3]
        };
    }
    FVector Transform(const FVector& v) const {
        double w = m[3][0] * v.X + m[3][1] * v.Y + m[3][2] * v.Z + m[3][3];
        FVector r = (*this) * v;
        if (w != 0.0) r = r * (1.0 / w);
        return r;
    }
};

// matriz de rotação a partir de rotator (graus)
inline FMatrix rotMatrix(const FRotator& rot) {
    double cp = std::cos(rot.Pitch * 3.14159265358979323846 / 180.0);
    double sp = std::sin(rot.Pitch * 3.14159265358979323846 / 180.0);
    double cy = std::cos(rot.Yaw * 3.14159265358979323846 / 180.0);
    double sy = std::sin(rot.Yaw * 3.14159265358979323846 / 180.0);
    double cr = std::cos(rot.Roll * 3.14159265358979323846 / 180.0);
    double sr = std::sin(rot.Roll * 3.14159265358979323846 / 180.0);

    FMatrix m;
    m.m[0][0] = cp * cy; m.m[0][1] = cp * sy; m.m[0][2] = sp;
    m.m[0][3] = 0;
    m.m[1][0] = sr * sp * cy - cr * sy; m.m[1][1] = sr * sp * sy + cr * cy; m.m[1][2] = -sr * cp;
    m.m[1][3] = 0;
    m.m[2][0] = -(cr * sp * cy + sr * sy); m.m[2][1] = cy * sr - cr * sp * sy; m.m[2][2] = cr * cp;
    m.m[2][3] = 0;
    m.m[3][0] = 0; m.m[3][1] = 0; m.m[3][2] = 0; m.m[3][3] = 1;
    return m;
}

// projeta ponto do mundo pra tela. retorna true se na frente da câmera.
inline bool w2s(const FVector& world, const FVector& camLoc, const FRotator& camRot,
                double fov, int screenW, int screenH, FVector& out) {
    FMatrix rot = rotMatrix(camRot);
    FVector v = world - camLoc;
    FVector t = rot.Transform(v);

    // t.Z = distância na direção de visão da câmera (para frente)
    if (t.Z <= 0.1) return false;

    double fovRad = fov * 3.14159265358979323846 / 180.0;
    double halfH = tan(fovRad / 2.0) * t.Z;
    double halfW = halfH * ((double)screenW / screenH);

    double x = screenW / 2.0 * (1.0 - t.X / halfW);
    double y = screenH / 2.0 * (1.0 + t.Y / halfH); // Y direta da tela (topo=0)

    out = {x, y, t.Z};
    return true;
}

// distância na tela do ponto ao centro (crosshair)
inline double screenDist(double x, double y, int sw, int sh) {
    double dx = x - sw / 2.0, dy = y - sh / 2.0;
    return std::sqrt(dx * dx + dy * dy);
}

// delta de rotação atual (view rot) para olhar para um alvo (em graus)
inline FRotator angleTo(const FVector& from, const FVector& to, const FRotator& current) {
    FVector d = to - from;
    double dist = std::sqrt(d.X * d.X + d.Y * d.Y + d.Z * d.Z);
    double pitch = -std::asin(d.Z / dist) * 180.0 / 3.14159265358979323846;
    double yaw = std::atan2(d.Y, d.X) * 180.0 / 3.14159265358979323846 - 90.0;

    FRotator delta;
    delta.Yaw = yaw - current.Yaw;
    delta.Pitch = pitch - current.Pitch;
    // normaliza yaw para [-180, 180]
    while (delta.Yaw > 180) delta.Yaw -= 360;
    while (delta.Yaw < -180) delta.Yaw += 360;
    return delta;
}
