// riscvsingle pipelined: une el controller (decodifica en ID) con el datapath.
// El datapath expone InstrD (la instruccion en Decode) para que el controller
// la decodifique; las senales de control vuelven al datapath para propagarse.
// La interfaz externa es la MISMA que el single-cycle (para no tocar 'top').
module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output        MemWrite,
                   output [31:0] DataAdr,
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  // senales de control en etapa D
  wire [1:0] ResultSrcD, ImmSrcD;
  wire [2:0] ALUControlD;
  wire       MemWriteD, ALUSrcD, RegWriteD, JumpD, BranchD;
  // instruccion en Decode (del datapath al controller)
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
