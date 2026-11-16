module imem(input  [31:0] a,
            output [31:0] rd);

  reg [31:0] RAM[255:0];    // 256 palabras
  integer i;
  initial begin
      for (i = 0; i < 256; i = i + 1) RAM[i] = 32'b0;
      $readmemh("riscvtest.dat", RAM);
  end

  assign rd = RAM[a[31:2]]; // word aligned
endmodule
