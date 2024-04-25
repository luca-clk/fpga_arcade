// free running randomizer
// every clock cycle random_val is a random number of BITS bits
// each sample is independent from the previous sample.
// It repeats after 4 Billion clocks! (2^32-1)

module randomizer(
  input  wire                       clk,
  input  wire                       reset,
  output logic [31:0]               random_val
);

always_ff @(posedge clk) begin
  if (reset) begin
    random_val <= '0;
  end else begin
    random_val <= fcs_crc32(.state_in(random_val), .data_in('0));
  end
end

localparam bit [31:0] POLYNOMIAL = 32'hEDB88320;

function automatic bit [31:0] fcs_crc32(
  input bit [31:0] state_in,
  input bit [ 7:0] data_in
);
  fcs_crc32 = state_in ^ data_in;
  for (int bit_ind=0; bit_ind<8; bit_ind++)
    fcs_crc32 = (fcs_crc32 >> 1) ^ ((fcs_crc32[0] == 1'b1) ? POLYNOMIAL : 0);
  return fcs_crc32;
endfunction : fcs_crc32

endmodule
