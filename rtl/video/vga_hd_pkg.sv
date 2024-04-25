package vga_hd_pkg;

// *************************** 1080P video timer ***************************

// 1920x1080@p60 has these timings:
//     Name        1920x1080p60
//     Standard      SMPTE 274M
//     VIC                   16
//     Short Name         1080p
//     Aspect Ratio        16:9

//     Pixel Clock        148.5 MHz
//     TMDS Clock       1,485.0 MHz
//     Pixel Time           6.7 ns ±0.5%
//     Horizontal Freq.  67.500 kHz
//     Line Time           14.8 μs
//     Vertical Freq.    60.000 Hz
//     Frame Time          16.7 ms

//     Horizontal Timings
//     Active Pixels       1920
//     Front Porch           88
//     Sync Width            44
//     Back Porch           148
//     Blanking Total       280
//     Total Pixels        2200
//     Sync Polarity        pos

//     Vertical Timings
//     Active Lines        1080
//     Front Porch            4
//     Sync Width             5
//     Back Porch            36
//     Blanking Total        45
//     Total Lines         1125
//     Sync Polarity        pos

//     Active Pixels  2,073,600
//     Data Rate           3.56 Gbps

//     Frame Memory (Kbits)
//      8-bit Memory     16,200
//     12-bit Memory     24,300
//     24-bit Memory     48,600
//     32-bit Memory     64,800

`ifndef FAST_SIM
  // 1080x1920@60p timings:
  localparam int TotalPixel     = 2200;
  localparam int TotalLines     = 1125;
  localparam int VertSyncLine   = 1120;
  localparam int HorzSyncPel    = 2156;
  localparam int HorzBackPorch  = 148;
  localparam int VertBackPorch  = 36;
  localparam int ActivePels     = 1920;
  localparam int ActiveLines    = 1080;
`else
  // For fast sim, the image size is way smaller
  // 150x200@XXXp fast sim:
  localparam int TotalPixel     = 280;
  localparam int TotalLines     = 170;
  localparam int VertSyncLine   = 165;
  localparam int HorzSyncPel    = 268;
  localparam int HorzBackPorch  = 20;
  localparam int VertBackPorch  = 10;
  localparam int ActivePels     = 200;
  localparam int ActiveLines    = 150;
`endif

endpackage
