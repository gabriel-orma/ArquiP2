// Testbench del pipeline con prog_flush (BRANCH tomado: flush de 2 instrucciones).
// Verifica que se escriba 5 en la direccion 100. Si el flush fallara, las 2
// instrucciones 'veneno' (addi x1,99 / addi x1,77) ejecutarian y el valor seria 77.
`timescale 1ns/1ps
module tb_pipeline_flush;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;
  localparam EXPECTED = 5;

  top dut(.clk(clk), .reset(reset),
          .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  initial begin
    $dumpfile("pipeline_flush.vcd");
    $dumpvars(0, tb_pipeline_flush);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  always @(negedge clk) begin
    if (MemWrite && DataAdr === 100) begin
      if (WriteData === EXPECTED)
        $display("PASS: flush branch -> Mem[100] = %0d (esperado %0d)", WriteData, EXPECTED);
      else
        $display("FAIL: flush branch -> Mem[100] = %0d (esperado %0d, veneno no anulado)", WriteData, EXPECTED);
      #20 $finish;
    end
  end

  initial begin
    #2000;
    $display("TIMEOUT: nunca se escribio en la direccion 100");
    $finish;
  end
endmodule
