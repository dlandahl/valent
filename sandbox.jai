
#import "Valent";

#if OS != .LINUX {
    #import "Yosys";
}

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

    // uart := read_entire_file("examples/uart.valent");
    p, success := compile(TEST_PROGRAM);
    if !success return;

    if !generate_verilog(p, "Top") print("Top is wrong\n");
    #if OS != .LINUX create_rtlil_design(p, "Top");
}

TEST_PROGRAM :: #string END

Hamming :: register {
    data[11];
    parity[4];
}

Test :: enum [11] {
    a; b; c; d; a; f; g; h; i;
}

Top :: module (clock: wire, index: wire[9]) -> out: flipflop[Test] {
    ram: [512] memory[Test];

    sequential (clock) {
        out <= ram[index];
    }
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
