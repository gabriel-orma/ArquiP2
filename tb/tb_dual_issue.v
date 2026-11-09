// tb_dual_issue: verifica el procesador dual-issue in-order (E2).
//
// Corre el MISMO programa de referencia que el pipeline single-issue
// (riscvtest.dat, que deja Mem[100]=25) para comprobar EQUIVALENCIA FUNCIONAL:
// el dual debe dar el mismo resultado final que las config. anteriores.
//
// Ademas imprime, por ciclo: PC, cuantas instrucciones se emiten (issueCount)
// y las 2 instrucciones buscadas (en ASCII via disasm), para VER el dual-issue.
`timescale 1ns/1ps
module tb_dual_issue;
  reg clk, reset;
  wire [31:0] WriteData, DataAdr;
  wire        MemWrite;
  integer i;

  top_dual dut(.clk(clk), .reset(reset),
               .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  // traduccion a mnemonico de las 2 instrucciones del par buscado
  wire [8*8:1] t0, t1;
  disasm d0(.instr(dut.Instr0F), .txt(t0));
  disasm d1(.instr(dut.Instr1F), .txt(t1));

  initial begin
    $dumpfile("dual_issue.vcd");
    $dumpvars(0, tb_dual_issue);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  integer cyc = 0;
  always @(posedge clk) if (!reset) begin
    cyc = cyc + 1;
    $display("c%0d  PC=%0d  emite=%0d | via0: %s via1: %s",
             cyc, dut.PCF, dut.issueCount, t0, t1);
  end

  initial begin
    #700;
    $display("---------- estado final ----------");
    for (i = 0; i < 12; i = i + 1)
      $display("  x%0d = %0d", i, dut.dp.rf.rf[i]);
    $display("  Mem[100] = %0d  (esperado 25)", dut.dmem.RAM[25]);
    if (dut.dmem.RAM[25] === 32'd25)
      $display("PASS: dual-issue equivalente al single-cycle (Mem[100]=25)");
    else
      $display("FAIL: Mem[100] = %0d  (se esperaba 25)", dut.dmem.RAM[25]);
    $finish;
  end
endmodule
