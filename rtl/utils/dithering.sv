// dithering is the operation of reducing the quantization effects (banding) by truncating and adding a pseudo-random value.

module dithering #(
  parameter int BITS_IN = 8,
  parameter int BITS_OUT = 4
)(
  input  wire                       clk,
  input  wire                       reset,

  input logic                       ce,
  input logic                       en,
  input logic [BITS_IN-1:0]         data_in,
  output logic [BITS_OUT-1:0]       data_out
);

localparam int DISCARD_BITS = BITS_IN - BITS_OUT;

logic [DISCARD_BITS-1:0]            prbs;
logic [BITS_OUT-1:0]                data_out_p;

randomizer randomizer_i(
  .clk,
  .reset,
  .random_val (prbs)
);

always_comb begin
  data_out_p = data_in[BITS_IN-1:DISCARD_BITS];
  if (en && (data_out_p < (2**BITS_OUT)-1)) begin
    data_out_p = data_out_p + (prbs < data_in[DISCARD_BITS-1:0]);
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    data_out <= '0;
  end else if (ce) begin
    data_out <= data_out_p;
  end
end

endmodule
