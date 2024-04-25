module bouncy_ball (
  input  wire                               clk,
  input  wire                               reset,

  input logic                               frame_start_strobe, // 1 pulse a frame to start reading from RAM

  input logic                               enable,           // when set forces color bar out
  input logic [15:0]                        velocity,         // ball velocity
  input logic [7:0]                         rack_step,         // ball velocity

  input logic                               up_R,
  input logic                               down_R,
  input logic                               up_L,
  input logic                               down_L,

  // image rendering
  output logic [3:0][11:0]                  obj_x,
  output logic [3:0][11:0]                  obj_y,
  output logic [3:0]                        obj_en,
  output logic [3:0][23:0]                  obj_color,

  // sound rendering:
  output logic                              ball_bounce_sound,
  output logic [7:0]                        alpha_out
);

import sin_cos_lut_pkg::*;
import vga_hd_pkg::*;

logic [15:0]                                pos_L;
logic [15:0]                                pos_R;


localparam int FRAC_BITS = 4;
localparam int NUM_BALLS = 2;

localparam int MIN_x = 8*(2**FRAC_BITS);
localparam int MIN_y = 16*(2**FRAC_BITS);

localparam int MAX_x = (vga_hd_pkg::ActivePels-24)*(2**FRAC_BITS);
localparam int MAX_y = (vga_hd_pkg::ActiveLines-32)*(2**FRAC_BITS);
localparam int INIT_POS_x = (vga_hd_pkg::ActivePels/2)*(2**FRAC_BITS);
localparam int INIT_POS_y = (vga_hd_pkg::ActiveLines/2)*(2**FRAC_BITS);
localparam int MAX_alpha = 150;
localparam int MIN_alpha = 10;

// the ball speed vector is represented as a direction dir quadrant 00, 01, 11, 10, and an angle 0-255
localparam logic [NUM_BALLS-1:0][1:0] INIT_DIR = {
  2'b00, 2'b01, 2'b10, 2'b11};
localparam logic [NUM_BALLS-1:0][7:0] INIT_ANGLE = {
  8'h80, 8'h70, 8'h60, 8'h50};

// Randomizer
localparam int RANDOM_BITS = 5;
logic [RANDOM_BITS-1:0]             prbs;
randomizer #(.BITS(RANDOM_BITS)) randomizer_i(
  .clk,
  .reset,
  .random_val (prbs)
);

// the position is fractional:
typedef logic signed [16:0] pos_t; // signed position
pos_t [NUM_BALLS-1:0]                     ball_pos_x, ball_pos_y;
pos_t [NUM_BALLS-1:0]                     next_ball_pos_x, next_ball_pos_y;
logic [NUM_BALLS-1:0][1:0]                dir, next_dir; // SE=00, SW=01, NW=11, NE=10
logic [NUM_BALLS-1:0][7:0]                alpha; // angle
logic [NUM_BALLS-1:0][8:0]                next_alpha; // angle
logic [NUM_BALLS-1:0]                     wall_bounce;
logic [NUM_BALLS-1:0][7:0]                cos_alpha, sin_alpha;
logic [NUM_BALLS-1:0][23:0]               delta_x_p, delta_y_p;
logic [NUM_BALLS-1:0][15:0]               delta_x, delta_y; // displacement x/y

// pipelining LUT reaqd port, mult and finally shift
always_ff @(posedge clk) begin
  for (int idx=0; idx<NUM_BALLS; idx++) begin
    sin_alpha[idx] <= sin_cos_lut_pkg::SIN_COS_LUT[alpha[idx]][1];
    cos_alpha[idx] <= sin_cos_lut_pkg::SIN_COS_LUT[alpha[idx]][0];
    delta_x_p[idx] <= (cos_alpha[idx] * velocity);
    delta_y_p[idx] <= (sin_alpha[idx] * velocity);
    delta_x[idx] <= delta_x_p[idx] >> 8;
    delta_y[idx] <= delta_y_p[idx] >> 8;
  end
end

always_comb begin
  for (int idx=0; idx<NUM_BALLS; idx++) begin
    next_dir[idx] = dir[idx];
    wall_bounce[idx] = 1'b0;
    // x
    if (!dir[idx][0]) begin
      next_ball_pos_x[idx] = ball_pos_x[idx] + $signed({1'b0, delta_x[idx]});
      if (next_ball_pos_x[idx] > MAX_x) begin
        next_ball_pos_x[idx] = MAX_x - next_ball_pos_x[idx] + MAX_x;
        next_dir[idx][0] = 1'b1;
        wall_bounce[idx] = 1'b1;
      end
    end else begin
      next_ball_pos_x[idx] = ball_pos_x[idx] - $signed({1'b0, delta_x[idx]});
      if (next_ball_pos_x[idx] < MIN_x) begin
        next_ball_pos_x[idx] = MIN_x - next_ball_pos_x[idx] + MIN_x;
        next_dir[idx][0] = 1'b0;
        wall_bounce[idx] = 1'b1;
      end
    end
    // y
    if (!dir[idx][1]) begin
      next_ball_pos_y[idx] = ball_pos_y[idx] + $signed({1'b0, delta_y[idx]});
      if (next_ball_pos_y[idx] > MAX_y) begin
        next_ball_pos_y[idx] = MAX_y - next_ball_pos_y[idx] + MAX_y;
        next_dir[idx][1] = 1'b1;
        wall_bounce[idx] = 1'b1;
      end
    end else begin
      next_ball_pos_y[idx] = ball_pos_y[idx] - $signed({1'b0, delta_y[idx]});
      if (next_ball_pos_y[idx] < MIN_y) begin
        next_ball_pos_y[idx] = MIN_y - next_ball_pos_y[idx] + MIN_y;
        next_dir[idx][1] = 1'b0;
        wall_bounce[idx] = 1'b1;
      end
    end
    // next alpha is just a randomized next_alpha
    next_alpha[idx] = alpha[idx];
    if (wall_bounce[idx]) begin
      if (prbs[4]) begin
        if (next_alpha[idx] + prbs[3:0] > MAX_alpha) begin
          next_alpha[idx] = MAX_alpha;
        end else begin
          next_alpha[idx] = next_alpha[idx] + prbs[3:0];
        end
      end else begin
        if (next_alpha[idx] < MIN_alpha + prbs[3:0]) begin
          next_alpha[idx] = MIN_alpha;
        end else begin
          next_alpha[idx] = next_alpha[idx] - prbs[3:0];
        end
      end
    end
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    for (int idx=0; idx<NUM_BALLS; idx++) begin
      ball_pos_x[idx]   <= INIT_POS_x;
      ball_pos_y[idx]   <= INIT_POS_y;
      dir[idx]          <= INIT_DIR[idx];
      alpha[idx]        <= INIT_ANGLE[idx];
    end
  end else if (enable && frame_start_strobe) begin
    for (int idx=0; idx<NUM_BALLS; idx++) begin
      ball_pos_x[idx]   <= next_ball_pos_x[idx];
      ball_pos_y[idx]   <= next_ball_pos_y[idx];
      dir[idx]          <= next_dir[idx];
      alpha[idx]        <= next_alpha[idx];
    end
  end
end

always_ff @(posedge clk) begin
  for (int idx=0; idx<NUM_BALLS; idx++) begin
    obj_x[idx] = (ball_pos_x[idx]>>>FRAC_BITS);
    obj_y[idx] = (ball_pos_y[idx]>>>FRAC_BITS);
  end
end

always_ff @(posedge clk) begin
  if (reset) begin
    ball_bounce_sound <= 1'b0;
  end else if (enable && frame_start_strobe) begin
    ball_bounce_sound <= |wall_bounce[NUM_BALLS-1:0];
  end
end

always_comb alpha_out = alpha[0];

always_comb begin
  obj_en = 4'b1111;
  obj_color = {
    24'h0000FF,
    24'hFF0000,
    24'h0000FF,
    24'hFF0000
  };
end

// racket positions
localparam int MIN_rack = 0;
localparam int MAX_rack = (vga_hd_pkg::ActiveLines-64)*(2**FRAC_BITS);
localparam int INIT_rack = (vga_hd_pkg::ActiveLines/2)*(2**FRAC_BITS);
always_ff @(posedge clk) begin
  if (reset) begin
    pos_L <= INIT_rack;
    pos_R <= INIT_rack;
  end else begin
    if (down_R) begin
      if (pos_R > MIN_rack + rack_step) begin
        pos_R <= pos_R - rack_step;
      end else begin
        pos_R <= MIN_rack;
      end
    end else if (up_R) begin
      if (pos_R < MAX_rack - rack_step) begin
        pos_R <= pos_R + rack_step;
      end else begin
        pos_R <= MAX_rack;
      end
    end
    if (down_L) begin
      if (pos_L > MIN_rack + rack_step) begin
        pos_L <= pos_L - rack_step;
      end else begin
        pos_L <= MIN_rack;
      end
    end else if (up_L) begin
      if (pos_L < MAX_rack - rack_step) begin
        pos_L <= pos_L + rack_step;
      end else begin
        pos_L <= MAX_rack;
      end
    end
  end
end

always_ff @(posedge clk) begin
  obj_x[2] = MIN_x>>FRAC_BITS;
  obj_x[3] = MAX_x>>FRAC_BITS;
  obj_y[2] = pos_L>>FRAC_BITS;
  obj_y[3] = pos_R>>FRAC_BITS;
end

endmodule
