module imem2(input  [31:0] a,
             output [31:0] rd0,  // instruccion en PC
             output [31:0] rd1);  // instruccion en PC+4
  reg [31:0] RAM[63:0];
  initial begin
    $readmemh("riscvtest.dat", RAM);
  end
  assign rd0 = RAM[a[31:2]];  // palabra en PC
  assign rd1 = RAM[a[31:2] + 1];  // palabra siguiente (PC+4)
endmodule
