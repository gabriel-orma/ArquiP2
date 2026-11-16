module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);

  reg [31:0] RAM[1023:0];   // 1024 palabras (soporta bases altas, p. ej. x1=1536)
  integer i;
  initial for (i = 0; i < 1024; i = i + 1) RAM[i] = 32'b0;

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk) begin
    if (we) RAM[a[31:2]] <= wd;
  end
endmodule
