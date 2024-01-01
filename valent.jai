
#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "File_Utilities";

#import "Yosys";

BACKEND: enum {
    VERILOG;
    RTLIL;
} : .VERILOG;

#load "typecheck.jai";
#load "parse.jai";

#if BACKEND == .VERILOG {
    #load "verilog_backend.jai";
} else {
    #load "rtlil_backend.jai";
}

#assert OS == .WINDOWS;

#run {
    set_build_options_dc(.{do_output = false});

    if !file_exists("yosys.dll")
        copy_file("modules/yosys.dll", "yosys.dll");

    main();
}

main :: () {
    file := read_entire_file("examples/simple.valent");

    tokens := tokenize(file);
    ast := parse(tokens);

    if !context.parser.error {
        top := compile(ast, "Blinky");
        verilog := generate(top);

        print(verilog);
    }
}
