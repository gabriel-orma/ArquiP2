// imem2: memoria de instrucciones de 2 puertos (lee PC y PC+4). Carga riscvtest.dat.
module imem2 #(parameter MEMFILE = "riscvtest.dat")
             (input  [31:0] a,
              output [31:0] rd0,
              output [31:0] rd1);
  reg [31:0] RAM[255:0];    // 256 palabras (programas de hasta 256 instrucciones)
  integer i;
  initial begin
    for (i = 0; i < 256; i = i + 1) RAM[i] = 32'b0;
    $readmemh(MEMFILE, RAM);
  end
  assign rd0 = RAM[a[31:2]];        // instruccion en PC
  assign rd1 = RAM[a[31:2] + 1];    // instruccion en PC+4
endmodule
