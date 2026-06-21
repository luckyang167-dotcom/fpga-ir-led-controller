# ModelSim compile script — compiles all RTL into work library
# Usage: vsim -do sim/compile.do

# Create or refresh work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Common base modules (no internal dependencies)
vlog -work work rtl/common/counter.v
vlog -work work rtl/common/edge_detect.v
vlog -work work rtl/common/pwm.v
vlog -work work rtl/common/glbcnt.v

# Functional modules (depend on common)
vlog -work work rtl/infrared/inf_controller.v
vlog -work work rtl/display/led_controller.v
vlog -work work rtl/fifo/fifo_controller.v
vlog -work work rtl/seq_detector/seq_detector.v

# Top-level
vlog -work work rtl/top/top_system.v

echo "=== RTL compilation complete ==="
