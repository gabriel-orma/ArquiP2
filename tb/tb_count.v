// tb_count: mide ciclos hasta completar (sw a Mem[100]). Sirve para A/B/C.
// Compilar con -DOPT para la config C (top_dual_opt), -DSINGLE para A (top), sin
// define para B (top_dual). Carga el programa desde riscvtest.dat.
`timescale 1ns/1ps
module tb_count;
  reg clk, reset;
  wire [31:0] WriteData, DataAdr;
  wire        MemWrite;

`ifdef SINGLE
  top dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
`elsif OPT
  top_dual_opt dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
`else
  top_dual dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
`endif

  integer cyc = 0;
  reg done = 0;

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  always @(posedge clk) if (!reset && !done) begin
    cyc = cyc + 1;
    if (MemWrite && DataAdr == 32'd100) begin
      done = 1;
      $display("RESULTADO Mem[100]=%0d  CICLOS=%0d", WriteData, cyc);
      #20; $finish;
    end
  end

  initial begin #4000; $display("TIMEOUT (no completo)"); $finish; end
endmodule
