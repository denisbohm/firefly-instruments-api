#include "fd_flasher.h"

#include "Kinetis.h"
#include "CMSIS/system_MKL03Z4.c"

__attribute__((used))
void fd_flasher_halt(void) {
    __asm("BKPT   #0");
}

#define page_size 0x400

__attribute__((used))
uint32_t fd_flasher_erase_all(void) {
    while ((FTFA->FSTAT & FTFA_FSTAT_CCIF_MASK) == 0) {
    }

    FTFA->FCCOB0 = 0x49; // Erase All Blocks Unsecure
    FTFA->FSTAT |= FTFA_FSTAT_CCIF_MASK;

    return fd_flasher_status_success;
}

__attribute__((used))
uint32_t fd_flasher_erase(uint32_t address, uint32_t size) {
    return fd_flasher_status_unimplemented;
#if 0
    if ((address & (page_size - 1)) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
    if ((size & (page_size - 1)) != 0) {
        return fd_flasher_status_invalid_parameter;
    }

    uint32_t erase_address = address;
    uint32_t erase_size = size;
    while (erase_size != 0) {
        while ((FTFA->FSTAT & FTFA_FSTAT_CCIF_MASK) == 0) {
        }

        FTFA->FCCOB0 = 0x09; // Erase Flash Sector
        FTFA->FCCOB1 = (erase_address >> 16) & 0xff;
        FTFA->FCCOB2 = (erase_address >> 8) & 0xff;
        FTFA->FCCOB3 = erase_address & 0xff;
        FTFA->FSTAT |= FTFA_FSTAT_CCIF_MASK;

        erase_address += page_size;
        erase_size -= page_size;
    }

    return fd_flasher_status_success;
#endif
}

__attribute__((used))
uint32_t fd_flasher_write(uint32_t address, uint8_t *data, uint32_t size) {
    if ((address & 0x3) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
    if ((size & 0x3) != 0) {
        return fd_flasher_status_invalid_parameter;
    }
        
    uint32_t write_address = address;
    uint8_t *write_data = data;
    uint32_t erase_size = size;
    while (erase_size != 0) {
        while ((FTFA->FSTAT & FTFA_FSTAT_CCIF_MASK) == 0) {
        }

        FTFA->FCCOB0 = 0x06; // Program Longword
        FTFA->FCCOB1 = (write_address >> 16) & 0xff;
        FTFA->FCCOB2 = (write_address >> 8) & 0xff;
        FTFA->FCCOB3 = write_address & 0xff;
        FTFA->FCCOB4 = (*write_data++ >> 24) & 0xff;
        FTFA->FCCOB5 = (*write_data++ >> 16) & 0xff;
        FTFA->FCCOB6 = (*write_data++ >> 8) & 0xff;
        FTFA->FCCOB7 = *write_data++ & 0xff;
        FTFA->FSTAT |= FTFA_FSTAT_CCIF_MASK;

        write_address++;
        erase_size -= 4;
    }

    return fd_flasher_status_success;
}

int main(void) {
    const void *used[] = {
        fd_flasher_halt,
        fd_flasher_erase_all,
        fd_flasher_erase,
        fd_flasher_write
    };
    int total = 0;
    for (int i = 0; i < sizeof(used) / sizeof(used[0]); ++i) {
        total += (int)used[i];
    }
    return total;
}
