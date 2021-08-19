#include "fd_flasher.h"

#include <nrf5340_network.h>

#define page_size 0x1000

__attribute__((used))
uint32_t fd_flasher_erase_all(void) {
    while (!NRF_NVMC_NS->READY) {
    }

    NRF_NVMC_NS->CONFIG = 2; // EEN
    NRF_NVMC_NS->ERASEALL = 1;
    NRF_NVMC_NS->CONFIG = 0;

    return fd_flasher_status_success;
}

__attribute__((used))
uint32_t fd_flasher_erase(uint32_t address, uint32_t size) {
    if ((address & (page_size - 1)) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
    if ((size & (page_size - 1)) != 0) {
        return fd_flasher_status_invalid_parameter;
    }

    NRF_NVMC_NS->CONFIG = 4; // PEEN
    uint32_t *erase_address = (uint32_t *)address;
    uint32_t erase_size = size;
    while (erase_size != 0) {
        while (!NRF_NVMC_NS->READY) {
        }
        *erase_address = 0xffffffff;
        erase_address += page_size;
        erase_size -= page_size;
    }
    NRF_NVMC_NS->CONFIG = 0;

    return fd_flasher_status_success;
}

__attribute__((used))
uint32_t fd_flasher_write(uint32_t address, uint8_t *data, uint32_t size) {
    if ((address & 0x3) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
    if ((size & 0x3) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
        
    NRF_NVMC_NS->CONFIG = 1; // WEN
    uint32_t *write_address = (uint32_t *)address;
    uint32_t *write_data = (uint32_t *)data;
    uint32_t erase_size = size;
    while (erase_size-- != 0) {
        while (!NRF_NVMC_NS->READY) {
        }
        *write_address++ = *write_data++;
    }
    NRF_NVMC_NS->CONFIG = 0;

    return fd_flasher_status_success;
}

int main(void) {
    return 0;
}
