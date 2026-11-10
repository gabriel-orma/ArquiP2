// top_dual: top-level del procesador dual-issue. Une datapath + imem2 + dmem.
module top_dual(input         clk, reset,
                output [31:0] WriteData, DataAdr,
                output        MemWrite);

  wire [31:0] PCF, Instr0F, Instr1F, ReadData;
  wire [1:0]  issueCount;

  imem2 imem(.a(PCF), .rd0(Instr0F), .rd1(Instr1F));

  datapath_dual dp(
    .clk(clk), .reset(reset),
    .PCF(PCF), .Instr0F(Instr0F), .Instr1F(Instr1F),
    .MemWriteM(MemWrite), .DataAdrM(DataAdr), .WriteDataM(WriteData),
    .ReadDataM(ReadData),
    .issueCountOut(issueCount)
  );

  dmem dmem(.clk(clk), .we(MemWrite), .a(DataAdr), .wd(WriteData), .rd(ReadData));
endmodule
