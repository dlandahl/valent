
`timescale 1ns / 1ps

module Block_Ram (
    input clk,
    input wr_en,
    input [31:0] addr,
    input [7:0] data_in,
    output reg [7:0] data_out,
    output reg [31:0] data_out32
  );

    reg [7:0] memory [0:'h1000];

    initial begin
       $readmemh("program.mem", memory);
    end

    always @ (posedge clk) begin
        if (wr_en == 1)
            memory[addr] <= data_in;

        data_out <= memory[addr];

        data_out32 <= { 
            memory[addr + 3], 
            memory[addr + 2],
            memory[addr + 1],
            memory[addr]
        };
    end
endmodule

module risc (
    input clk,
    input reset,
    output reg [0:0] led,
    output reg [31:0] data_out
  );

    integer i;

    parameter GPR_COUNT = 32;
    parameter WORD_SIZE = 32;

    reg [WORD_SIZE-1:0] gpr [0:GPR_COUNT-1];
    reg [WORD_SIZE-1:0] pc;

    reg [31:0] ram_data32;
    reg [7:0] ram_data;
    reg [WORD_SIZE-1:0] ram_addr;

    Block_Ram ram(.clk(clk), .data_out(ram_data), .data_out32(ram_data32), .addr(ram_addr));

    reg [2:0] current_stage;

    parameter STAGE_FETCH = 0;
    parameter STAGE_DECODE = 1;
    parameter STAGE_EXECUTE = 2;
    parameter STAGE_MEMORY = 3;

    parameter OPCODE_LOAD   = 7'b00_000_11;
    parameter OPCODE_STORE  = 7'b01_000_11;
    parameter OPCODE_BRANCH = 7'b11_000_11;
    parameter OPCODE_OP_IMM = 7'b00_100_11;
    parameter OPCODE_OP     = 7'b01_100_11;
    parameter OPCODE_JAL    = 7'b11_011_11;
    parameter OPCODE_JALR   = 7'b11_001_11;

    reg [WORD_SIZE-1:0] inst;
    reg [WORD_SIZE-1:0] last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data32 : last_inst;

    wire [6:0] opcode = inst[6:0];
    wire [4:0] rd     = inst[11:7];
    wire [2:0] funct  = inst[14:12];
    wire [4:0] rs1    = inst[19:15];
    wire [4:0] rs2    = inst[24:20];

    wire [WORD_SIZE-1:0] imm_i = { { 21{inst[31]} }, inst[30:20] };
    wire [WORD_SIZE-1:0] imm_s = { { 21{inst[31]} }, inst[30:25], inst[11:7] };
    wire [WORD_SIZE-1:0] imm_b = { { 20{inst[31]} }, inst[7], inst[30:25], inst[11:8], 1'b0 };
    wire [WORD_SIZE-1:0] imm_u = { inst[31:12], 13'b0 };
    wire [WORD_SIZE-1:0] imm_j = { { 12{inst[31]} }, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0 };

    reg [WORD_SIZE-1:0] op_param_a;
    reg [WORD_SIZE-1:0] op_param_b;

    wire funct7 = (opcode == OPCODE_OP_IMM ? imm_i[10:10] : 1'b0);

    parameter FUNCT_OP_ADD_SUB = 3'b000;
    parameter FUNCT_OP_SLL     = 3'b001;
    parameter FUNCT_OP_SLT     = 3'b010;
    parameter FUNCT_OP_SLTU    = 3'b011;
    parameter FUNCT_OP_XOR     = 3'b100;
    parameter FUNCT_OP_SRL_SRA = 3'b101;
    parameter FUNCT_OP_OR      = 3'b110;
    parameter FUNCT_OP_AND     = 3'b111;

    reg [WORD_SIZE-1:0] alu_result;

    always @ (*) begin
        if (opcode == OPCODE_OP || opcode == OPCODE_OP_IMM) case (funct)
            FUNCT_OP_ADD_SUB: alu_result = funct7 ? (op_param_a - op_param_b)
                                              : (op_param_a +   op_param_b);
            FUNCT_OP_SLL:     alu_result      =  op_param_a <<  op_param_b;
            FUNCT_OP_SLT:     alu_result[0:0] =  $signed(op_param_a < op_param_b);
            FUNCT_OP_SLTU:    alu_result[0:0] =  op_param_a <   op_param_b;
            FUNCT_OP_XOR:     alu_result      =  op_param_a ^   op_param_b;
            FUNCT_OP_SRL_SRA: alu_result      = funct7 ? (op_param_a >> op_param_b)
                                              : (op_param_a >>> op_param_b);
            FUNCT_OP_OR:      alu_result      =  op_param_a |   op_param_b;
            FUNCT_OP_AND:     alu_result      =  op_param_a &   op_param_b;
        endcase
    end

    reg [11:0] branch_offset;

    parameter FUNCT_BRANCH_BEQ  = 3'b000;
    parameter FUNCT_BRANCH_BNE  = 3'b001;
    parameter FUNCT_BRANCH_BLT  = 3'b010;
    parameter FUNCT_BRANCH_BGE  = 3'b011;
    parameter FUNCT_BRANCH_BLTU = 3'b100;
    parameter FUNCT_BRANCH_BGEU = 3'b101;

    always @ (*) begin
        if (opcode == OPCODE_BRANCH) case (funct)
            FUNCT_BRANCH_BEQ:   alu_result = op_param_a == op_param_b;
            FUNCT_BRANCH_BNE:   alu_result = op_param_a != op_param_b;
            FUNCT_BRANCH_BLT:   alu_result = $signed(op_param_a <  op_param_b);
            FUNCT_BRANCH_BGE:   alu_result = $signed(op_param_a >= op_param_b);
            FUNCT_BRANCH_BLTU:  alu_result = op_param_a <  op_param_b;
            FUNCT_BRANCH_BGEU:  alu_result = op_param_a >= op_param_b;
        endcase
    end

    wire [2:0] debug_stage = (current_stage == 0 ? 2 : (current_stage - 1));

    always @ (posedge clk) if (reset) begin
        current_stage <= 0;
        pc <= 0;
        ram_addr <= 0;

        for (i = 0; i < GPR_COUNT; i = i + 1)
            gpr[i] <= 0;
    end else begin

        current_stage <= current_stage + 1;

        case (current_stage)
          STAGE_FETCH: begin
          end

          STAGE_DECODE: begin
            last_inst <= ram_data32;

            op_param_a <= gpr[rs1];
            op_param_b <= gpr[rs2];

            if (opcode == OPCODE_OP_IMM)
                op_param_b <= imm_i;
          end

          STAGE_EXECUTE: begin
            if (opcode == OPCODE_OP_IMM || opcode == OPCODE_OP)
                gpr[rd] <= alu_result;

            else if (opcode == OPCODE_BRANCH) begin
                if (alu_result) pc <= $signed(pc + imm_b - 4);
            end

            else if (opcode == OPCODE_JAL) begin
                pc <= $signed(pc + imm_j - 4);
                gpr[rd] <= pc + 4;
            end

            else if (opcode == OPCODE_JALR) begin
                pc <= $signed(pc + imm_i + op_param_a - 4);
                gpr[rd] <= pc + 4;
            end
          end

          STAGE_MEMORY: begin
            current_stage <= 0;

            ram_addr <= pc;
            pc <= pc + 4;
          end
        endcase
    end
endmodule
