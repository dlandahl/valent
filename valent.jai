
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";

// #import "Yosys";

#load "typecheck.jai";
#load "parse.jai";
#load "verilog_backend.jai";
// #load "rtlil_backend.jai";

// #assert OS == .WINDOWS;

#run main();

main :: () {

    tokens := tokenize(TEST_PROGRAM);
    ast := cast(*Ast_Node) parse(tokens);

    if !context.parser.error {
        ast = typecheck(xx ast, top = "blink");
        v := generate(xx ast);
        print(v);
    }
}

TEST_PROGRAM :: #string END

blink :: chip (input: wire[2], clock: wire, enable: wire) -> result: flipflop {
    sequential (clock) if enable {
        { result, result, 1'b0 } <= { input - 5, 1'b1 };

        generate {
            print("Hello, World!\n");
            print("Something else\n");
        }
    }
}

END;

/*

yosys_test :: () {
    rtlil_initialise_design();
    module := rtlil_add_module("$test");

    counter := rtlil_add_wire(module, "$counter", 5, 1, false, true);
    condition := rtlil_add_wire(module, "$condition", 1, 2, false, true);
    clock_wire := rtlil_add_wire(module, "$the_clock", 1, 3, true, false);

    process := rtlil_add_process(module, "$the_process", true, clock_wire);
    rtlil_switch_test(module, process, condition, counter);

//    output_wire := rtlil_add_wire(module, "$the_output", 3, 1, false, true);
//    input_wire := rtlil_add_wire(module, "$the_input", 3, 2, true, false);
//
//    rtlil_connect_signals(
//        module,
//        input_wire,
//        output_wire,
//    );

    rtlil_finish_module(module);
    rtlil_done();

    yosys_run_pass("dump");
}

*/
