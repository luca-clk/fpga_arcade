module encoder_sense (
  input  wire                   clk,
  input  wire                   reset,

  input logic                   dir,
  input logic                   k1,
  input logic                   k2,
  output logic                  up,
  output logic                  down
);

logic k1_q, k2_q, k1_qq, k2_qq;

always_ff @(posedge clk) begin
  if (reset) begin
    k1_q    <= 1'b0;
    k2_q    <= 1'b0;
    k1_qq   <= 1'b0;
    k2_qq   <= 1'b0;
    up      <= 1'b0;
    down    <= 1'b0;
  end else begin
    k1_q    <= k1;
    k2_q    <= k2;
    k1_qq   <= k1_q;
    k2_qq   <= k2_q;
    if ((!k1_q && k1_qq && k2_qq) || (k1_q && !k1_qq && !k2_qq)) begin
      up <= dir;
      down <= !dir;
    end else if ((!k1_q && k1_qq && !k2_qq) || (k1_q && !k1_qq && k2_qq)) begin
      up <= !dir;
      down <= dir;
    end else begin
      up <= 1'b0;
      down <= 1'b0;
    end
  end
end

endmodule
