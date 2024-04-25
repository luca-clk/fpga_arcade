module io_ctrl #(
  parameter int NUM_CTRL_VARS = 16,
  parameter int CLK_RATE = 49500000
)(
  input logic         clk,
  input logic         reset,

  // SWITCHES
  input logic [15:0]  SW,

  // BUTTONS
  input logic         BTNC,
  input logic         BTNU,
  input logic         BTNL,
  input logic         BTNR,
  input logic         BTND,

  // PMOD INPUTS (and outputs)
  input logic         SPWH_R_1,
  input logic         SPWH_R_2,
  output logic        BTN_R_A_OUT,
  input logic         BTN_R_A_IN,
  output logic        BTN_R_B_OUT,
  input logic         BTN_R_B_IN,

  input logic         SPWH_L_1,
  input logic         SPWH_L_2,
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
  output logic [15:0] LED,

  //  Debug controls:
  output logic [NUM_CTRL_VARS-1:0][15:0]  control_vars,   // always 16 bit - scale and offset elsewhere
  output logic [15:0]   sw_control,     // static switches
  input logic [15:0]    display_16led,  // display 16 led's

  // Wheel controls:
  output logic          up_R,
  output logic          down_R,
  output logic          up_L,
  output logic          down_L,
  // button controls:
  output logic          btn_r_a,
  output logic          btn_r_b,
  output logic          btn_l_a,
  output logic          btn_l_b,
  input logic           blink_btn_r_a,
  input logic           blink_btn_r_b,
  input logic           blink_btn_l_a,
  input logic           blink_btn_l_b
);

logic                 btnc_d, btnu_d, btnl_d, btnr_d, btnd_d;
logic                 btnc_dd, btnu_dd, btnl_dd, btnr_dd, btnd_dd;

///////////////////////////////////////////////////////////////////////////////
// STATIC SWITCHES
///////////////////////////////////////////////////////////////////////////////

// debounce switches:
debounce #(.WIDTH(16), .LEN_LOG(12)) debounce_sw_i (
  .clk            (clk),
  .reset          (reset),
  .sw_in          (SW),
  .sw_out         (sw_control)
);

///////////////////////////////////////////////////////////////////////////////
// DISPLAY and CONTROL VARS
///////////////////////////////////////////////////////////////////////////////

// debounce buttons
debounce #(.WIDTH(5), .LEN_LOG(16)) debounce_btn_i (
  .clk            (clk),
  .reset          (reset),
  .sw_in          ({BTNC, BTNU, BTNL, BTNR, BTND}),
  .sw_out         ({btnc_d, btnu_d, btnl_d, btnr_d, btnd_d})
);

logic [$clog2(NUM_CTRL_VARS)-1:0] control_vars_idx;

// Left and right select the control_vars_idx
always_ff @(posedge clk) begin
  if (reset) begin
    btnl_dd <= 0;
    btnr_dd <= 0;
    control_vars_idx <= '0;
  end else begin
    btnl_dd <= btnl_d;
    btnr_dd <= btnr_d;
    if (btnl_d && !btnl_dd) begin
      if (control_vars_idx > 0) begin
        control_vars_idx <= control_vars_idx - 1;
      end else begin
        control_vars_idx <= NUM_CTRL_VARS-1;
      end
    end else if (btnr_d && !btnr_dd) begin
      if (control_vars_idx < NUM_CTRL_VARS-1) begin
        control_vars_idx <= control_vars_idx + 1;
      end else begin
        control_vars_idx <= 0;
      end
    end
  end
end

// Up/Down increment/decrement the value - FSM
localparam int TIME_100MS = CLK_RATE / 10; // 10 beat per second - 100ms
localparam int HOLD_SLOW_WAIT = 10; // 1 second in unit of 100ms interval
localparam int HOLD_FAST_WAIT = 20; // 2 more second in unit of 100ms interval
typedef enum logic[2:0] {
  IDLE          = 0,
  HOLD          = 1,
  HOLD_SLOW     = 2,
  HOLD_FAST     = 3
} hold_fsm_t;
hold_fsm_t hold_fsm;
logic which_btn; // valid only in HOLD/HOLD_SLOW/HOLD_FAST
logic [$clog2(TIME_100MS)-1:0]    timer_100ms;
logic                             timer_100ms_pls;
logic [7:0]                       timer_cnt;

always_ff @(posedge clk) begin
  if (reset) begin
    timer_100ms <= 0;
    timer_cnt <= '0;
    hold_fsm <= IDLE;
    which_btn <= 1'b0;
    timer_100ms_pls <= 1'b0;
  end else begin
    timer_100ms_pls <= timer_100ms == '0;
    timer_100ms <= (timer_100ms < TIME_100MS) ? (timer_100ms + 1) : '0;
    // mini fsm for hold detect:
    case (hold_fsm)
      IDLE: begin
        timer_cnt <= '0;
        if (btnu_d || btnd_d) begin
          hold_fsm <= HOLD;
          which_btn <= btnu_d; // 1 is up, 0 is down
          timer_100ms <= 0;
        end
      end
      HOLD: begin
        timer_cnt <= timer_cnt + timer_100ms_pls;
        if ((which_btn && !btnu_d) || (!which_btn && !btnd_d)) begin
          hold_fsm <= IDLE;
        end else if (timer_cnt >= HOLD_SLOW_WAIT) begin
          hold_fsm <= HOLD_SLOW;
          timer_cnt <= '0;
          timer_100ms <= '0;
        end
      end
      HOLD_SLOW: begin
        timer_cnt <= timer_cnt + timer_100ms_pls;
        if ((which_btn && !btnu_d) || (!which_btn && !btnd_d)) begin
          hold_fsm <= IDLE;
        end else if (timer_cnt >= HOLD_FAST_WAIT) begin
          hold_fsm <= HOLD_FAST;
          timer_cnt <= '0;
          timer_100ms <= '0;
        end
      end
      HOLD_FAST: begin
        if ((which_btn && !btnu_d) || (!which_btn && !btnd_d)) begin
          hold_fsm <= IDLE;
        end
      end
    endcase
  end
end


// Update control_vars
always_ff @(posedge clk) begin
  if (reset) begin
    // Initialize all of the at 0:
    for (int idx=0; idx<NUM_CTRL_VARS; idx++) begin
      control_vars[idx] <= 0;
    end
    // special initialization
    control_vars[0] <= 50; // ball speed
    control_vars[1] <= 10; // syncs_latency_correction
    control_vars[2] <= 16; // rack_step
    control_vars[3] <= 16'h0100; // audio gain
  end else begin
    if ((hold_fsm == IDLE && btnu_d) || (hold_fsm == HOLD_SLOW && which_btn && timer_100ms_pls)) begin
      control_vars[control_vars_idx] <= control_vars[control_vars_idx] + 1;
    end else if ((hold_fsm == IDLE && btnd_d) || (hold_fsm == HOLD_SLOW && !which_btn && timer_100ms_pls)) begin
      control_vars[control_vars_idx] <= control_vars[control_vars_idx] - 1;
    end else if (hold_fsm == HOLD_FAST && which_btn && timer_100ms_pls) begin
      control_vars[control_vars_idx] <= control_vars[control_vars_idx] + 10;
    end else if (hold_fsm == HOLD_FAST && !which_btn && timer_100ms_pls) begin
      control_vars[control_vars_idx] <= control_vars[control_vars_idx] - 10;
    end
  end
end

logic [7:0][3:0]        display_string;

assign display_string[3:0] = control_vars_idx;
assign display_string[7:4] = control_vars[control_vars_idx];

seven_segment_driver seven_segment_driver_i(
  .clk        (clk),
  .reset      (reset),
  .nibbles_in (display_string),
  .points_in  (control_vars_idx),
  .CA,
  .CB,
  .CC,
  .CD,
  .CE,
  .CF,
  .CG,
  .DP,
  .AN
);

///////////////////////////////////////////////////////////////////////////////
// INPUTS buttons and wheels
///////////////////////////////////////////////////////////////////////////////
encoder_sense encoder_sense_iR(
  .clk    (clk),
  .reset  (reset),

  .dir    (1'b0),
  .k1     (SPWH_R_1),
  .k2     (SPWH_R_2),
  .up     (up_R),
  .down   (down_R)
);
encoder_sense encoder_sense_iL(
  .clk    (clk),
  .reset  (reset),

  .dir    (1'b1),
  .k1     (SPWH_L_1),
  .k2     (SPWH_L_2),
  .up     (up_L),
  .down   (down_L)
);

debounce #(.WIDTH(4), .LEN_LOG(16)) debounce_btn_ii (
  .clk            (clk),
  .reset          (reset),
  .sw_in          ({BTN_R_A_IN, BTN_R_B_IN, BTN_L_A_IN, BTN_L_B_IN}),
  .sw_out         ({btn_r_a, btn_r_b, btn_l_a, btn_l_b})
);

///////////////////////////////////////////////////////////////////////////////
// Output LED
///////////////////////////////////////////////////////////////////////////////
always_comb begin
  LED       = display_16led;
end

///////////////////////////////////////////////////////////////////////////////
// Blinking Button LEDs
///////////////////////////////////////////////////////////////////////////////
logic [31:0]  led_counter;
logic [7:0]   pwm_counter;
logic         led_pulse_slow;
localparam    LED_PULSE_LOG_SLOW = 25;
always_ff @(posedge clk) begin
  if (reset) begin
    led_counter <= 0;
    pwm_counter <= '0;
  end else begin
    led_counter <= led_counter + 1;
    pwm_counter <= pwm_counter + 1;
    led_pulse_slow <= pwm_counter>led_counter[(LED_PULSE_LOG_SLOW-1) -: 8] ?
        led_counter[LED_PULSE_LOG_SLOW] : !led_counter[LED_PULSE_LOG_SLOW];
  end
end

// placeholder - add some function to the LED driving
always_comb begin
  BTN_R_A_OUT = blink_btn_r_a ? !led_pulse_slow : 1'b1;
  BTN_R_B_OUT = blink_btn_r_b ? led_pulse_slow : 1'b1;
  BTN_L_A_OUT = blink_btn_l_a ? !led_pulse_slow : 1'b1;
  BTN_L_B_OUT = blink_btn_l_b ? led_pulse_slow : 1'b1;
end

// `ifndef __SIMULATION__
//   logic [127:0] probe0;

//   ila_128_2048 ila (
//     .clk(clk), // input wire clk
//     .probe0(probe0) // input wire [127:0]  probe0
//   );

//   assign probe0 = {down_L, up_L, down_R, up_R, SPWH_L_1, SPWH_L_2, SPWH_R_1, SPWH_R_2};
// `endif

endmodule
