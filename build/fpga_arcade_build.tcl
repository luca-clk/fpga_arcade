create_project fpga_arcade fpga_arcade -part xc7a100tcsg324-1 -force -verbose
add_files -norecurse {
    ../rtl/audio/audio_pwm.sv 
    ../rtl/video/vga_hd_pkg.sv ../rtl/utils/debounce.sv 
    ../rtl/video/obj_pkg.sv ../rtl/utils/dithering.sv ../rtl/io_ctrl/encoder_sense.sv 
    ../rtl/video/font_pkg.sv ../rtl/top/system_clock_gen.sv ../rtl/top/game.sv 
    ../rtl/audio/audio_playout.sv ../rtl/audio/sound_pkg.sv ../rtl/top/sin_cos_lut_pkg.sv 
    ../rtl/utils/randomizer.sv ../rtl/io_ctrl/io_ctrl.sv ../rtl/io_ctrl/seven_segment_driver.sv 
    ../rtl/video/image_rendering.sv ../rtl/top/nexys_arcade_top.sv ../rtl/video/vga_hd_driver.sv 
    ../rtl/video/text_rendering.sv}

set BUILD_TIME [clock seconds]
puts "time: $BUILD_TIME"
set common_defines {}
lappend common_defines "BUILD_TIME=${BUILD_TIME}"
set_property verilog_define "[join [list ${common_defines}]]" [current_fileset]

add_files -fileset constrs_1 -norecurse ../constraints/Nexys-4-DDR-Master.xdc
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
close_project