#pragma once
// ============================================================
// STUB — dependencia ausente do closehandle.cpp
// Voce enviou closehandle.cpp mas nao enviou Cheat/Globals.hpp.
// Este e um minimo pra compilar; preencha o shutdown real no seu codigo.
// ============================================================

#include <cstddef>

namespace General {
extern bool ShutDown; // // FILL: defina essa variavel no seu .cpp de globals
}

struct Globals {
    General General;
};

extern Globals g_Globals; // // FILL: instancie isso em algum .cpp do seu projeto
