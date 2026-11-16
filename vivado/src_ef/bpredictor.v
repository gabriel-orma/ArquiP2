// bpredictor: tabla de contadores saturados de 2 bits (prediccion de direccion).
// 2 lecturas (IF, para via0 y via1) y 1 escritura (EX, al resolver). MSB=1 -> tomado.
module bpredictor #(parameter IDX = 4)(
  input         clk, reset,
  input  [31:0] rPC0, rPC1,
  output        taken0, taken1,
  input         we,
  input  [31:0] wPC,
  input         wTaken
);
  localparam N = 1 << IDX;
  reg [1:0] ctr [0:N-1];

  wire [IDX-1:0] idx0 = rPC0[IDX+1:2];
  wire [IDX-1:0] idx1 = rPC1[IDX+1:2];
  wire [IDX-1:0] idxw = wPC [IDX+1:2];

  integer i;
  initial for (i = 0; i < N; i = i + 1) ctr[i] = 2'b01;   // debilmente no-tomado

  assign taken0 = ctr[idx0][1];
  assign taken1 = ctr[idx1][1];

  always @(posedge clk) begin
    if (reset)
      for (i = 0; i < N; i = i + 1) ctr[i] <= 2'b01;
    else if (we) begin
      if (wTaken) ctr[idxw] <= (ctr[idxw] == 2'b11) ? 2'b11 : ctr[idxw] + 2'b01;
      else        ctr[idxw] <= (ctr[idxw] == 2'b00) ? 2'b00 : ctr[idxw] - 2'b01;
    end
  end
endmodule
