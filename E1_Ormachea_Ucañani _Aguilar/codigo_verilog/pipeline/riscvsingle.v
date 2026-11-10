module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  wire [1:0] ResultSrcD, ImmSrcD;
  wire [2:0] ALUControlD;
  wire       MemWriteD, ALUSrcD, RegWriteD, JumpD, BranchD;
  wire [31:0] InstrD;

  controller c(
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .ALUSrc(ALUSrcD),
    .RegWrite(RegWriteD),
    .Jump(JumpD),
    .Branch(BranchD),
    .ImmSrc(ImmSrcD),
    .ALUControl(ALUControlD)
  );

  datapath dp(
    .clk(clk), .reset(reset),
    .ResultSrcD(ResultSrcD), .MemWriteD(MemWriteD), .ALUSrcD(ALUSrcD),
    .RegWriteD(RegWriteD), .JumpD(JumpD), .BranchD(BranchD),
    .ALUControlD(ALUControlD), .ImmSrcD(ImmSrcD),
    .PCF(PC), .InstrF(Instr),
    .InstrD(InstrD),
    .MemWriteM(MemWrite), .ALUResultM(DataAdr), .WriteDataM(WriteData), .ReadDataM(ReadData)
  );
endmodule
