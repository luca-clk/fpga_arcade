// debounces an array of switches and buttons independently
// it immediately propagates the sw to the out then it masks out further transactions for
// 2^LEN_LOG clock cycles

module debounce #(
  parameter int WIDTH = 16,
  parameter int LEN_LOG = 16
)(
  input  wire                       clk,
  input  wire                       reset,

  input wire [WIDTH-1:0]            sw_in,
  output logic [WIDTH-1:0]          sw_out
);

logic [WIDTH-1:0]                   sw_in_d;
logic [WIDTH-1:0]                   sw_in_dd;
logic [WIDTH-1:0][LEN_LOG-1:0]      count;

// sync to local clock:
always_ff @(posedge clk) begin
  sw_in_d <= sw_in;
  sw_in_dd <= sw_in_d;
end

// debounce
generate
  for (genvar idx=0; idx<WIDTH; idx++) begin
    always_ff @(posedge clk) begin
      if (reset) begin
        count[idx] <= '0;
      end else if (count[idx] == '0) begin
        sw_out[idx] <= sw_in_dd[idx];
        if (sw_in_dd[idx]^sw_out[idx]) begin
          count[idx] <= '1;
        end
      end else begin
        count[idx] <= count[idx] - 1;
      end
    end
  end
endgenerate

endmodule
