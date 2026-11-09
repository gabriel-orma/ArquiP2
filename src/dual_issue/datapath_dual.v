// datapath_dual: datapath del procesador SUPERESCALAR dual-issue IN-ORDER (E2).
//
// ====================== VISION GENERAL ======================
// 4 etapas: F/D (fetch+decode+issue, COMBINACIONAL) -> E -> M -> W.
// Dos VIAS paralelas (via 0 = la mas vieja del par, via 1 = la siguiente).
//
//   PC(reg) --[ fetch 2 instr, 2 controllers, issue unit, regfile 4R, forward ]-->
//            D/E(reg) --[ 2 ALU, resolucion de 1 branch ]--> E/M(reg) -->
//            [ 1 puerto de memoria ] --> M/W(reg) --> [ 2 result mux ] --> regfile 2W
//
// REAGRUPAMIENTO (sin cola): el front-end es combinacional y el PC avanza
//   +8 si emito 2,  +4 si emito 1 (la via1 no emitida se re-busca sola como
//   nueva via0),  +0 si hay stall load-use. Nada se pierde ni se duplica.
//
// FORWARDING: se hace en la etapa F/D (al leer operandos). Fuentes, de mas
//   reciente a menos: EX via1 > EX via0 > MEM via1 > MEM via0 > regfile
//   (la distancia 3, WB->lectura, la cubre el regfile con write-before-read).
//   Los lw en EX NO se forwardean (su dato aun no existe): eso lo cubre el stall.
//
// BRANCH: se resuelve en EX. Si la via0 del par es un salto tomado, se ANULA la
//   via1 (mas joven). Si la via1 es el salto, la via0 (mas vieja) se conserva.
//   En ambos casos se hace flush del par mas joven que se trajo de mas.
module datapath_dual(
  input         clk, reset,
  // fetch (de imem2 en 'top': Instr0F en PCF, Instr1F en PCF+4)
  output [31:0] PCF,
  input  [31:0] Instr0F, Instr1F,
  // puerto UNICO de memoria de datos (etapa M)
  output        MemWriteM,
  output [31:0] DataAdrM,
  output [31:0] WriteDataM,
  input  [31:0] ReadDataM,
  // debug / observacion
  output [1:0]  issueCountOut
);

  // ===================================================================
  //                       ETAPA F/D (combinacional)
  // ===================================================================
  wire [31:0] PCPlus4F, PCPlus8F, PCNextF;
  assign PCPlus4F = PCF + 32'd4;
  assign PCPlus8F = PCF + 32'd8;

  // --- campos de registro de cada via ---
  wire [4:0] Rs1_0 = Instr0F[19:15], Rs2_0 = Instr0F[24:20], Rd0 = Instr0F[11:7];
  wire [4:0] Rs1_1 = Instr1F[19:15], Rs2_1 = Instr1F[24:20], Rd1 = Instr1F[11:7];

  // --- control de cada via (2 controllers) ---
  wire [1:0] ResultSrc0D, ImmSrc0D, ResultSrc1D, ImmSrc1D;
  wire [2:0] ALUControl0D, ALUControl1D;
  wire       MemWrite0D, ALUSrc0D, RegWrite0D, Jump0D, Branch0D;
  wire       MemWrite1D, ALUSrc1D, RegWrite1D, Jump1D, Branch1D;

  controller c0(.op(Instr0F[6:0]), .funct3(Instr0F[14:12]), .funct7b5(Instr0F[30]),
    .ResultSrc(ResultSrc0D), .MemWrite(MemWrite0D), .ALUSrc(ALUSrc0D),
    .RegWrite(RegWrite0D), .Jump(Jump0D), .Branch(Branch0D),
    .ImmSrc(ImmSrc0D), .ALUControl(ALUControl0D));
  controller c1(.op(Instr1F[6:0]), .funct3(Instr1F[14:12]), .funct7b5(Instr1F[30]),
    .ResultSrc(ResultSrc1D), .MemWrite(MemWrite1D), .ALUSrc(ALUSrc1D),
    .RegWrite(RegWrite1D), .Jump(Jump1D), .Branch(Branch1D),
    .ImmSrc(ImmSrc1D), .ALUControl(ALUControl1D));

  wire MemOp0 = MemWrite0D | (ResultSrc0D == 2'b01);  // sw o lw
  wire MemOp1 = MemWrite1D | (ResultSrc1D == 2'b01);
  wire BrJmp0 = Branch0D | Jump0D;
  wire BrJmp1 = Branch1D | Jump1D;

  // --- inmediatos ---
  wire [31:0] ImmExt0D, ImmExt1D;
  extend ext0(.instr(Instr0F[31:7]), .immsrc(ImmSrc0D), .immext(ImmExt0D));
  extend ext1(.instr(Instr1F[31:7]), .immsrc(ImmSrc1D), .immext(ImmExt1D));

  // --- regfile 4R/2W ---
  wire [31:0] RD1_0D, RD2_0D, RD1_1D, RD2_1D;
  // escrituras (desde WB, declaradas mas abajo)
  wire        RegWrite0W, RegWrite1W;
  wire [4:0]  Rd0W, Rd1W;
  wire [31:0] Result0W, Result1W;
  regfile2w rf(.clk(clk),
    .we1(RegWrite0W), .we2(RegWrite1W),
    .a1(Rs1_0), .a2(Rs2_0), .a3(Rs1_1), .a4(Rs2_1),
    .wa1(Rd0W), .wa2(Rd1W), .wd1(Result0W), .wd2(Result1W),
    .rd1(RD1_0D), .rd2(RD2_0D), .rd3(RD1_1D), .rd4(RD2_1D));

  // --- se declaran aqui las senales de EX/MEM que usa el forwarding y el issue ---
  wire        RegWrite0E, RegWrite1E, MemWrite0E, MemWrite1E;
  wire [1:0]  ResultSrc0E, ResultSrc1E;
  wire [4:0]  Rd0E, Rd1E;
  wire [31:0] ALUResult0E, ALUResult1E, PCPlus4_0E, PCPlus4_1E;
  wire        lwE0 = ResultSrc0E[0];   // 1 solo si la via0 en EX es lw
  wire        lwE1 = ResultSrc1E[0];
  wire        RegWrite0M, RegWrite1M;
  wire [1:0]  ResultSrc0M, ResultSrc1M;
  wire [4:0]  Rd0M, Rd1M;
  wire [31:0] ALUResult0M, ALUResult1M, PCPlus4_0M, PCPlus4_1M;

  // --- ISSUE UNIT ---
  wire       stall, issue1;
  wire [1:0] issueCount;
  issueunit iu(
    .Rs1_0(Rs1_0), .Rs2_0(Rs2_0), .Rd0(Rd0),
    .RegWrite0(RegWrite0D), .MemOp0(MemOp0), .BranchJump0(BrJmp0),
    .Rs1_1(Rs1_1), .Rs2_1(Rs2_1),
    .MemOp1(MemOp1), .BranchJump1(BrJmp1),
    .lwE0(lwE0), .lwE1(lwE1), .RdE0(Rd0E), .RdE1(Rd1E),
    .stall(stall), .issueCount(issueCount), .issue1(issue1));
  assign issueCountOut = issueCount;

  // --- valores forwardeables desde EX y MEM (por via) ---
  // EX: lw excluido (lo cubre el stall). jal -> PC+4, resto -> ALU.
  wire [31:0] fwdValE0 = (ResultSrc0E == 2'b10) ? PCPlus4_0E : ALUResult0E;
  wire [31:0] fwdValE1 = (ResultSrc1E == 2'b10) ? PCPlus4_1E : ALUResult1E;
  // MEM: load -> ReadData, jal -> PC+4, resto -> ALU
  wire [31:0] fwdValM0 = (ResultSrc0M == 2'b01) ? ReadDataM :
                         (ResultSrc0M == 2'b10) ? PCPlus4_0M : ALUResult0M;
  wire [31:0] fwdValM1 = (ResultSrc1M == 2'b01) ? ReadDataM :
                         (ResultSrc1M == 2'b10) ? PCPlus4_1M : ALUResult1M;

  // --- forwarding de cada operando (prioridad EX1>EX0>MEM1>MEM0>regfile) ---
  // operando A via0
  wire [31:0] SrcA_0D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs1_0) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs1_0) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs1_0))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs1_0))         ? fwdValM0 : RD1_0D;
  // operando B (dato de rs2 / store) via0
  wire [31:0] Data2_0D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs2_0) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs2_0) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs2_0))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs2_0))         ? fwdValM0 : RD2_0D;
  // operando A via1
  wire [31:0] SrcA_1D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs1_1) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs1_1) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs1_1))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs1_1))         ? fwdValM0 : RD1_1D;
  // operando B via1
  wire [31:0] Data2_1D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs2_1) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs2_1) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs2_1))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs2_1))         ? fwdValM0 : RD2_1D;

  // --- control empaquetado D->E (10 bits por via) ---
  // {RegWrite, ResultSrc(2), MemWrite, Jump, Branch, ALUSrc, ALUControl(3)}
  wire [9:0] ctrl0D = {RegWrite0D, ResultSrc0D, MemWrite0D, Jump0D, Branch0D, ALUSrc0D, ALUControl0D};
  wire [9:0] ctrl1D = {RegWrite1D, ResultSrc1D, MemWrite1D, Jump1D, Branch1D, ALUSrc1D, ALUControl1D};

  // ===================================================================
  //          FLUSH / STALL y actualizacion del PC
  // ===================================================================
  wire flushDE;                         // (de EX, declarado abajo) salto tomado
  // burbujas en el registro D/E:
  wire clear0 = stall | flushDE;                 // via0: burbuja si stall o flush
  wire clear1 = stall | flushDE | ~issue1;       // via1: ademas si no se emitio

  // ===================================================================
  //                       REGISTRO D/E
  // ===================================================================
  wire [9:0]  ctrl0E, ctrl1E;
  wire [31:0] SrcA0E, Data20E, Imm0E, PC0E;
  wire [31:0] SrcA1E, Data21E, Imm1E, PC1E;

  // via 0
  floprc #(10) de0_ctrl(.clk(clk), .reset(reset), .clear(clear0), .d(ctrl0D),    .q(ctrl0E));
  floprc #(32) de0_a   (.clk(clk), .reset(reset), .clear(clear0), .d(SrcA_0D),   .q(SrcA0E));
  floprc #(32) de0_b   (.clk(clk), .reset(reset), .clear(clear0), .d(Data2_0D),  .q(Data20E));
  floprc #(32) de0_imm (.clk(clk), .reset(reset), .clear(clear0), .d(ImmExt0D),  .q(Imm0E));
  floprc #(32) de0_pc  (.clk(clk), .reset(reset), .clear(clear0), .d(PCF),       .q(PC0E));
  floprc #(32) de0_pc4 (.clk(clk), .reset(reset), .clear(clear0), .d(PCPlus4F),  .q(PCPlus4_0E));
  floprc #(5)  de0_rd  (.clk(clk), .reset(reset), .clear(clear0), .d(Rd0),       .q(Rd0E));
  // via 1 (su PC es PCF+4, su PC+4 es PCF+8)
  floprc #(10) de1_ctrl(.clk(clk), .reset(reset), .clear(clear1), .d(ctrl1D),    .q(ctrl1E));
  floprc #(32) de1_a   (.clk(clk), .reset(reset), .clear(clear1), .d(SrcA_1D),   .q(SrcA1E));
  floprc #(32) de1_b   (.clk(clk), .reset(reset), .clear(clear1), .d(Data2_1D),  .q(Data21E));
  floprc #(32) de1_imm (.clk(clk), .reset(reset), .clear(clear1), .d(ImmExt1D),  .q(Imm1E));
  floprc #(32) de1_pc  (.clk(clk), .reset(reset), .clear(clear1), .d(PCPlus4F),  .q(PC1E));
  floprc #(32) de1_pc4 (.clk(clk), .reset(reset), .clear(clear1), .d(PCPlus8F),  .q(PCPlus4_1E));
  floprc #(5)  de1_rd  (.clk(clk), .reset(reset), .clear(clear1), .d(Rd1),       .q(Rd1E));

  // desempaco control en E
  wire Jump0E, Branch0E, ALUSrc0E;  wire [2:0] ALUControl0E;
  wire Jump1E, Branch1E, ALUSrc1E;  wire [2:0] ALUControl1E;
  assign {RegWrite0E, ResultSrc0E, MemWrite0E, Jump0E, Branch0E, ALUSrc0E, ALUControl0E} = ctrl0E;
  assign {RegWrite1E, ResultSrc1E, MemWrite1E, Jump1E, Branch1E, ALUSrc1E, ALUControl1E} = ctrl1E;

  // ===================================================================
  //                       ETAPA EX (2 ALU, 1 branch)
  // ===================================================================
  wire [31:0] SrcB0E = ALUSrc0E ? Imm0E : Data20E;
  wire [31:0] SrcB1E = ALUSrc1E ? Imm1E : Data21E;
  wire Zero0E, Zero1E;
  alu alu0(.a(SrcA0E), .b(SrcB0E), .alucontrol(ALUControl0E), .result(ALUResult0E), .zero(Zero0E));
  alu alu1(.a(SrcA1E), .b(SrcB1E), .alucontrol(ALUControl1E), .result(ALUResult1E), .zero(Zero1E));

  wire [31:0] PCTarget0E = PC0E + Imm0E;
  wire [31:0] PCTarget1E = PC1E + Imm1E;
  wire PCSrc0E = (Branch0E & Zero0E) | Jump0E;
  wire PCSrc1E = (Branch1E & Zero1E) | Jump1E;

  // si la via0 toma el salto, se anula la via1 (mas joven del mismo par)
  wire annul1 = PCSrc0E;
  wire RegWrite1E_eff = RegWrite1E & ~annul1;
  wire MemWrite1E_eff = MemWrite1E & ~annul1;

  // salto efectivo: prioridad a la via0 (mas vieja)
  assign flushDE = PCSrc0E | (PCSrc1E & ~annul1);
  wire [31:0] PCTargetE = PCSrc0E ? PCTarget0E : PCTarget1E;

  // --- siguiente PC ---
  assign PCNextF = flushDE          ? PCTargetE :
                   stall            ? PCF       :
                   (issueCount==2'd2)? PCPlus8F  :
                                      PCPlus4F;   // issueCount==1
  flopr #(32) pcreg(.clk(clk), .reset(reset), .d(PCNextF), .q(PCF));

  // dato de store por via
  wire [31:0] WriteData0E = Data20E;
  wire [31:0] WriteData1E = Data21E;

  // ===================================================================
  //                       REGISTRO EX/MEM
  // ===================================================================
  wire [3:0] ctrl0M, ctrl1M;
  wire [31:0] WriteData0M, WriteData1M;
  flopr #(4)  em0_ctrl(.clk(clk), .reset(reset), .d({RegWrite0E,     ResultSrc0E, MemWrite0E}),     .q(ctrl0M));
  flopr #(4)  em1_ctrl(.clk(clk), .reset(reset), .d({RegWrite1E_eff, ResultSrc1E, MemWrite1E_eff}), .q(ctrl1M));
  flopr #(32) em0_alu (.clk(clk), .reset(reset), .d(ALUResult0E), .q(ALUResult0M));
  flopr #(32) em1_alu (.clk(clk), .reset(reset), .d(ALUResult1E), .q(ALUResult1M));
  flopr #(32) em0_wd  (.clk(clk), .reset(reset), .d(WriteData0E), .q(WriteData0M));
  flopr #(32) em1_wd  (.clk(clk), .reset(reset), .d(WriteData1E), .q(WriteData1M));
  flopr #(5)  em0_rd  (.clk(clk), .reset(reset), .d(Rd0E),        .q(Rd0M));
  flopr #(5)  em1_rd  (.clk(clk), .reset(reset), .d(Rd1E),        .q(Rd1M));
  flopr #(32) em0_pc4 (.clk(clk), .reset(reset), .d(PCPlus4_0E),  .q(PCPlus4_0M));
  flopr #(32) em1_pc4 (.clk(clk), .reset(reset), .d(PCPlus4_1E),  .q(PCPlus4_1M));

  wire MemWrite0M_w, MemWrite1M_w;
  assign {RegWrite0M, ResultSrc0M, MemWrite0M_w} = ctrl0M;
  assign {RegWrite1M, ResultSrc1M, MemWrite1M_w} = ctrl1M;

  // ===================================================================
  //                       ETAPA MEM (1 puerto)
  // ===================================================================
  wire memOp0M = MemWrite0M_w | (ResultSrc0M == 2'b01);
  wire memOp1M = MemWrite1M_w | (ResultSrc1M == 2'b01);
  wire selMem1 = memOp1M;    // solo una via accede a memoria (garantizado por issue unit)
  assign DataAdrM   = selMem1 ? ALUResult1M : ALUResult0M;
  assign WriteDataM = selMem1 ? WriteData1M : WriteData0M;
  assign MemWriteM  = MemWrite0M_w | MemWrite1M_w;

  // ===================================================================
  //                       REGISTRO MEM/WB
  // ===================================================================
  wire [2:0] ctrl0W, ctrl1W;
  wire [31:0] ALUResult0W, ALUResult1W, PCPlus4_0W, PCPlus4_1W, ReadDataW;
  flopr #(3)  mw0_ctrl(.clk(clk), .reset(reset), .d({RegWrite0M, ResultSrc0M}), .q(ctrl0W));
  flopr #(3)  mw1_ctrl(.clk(clk), .reset(reset), .d({RegWrite1M, ResultSrc1M}), .q(ctrl1W));
  flopr #(32) mw0_alu (.clk(clk), .reset(reset), .d(ALUResult0M), .q(ALUResult0W));
  flopr #(32) mw1_alu (.clk(clk), .reset(reset), .d(ALUResult1M), .q(ALUResult1W));
  flopr #(5)  mw0_rd  (.clk(clk), .reset(reset), .d(Rd0M),        .q(Rd0W));
  flopr #(5)  mw1_rd  (.clk(clk), .reset(reset), .d(Rd1M),        .q(Rd1W));
  flopr #(32) mw0_pc4 (.clk(clk), .reset(reset), .d(PCPlus4_0M),  .q(PCPlus4_0W));
  flopr #(32) mw1_pc4 (.clk(clk), .reset(reset), .d(PCPlus4_1M),  .q(PCPlus4_1W));
  flopr #(32) mw_rdd  (.clk(clk), .reset(reset), .d(ReadDataM),   .q(ReadDataW));  // compartido

  wire [1:0] ResultSrc0W, ResultSrc1W;
  assign {RegWrite0W, ResultSrc0W} = ctrl0W;
  assign {RegWrite1W, ResultSrc1W} = ctrl1W;

  // ===================================================================
  //                       ETAPA WB (2 result mux)
  // ===================================================================
  mux3 #(32) res0(.d0(ALUResult0W), .d1(ReadDataW), .d2(PCPlus4_0W), .s(ResultSrc0W), .y(Result0W));
  mux3 #(32) res1(.d0(ALUResult1W), .d1(ReadDataW), .d2(PCPlus4_1W), .s(ResultSrc1W), .y(Result1W));

endmodule
