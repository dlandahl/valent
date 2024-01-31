

#import "Valent";

#import "Compiler";
#import "Basic";
#import "File";
#import "String";
#import "Command_Line";

#run {
    set_build_options_dc(.{do_output = false});

    p, success := compile(TEST_PROGRAM);
    if !success return;

    generate_verilog(p, "Top");
    create_rtlil_design(p, "Top");
}

TEST_PROGRAM :: #string END

Test :: register { a; b; c[2]; d; }

Top :: module (clock: wire) {
    thing: flipflop[Test];
    stuff: flipflop[4];

    sequential (clock) {
        stuff <=,trunc 2 # (thing.c);
        thing <= 5'b0;
    }
}

Inner :: module (input: wire) -> output: wire {
    combinational output = !input;
}

END;
