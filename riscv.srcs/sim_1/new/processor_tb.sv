`timescale 1ns / 1ps

module processor_tb ( );
    reg clk = 0;
    reg reset = 0;
    always #10 clk <= ~clk;

    initial begin
        test_0 <= 0;
        test_1 <= 0;
        reset <= 1;
        #50;
        reset <= 0;
    end

    risc processor(.clk(clk), .reset(reset));

    reg [7:0] test_0;
    reg [7:0] test_1;
    wire [7:0] test_2 = test_1;

    always @ (posedge clk) begin
        test_0 <= test_0 + 1;
        test_1 <= test_0;
    end
endmodule
