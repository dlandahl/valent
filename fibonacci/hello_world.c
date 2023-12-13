
#include <stdint.h>

#define true 1

int main() {
    uint32_t f = 1, f_1 = 1, f_2 = 0;

    uint32_t *sequence = (uint32_t *)0x100;

    for (uint32_t n = 0; n < 20; n++) {
        sequence[n] = f;

        f = f_1 + f_2;
        f_2 = f_1;
        f_1 = f;
    }

    while (true);
}
