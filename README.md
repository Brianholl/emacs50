# cs50-emacs — emacs50

```text
███████╗███╗   ███╗ █████╗  ██████╗███████╗███████╗ ██████╗
██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝██╔════╝██╔═████╗
█████╗  ██╔████╔██║███████║██║     ███████╗███████╗██║██╔██║
██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║╚════██║████╔╝██║
███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║███████║╚██████╔╝
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝ ╚═════╝
```

**Versión 1.0** — sucesor unificado de
[emacs-crisol](https://github.com/Brianholl/emacs-crisol) (C) y
[emacs-crustgo](https://github.com/Brianholl/emacs-crustgo) (C/C++/Rust/Go
+ ESP32).

Un Emacs **mínimo para todo el curso [CS50x](https://cs50.harvard.edu/x/)**
— C, Python (+Flask), SQL, HTML/CSS/JS — **más ESP32** (y C++/Rust/Go).
`lsp-mode`, debug con `gdb`/`dap`, y el **look del VS Code de CS50**:
tema GitHub Dark (VS Code) con fondo negro puro, pestañas de editor
(tab-line), árbol de archivos a la izquierda (treemacs) y terminal abajo
— árbol y terminal se abren solos al arrancar (`emacs50 .`).
Sin org-mode, sin IA, sin adornos. Hermano de
[cs50-vscode](../cs50-vscode/) y [cs50-scratch](../cs50-scratch/).

---

## Instalación (CachyOS / Arch)

**Todo está en `install.sh` — es autocontenido** (la configuración de
Emacs va embebida; escribe en `~/.local/share/emacs50/` y el repo queda
limpio). Para el taller basta copiar ese único archivo:

```bash
./install.sh                     # curso CS50x completo
./install.sh --sistemas          # + Rust y Go (LSP + delve)
./install.sh --esp32             # + toolchains ESP32 (C, Rust y Go)
./install.sh --esp32=c,rust      # solo esas cadenas ESP32
./install.sh --sistemas --esp32  # todo
```

El script instala dependencias con pacman (solo pide sudo si falta algo),
escribe la config, crea el lanzador `emacs50` (terminal + menú de
aplicaciones) y descarga los paquetes de Emacs. Variables para `--esp32`:
`IDF_BRANCH` (def: `release/v5.3`) e `IDF_TARGETS` (def: `esp32,esp32s3`).

## Uso

```bash
emacs50            # abre Emacs con la config
emacs50 hello.c    # abre directamente un archivo
```

### Atajos

| Tecla           | Acción                                            |
|-----------------|---------------------------------------------------|
| `F4`            | **Terminal** abajo (mostrar/ocultar, como cs50.dev) |
| `F5`            | Guardar y **compilar/correr**                     |
| `F6`            | **Flashear ESP32** (`.emacs50-flash` / detección) |
| `F9`            | **Árbol de archivos** del proyecto (mostrar/ocultar) |
| `F12`           | Ir a la **definición** (LSP)                      |
| `Shift-F12`     | Buscar **referencias** (LSP)                      |
| `C-c l`         | Prefijo de comandos LSP                           |
| `M-x gdb`       | Debugger (C/C++/Rust; `gdb-many-windows`)         |
| `M-x dap-debug` | Debug por dap (incl. Go con delve)                |

### Qué hace F5

| Archivo / proyecto           | Corre                                        |
|------------------------------|----------------------------------------------|
| `Makefile` (C/C++)           | `make`                                       |
| `.c` suelto                  | `gcc -Wall -Wextra -g … && ./bin`            |
| `.cpp` suelto                | `g++ -std=c++17 -Wall -Wextra -g … && ./bin` |
| `app.py`                     | `flask run` (semana 9 de CS50)               |
| `.py` suelto                 | `python archivo.py`                          |
| `.html`                      | lo abre en el navegador                      |
| `.sql`                       | sugiere `M-x sql-sqlite` (dialecto ya seteado) |
| `Cargo.toml` (`.rs`)         | `cargo run`                                  |
| `go.mod` (`.go`)             | `go run .`                                   |

### LSP por lenguaje

C/C++ → `clangd` · Python → `pyright` · Rust → `rust-analyzer` · Go → `gopls`

### Debug y registros

`M-x gdb` con `gdb-many-windows`: código, locals, stack y breakpoints;
registros con `M-x gdb-display-registers-buffer`. Para `dap-mode`, la
primera vez: `M-x dap-cpptools-setup` (C/C++/Rust) — Go usa delve.

---

## ESP32 (F6)

`F5` compila en el **host**; `F6` hace build+flash al ESP32. Orden de
decisión: archivo **`.emacs50-flash`** del proyecto con el comando exacto
(acepta también el viejo `.crustgo-flash`) → detección de ESP-IDF
(`sdkconfig`) / MicroPython (`main.py`) / Rust (`Cargo.toml` con espflash
como runner) / TinyGo (`go.mod`).

F6 corre en un buffer **interactivo** (espflash pregunta por el puerto la
primera vez; el monitor acepta teclas) y **carga los entornos solo**: si
`idf.py` no está en el PATH agrega `source ~/esp/esp-idf/export.sh`, y
para cargo/espflash agrega `source ~/export-esp.sh` — no hace falta abrir
emacs50 desde una terminal con `get_idf`/`get_esp`.

- **C / C++** → ESP-IDF (`get_idf` carga el entorno; `idf.py`). C++ va
  nativo: `main.cpp` con `extern "C" void app_main()` — ver
  `templates/esp32/cpp-idf-hello/`.
- **Rust** → espup + espflash (`get_esp` carga el entorno — necesario
  incluso en no_std: trae el linker Xtensa). Ejemplos en el tren
  **esp-hal 1.0**.
- **Go** → TinyGo (solo ESP32 clásico, no el S3)
- **MicroPython** → esptool (firmware) + mpremote (F6 corre `main.py` en
  la placa) — ver `templates/esp32/micropython-hello/`.

Componentes de `--esp32`: `c`, `rust`, `go`, `micropython` (por defecto,
todos).

Material heredado de crustgo, ya renombrado:

- [`examples/esp32/`](examples/esp32/) — blink en C, Rust y Go + el SOS
  con el LED RGB (WS2812) del ESP32-S3 en Rust/esp-hal, y el
  [`HOWTO.md`](examples/esp32/HOWTO.md) con troubleshooting de versiones.
- [`templates/esp32/`](templates/esp32/) — plantillas de arranque
  (hello+blink con auto-test por serie).

---

## Estructura

```
cs50-emacs/
├── install.sh        TODO: deps + config embebida + lanzador + elpa + ESP32
├── uninstall.sh      desinstala emacs50 (--esp32 quita también ESP-IDF/espup)
├── README.md
├── examples/esp32/   blink C/Rust/Go, SOS RGB del S3, HOWTO
└── templates/esp32/  plantillas de arranque ESP32
```

## Desinstalar

```bash
./uninstall.sh            # borra config, lanzador, función fish y menú
./uninstall.sh --esp32    # además ESP-IDF y el toolchain esp de Rust
```

No toca los paquetes de pacman (emacs, gcc, python, …), que son
compartidos con el sistema.

En el sistema instalado:

```
~/.local/share/emacs50/   early-init.el · init.el · elpa/ · custom.el
~/.local/bin/emacs50      lanzador
```

## Licencia

MIT.
