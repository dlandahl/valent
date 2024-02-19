
PROGRAM :: #string END
#program_export
main :: () {
    f, f_1, f_2: u64 = 1, 1, 0;

    sequence: *u64 = cast(*u64)8;

    for 0..29 {
        sequence[it] = f;

        f = f_1 + f_2;
        f_2 = f_1;
        f_1 = f;
    }

    while true {}
}
END;

#run build();

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

    run("llc -filetype=obj .build/fibonacci.bc -o .build/fibonacci.o -march riscv64 --function-sections");
    run("riscv64-unknown-elf-ld -T linker.lds -o .build/fibonacci_linked.o .build/fibonacci.o");
    run("riscv64-unknown-elf-objcopy -O binary .build/fibonacci_linked.o .build/fibonacci.bin");

    binary := cast([] u8) read_entire_file(".build/fibonacci.bin");
    hex_data := format_hex_words(binary);

    write_entire_file("program.mem", hex_data);
    run("riscv64-unknown-elf-objdump --disassemble=main .build/fibonacci_linked.o");

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
    words.count = binary.count / 8;

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
