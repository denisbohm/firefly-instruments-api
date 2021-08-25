#include <nrf5340_application.h>

int main(void) {
    NRF_CTRLAP_S->APPROTECT.DISABLE = 0x50fa50fa;
    NRF_CTRLAP_S->SECUREAPPROTECT.DISABLE = 1;
    return 0;
}
