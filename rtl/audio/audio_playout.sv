module audio_playout #(
  parameter int AUD_BITS = 12,
  parameter int SOUND_IDX_BITS = 8
) (
  input  wire                             clk,
  input  wire                             reset,

  input logic                             aud_valid,  // sample rate pulse
  input logic                             play_sound, // 1 clk pulse or continous for loop playout
  input logic [SOUND_IDX_BITS-1:0]        sound_idx,
  output logic [AUD_BITS-1:0]             audio
);

import sound_pkg::*;

logic [$clog2(sound_pkg::TOTOAL_LEN+1)-1:0]   sample_idx;
logic [$clog2(sound_pkg::TOTOAL_LEN+1)-1:0]   sound_stop;
logic                                         playing;

always_ff @(posedge clk) begin
  if (reset) begin
    playing       <= 1'b0;
    sample_idx    <= '0;
    sound_stop    <= '0;
    audio         <= 0;
  end else begin
    if (play_sound && !playing) begin
      playing     <= 1'b1;
      sample_idx  <= sound_pkg::Sound_Start_Length[sound_idx][0];
      sound_stop  <= sound_pkg::Sound_Start_Length[sound_idx][1];
      audio       <= 0;
    end else if (playing && aud_valid) begin
      if (sample_idx <= sound_stop) begin
        sample_idx  <= sample_idx + 1;
        audio       <= sound_pkg::Sound[sample_idx];
      end else begin
        playing     <= 1'b0;
        audio       <= 0;
      end
    end
  end
end

// `ifndef __SIMULATION__
//   logic [127:0] probe0;

//   ila_128_2048 ila (
//     .clk(clk), // input wire clk
//     .probe0(probe0) // input wire [127:0]  probe0
//   );

//   assign probe0 = {aud_valid, audio, playing, sample_idx};
// `endif

endmodule
