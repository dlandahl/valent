
PROGRAM :: #string END
#program_export "main"
main :: () {
    f, f_1, f_2: u32 = 1, 1, 0;

    sequence: *u32 = cast(*u32)4;

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

#import "Compiler";

build :: () {
    workspace := compiler_create_workspace("RISC-V");

    options := get_build_options(workspace);
    options.output_type = .OBJECT_FILE;
    options.output_executable_name = "fibonacci";
    options.llvm_options.output_bitcode = true;
    options.cpu_target = .CUSTOM;
    set_optimization(*options, .OPTIMIZED_VERY_SMALL, true);
    set_build_options(options, workspace);

    add_build_string(PROGRAM, workspace);

    set_build_options_dc(.{do_output = false});
}

/*

  /mnt/c/jai/bin/jai-linux fibonacci.jai
  ~/llvm16/bin/llc -filetype=obj fibonacci.bc -o fibonacci.o -march riscv64
  riscv64-unknown-elf-objdump --disassemble=main fibonacci.o > fibonacci.objdump.txt

*/
