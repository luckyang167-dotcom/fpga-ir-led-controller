# ModelSim simulation script for led_controller
# Usage: vsim -do sim/tb_led_controller.do

# Compile RTL dependencies
if {![file exists work]} { vlib work }
vlog -work work rtl/common/counter.v
vlog -work work rtl/common/pwm.v
vlog -work work rtl/display/led_controller.v

# Compile testbench
vlog -work work tb/tb_led_controller.v

# Run simulation (no GUI)
vsim -c work.tb_led_controller -do "run -all; quit"
