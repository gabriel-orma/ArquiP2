`timescale 1ns/1ps
module tb_pipeline_stall;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;
  localparam EXPECTED = 14;

  top dut(.clk(clk), .reset(reset),
          .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  initial begin
    $dumpfile("pipeline_stall.vcd");
    $dumpvars(0, tb_pipeline_stall);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  always @(negedge clk) begin
    if (MemWrite && DataAdr === 100) begin
      if (WriteData === EXPECTED)
        $display("PASS: load-use -> Mem[100] = %0d (esperado %0d)", WriteData, EXPECTED);
      else
        $display("FAIL: load-use -> Mem[100] = %0d (esperado %0d)", WriteData, EXPECTED);
      #20 $finish;
    end
  end

  initial begin
    #2000;
    $display("TIMEOUT: nunca se escribio en la direccion 100");
    $finish;
  end
endmodule
