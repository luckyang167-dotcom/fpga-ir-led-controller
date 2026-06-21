# Simulation Environment Setup Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a clean, reproducible simulation flow for all 4 testbenches, fix RTL bugs that block simulation, and remove duplicate inline module definitions from testbenches.

**Architecture:** Each testbench compiles against canonical RTL in `rtl/` rather than carrying inline copies of dependency modules. A shared `sim/compile.do` Tcl script compiles all RTL once; per-testbench `.do` scripts compile the TB and run the simulation. This eliminates simulation-synthesis mismatch from divergent inline modules.

**Tech Stack:** ModelSim/Questa (Tcl-based), Verilog HDL, Quartus II 13.1

---

## Current Problems Found During Analysis

1. **tb_inf_controller.v** (lines 180-279): Carries inline copies of `counter`, `edge_detect`, `glbcnt` that differ from RTL versions — these would conflict when co-compiled with RTL and mask RTL bugs
2. **tb_led_controller.v** (lines 1-71): Carries inline copies of `counter`, `pwm` — same conflict issue
3. **rtl/common/glbcnt.v**: Instantiates `counter` with `.period()` unconnected — causes undefined/X behavior in simulation
4. **EDA tools not in PATH**: No ModelSim/Questa installation detected on this Linux system — tools are likely on Windows (NTFS partition is shared)

---

### Task 1: Fix RTL glbcnt period bug

**Files:**
- Modify: `rtl/common/glbcnt.v`

**Problem:** `counter` instantiation inside glbcnt has `.period()` unconnected (empty port). The counter uses `period` in `if (q_reg >= period - 1)` — unconnected input is Z, causing undefined behavior. glbcnt is used by inf_controller for pulse-width timing measurement, so it must free-run correctly.

**Fix:** glbcnt is a free-running counter (cleared only by edge events via `sclr`). Wire `period` to all-1s so the counter wraps naturally at its bit width rather than being reset by period comparison.

- [ ] **Step 1: Fix glbcnt counter instantiation**

Change the counter instantiation in `rtl/common/glbcnt.v` from:
```verilog
counter counter_glb(
    .clk      (clk    ),
    .rst_n    (rst_n  ),
    .en       (en     ),
    .sclr     (all_edg),
    .period   ( ),
    .q        (q)
);
```
To:
```verilog
counter #(.N(N)) counter_glb(
    .clk      (clk    ),
    .rst_n    (rst_n  ),
    .en       (en     ),
    .sclr     (all_edg),
    .period   ({N{1'b1}}),   // max value: free-run, wrap by bit overflow
    .q        (q),
    .tick     ()
);
```

Also add the `tick` port (unused) to match the counter module interface.

- [ ] **Step 2: Verify glbcnt fix doesn't break compilation**

Run: `grep -r "glbcnt" rtl/` to confirm all instantiations have matching ports.

Expected: `inf_controller.v` instantiates glbcnt with ports `.clk, .rst_n, .i_inf, .en, .sclr, .q` which matches the module definition.

---

### Task 2: Clean tb_inf_controller.v — remove inline dependency modules

**Files:**
- Modify: `tb/tb_inf_controller.v`

**Problem:** Lines 180-279 define simulation-only copies of `counter`, `edge_detect`, `glbcnt` that differ from RTL. When RTL is compiled first, these redefinitions cause elaboration errors. The TB should compile dependencies from `rtl/common/` instead.

- [ ] **Step 1: Remove inline module definitions**

Delete lines 180-279 from `tb/tb_inf_controller.v` (everything from `// ==================== 补充依赖模块的仿真实现 ====================` to end of file).

- [ ] **Step 2: Verify the remaining TB is self-contained**

Run: `grep "^module " tb/tb_inf_controller.v`
Expected: Only `module tb_inf_controller();` — single module definition.

- [ ] **Step 3: Check DUT instantiation port match**

The TB instantiates `inf_controller` as:
```verilog
inf_controller u_inf_controller(
    .clk(clk), .rst_n(rst_n), .i_inf(i_inf),
    .data(data), .inf_vld(inf_vld)
);
```
Run: `grep "^module inf_controller" rtl/infrared/inf_controller.v`
Expected: Ports match — `clk, rst_n, i_inf, data, inf_vld`

---

### Task 3: Clean tb_led_controller.v — remove inline dependency modules

**Files:**
- Modify: `tb/tb_led_controller.v`

**Problem:** Lines 1-71 define inline `counter` (N=26) and `pwm` modules. These conflict with RTL versions in `rtl/common/`.

- [ ] **Step 1: Remove inline module definitions**

Delete lines 1-71 from `tb/tb_led_controller.v` (everything from `// ------------------------------` before `// 被测模块依赖的counter子模块` through the `endmodule` of `pwm`).

The file should start directly with:
```verilog
`timescale 1ns/1ps

// ------------------------------
// LED控制器Testbench主模块
// ------------------------------
module tb_led_controller;
```

- [ ] **Step 2: Verify the remaining TB**

Run: `grep "^module " tb/tb_led_controller.v`
Expected: Only `module tb_led_controller;`

- [ ] **Step 3: Check DUT instantiation port match**

The TB instantiates `led_controller` as:
```verilog
led_controller u_led_controller(
    .clk(clk), .rst_n(rst_n), .mode(mode), .dir(dir),
    .speed(speed), .bright(bright), .led(led)
);
```
Run: `grep "^module led_controller" rtl/display/led_controller.v`
Expected: Ports match.

---

### Task 4: Verify clean testbenches — tb_fifo and tb_seq_detector

**Files:**
- Read: `tb/tb_fifo_controller.v`
- Read: `tb/tb_seq_detector.v`

These two testbenches are already clean (no inline dependency modules). Verify DUT port compatibility.

- [ ] **Step 1: Verify tb_fifo_controller DUT ports**

Run: `grep "fifo_controller uut" tb/tb_fifo_controller.v`
Run: `grep "^module fifo_controller" rtl/fifo/fifo_controller.v`
Expected: Ports match `(wclk, rclk, rst_n, wr_en, rd_en, data_in, data_out, full, empty, almost_full, almost_empty)`

- [ ] **Step 2: Verify tb_seq_detector DUT ports**

Run: `grep "seq_detector uut" tb/tb_seq_detector.v`
Run: `grep "^module seq_detector" rtl/seq_detector/seq_detector.v`
Expected: Ports match `(clk, rst_n, data_in, o_sq1, o_sq2)`

---

### Task 5: Create ModelSim compile script (sim/compile.do)

**Files:**
- Create: `sim/compile.do`

This Tcl script compiles all RTL modules bottom-up (common first, then dependents). ModelSim resolves dependencies by compile order within a work library.

- [ ] **Step 1: Create sim/compile.do**

```tcl
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
```

---

### Task 6: Create per-testbench simulation scripts

**Files:**
- Create: `sim/tb_inf_controller.do`
- Create: `sim/tb_led_controller.do`
- Create: `sim/tb_fifo_controller.do`
- Create: `sim/tb_seq_detector.do`

Each script: compiles RTL, compiles the TB, runs simulation with VCD dump, prints results.

- [ ] **Step 1: Create sim/tb_inf_controller.do**

```tcl
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
```

- [ ] **Step 2: Create sim/tb_led_controller.do**

```tcl
# Compile RTL dependencies
if {![file exists work]} { vlib work }
vlog -work work rtl/common/counter.v
vlog -work work rtl/common/pwm.v
vlog -work work rtl/display/led_controller.v

# Compile testbench
vlog -work work tb/tb_led_controller.v

# Run simulation
vsim -c work.tb_led_controller -do "run -all; quit"
```

- [ ] **Step 3: Create sim/tb_fifo_controller.do**

```tcl
# Compile RTL
if {![file exists work]} { vlib work }
vlog -work work rtl/fifo/fifo_controller.v

# Compile testbench
vlog -work work tb/tb_fifo_controller.v

# Run simulation
vsim -c work.fifo_controller_tb -do "run -all; quit"
```

- [ ] **Step 4: Create sim/tb_seq_detector.do**

```tcl
# Compile RTL
if {![file exists work]} { vlib work }
vlog -work work rtl/seq_detector/seq_detector.v

# Compile testbench
vlog -work work tb/tb_seq_detector.v

# Run simulation
vsim -c work.seq_detector_tb -do "run -all; quit"
```

---

### Task 7: Create top-level simulation runner

**Files:**
- Create: `sim/run_all.sh`

A shell script that runs all 4 simulations sequentially and reports pass/fail.

- [ ] **Step 1: Create sim/run_all.sh**

```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x sim/run_all.sh`

---

### Task 8: Update ModelSim project files for new paths

**Files:**
- Modify: `sim/modelsim/*.mpf`

The old `.mpf` files reference paths like `../1 (2)/1/counter.v`. These need path updates or can be replaced by the new `.do` scripts.

**Decision:** The `.do` scripts (Tasks 5-6) are the primary simulation interface. The old `.mpf` files are preserved for reference but are secondary. Add a note in CLAUDE.md about this.

- [ ] **Step 1: Document the simulation workflow in CLAUDE.md**

Add a "Simulation" section to CLAUDE.md documenting:
- Prerequisites: ModelSim/Questa in PATH
- Single testbench: `vsim -do sim/tb_<name>.do`
- All testbenches: `bash sim/run_all.sh`
- Old .mpf files in `sim/modelsim/` are reference-only, paths need manual update if used with GUI

---

### Task 9: Fix the testbench file for exercise ex03 (edge_detector has inline TB)

**Files:**
- Read: `exercises/ex03_edge_detector/edge_detector.v`
- Create: `exercises/ex03_edge_detector/tb_edge_detector.v`

The exercise file `edge_detector.v` contains both DUT and inline `tb_inf` testbench module (like the old project structure). Split them for consistency.

- [ ] **Step 1: Extract DUT module to clean file**

The `edge_detector` module (lines 3-33 of the original) is the DUT. The `tb_inf` module (lines 36-96) is the testbench. Create a clean separate TB:

```verilog
`timescale 1ns/1ps

module tb_edge_detector();
    reg clk, rst_n, i_inf;
    wire poa_edg, neg_edg, all_edg;

    localparam PERIOD_CLK = 20;

    edge_detector uut (
        .clk(clk), .rst_n(rst_n), .i_inf(i_inf),
        .poa_edg(poa_edg), .neg_edg(neg_edg), .all_edg(all_edg)
    );

    initial begin
        clk = 0;
        forever #(PERIOD_CLK/2) clk = ~clk;
    end

    initial begin
        rst_n = 0; i_inf = 1; #100;
        rst_n = 1; #100;
        repeat(1000) begin
            @(negedge clk);
            i_inf = ($random) % 2;
        end
        #1000;
        $finish;
    end

    initial begin
        $monitor("Time = %0t, i_inf = %b, poa_edg = %b, neg_edg = %b, all_edg = %b",
                 $time, i_inf, poa_edg, neg_edg, all_edg);
        $dumpfile("tb_edge_detector.vcd");
        $dumpvars(0, tb_edge_detector);
    end
endmodule
```

But wait — the exercise `edge_detector.v` module uses port names `poa_edg, neg_edg, all_edg` which differs from the `rtl/common/edge_detect.v` which uses `pos_edg, neg_edg, all_edg`. Keep the exercise version as-is since it's a standalone exercise.

This task is optional — exercises are standalone and don't need the same treatment as the main project testbenches.

---

### Task 10: Final verification — check all file consistency

**Files:**
- All RTL and TB files

- [ ] **Step 1: Verify no module name conflicts across RTL and TB**

Run: `grep -h "^module " rtl/**/*.v tb/*.v | sort | uniq -c | sort -rn`
Expected: Each module name appears exactly once (no duplicates across RTL and TB).

- [ ] **Step 2: Check all VCD dump filenames are consistent**

Run: `grep -h '\$dumpfile' tb/*.v`
Expected: Each TB has a unique .vcd filename.

- [ ] **Step 3: Verify compile order — no missing dependencies**

Run: `grep -h "counter\|edge_detect\|pwm\|glbcnt\|inf_controller\|led_controller\|fifo_controller\|seq_detector" rtl/**/*.v | grep -v "^module\|^//\|input\|output\|wire\|reg" | grep "[a-z]_[a-z]" `

Expected: All instantiations reference modules that exist in `rtl/`.

---

## Simulation Quick Reference (add to CLAUDE.md)

```markdown
## Simulation

**Prerequisites:** ModelSim/Questa (`vsim`, `vlib`, `vlog`) in PATH. On this NTFS system, tools are typically on the Windows side.

**Run a single testbench:**
```bash
vsim -do sim/tb_inf_controller.do     # IR controller
vsim -do sim/tb_led_controller.do     # LED controller
vsim -do sim/tb_fifo_controller.do    # FIFO controller
vsim -do sim/tb_seq_detector.do       # Sequence detector
```

**Run all testbenches:**
```bash
bash sim/run_all.sh
```

**Compile order** (when running manually in ModelSim GUI):
1. `rtl/common/counter.v` → `edge_detect.v` → `pwm.v` → `glbcnt.v`
2. `rtl/infrared/inf_controller.v`, `rtl/display/led_controller.v`, `rtl/fifo/fifo_controller.v`, `rtl/seq_detector/seq_detector.v`
3. `rtl/top/top_system.v`
4. Then compile and run the testbench `.v` file.
```
