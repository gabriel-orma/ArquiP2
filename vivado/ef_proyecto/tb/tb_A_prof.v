// tb_A_prof: Config A (pipeline single-issue) + programa del PROFESOR.
// Elige este testbench como top de simulacion y dale Run. 'done' = senal de
// comprobacion (se alcanzo fin). Imprime ciclos y vuelca la memoria resultado.
`timescale 1ns/1ps
module tb_A_prof;
  reg clk, reset; wire [31:0] WriteData, DataAdr; wire MemWrite;
  localparam [31:0] FIN = 32'd356;              // etiqueta fin del programa del profesor
  integer cyc = 0, cyc_done = 0, i; reg done = 0;

  top #(.MEMFILE("prof_ef.dat")) dut(.clk(clk), .reset(reset),
      .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PC;

  initial begin $dumpfile("A_prof.vcd"); $dumpvars(0, tb_A_prof); end
  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  // completado = el PC se queda en la region de fin (>=6 ciclos); un paso
  // transitorio por fin (el pipeline busca mas alla del salto) dura 1-2 ciclos.
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
    $display("==== [A pipeline] programa profesor: fin en %0d ciclos ====", cyc_done);
    $display("Estado de memoria M[x1+off] (x1=1536):");
    for (i = 0; i <= 13; i = i + 1) $display("  M[x1+%0d] = %0d", i*4, dut.dmem.RAM[384+i]);
    $finish;
  end
  initial begin #40000; $display("TIMEOUT"); $finish; end
endmodule
