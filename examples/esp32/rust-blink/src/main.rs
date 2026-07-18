//! Blink no_std con esp-hal 1.0 (ESP32-S3).
//!
//! ⚠️ La API de esp-hal cambia seguido. Esto es esp-hal **1.0** (mismo tren que
//! rust-sos-s3). Si algún día no compila, regenerá un esqueleto fresco:
//!
//!     cargo install esp-generate
//!     esp-generate --chip esp32s3 mi-proyecto   # o --chip esp32
//!
//! y copiale el "glue" de emacs50 (.cargo/config.toml, rust-toolchain.toml,
//! build.rs, .emacs50-flash) de esta carpeta.

#![no_std]
#![no_main]

use esp_backtrace as _;
use esp_hal::{
    delay::Delay,
    gpio::{Level, Output, OutputConfig},
    main,
};
use log::info;

esp_bootloader_esp_idf::esp_app_desc!();

#[main]
fn main() -> ! {
    esp_println::logger::init_logger_from_env();
    let peripherals = esp_hal::init(esp_hal::Config::default());
    let delay = Delay::new();

    // LED: GPIO2 en el ESP32 clásico. En el S3 DevKitC el LED on-board es RGB
    // (WS2812, GPIO48) y no sirve un GPIO simple — para ese, ver rust-sos-s3;
    // acá conectá un LED común a GPIO2.
    let mut led = Output::new(peripherals.GPIO2, Level::Low, OutputConfig::default());

    loop {
        led.toggle();
        info!("blink");
        delay.delay_millis(500);
    }
}
