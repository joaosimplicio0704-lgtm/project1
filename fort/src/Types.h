#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace fn {
    inline constexpr double kPi = 3.14159265358979323846;

    struct FVector {
        double X = 0.0;
        double Y = 0.0;
        double Z = 0.0;
    };

    struct FRotator {
        double Pitch = 0.0;
        double Yaw = 0.0;
        double Roll = 0.0;
    };

    struct FQuat {
        double X = 0.0;
        double Y = 0.0;
        double Z = 0.0;
        double W = 1.0;
    };

    // UE5 large-world-coordinate layout from the supplied dump.
    // Explicit tail/interior padding preserves FTransform's 0x60 stride.
    struct FTransform {
        FQuat Rotation;       // 0x00
        FVector Translation;  // 0x20
        std::uint64_t Pad38 = 0;
        FVector Scale3D{ 1.0, 1.0, 1.0 }; // 0x40
        std::uint64_t Pad58 = 0;
    };

    static_assert(offsetof(FTransform, Translation) == 0x20);
    static_assert(offsetof(FTransform, Scale3D) == 0x40);
    static_assert(sizeof(FTransform) == 0x60);

    struct FMatrix {
        double M[4][4]{};
    };

    struct FMinimalViewInfoPrefix {
        FVector Location;  // 0x00
        FRotator Rotation; // 0x18
        float FOV = 90.0f; // 0x30
    };

    struct FCameraCachePrefix {
        float Timestamp = 0.0f;
        std::uint8_t Pad04[0x0C]{};
        FMinimalViewInfoPrefix POV; // 0x10
    };

    static_assert(offsetof(FCameraCachePrefix, POV) == 0x10);
    static_assert(offsetof(FMinimalViewInfoPrefix, Rotation) == 0x18);
    static_assert(offsetof(FMinimalViewInfoPrefix, FOV) == 0x30);

    template <typename T>
    struct TArray {
        T* Data = nullptr;
        std::int32_t Count = 0;
        std::int32_t Max = 0;
    };

    struct FString {
        wchar_t* Data = nullptr;
        std::int32_t Count = 0;
        std::int32_t Max = 0;
    };

    struct ScreenPoint {
        float X = 0.0f;
        float Y = 0.0f;
    };

    inline bool IsValidAddress(std::uintptr_t address) {
        return address >= 0x10000 && address < 0x0000800000000000ULL;
    }

    inline bool IsFinite(const FVector& value) {
        return std::isfinite(value.X) && std::isfinite(value.Y) && std::isfinite(value.Z);
    }

    inline bool IsFinite(const FRotator& value) {
        return std::isfinite(value.Pitch) && std::isfinite(value.Yaw) && std::isfinite(value.Roll);
    }

    inline FVector operator+(const FVector& a, const FVector& b) {
        return { a.X + b.X, a.Y + b.Y, a.Z + b.Z };
    }

    inline FVector operator-(const FVector& a, const FVector& b) {
        return { a.X - b.X, a.Y - b.Y, a.Z - b.Z };
    }

    inline FVector operator*(const FVector& value, double scalar) {
        return { value.X * scalar, value.Y * scalar, value.Z * scalar };
    }

    inline double Dot(const FVector& a, const FVector& b) {
        return a.X * b.X + a.Y * b.Y + a.Z * b.Z;
    }

    inline double Length(const FVector& value) {
        return std::sqrt(Dot(value, value));
    }

    inline double DegToRad(double degrees) {
        return degrees * kPi / 180.0;
    }

    inline double RadToDeg(double radians) {
        return radians * 180.0 / kPi;
    }

    inline double NormalizeAngle(double angle) {
        angle = std::fmod(angle + 180.0, 360.0);
        if (angle < 0.0) angle += 360.0;
        return angle - 180.0;
    }

    inline FRotator LookAt(const FVector& from, const FVector& to) {
        const FVector direction = to - from;
        const double horizontal = std::hypot(direction.X, direction.Y);
        return {
            RadToDeg(std::atan2(direction.Z, horizontal)),
            RadToDeg(std::atan2(direction.Y, direction.X)),
            0.0
        };
    }

    inline FMatrix operator*(const FMatrix& a, const FMatrix& b) {
        FMatrix result{};
        for (int row = 0; row < 4; ++row) {
            for (int column = 0; column < 4; ++column) {
                for (int index = 0; index < 4; ++index) {
                    result.M[row][column] += a.M[row][index] * b.M[index][column];
                }
            }
        }
        return result;
    }

    inline FVector TransformPoint(const FMatrix& matrix, const FVector& point) {
        return {
            point.X * matrix.M[0][0] + point.Y * matrix.M[1][0] + point.Z * matrix.M[2][0] + matrix.M[3][0],
            point.X * matrix.M[0][1] + point.Y * matrix.M[1][1] + point.Z * matrix.M[2][1] + matrix.M[3][1],
            point.X * matrix.M[0][2] + point.Y * matrix.M[1][2] + point.Z * matrix.M[2][2] + matrix.M[3][2]
        };
    }

    inline FMatrix ToMatrix(const FTransform& transform) {
        const FQuat& q = transform.Rotation;
        const double xx = q.X * q.X;
        const double yy = q.Y * q.Y;
        const double zz = q.Z * q.Z;
        const double xy = q.X * q.Y;
        const double xz = q.X * q.Z;
        const double yz = q.Y * q.Z;
        const double xw = q.X * q.W;
        const double yw = q.Y * q.W;
        const double zw = q.Z * q.W;
        const FVector& s = transform.Scale3D;

        FMatrix result{};
        result.M[0][0] = (1.0 - 2.0 * (yy + zz)) * s.X;
        result.M[0][1] = (2.0 * (xy - zw)) * s.Y;
        result.M[0][2] = (2.0 * (xz + yw)) * s.Z;

        result.M[1][0] = (2.0 * (xy + zw)) * s.X;
        result.M[1][1] = (1.0 - 2.0 * (xx + zz)) * s.Y;
        result.M[1][2] = (2.0 * (yz - xw)) * s.Z;

        result.M[2][0] = (2.0 * (xz - yw)) * s.X;
        result.M[2][1] = (2.0 * (yz + xw)) * s.Y;
        result.M[2][2] = (1.0 - 2.0 * (xx + yy)) * s.Z;

        result.M[3][0] = transform.Translation.X;
        result.M[3][1] = transform.Translation.Y;
        result.M[3][2] = transform.Translation.Z;
        result.M[3][3] = 1.0;
        return result;
    }

    inline bool InvertMatrix(const FMatrix& input, FMatrix& output) {
        double work[4][8]{};
        for (int row = 0; row < 4; ++row) {
            for (int column = 0; column < 4; ++column) {
                work[row][column] = input.M[row][column];
            }
            work[row][row + 4] = 1.0;
        }

        for (int column = 0; column < 4; ++column) {
            int pivot = column;
            for (int row = column + 1; row < 4; ++row) {
                if (std::abs(work[row][column]) > std::abs(work[pivot][column])) {
                    pivot = row;
                }
            }
            if (std::abs(work[pivot][column]) < 1e-12) return false;
            if (pivot != column) {
                for (int index = 0; index < 8; ++index) {
                    std::swap(work[pivot][index], work[column][index]);
                }
            }

            const double divisor = work[column][column];
            for (double& value : work[column]) value /= divisor;

            for (int row = 0; row < 4; ++row) {
                if (row == column) continue;
                const double factor = work[row][column];
                for (int index = 0; index < 8; ++index) {
                    work[row][index] -= factor * work[column][index];
                }
            }
        }

        for (int row = 0; row < 4; ++row) {
            for (int column = 0; column < 4; ++column) {
                output.M[row][column] = work[row][column + 4];
            }
        }
        return true;
    }

    // Unreal camera convention: X is right, Y is up, Z is forward after
    // projecting onto the camera axes. Screen Y is flipped at the end.
    inline bool WorldToScreen(
        const FVector& world,
        const FVector& cameraLocation,
        const FRotator& cameraRotation,
        float cameraFov,
        int screenWidth,
        int screenHeight,
        ScreenPoint& output) {
        if (screenWidth <= 0 || screenHeight <= 0 || cameraFov <= 1.0f || cameraFov >= 179.0f) {
            return false;
        }

        const double yaw = DegToRad(cameraRotation.Yaw);
        const double pitch = DegToRad(cameraRotation.Pitch);
        const double sy = std::sin(yaw);
        const double cy = std::cos(yaw);
        const double sp = std::sin(pitch);
        const double cp = std::cos(pitch);

        const FVector axisX{ cy * cp, sy * cp, sp };
        const FVector axisY{ -sy, cy, 0.0 };
        const FVector axisZ{ -cy * sp, -sy * sp, cp };
        const FVector delta = world - cameraLocation;
        const double right = Dot(delta, axisY);
        const double up = Dot(delta, axisZ);
        const double forward = Dot(delta, axisX);
        if (forward < 0.01) return false;

        const double focal = (screenWidth * 0.5) / std::tan(DegToRad(cameraFov) * 0.5);
        output.X = static_cast<float>(screenWidth * 0.5 + right * focal / forward);
        output.Y = static_cast<float>(screenHeight * 0.5 - up * focal / forward);
        return std::isfinite(output.X) && std::isfinite(output.Y);
    }
}
