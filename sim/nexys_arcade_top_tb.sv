// This testbench simply supplies the synthesizable testbench with a clock and reset for use in simulation

module nexys_arcade_top_tb ();

bit clk;
bit reset;

// 100MHz clock
initial begin
  clk = '0;
  forever #5 clk = !clk;
end

logic [15:0]      SW = 16'b0000_0000_0001_1001;

nexys_arcade_top dut_i (
  .CLK100MHZ        (clk),
  .CPU_RESETN       (!reset),

  .VGA_R            (),
  .VGA_G            (),
  .VGA_B            (),
  .VGA_HS           (),
  .VGA_VS           (),

  .SW               (SW),

  .SPWH_R_1         (),
  .SPWH_R_2         (),
  .BTN_R_A_OUT      (),
  .BTN_R_A_IN       (1'b1),
  .BTN_R_B_OUT      (),
  .BTN_R_B_IN       (1'b0),
  .SPWH_L_1         (),
  .SPWH_L_2         (),
  .BTN_L_A_OUT      (),
  .BTN_L_A_IN       (1'b1),
  .BTN_L_B_OUT      (),
  .BTN_L_B_IN       (1'b0),

  .CA               (),
  .CB               (),
  .CC               (),
  .CD               (),
  .CE               (),
  .CF               (),
  .CG               (),
  .DP               (),
  .AN               (),

  .LED              (),

  .AUD_PWM          (),
  .AUD_SD           ()

);

initial begin
  reset = 0;
  #100 reset = 1;
  #200 reset = 0;
  // Drive the sound: force
  #10000;
  @(posedge clk) force dut_i.play_sound = 1'b1;
  #100;
  @(posedge clk) release dut_i.play_sound;
  #100;
  #10s;
  $finish;
end

endmodule
