# ModelSim simulation script for fifo_controller
# Usage: vsim -do sim/tb_fifo_controller.do

# Compile RTL
if {![file exists work]} { vlib work }
vlog -work work rtl/fifo/fifo_controller.v

# Compile testbench
vlog -work work tb/tb_fifo_controller.v

# Run simulation (no GUI)
vsim -c work.fifo_controller_tb -do "run -all; quit"
