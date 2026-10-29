// Testbench con volcado VCD para ver el single-cycle en GTKWave.
// NO modifica el testbench entregado (src/single_cycle/testbench.v): es una copia
// que ademas genera single_cycle.vcd y usa $finish (no $stop) para correr en batch.
`timescale 1ns/1ps
module tb_single_cycle_wave;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;

  // dispositivo bajo prueba
  top dut(
    .clk(clk),
    .reset(reset),
    .WriteData(WriteData),
    .DataAdr(DataAdr),
    .MemWrite(MemWrite)
  );

  // volcado de ondas: nivel 0 = toda la jerarquia bajo este modulo
  initial begin
    $dumpfile("single_cycle.vcd");
    $dumpvars(0, tb_single_cycle_wave);
  end

  // reset inicial
  initial begin
    reset = 1; #22; reset = 0;
  end

  // reloj de 10 ns
  always begin
    clk = 1; #5; clk = 0; #5;
  end

  // chequeo de resultado (igual que el testbench original) + corte limpio
  always @(negedge clk) begin
    if (MemWrite) begin
      if (DataAdr === 100 & WriteData === 25) begin
        $display("Simulation succeeded");
        #20 $finish;
      end else if (DataAdr !== 96) begin
        $display("Simulation failed");
        #20 $finish;
      end
    end
  end

  // tope de seguridad por si nunca se cumple la condicion
  initial begin
    #2000;
    $display("Timeout: no se alcanzo la condicion de exito");
    $finish;
  end
endmodule
