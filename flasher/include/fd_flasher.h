#ifndef fd_flasher_h
#define fd_flasher_h

#include <stdint.h>

typedef enum {
     fd_flasher_status_success = 0,
     fd_flasher_status_failure = 1,
     fd_flasher_status_invalid_parameter = 2,
     fd_flasher_status_unimplemented = 3,
} fd_flasher_status_t;

__attribute__((used))
uint32_t fd_flasher_erase_all(void);

__attribute__((used))
uint32_t fd_flasher_erase(uint32_t address, uint32_t size);

__attribute__((used))
uint32_t fd_flasher_write(uint32_t address, uint8_t *data, uint32_t size);

#endif
