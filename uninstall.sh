#!/usr/bin/env bash
#
# uninstall.sh — desinstala emacs50 (todo lo que creó install.sh)
#
# Borra:
#   - la configuración y paquetes de Emacs (~/.local/share/emacs50/)
#   - el lanzador (~/.local/bin/emacs50), la función fish y la entrada
#     del menú de aplicaciones
#
# NO toca los paquetes del sistema (emacs, gcc, python, …): son
# compartidos con el resto del sistema. Si querés borrarlos:
#   sudo pacman -Rs emacs pyright python-flask …
#
# Uso:
#   ./uninstall.sh            desinstala emacs50
#   ./uninstall.sh --esp32    además: ESP-IDF (~/esp/esp-idf), el
#                             toolchain 'esp' de Rust (espup uninstall,
#                             ~/export-esp.sh) y los atajos get_idf/get_esp.
#                             No toca cargo/rustup/tinygo/esptool.

set -euo pipefail

WITH_ESP32=0
for arg in "$@"; do
    case "$arg" in
        --esp32)   WITH_ESP32=1 ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opción desconocida: $arg (usar --help)"; exit 1 ;;
    esac
done

msg() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }

# Cerrar instancias de emacs50 abiertas (usan la config que vamos a borrar)
if pgrep -f "init-directory.*emacs5[0]" >/dev/null 2>&1; then
    msg "Cerrando instancias de emacs50 abiertas…"
    pkill -f "init-directory.*emacs5[0]" || true
    sleep 1
fi

rm -rf "$HOME/.local/share/emacs50"
rm -f  "$HOME/.local/bin/emacs50" \
       "$HOME/.config/fish/functions/emacs50.fish" \
       "$HOME/.local/share/applications/emacs50.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
ok "emacs50 desinstalado (config, lanzador, función fish y menú)."

if [ "$WITH_ESP32" -eq 1 ]; then
    msg "Quitando toolchains ESP32 instalados por install.sh --esp32…"
    rm -rf "$HOME/esp/esp-idf"
    rmdir "$HOME/esp" 2>/dev/null || true   # solo si quedó vacío
    command -v espup >/dev/null 2>&1 && espup uninstall 2>/dev/null || true
    rm -f "$HOME/export-esp.sh" \
          "$HOME/.config/fish/functions/get_idf.fish" \
          "$HOME/.config/fish/functions/get_esp.fish"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && sed -i '/alias get_idf=/d; /alias get_esp=/d' "$rc"
    done
    ok "ESP32 quitado (quedan cargo/rustup, tinygo y esptool, que son del sistema)."
fi

echo
ok "Listo. Los paquetes de pacman no se tocaron."
