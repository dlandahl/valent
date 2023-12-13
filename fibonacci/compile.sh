
riscv64-unknown-elf-gcc -mabi=ilp32d -march=rv32g -mno-relax -nostdlib -nostartfiles -nodefaultlibs -ffreestanding -O2 -c -o hello_world.o hello_world.c

riscv64-unknown-elf-objcopy -O binary hello_world.o hello_world.bin
riscv64-unknown-elf-objdump -d hello_world.o
xxd -p -c 4 hello_world.bin hello_world.hex
