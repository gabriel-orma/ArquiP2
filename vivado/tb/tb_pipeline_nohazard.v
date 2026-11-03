// Testbench del pipeline con el programa sin dependencias.
// Verifica que se escriba 25 en la direccion 100 (igual que el single-cycle).
// Genera VCD y termina con $finish y mensaje PASS/FAIL.
`timescale 1ns/1ps
module tb_pipeline_nohazard;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;

  top dut(
    .clk(clk), .reset(reset),
    .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite)
  );

  initial begin
    $dumpfile("pipeline_nohazard.vcd");
    $dumpvars(0, tb_pipeline_nohazard);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  always @(negedge clk) begin
    if (MemWrite) begin
      if (DataAdr === 100 && WriteData === 25) begin
        $display("PASS: el pipeline escribio 25 en la direccion 100");
        #20 $finish;
      end else begin
        $display("FAIL: escritura inesperada  DataAdr=%0d  WriteData=%0d", DataAdr, WriteData);
        #20 $finish;
      end
    end
  end

  initial begin
    #2000;
    $display("TIMEOUT: nunca se escribio en memoria (algo esta mal)");
    $finish;
  end
endmodule
