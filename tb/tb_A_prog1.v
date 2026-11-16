// tb_A_prog1: Config A (pipeline single-issue) + programa PROPIO (arreglo+bucle).
// Resultado esperado: Mem[100] = 30.
`timescale 1ns/1ps
module tb_A_prog1;
  reg clk, reset; wire [31:0] WriteData, DataAdr; wire MemWrite;
  localparam [31:0] FIN = 32'd84;               // etiqueta fin de ef_prog1
  integer cyc = 0, cyc_done = 0; reg done = 0;

  top #(.MEMFILE("ef_prog1.dat")) dut(.clk(clk), .reset(reset),
      .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PC;

  initial begin $dumpfile("A_prog1.vcd"); $dumpvars(0, tb_A_prog1); end
  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  integer finCnt = 0, finStart = 0;
  always @(posedge clk) if (!reset && !done) begin
    cyc = cyc + 1;
    if (PCnow >= FIN) begin
      if (finCnt == 0) finStart = cyc;
      finCnt = finCnt + 1;
      if (finCnt >= 6) begin done = 1; cyc_done = finStart; end
    end else finCnt = 0;
  end
  initial begin
    wait (done); #60;
    $display("==== [A pipeline] programa propio: fin en %0d ciclos ====", cyc_done);
    $display("  Mem[100] = %0d  (esperado 30)", dut.dmem.RAM[25]);
    $finish;
  end
  initial begin #40000; $display("TIMEOUT"); $finish; end
endmodule
