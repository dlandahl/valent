
#import "Valent";
#import "Yosys";

#import "Compiler";
#import "Basic";
#import "File";
#import "String";
#import "Command_Line";

#run {
    set_build_options_dc(.{do_output = false});

    // write_entire_file("test.v", VERILOGTEST_PROGRAM);
    // rtlil_initialise_design();
    // run_yosys_command("read_verilog test.v");
    // run_yosys_command("dump");
    // return;

    p, success := compile(TEST_PROGRAM);
    if !success return;

    generate_verilog(p, "Top");
    create_rtlil_design(p, "Top");
}

TEST_PROGRAM :: #string END

Top :: module (clock: wire, a: wire) -> out: wire {
    inv: Inverter(a, a) -> out;
}

Inverter :: module (in: wire) -> out: wire {
    combinational { out = !in; }
}

END;


VERILOG_TEST_PROGRAM :: #string END

module something ();

  wire clock;
  wire condition;
  reg [9:0] x;

  reg [2:0] src_a;
  reg [2:0] src_b;

  wire something;

  always @ (posedge clock) begin
    if (condition) { x, something } <= { 12{src_a + src_b} };

    else             x[9:5]              <= 1;
  end

endmodule

END;
