// hazardunit: UNICO modulo que resuelve los hazards del pipeline single-issue.
// Es combinacional. Reune las tres piezas vistas en teoria:
//
//  1) FORWARDING (data hazard): compara el registro que la instruccion en EX
//     va a LEER (Rs1E/Rs2E) contra el que las instrucciones adelante van a
//     ESCRIBIR (RdM en MEM, RdW en WB). Si coincide (y esa instr escribe y no
//     es x0), adelanta el dato. Prioridad al mas reciente (MEM sobre WB).
//       ForwardAE/BE: 00=regfile, 10=desde MEM (ALUResultM), 01=desde WB (ResultW)
//
//  2) STALL load-use: el unico caso que el forwarding no puede. Si la instr en
//     EX es un lw (ResultSrcE0=1) y la instr en ID (Rs1D/Rs2D) necesita su
//     destino (RdE), hay que congelar 1 ciclo.
//       lwStall -> StallF (congela PC), StallD (congela IF/ID), y burbuja en EX.
//
//  3) FLUSH control (branch/jump tomado): PCSrcE llega desde EX. Si el salto se
//     toma, se anulan las 2 instrucciones mal traidas.
//       FlushD = PCSrcE                 (anula IF/ID)
//       FlushE = lwStall OR PCSrcE      (burbuja ID/EX por load-use O por branch)
module hazardunit(
  // para forwarding
  input  [4:0] Rs1E, Rs2E, RdM, RdW,
  input        RegWriteM, RegWriteW,
  // para lwStall
  input  [4:0] Rs1D, Rs2D, RdE,
  input        ResultSrcE0,   // bit0 de ResultSrcE: 1 solo si la instr en EX es lw
  // para flush
  input        PCSrcE,        // salto tomado (Branch&Zero | Jump), resuelto en EX
  // salidas
  output [1:0] ForwardAE, ForwardBE,
  output       StallF, StallD,
  output       FlushD, FlushE
);

  // ----- Forwarding (operando A) -----
  assign ForwardAE =
      ( (Rs1E == RdM) & RegWriteM & (Rs1E != 5'd0) ) ? 2'b10 :  // desde MEM
      ( (Rs1E == RdW) & RegWriteW & (Rs1E != 5'd0) ) ? 2'b01 :  // desde WB
                                                       2'b00;   // del regfile

  // ----- Forwarding (operando B) -----
  assign ForwardBE =
      ( (Rs2E == RdM) & RegWriteM & (Rs2E != 5'd0) ) ? 2'b10 :
      ( (Rs2E == RdW) & RegWriteW & (Rs2E != 5'd0) ) ? 2'b01 :
                                                       2'b00;

  // ----- Stall load-use -----
  wire lwStall = ResultSrcE0 & ( (Rs1D == RdE) | (Rs2D == RdE) );
  assign StallF = lwStall;
  assign StallD = lwStall;

  // ----- Flush -----
  assign FlushD = PCSrcE;
  assign FlushE = lwStall | PCSrcE;

endmodule
