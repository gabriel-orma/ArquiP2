// floprc: flip-flop con reset asincrono y CLEAR sincrono.
// Igual que flopr, pero con una entrada 'clear':
//   - si clear=1 -> en el flanco pone q a 0 (inserta una BURBUJA / hace FLUSH)
//   - si clear=0 -> captura d normalmente
// Se usa en el registro ID/EX: al hacer flush de un salto o al meter una
// burbuja por load-use, se limpia la instruccion que venia.
module floprc (input  clk, reset, clear,
               input  [WIDTH-1:0] d,
               output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)      q <= 0;   // reset: fuerza 0
    else if (clear) q <= 0;   // clear: limpia (burbuja/flush)
    else            q <= d;   // normal: captura la entrada
  end
endmodule
