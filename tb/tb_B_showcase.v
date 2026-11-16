// tb_B_showcase: Config B (dual-issue) + programa showcase. Doble emision. Mem[100]=180.
`timescale 1ns/1ps
module tb_B_showcase;
  reg clk, reset; wire [31:0] WriteData, DataAdr; wire MemWrite;
  localparam [31:0] FIN = 32'd100;
  integer cyc = 0, cyc_done = 0; reg done = 0;

  top_dual #(.MEMFILE("ef_showcase.dat")) dut(.clk(clk), .reset(reset),
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
  wire stallS = dut.dp.stall, flushS = dut.dp.flushDE, annulS = dut.dp.annul1;

  initial begin $dumpfile("B_showcase.vcd"); $dumpvars(0, tb_B_showcase); end
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
    $display("==== [B dual-issue] showcase: fin en %0d ciclos ====", cyc_done);
    $display("  Mem[100] = %0d  (esperado 180)", dut.dmem.RAM[25]);
    $finish;
  end
  initial begin #40000; $display("TIMEOUT"); $finish; end
endmodule
