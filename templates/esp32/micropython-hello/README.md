# micropython-hello — MicroPython en ESP32

## 1. Instalar el firmware de MicroPython (una sola vez por placa)

Descargar el `.bin` para tu chip de https://micropython.org/download/
(ESP32_GENERIC para la clásica, ESP32_GENERIC_S3 para la S3) y:

```bash
esptool --chip auto erase_flash                       # borrar
esptool --chip auto write_flash 0x1000 FIRMWARE.bin   # clásica (S3: offset 0x0)
```

## 2. Correr código

- **F6** en emacs50 → `mpremote run main.py` (corre el archivo sin copiarlo)
- `mpremote fs cp main.py :main.py` → lo deja instalado (corre al reiniciar)
- `mpremote repl` → REPL interactivo en la placa

`esptool` y `mpremote` los instala `install.sh --esp32` (vía pipx, sin sudo).
