// disasm.v -- SOLO PARA SIMULACION / WAVEFORM. No se sintetiza ni afecta la logica.
// Traduce una instruccion de 32 bits a un mnemonico corto (8 chars ASCII),
// para poder VER en la waveform/consola que instruccion esta en cada etapa
// (en vez de leer el binario). instr=0 se muestra como "bubble" (NOP/flush).
module disasm(input [31:0] instr, output reg [8*8:1] txt);
  wire [6:0] op = instr[6:0];
  wire [2:0] f3 = instr[14:12];
  wire       f7 = instr[30];

  always @* begin
    if (^instr === 1'bx) txt = "----    ";       // memoria sin cargar (post-programa)
    else case (op)
      7'b0110011: case (f3)                         // R-type
                    3'b000: txt = f7 ? "sub     " : "add     ";
                    3'b010: txt = "slt     ";
                    3'b110: txt = "or      ";
                    3'b111: txt = "and     ";
                    default: txt = "r-?     ";
                  endcase
      7'b0010011: case (f3)                         // I-type ALU
                    3'b000: txt = "addi    ";
                    3'b010: txt = "slti    ";
                    3'b110: txt = "ori     ";
                    3'b111: txt = "andi    ";
                    default: txt = "i-?     ";
                  endcase
      7'b0000011: txt = "lw      ";
      7'b0100011: txt = "sw      ";
      7'b1100011: txt = "beq     ";
      7'b1101111: txt = "jal     ";
      7'b0000000: txt = "bubble  ";                 // instr=0 -> NOP / burbuja / flush
      default:    txt = "???     ";
    endcase
  end
endmodule
