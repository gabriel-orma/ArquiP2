// maindec (igual que el single-cycle, con 2 ajustes para el pipeline):
//  - R-type: ImmSrc pasa de 'xx' a '00' (no usa inmediato; evita 'x')
//  - default: pasa de 'x' a todo 0 -> una instruccion desconocida (o el 0 que
//    llena el pipeline al arrancar) se comporta como NOP inofensivo (no escribe
//    registros ni memoria). Esto evita valores 'x' al llenar la tuberia.
module maindec(input  [6:0] op,
               output [1:0] ResultSrc,
               output MemWrite,
               output Branch, ALUSrc,
               output RegWrite, Jump,
               output [1:0] ImmSrc,
               output [1:0] ALUOp);

  reg [10:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump} = controls;

  always @* case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
      7'b0000011: controls = 11'b1_00_1_0_01_0_00_0; // lw
      7'b0100011: controls = 11'b0_01_1_1_00_0_00_0; // sw
      7'b0110011: controls = 11'b1_00_0_0_00_0_10_0; // R-type
      7'b1100011: controls = 11'b0_10_0_0_00_1_01_0; // beq
      7'b0010011: controls = 11'b1_00_1_0_00_0_10_0; // I-type ALU
      7'b1101111: controls = 11'b1_11_0_0_10_0_00_1; // jal
      default:    controls = 11'b0_00_0_0_00_0_00_0; // NOP seguro (evita 'x')
    endcase
endmodule
