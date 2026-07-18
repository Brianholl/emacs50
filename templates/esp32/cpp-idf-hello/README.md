# cpp-idf-hello — C++ en ESP32 con ESP-IDF

ESP-IDF compila C++ nativamente (`main.cpp` con `extern "C" void app_main()`).

```bash
get_idf                        # carga el entorno ESP-IDF
idf.py set-target esp32s3      # o esp32
idf.py build                   # compilar
```

Con la placa conectada: **F6** en emacs50 (corre `idf.py flash monitor`).
