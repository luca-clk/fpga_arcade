// TODO:
// 2. revisit paddle size and hit angle adjustment
// 3. game over sound
// 4. add point display
module game #(
  parameter int CLK_RATE        = 49500000,
  parameter int NUM_OBJ         = 4,
  parameter int STRING_ROWS     = 19,
  parameter int STRING_COLS     = 30,
  parameter int SOUND_IDX_BITS  = 2
  )(
  input  wire                               clk,
  input  wire                               reset,

  input logic                               frame_start_strobe, // 1 pulse a frame to update game status

  input logic [7:0]                         paddle_step,      // paddle velocity

  // button inputs:
  input logic                               btn_r_a,
  input logic                               btn_r_b,
  input logic                               btn_l_a,
  input logic                               btn_l_b,
  output logic                              blink_btn_r_a,
  output logic                              blink_btn_r_b,
  output logic                              blink_btn_l_a,
  output logic                              blink_btn_l_b,

  // Wheel control inputs
  input logic                               up_R,
  input logic                               down_R,
  input logic                               up_L,
  input logic                               down_L,

  // image rendering
  output logic [3:0][11:0]                  obj_x,
  output logic [3:0][11:0]                  obj_y,
  output logic [3:0]                        obj_en,
  output logic [3:0][23:0]                  obj_color,
  output logic [3:0][23:0]                  frame_color,
  output logic [3:0][7:0]                   frame_widths,

  // text rendering
  output logic [STRING_ROWS-1:0]            string_dir,
  output logic [STRING_ROWS-1:0][STRING_COLS-1:0][7:0] strings,
  output logic [23:0]                       text_color,

  // sound rendering:
  output logic                              play_sound,
  output logic [SOUND_IDX_BITS-1:0]         sound_idx
);

localparam int ANGLE_BITS = 10; // input to the LUT is just 1/4 of a unit circle - remove 2 bits for the LUT input
localparam int SIN_COS_BITS = 8;
localparam int VELOCITY_BITS = 16;
localparam int FRAC_BITS = 4;
localparam int COORDINATE_BITS = 12; // 0 - 2047
localparam int POS_BITS = COORDINATE_BITS + FRAC_BITS + 1; // +1 because of the signed
localparam int START_VELOCITY = 'd250;
localparam int STEP_VELOCITY = 'd5; // increase of ball velocity at every second

import sin_cos_lut_pkg::*;
import vga_hd_pkg::*;

// Adjust the bounce alpha
localparam int RND_ALPHA = 3;
localparam int HIT_ADJ = 60; // amount of rotation caused by the paddle hit

logic ball_bounce_sound;
logic game_failed;
logic ball_bounce_sound_p;
logic game_failed_p;
logic init_game;
logic motion_enable;
logic obj_paddle_R;
logic obj_paddle_L;
logic obj_ball_0;
logic obj_ball_1;

logic     bounce_north;
logic     bounce_south;
logic     bounce_east;
logic     bounce_west;


///////////////////////////////////////////////////////////////////////////////
// Randomizer
///////////////////////////////////////////////////////////////////////////////
localparam int RANDOM_BITS = 5;
logic [RANDOM_BITS-1:0]             prbs;
randomizer randomizer_i(
  .clk,
  .reset,
  .random_val (prbs)
);

///////////////////////////////////////////////////////////////////////////////
// Ball position
///////////////////////////////////////////////////////////////////////////////
localparam int BALL_SIZE = 16;
localparam int MIN_x = BALL_SIZE*(2**FRAC_BITS);
localparam int MAX_x = (vga_hd_pkg::ActivePels-BALL_SIZE)*(2**FRAC_BITS); // x is the long dir
localparam int MIN_y = (BALL_SIZE+8)*(2**FRAC_BITS);
localparam int MAX_y = (vga_hd_pkg::ActiveLines-(BALL_SIZE+8))*(2**FRAC_BITS);
localparam int INIT_POS_x = (vga_hd_pkg::ActivePels/2)*(2**FRAC_BITS);
localparam int INIT_POS_y = (vga_hd_pkg::ActiveLines/2)*(2**FRAC_BITS);
 // Limit alpha angle to avoid side by side wall bounces
localparam real MAX_ANGLE = 0.5;
localparam int MAX_ALPHA_00 = (MAX_ANGLE)*(2**(ANGLE_BITS-2)); // north east
localparam int MAX_ALPHA_01 = (1.0 + MAX_ANGLE)*(2**(ANGLE_BITS-2)); // north west
localparam int MAX_ALPHA_10 = (2.0 + MAX_ANGLE)*(2**(ANGLE_BITS-2)); // south west
localparam int MAX_ALPHA_11 = (3.0 + MAX_ANGLE)*(2**(ANGLE_BITS-2)); // south east

localparam logic [ANGLE_BITS-1:0] INIT_ANGLE = 'd20; // 45 degrees

localparam int PADDLE_SIZE = 64;
localparam int PADDLE_SIZE_F = PADDLE_SIZE*(2**FRAC_BITS);

logic signed [POS_BITS-1:0] pos_paddle_L;
logic signed [POS_BITS-1:0] pos_paddle_R;
localparam int MIN_paddle = (PADDLE_SIZE/2)*(2**FRAC_BITS);
localparam int MAX_paddle = (vga_hd_pkg::ActiveLines-(PADDLE_SIZE/2))*(2**FRAC_BITS);
localparam int INIT_paddle = (vga_hd_pkg::ActiveLines/2)*(2**FRAC_BITS); // in the middle

// this position is relative to the center of the object
typedef struct packed {
  logic signed [POS_BITS-1:0] x;
  logic signed [POS_BITS-1:0] y;
} pos_t;

// the position is fractional:
pos_t                         ball_pos;
pos_t                         ball_next_pos;
// ball displacement is polar coordinate: an unsigned velocity and an unsigned angle alpha
logic [ANGLE_BITS-1:0]        alpha;
logic [ANGLE_BITS-1:0]        next_alpha; // direction change due to bounce
logic [ANGLE_BITS-1:0]        next_alpha_adj; // adj for random and paddle bounce
logic [ANGLE_BITS-1:0]        alpha_d;
logic [VELOCITY_BITS-1:0]     ball_velocity;

logic [SIN_COS_BITS-1:0]        cos_alpha, sin_alpha;
logic signed [SIN_COS_BITS:0]   delta_x_s, delta_y_s; // signed displacement
logic signed [VELOCITY_BITS+SIN_COS_BITS:0] delta_x_p, delta_y_p;

// Given alpha and velocity calculate the x/y displacement
// pipelining LUT read port, mult and finally shift
always_ff @(posedge clk) begin
  sin_alpha <= sin_cos_lut_pkg::SIN_LUT[alpha[ANGLE_BITS-3:0]];
  cos_alpha <= sin_cos_lut_pkg::SIN_LUT[(2**(ANGLE_BITS-2))-alpha[ANGLE_BITS-3:0]]; // complement
  alpha_d <= alpha;
  case (alpha_d[ANGLE_BITS-1:ANGLE_BITS-2]) // the 2 msb of the angle tells us the direction
    2'b00: begin // first quadrant:
        delta_x_s <= +$signed({1'b0, cos_alpha});
        delta_y_s <= -$signed({1'b0, sin_alpha});
      end
    2'b01: begin // 2nd quadrant
        delta_x_s <= -$signed({1'b0, sin_alpha});
        delta_y_s <= -$signed({1'b0, cos_alpha});
    end
    2'b10: begin // 3rd quadrant
        delta_x_s <= -$signed({1'b0, cos_alpha});
        delta_y_s <= +$signed({1'b0, sin_alpha});
    end
    2'b11: begin // 4th quadrant
        delta_x_s <= +$signed({1'b0, sin_alpha});
        delta_y_s <= +$signed({1'b0, cos_alpha});
    end
  endcase
  // apply the velocity
  delta_x_p <= (delta_x_s * $signed(ball_velocity)) >>> SIN_COS_BITS;
  delta_y_p <= (delta_y_s * $signed(ball_velocity)) >>> SIN_COS_BITS;
end

// Given the displacement now we calculate 2 things:
// the next position (keeping account for the bouncing) and whether there is a bounce
// and the new alpha

// determing the next direction:
// inputs: delta_x_p/delta_y_p current position ball_pos.x/y
// outputs: bounce_north/bounce_south/bounce_east/bounce_west/next_alpha/ball_next_pos.x/y
always_comb begin
  bounce_north = 1'b0;
  bounce_south = 1'b0;
  bounce_east = 1'b0;
  bounce_west = 1'b0;
  next_alpha = alpha;

  // candidate new position
  ball_next_pos.x = (ball_pos.x + delta_x_p);
  ball_next_pos.y = (ball_pos.y + delta_y_p);

  // check if we are bouncing and change the alpha and ball_next_pos accordingly
  if ((ball_pos.x + delta_x_p) > MAX_x) begin
    // bounce east
    ball_next_pos.x = MAX_x - (ball_pos.x + delta_x_p) + MAX_x;
    bounce_west = 1'b1;
    next_alpha = (2**(ANGLE_BITS-1)) - alpha;
  end else if ((ball_pos.x + delta_x_p) < MIN_x) begin
    // bounce west
    ball_next_pos.x = MIN_x - (ball_pos.x + delta_x_p) + MIN_x;
    bounce_east = 1'b1;
    next_alpha = (2**(ANGLE_BITS-1)) - alpha;
  end else if ((ball_pos.y + delta_y_p) > MAX_y) begin
    // bounce south
    ball_next_pos.y = MAX_y - (ball_pos.y + delta_y_p) + MAX_y;
    bounce_south = 1'b1;
    next_alpha = -alpha;
  end else if ((ball_pos.y + delta_y_p) < MIN_y) begin
    // bounce north
    ball_next_pos.y = MIN_y - (ball_pos.y + delta_y_p) + MIN_y;
    bounce_north = 1'b1;
    next_alpha = -alpha;
  end
end

// adjust alpha based on bounce and determin if we hit the paddle
// inputs: next_alpha, bounce_north/bounce_south/bounce_east/bounce_west
// outputs: game_failed_p/ball_bounce_sound_p/next_alpha_adj
always_comb begin
  ball_bounce_sound_p = 1'b0;
  game_failed_p = 1'b0;
  next_alpha_adj = next_alpha;
  if (bounce_north || bounce_south) begin
    next_alpha_adj = next_alpha + (prbs[RND_ALPHA] ? -prbs[RND_ALPHA-1:0] : +prbs[RND_ALPHA-1:0]);
    if (next_alpha_adj[ANGLE_BITS-1:ANGLE_BITS-2] == 2'b00 && next_alpha_adj > MAX_ALPHA_00) begin
      next_alpha_adj = MAX_ALPHA_00;
    end else if (next_alpha_adj[ANGLE_BITS-1:ANGLE_BITS-2] == 2'b01 && next_alpha_adj < MAX_ALPHA_01) begin
      next_alpha_adj = MAX_ALPHA_01;
    end else if (next_alpha_adj[ANGLE_BITS-1:ANGLE_BITS-2] == 2'b10 && next_alpha_adj > MAX_ALPHA_10) begin
      next_alpha_adj = MAX_ALPHA_10;
    end else if (next_alpha_adj[ANGLE_BITS-1:ANGLE_BITS-2] == 2'b11 && next_alpha_adj < MAX_ALPHA_11) begin
      next_alpha_adj = MAX_ALPHA_11;
    end
    ball_bounce_sound_p = 1'b1;
  end else if (bounce_east) begin
    if (obj_paddle_L) begin
      if (ball_pos.y >= pos_paddle_L && ball_pos.y < (pos_paddle_L + (PADDLE_SIZE_F))) begin
        next_alpha_adj = next_alpha - HIT_ADJ;
        ball_bounce_sound_p = 1'b1;
      end else if (ball_pos.y < pos_paddle_L && ball_pos.y > (pos_paddle_L - (PADDLE_SIZE_F))) begin
        next_alpha_adj = next_alpha + HIT_ADJ;
        ball_bounce_sound_p = 1'b1;
      end else begin
        game_failed_p = 1'b1;
      end
    end else begin
      next_alpha_adj = next_alpha;
      ball_bounce_sound_p = 1'b1;
    end
  end else if (bounce_west) begin
    if (obj_paddle_R) begin
      if (ball_pos.y >= pos_paddle_R && ball_pos.y < (pos_paddle_R + (PADDLE_SIZE_F))) begin
        next_alpha_adj = next_alpha + HIT_ADJ;
        ball_bounce_sound_p = 1'b1;
      end else if (ball_pos.y < pos_paddle_R && ball_pos.y > (pos_paddle_R - (PADDLE_SIZE_F))) begin
        next_alpha_adj = next_alpha - HIT_ADJ;
        ball_bounce_sound_p = 1'b1;
      end else begin
        game_failed_p = 1'b1;
      end
    end else begin
      next_alpha_adj = next_alpha;
      ball_bounce_sound_p = 1'b1;
    end
  end
end

always_ff @(posedge clk) begin
  if (reset || init_game) begin
    ball_pos.x        <= INIT_POS_x;
    ball_pos.y        <= INIT_POS_y;
    alpha             <= INIT_ANGLE + (prbs[0] ? (2**(ANGLE_BITS-1)) : 0);
    ball_bounce_sound <= 1'b0;
    game_failed       <= 1'b0;
  end else if (motion_enable && frame_start_strobe) begin
    ball_pos.x        <= ball_next_pos.x;
    ball_pos.y        <= ball_next_pos.y;
    alpha             <= next_alpha_adj;
    ball_bounce_sound <= ball_bounce_sound_p;
    game_failed       <= game_failed_p;
  end
end

// obj position is referred top left corner of the object, but in the game they are referred to the center of the obj
always_ff @(posedge clk) begin
  obj_x[0] = (ball_pos.x>>>FRAC_BITS) - (BALL_SIZE/2);
  obj_y[0] = (ball_pos.y>>>FRAC_BITS) - (BALL_SIZE/2);
  // 2nd ball is disable for now
  obj_x[1] = '0;
  obj_y[1] = '0;
end

///////////////////////////////////////////////////////////////////////////////
// Paddle position
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
  if (reset || init_game) begin
    pos_paddle_L <= INIT_paddle;
    pos_paddle_R <= INIT_paddle;
  end else if (motion_enable) begin
    if (up_R) begin
      if (pos_paddle_R > MIN_paddle + $signed({1'b0, paddle_step})) begin
        pos_paddle_R <= pos_paddle_R - $signed({1'b0, paddle_step});
      end else begin
        pos_paddle_R <= MIN_paddle;
      end
    end else if (down_R) begin
      if (pos_paddle_R < MAX_paddle - $signed({1'b0, paddle_step})) begin
        pos_paddle_R <= pos_paddle_R + $signed({1'b0, paddle_step});
      end else begin
        pos_paddle_R <= MAX_paddle;
      end
    end
    if (up_L) begin
      if (pos_paddle_L > MIN_paddle + $signed({1'b0, paddle_step})) begin
        pos_paddle_L <= pos_paddle_L - $signed({1'b0, paddle_step});
      end else begin
        pos_paddle_L <= MIN_paddle;
      end
    end else if (down_L) begin
      if (pos_paddle_L < MAX_paddle - $signed({1'b0, paddle_step})) begin
        pos_paddle_L <= pos_paddle_L + $signed({1'b0, paddle_step});
      end else begin
        pos_paddle_L <= MAX_paddle;
      end
    end
  end
end
// obj 2 and 3 are the 2 paddles:
always_ff @(posedge clk) begin
  obj_x[2] = (MIN_x>>>FRAC_BITS) - (BALL_SIZE/2);
  obj_x[3] = (MAX_x>>>FRAC_BITS) - (BALL_SIZE/2);
  obj_y[2] = (pos_paddle_L>>>FRAC_BITS) - (PADDLE_SIZE/2);
  obj_y[3] = (pos_paddle_R>>>FRAC_BITS) - (PADDLE_SIZE/2);
end

///////////////////////////////////////////////////////////////////////////////
// Timer
///////////////////////////////////////////////////////////////////////////////
localparam int  ONE_SECOND_COUNT = CLK_RATE;
localparam int  TO_5SEC = 5;
localparam int  TO_3SEC = 3;
localparam int  TO_30SEC = 30;

logic [$clog2(CLK_RATE)-1:0]    one_sec_counter;
logic                           one_sec_pls;

always_ff @(posedge clk) begin
  if (reset) begin
    one_sec_counter <= 0;
    one_sec_pls <= 1'b0;
  end else begin
    if (one_sec_counter < ONE_SECOND_COUNT-1) begin
      one_sec_counter <= one_sec_counter + 1;
      one_sec_pls <= 1'b0;
    end else begin
      one_sec_counter <= '0;
      one_sec_pls <= 1'b1;
    end
  end
end

///////////////////////////////////////////////////////////////////////////////
// Game state machine
///////////////////////////////////////////////////////////////////////////////
enum {
  Idle,
  CompVsComp,
  WaitForR,
  WaitForL,
  OnePlayerR,
  OnePlayerL,
  TwoPlayers,
  Finished
} game_state;
logic [7:0]                     timer_sec; // timer in second - max 256 seconds

always_ff @(posedge clk) begin
  if (reset) begin
    game_state      <= Idle;
    timer_sec       <= '0;
    init_game       <= 1'b1;
  end else begin
    case (game_state)
      Idle: begin
        timer_sec         <= timer_sec + one_sec_pls;
        init_game         <= 1'b1;
        if (btn_r_a || btn_r_b) begin
          game_state      <= WaitForL;
          timer_sec       <= '0;
        end else if (btn_l_a || btn_l_b) begin
          game_state      <= WaitForR;
          timer_sec       <= '0;
        end else if (timer_sec > TO_30SEC) begin
          game_state      <= CompVsComp;
        end
      end
      CompVsComp: begin
        init_game         <= 1'b0;
        if (btn_r_a || btn_r_b) begin
          game_state      <= WaitForL;
          timer_sec       <= '0;
        end else if (btn_l_a || btn_l_b) begin
          game_state      <= WaitForR;
          timer_sec       <= '0;
        end
      end
      WaitForL: begin
        timer_sec         <= timer_sec + one_sec_pls;
        init_game         <= 1'b1;
        if (btn_l_a || btn_l_b) begin
          game_state      <= TwoPlayers;
        end else if (timer_sec > TO_5SEC) begin
          game_state      <= OnePlayerR;
        end
      end
      WaitForR: begin
        timer_sec         <= timer_sec + one_sec_pls;
        init_game         <= 1'b1;
        if (btn_r_a || btn_r_b) begin
          game_state      <= TwoPlayers;
        end else if (timer_sec > TO_5SEC) begin
          game_state      <= OnePlayerL;
        end
      end
      OnePlayerR: begin
        init_game         <= 1'b0;
        if (game_failed) begin
          game_state      <= Finished;
          timer_sec       <= '0;
        end
      end
      OnePlayerL: begin
        init_game         <= 1'b0;
        if (game_failed) begin
          game_state      <= Finished;
          timer_sec       <= '0;
        end
      end
      TwoPlayers: begin
        init_game         <= 1'b0;
        if (game_failed) begin
          game_state      <= Finished;
          timer_sec       <= '0;
        end
      end
      Finished: begin
        timer_sec         <= timer_sec + one_sec_pls;
        if (timer_sec > TO_3SEC) begin
          game_state      <= Idle;
          timer_sec       <= '0;
        end
      end
      default: begin
        game_state        <= Idle;
      end
    endcase
  end
end

///////////////////////////////////////////////////////////////////////////////
// State machine outputs
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge clk) begin
  if (reset) begin
    obj_paddle_L    <= 1'b0;
    obj_paddle_R    <= 1'b0;
    sound_idx       <= '0;
    play_sound      <= 1'b0;
    frame_widths    <= {8'd0, 8'd0, 8'd0, 8'd0};
    obj_ball_1      <= 1'b0;
    obj_ball_0      <= 1'b0;
    motion_enable   <= 1'b0;
  end else begin
    // reset strings to be empty
    case (game_state)
      Idle: begin
        frame_widths    <= {8'd0, 8'd0, 8'd0, 8'd0};
        obj_paddle_R    <= 1'b0;
        obj_paddle_L    <= 1'b0;
        play_sound      <= 1'b0;
        obj_ball_0      <= 1'b0;
        motion_enable   <= 1'b0;
      end
      CompVsComp: begin
        frame_widths    <= {8'd8, 8'd8, 8'd8, 8'd8};
        obj_ball_0      <= 1'b1; // only 1 ball
        obj_paddle_R    <= 1'b0;
        obj_paddle_L    <= 1'b0;
        play_sound      <= 1'b0;
        motion_enable   <= 1'b1;
      end
      WaitForR: begin
        frame_widths    <= {8'd0, 8'd0, 8'd0, 8'd0};
        obj_ball_0      <= 1'b0;
        obj_paddle_L    <= 1'b1;
        play_sound      <= 1'b0;
        motion_enable   <= 1'b0;
      end
      WaitForL: begin
        frame_widths    <= {8'd0, 8'd0, 8'd0, 8'd0};
        obj_ball_0      <= 1'b0;
        obj_paddle_R    <= 1'b1;
        play_sound      <= 1'b0;
        motion_enable   <= 1'b0;
      end
      OnePlayerR: begin
        frame_widths    <= {8'd8, 8'd8, 8'd0, 8'd8};
        obj_ball_0      <= 1'b1; // only 1 ball
        obj_paddle_R    <= 1'b1;
        play_sound      <= ball_bounce_sound;
        sound_idx       <= '0;
        motion_enable   <= 1'b1;
      end
      OnePlayerL: begin
        frame_widths    <= {8'd8, 8'd8, 8'd8, 8'd0};
        obj_ball_0      <= 1'b1; // only 1 ball
        obj_paddle_L    <= 1'b1;
        play_sound      <= ball_bounce_sound;
        sound_idx       <= '0;
        motion_enable   <= 1'b1;
      end
      TwoPlayers: begin
        frame_widths    <= {8'd8, 8'd8, 8'd0, 8'd0};
        obj_ball_0      <= 1'b1; // only 1 ball
        obj_paddle_L    <= 1'b1;
        obj_paddle_R    <= 1'b1;
        play_sound      <= ball_bounce_sound;
        sound_idx       <= '0;
        motion_enable   <= 1'b1;
      end
      Finished: begin
        play_sound      <= timer_sec == '0;
        sound_idx       <= 1;
        motion_enable   <= 1'b0;
      end
    endcase
  end
end

// Overlay text
always_ff @(posedge clk) begin
  // reset strings to be empty
  for (int idx=0; idx<STRING_ROWS; idx++) begin
    strings[idx]    <= {"                              "};
  end
  text_color        <= 24'h5F5F5F;
  case (game_state)
    Idle: begin
      strings[ 6]   <= {"   push any button to start   "};
      strings[ 7]   <= {"https://github.com/           "};
      strings[ 8]   <= {"         /luca-clk/fpga_arcade"};
      strings[10]   <= {"https://github.com/           "};
      strings[11]   <= {"         /luca-clk/fpga_arcade"};
      strings[12]   <= {"   push any button to start   "};
    end
    CompVsComp: begin
      strings[ 7]   <= {"   push any button to start   "};
      strings[11]   <= {"   push any button to start   "};
    end
    WaitForR: begin
      strings[ 7]   <= {"    Wait For Other Player     "};
      strings[11]   <= {"                              "};
      text_color    <= 24'hFF0000;
    end
    WaitForL: begin
      strings[ 7]   <= {"                              "};
      strings[11]   <= {"    Wait For Other Player     "};
      text_color    <= 24'hFFFF00;
    end
    Finished: begin
      strings[ 7]   <= {"          Game Over           "};
      strings[11]   <= {"          Game Over           "};
      text_color    <= 24'hFF0000;
    end
  endcase
end

// Ball velocity - reset at START_VELOCITY at every idel
always_ff @(posedge clk) begin
  if (game_state == OnePlayerR || game_state == OnePlayerL || game_state == TwoPlayers) begin
    ball_velocity    <= ball_velocity + (one_sec_pls ? STEP_VELOCITY : '0);
  end else begin
    ball_velocity    <= START_VELOCITY;
  end
end

// ball velocity
always_ff @(posedge clk) begin
  blink_btn_r_a   <= 1'b0;
  blink_btn_r_b   <= 1'b0;
  blink_btn_l_a   <= 1'b0;
  blink_btn_l_b   <= 1'b0;
  if (game_state == Idle || game_state == CompVsComp) begin
    blink_btn_r_a <= 1'b1;
    blink_btn_r_b <= 1'b1;
    blink_btn_l_a <= 1'b1;
    blink_btn_l_b <= 1'b1;
  end else if (game_state == WaitForR) begin
    blink_btn_r_a <= 1'b1;
    blink_btn_r_b <= 1'b1;
  end else if (game_state == WaitForL) begin
    blink_btn_l_a <= 1'b1;
    blink_btn_l_b <= 1'b1;
  end
end

// constants:
always_comb begin
  string_dir  = 'b1111111110000000000;
  frame_color = {24'h773311, 24'h773311, 24'h773311, 24'h773311};
  obj_en      = {obj_paddle_R, obj_paddle_L, obj_ball_1, obj_ball_0};
  obj_color <= {
    24'h0000FF,   // paddle R
    24'hFF0000,   // paddle L
    24'h0000FF,   // ball 1
    24'hFFFFFF    // ball 0
  };
end

// `define ILA_DEBUG 1
`ifndef __SIMULATION__
`ifdef ILA_DEBUG

  logic [127:0] probe0;

  ila_128_2048 ila (
    .clk(clk), // input wire clk
    .probe0(probe0) // input wire [127:0]  probe0
  );

  assign probe0 = {alpha, ball_velocity, game_state, delta_x_p,delta_y_p};
`endif
`endif

endmodule
