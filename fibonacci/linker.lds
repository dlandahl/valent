
ENTRY(main)

SECTIONS {
    . = 0x0000;
    .text : {
        *(.text.main*);
        *(.text.startup*);
        *(.text*);
    }
    .bss : {.*}
}
