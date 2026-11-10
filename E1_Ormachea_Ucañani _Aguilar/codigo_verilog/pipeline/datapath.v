module datapath(
  input         clk, reset,
  input  [1:0]  ResultSrcD,
  input         MemWriteD,
  input         ALUSrcD,
  input         RegWriteD,
  input         JumpD,
  input         BranchD,
  input  [2:0]  ALUControlD,
  input  [1:0]  ImmSrcD,
  output [31:0] PCF,
  input  [31:0] InstrF,
  output [31:0] InstrD,
  output        MemWriteM,
  output [31:0] ALUResultM,
  output [31:0] WriteDataM,
  input  [31:0] ReadDataM
);

  wire [31:0] PCNextF, PCPlus4F;
  wire [31:0] PCTargetE;  // feedback desde EX
  wire        PCSrcE;  // feedback desde EX
  wire [31:0] PCD, PCPlus4D;
  wire [4:0]  Rs1D, Rs2D, RdD;
  wire [31:0] RD1D, RD2D, ImmExtD;
  wire [9:0]  ctrlD, ctrlE;  // control empaquetado
  wire        RegWriteE, MemWriteE, ALUSrcE, JumpE, BranchE;
  wire [1:0]  ResultSrcE;
  wire [2:0]  ALUControlE;
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [4:0]  RdE, Rs1E, Rs2E;
  wire [31:0] SrcAE, SrcBE, ALUResultE, WriteDataE;
  wire        ZeroE;
  wire [3:0]  ctrlM;
  wire        RegWriteM;
  wire [1:0]  ResultSrcM;
  wire [4:0]  RdM;
  wire [31:0] PCPlus4M;
  wire [2:0]  ctrlW;
  wire        RegWriteW;
  wire [1:0]  ResultSrcW;
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W, ResultW;
  wire [4:0]  RdW;
  wire [1:0]  ForwardAE, ForwardBE;
  wire        StallF, StallD, FlushD, FlushE;

  mux2 #(32) pcmux (.d0(PCPlus4F), .d1(PCTargetE), .s(PCSrcE), .y(PCNextF));
  flopenr #(32) pcreg(.clk(clk), .reset(reset), .en(~StallF), .d(PCNextF), .q(PCF));
  adder         pcadd4(.a(PCF), .b(32'd4), .y(PCPlus4F));

  flopenrc #(32) ff_instr(.clk(clk), .reset(reset), .clear(FlushD), .en(~StallD), .d(InstrF),   .q(InstrD));
  flopenrc #(32) ff_pc   (.clk(clk), .reset(reset), .clear(FlushD), .en(~StallD), .d(PCF),      .q(PCD));
  flopenrc #(32) ff_pc4  (.clk(clk), .reset(reset), .clear(FlushD), .en(~StallD), .d(PCPlus4F), .q(PCPlus4D));

  assign Rs1D = InstrD[19:15];
  assign Rs2D = InstrD[24:20];
  assign RdD  = InstrD[11:7];

  regfile rf(.clk(clk), .we3(RegWriteW),
             .a1(Rs1D), .a2(Rs2D), .a3(RdW),
             .wd3(ResultW), .rd1(RD1D), .rd2(RD2D));
  extend  ext(.instr(InstrD[31:7]), .immsrc(ImmSrcD), .immext(ImmExtD));

  assign ctrlD = {RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUSrcD, ALUControlD};

  floprc #(10) de_ctrl(.clk(clk), .reset(reset), .clear(FlushE), .d(ctrlD),    .q(ctrlE));
  floprc #(32) de_rd1 (.clk(clk), .reset(reset), .clear(FlushE), .d(RD1D),     .q(RD1E));
  floprc #(32) de_rd2 (.clk(clk), .reset(reset), .clear(FlushE), .d(RD2D),     .q(RD2E));
  floprc #(32) de_pc  (.clk(clk), .reset(reset), .clear(FlushE), .d(PCD),      .q(PCE));
  floprc #(32) de_imm (.clk(clk), .reset(reset), .clear(FlushE), .d(ImmExtD),  .q(ImmExtE));
  floprc #(32) de_pc4 (.clk(clk), .reset(reset), .clear(FlushE), .d(PCPlus4D), .q(PCPlus4E));
  floprc #(5)  de_rd  (.clk(clk), .reset(reset), .clear(FlushE), .d(RdD),      .q(RdE));
  floprc #(5)  de_rs1 (.clk(clk), .reset(reset), .clear(FlushE), .d(Rs1D),     .q(Rs1E));
  floprc #(5)  de_rs2 (.clk(clk), .reset(reset), .clear(FlushE), .d(Rs2D),     .q(Rs2E));

  assign RegWriteE   = ctrlE[9];
  assign ResultSrcE  = ctrlE[8:7];
  assign MemWriteE   = ctrlE[6];
  assign JumpE       = ctrlE[5];
  assign BranchE     = ctrlE[4];
  assign ALUSrcE     = ctrlE[3];
  assign ALUControlE = ctrlE[2:0];

  mux3 #(32) faemux(.d0(RD1E), .d1(ResultW), .d2(ALUResultM), .s(ForwardAE), .y(SrcAE));
  mux3 #(32) fbemux(.d0(RD2E), .d1(ResultW), .d2(ALUResultM), .s(ForwardBE), .y(WriteDataE));
  mux2 #(32) srcbmux(.d0(WriteDataE), .d1(ImmExtE), .s(ALUSrcE), .y(SrcBE));

  alu alu(.a(SrcAE), .b(SrcBE), .alucontrol(ALUControlE), .result(ALUResultE), .zero(ZeroE));
  adder pcaddbranch(.a(PCE), .b(ImmExtE), .y(PCTargetE));
  assign PCSrcE = (BranchE & ZeroE) | JumpE;

  flopr #(4)  em_ctrl(.clk(clk), .reset(reset), .d({RegWriteE, ResultSrcE, MemWriteE}), .q(ctrlM));
  flopr #(32) em_alu (.clk(clk), .reset(reset), .d(ALUResultE), .q(ALUResultM));
  flopr #(32) em_wd  (.clk(clk), .reset(reset), .d(WriteDataE), .q(WriteDataM));
  flopr #(5)  em_rd  (.clk(clk), .reset(reset), .d(RdE),        .q(RdM));
  flopr #(32) em_pc4 (.clk(clk), .reset(reset), .d(PCPlus4E),   .q(PCPlus4M));

  assign RegWriteM  = ctrlM[3];
  assign ResultSrcM = ctrlM[2:1];
  assign MemWriteM  = ctrlM[0];

  flopr #(3)  mw_ctrl(.clk(clk), .reset(reset), .d({RegWriteM, ResultSrcM}), .q(ctrlW));
  flopr #(32) mw_alu (.clk(clk), .reset(reset), .d(ALUResultM), .q(ALUResultW));
  flopr #(32) mw_rdd (.clk(clk), .reset(reset), .d(ReadDataM),  .q(ReadDataW));
  flopr #(5)  mw_rd  (.clk(clk), .reset(reset), .d(RdM),        .q(RdW));
  flopr #(32) mw_pc4 (.clk(clk), .reset(reset), .d(PCPlus4M),   .q(PCPlus4W));

  assign RegWriteW  = ctrlW[2];
  assign ResultSrcW = ctrlW[1:0];

  mux3 #(32) resultmux(.d0(ALUResultW), .d1(ReadDataW), .d2(PCPlus4W),
                       .s(ResultSrcW), .y(ResultW));

  hazardunit hu(
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW),
    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE),
    .ResultSrcE0(ResultSrcE[0]),
    .PCSrcE(PCSrcE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE)
  );

endmodule
