#!/bin/bash
# Run all testbenches with Icarus Verilog and report results
# Prerequisites: iverilog, vvp in PATH

set -e
cd "$(dirname "$0")/.."

# Cleanup any previous run artifacts
rm -f sim/*.vcd sim/*.vvp

TB_RUNS=(
    # name        sources
    "tb_inf_controller:rtl/common/counter.v rtl/common/edge_detect.v rtl/common/glbcnt.v rtl/infrared/inf_controller.v tb/tb_inf_controller.v"
    "tb_led_controller:rtl/common/counter.v rtl/common/pwm.v rtl/display/led_controller.v tb/tb_led_controller.v"
    "tb_fifo_controller:rtl/fifo/fifo_controller.v tb/tb_fifo_controller.v"
    "tb_seq_detector:rtl/seq_detector/seq_detector.v tb/tb_seq_detector.v"
)

PASSED=0
FAILED=0
declare -a RESULTS

for entry in "${TB_RUNS[@]}"; do
    name="${entry%%:*}"
    sources="${entry#*:}"

    echo "=== Compiling $name ==="
    vvp_file="sim/${name}.vvp"

    if iverilog -o "$vvp_file" $sources 2>&1; then
        echo "  Compile: OK"
    else
        echo "  FAIL: compilation error"
        FAILED=$((FAILED + 1))
        RESULTS+=("FAIL: $name (compile)")
        continue
    fi

    echo "=== Running $name ==="
    if timeout 30 vvp "$vvp_file" 2>&1 | tee "sim/${name}.log"; then
        echo "  PASS: $name"
        PASSED=$((PASSED + 1))
        RESULTS+=("PASS: $name")
    else
        echo "  FAIL: $name (runtime)"
        FAILED=$((FAILED + 1))
        RESULTS+=("FAIL: $name (runtime)")
    fi
done

echo ""
echo "=== Simulation Results ==="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo "Total: $((PASSED + FAILED)), Passed: $PASSED, Failed: $FAILED"
