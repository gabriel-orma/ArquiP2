// btb: Branch Target Buffer directo. Guarda el destino de branches/jumps tomados.
// 2 puertos de lectura (IF: via0 y via1) y 1 de escritura (EX: al resolver tomado).
module btb #(parameter IDX = 4)(
  input         clk, reset,
  input  [31:0] rPC0, rPC1,
  output        hit0, hit1,
  output [31:0] target0, target1,
  input         we,
  input  [31:0] wPC,
  input  [31:0] wTarget
);
  localparam N    = 1 << IDX;
  localparam TAGW = 30 - IDX;            // PC[31:2] menos el indice

  reg            valid [0:N-1];
  reg [TAGW-1:0] tag   [0:N-1];
  reg [31:0]     tgt   [0:N-1];

  wire [IDX-1:0]  idx0 = rPC0[IDX+1:2];
  wire [IDX-1:0]  idx1 = rPC1[IDX+1:2];
  wire [IDX-1:0]  idxw = wPC [IDX+1:2];
  wire [TAGW-1:0] tg0  = rPC0[31:IDX+2];
  wire [TAGW-1:0] tg1  = rPC1[31:IDX+2];

  integer i;
  initial for (i = 0; i < N; i = i + 1) begin valid[i] = 1'b0; tag[i] = 0; tgt[i] = 0; end

  assign hit0    = valid[idx0] & (tag[idx0] == tg0);
  assign hit1    = valid[idx1] & (tag[idx1] == tg1);
  assign target0 = tgt[idx0];
  assign target1 = tgt[idx1];

  always @(posedge clk) begin
    if (reset)
      for (i = 0; i < N; i = i + 1) valid[i] <= 1'b0;
    else if (we) begin
      valid[idxw] <= 1'b1;
      tag  [idxw] <= wPC[31:IDX+2];
      tgt  [idxw] <= wTarget;
    end
  end
endmodule
