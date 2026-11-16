// datapath_dual_opt: datapath del dual-issue in-order + prediccion de branch (config C).
// Igual que config B (5 etapas, 2 vias) mas: predictor de 2 bits + BTB en IF.
// La prediccion correcta de un branch tomado ELIMINA la penalizacion de 2 ciclos.
module datapath_dual_opt(
  input         clk, reset,
  output [31:0] PCF,
  input  [31:0] Instr0F, Instr1F,
  output        MemWriteM,
  output [31:0] DataAdrM,
  output [31:0] WriteDataM,
  input  [31:0] ReadDataM,
  output [1:0]  issueCountOut
);

  // senales que se definen mas abajo (ID/EX, EX)
  wire        stall, issue1;
  wire [1:0]  issueCount;
  wire        flushDE;              // ahora: mala prediccion (de EX)
  wire [31:0] PCTargetE;            // PC de recuperacion (de EX)
  wire [31:0] PC1D;                 // direccion de la via1 en ID (para reagrupar)
  // actualizacion del BTB/predictor (de EX)
  wire        btb_we, pred_we, pred_wTaken;
  wire [31:0] btb_wPC, btb_wTgt, pred_wPC;

  // ===================== ETAPA IF =====================
  // PC = puntero de fetch. Avanza +8; en mala prediccion va al PC correcto; en stall
  // se congela; en emision parcial se reagrupa a PC1D; si predice salto, al destino.
  wire [31:0] PCF4 = PCF + 32'd4;

  // --- prediccion: BTB (destino) + contador 2 bits (tomado/no) ---
  wire        btb_hit0, btb_hit1, pred_t0, pred_t1;
  wire [31:0] btb_tgt0, btb_tgt1;
  btb btbu(.clk(clk), .reset(reset), .rPC0(PCF), .rPC1(PCF4),
    .hit0(btb_hit0), .hit1(btb_hit1), .target0(btb_tgt0), .target1(btb_tgt1),
    .we(btb_we), .wPC(btb_wPC), .wTarget(btb_wTgt));
  bpredictor bpu(.clk(clk), .reset(reset), .rPC0(PCF), .rPC1(PCF4),
    .taken0(pred_t0), .taken1(pred_t1),
    .we(pred_we), .wPC(pred_wPC), .wTaken(pred_wTaken));

  wire        predTaken0 = btb_hit0 & pred_t0;            // via0 predicha tomada
  wire        predTaken1 = btb_hit1 & pred_t1 & ~predTaken0;
  wire        predTakenPkt = predTaken0 | predTaken1;
  wire [31:0] predTargetPkt = predTaken0 ? btb_tgt0 : btb_tgt1;
  wire        predAnnul1 = predTaken0;                    // si salta la via0, anula la via1

  wire [31:0] PCNextF;
  assign PCNextF = flushDE           ? PCTargetE :
                   stall             ? PCF :
                   (issueCount==2'd1)? PC1D :
                   predTakenPkt      ? predTargetPkt :
                                       PCF + 32'd8;
  flopr #(32) pcreg(.clk(clk), .reset(reset), .d(PCNextF), .q(PCF));

  // registro IF/ID: guarda el par y la prediccion. Se congela en stall, se limpia en
  // mala prediccion o reagrupamiento (flushIFID); la via1 ademas si se predijo salto en via0.
  wire        flushIFID = flushDE | (issueCount==2'd1);
  wire        clrI1     = flushIFID | predAnnul1;
  wire [31:0] I0D, I1D, PC0D;
  flopenrc #(32) ifid_i0 (.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(Instr0F),     .q(I0D));
  flopenrc #(32) ifid_i1 (.clk(clk), .reset(reset), .clear(clrI1),     .en(~stall), .d(Instr1F),     .q(I1D));
  flopenrc #(32) ifid_pc0(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(PCF),         .q(PC0D));
  flopenrc #(32) ifid_pc1(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(PCF4),        .q(PC1D));
  // prediccion registrada hacia ID
  wire        predTaken0D, predTaken1D;
  wire [31:0] predTarget0D, predTarget1D;
  flopenrc #(1)  ifid_pt0(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(predTaken0),  .q(predTaken0D));
  flopenrc #(1)  ifid_pt1(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(predTaken1),  .q(predTaken1D));
  flopenrc #(32) ifid_tg0(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(btb_tgt0),    .q(predTarget0D));
  flopenrc #(32) ifid_tg1(.clk(clk), .reset(reset), .clear(flushIFID), .en(~stall), .d(btb_tgt1),    .q(predTarget1D));

  // ===================== ETAPA ID =====================
  wire [4:0] Rs1_0 = I0D[19:15], Rs2_0 = I0D[24:20], Rd0 = I0D[11:7];
  wire [4:0] Rs1_1 = I1D[19:15], Rs2_1 = I1D[24:20], Rd1 = I1D[11:7];

  // 2 controllers
  wire [1:0] ResultSrc0D, ImmSrc0D, ResultSrc1D, ImmSrc1D;
  wire [2:0] ALUControl0D, ALUControl1D;
  wire       MemWrite0D, ALUSrc0D, RegWrite0D, Jump0D, Branch0D;
  wire       MemWrite1D, ALUSrc1D, RegWrite1D, Jump1D, Branch1D;

  controller c0(.op(I0D[6:0]), .funct3(I0D[14:12]), .funct7b5(I0D[30]),
    .ResultSrc(ResultSrc0D), .MemWrite(MemWrite0D), .ALUSrc(ALUSrc0D),
    .RegWrite(RegWrite0D), .Jump(Jump0D), .Branch(Branch0D),
    .ImmSrc(ImmSrc0D), .ALUControl(ALUControl0D));
  controller c1(.op(I1D[6:0]), .funct3(I1D[14:12]), .funct7b5(I1D[30]),
    .ResultSrc(ResultSrc1D), .MemWrite(MemWrite1D), .ALUSrc(ALUSrc1D),
    .RegWrite(RegWrite1D), .Jump(Jump1D), .Branch(Branch1D),
    .ImmSrc(ImmSrc1D), .ALUControl(ALUControl1D));

  wire MemOp0 = MemWrite0D | (ResultSrc0D == 2'b01);   // sw o lw
  wire MemOp1 = MemWrite1D | (ResultSrc1D == 2'b01);
  wire BrJmp0 = Branch0D | Jump0D;
  wire BrJmp1 = Branch1D | Jump1D;

  // inmediatos
  wire [31:0] ImmExt0D, ImmExt1D;
  extend ext0(.instr(I0D[31:7]), .immsrc(ImmSrc0D), .immext(ImmExt0D));
  extend ext1(.instr(I1D[31:7]), .immsrc(ImmSrc1D), .immext(ImmExt1D));

  // regfile 4R/2W (escrituras desde WB, abajo)
  wire [31:0] RD1_0D, RD2_0D, RD1_1D, RD2_1D;
  wire        RegWrite0W, RegWrite1W;
  wire [4:0]  Rd0W, Rd1W;
  wire [31:0] Result0W, Result1W;
  regfile2w rf(.clk(clk),
    .we1(RegWrite0W), .we2(RegWrite1W),
    .a1(Rs1_0), .a2(Rs2_0), .a3(Rs1_1), .a4(Rs2_1),
    .wa1(Rd0W), .wa2(Rd1W), .wd1(Result0W), .wd2(Result1W),
    .rd1(RD1_0D), .rd2(RD2_0D), .rd3(RD1_1D), .rd4(RD2_1D));

  // senales de EX/MEM que usan el forwarding y el issue
  wire        RegWrite0E, RegWrite1E, MemWrite0E, MemWrite1E;
  wire [1:0]  ResultSrc0E, ResultSrc1E;
  wire [4:0]  Rd0E, Rd1E;
  wire [31:0] ALUResult0E, ALUResult1E, PCPlus4_0E, PCPlus4_1E;
  wire        lwE0 = ResultSrc0E[0];
  wire        lwE1 = ResultSrc1E[0];
  wire        RegWrite0M, RegWrite1M;
  wire [1:0]  ResultSrc0M, ResultSrc1M;
  wire [4:0]  Rd0M, Rd1M;
  wire [31:0] ALUResult0M, ALUResult1M, PCPlus4_0M, PCPlus4_1M;

  // Issue Unit
  issueunit iu(
    .Rs1_0(Rs1_0), .Rs2_0(Rs2_0), .Rd0(Rd0),
    .RegWrite0(RegWrite0D), .MemOp0(MemOp0), .BranchJump0(BrJmp0),
    .Rs1_1(Rs1_1), .Rs2_1(Rs2_1),
    .MemOp1(MemOp1), .BranchJump1(BrJmp1),
    .lwE0(lwE0), .lwE1(lwE1), .RdE0(Rd0E), .RdE1(Rd1E),
    .stall(stall), .issueCount(issueCount), .issue1(issue1));
  assign issueCountOut = issueCount;

  // valores forwardeables desde EX y MEM
  wire [31:0] fwdValE0 = (ResultSrc0E == 2'b10) ? PCPlus4_0E : ALUResult0E;
  wire [31:0] fwdValE1 = (ResultSrc1E == 2'b10) ? PCPlus4_1E : ALUResult1E;
  wire [31:0] fwdValM0 = (ResultSrc0M == 2'b01) ? ReadDataM :
                         (ResultSrc0M == 2'b10) ? PCPlus4_0M : ALUResult0M;
  wire [31:0] fwdValM1 = (ResultSrc1M == 2'b01) ? ReadDataM :
                         (ResultSrc1M == 2'b10) ? PCPlus4_1M : ALUResult1M;

  // forwarding por operando (prioridad EX1 > EX0 > MEM1 > MEM0 > regfile)
  wire [31:0] SrcA_0D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs1_0) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs1_0) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs1_0))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs1_0))         ? fwdValM0 : RD1_0D;
  wire [31:0] Data2_0D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs2_0) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs2_0) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs2_0))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs2_0))         ? fwdValM0 : RD2_0D;
  wire [31:0] SrcA_1D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs1_1) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs1_1) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs1_1))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs1_1))         ? fwdValM0 : RD1_1D;
  wire [31:0] Data2_1D =
    (RegWrite1E & (Rd1E!=0) & (Rd1E==Rs2_1) & ~lwE1) ? fwdValE1 :
    (RegWrite0E & (Rd0E!=0) & (Rd0E==Rs2_1) & ~lwE0) ? fwdValE0 :
    (RegWrite1M & (Rd1M!=0) & (Rd1M==Rs2_1))         ? fwdValM1 :
    (RegWrite0M & (Rd0M!=0) & (Rd0M==Rs2_1))         ? fwdValM0 : RD2_1D;

  // control empaquetado ID->EX: {RegWrite, ResultSrc(2), MemWrite, Jump, Branch, ALUSrc, ALUControl(3)}
  wire [9:0] ctrl0D = {RegWrite0D, ResultSrc0D, MemWrite0D, Jump0D, Branch0D, ALUSrc0D, ALUControl0D};
  wire [9:0] ctrl1D = {RegWrite1D, ResultSrc1D, MemWrite1D, Jump1D, Branch1D, ALUSrc1D, ALUControl1D};

  // burbujas del registro ID/EX
  wire clear0 = stall | flushDE;
  wire clear1 = stall | flushDE | ~issue1;

  // ===================== REGISTRO ID/EX =====================
  wire [9:0]  ctrl0E, ctrl1E;
  wire [31:0] SrcA0E, Data20E, Imm0E, PC0E;
  wire [31:0] SrcA1E, Data21E, Imm1E, PC1E;
  wire        predTaken0E, predTaken1E;
  wire [31:0] predTarget0E, predTarget1E;

  floprc #(10) de0_ctrl(.clk(clk), .reset(reset), .clear(clear0), .d(ctrl0D),        .q(ctrl0E));
  floprc #(32) de0_a   (.clk(clk), .reset(reset), .clear(clear0), .d(SrcA_0D),       .q(SrcA0E));
  floprc #(32) de0_b   (.clk(clk), .reset(reset), .clear(clear0), .d(Data2_0D),      .q(Data20E));
  floprc #(32) de0_imm (.clk(clk), .reset(reset), .clear(clear0), .d(ImmExt0D),      .q(Imm0E));
  floprc #(32) de0_pc  (.clk(clk), .reset(reset), .clear(clear0), .d(PC0D),          .q(PC0E));
  floprc #(32) de0_pc4 (.clk(clk), .reset(reset), .clear(clear0), .d(PC0D + 32'd4),  .q(PCPlus4_0E));
  floprc #(5)  de0_rd  (.clk(clk), .reset(reset), .clear(clear0), .d(Rd0),           .q(Rd0E));
  floprc #(1)  de0_pt  (.clk(clk), .reset(reset), .clear(clear0), .d(predTaken0D),   .q(predTaken0E));
  floprc #(32) de0_tg  (.clk(clk), .reset(reset), .clear(clear0), .d(predTarget0D),  .q(predTarget0E));
  floprc #(10) de1_ctrl(.clk(clk), .reset(reset), .clear(clear1), .d(ctrl1D),        .q(ctrl1E));
  floprc #(32) de1_a   (.clk(clk), .reset(reset), .clear(clear1), .d(SrcA_1D),       .q(SrcA1E));
  floprc #(32) de1_b   (.clk(clk), .reset(reset), .clear(clear1), .d(Data2_1D),      .q(Data21E));
  floprc #(32) de1_imm (.clk(clk), .reset(reset), .clear(clear1), .d(ImmExt1D),      .q(Imm1E));
  floprc #(32) de1_pc  (.clk(clk), .reset(reset), .clear(clear1), .d(PC1D),          .q(PC1E));
  floprc #(32) de1_pc4 (.clk(clk), .reset(reset), .clear(clear1), .d(PC1D + 32'd4),  .q(PCPlus4_1E));
  floprc #(5)  de1_rd  (.clk(clk), .reset(reset), .clear(clear1), .d(Rd1),           .q(Rd1E));
  floprc #(1)  de1_pt  (.clk(clk), .reset(reset), .clear(clear1), .d(predTaken1D),   .q(predTaken1E));
  floprc #(32) de1_tg  (.clk(clk), .reset(reset), .clear(clear1), .d(predTarget1D),  .q(predTarget1E));

  wire Jump0E, Branch0E, ALUSrc0E;  wire [2:0] ALUControl0E;
  wire Jump1E, Branch1E, ALUSrc1E;  wire [2:0] ALUControl1E;
  assign {RegWrite0E, ResultSrc0E, MemWrite0E, Jump0E, Branch0E, ALUSrc0E, ALUControl0E} = ctrl0E;
  assign {RegWrite1E, ResultSrc1E, MemWrite1E, Jump1E, Branch1E, ALUSrc1E, ALUControl1E} = ctrl1E;

  // ===================== ETAPA EX (2 ALU, 1 branch) =====================
  wire [31:0] SrcB0E = ALUSrc0E ? Imm0E : Data20E;
  wire [31:0] SrcB1E = ALUSrc1E ? Imm1E : Data21E;
  wire Zero0E, Zero1E;
  alu alu0(.a(SrcA0E), .b(SrcB0E), .alucontrol(ALUControl0E), .result(ALUResult0E), .zero(Zero0E));
  alu alu1(.a(SrcA1E), .b(SrcB1E), .alucontrol(ALUControl1E), .result(ALUResult1E), .zero(Zero1E));

  wire [31:0] PCTarget0E = PC0E + Imm0E;
  wire [31:0] PCTarget1E = PC1E + Imm1E;
  wire        PCSrc0E = (Branch0E & Zero0E) | Jump0E;   // via0 realmente toma
  wire        PCSrc1E = (Branch1E & Zero1E) | Jump1E;   // via1 realmente toma
  wire        isBr0E  = Branch0E | Jump0E;
  wire        isBr1E  = Branch1E | Jump1E;

  // branch en via0 tomado -> anula via1 (igual que B)
  wire annul1 = PCSrc0E;
  wire RegWrite1E_eff = RegWrite1E & ~annul1;
  wire MemWrite1E_eff = MemWrite1E & ~annul1;

  // --- verificacion de la prediccion (a lo sumo 1 branch por ciclo) ---
  // mala prediccion si no coincide la direccion, o si tomado pero a otro destino.
  wire mispred0 = (isBr0E | predTaken0E) &
                  ((PCSrc0E ^ predTaken0E) | (PCSrc0E & (PCTarget0E != predTarget0E)));
  wire mispred1 = ~annul1 & (isBr1E | predTaken1E) &
                  ((PCSrc1E ^ predTaken1E) | (PCSrc1E & (PCTarget1E != predTarget1E)));
  // PC correcto: tomado -> destino; si se predijo salto y no era -> siguiente (PC+4)
  wire [31:0] correctPC0 = PCSrc0E ? PCTarget0E : (PC0E + 32'd4);
  wire [31:0] correctPC1 = PCSrc1E ? PCTarget1E : (PC1E + 32'd4);

  assign flushDE   = mispred0 | mispred1;                 // flush SOLO en mala prediccion
  assign PCTargetE = mispred0 ? correctPC0 : correctPC1;

  // actualizacion del BTB (inserta en tomado) y del predictor (en toda resolucion)
  wire brRes0 = isBr0E;
  wire brRes1 = isBr1E & ~annul1;
  assign btb_we      = (brRes0 & PCSrc0E) | (brRes1 & PCSrc1E);
  assign btb_wPC     = brRes0 ? PC0E : PC1E;
  assign btb_wTgt    = brRes0 ? PCTarget0E : PCTarget1E;
  assign pred_we     = brRes0 | brRes1;
  assign pred_wPC    = brRes0 ? PC0E : PC1E;
  assign pred_wTaken = brRes0 ? PCSrc0E : PCSrc1E;

  wire [31:0] WriteData0E = Data20E;
  wire [31:0] WriteData1E = Data21E;

  // ===================== REGISTRO EX/MEM =====================
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

  // ===================== ETAPA MEM (1 puerto, selector de via) =====================
  wire memOp0M = MemWrite0M_w | (ResultSrc0M == 2'b01);
  wire memOp1M = MemWrite1M_w | (ResultSrc1M == 2'b01);
  wire selMem1 = memOp1M;
  assign DataAdrM   = selMem1 ? ALUResult1M : ALUResult0M;
  assign WriteDataM = selMem1 ? WriteData1M : WriteData0M;
  assign MemWriteM  = MemWrite0M_w | MemWrite1M_w;

  // ===================== REGISTRO MEM/WB =====================
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
  flopr #(32) mw_rdd  (.clk(clk), .reset(reset), .d(ReadDataM),   .q(ReadDataW));

  wire [1:0] ResultSrc0W, ResultSrc1W;
  assign {RegWrite0W, ResultSrc0W} = ctrl0W;
  assign {RegWrite1W, ResultSrc1W} = ctrl1W;

  // ===================== ETAPA WB (2 result mux) =====================
  mux3 #(32) res0(.d0(ALUResult0W), .d1(ReadDataW), .d2(PCPlus4_0W), .s(ResultSrc0W), .y(Result0W));
  mux3 #(32) res1(.d0(ALUResult1W), .d1(ReadDataW), .d2(PCPlus4_1W), .s(ResultSrc1W), .y(Result1W));

endmodule
