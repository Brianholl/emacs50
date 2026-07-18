#!/usr/bin/env bash
#
# install.sh — emacs50: Emacs para todo CS50x + ESP32 (CachyOS / Arch)
#
# Sucesor unificado de emacs-crisol (C) y emacs-crustgo (C/C++/Rust/Go +
# ESP32): un solo Emacs mínimo que cubre el curso CS50x completo
# (C, Python, SQL, HTML/CSS/JS, Flask) más desarrollo ESP32.
#
# Script AUTOCONTENIDO: basta copiar este archivo a cada máquina.
#   1. Dependencias del curso: gcc/gdb/valgrind, clangd, python+flask,
#      pyright, sqlite (solo pide sudo si falta algo)
#   2. La configuración de Emacs en ~/.local/share/emacs50/
#   3. El lanzador 'emacs50' (~/.local/bin + función fish + menú KDE)
#   4. Los paquetes de Emacs (elpa)
#
# Uso:
#   ./install.sh                        instalación CS50x
#   ./install.sh --sistemas             + Rust y Go (con LSP y delve)
#   ./install.sh --esp32                + toolchains ESP32: C/C++ (ESP-IDF),
#                                         Rust (espup/espflash), Go (TinyGo)
#                                         y MicroPython (esptool/mpremote)
#   ./install.sh --esp32=c,rust         solo esas cadenas ESP32
#                                       (c | rust | go | micropython)
#   ./install.sh --sistemas --esp32     todo
#
# Variables (para --esp32):
#   IDF_BRANCH   rama de ESP-IDF a clonar   (def: release/v5.3)
#   IDF_TARGETS  chips a instalar           (def: esp32,esp32s3)
#
# NO ejecutar como root.

set -euo pipefail

EMACS50_DIR="$HOME/.local/share/emacs50"
BIN_DIR="$HOME/.local/bin"

WITH_SISTEMAS=0
WITH_ESP32=0
ESP32_PARTS="c,rust,go,micropython"
for arg in "$@"; do
    case "$arg" in
        --sistemas) WITH_SISTEMAS=1 ;;
        --esp32)    WITH_ESP32=1 ;;
        --esp32=*)  WITH_ESP32=1; ESP32_PARTS="${arg#--esp32=}" ;;
        -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Opción desconocida: $arg (usar --help)"; exit 1 ;;
    esac
done

msg()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m ✗ %s\033[0m\n' "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] && fail "No ejecutar como root."
have pacman || fail "Este script es para Arch/CachyOS (pacman)."

# Helper: instala con pacman solo lo que falte (así solo pide sudo si hace falta)
pacman_needed() {
    local missing=()
    for p in "$@"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        msg "Instalando con pacman: ${missing[*]}  (pide sudo)"
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
}

# Helper: agrega un alias/línea a bash y zsh si no está
add_rc_line() {  # $1=patrón-de-búsqueda  $2=línea
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && { grep -q "$1" "$rc" || echo "$2" >> "$rc"; }
    done
}

# ── 1. Dependencias del curso CS50x ───────────────────────────
# C: gcc/gdb/make/valgrind + clangd (LSP) · Python: python/pip/flask +
# pyright (LSP) · SQL: sqlite · git para los repos de los alumnos.
pacman_needed emacs gcc gdb make valgrind clang python python-pip \
              python-pipx python-flask pyright sqlite git
ok "Dependencias CS50x presentes."

# ── 2. Rust y Go (opcional, --sistemas) ───────────────────────
if [ "$WITH_SISTEMAS" -eq 1 ]; then
    pacman_needed go gopls
    # Rust: si ya hay rustup (toolchain propio), NO instalamos los paquetes
    # 'rust'/'rust-analyzer' de pacman porque ENTRAN EN CONFLICTO con rustup.
    if have rustup; then
        msg "Detectado rustup — Rust se gestiona aparte (no se toca con pacman)."
        have rust-analyzer || rustup component add rust-analyzer || \
            echo "!!  Agregá rust-analyzer con: rustup component add rust-analyzer"
    else
        pacman_needed rust rust-analyzer
    fi
    # delve: debugger de Go
    if have go && ! have dlv; then
        msg "Instalando delve (dlv) con 'go install'…"
        go install github.com/go-delve/delve/cmd/dlv@latest || \
            echo "!!  No se pudo instalar dlv; instalalo a mano si vas a depurar Go."
    fi
    ok "Rust y Go listos."
fi

# ── 3. Configuración de Emacs ─────────────────────────────────
mkdir -p "$EMACS50_DIR"

cat > "$EMACS50_DIR/early-init.el" << 'EMACS50_EARLY'
;;; early-init.el --- emacs50 — arranque temprano -*- lexical-binding: t; -*-

;; Sin barras ni adornos: se desactivan ANTES de dibujar el frame (sin parpadeo).
(setq inhibit-startup-screen t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

;; GC alto durante el arranque; se normaliza al final de init.el.
(setq gc-cons-threshold (* 128 1024 1024))

;; package.el se inicializa manualmente en init.el.
(setq package-enable-at-startup nil)

;;; early-init.el ends here
EMACS50_EARLY

cat > "$EMACS50_DIR/init.el" << 'EMACS50_INIT'
;;; init.el --- emacs50 — Emacs para todo CS50x + ESP32 -*- lexical-binding: t; -*-
;;
;; Version: 1.0
;;
;; emacs50: sucesor unificado de emacs-crisol y emacs-crustgo.
;; Cubre el curso CS50x completo — C, Python (+Flask), SQL, HTML/CSS/JS —
;; más C++/Rust/Go y flasheo de ESP32. Tema dark + números de línea,
;; lsp-mode y debug con gdb/dap. Sin org-mode, sin IA, sin adornos.
;;
;; Lanzar:  emacs50
;;     o:   emacs --init-directory ~/.local/share/emacs50/

;; ─────────────────────────────────────────────────────────────
;; 1. Paquetes (MELPA + use-package)
;; ─────────────────────────────────────────────────────────────
(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;; ─────────────────────────────────────────────────────────────
;; 2. UI: tema dark + números de línea
;; ─────────────────────────────────────────────────────────────
(use-package emacs
  :ensure nil
  :config
  (setq ring-bell-function 'ignore)        ; sin sonidos
  ;; Sin popup de warnings de la compilación nativa (ruido de 1ª ejecución)
  (setq native-comp-async-report-warnings-errors 'silent)
  ;; Siempre minibuffer, nunca diálogos gráficos del sistema
  (setq use-dialog-box nil
        use-file-dialog nil)
  ;; Mensaje del buffer *scratch* — ASCII art de emacs50
  (setq initial-scratch-message "\
;;
;; ███████╗███╗   ███╗ █████╗  ██████╗███████╗███████╗ ██████╗
;; ██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝██╔════╝██╔═████╗
;; █████╗  ██╔████╔██║███████║██║     ███████╗███████╗██║██╔██║
;; ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║╚════██║████╔╝██║
;; ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║███████║╚██████╔╝
;; ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝ ╚═════╝
;;
;;   CS50x + ESP32  ·  F4 terminal · F5 compila/corre · F6 flashea
;;   F9 árbol · F12 def · M-x gdb · 1ª vez: M-x dap-cpptools-setup
\n")
  (setq-default indent-tabs-mode nil
                tab-width 4
                c-basic-offset 4)
  (column-number-mode 1)
  (global-auto-revert-mode 1)              ; recargar archivos cambiados fuera
  ;; Números de línea absolutos, como VS Code
  (setq display-line-numbers-type t)
  (global-display-line-numbers-mode 1)
  ;; Fuente (usa la primera disponible)
  (require 'cl-lib)
  (when (display-graphic-p)
    (cl-dolist (f '("JetBrains Mono" "Iosevka" "Hack" "DejaVu Sans Mono"))
      (when (member f (font-family-list))
        (set-face-attribute 'default nil :font f :height 140)
        (cl-return)))))

;; Tema: GitHub Dark de VS Code, con fondo negro puro como el code de CS50
(use-package github-dark-vscode-theme
  :config
  (load-theme 'github-dark-vscode t)
  (dolist (face '(default fringe line-number line-number-current-line))
    (when (facep face)
      (set-face-attribute face nil :background "#000000"))))

;; ─────────────────────────────────────────────────────────────
;; 3. Autocompletado
;; ─────────────────────────────────────────────────────────────
(use-package company
  :hook (after-init . global-company-mode)
  :config
  (setq company-minimum-prefix-length 1
        company-idle-delay 0.2))

;; ─────────────────────────────────────────────────────────────
;; 4. Modos de lenguaje
;; ─────────────────────────────────────────────────────────────
;; C/C++ y Python ya vienen (cc-mode, python-mode). SQL: dialecto sqlite,
;; como en CS50. HTML/CSS/JS: modos incluidos (mhtml-mode, css-mode, js-mode).
(setq sql-product 'sqlite
      js-indent-level 2
      css-indent-offset 2
      python-indent-offset 4)

(use-package rust-mode
  :mode "\\.rs\\'"
  :config
  ;; Formatear con rustfmt al guardar
  (setq rust-format-on-save t))

(use-package go-mode
  :mode "\\.go\\'"
  :config
  ;; gofmt al guardar (Go usa tabs; respetamos su estilo nativo)
  (add-hook 'before-save-hook #'gofmt-before-save nil t))

;; ─────────────────────────────────────────────────────────────
;; 5. LSP — clangd (C/C++) · pyright (Python) · rust-analyzer · gopls
;; ─────────────────────────────────────────────────────────────
(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :hook ((c-mode    . lsp-deferred)
         (c++-mode  . lsp-deferred)
         (rust-mode . lsp-deferred)
         (go-mode   . lsp-deferred)
         ;; organizar imports de Go al guardar (gopls)
         (go-mode   . (lambda ()
                        (add-hook 'before-save-hook
                                  #'lsp-organize-imports nil t))))
  :init
  (setq lsp-keymap-prefix "C-c l"
        ;; no preguntar por el root del proyecto (archivos sueltos de clase)
        lsp-auto-guess-root t)
  :config
  (setq lsp-headerline-breadcrumb-enable nil
        lsp-idle-delay 0.5)
  ;; F12 = ir a definición · Shift-F12 = referencias
  (define-key lsp-mode-map (kbd "<f12>")   #'lsp-find-definition)
  (define-key lsp-mode-map (kbd "S-<f12>") #'lsp-find-references))

;; Python → pyright
(use-package lsp-pyright
  :hook (python-mode . (lambda ()
                         (require 'lsp-pyright)
                         (lsp-deferred))))

(use-package lsp-ui
  :commands lsp-ui-mode
  :config
  (setq lsp-ui-doc-enable nil
        lsp-ui-sideline-enable t))

;; ─────────────────────────────────────────────────────────────
;; 6. Debug — dap-mode + gdb / delve
;; ─────────────────────────────────────────────────────────────
(autoload 'dap-cpptools-setup "dap-cpptools" "Install dap-cpptools" t)
(use-package dap-mode
  :after lsp-mode
  :config
  (require 'dap-cpptools)        ; adaptador C/C++/Rust (usa gdb por debajo)
  (require 'dap-dlv-go)          ; adaptador Go (usa delve / dlv)
  (dap-auto-configure-mode 1))

;; GDB nativo de Emacs — es lo más sólido para VER REGISTROS (C/C++/Rust).
;; M-x gdb  → abre el layout completo; con gdb-many-windows tenés
;; locals/stack/breakpoints. Para registros: en el buffer de gud,
;; M-x gdb-display-registers-buffer (o cambiá una ventana a ese buffer);
;; se actualizan en cada paso.
;; Para Go, lo idiomático es delve:  M-x dap-debug → "Go Dlv ...".
(setq gdb-many-windows t
      gdb-show-main t)

;; ─────────────────────────────────────────────────────────────
;; 6b. Look "como code": pestañas + árbol de archivos (F9)
;; ─────────────────────────────────────────────────────────────
;; Pestañas de buffers arriba de cada ventana, como las del editor de VS Code
(global-tab-line-mode 1)
;; sin pestañas en las ventanas especiales
(dolist (hook '(eat-mode-hook compilation-mode-hook treemacs-mode-hook))
  (add-hook hook (lambda () (setq-local tab-line-format nil))))

;; Árbol de archivos a la izquierda (treemacs ya viene con dap/lsp)
(use-package treemacs
  :commands (treemacs treemacs-add-and-display-current-project-exclusively)
  :config
  (setq treemacs-width 30
        treemacs-no-png-images t)    ; iconos de texto, estilo vs-minimal
  ;; sin números de línea en el árbol
  (add-hook 'treemacs-mode-hook (lambda () (display-line-numbers-mode -1))))

(defun emacs50-tree ()
  "F9: mostrar/ocultar el árbol de archivos del proyecto actual."
  (interactive)
  (if (and (fboundp 'treemacs-current-visibility)
           (eq (treemacs-current-visibility) 'visible))
      (treemacs)                                        ; visible → ocultar
    (treemacs-add-and-display-current-project-exclusively)))  ; sin preguntar

(global-set-key (kbd "<f9>") #'emacs50-tree)

;; ─────────────────────────────────────────────────────────────
;; 7. Terminal abajo con F4 (como en cs50.dev)
;; ─────────────────────────────────────────────────────────────
(use-package eat
  :commands (eat)
  :init
  ;; bash siempre, como en cs50.dev (y evita asistentes de zsh/fish del
  ;; sistema). eat usa explicit-shell-file-name; eat-shell no existe en 0.9.x.
  (setq explicit-shell-file-name "/bin/bash")
  :config
  (setq eat-kill-buffer-on-exit t)
  ;; sin números de línea dentro de la terminal
  (add-hook 'eat-mode-hook (lambda () (display-line-numbers-mode -1))))

(defun emacs50-terminal ()
  "F4: mostrar/ocultar una terminal en la parte de abajo."
  (interactive)
  (let* ((buf (get-buffer "*eat*"))
         (win (and buf (get-buffer-window buf))))
    (if win
        (delete-window win)
      (let ((window (display-buffer
                     (or buf (save-window-excursion (eat "/bin/bash")))
                     '((display-buffer-in-side-window)
                       (side . bottom)
                       (window-height . 0.3)))))
        (select-window window)))))

(global-set-key (kbd "<f4>") #'emacs50-terminal)

;; Al arrancar en modo gráfico: terminal abajo ya abierta (como cs50.dev)
;; y, si se abrió una carpeta (emacs50 .), el árbol de archivos a la izquierda.
(add-hook 'emacs-startup-hook
          (lambda ()
            (when (display-graphic-p)
              (save-selected-window (emacs50-terminal))
              (when (derived-mode-p 'dired-mode)
                (save-selected-window
                 (treemacs-add-and-display-current-project-exclusively))))))

;; ─────────────────────────────────────────────────────────────
;; 8. Compilar / correr con F5 (según el proyecto o el archivo)
;; ─────────────────────────────────────────────────────────────
(setq compilation-scroll-output t)

(defun emacs50-compile ()
  "F5: guarda y compila/corre. Detecta el proyecto (Makefile, Cargo.toml,
go.mod) y, si no hay, actúa según el archivo: C → gcc, C++ → g++,
Python → python (app.py → flask run), Rust → rustc, Go → go run,
HTML → abrir en el navegador."
  (interactive)
  (save-buffer)
  (let* ((file  buffer-file-name)
         (ext   (and file (downcase (or (file-name-extension file) ""))))
         (base  (and file (file-name-base file)))
         (name  (and file (file-name-nondirectory file)))
         (cargo (locate-dominating-file default-directory "Cargo.toml"))
         (gomod (locate-dominating-file default-directory "go.mod"))
         (make  (locate-dominating-file default-directory "Makefile"))
         dir cmd)
    (cond
     ;; ── HTML: abrir en el navegador, no "compilar" ──────────
     ((member ext '("html" "htm"))
      (browse-url-of-file file)
      (setq cmd nil))
     ;; ── Python ──────────────────────────────────────────────
     ((string= ext "py")
      (if (string= name "app.py")
          (setq dir default-directory cmd "flask run")   ; semana 9 de CS50
        (setq dir default-directory
              cmd (format "python %s" (shell-quote-argument name)))))
     ;; ── SQL: sugerencia, no compilación ─────────────────────
     ((string= ext "sql")
      (message "SQL: abrí la base con  M-x sql-sqlite  y mandá el buffer con C-c C-b")
      (setq cmd nil))
     ;; ── Rust ────────────────────────────────────────────────
     ((string= ext "rs")
      (if cargo
          (setq dir cargo cmd "cargo run")
        (setq dir default-directory
              cmd (format "rustc %s -o %s && ./%s"
                          (shell-quote-argument name) base base))))
     ;; ── Go ──────────────────────────────────────────────────
     ((string= ext "go")
      (if gomod
          (setq dir default-directory cmd "go run .")
        (setq dir default-directory
              cmd (format "go run %s" (shell-quote-argument name)))))
     ;; ── C ───────────────────────────────────────────────────
     ((string= ext "c")
      (if make
          (setq dir make cmd "make")
        (setq dir default-directory
              cmd (format "gcc -Wall -Wextra -g %s -o %s && ./%s"
                          (shell-quote-argument name) base base))))
     ;; ── C++ ─────────────────────────────────────────────────
     ((member ext '("cpp" "cc" "cxx" "c++" "hpp"))
      (if make
          (setq dir make cmd "make")
        (setq dir default-directory
              cmd (format "g++ -std=c++17 -Wall -Wextra -g %s -o %s && ./%s"
                          (shell-quote-argument name) base base))))
     ;; ── Sin extensión conocida: probar Makefile ─────────────
     (make (setq dir make cmd "make"))
     (t (message "emacs50: no sé cómo compilar este buffer (%s)" (or name "?"))))
    (when cmd
      (let ((default-directory dir))
        (compile cmd)))))

(global-set-key (kbd "<f5>") #'emacs50-compile)

;; ─────────────────────────────────────────────────────────────
;; 9. ESP32 / embebido — flashear con F6
;; ─────────────────────────────────────────────────────────────
;; F5 compila/corre en el HOST. Para microcontroladores el build+flash
;; lo maneja cada ecosistema (idf.py / espflash / tinygo), así que F6 va
;; aparte. Lo más confiable: un archivo .emacs50-flash en la raíz del
;; proyecto con el comando exacto (puerto, target, etc.). Si no está,
;; intentamos detectar ESP-IDF / cargo-espflash / TinyGo.
(defun emacs50-esp-flash ()
  "F6: build + flash a un ESP32.
Usa el comando del archivo `.emacs50-flash' del proyecto si existe (también
acepta el viejo `.crustgo-flash'); si no, detecta ESP-IDF (sdkconfig),
MicroPython (main.py), Rust (Cargo.toml) o TinyGo (go.mod)."
  (interactive)
  (when buffer-file-name (save-buffer))
  (let* ((root (or (locate-dominating-file default-directory ".emacs50-flash")
                   (locate-dominating-file default-directory ".crustgo-flash")
                   (locate-dominating-file default-directory "sdkconfig")
                   (locate-dominating-file default-directory "sdkconfig.defaults")
                   (locate-dominating-file default-directory "main.py")
                   (locate-dominating-file default-directory "Cargo.toml")
                   (locate-dominating-file default-directory "go.mod")
                   default-directory))
         (flashfile (cl-find-if #'file-exists-p
                                (list (expand-file-name ".emacs50-flash" root)
                                      (expand-file-name ".crustgo-flash" root))))
         cmd)
    (cond
     ;; 1) comando explícito del proyecto (gana siempre)
     (flashfile
      (setq cmd (string-trim
                 (with-temp-buffer
                   (insert-file-contents flashfile)
                   (buffer-string)))))
     ;; 2) ESP-IDF (C/C++)
     ((or (file-exists-p (expand-file-name "sdkconfig" root))
          (file-exists-p (expand-file-name "sdkconfig.defaults" root)))
      (setq cmd "idf.py flash monitor"))
     ;; 2b) MicroPython (main.py en la raíz; el firmware ya debe estar en la placa)
     ((file-exists-p (expand-file-name "main.py" root))
      (setq cmd "mpremote run main.py"))
     ;; 3) Rust embebido (espflash como runner de cargo)
     ((file-exists-p (expand-file-name "Cargo.toml" root))
      (setq cmd "cargo run --release"))
     ;; 4) TinyGo
     ((file-exists-p (expand-file-name "go.mod" root))
      (setq cmd "tinygo flash -target=esp32-coreboard-v2 -monitor .")))
    (if (and cmd (not (string-empty-p cmd)))
        (let ((default-directory root))
          ;; modo comint (interactivo): espflash pregunta por el puerto (y/n)
          ;; y el monitor de idf.py acepta teclas — en el buffer se puede tipear
          (compile cmd t))
      (message "emacs50: no sé cómo flashear. Creá un .emacs50-flash con el comando."))))

(global-set-key (kbd "<f6>") #'emacs50-esp-flash)

;; ─────────────────────────────────────────────────────────────
;; 10. Final: GC normal + custom-file separado
;; ─────────────────────────────────────────────────────────────
(setq gc-cons-threshold (* 32 1024 1024))
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file))

;;; init.el ends here
EMACS50_INIT
ok "Configuración escrita en $EMACS50_DIR"

# ── 4. Lanzador 'emacs50' ─────────────────────────────────────
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/emacs50" << LAUNCHER
#!/bin/sh
exec emacs --init-directory "$EMACS50_DIR/" "\$@"
LAUNCHER
chmod +x "$BIN_DIR/emacs50"

# PATH para bash/zsh (CachyOS suele incluir ~/.local/bin, por si acaso)
add_rc_line '.local/bin' 'export PATH="$HOME/.local/bin:$PATH"'
# fish: función + PATH
if [ -d "$HOME/.config/fish" ] || have fish; then
    mkdir -p "$HOME/.config/fish/functions"
    cat > "$HOME/.config/fish/functions/emacs50.fish" << FISH
function emacs50 --description 'emacs50 — Emacs para CS50x + ESP32'
    emacs --init-directory $EMACS50_DIR/ \$argv
end
FISH
fi
# Entrada en el menú de aplicaciones
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/emacs50.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=Emacs50
Comment=Emacs para CS50x + ESP32
Exec=$BIN_DIR/emacs50 %F
Icon=emacs
Terminal=false
Categories=Development;
Keywords=emacs;cs50;c;python;sql;esp32;
DESKTOP
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
ok "Lanzador 'emacs50' instalado (terminal y menú de aplicaciones)."

# ── 5. Paquetes de Emacs (elpa) ───────────────────────────────
msg "Descargando paquetes de Emacs (puede tardar la primera vez)…"
emacs -Q --batch \
  --eval "(setq user-emacs-directory \"$EMACS50_DIR/\" package-user-dir \"$EMACS50_DIR/elpa\")" \
  -l "$EMACS50_DIR/init.el" \
  --eval '(message "==> %d paquetes activos en %s" (length package-activated-list) package-user-dir)'
ok "Paquetes de Emacs instalados."

# ── 6. Toolchains ESP32 (opcional, --esp32) ───────────────────
if [ "$WITH_ESP32" -eq 1 ]; then
    IDF_BRANCH="${IDF_BRANCH:-release/v5.3}"
    IDF_TARGETS="${IDF_TARGETS:-esp32,esp32s3}"
    ESP_DIR="$HOME/esp"
    IDF_DIR="$ESP_DIR/esp-idf"
    do_c=0; do_rust=0; do_go=0; do_mpy=0
    IFS=',' read -ra parts <<< "$ESP32_PARTS"
    for a in "${parts[@]}"; do
        case "$a" in
            c|cpp|c++|idf)            do_c=1 ;;
            rust|rs)                  do_rust=1 ;;
            go|tinygo)                do_go=1 ;;
            micropython|mpy|upython)  do_mpy=1 ;;
            *) fail "componente ESP32 desconocido: $a (usá: c | rust | go | micropython)" ;;
        esac
    done
    msg "ESP32  (C=$do_c  Rust=$do_rust  Go=$do_go  MicroPython=$do_mpy)  IDF_BRANCH=$IDF_BRANCH  IDF_TARGETS=$IDF_TARGETS"

    # Prerrequisitos comunes
    ESP_PKGS=(git wget flex bison gperf python cmake ninja ccache dfu-util libusb)
    if [ "$do_rust" -eq 1 ] && ! have rustup && ! have cargo; then
        ESP_PKGS+=(rustup)
    fi
    pacman_needed "${ESP_PKGS[@]}"

    # Acceso al puerto serie (grupo uucp en Arch)
    if ! id -nG "$USER" | grep -qw uucp; then
        msg "Agregando $USER al grupo 'uucp' (acceso a /dev/ttyUSB* y /dev/ttyACM*)"
        sudo usermod -aG uucp "$USER"
        echo "    ⚠️  Cerrá sesión y volvé a entrar para que tome efecto."
    fi
    mkdir -p ~/.config/fish/functions

    # ── C / C++ — ESP-IDF ─────────────────────────────────────
    if [ "$do_c" -eq 1 ]; then
        msg "[C] ESP-IDF ($IDF_BRANCH)"
        mkdir -p "$ESP_DIR"
        if [ -d "$IDF_DIR/.git" ]; then
            echo "    Ya existe $IDF_DIR — no lo toco (para actualizar: cd ahí y git pull)."
        else
            git clone -b "$IDF_BRANCH" --depth 1 --shallow-submodules --recursive \
                https://github.com/espressif/esp-idf.git "$IDF_DIR"
        fi
        msg "[C] Instalando toolchains de IDF para: $IDF_TARGETS"
        ( cd "$IDF_DIR" && ./install.sh "$IDF_TARGETS" )
        # Atajo para cargar el entorno en cada terminal
        add_rc_line 'alias get_idf=' "alias get_idf=\". $IDF_DIR/export.sh\""
        if [ -f "$IDF_DIR/export.fish" ]; then
            cat > ~/.config/fish/functions/get_idf.fish << EOF
function get_idf --description 'cargar entorno ESP-IDF'
    source $IDF_DIR/export.fish
end
EOF
        fi
        ok "[C] ESP-IDF listo. Atajo 'get_idf' instalado (carga el entorno)."
    fi

    # ── Rust — espup + espflash ───────────────────────────────
    if [ "$do_rust" -eq 1 ]; then
        msg "[Rust] espup / espflash / ldproxy"
        if ! have cargo; then
            # recién instalamos rustup por pacman → fijamos un toolchain base
            rustup default stable
        fi
        # `cargo install` deja los binarios en ~/.cargo/bin; con rustup recién
        # puesto por pacman eso puede NO estar en el PATH → ni espup ni
        # `cargo run` (que usa espflash como runner) los encontrarían.
        export PATH="$HOME/.cargo/bin:$PATH"
        add_rc_line '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
        if [ ! -f ~/.config/fish/conf.d/cargo-path.fish ]; then
            mkdir -p ~/.config/fish/conf.d
            echo 'fish_add_path "$HOME/.cargo/bin"' > ~/.config/fish/conf.d/cargo-path.fish
        fi
        # Herramientas (cargo install es idempotente; saltamos si ya están)
        have espup    || cargo install espup
        have espflash || cargo install espflash
        have ldproxy  || cargo install ldproxy   # necesario para builds 'std' (esp-idf-hal)
        if [ ! -f "$HOME/export-esp.sh" ]; then
            msg "[Rust] espup install — instala el toolchain 'esp' (Xtensa)"
            espup install
        else
            echo "    Ya existe ~/export-esp.sh — el toolchain 'esp' ya está. (espup update para actualizar)"
        fi
        # Atajo get_esp — REQUERIDO incluso para no_std: export-esp.sh agrega al
        # PATH el GCC de Xtensa (xtensa-esp32s3-elf-gcc), que esp-hal usa como
        # LINKER. Sin esto, `cargo build` falla con: linker not found.
        # (LIBCLANG_PATH, que también exporta, solo hace falta para builds 'std'.)
        add_rc_line 'alias get_esp=' "alias get_esp=\". $HOME/export-esp.sh\""
        if [ -f "$HOME/export-esp.sh" ]; then
            # Traducimos export-esp.sh (bash) a una función fish equivalente:
            #   export PATH="DIR:$PATH"  → fish_add_path DIR   (el linker Xtensa)
            #   export VAR="VAL"          → set -gx VAR VAL
            {
                echo "function get_esp --description 'env del toolchain esp (Rust Xtensa)'"
                while IFS= read -r line; do
                    case "$line" in
                        'export PATH='*)
                            dirs=$(printf '%s\n' "$line" | sed -E 's/^export PATH="?(.*):\$PATH"?.*/\1/')
                            printf '%s\n' "$dirs" | tr ':' '\n' | while IFS= read -r d; do
                                [ -n "$d" ] && echo "    fish_add_path $d"
                            done
                            ;;
                        'export '*)
                            printf '%s\n' "$line" | sed -E 's/^export ([A-Za-z0-9_]+)="?([^"]*)"?.*/    set -gx \1 \2/'
                            ;;
                    esac
                done < "$HOME/export-esp.sh"
                echo "end"
            } > ~/.config/fish/functions/get_esp.fish
        fi
        ok "[Rust] espup/espflash listos. Atajo 'get_esp' instalado (cargalo antes de compilar)."
    fi

    # ── Go — TinyGo (AUR) + esptool ───────────────────────────
    if [ "$do_go" -eq 1 ]; then
        msg "[Go] TinyGo + esptool"
        pacman_needed go
        sudo pacman -S --needed --noconfirm esptool 2>/dev/null || \
            echo "!!  No pude instalar 'esptool' por pacman; instalalo a mano si vas a usar Go."
        if have tinygo; then
            echo "    TinyGo ya está instalado."
        else
            AUR=""
            for h in paru yay; do have "$h" && AUR="$h" && break; done
            if [ -n "$AUR" ]; then
                msg "[Go] Instalando tinygo-bin desde AUR con $AUR"
                "$AUR" -S --needed tinygo-bin
            else
                echo "!!  TinyGo está en AUR y no encontré paru/yay:  paru -S tinygo-bin"
            fi
        fi
        echo "    ℹ️  Recordá: TinyGo soporta el ESP32 clásico, NO el ESP32-S3."
    fi

    # ── MicroPython — esptool + mpremote (vía pipx, sin sudo) ─
    if [ "$do_mpy" -eq 1 ]; then
        msg "[MicroPython] esptool + mpremote (pipx)"
        have pipx || fail "falta pipx (lo instala la sección 1 de este script)"
        have esptool  || pipx install esptool  >/dev/null
        have mpremote || pipx install mpremote >/dev/null
        echo "    Firmware: bajá el .bin de https://micropython.org/download/ y:"
        echo "      esptool --chip auto erase_flash"
        echo "      esptool --chip auto write_flash 0x1000 FIRMWARE.bin   # S3: offset 0x0"
        echo "    Después: F6 en un proyecto con main.py corre 'mpremote run main.py'."
        ok "[MicroPython] esptool y mpremote listos (plantilla: templates/esp32/micropython-hello)."
    fi
fi

# ── 7. Verificación ───────────────────────────────────────────
echo
msg "Verificación:"
check() { if have "$1"; then printf '    ✓ %s\n' "$1"; else printf '    ✗ %s  (FALTA)\n' "$1"; fi; }
for b in emacs gcc gdb make valgrind clangd python pyright sqlite3 flask; do check "$b"; done
if [ "$WITH_SISTEMAS" -eq 1 ]; then
    for b in rustc cargo rust-analyzer go gopls dlv; do check "$b"; done
fi
if [ "$WITH_ESP32" -eq 1 ]; then
    [ "$do_c" -eq 1 ] && { [ -f "$IDF_DIR/export.sh" ] && printf '    ✓ ESP-IDF (cargá el entorno con get_idf)\n' || printf '    ✗ ESP-IDF\n'; }
    [ "$do_rust" -eq 1 ] && { check espup; check espflash; }
    [ "$do_go" -eq 1 ] && { check tinygo; check esptool; }
    [ "$do_mpy" -eq 1 ] && { check esptool; check mpremote; }
fi

echo
ok "Listo. Abrí una terminal nueva y ejecutá:  emacs50"
echo "   F4 terminal · F5 compila/corre · F6 flashea ESP32 · F12 definición"
echo "   Extras de CS50 (opcionales):  pipx install check50 style50 submit50"
echo "   (la librería 'cs50' de Python va en el venv de cada proyecto)"
