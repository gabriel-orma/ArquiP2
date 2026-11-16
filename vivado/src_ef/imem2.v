// imem2: memoria de instrucciones de 2 puertos (lee PC y PC+4). Carga riscvtest.dat.
module imem2(input  [31:0] a,
             output [31:0] rd0,
             output [31:0] rd1);
  reg [31:0] RAM[63:0];
  initial $readmemh("riscvtest.dat", RAM);
  assign rd0 = RAM[a[31:2]];        // instruccion en PC
  assign rd1 = RAM[a[31:2] + 1];    // instruccion en PC+4
endmodule
