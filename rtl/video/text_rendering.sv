import font_pkg::*;

module text_rendering #(
  parameter int ROW_START = 4,          // row start
  parameter int STRING_ROWS = 19,       // number of string rows
  parameter int COL_START = 2,          // col start
  parameter int STRING_COLS = 30,       // how many chars pre row
  parameter int SCALE_FONT = 2,         // scaling up the font
  parameter int SCALE_CHAR = SCALE_FONT + $clog2(font_pkg::FONT_SIZE_X)
)(
  input wire                                            vid_clk,
  input wire                                            vid_reset,
  // video
  input logic                                           active,
  input logic [11:0]                                    active_h, // 2 clock latency between this and the vid_action_layer output
  input logic [11:0]                                    active_v,
  // text color
  input logic [23:0]                                    text_color,
  // string content arrays
  input logic [STRING_ROWS-1:0]                         string_dir, // direction of the font (0/180)
  input logic [STRING_ROWS-1:0][STRING_COLS-1:0][7:0]   string_in,  // the string itself
  // output video
  output logic [24:0]                                   vid_text_layer    // R+G+B+T=transarency (msbit: 1 on, 0 off)
);

// position of the char
logic [$clog2(STRING_COLS)-1:0]                         char_col;
logic [$clog2(STRING_ROWS)-1:0]                         char_row;
logic                                                   en_text, en_text_d;
logic [7:0]                                             char_sel;

//relative char position (pixel in pos)
logic [$clog2(font_pkg::FONT_SIZE_X)-1:0]               char_x, char_x_d;
logic [$clog2(font_pkg::FONT_SIZE_X)-1:0]               char_y, char_y_d;

// global text positioning (and local, within char box)
always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    en_text <= 1'b0;
    char_col <= '0;
    char_row <= '0;
    char_x <= '0;
    char_y <= '0;
  end else begin
    en_text <= (active && (active_h>>(SCALE_CHAR+1)) >= ROW_START && (active_h>>(SCALE_CHAR+1)) < ROW_START + STRING_ROWS &&
        (active_h[SCALE_CHAR] == 1'b0) &&
        (active_v>>SCALE_CHAR) >= COL_START && (active_v>>SCALE_CHAR) < COL_START + STRING_COLS);
    char_row <= (active_h>>SCALE_CHAR+1) - ROW_START;
    char_col <= (active_v>>SCALE_CHAR) - COL_START;
    char_x <= active_v[SCALE_CHAR-1:SCALE_FONT];
    char_y <= active_h[SCALE_CHAR-1:SCALE_FONT];
  end
end

// video generator:
always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    char_sel <= '0;
    char_x_d <= '0;
    char_y_d <= '0;
    en_text_d <= 1'b0;
    vid_text_layer <= 25'h0000000;
  end else begin
    vid_text_layer[23:0] <= text_color;
    // rotate the text
    if (string_dir[char_row]) begin
      char_sel <= string_in[char_row][char_col];
      char_x_d <= font_pkg::FONT_SIZE_X - char_x - 1;
      char_y_d <= char_y;
    end else begin
      char_sel <= string_in[char_row][STRING_COLS-char_col-1];
      char_x_d <= char_x;
      char_y_d <= font_pkg::FONT_SIZE_Y - char_y - 1;
    end
    en_text_d <= en_text;
    vid_text_layer[24] <= en_text_d && font_pkg::font[char_sel][char_y_d][char_x_d];
  end
end

endmodule
