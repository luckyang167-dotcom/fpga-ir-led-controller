#!/bin/bash
# Run all testbenches and report results
# Prerequisite: ModelSim vsim must be in PATH

set -e
cd "$(dirname "$0")/.."

TB_SCRIPTS=(
    "sim/tb_inf_controller.do"
    "sim/tb_led_controller.do"
    "sim/tb_fifo_controller.do"
    "sim/tb_seq_detector.do"
)

PASSED=0
FAILED=0
RESULTS=()

for tb in "${TB_SCRIPTS[@]}"; do
    name=$(basename "$tb" .do)
    echo "=== Running $name ==="
    if vsim -c -do "do $tb" 2>&1 | tee "sim/${name}.log"; then
        echo "  PASS: $name"
        PASSED=$((PASSED + 1))
        RESULTS+=("PASS: $name")
    else
        echo "  FAIL: $name"
        FAILED=$((FAILED + 1))
        RESULTS+=("FAIL: $name")
    fi
    rm -rf work transcript
done

echo ""
echo "=== Simulation Results ==="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo "Total: $((PASSED + FAILED)), Passed: $PASSED, Failed: $FAILED"
