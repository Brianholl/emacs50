# Plantilla Go — TinyGo (hello + blink)

Smoke test para el **ESP32 clásico (ZY)**. **No corre en el S3.**

```bash
tinygo flash -target=esp32 -monitor .    # F6 en emacs50
```

**Anda si** en el monitor ves:

```
Hola desde emacs50! TinyGo funcionando.
tick 0
tick 1
...
```

> Empezá tu proyecto copiando esta carpeta y cambiando `module` en `go.mod`.
