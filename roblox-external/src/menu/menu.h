#pragma once
#include "../config.h"

class Detector;
class Esp;
class Overlay;

namespace menu {

// desenha o menu. *open controla visibilidade (INSERT).
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, Detector& detector, bool* open);

} // namespace menu
