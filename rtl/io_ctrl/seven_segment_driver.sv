module seven_segment_driver (
  input  wire                   clk,
  input  wire                   reset,

  input logic [7:0][3:0]        nibbles_in,
  input logic [7:0]             points_in,

  // display
  output logic                  CA,
  output logic                  CB,
  output logic                  CC,
  output logic                  CD,
  output logic                  CE,
  output logic                  CF,
  output logic                  CG,
  output logic                  DP,
  output logic [7:0]            AN
);

// count 3 msb rotate char 0..7, 8 msb just wait
logic [10:0]                    count;

// samples input and rotates
always_ff @(posedge clk) begin
  if (reset) begin
    count <= '0;
    {CA, CB, CC, CD, CE, CF, CG} <= 7'h7F;
    AN[7:0] <= 8'hFF;
  end else begin
    count <= count + 1;
    if (count[7:0] == '0) begin
      case(count[10:8])
        3'd0: AN[7:0] <= 8'hFE;
        3'd1: AN[7:0] <= 8'hFD;
        3'd2: AN[7:0] <= 8'hFB;
        3'd3: AN[7:0] <= 8'hF7;
        3'd4: AN[7:0] <= 8'hEF;
        3'd5: AN[7:0] <= 8'hDF;
        3'd6: AN[7:0] <= 8'hBF;
        3'd7: AN[7:0] <= 8'h7F;
        default: AN[7:0] <= 8'hFE;
      endcase
      {CA, CB, CC, CD, CE, CF, CG} <= conv_nibble_into_7seg(nibbles_in[count[10:8]]);
      DP <= !points_in[count[10:8]];
    end
  end
end

function logic [6:0] conv_nibble_into_7seg(input logic [3:0] nibble);
  case (nibble)
    // order........abcdefg.... these are active low segments
    4'h0: return 7'b0000001;
    4'h1: return 7'b1001111;
    4'h2: return 7'b0010010;
    4'h3: return 7'b0000110;
    4'h4: return 7'b1001100;
    4'h5: return 7'b0100100;
    4'h6: return 7'b0100000;
    4'h7: return 7'b0001111;
    4'h8: return 7'b0000000;
    4'h9: return 7'b0001100;
    4'hA: return 7'b0001000;
    4'hB: return 7'b1100000;
    4'hC: return 7'b0110001;
    4'hD: return 7'b1000010;
    4'hE: return 7'b0110000;
    4'hF: return 7'b0111000;
    default: return 7'b0000001;
  endcase
endfunction

endmodule
