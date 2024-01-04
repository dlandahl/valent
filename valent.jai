
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
    // set_build_options_dc(.{do_output = false, append_linker_arguments = .["/STACK:5242880"]});

    copy_file("yosys/x64/Debug/yosys.dll", "modules/yosys.dll");
    copy_file("yosys/x64/Debug/yosys.lib", "modules/yosys.lib");
    copy_file("yosys/x64/Debug/yosys.dll", "yosys.dll");

    main();
}

main :: () {
    yosys_test();
    return;

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

    counter := rtlil_add_wire(module, "$counter", 5, 1, false, true);
    condition := rtlil_add_wire(module, "$condition", 1, 2, false, true);
    clock_wire := rtlil_add_wire(module, "$the_clock", 1, 3, true, false);

    process := rtlil_add_process(module, "$the_process", true, rtlil_signal_from_wire(clock_wire));
    rtlil_switch_test(module, process, rtlil_signal_from_wire(condition), rtlil_signal_from_wire(counter));

//    output_wire := rtlil_add_wire(module, "$the_output", 3, 1, false, true);
//    input_wire := rtlil_add_wire(module, "$the_input", 3, 2, true, false);
//
//    rtlil_connect_signals(
//        module,
//        rtlil_signal_from_wire(input_wire),
//        rtlil_signal_from_wire(output_wire),
//    );

    rtlil_finish_module(module);
    rtlil_done();

    yosys_run_pass("dump");
}
