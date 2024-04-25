create_project fpga_arcade_sim fpga_arcade_sim -part xc7a100tcsg324-1 -force -verbose
add_files -norecurse {
    nexys_arcade_top_tb.sv
    ../rtl/audio/audio_pwm.sv 
    ../rtl/video/vga_hd_pkg.sv ../rtl/utils/debounce.sv 
    ../rtl/video/obj_pkg.sv ../rtl/utils/dithering.sv ../rtl/io_ctrl/encoder_sense.sv 
    ../rtl/video/font_pkg.sv ../rtl/top/system_clock_gen.sv ../rtl/top/game.sv 
    ../rtl/audio/audio_playout.sv ../rtl/audio/sound_pkg.sv ../rtl/top/sin_cos_lut_pkg.sv 
    ../rtl/utils/randomizer.sv ../rtl/io_ctrl/io_ctrl.sv ../rtl/io_ctrl/seven_segment_driver.sv 
    ../rtl/video/image_rendering.sv ../rtl/top/nexys_arcade_top.sv ../rtl/video/vga_hd_driver.sv 
    ../rtl/video/text_rendering.sv}
set_property top nexys_arcade_top_tb [current_fileset -simset]
launch_simulation -noclean_dir -step simulate
close_sim
