module flopenrc (input  clk, reset, clear, en,
                 input  [WIDTH-1:0] d,
                 output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q;

  always @(posedge clk or posedge reset) begin
    if (reset)      q <= 0;  // reset
    else if (clear) q <= 0;
    else if (en)    q <= d;  // captura si esta habilitado
  end
endmodule
