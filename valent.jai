
#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "File_Utilities";

#import "Yosys";

#load "typecheck.jai";
#load "parse.jai";
// #load "verilog_backend.jai";
#load "rtlil_backend.jai";

#assert OS == .WINDOWS;

#run {
    set_build_options_dc(.{do_output = false});

    if !file_exists("yosys.dll")
        copy_file("modules/yosys.dll", "yosys.dll");

    main();
}

main :: () {

    tokens := tokenize(TEST);

    ast: *Ast_Node;
    ast = parse(tokens);

    if !context.parser.error {
        ast = typecheck(xx ast, top = "blink");
        generate(xx ast);

        // print(verilog);
    }
}

TEST :: #string END

blink :: chip (a: wire[4], b: wire) -> c: wire[5] {
    combinational c = a + 5 - b;
}

END;

yosys_test :: () {
    rtlil_initialise_design();
    module := rtlil_add_module("$test");

    output_wire := rtlil_add_wire(module, "$the_output", 3, 1, false, true);
    input_wire := rtlil_add_wire(module, "$the_input", 3, 2, true, false);

    rtlil_connect_signals(
        module,
        rtlil_signal_from_wire(input_wire),
        rtlil_signal_from_wire(output_wire),
    );

    rtlil_finish_module(module);
    rtlil_done();

    yosys_run_pass("write_verilog");
}
