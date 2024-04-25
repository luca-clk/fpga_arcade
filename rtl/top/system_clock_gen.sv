(* keep_hierarchy = "yes" *)
module system_clock_gen (
  input  wire  clk_in_100,
  input  wire  reset,

  output wire  locked,
  output wire  clk_out_148_5,
  output wire  clk_out_49_5
);

wire [1:0] clk_out;

wire clkfb_out, clkfb_in;

MMCME2_ADV #(
  .BANDWIDTH            ("OPTIMIZED"),
  .CLKOUT4_CASCADE      ("FALSE"),
  .COMPENSATION         ("ZHOLD"),
  .STARTUP_WAIT         ("FALSE"),
  .DIVCLK_DIVIDE        (5),
  .CLKFBOUT_MULT_F      (37.125),
  .CLKFBOUT_PHASE       (0.000),
  .CLKFBOUT_USE_FINE_PS ("FALSE"),
  .CLKOUT0_DIVIDE_F     (5.000),
  .CLKOUT0_PHASE        (0.000),
  .CLKOUT0_DUTY_CYCLE   (0.500),
  .CLKOUT0_USE_FINE_PS  ("FALSE"),
  .CLKOUT1_DIVIDE       (15),
  .CLKOUT1_PHASE        (0.000),
  .CLKOUT1_DUTY_CYCLE   (0.500),
  .CLKOUT1_USE_FINE_PS  ("FALSE"),
  .CLKIN1_PERIOD        (10.000)
) mmcm_adv_i (
  .CLKIN1              (clk_in_100),
  .CLKIN2              (1'b0),
  .CLKFBIN             (clkfb_in),

  .CLKFBOUT            (clkfb_out),
  .CLKFBOUTB           (),
  .CLKOUT0             (clk_out[0]),
  .CLKOUT0B            (),
  .CLKOUT1             (clk_out[1]),
  .CLKOUT1B            (),
  .CLKOUT2             (),
  .CLKOUT2B            (),
  .CLKOUT3             (),
  .CLKOUT3B            (),
  .CLKOUT4             (),
  .CLKOUT5             (),
  .CLKOUT6             (),

  .CLKINSEL            (1'b1),
  .DADDR               (7'h0),
  .DCLK                (1'b0),
  .DEN                 (1'b0),
  .DI                  (16'h0),
  .DO                  (),
  .DRDY                (),
  .DWE                 (1'b0),
  .PSCLK               (1'b0),
  .PSEN                (1'b0),
  .PSINCDEC            (1'b0),
  .PSDONE              (),
  .LOCKED              (locked),
  .CLKINSTOPPED        (),
  .CLKFBSTOPPED        (),
  .PWRDWN              (1'b0),
  .RST                 (reset)
);

// Feedback clock (buffered)
BUFG clkf_buf_i (
  .I (clkfb_out),
  .O (clkfb_in)
);

BUFG clk_out_148_5_buf_i (
  .I (clk_out[0]),
  .O (clk_out_148_5)
);

BUFG clk_out_49_5_buf_i (
  .I (clk_out[1]),
  .O (clk_out_49_5)
);

endmodule
