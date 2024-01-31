

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

    generate_verilog(p, "top");
    create_rtlil_design(p, "top");
}

TEST_PROGRAM :: #string END

Top :: module (clock: wire) {
    inverted: wire;
    inner: Inner(clock) -> inverted;
}

Inner :: module (input: wire) -> output: wire {
    combinational output = !input;
}

END;
