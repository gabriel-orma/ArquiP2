// tb_dual_trace: testbench GENERICO de traza para el dual-issue (E2).
//
// Pensado para la critica del profesor en E1: que en el waveform se vea CLARO
// lo que pasa, con las instrucciones en TEXTO (no binario). Por cada ciclo
// imprime, por via y por etapa, que instruccion esta (mnemonico via disasm) y
// cuantas se emiten, con banderas STALL/FLUSH/ANNUL.
//
// Corre el programa cargado en 'riscvtest.dat' (se intercambia el .dat para
// cada prueba). Al final vuelca registros y memoria.
//
// Para Vivado: expone senales txt* (ASCII) para poner en la waveform con
// radix ASCII y ver las instrucciones por nombre en cada etapa.
`timescale 1ns/1ps
module tb_dual_trace;
  reg clk, reset;
  wire [31:0] WriteData, DataAdr;
  wire        MemWrite;
  integer i;

  top_dual dut(.clk(clk), .reset(reset),
               .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  // ---- instrucciones buscadas (etapa F/D de cada via) ----
  wire [31:0] i0F = dut.dp.Instr0F;
  wire [31:0] i1F = dut.dp.Instr1F;

  // ---- reconstruccion de la instruccion en cada etapa (vias 0 y 1) ----
  // Se replica el pipeline: D/E se limpia con clear0/clear1 (burbuja); E/M y
  // M/W solo propagan. Asi sabemos que instruccion viaja por cada etapa.
  reg [31:0] i0E, i0M, i0W, i1E, i1M, i1W;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      i0E<=0; i0M<=0; i0W<=0; i1E<=0; i1M<=0; i1W<=0;
    end else begin
      i0E <= dut.dp.clear0 ? 32'b0 : i0F;
      i1E <= dut.dp.clear1 ? 32'b0 : i1F;
      i0M <= i0E;  i0W <= i0M;
      i1M <= i1E;  i1W <= i1M;
    end
  end

  // ---- traduccion a texto (una instancia disasm por etapa/via) ----
  wire [8*8:1] t0F,t0E,t0M,t0W, t1F,t1E,t1M,t1W;
  disasm d0F(.instr(i0F),.txt(t0F));  disasm d0E(.instr(i0E),.txt(t0E));
  disasm d0M(.instr(i0M),.txt(t0M));  disasm d0W(.instr(i0W),.txt(t0W));
  disasm d1F(.instr(i1F),.txt(t1F));  disasm d1E(.instr(i1E),.txt(t1E));
  disasm d1M(.instr(i1M),.txt(t1M));  disasm d1W(.instr(i1W),.txt(t1W));

  initial begin
    $dumpfile("dual_trace.vcd");
    $dumpvars(0, tb_dual_trace);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  integer cyc = 0;
  reg [8*10:1] flags;
  always @(posedge clk) if (!reset) begin
    cyc = cyc + 1;
    flags = dut.dp.stall   ? "STALL " :
            dut.dp.flushDE ? "FLUSH " :
            dut.dp.annul1  ? "ANNUL " : "      ";
    $display("c%0d PC=%0d em=%0d %s| v0 F=%s E=%s M=%s W=%s | v1 F=%s E=%s M=%s W=%s",
             cyc, dut.dp.PCF, dut.dp.issueCountOut, flags,
             t0F, t0E, t0M, t0W, t1F, t1E, t1M, t1W);
  end

  initial begin
    #300;
    $display("---------- estado final ----------");
    for (i = 1; i < 12; i = i + 1)
      $display("  x%0d = %0d", i, dut.dp.rf.rf[i]);
    $display("  Mem[96]=%0d  Mem[100]=%0d", dut.dmem.RAM[24], dut.dmem.RAM[25]);
    $finish;
  end
endmodule
