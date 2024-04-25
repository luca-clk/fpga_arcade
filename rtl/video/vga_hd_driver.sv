// VGA HD 1920x1080x60p image rendering module that drives the RGB 12 bit VGA interface
// This module outputs a few control signals to all the video components generators (active_*, frame/line start strobes)
// and it receives 3 video layers: text (top), action (middle), background (bottom), the top and middle layer have 1 bit of
// transparency (if 0, transparent)
// Special controls:
// 1. enable color bar,
// 2. dithering en/disable
// 3. syncs adjustments to fine tune horizontal adjustments

module vga_hd_driver (
  input  wire                           vid_clk,  // 148.5MHz
  input  wire                           vid_reset,

  input logic                           color_bar_en,     // when set forces color bar out
  input logic                           dithering_en,     // when set enables dithering
  input logic [3:0]                     syncs_latency_correction,

  // outputs to video sources - expects to get inputs vid_* 1 clk after active_*
  output logic                          active,
  output logic [11:0]                   active_h,
  output logic [11:0]                   active_v,
  output logic                          frame_start_strobe, // 1 pulse a frame to start reading from RAM
  output logic                          line_start_strobe, // only on active line - 1 pulse for each active line

  // inputs from input 3 layers sources
  input logic [24:0]                    vid_text_layer,  // R+G+B+T=transarency (msbit: 1 on, 0 off)
  input logic [24:0]                    vid_action_layer,  // R+G+B+T=transarency (msbit: 1 on, 0 off)
  input logic [23:0]                    vid_back_layer,  // R+G+B

  // output to drive monitor
  output logic [11:0]                   vga_rgb, // 12 bit RGB (11:8 Red, 7:4, Green, 3:0 Blue)
  output logic                          vga_hs,
  output logic                          vga_vs
);


import vga_hd_pkg::*;

localparam logic [23:0] Black   = 24'h000000;

logic [11:0]        h_count, v_count;
logic [15:0]        vga_vs_sr;
logic [15:0]        vga_hs_sr;
logic               active_d;

always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    h_count <= '0;
    v_count <= '0;
    active <= 1'b0;
    active_d <= 1'b0;
    active_h <= '0;
    active_v <= '0;
    vga_hs_sr <= '0;
    vga_vs_sr <= '0;
    frame_start_strobe <= 1'b0;
    line_start_strobe <= 1'b0;
  end else begin
    if (h_count < vga_hd_pkg::TotalPixel-1) begin
      h_count <= h_count + 1;
    end else begin
      h_count <= '0;
      if (v_count < vga_hd_pkg::TotalLines-1) begin
        v_count <= v_count + 1;
      end else begin
        v_count <= '0;
      end
    end
    // decode the lines + SR pipeline to adjust and compensate for horizontal centering
    vga_vs_sr <= {vga_vs_sr, (v_count >= vga_hd_pkg::VertSyncLine)};
    vga_hs_sr <= {vga_hs_sr, (h_count >= vga_hd_pkg::HorzSyncPel)};
    // active pixel geometry
    active <= (
        h_count >=  vga_hd_pkg::HorzBackPorch &&
        h_count <   vga_hd_pkg::HorzBackPorch+vga_hd_pkg::ActivePels &&
        v_count >=  vga_hd_pkg::VertBackPorch &&
        v_count <   vga_hd_pkg::VertBackPorch+vga_hd_pkg::ActiveLines);
    active_h <= h_count - vga_hd_pkg::HorzBackPorch;
    active_v <= v_count - vga_hd_pkg::VertBackPorch;
    frame_start_strobe <= (v_count==0 && h_count==0);
    line_start_strobe <= (
        v_count >=  vga_hd_pkg::VertBackPorch &&
        v_count <   vga_hd_pkg::VertBackPorch+vga_hd_pkg::ActiveLines &&
        h_count==0);
    active_d <= active;
  end
end

// *************************************************************************
// *************************** video layer mixer ***************************
// *************************************************************************
logic [23:0]              colorbar;
logic [23:0]              vga_rgb_p;
logic [11:0]              vga_rgb_12b;

always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    vga_rgb_p <= Black;
  end else if (active_d && color_bar_en) begin
    vga_rgb_p <= colorbar;
  end else if (active_d) begin
    // layering here:
    if (vid_text_layer[24]) begin
      // top layer: text
      vga_rgb_p <= vid_text_layer[23:0];
    end else if (vid_action_layer[24]) begin
      // 2nd layer: action
      vga_rgb_p <= vid_action_layer[23:0];
    end else begin
      // background
      vga_rgb_p <= vid_back_layer;
    end
  end else begin
    vga_rgb_p <= Black;
  end
end

generate
  for (genvar color_idx = 0; color_idx < 3; color_idx++) begin: gen_loop_3colors
    dithering #(.BITS_IN(8), .BITS_OUT(4)) dithering_i (
      .clk        (vid_clk),
      .reset      (vid_reset),
      .ce         (1'b1),
      .en         (dithering_en),
      .data_in    (vga_rgb_p[8*color_idx +: 8]), // 8 bits color
      .data_out   (vga_rgb_12b[4*color_idx +: 4]) // 4 bit color
    );
  end
endgenerate

// output flops:
always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    vga_rgb <= Black;
    vga_hs <= 1'b0;
    vga_vs <= 1'b0;
  end else begin
    vga_rgb <= vga_rgb_12b;
    vga_hs <= vga_hs_sr[syncs_latency_correction];
    vga_vs <= vga_vs_sr[syncs_latency_correction];
  end
end

// *************************************************************************
// ****************************** COLOR BAR ********************************
// *************************************************************************
// mapped as 12 bits RGB
localparam logic [23:0] White   = 24'hFFFFFF;
localparam logic [23:0] Yellow  = 24'hFFFF00;
localparam logic [23:0] Cyan    = 24'h00FFFF;
localparam logic [23:0] Green   = 24'h00FF00;
localparam logic [23:0] Magenta = 24'hFF00FF;
localparam logic [23:0] Red     = 24'hFF0000;
localparam logic [23:0] Blue    = 24'h0000FF;
localparam logic [23:0] Gray75  = 24'h404040;
localparam logic [23:0] Gray50  = 24'h808080;
localparam logic [23:0] Gray25  = 24'hC0C0C0;
//localparam logic [23:0] Black   = 24'h000000;
// Colorbar regions:
localparam int VertSplit = 700;
localparam int HorzC0 = 274;
localparam int HorzC1 = 548;
localparam int HorzC2 = 822;
localparam int HorzC3 = 1096;
localparam int HorzC4 = 1370;
localparam int HorzC5 = 1644;
localparam int HorzG0 = 384;
localparam int HorzG1 = 768;
localparam int HorzG2 = 1152;
localparam int HorzG3 = 1536;

// color bar gen:
always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    colorbar <= '0;
  end else if (active) begin
    if (active_v < VertSplit) begin
      if (active_h < HorzC0) begin
        colorbar <= White;
      end else if (active_h < HorzC1) begin
        colorbar <= Yellow;
      end else if (active_h < HorzC2) begin
        colorbar <= Cyan;
      end else if (active_h < HorzC3) begin
        colorbar <= Green;
      end else if (active_h < HorzC4) begin
        colorbar <= Magenta;
      end else if (active_h < HorzC5) begin
        colorbar <= Red;
      end else begin
        colorbar <= Blue;
      end
    end else begin
      if (active_h < HorzG0) begin
        colorbar <= Black;
      end else if (active_h < HorzG1) begin
        colorbar <= Gray75;
      end else if (active_h < HorzG2) begin
        colorbar <= Gray50;
      end else if (active_h < HorzG3) begin
        colorbar <= Gray25;
      end else begin
        colorbar <= White;
      end
    end
  end
end

endmodule
