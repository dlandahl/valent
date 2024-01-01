
#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "File_Utilities";

#import "Yosys";

#load "typecheck.jai";
#load "parse.jai";
#load "verilog_backend.jai";
// #load "rtlil_backend.jai";

#assert OS == .WINDOWS;

#run {
    set_build_options_dc(.{do_output = false});

    if !file_exists("yosys.dll")
        copy_file("modules/yosys.dll", "yosys.dll");

    main();
}

main :: () {
    tokens := tokenize(TEST);

    ast := parse(tokens);

    if !context.parser.error {
        ast = typecheck(ast, top = "blink");
        verilog := generate(ast);

        print(verilog);
    }
}

TEST :: #string END

blink :: chip (clk: wire, reset: wire) -> led: flipflop {
    counter: flipflop[18];

    sequential(clk) if reset {
        counter <= 0;
        led <= 0;
    } else {
        counter <= counter + 1;

        if counter == 0 {
            led <= !led;
        }
    }
}

END;
