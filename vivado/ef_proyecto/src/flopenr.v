// flopenr: flip-flop con ENABLE y reset asincrono.
// Igual que flopr, pero con una entrada 'en':
//   - si en=1 -> captura d en el flanco (comportamiento normal)
//   - si en=0 -> CONSERVA su valor (congela) -> sirve para STALL
// Se usa en el registro PC y en el registro IF/ID (se congelan al hacer stall).
module flopenr (input  clk, reset, en,
                input  [WIDTH-1:0] d,
                output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)   q <= 0;      // reset: fuerza 0
    else if (en) q <= d;      // habilitado: captura la entrada
    // si en=0: q no cambia (se mantiene) -> burbuja/stall
  end
endmodule
