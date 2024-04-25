// Top level arty
// Implements a simple synthesizable testbench to test the streaming_int_divider
// on hardware with hard-coded test vectors.
`ifndef BUILD_TIME
  `define BUILD_TIME 0
`endif

module nexys_arcade_top(
  input  wire         CLK100MHZ,
  input  wire         CPU_RESETN,

  output logic [3:0]  VGA_R,
  output logic [3:0]  VGA_G,
  output logic [3:0]  VGA_B,
  output logic        VGA_HS,
  output logic        VGA_VS,

  // SWITCHES
  input logic [15:0]  SW,

  // BUTTONS
  input logic         BTNC,
  input logic         BTNU,
  input logic         BTNL,
  input logic         BTNR,
  input logic         BTND,

  // PMOD INPUTS (and outputs)
  input logic         SPWH_R_1,       // spin wheel
  input logic         SPWH_R_2,       // spin wheel
  output logic        BTN_R_A_OUT,
  input logic         BTN_R_A_IN,
  output logic        BTN_R_B_OUT,
  input logic         BTN_R_B_IN,

  input logic         SPWH_L_1,       // spin wheel
  input logic         SPWH_L_2,       // spin wheel
  output logic        BTN_L_A_OUT,
  input logic         BTN_L_A_IN,
  output logic        BTN_L_B_OUT,
  input logic         BTN_L_B_IN,

  // display
  output logic        CA,
  output logic        CB,
  output logic        CC,
  output logic        CD,
  output logic        CE,
  output logic        CF,
  output logic        CG,
  output logic        DP,
  output logic [7:0]  AN,

  // LEDs
  output logic [15:0]   LED,

  // AUDIO PWM
  output logic        AUD_PWM,
  output logic        AUD_SD
);

logic [15:0]          sw_control;
logic [15:0]          display_16led;
logic                 btn_r_a, btn_r_b, btn_l_a, btn_l_b;
logic                 up_R, down_R, up_L, down_L;
logic                 blink_btn_r_a;
logic                 blink_btn_r_b;
logic                 blink_btn_l_a;
logic                 blink_btn_l_b;
///////////////////////////////////////////////////////////////////////////////
// Clock and reset
///////////////////////////////////////////////////////////////////////////////
localparam int BUILD_TIME = `BUILD_TIME;

logic clk_49_5;
logic reset_49_5;
logic clk_148_5;
logic reset_148_5;
wire locked;
logic async_reset;
system_clock_gen system_clock_gen_i(
  .clk_in_100     (CLK100MHZ),
  .reset          (!CPU_RESETN),
  .locked         (locked),
  .clk_out_148_5  (clk_148_5),
  .clk_out_49_5   (clk_49_5)
);
 
assign async_reset = (!CPU_RESETN || !locked);

localparam int RESET_LATENCY = 10;
logic [RESET_LATENCY-1:0] delay_clk_148_5;
logic [RESET_LATENCY-1:0] delay_clk_49_5;
// reset asserted asynchronously deasserted synchronously 
always_ff @(posedge clk_148_5 or posedge async_reset) begin
  if (async_reset) begin
    delay_clk_148_5 <= '1;
  end else begin
    delay_clk_148_5 <= {delay_clk_148_5, 1'b0};
  end
end
assign reset_148_5 = delay_clk_148_5[RESET_LATENCY-1];
always_ff @(posedge clk_49_5 or posedge async_reset) begin
  if (async_reset) begin
    delay_clk_49_5 <= '1;
  end else begin
    delay_clk_49_5 <= {delay_clk_49_5, 1'b0};
  end
end
assign reset_49_5 = delay_clk_49_5[RESET_LATENCY-1];

///////////////////////////////////////////////////////////////////////////////
// IO Controls
///////////////////////////////////////////////////////////////////////////////
localparam int NUM_CTRL_VARS = 16;
logic [NUM_CTRL_VARS-1:0][15:0]  control_vars;  // debug control variables, controlled by FPGA buttons

io_ctrl #(
  .NUM_CTRL_VARS (NUM_CTRL_VARS)
) io_ctrl_i (
  .clk        (clk_49_5),
  .reset      (reset_49_5),
  // FPGA pins
  .SW,
  .BTNC,
  .BTNU,
  .BTNL,
  .BTNR,
  .BTND,
  .SPWH_R_1,
  .SPWH_R_2,
  .BTN_R_A_OUT,
  .BTN_R_A_IN,
  .BTN_R_B_OUT,
  .BTN_R_B_IN,
  .SPWH_L_1,
  .SPWH_L_2,
  .BTN_L_A_OUT,
  .BTN_L_A_IN,
  .BTN_L_B_OUT,
  .BTN_L_B_IN,
  .CA,
  .CB,
  .CC,
  .CD,
  .CE,
  .CF,
  .CG,
  .DP,
  .AN,
  .LED,

  // debug control
  .control_vars,
  .sw_control,
  .display_16led,

  // commands:
  .up_R,
  .down_R,
  .up_L,
  .down_L,
  .btn_r_a,
  .btn_r_b,
  .btn_l_a,
  .btn_l_b,
  .blink_btn_r_a,
  .blink_btn_r_b,
  .blink_btn_l_a,
  .blink_btn_l_b
);


// PLACEHOLDER: add some functions to these pins
always_comb begin
  display_16led[0]  = btn_r_a;
  display_16led[1]  = btn_r_b;
  display_16led[2]  = btn_l_a;
  display_16led[3]  = btn_l_b;
end


///////////////////////////////////////////////////////////////////////////////
// Video Driver
///////////////////////////////////////////////////////////////////////////////
logic                           active;
logic [11:0]                    active_h;
logic [11:0]                    active_v;
logic                           frame_start_strobe;
logic                           line_start_strobe;
logic [24:0]                    vid_action_layer;
logic [24:0]                    vid_text_layer;
logic                           frame_start_toggle;
logic                           frame_start_toggle_d;
logic                           frame_start_toggle_dd;
logic                           frame_start_strobe_49_5;

vga_hd_driver vga_hd_driver_i(
  .vid_clk            (clk_148_5),
  .vid_reset          (reset_148_5),
  .color_bar_en       (sw_control[2]),
  .dithering_en       (sw_control[3]),
  .syncs_latency_correction   (control_vars[1]),
  // video sync to control the video timing
  .active,
  .active_h,
  .active_v,
  .frame_start_strobe,
  .line_start_strobe,
  // video inputs
  .vid_text_layer     (vid_text_layer),
  .vid_action_layer   (vid_action_layer),
  .vid_back_layer     (24'h0),  // TODO: add a background
  .vga_rgb            ({VGA_R, VGA_G, VGA_B}), // 12 bit RGB (11:8 Red, 7:4, Green, 3:0 Blue)
  .vga_hs             (VGA_HS),
  .vga_vs             (VGA_VS)
);

// Object rendering
import obj_pkg::*;
logic [obj_pkg::NUM_OBJ-1:0][11:0]  obj_x, obj_x_d;
logic [obj_pkg::NUM_OBJ-1:0][11:0]  obj_y, obj_y_d;
logic [obj_pkg::NUM_OBJ-1:0]        obj_en, obj_en_d;
logic [obj_pkg::NUM_OBJ-1:0][23:0]  obj_color, obj_color_d;
logic [3:0][23:0]                   frame_color, frame_color_d;
logic [3:0][7:0]                    frame_widths, frame_widths_d;

image_rendering image_rendering_i(
  .vid_clk            (clk_148_5),
  .vid_reset          (reset_148_5),
  .active             (active),
  .active_h           (active_h),
  .active_v           (active_v),
  .frame_widths       (frame_widths_d),
  .frame_color        (frame_color_d),
  .obj_x              (obj_x_d),
  .obj_y              (obj_y_d),
  .obj_en             (obj_en_d),
  .obj_color          (obj_color_d),
  .vid_action_layer   (vid_action_layer)
);

// Text rendering
parameter int ROW_START = 6;
parameter int STRING_ROWS = 19;
parameter int COL_START = 2;
parameter int STRING_COLS = 30;
parameter int SCALE_FONT = 2;
logic [STRING_ROWS-1:0]                         string_dir, string_dir_d;
logic [STRING_ROWS-1:0][STRING_COLS-1:0][7:0]   strings, strings_d;
logic [23:0]                                    text_color, text_color_d;

text_rendering  #(
  .ROW_START          (ROW_START),
  .STRING_ROWS        (STRING_ROWS),
  .COL_START          (COL_START),
  .STRING_COLS        (STRING_COLS),
  .SCALE_FONT         (SCALE_FONT)
) text_rendering_i (
  .vid_clk            (clk_148_5),
  .vid_reset          (reset_148_5),
  .active             (active),
  .active_h           (active_h),
  .active_v           (active_v),
  .text_color         (text_color_d),
  .string_dir         (string_dir_d),
  .string_in          (strings_d),
  .vid_text_layer     (vid_text_layer)    // R+G+B+T=transarency (msbit: 1 on, 0 off)
);

// resync frame_start_strobe into the slower clock domain:
always_ff @(posedge clk_148_5) begin
  if (reset_148_5) begin
    frame_start_toggle <= 1'b0;
  end else if (frame_start_strobe) begin
    frame_start_toggle <= !frame_start_toggle;
  end
end
always_ff @(posedge clk_49_5) begin
  if (reset_49_5) begin
    frame_start_toggle_d <= 1'b0;
    frame_start_toggle_dd <= 1'b0;
    frame_start_strobe_49_5 <= 1'b0;
  end else begin
    frame_start_toggle_d <= frame_start_toggle;
    frame_start_toggle_dd <= frame_start_toggle_d;
    frame_start_strobe_49_5 <= frame_start_toggle_dd ^ frame_start_toggle_d;
  end
end

///////////////////////////////////////////////////////////////////////////////
// Audio Driver
///////////////////////////////////////////////////////////////////////////////
logic aud_valid;
parameter int AUD_BITS = 12;
parameter int GAIN_BITS = 16;
parameter int GAIN_FRAC_BITS = 8;
parameter int NUM_SOUNDS = 2;
parameter int PWM_PERIOD_LOG = 11;  // this determines the audio sample rate (clk_freq / 2**PWM_PERIOD_LOG)
parameter int SOUND_IDX_BITS = $clog2(NUM_SOUNDS);

logic [AUD_BITS-1:0]              audio;
logic                             play_sound;
logic [SOUND_IDX_BITS-1:0]        sound_idx;

audio_playout #(
  .AUD_BITS         (AUD_BITS),
  .SOUND_IDX_BITS   (SOUND_IDX_BITS)
) audio_playout_i (
  .clk            (clk_49_5),
  .reset          (reset_49_5),
  .aud_valid      (aud_valid),
  .play_sound     (play_sound),
  .sound_idx      (sound_idx),
  .audio          (audio)
);

// TODO: add audio mixing here: (background sound, action noise etc...)
audio_pwm #(
  .AUD_BITS       (AUD_BITS),
  .GAIN_BITS      (GAIN_BITS),
  .GAIN_FRAC_BITS (GAIN_FRAC_BITS),
  .PWM_PERIOD_LOG (PWM_PERIOD_LOG) // this determines the sample rate: SR = 49.5MHz/2**PWM_PERIOD_LOG
) audio_pwm_i (
  .clk            (clk_49_5),
  .reset          (reset_49_5),
  .audio_gain     (control_vars[3][GAIN_BITS-1:0]),
  .audio_valid    (aud_valid),
  .audio          (audio),
  .pwm_out        (AUD_PWM)
);

assign AUD_SD = sw_control[1];

///////////////////////////////////////////////////////////////////////////////
// Game
///////////////////////////////////////////////////////////////////////////////
game #(
  .CLK_RATE           (49500000),
  .NUM_OBJ            (obj_pkg::NUM_OBJ),
  .STRING_ROWS        (STRING_ROWS),
  .STRING_COLS        (STRING_COLS),
  .SOUND_IDX_BITS     (SOUND_IDX_BITS)
) game_i (
  .clk                (clk_49_5),
  .reset              (reset_49_5),
  .frame_start_strobe (frame_start_strobe_49_5),
  // debug controls
  // .enable             (sw_control[4]), // start stop the motion
  // .velocity           (4*control_vars[0]),
  .paddle_step        (control_vars[2]),
  // user inputs - buttons
  .btn_r_a            (btn_r_a),
  .btn_r_b            (btn_r_b),
  .btn_l_a            (btn_l_a),
  .btn_l_b            (btn_l_b),
  // button blink
  .blink_btn_r_a      (blink_btn_r_a),
  .blink_btn_r_b      (blink_btn_r_b),
  .blink_btn_l_a      (blink_btn_l_a),
  .blink_btn_l_b      (blink_btn_l_b),
  // user input - spin wheels
  .up_R               (up_R),
  .down_R             (down_R),
  .up_L               (up_L),
  .down_L             (down_L),
  // video rendering outputs - all these are generated in the slow clock domain
  .obj_x              (obj_x),
  .obj_y              (obj_y),
  .obj_en             (obj_en),
  .obj_color          (obj_color),
  .frame_color        (frame_color),
  .frame_widths       (frame_widths),
  .string_dir         (string_dir),
  .strings            (strings),
  .text_color         (text_color),
  // sound interface outputs
  .play_sound         (play_sound),
  .sound_idx          (sound_idx)
);

// all the video control signals here are generated in the slow clock domain, they need to cross into the video clock domain:
xpm_cdc_array_single #(.WIDTH(obj_pkg::NUM_OBJ*12)) cdc_obj_x (
  .src_clk(clk_49_5),
  .src_in(obj_x),
  .dest_clk(clk_148_5),
  .dest_out(obj_x_d)
);
xpm_cdc_array_single #(.WIDTH(obj_pkg::NUM_OBJ*12)) cdc_obj_y (
  .src_clk(clk_49_5),
  .src_in(obj_y),
  .dest_clk(clk_148_5),
  .dest_out(obj_y_d)
);
xpm_cdc_array_single #(.WIDTH(obj_pkg::NUM_OBJ)) cdc_obj_en (
  .src_clk(clk_49_5),
  .src_in(obj_en),
  .dest_clk(clk_148_5),
  .dest_out(obj_en_d)
);
xpm_cdc_array_single #(.WIDTH(obj_pkg::NUM_OBJ*24)) cdc_obj_color (
  .src_clk(clk_49_5),
  .src_in(obj_color),
  .dest_clk(clk_148_5),
  .dest_out(obj_color_d)
);
xpm_cdc_array_single #(.WIDTH(4*24)) cdc_frame_color (
  .src_clk(clk_49_5),
  .src_in(frame_color),
  .dest_clk(clk_148_5),
  .dest_out(frame_color_d)
);
xpm_cdc_array_single #(.WIDTH(4*8)) cdc_frame_widths (
  .src_clk(clk_49_5),
  .src_in(frame_widths),
  .dest_clk(clk_148_5),
  .dest_out(frame_widths_d)
);
xpm_cdc_array_single #(.WIDTH(STRING_ROWS)) cdc_string_dir (
  .src_clk(clk_49_5),
  .src_in(string_dir),
  .dest_clk(clk_148_5),
  .dest_out(string_dir_d)
);
always_ff @(posedge clk_148_5) begin
  if (frame_start_strobe) begin
    strings_d <= strings;
  end
end
xpm_cdc_array_single #(.WIDTH(24)) cdc_text_color (
  .src_clk(clk_49_5),
  .src_in(text_color),
  .dest_clk(clk_148_5),
  .dest_out(text_color_d)
);

// `define ILA_DEBUG 1

`ifndef __SIMULATION__
`ifdef ILA_DEBUG
logic [127:0] probe0;

ila_128_2048 ila (
   .clk(clk_49_5), // input wire clk
   .probe0(probe0) // input wire [63:0]  probe0
);

assign probe0 = {freq_int, audio_tone, aud_valid, ramp_up};
`endif
`endif

endmodule
