// regfile2w: Register File con 4 LECTURAS y 2 ESCRITURAS por ciclo (E2).
//
// Por que 4R/2W: el dual-issue emite hasta 2 instrucciones por ciclo, y cada
// una lee hasta 2 registros (2x2 = 4 lecturas) y escribe hasta 1 (2 escrituras).
//
// Escritura: en FLANCO DE BAJADA (negedge), igual que el pipeline single-issue,
// para resolver la dependencia a distancia (write-before-read): si una
// instruccion escribe en WB y otra lee el mismo registro el mismo ciclo, la
// lectura ve el valor NUEVO.
//
// ESCRITURA SIMULTANEA al MISMO registro (regla del enunciado): si las dos vias
// escriben el mismo rd en el mismo ciclo, debe ganar la MAS JOVEN en orden de
// programa (via 1). Se logra escribiendo primero la via0 y luego la via1 dentro
// del mismo bloque: la ultima asignacion no-bloqueante al mismo rf[] prevalece.
module regfile2w(
  input         clk,
  input         we1, we2,            // enables de las 2 escrituras (via0, via1)
  input  [4:0]  a1, a2, a3, a4,      // 4 direcciones de lectura
  input  [4:0]  wa1, wa2,            // 2 direcciones de escritura (via0, via1)
  input  [31:0] wd1, wd2,            // 2 datos de escritura
  output [31:0] rd1, rd2, rd3, rd4   // 4 datos leidos
);
  integer i;
  reg [31:0] rf[31:0];

  // valor inicial 0 en todos (evita 'x' entre simuladores; lo pide CLAUDE.md)
  initial for (i = 0; i < 32; i = i + 1) rf[i] = 32'b0;

  // 2 escrituras en negedge. Orden via0 -> via1: si wa1==wa2, gana via1 (joven).
  always @(negedge clk) begin
    if (we1 && (wa1 != 5'd0)) rf[wa1] <= wd1;   // via 0 (mayor, mas vieja)
    if (we2 && (wa2 != 5'd0)) rf[wa2] <= wd2;   // via 1 (menor, mas joven) GANA
  end

  // 4 lecturas combinacionales. x0 cableado a 0.
  assign rd1 = (a1 != 5'd0) ? rf[a1] : 32'b0;
  assign rd2 = (a2 != 5'd0) ? rf[a2] : 32'b0;
  assign rd3 = (a3 != 5'd0) ? rf[a3] : 32'b0;
  assign rd4 = (a4 != 5'd0) ? rf[a4] : 32'b0;
endmodule
