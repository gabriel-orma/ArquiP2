module dualfetchdecode(
  input         clk, reset,
  output [31:0] PCF,
  input  [31:0] Instr0F, Instr1F,  // de imem2 (2 puertos)
  output [31:0] Instr0D, Instr1D,
  output        RegWrite0D, RegWrite1D,
  output [2:0]  ALUControl0D, ALUControl1D,
  output [4:0]  Rs1_0D, Rs2_0D, Rd0D,
  output [4:0]  Rs1_1D, Rs2_1D, Rd1D
);

  wire [31:0] PCNextF, PCPlus8F;
  flopr #(32) pcreg(.clk(clk), .reset(reset), .d(PCNextF), .q(PCF));
  adder       pcadd8(.a(PCF), .b(32'd8), .y(PCPlus8F));
  assign PCNextF = PCPlus8F;

  flopr #(32) ff0(.clk(clk), .reset(reset), .d(Instr0F), .q(Instr0D));
  flopr #(32) ff1(.clk(clk), .reset(reset), .d(Instr1F), .q(Instr1D));

  assign Rs1_0D = Instr0D[19:15];  assign Rs2_0D = Instr0D[24:20];  assign Rd0D = Instr0D[11:7];
  assign Rs1_1D = Instr1D[19:15];  assign Rs2_1D = Instr1D[24:20];  assign Rd1D = Instr1D[11:7];

  wire [1:0] rs0, is0, rs1c, is1;
  wire       mw0, as0, j0, b0, mw1, as1, j1, b1;

  controller c0(
    .op(Instr0D[6:0]), .funct3(Instr0D[14:12]), .funct7b5(Instr0D[30]),
    .ResultSrc(rs0), .MemWrite(mw0), .ALUSrc(as0),
    .RegWrite(RegWrite0D), .Jump(j0), .Branch(b0),
    .ImmSrc(is0), .ALUControl(ALUControl0D)
  );
  controller c1(
    .op(Instr1D[6:0]), .funct3(Instr1D[14:12]), .funct7b5(Instr1D[30]),
    .ResultSrc(rs1c), .MemWrite(mw1), .ALUSrc(as1),
    .RegWrite(RegWrite1D), .Jump(j1), .Branch(b1),
    .ImmSrc(is1), .ALUControl(ALUControl1D)
  );
endmodule
