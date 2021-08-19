cmake_minimum_required(VERSION 3.20.0)

set(BOARD nrf5340dk_nrf5340_cpunet)
set(DTC_OVERLAY_FILE nrf5340dk_nrf5340_cpunet.overlay)

find_package(Zephyr HINTS $ENV{ZEPHYR_BASE})

project(flasher_nrf53_net)

zephyr_include_directories(../include)

target_sources(app PRIVATE src/main.c)
