# ModelSim simulation script for inf_controller
# Usage: vsim -do sim/tb_inf_controller.do

# Compile RTL dependencies
if {![file exists work]} { vlib work }
vlog -work work rtl/common/counter.v
vlog -work work rtl/common/edge_detect.v
vlog -work work rtl/common/glbcnt.v
vlog -work work rtl/infrared/inf_controller.v

# Compile testbench
vlog -work work tb/tb_inf_controller.v

# Run simulation (no GUI)
vsim -c work.tb_inf_controller -do "run -all; quit"
