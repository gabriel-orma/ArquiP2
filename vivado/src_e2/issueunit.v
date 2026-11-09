// issueunit: el "cerebro" del dual-issue in-order (E2).
//
// Cada ciclo mira el PAR candidato (I0 = la mas vieja, I1 = la siguiente en el
// programa) ya decodificado, y decide CUANTAS emitir: 2, 1 o 0, SIN romper el
// orden del programa. La instruccion no emitida NO se pierde: como el front-end
// es combinacional y el PC solo avanza +4 cuando se emite 1, I1 se vuelve a
// buscar el siguiente ciclo como nueva I0 (reagrupamiento).
//
// REGLAS DE EMISION (escritas antes de codificar, como pide CLAUDE.md):
//
//  Emito las 2 (issueCount=2) SOLO si NO hay ninguno de estos conflictos:
//   (a) RAW intra-par : I1 LEE un registro que I0 ESCRIBE  -> I1 debe esperar.
//   (b) Conflicto de memoria : I0 e I1 son ambos acceso a memoria (solo hay
//       1 puerto de datos) -> solo una puede ir.
//   (c) Conflicto de branch  : I0 e I1 son ambos salto (solo hay 1 unidad de
//       resolucion de saltos) -> solo una puede ir.
//  Si hay alguno -> emito solo I0 (issueCount=1); I1 se reagrupa.
//  (Dos ALU independientes SI se permiten: hay 2 ALU.)
//
//  LOAD-USE (stall, issueCount=0): si una instruccion que voy a emitir necesita
//  el resultado de un lw que esta en EX (aun no cargado de memoria), no hay
//  forwarding posible -> congelo 1 ciclo (PC quieto, burbuja). Al ciclo siguiente
//  el lw ya esta en MEM y el forwarding resuelve.
//
// Nota: I0 (la lider del par) siempre se emite salvo stall. El orden se respeta
// porque nunca se emite I1 adelantandose a I0.
module issueunit(
  // --- par candidato ya decodificado (etapa F/D, combinacional) ---
  input  [4:0] Rs1_0, Rs2_0, Rd0,
  input        RegWrite0,            // I0 escribe registro
  input        MemOp0,               // I0 es lw o sw
  input        BranchJump0,          // I0 es beq o jal
  input  [4:0] Rs1_1, Rs2_1,
  input        MemOp1,
  input        BranchJump1,
  // --- estado de EX, para el load-use ---
  input        lwE0, lwE1,           // hay un lw en EX en esa via
  input  [4:0] RdE0, RdE1,           // destino de ese lw
  // --- salidas ---
  output       stall,                // load-use: emitir 0, congelar
  output [1:0] issueCount,           // 2, 1 o 0
  output       issue1                // 1 si la via 1 emite este ciclo
);

  // (a) RAW intra-par: I1 lee lo que I0 escribe (y no es x0)
  wire rawPair = RegWrite0 & (Rd0 != 5'd0) &
                 ( (Rd0 == Rs1_1) | (Rd0 == Rs2_1) );

  // (b) conflicto estructural de memoria
  wire memConf = MemOp0 & MemOp1;

  // (c) conflicto estructural de branch
  wire brConf  = BranchJump0 & BranchJump1;

  // puedo emitir 2 solo si no hay ninguno de los tres conflictos
  wire canIssue2 = ~(rawPair | memConf | brConf);

  // --- load-use: alguna instruccion a emitir usa un lw que esta en EX ---
  wire useLwE0 = lwE0 & (RdE0 != 5'd0) &
       ( (RdE0 == Rs1_0) | (RdE0 == Rs2_0) | (RdE0 == Rs1_1) | (RdE0 == Rs2_1) );
  wire useLwE1 = lwE1 & (RdE1 != 5'd0) &
       ( (RdE1 == Rs1_0) | (RdE1 == Rs2_0) | (RdE1 == Rs1_1) | (RdE1 == Rs2_1) );
  assign stall = useLwE0 | useLwE1;

  // via 1 emite solo si no hay stall y se pueden emitir las 2
  assign issue1     = ~stall & canIssue2;
  assign issueCount = stall ? 2'd0 : (canIssue2 ? 2'd2 : 2'd1);
endmodule
