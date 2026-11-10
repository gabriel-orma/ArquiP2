module hazardunit(
  input  [4:0] Rs1E, Rs2E, RdM, RdW,
  input        RegWriteM, RegWriteW,
  input  [4:0] Rs1D, Rs2D, RdE,
  input        ResultSrcE0,
  input        PCSrcE,
  output [1:0] ForwardAE, ForwardBE,
  output       StallF, StallD,
  output       FlushD, FlushE
);

  assign ForwardAE =
      ( (Rs1E == RdM) & RegWriteM & (Rs1E != 5'd0) ) ? 2'b10 :  // desde MEM
      ( (Rs1E == RdW) & RegWriteW & (Rs1E != 5'd0) ) ? 2'b01 :  // desde WB
                                                       2'b00;  // del regfile

  assign ForwardBE =
      ( (Rs2E == RdM) & RegWriteM & (Rs2E != 5'd0) ) ? 2'b10 :
      ( (Rs2E == RdW) & RegWriteW & (Rs2E != 5'd0) ) ? 2'b01 :
                                                       2'b00;

  wire lwStall = ResultSrcE0 & ( (Rs1D == RdE) | (Rs2D == RdE) );
  assign StallF = lwStall;
  assign StallD = lwStall;

  assign FlushD = PCSrcE;
  assign FlushE = lwStall | PCSrcE;

endmodule
