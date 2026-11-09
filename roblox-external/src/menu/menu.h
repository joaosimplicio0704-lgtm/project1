#pragma once
#include "../config.h"

class AimAssist;
class Detector;
class Esp;
class Fly;
class MemView;
class Overlay;
class Trigger;

namespace menu {

// desenha o menu. *open controla visibilidade (INSERT).
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, Detector& detector,
          MemView& memView, AimAssist& aim, const Trigger& trigger, const Fly& fly, bool* open);

} // namespace menu
