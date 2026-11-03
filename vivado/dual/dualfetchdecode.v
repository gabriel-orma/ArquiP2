// dualfetchdecode -- FRONT-END dual-issue PRELIMINAR para E1.
//
// Objetivo de E1: demostrar que la parte de adelante del pipeline se puede
// DUPLICAR: traer 2 instrucciones por ciclo (dual fetch) y decodificarlas en
// paralelo con 2 controllers (dual decode).
//
// IMPORTANTE (alcance E1): esto es un BOCETO. NO tiene Issue Unit, NO decide
// cuantas emitir, NO maneja hazards entre las 2 vias, NO ejecuta. El PC avanza
// +8 de forma secuencial (sin saltos). Todo eso (la parte dificil) es E2.
//
// Reutiliza el modulo 'controller' del pipeline single-issue (instanciado 2 veces).
module dualfetchdecode(
  input         clk, reset,
  output [31:0] PCF,
  input  [31:0] Instr0F, Instr1F,     // de imem2 (2 puertos)
  // --- resultados del decode de cada via (lo que se expone del boceto) ---
  output [31:0] Instr0D, Instr1D,
  output        RegWrite0D, RegWrite1D,
  output [2:0]  ALUControl0D, ALUControl1D,
  output [4:0]  Rs1_0D, Rs2_0D, Rd0D,
  output [4:0]  Rs1_1D, Rs2_1D, Rd1D
);

  // ===================== DUAL FETCH (F) =====================
  wire [31:0] PCNextF, PCPlus8F;
  // PC secuencial: avanza +8 (dos instrucciones) por ciclo. Sin saltos (boceto).
  flopr #(32) pcreg(.clk(clk), .reset(reset), .d(PCNextF), .q(PCF));
  adder       pcadd8(.a(PCF), .b(32'd8), .y(PCPlus8F));
  assign PCNextF = PCPlus8F;

  // ============== registro IF/ID (2 instrucciones) ==============
  flopr #(32) ff0(.clk(clk), .reset(reset), .d(Instr0F), .q(Instr0D));
  flopr #(32) ff1(.clk(clk), .reset(reset), .d(Instr1F), .q(Instr1D));

  // ===================== DUAL DECODE (D) =====================
  // campos de registro de cada instruccion
  assign Rs1_0D = Instr0D[19:15];  assign Rs2_0D = Instr0D[24:20];  assign Rd0D = Instr0D[11:7];
  assign Rs1_1D = Instr1D[19:15];  assign Rs2_1D = Instr1D[24:20];  assign Rd1D = Instr1D[11:7];

  // control de cada via (seniales que no usamos en el boceto quedan sin cablear)
  wire [1:0] rs0, is0, rs1c, is1;
  wire       mw0, as0, j0, b0, mw1, as1, j1, b1;

  // via 0
  controller c0(
    .op(Instr0D[6:0]), .funct3(Instr0D[14:12]), .funct7b5(Instr0D[30]),
    .ResultSrc(rs0), .MemWrite(mw0), .ALUSrc(as0),
    .RegWrite(RegWrite0D), .Jump(j0), .Branch(b0),
    .ImmSrc(is0), .ALUControl(ALUControl0D)
  );
  // via 1
  controller c1(
    .op(Instr1D[6:0]), .funct3(Instr1D[14:12]), .funct7b5(Instr1D[30]),
    .ResultSrc(rs1c), .MemWrite(mw1), .ALUSrc(as1),
    .RegWrite(RegWrite1D), .Jump(j1), .Branch(b1),
    .ImmSrc(is1), .ALUControl(ALUControl1D)
  );
endmodule
