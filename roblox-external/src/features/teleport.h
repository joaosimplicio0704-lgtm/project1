#pragma once
#include <cstdint>

#include "../config.h"
#include "../sdk/sdk.h"

class Memory;
struct LocalState;
struct SceneSnapshot;

// ============================================================
// TELEPORTE — ir ate um jogador (ou coordenada) selecionado.
//
// Duas formas:
//   instantaneo — um write de Primitive::Position. E o que a validacao de
//                 movimento derruba (erro 277) em jogo com anti-cheat.
//   suave       — N writes de ate `stepStuds`, a `writeHz`: para o servidor
//                 e movimento rapido, nao salto.
//
// O alvo e escolhido na lista da aba Acoes (jogador selecionado) ou pelo
// item filtrado (magnet). "Voltar" guarda a posicao de onde voce saiu.
// ============================================================

class Teleport {
public:
    void Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked);

    // seleciona quem vai ser o destino
    void Select(uintptr_t player) { m_selected = player; }
    uintptr_t Selected() const { return m_selected; }

    // mira no jogador e comeca (inst/suave conforme settings.teleport.smooth)
    bool GoToPlayer(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                    const SceneSnapshot& scene);

    // vai pra um ponto qualquer (usado pelo magnet "ir ate o item")
    bool GoToPoint(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                   const Vector3& target);

    // guarda de onde saimos / volta pra la
    bool SaveReturn(const LocalState& local);
    bool Return(const cfg::Settings& settings, Memory& memory, const LocalState& local);
    bool HasReturn() const { return m_haveReturn; }

    void Cancel();
    bool Stepping() const { return m_stepping; }
    int  Writes() const { return m_writes; }

private:
    void BeginStepping(const cfg::TeleportSettings& settings, const Vector3& from, const Vector3& target);

    uintptr_t m_selected = 0;
    Vector3   m_return{};
    bool      m_haveReturn = false;

    Vector3   m_from{};
    Vector3   m_target{};
    bool      m_stepping = false;
    uint64_t  m_lastWrite = 0;
    int       m_writes = 0;
};
