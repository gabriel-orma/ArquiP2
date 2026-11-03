// tb_pipeline_generic.v -- testbench GENERICO para CUALQUIER programa.
// No verifica un valor fijo: solo corre el pipeline y VUELCA el estado final
// (registros y memoria de datos) a la consola, ademas de mostrar cada STORE.
// Sirve para el programa del profesor, cuyo resultado esperado no conocemos.
`timescale 1ns/1ps
module tb_pipeline_generic;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;
  integer i;

  top dut(.clk(clk), .reset(reset),
          .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  initial begin
    $dumpfile("pipeline_generic.vcd");
    $dumpvars(0, tb_pipeline_generic);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  // muestra en vivo cada escritura a memoria (cada sw)
  always @(negedge clk) begin
    if (MemWrite)
      $display("t=%0t  STORE  Mem[byte %0d] = %0d  (0x%08h)",
               $time, DataAdr, WriteData, WriteData);
  end

  // corre un tiempo fijo y vuelca el estado final
  initial begin
    #2000;
    $display("\n===== REGISTROS (x0..x31) =====");
    for (i = 0; i < 32; i = i + 1) begin
      if (i == 0)
        $display("  x0  = 0");
      else
        $display("  x%0d = %0d  (0x%08h)", i, dut.rvsingle.dp.rf.rf[i], dut.rvsingle.dp.rf.rf[i]);
    end
    $display("\n===== MEMORIA DE DATOS (palabras 0..31) =====");
    for (i = 0; i < 32; i = i + 1)
      $display("  Mem palabra %0d (byte %0d) = %0d  (0x%08h)",
               i, i*4, dut.dmem.RAM[i], dut.dmem.RAM[i]);
    $display("\n(fin de la simulacion generica)");
    $finish;
  end
endmodule
