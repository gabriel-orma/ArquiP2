module floprc (input  clk, reset, clear,
               input  [WIDTH-1:0] d,
               output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)      q <= 0;  // reset: fuerza 0
    else if (clear) q <= 0;  // clear: limpia (burbuja/flush)
    else            q <= d;  // normal: captura la entrada
  end
endmodule
