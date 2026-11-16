// tb_C_loop: Config C (dual + predictor + BTB) + bucle (ef_loop). DEMO del predictor.
// En el waveform: predTakenPkt (PREDICE) y flushDE (MISPRED) muestran como el BTB
// aprende el salto de retorno. Esperado: Mem[100]=24.
`timescale 1ns/1ps
module tb_C_loop;
  reg clk, reset; wire [31:0] WriteData, DataAdr; wire MemWrite;
  localparam [31:0] FIN = 32'd32;
  integer cyc = 0, cyc_done = 0; reg done = 0;

  top_dual_opt #(.MEMFILE("ef_loop.dat")) dut(.clk(clk), .reset(reset),
      .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
  wire [31:0] PCnow = dut.PCF;

  wire [31:0] i0F = dut.dp.Instr0F, i1F = dut.dp.Instr1F, i0D = dut.dp.I0D, i1D = dut.dp.I1D;
  reg  [31:0] i0E,i0M,i0W,i1E,i1M,i1W;
  always @(posedge clk or posedge reset)
    if (reset) begin i0E<=0;i0M<=0;i0W<=0;i1E<=0;i1M<=0;i1W<=0; end
    else begin i0E<=dut.dp.clear0?32'b0:i0D; i1E<=dut.dp.clear1?32'b0:i1D;
               i0M<=i0E;i0W<=i0M;i1M<=i1E;i1W<=i1M; end
  wire [8*8:1] t0F,t0E,t0M,t0W,t1F,t1E,t1M,t1W;
  disasm d0F(.instr(i0F),.txt(t0F)); disasm d0E(.instr(i0E),.txt(t0E));
  disasm d0M(.instr(i0M),.txt(t0M)); disasm d0W(.instr(i0W),.txt(t0W));
  disasm d1F(.instr(i1F),.txt(t1F)); disasm d1E(.instr(i1E),.txt(t1E));
  disasm d1M(.instr(i1M),.txt(t1M)); disasm d1W(.instr(i1W),.txt(t1W));
  wire [1:0] em = dut.dp.issueCountOut;
  wire predS  = dut.dp.predTakenPkt;   // PREDICE
  wire mispS  = dut.dp.flushDE;        // MISPRED
  wire hit0S  = dut.dp.btb_hit0, hit1S = dut.dp.btb_hit1;

  integer finCnt = 0, finStart = 0;
  initial begin $dumpfile("C_loop.vcd"); $dumpvars(0, tb_C_loop); end
  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  always @(posedge clk) if (!reset && !done) begin
    cyc = cyc + 1;
    // traza por consola de la prediccion
    $display("c%0d PC=%0d %s %s | v0 F=%s E=%s | v1 F=%s E=%s",
             cyc, PCnow, predS?"PREDICE":"       ", mispS?"MISPRED":"       ",
             t0F, t0E, t1F, t1E);
    if (PCnow >= FIN) begin
      if (finCnt == 0) finStart = cyc;
      finCnt = finCnt + 1;
      if (finCnt >= 6) begin done = 1; cyc_done = finStart; end
    end else finCnt = 0;
  end
  initial begin
    wait (done); #40;
    $display("==== [C] bucle ef_loop: Mem[100] = %0d (esperado 24) ====", dut.dmem.RAM[25]);
    $finish;
  end
  initial begin #20000; $display("TIMEOUT"); $finish; end
endmodule
