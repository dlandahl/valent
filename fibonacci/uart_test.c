
#include "stdint.h"

enum uart_flags {
  UART_READY    = 1 << 8,
  UART_EXECUTE  = 1 << 9,
};

volatile uint64_t* const MMIO_SWITCHES = 0x100;
volatile uint64_t* const MMIO_LEDS     = 0x108;
volatile uint64_t* const MMIO_UART     = 0x110;
volatile uint64_t* const MMIO_BUTTONS  = 0x118;

const uint8_t* message = "Hello, Sailor!\n";

int main(void) {
  uint64_t leds;

  while (1) {
    leds += 1;
    *MMIO_LEDS = leds;

    for (int i = 0; i < 15; i++) {
      uint64_t byte = message[i];

      enum uart_flags flags = *MMIO_UART;
      while (!(flags & UART_READY)) {
        flags = *MMIO_UART;
      }

      *MMIO_UART = byte | UART_EXECUTE;
      *MMIO_LEDS = byte;
    }
  }

  return 0;
}
