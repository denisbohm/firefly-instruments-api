#include <nrf5340_application.h>

#include <stdint.h>

#define failure 0xffffffff
#define success 0
#define invalid_parameter 1

#define page_size 0x1000

__attribute__((used))
uint32_t erase_all(void) {
    while (!NRF_NVMC_NS->READY) {
    }

    NRF_NVMC_NS->CONFIG = 2; // EEN
    NRF_NVMC_NS->ERASEALL = 1;
    NRF_NVMC_NS->CONFIG = 0;

    return success;
}

__attribute__((used))
uint32_t erase(uint32_t address, uint32_t size) {
    if ((address & (page_size - 1)) != 0) {
        return invalid_parameter;
    }
    if ((size & (page_size - 1)) != 0) {
        return invalid_parameter;
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

    return success;
}

__attribute__((used))
uint32_t write(uint32_t address, uint8_t *data, uint32_t size) {
    if ((address & 0x3) != 0) {
        return invalid_parameter;
    }
    if ((size & 0x3) != 0) {
        return invalid_parameter;
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

    return success;
}

int main(void) {
    return 0;
}
