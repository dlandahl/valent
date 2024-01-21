
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Bit_Operations";

// #import "Yosys";

#load "runtime_shared.jai";
#load "typecheck.jai";
#load "parse.jai";
#load "verilog_backend.jai";
// #load "rtlil_backend.jai";

#run main();

main :: () {
    set_build_options_dc(.{do_output = false});

    tokens := tokenize(TEST_PROGRAM);
    ast := cast(*Ast_Node) parse(tokens);

    if !context.parser.error {
        ast = typecheck(xx ast, top = "switch_test");
        v := generate(xx ast);
        print("%\n", v);
    }
}

TEST_PROGRAM :: #string END

Test_Enum :: enum [3] {
    A; B; C; D; E; F; G;
}

switch_test :: chip (clock: wire, condition: wire[Test_Enum]) -> state: flipflop[3] {
    test: wire[Test_Enum];

    sequential (clock) switch condition {
         case Test_Enum.A state <= 4;
         case Test_Enum.B state <= Test_Enum.A;
         case Test_Enum.C state <= 2;
    }

    combinational test = Test_Enum.G;
}

END;

/*

inverter :: chip (clock: wire) -> f: wire {

    Test_Enum :: enum[5+5] {
        a :: 10;
        b; // 10'd11
        c; // 10'd12
        d :: 5;
    }

    ff: flipflop[Test_Enum];

    test: flipflop;
    counter: flipflop[10];

    sequential (clock) {
        {1'b0, counter} <= counter + 1;

        if (counter == 0) {
            test <= !test;
        }

        ff <= Test_Enum.a;
    }

    combinational f = test;
}

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
