#pragma once
#include <cstddef>
#include <cstdint>
#include <windows.h>

// ============================================================
// xorstr.h — shim compativel com a API do XorStr.hpp
//
//   XorStr("GetProfileIntA")        -> const char*
//   xorstr("kernel32.dll").use([]( const char* s ){ ... })
//
// Compile-time: o literal e cifrado em .rdata (constexpr), o plaintext so
// existe decifrado em um buffer thread_local durante a chamada.
// Substitui a dependencia externa XorStr.hpp (nao inclusa no projeto original).
// ============================================================

namespace xs {

constexpr std::uint8_t KeyAt(std::size_t i, std::uint8_t base) {
    return static_cast<std::uint8_t>((base + i * 131u + 7u) & 0xFFu);
}

template <std::size_t N>
struct Blob {
    char data[N]{};
};

template <std::uint8_t Base, std::size_t N>
constexpr Blob<N> Make(const char (&src)[N]) {
    Blob<N> blob{};
    for (std::size_t i = 0; i < N; ++i)
        blob.data[i] = static_cast<char>(static_cast<std::uint8_t>(src[i]) ^ KeyAt(i, Base));
    return blob;
}

template <std::uint8_t Base, std::size_t N>
void Decode(const Blob<N>& blob, char (&out)[N]) {
    for (std::size_t i = 0; i < N; ++i)
        out[i] = static_cast<char>(static_cast<std::uint8_t>(blob.data[i]) ^ KeyAt(i, Base));
}

template <std::size_t N>
struct Use {
    Blob<N> blob;
    constexpr explicit Use(Blob<N> b) : blob(b) {}

    template <class F>
    auto use(F&& f) const {
        char buffer[N];
        Decode<0x5B>(blob, buffer);
        auto result = f(static_cast<const char*>(buffer));
        SecureZeroMemory(buffer, N);
        return result;
    }
};

} // namespace xs

#define XorStr(lit)                                              \
    ([]() -> const char* {                                       \
        static constexpr ::xs::Blob<sizeof(lit)> Blob =          \
            ::xs::Make<0x5B>(lit);                               \
        static thread_local char Buffer[sizeof(lit)];            \
        ::xs::Decode<0x5B>(Blob, Buffer);                        \
        return Buffer;                                           \
    }())

#define xorstr(lit) (::xs::Use{ ::xs::Make<0x5B>(lit) })
