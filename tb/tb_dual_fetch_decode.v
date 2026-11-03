// Testbench del front-end dual PRELIMINAR (dual fetch + dual decode).
// Demuestra que se traen y decodifican 2 instrucciones por ciclo.
// PASS: en algun ciclo las 2 vias decodifican a la vez (ambos RegWrite=1).
`timescale 1ns/1ps
module tb_dual_fetch_decode;
  reg clk, reset;
  wire [31:0] PCF, Instr0F, Instr1F;
  wire [31:0] Instr0D, Instr1D;
  wire        RegWrite0D, RegWrite1D;
  wire [2:0]  ALUControl0D, ALUControl1D;
  wire [4:0]  Rs1_0D, Rs2_0D, Rd0D, Rs1_1D, Rs2_1D, Rd1D;

  imem2 imem(.a(PCF), .rd0(Instr0F), .rd1(Instr1F));
  dualfetchdecode dut(
    .clk(clk), .reset(reset), .PCF(PCF),
    .Instr0F(Instr0F), .Instr1F(Instr1F),
    .Instr0D(Instr0D), .Instr1D(Instr1D),
    .RegWrite0D(RegWrite0D), .RegWrite1D(RegWrite1D),
    .ALUControl0D(ALUControl0D), .ALUControl1D(ALUControl1D),
    .Rs1_0D(Rs1_0D), .Rs2_0D(Rs2_0D), .Rd0D(Rd0D),
    .Rs1_1D(Rs1_1D), .Rs2_1D(Rs2_1D), .Rd1D(Rd1D)
  );

  integer dual_ok = 0;

  initial begin
    $dumpfile("dual_fetch_decode.vcd");
    $dumpvars(0, tb_dual_fetch_decode);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  // observa el decode en cada flanco de subida (cuando IF/ID ya cargo el par)
  always @(posedge clk) begin
    if (!reset) begin
      $display("PC=%0d | via0: Instr=%h Rd=x%0d RegWr=%b | via1: Instr=%h Rd=x%0d RegWr=%b",
               PCF, Instr0D, Rd0D, RegWrite0D, Instr1D, Rd1D, RegWrite1D);
      if (RegWrite0D && RegWrite1D && (Instr0D !== Instr1D))
        dual_ok = 1;   // dos instrucciones distintas decodificadas a la vez
    end
  end

  initial begin
    #120;
    if (dual_ok)
      $display("PASS: dual decode -> 2 instrucciones decodificadas en el mismo ciclo");
    else
      $display("FAIL: no se observo decode simultaneo de 2 vias");
    $finish;
  end
endmodule
