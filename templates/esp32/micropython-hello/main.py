# Hola mundo MicroPython para ESP32 — plantilla emacs50
# Parpadea el LED (GPIO 2 en la mayoría de las placas ESP32 clásicas;
# en la ESP32-S3 el LED on-board suele ser un WS2812 en GPIO 48 → usar neopixel).
from machine import Pin
import time

led = Pin(2, Pin.OUT)
contador = 0
while True:
    led.value(not led.value())
    print(f"Hola desde MicroPython ({contador})")
    contador += 1
    time.sleep(0.5)
