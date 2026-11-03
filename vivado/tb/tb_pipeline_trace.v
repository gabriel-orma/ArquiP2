// tb_pipeline_trace.v -- DEMOSTRACION VISUAL del flujo por etapas.
// Reconstruye la instruccion presente en cada etapa (F,D,E,M,W) y la traduce
// a texto con 'disasm', para ver COMO una instruccion avanza por el pipeline
// y como aparecen BURBUJAS en los stalls y flushes. No modifica el procesador:
// solo observa sus senales internas.
`timescale 1ns/1ps
module tb_pipeline_trace;
  reg          clk, reset;
  wire [31:0]  WriteData, DataAdr;
  wire         MemWrite;
  integer      ciclo;

  top dut(.clk(clk), .reset(reset),
          .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  // ---- instruccion visible en cada etapa ----
  wire [31:0] InstrF = dut.Instr;              // la que se esta buscando (F)
  wire [31:0] InstrD = dut.rvsingle.dp.InstrD; // ya registrada en Decode (D)
  reg  [31:0] InstrE, InstrM, InstrW;          // reconstruidas (debug) para E,M,W

  // Mismo comportamiento que los registros reales: ID/EX se limpia con FlushE
  // (burbuja de load-use o de branch), EX/MEM y MEM/WB solo avanzan.
  always @(posedge clk or posedge reset)
    if (reset) begin InstrE <= 0; InstrM <= 0; InstrW <= 0; end
    else begin
      InstrE <= dut.rvsingle.dp.FlushE ? 32'b0 : InstrD;
      InstrM <= InstrE;
      InstrW <= InstrM;
    end

  // ---- texto por etapa (sirve para consola Y para la waveform en radix ASCII) ----
  wire [8*8:1] txtF, txtD, txtE, txtM, txtW;
  disasm dF(.instr(InstrF), .txt(txtF));
  disasm dD(.instr(InstrD), .txt(txtD));
  disasm dE(.instr(InstrE), .txt(txtE));
  disasm dM(.instr(InstrM), .txt(txtM));
  disasm dW(.instr(InstrW), .txt(txtW));

  initial begin
    $dumpfile("pipeline_trace.vcd");
    $dumpvars(0, tb_pipeline_trace);
  end

  initial begin reset = 1; #22; reset = 0; end
  always  begin clk = 1; #5; clk = 0; #5; end

  initial ciclo = 0;
  always @(posedge clk) ciclo = ciclo + 1;

  // Tabla por ciclo: cada fila es una "foto" del pipeline en ese ciclo.
  // Se lee de izquierda (F) a derecha (W); una instruccion baja una columna por ciclo.
  initial $display("\nciclo |   F     |   D     |   E     |   M     |   W");
  always @(negedge clk) if (!reset)
    $display(" %2d   | %-7s | %-7s | %-7s | %-7s | %-7s",
             ciclo, txtF, txtD, txtE, txtM, txtW);

  initial begin
    #140;
    $display("\n(fin del trace)\n");
    $finish;
  end
endmodule
