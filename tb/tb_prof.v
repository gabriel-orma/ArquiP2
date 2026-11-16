// tb_prof: testbench del programa OFICIAL del profesor (EF).
// Completa al alcanzar la etiqueta fin (dir 356). Cuenta ciclos EXCLUYENDO el
// bucle fin y vuelca M[x1+0..52] (x1=1536) para comparar con los estados de
// referencia. 'done' es la SENAL DE COMPROBACION (visible en el waveform).
// Compilar: -DSINGLE (A), sin define (B), -DOPT (C).
`timescale 1ns/1ps
module tb_prof;
  reg clk, reset;
  wire [31:0] WriteData, DataAdr;
  wire        MemWrite;
  localparam [31:0] FIN  = 32'd356;   // direccion de la etiqueta fin
  localparam        BASE = 384;       // palabra base de datos (x1=1536 -> 1536/4)

`ifdef SINGLE
  top dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PC;
`elsif OPT
  top_dual_opt dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PCF;
`else
  top_dual dut(.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PCF;
`endif

  integer cyc = 0, cyc_done = 0, i;
  reg done = 0;   // SENAL DE COMPROBACION: se alcanzo la etiqueta fin

  initial begin $dumpfile("prof.vcd"); $dumpvars(0, tb_prof); end
  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  // completado = el PC se queda sostenidamente en la region de fin (>=6 ciclos);
  // un paso transitorio por fin (el pipeline busca mas alla del salto) dura 1-2.
  integer finCnt = 0, finStart = 0;
  always @(posedge clk) if (!reset && !done) begin
    cyc = cyc + 1;
    if (PCnow >= FIN) begin
      if (finCnt == 0) finStart = cyc;
      finCnt = finCnt + 1;
      if (finCnt >= 6) begin done = 1; cyc_done = finStart; end
    end else finCnt = 0;
  end

  // al completar, drena el pipeline y vuelca el estado de memoria
  initial begin
    wait (done);
    #60;   // drenar instrucciones en vuelo (ultimos sw)
    $display("==== COMPLETADO (fin alcanzado) en %0d ciclos ====", cyc_done);
    $display("Estado de memoria M[x1+off]  (x1=1536):");
    for (i = 0; i <= 13; i = i + 1)
      $display("  M[x1+%0d] = %0d", i*4, dut.dmem.RAM[BASE + i]);
    $finish;
  end

  initial begin #40000; $display("TIMEOUT (no alcanzo fin)"); $finish; end
endmodule
