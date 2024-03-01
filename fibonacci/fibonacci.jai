
PROGRAM :: #string END

MMIO_SWITCHES :: cast(*u64) 0x100;
MMIO_LEDS     :: cast(*u64) 0x108;
MMIO_UART     :: cast(*Uart_Control) 0x110;
MMIO_BUTTONS  :: cast(*u64) 0x118; // Up left down right

Uart_Control :: union {
    data: u8;

    flags: enum_flags u64 {
        READY     :: 1 << 8; // Asserted by hardware when nothing is currently being transferred
        EXECUTE   :: 1 << 9; // Asserted by software when transfer should start
    }
}

#program_export
main :: () {
    while true {
        byte := cast,trunc(u8) MMIO_SWITCHES.*;

        flags := MMIO_UART.flags;
        while !(flags & .READY) {
            flags = MMIO_UART.flags;
        }

        MMIO_UART.* = .{
            byte = byte,
            flags = .EXECUTE,
        };
    }
}

// #program_export __muldi3 :: () {}
#program_export memset :: () {}
#program_export to_string :: () {}

END;

#run build();

UART_TEST :: true;

#assert OS == .LINUX;

#import "Compiler";
#import "Process";
#import "File";
#import "Basic";

build :: () {
    workspace := compiler_create_workspace("RISC-V");

    make_directory_if_it_does_not_exist(".build");

    options := get_build_options(workspace);
    options.output_type = .OBJECT_FILE;
    options.output_executable_name = "fibonacci";
    options.llvm_options.output_bitcode = true;
    options.llvm_options.function_sections = true;
    options.import_path = .["risc-v_modules"];

    options.cpu_target = .CUSTOM;
    options.entry_point_name = "main";
    options.output_path = ".build";

    set_optimization(*options, .OPTIMIZED_VERY_SMALL, true);
    set_build_options(options, workspace);

    compiler_begin_intercept(workspace);
    add_build_string(PROGRAM, workspace);

    while true {
        msg := compiler_wait_for_message();
        if msg.kind == .COMPLETE break;
    }

    compiler_end_intercept(workspace);

    #if !UART_TEST {
        // run("/home/dlandahl/llvm16/bin/opt .build/fibonacci.bc -o .build/fibonacci_opt.bc --Oz");
        run("/home/dlandahl/llvm16/bin/llc -filetype=obj .build/fibonacci.bc -o .build/fibonacci.o -march riscv64 --function-sections --O2");
        run("riscv64-unknown-elf-ld -T linker.lds -o .build/linked.o .build/fibonacci.o");
        run("riscv64-unknown-elf-objcopy -O binary .build/linked.o .build/result.bin");
    }

    else {
        run("riscv64-unknown-elf-gcc -mabi=lp64 -march=rv64i -mno-relax -nostdlib -nostartfiles -nodefaultlibs -ffreestanding -O2 -c -o .build/uart_test.o uart_test.c");
        run("riscv64-unknown-elf-ld -T linker.lds -o .build/linked.o .build/uart_test.o");
        run("riscv64-unknown-elf-objcopy -O binary .build/linked.o .build/result.bin");
    }

    binary := cast([] u8) read_entire_file(".build/linked.bin");
    hex_data := format_hex_words(binary);

    write_entire_file("program.mem", hex_data);
    run("riscv64-unknown-elf-objdump -D .build/linked.o");

    set_build_options_dc(.{do_output = false});
}

format_hex_words :: (binary: [] u8) -> string {
    bytes_needed := binary.count * 2 + binary.count / 4;

    builder: String_Builder;
    init_string_builder(*builder, bytes_needed);

    format: FormatInt;
    format.base = 16;
    format.minimum_digits = 16;

    words: [] u64;
    words.data = cast(*u64) binary.data;
    words.count = (binary.count+8) / 8;

    for words {
        format.value = it;
        print_integer(*builder, format);
        append(*builder, cast(u8) #char "\n");
    }

    return builder_to_string(*builder);
}

run :: (format_string: string, args: .. Any) -> bool {
    command := tprint(format_string, .. args);

    array := break_command_into_strings(command);
    result := run_command(.. array);

    return result.exit_code == 0;
}
