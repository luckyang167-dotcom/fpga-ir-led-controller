# ModelSim simulation script for seq_detector
# Usage: vsim -do sim/tb_seq_detector.do

# Compile RTL
if {![file exists work]} { vlib work }
vlog -work work rtl/seq_detector/seq_detector.v

# Compile testbench
vlog -work work tb/tb_seq_detector.v

# Run simulation (no GUI)
vsim -c work.seq_detector_tb -do "run -all; quit"
