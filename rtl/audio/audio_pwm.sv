module audio_pwm #(
  parameter int AUD_BITS = 12,
  parameter int GAIN_BITS = 16,
  parameter int GAIN_FRAC_BITS = 8,
  parameter int PWM_PERIOD_LOG = 11
) (
  input  wire                         clk, // must be ~(2**PWM_PERIOD_LOG * sample rate) = (2**10*24000)
  input  wire                         reset,

  input logic signed [GAIN_BITS-1:0]  audio_gain,
  output logic                        audio_valid,
  input logic signed [AUD_BITS-1:0]   audio,
  output logic                        pwm_out
);

localparam int                        HALF_PWM_SCALE = 2**(PWM_PERIOD_LOG-1);
localparam int                        AUDIO_SHIFT = AUD_BITS+GAIN_FRAC_BITS-PWM_PERIOD_LOG;

logic [PWM_PERIOD_LOG-1:0]            pwm_period_count;
logic signed [AUD_BITS+GAIN_BITS-1:0] audio_gained;
logic signed [PWM_PERIOD_LOG:0]       audio_truncated;
logic signed [PWM_PERIOD_LOG:0]       audio_offset; // this should be always positive
logic                                 req_sample, req_sample_d, req_sample_dd;
logic                                 pwm_out_p;

// apply a gain, truncate and shift in the positive
always_ff @(posedge clk) begin
  if (reset) begin
    audio_gained <= '0;
    audio_truncated <= '0;
    audio_offset <= HALF_PWM_SCALE;
  end else if (req_sample) begin
    audio_gained <= audio * audio_gain;
  end else if (req_sample_d) begin
    audio_truncated <= audio_gained>>>AUDIO_SHIFT;
  end else if (req_sample_dd) begin
    audio_offset <= audio_truncated + HALF_PWM_SCALE; // audio_offset should be positive
  end
end

// audio timing:
// we assume we handle 48000Hz audio samples
// 49.5MHz/2**10 = ~48340Hz
always_ff @(posedge clk) begin
  if (reset) begin
    pwm_period_count    <= '0;
    req_sample          <= 1'b0;
    req_sample_d        <= 1'b0;
    req_sample_dd       <= 1'b0;
    pwm_out_p           <= 1'b0;
    pwm_out             <= 1'b0;
  end else begin
    pwm_period_count    <= pwm_period_count + 1;
    req_sample          <= pwm_period_count == 0;
    req_sample_d        <= req_sample;
    req_sample_dd       <= req_sample_d;
    if (req_sample_dd) begin
      pwm_out_p <= 1'b1;
    end else if (pwm_period_count > audio_offset) begin
      pwm_out_p <= 1'b0;
    end
    pwm_out <= pwm_out_p;
  end
end

assign audio_valid = req_sample;

// `ifndef __SIMULATION__
//   logic [127:0] probe0;

//   ila_128_2048 ila (
//     .clk(clk), // input wire clk
//     .probe0(probe0) // input wire [127:0]  probe0
//   );

//   assign probe0 = {audio_valid, audio, audio_truncated, pwm_period_count, audio_offset, pwm_out_p};
// `endif

endmodule
