
`timescale 1ns / 1ps

module Block_Ram (
    input             clk,
    input             wr_en,
    input [1:0]       write_width,
    input [31:0]      data_in,
    input [31:0]      addr,
    output reg [31:0] data_out
  );

    reg [7:0] memory [0:'h1000];

    initial begin
       $readmemh("program.mem", memory);
    end

    always @ (posedge clk) begin
        if (wr_en == 1) begin
            memory[addr] <= data_in[7:0];
            if (write_width > 0) memory[addr+1] <= data_in[15:8];
            if (write_width > 1) begin
                memory[addr+2] <= data_in[23:16];
                memory[addr+3] <= data_in[31:24];
            end
        end

        data_out <= { 
            memory[addr+3], 
            memory[addr+2],
            memory[addr+1],
            memory[addr]
        };
    end
endmodule

module risc (
    input clk,
    input reset,
    output reg [15:0] led
  );

    integer i;

    parameter GPR_COUNT = 32;
    parameter WORD_SIZE = 32;

    reg [WORD_SIZE-1:0] gpr [0:GPR_COUNT-1];
    reg [WORD_SIZE-1:0] pc;

    assign led = gpr[13][15:0];

    reg [31:0] ram_data;
    reg [31:0] ram_data_in;
    reg [1:0]  ram_write_width;
    reg        ram_wr_en;
    reg [WORD_SIZE-1:0] ram_addr;

    Block_Ram ram(.clk(clk), .data_out(ram_data), .data_in(ram_data_in), .addr(ram_addr), .write_width(ram_write_width), .wr_en(ram_wr_en));

    reg [2:0] current_stage;

    parameter STAGE_FETCH = 0;
    parameter STAGE_DECODE = 1;
    parameter STAGE_EXECUTE = 2;
    parameter STAGE_MEMORY = 3;
    parameter STAGE_WRITEBACK = 4;

    parameter OPCODE_AUIPC  = 7'b00_101_11;
    parameter OPCODE_LUI    = 7'b01_101_11;
    parameter OPCODE_LOAD   = 7'b00_000_11;
    parameter OPCODE_STORE  = 7'b01_000_11;
    parameter OPCODE_OP_IMM = 7'b00_100_11;
    parameter OPCODE_OP     = 7'b01_100_11;
    parameter OPCODE_BRANCH = 7'b11_000_11;
    parameter OPCODE_JALR   = 7'b11_001_11;
    parameter OPCODE_JAL    = 7'b11_011_11;

    reg [WORD_SIZE-1:0] inst;
    reg [WORD_SIZE-1:0] last_inst;
    assign inst = (current_stage == STAGE_DECODE) ? ram_data : last_inst;

    wire [6:0] opcode = inst[6:0];
    wire [4:0] rd     = inst[11:7];
    wire [2:0] funct  = inst[14:12];
    wire [4:0] rs1    = inst[19:15];
    wire [4:0] rs2    = inst[24:20];

    wire [WORD_SIZE-1:0] imm_i = { { 21{inst[31]} }, inst[30:20] };
    wire [WORD_SIZE-1:0] imm_s = { { 21{inst[31]} }, inst[30:25], inst[11:7] };
    wire [WORD_SIZE-1:0] imm_b = { { 20{inst[31]} }, inst[7], inst[30:25], inst[11:8], 1'b0 };
    wire [WORD_SIZE-1:0] imm_u = { inst[31:12], 12'b0 };
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

    parameter FUNCT_BRANCH_BEQ  = 3'b000;
    parameter FUNCT_BRANCH_BNE  = 3'b001;
    parameter FUNCT_BRANCH_BLT  = 3'b010;
    parameter FUNCT_BRANCH_BGE  = 3'b011;
    parameter FUNCT_BRANCH_BLTU = 3'b100;
    parameter FUNCT_BRANCH_BGEU = 3'b101;

    parameter FUNCT_LOAD_LB   = 3'b000;
    parameter FUNCT_LOAD_LH   = 3'b001;
    parameter FUNCT_LOAD_LW   = 3'b010;
    parameter FUNCT_LOAD_LBU  = 3'b100;
    parameter FUNCT_LOAD_LHU  = 3'b101;

    parameter FUNCT_STORE_SB   = 3'b000;
    parameter FUNCT_STORE_SH   = 3'b001;
    parameter FUNCT_STORE_SW   = 3'b010;

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
            pc <= pc + 4;
          end

          STAGE_DECODE: begin
            last_inst <= ram_data;

            op_param_a <= gpr[rs1];
            op_param_b <= gpr[rs2];

            if (opcode == OPCODE_OP_IMM)
                op_param_b <= imm_i;
          end

          STAGE_EXECUTE: begin
            case (opcode)
              OPCODE_LUI:
                  gpr[rd] <= imm_u;

              OPCODE_AUIPC:
                  gpr[rd] <= imm_u + pc;

              OPCODE_OP_IMM, OPCODE_OP:
                  gpr[rd] <= alu_result;

              OPCODE_BRANCH:
                  if (alu_result) pc <= $signed(pc + imm_b - 4);

              OPCODE_JAL: begin
                  pc <= $signed(pc + imm_j - 4);
                  gpr[rd] <= pc + 4;
              end

              OPCODE_JALR: begin
                  pc <= $signed(pc + imm_i + op_param_a - 4);
                  gpr[rd] <= pc + 4;
              end

              OPCODE_LOAD:
                  ram_addr <= op_param_a + imm_i;

              OPCODE_STORE: begin
                  ram_addr <= op_param_a + imm_s;
                  ram_write_width <= funct;
                  ram_wr_en <= 1;
                  ram_data_in <= op_param_b;
              end
            endcase
          end

          STAGE_MEMORY: begin
          end

          STAGE_WRITEBACK: begin
            ram_wr_en <= 0;

            if (opcode == OPCODE_LOAD)
                case (funct)
                  FUNCT_LOAD_LB:  gpr[rd][7:0] <= ram_data[7:0];
                  FUNCT_LOAD_LH:  gpr[rd] <= { { 16{ram_data[15:15]} }, ram_data[15:0] };
                  FUNCT_LOAD_LW:  gpr[rd] <= ram_data;
                  FUNCT_LOAD_LBU: gpr[rd] <= { 24'b0, ram_data[7:0] };
                  FUNCT_LOAD_LHU: gpr[rd] <= { 16'b0, ram_data[15:0] };
                endcase

            current_stage <= 0;

            ram_addr <= pc;
          end
        endcase
    end
endmodule






/*

RV32I
[x] LUI
[x] AUIPC
[x] JAL
[x] JALR
[x] BEQ
[x] BNE
[x] BLT
[x] BGE
[x] BLTU
[x] BGEU
[x] LB
[x] LH
[x] LW
[x] LBU
[x] LHU
[x] SB
[x] SH
[x] SW
[x] ADDI
[x] SLTI
[x] SLTIU
[x] XORI
[x] ORI
[x] ANDI
[ ] SLLI
[ ] SRLI
[ ] SRAI
[x] ADD
[x] SUB
[x] SLL
[x] SLT
[x] SLTU
[x] XOR
[x] SRL
[x] SRA
[x] OR
[x] AND
[ ] FENCE
[ ] FENCE.I
[ ] ECALL
[ ] EBREAK
[ ] CSRRW
[ ] CSRRS
[ ] CSRRC
[ ] CSRRWI
[ ] CSRRSI
[ ] CSRRCI

 */
