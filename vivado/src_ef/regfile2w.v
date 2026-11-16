// regfile2w: Register File de 4 lecturas y 2 escrituras por ciclo (E2).
// Escribe en flanco de bajada (write-before-read). Si wa1==wa2, gana la via 1.
module regfile2w(
  input         clk,
  input         we1, we2,
  input  [4:0]  a1, a2, a3, a4,
  input  [4:0]  wa1, wa2,
  input  [31:0] wd1, wd2,
  output [31:0] rd1, rd2, rd3, rd4
);
  integer i;
  reg [31:0] rf[31:0];

  initial for (i = 0; i < 32; i = i + 1) rf[i] = 32'b0;

  always @(negedge clk) begin
    if (we1 && (wa1 != 5'd0)) rf[wa1] <= wd1;   // via 0
    if (we2 && (wa2 != 5'd0)) rf[wa2] <= wd2;   // via 1 (gana si wa1==wa2)
  end

  assign rd1 = (a1 != 5'd0) ? rf[a1] : 32'b0;
  assign rd2 = (a2 != 5'd0) ? rf[a2] : 32'b0;
  assign rd3 = (a3 != 5'd0) ? rf[a3] : 32'b0;
  assign rd4 = (a4 != 5'd0) ? rf[a4] : 32'b0;
endmodule
