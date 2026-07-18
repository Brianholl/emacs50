// Hola mundo en C++ para ESP32 (ESP-IDF) — plantilla emacs50
#include <cstdio>
#include <string>
#include <vector>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

class Saludador {
    std::string nombre;
public:
    explicit Saludador(std::string n) : nombre(std::move(n)) {}
    void saludar(int i) const { std::printf("Hola desde C++ #%d, %s!\n", i, nombre.c_str()); }
};

extern "C" void app_main(void)
{
    std::vector<Saludador> saludadores;
    saludadores.emplace_back("ESP32");
    saludadores.emplace_back("emacs50");
    int i = 0;
    while (true) {
        for (const auto& s : saludadores) s.saludar(i);
        i++;
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
