//! Plantilla "smoke test" de emacs50 para Rust + esp-hal 1.0 (ESP32-S3, no_std).
//! Imprime por serie con esp-println y parpadea un LED: si ves los "tick N"
//! en el monitor, toda la cadena (compilar/flashear/serie/GPIO) anda.
//!
//! ⚠️ Si no compila con una esp-hal futura, regenerá con
//! `esp-generate --chip esp32s3 ...` y pegale el glue de esta carpeta
//! (.cargo/config.toml, rust-toolchain.toml, build.rs, .emacs50-flash).

#![no_std]
#![no_main]

use esp_backtrace as _;
use esp_hal::{
    delay::Delay,
    gpio::{Level, Output, OutputConfig},
    main,
};
use esp_println::println;

esp_bootloader_esp_idf::esp_app_desc!();

#[main]
fn main() -> ! {
    let peripherals = esp_hal::init(esp_hal::Config::default());
    let delay = Delay::new();

    // GPIO2: LED externo (el on-board del S3 es WS2812 → ver rust-sos-s3)
    let mut led = Output::new(peripherals.GPIO2, Level::Low, OutputConfig::default());

    let mut tick: u32 = 0;
    loop {
        led.toggle();
        println!("tick {tick} — hola desde Rust/esp-hal en ESP32");
        tick += 1;
        delay.delay_millis(1000);
    }
}
