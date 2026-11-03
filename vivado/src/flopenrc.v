// flopenrc: flip-flop con ENABLE, reset asincrono y CLEAR sincrono.
// Combina los dos anteriores. Prioridad: reset > clear > enable > conservar.
//   - clear=1 -> pone q a 0 (FLUSH), aunque en=0
//   - en=0    -> conserva (STALL)
//   - en=1    -> captura d
// Se usa en el registro IF/ID, que necesita AMBOS: congelarse en un stall
// (en=~StallD) y limpiarse en un flush (clear=FlushD).
module flopenrc (input  clk, reset, clear, en,
                 input  [WIDTH-1:0] d,
                 output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)      q <= 0;   // reset
    else if (clear) q <= 0;   // flush (tiene prioridad sobre enable)
    else if (en)    q <= d;   // captura si esta habilitado
    // si en=0 y clear=0: conserva (stall)
  end
endmodule
