module flopenr (input  clk, reset, en,
                input  [WIDTH-1:0] d,
                output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)   q <= 0;  // reset: fuerza 0
    else if (en) q <= d;  // habilitado: captura la entrada
  end
endmodule
