cmake_minimum_required(VERSION 3.20.0)

set(BOARD nrf5340dk_nrf5340_cpuapp)
set(DTC_OVERLAY_FILE nrf5340dk_nrf5340_cpuapp.overlay)

find_package(Zephyr HINTS $ENV{ZEPHYR_BASE})

project(flasher_nrf53_app)

target_sources(app PRIVATE src/main.c)
