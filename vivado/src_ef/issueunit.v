// issueunit: decide cuantas instrucciones emitir por ciclo (2/1/0), en orden.
module issueunit(
  input  [4:0] Rs1_0, Rs2_0, Rd0,
  input        RegWrite0, MemOp0, BranchJump0,
  input  [4:0] Rs1_1, Rs2_1,
  input        MemOp1, BranchJump1,
  input        lwE0, lwE1,
  input  [4:0] RdE0, RdE1,
  output       stall,
  output [1:0] issueCount,
  output       issue1
);

  // conflictos que impiden emitir 2
  wire rawPair = RegWrite0 & (Rd0 != 5'd0) & ( (Rd0 == Rs1_1) | (Rd0 == Rs2_1) );  // RAW intra-par
  wire memConf = MemOp0 & MemOp1;             // 2 accesos a memoria (1 puerto)
  wire brConf  = BranchJump0 & BranchJump1;   // 2 saltos (1 unidad)
  wire canIssue2 = ~(rawPair | memConf | brConf);

  // load-use: una a emitir usa un lw que esta en EX -> stall
  wire useLwE0 = lwE0 & (RdE0 != 5'd0) &
       ( (RdE0 == Rs1_0) | (RdE0 == Rs2_0) | (RdE0 == Rs1_1) | (RdE0 == Rs2_1) );
  wire useLwE1 = lwE1 & (RdE1 != 5'd0) &
       ( (RdE1 == Rs1_0) | (RdE1 == Rs2_0) | (RdE1 == Rs1_1) | (RdE1 == Rs2_1) );
  assign stall = useLwE0 | useLwE1;

  assign issue1     = ~stall & canIssue2;
  assign issueCount = stall ? 2'd0 : (canIssue2 ? 2'd2 : 2'd1);
endmodule
