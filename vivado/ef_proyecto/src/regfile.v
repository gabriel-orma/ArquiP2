module regfile(input  clk, 
               input  we3, 
               input  [ 4:0] a1, a2, a3, 
               input  [31:0] wd3, 
               output [31:0] rd1, rd2); 

  reg [31:0] rf[31:0];

  // CAMBIO PIPELINE (correccion 2): escribe en FLANCO DE BAJADA (negedge).
  // Asi, cuando WB escribe un registro y una instruccion en ID lo lee EN EL
  // MISMO CICLO (dependencia a distancia 3), la escritura ocurre en la primera
  // mitad del ciclo y la lectura ve el valor NUEVO (write-before-read). Esto
  // cierra el caso que el forwarding no cubre, sin un tercer cable de adelanto.
  always @(negedge clk) begin
    if (we3) rf[a3] <= wd3;
  end

  // read two ports combinationally (A1/RD1, A2/RD2)
  // register 0 hardwired to 0
  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule