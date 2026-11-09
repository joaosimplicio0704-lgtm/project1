#pragma once
#include "../config.h"

class Esp;
class Overlay;

namespace menu {

// desenha o menu. *open controla visibilidade (INSERT).
void Draw(cfg::Settings& settings, Esp& esp, Overlay& overlay, bool* open);

} // namespace menu
