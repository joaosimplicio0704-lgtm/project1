#pragma once
#include "../config.h"

class AimAssist;
class Detector;
class Esp;
class MemView;
class Overlay;
class Trigger;

namespace menu {

// desenha o menu. *open controla visibilidade (INSERT).
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, Detector& detector,
          MemView& memView, const AimAssist& aim, const Trigger& trigger, bool* open);

} // namespace menu
