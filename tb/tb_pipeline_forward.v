// Testbench del pipeline con prog_forward (data hazards resueltos por FORWARDING).
// Verifica que se escriba 28 en la direccion 100.
`timescale 1ns/1ps
module tb_pipeline_forward;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;
  localparam EXPECTED = 28;

  top dut(.clk(clk), .reset(reset),
          .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  initial begin
    $dumpfile("pipeline_forward.vcd");
    $dumpvars(0, tb_pipeline_forward);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  // solo nos interesa la escritura a la direccion 100 (resultado final)
  always @(negedge clk) begin
    if (MemWrite && DataAdr === 100) begin
      if (WriteData === EXPECTED)
        $display("PASS: forwarding -> Mem[100] = %0d (esperado %0d)", WriteData, EXPECTED);
      else
        $display("FAIL: forwarding -> Mem[100] = %0d (esperado %0d)", WriteData, EXPECTED);
      #20 $finish;
    end
  end

  initial begin
    #2000;
    $display("TIMEOUT: nunca se escribio en la direccion 100");
    $finish;
  end
endmodule
