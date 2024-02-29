
#include "stdint.h"

enum uart_flags {
  READY    = 1,
  EXECUTE  = 2,
};

struct uart {
  uint64_t byte;
  union {
    enum uart_flags flags;
    uint64_t pad;
  };
};

volatile uint64_t* const MMIO_SWITCHES = 0x100;
volatile uint64_t* const MMIO_LEDS     = 0x108;
volatile struct uart* const MMIO_UART  = 0x110;
volatile uint64_t* const MMIO_BUTTONS  = 0x120;

int main(void) {
  while (1) {
    if (!*MMIO_BUTTONS) continue;
    uint8_t byte = *MMIO_SWITCHES;

    enum uart_flags flags = MMIO_UART->flags;
    while (!(flags & READY)) {
      flags = MMIO_UART->flags;
    }

    MMIO_UART->byte = byte;
    MMIO_UART->flags = EXECUTE;
  }

  return 0;
}
