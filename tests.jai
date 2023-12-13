
#import "Compiler";
#import "Basic";
#import "Process";
#import "File";


run :: (format_string: string, args: .. Any) -> bool {
    command := tprint(format_string, .. args);

    array := break_command_into_strings(command);
    result := run_command(.. array);

    return result.exit_code == 0;
}

#run {
    set_build_options_dc(.{do_output = false});

    make_directory_if_it_does_not_exist(".build");
    user_args := get_build_options().compile_time_command_line;

    for programs {
        using it;

        write_entire_file(tprint(".build/%.s", name), code);

        run("clang --target=riscv32 -march=rv32g -mno-relax .build/%1.s -c -o .build/%1.o", name);
        run("riscv64-unknown-elf-objcopy -O binary -j .text .build/%1.o .build/%1.bin", name);

        if user_args.count && name == user_args[0] {
            run("riscv64-unknown-elf-objdump .build/%.o -d", name);
        }

        binary := cast([] u8) read_entire_file(tprint(".build/%.bin", name));
        hex_data := format_hex_words(binary);

        write_entire_file(tprint("%.mem", name), hex_data);

        if user_args.count && name == user_args[0] {
            write_entire_file("vivado_project/riscv.srcs/sources_1/imports/riscv_llvm/program.mem", hex_data);
        }
    }
}

format_hex_words :: (binary: [] u8) -> string {
    bytes_needed := binary.count * 2 + binary.count / 4;

    builder: String_Builder;
    init_string_builder(*builder, bytes_needed);

    format: FormatInt;
    format.base = 16;
    format.minimum_digits = 8;

    words: [] u32;
    words.data = cast(*u32) binary.data;
    words.count = binary.count / 4;

    for words {
        format.value = it;
        print_integer(*builder, format);
        append(*builder, cast(u8) #char "\n");
    }

    return builder_to_string(*builder);
}

format_hex_bytes :: (binary: [] u8) -> string {
    bytes_needed := binary.count * 3 + binary.count;

    builder: String_Builder;
    init_string_builder(*builder, bytes_needed);

    format: FormatInt;
    format.base = 16;
    format.minimum_digits = 2;

    for binary {
        format.value = it;
        print_integer(*builder, format);

        do_newline := (it_index + 1) % 4 == 0;
        whitespace_char := cast(u8) ifx do_newline then #char "\n" else #char " ";
        append(*builder, whitespace_char);
    }

    return builder_to_string(*builder);
}

Program :: struct {
    name: string;
    code: string;
}

programs :: Program.[
    .{"load_store", load_store},
    .{"counter", counter},
];



load_store :: #string END

.global _start
.text

_start:
    la x3, data
    lb x2, 1(x3)
    la x1, result
    sb x2, 3(x1)

    lw  x2, 0(x3)
    lh  x2, 2(x3)
    lbu x2, 3(x3)
    lw  x2, 4(x3)
    lhu x2, 4(x3)
stop:
    jal stop

data:
    .word 0x82345678
    .word 0x9abcdef0

result:

END;



counter :: #string END

.global _start
.text

_start:
    li x1, 10
    li x2, 1

loop:
    addi x2, x2,  1
    blt  x2, x1,  loop

stop:
    jal  stop

END;
