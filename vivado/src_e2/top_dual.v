// top_dual: top-level del procesador SUPERESCALAR dual-issue in-order (E2).
// Conecta el datapath dual con la memoria de instrucciones de 2 puertos (imem2)
// y la memoria de datos de 1 puerto (dmem, reusada del pipeline single-issue).
module top_dual(input         clk, reset,
                output [31:0] WriteData, DataAdr,
                output        MemWrite);

  wire [31:0] PCF, Instr0F, Instr1F, ReadData;
  wire [1:0]  issueCount;

  // memoria de instrucciones: 2 puertos (lee PC y PC+4). Carga 'riscvtest.dat'.
  imem2 imem(.a(PCF), .rd0(Instr0F), .rd1(Instr1F));

  // procesador dual-issue
  datapath_dual dp(
    .clk(clk), .reset(reset),
    .PCF(PCF), .Instr0F(Instr0F), .Instr1F(Instr1F),
    .MemWriteM(MemWrite), .DataAdrM(DataAdr), .WriteDataM(WriteData),
    .ReadDataM(ReadData),
    .issueCountOut(issueCount)
  );

  // memoria de datos: 1 puerto (reusa dmem del pipeline)
  dmem dmem(.clk(clk), .we(MemWrite), .a(DataAdr), .wd(WriteData), .rd(ReadData));
endmodule
