# GitHub Upload Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean build artifacts, create README, initialize git repository, and prepare project for GitHub upload.

**Architecture:** Exclude large binary files (videos, build artifacts) via `.gitignore`, keep source code (RTL/TB/FPGA/Exercises) and documentation, write bilingual README documenting the project.

**Tech Stack:** Git, GitHub, Verilog HDL, Icarus Verilog, ModelSim/Questa, Quartus II 13.1

---

## Current State

| Category | Size | Action |
|----------|------|--------|
| rtl/ + tb/ + fpga/ + exercises/ | ~300K | Keep (source code) |
| docs/ 课程报告 (.doc/.pptx) | ~20MB | Keep (documentation) |
| docs/ 视频 (.mp4) | ~285MB | Gitignore (too large for GitHub) |
| reference/ | 1.1GB | Gitignore (teacher's reference, read-only) |
| *.vcd (root) | 618MB | Delete (build artifacts) |
| sim/*.log + sim/*.vvp | 34MB | Delete (build artifacts) |
| fpga/ *.ddb, *.qws | <1MB | Gitignore (Quartus artifacts) |

**Target repo size: < 30MB** (source code + documents only)

---

### Task 1: Clean up build artifacts

**Files:**
- Delete: `fifo_controller.vcd`, `tb_inf_controller.vcd`, `tb_led_controller.vcd`, `seq_detector.vcd` (root directory)
- Delete: `sim/*.log`, `sim/*.vvp`

These are simulation output files already covered by `.gitignore` but need physical cleanup before git init.

- [ ] **Step 1: Delete root VCD files**

Run:
```bash
cd "/run/media/luckyang/NTFS-785G/11.7 eda"
rm -f *.vcd
```

- [ ] **Step 2: Delete sim/ build artifacts**

Run:
```bash
rm -f sim/*.log sim/*.vvp
```

- [ ] **Step 3: Verify cleanup**

Run:
```bash
du -sh . && ls *.vcd 2>/dev/null || echo "No VCD files in root"
```
Expected: No VCD files, total size significantly reduced.

---

### Task 2: Update .gitignore

**Files:**
- Modify: `.gitignore`

The current `.gitignore` covers basic artifacts but needs additions for video files, reference directory, and simulation logs.

- [ ] **Step 1: Update .gitignore**

Replace the current `.gitignore` content with:

```gitignore
# ModelSim / Questa simulation artifacts
work/
*.wlf
*.vcd
*.vvp
*.v.out
_transcript
*.log

# Quartus II build artifacts
db/
incremental_db/
output_files/
hc_output/
*.qws
*.ddb
*.stp
*.ipinfo
c5_pin_model_dump.txt

# Icarus Verilog artifacts
*.vvp

# OS files
.DS_Store
Thumbs.db

# Large binary files (excluded from git)
*.mp4
*.zip
*.rar

# Reference code (read-only, teacher's materials)
reference/

# Editor / IDE
*.code-workspace
```

---

### Task 3: Create README.md

**Files:**
- Create: `README.md`

Bilingual (CN/EN) README documenting project overview, architecture, tools, and simulation workflow.

- [ ] **Step 1: Create README.md**

```markdown
# EDA Course Design — Infrared Decoding & LED Display System

> 电子设计自动化(EDA)课程设计 — 红外遥控解码与LED显示系统

基于 Verilog HDL 的红外遥控(NEC协议)解码与LED显示控制系统，目标平台为 Altera FPGA。

## 项目概述

本系统通过红外接收头采集遥控器信号，经 NEC 协议解码后提取按键码，由顶层状态机映射为 LED 控制器的模式/速度/亮度/方向参数，驱动10位LED实现多种显示效果。

### 功能特性

- **NEC红外协议解码**：5状态FSM，支持9ms引导码检测、32位数据接收、重复码识别
- **4种LED显示模式**：空闲(idle)、闪烁(flash)、移动(move)、计数(count)
- **4种自动亮度模式**：固定亮度、呼吸灯、渐变、闪烁
- **非线性亮度曲线**：PWM增强对比度，低亮度平方关系，高亮度线性
- **跨时钟域FIFO**：写时钟25MHz / 读时钟50MHz，深度16×8bit，水位线12/2
- **序列检测器**：Moore FSM检测"1011"序列（支持重叠和非重叠模式）

## 系统架构

```
top_system (rtl/top/top_system.v)
├── inf_controller (rtl/infrared/inf_controller.v)
│   ├── counter #(.N(11))     → 50MHz → 25kHz 时钟分频
│   ├── edge_detect           → 红外信号边沿检测
│   └── glbcnt                → 脉宽计时器
│       ├── counter
│       └── edge_detect
├── led_controller (rtl/display/led_controller.v)
│   ├── counter #(.N(26))     → 刷新率控制
│   └── pwm                   → 亮度控制(8位占空比, 非线性曲线)
│       └── counter #(.N(8))
└── top_system FSM            → 红外键码 → mode/speed/brightness/dir 映射
```

## 项目结构

```
├── rtl/                    # 可综合RTL源码
│   ├── common/             # 公共基础模块 (counter, edge_detect, pwm, glbcnt)
│   ├── infrared/           # 红外协议解码
│   ├── display/            # LED控制和PWM
│   ├── fifo/               # 跨时钟域FIFO
│   ├── seq_detector/       # 序列检测FSM
│   └── top/                # 顶层系统集成
├── tb/                     # 独立测试平台
├── fpga/                   # Quartus II FPGA工程
│   ├── main/               # 主课程设计工程
│   └── test1/              # 早期测试工程
├── sim/                    # 仿真脚本
│   ├── compile.do          # ModelSim全量编译
│   ├── run_all.sh          # ModelSim一键仿真
│   ├── run_iverilog.sh     # Icarus Verilog一键仿真
│   └── modelsim/           # ModelSim项目文件(参考)
├── exercises/              # 独立实验练习 (ex01-ex05)
├── docs/                   # 课程设计报告与演示文档
└── CLAUDE.md               # AI辅助开发指南
```

## 工具与流程

### FPGA综合
- **Quartus II 13.1 (64-bit)**
- 打开 `fpga/main/11_28test1.qpf`

### 仿真 (ModelSim/Questa — Windows)
```bash
bash sim/run_all.sh              # 运行全部4个测试平台
vsim -do sim/tb_inf_controller.do  # 运行单个测试平台
```

### 仿真 (Icarus Verilog — Linux)
```bash
# 安装
sudo apt install iverilog gtkwave

# 运行全部仿真
bash sim/run_iverilog.sh

# 查看波形
gtkwave *.vcd
```

## 设计模式

- **FSM**: 双进程风格 — 时序逻辑 `always @(posedge clk or negedge rst_n)` 用于状态寄存器 + 组合逻辑 `always @(*)` 用于次态逻辑
- **状态编码**: 独热码(one-hot)，通过 `localparam` 定义
- **时钟域**: FIFO处理25MHz(写) ↔ 50MHz(读)跨域，其余模块单时钟50MHz
- **复位**: 异步复位，低有效(`rst_n`)，全模块统一
- **参数化**: `#(parameter N=default)` 语法实现位宽参数化

## 测试平台

| 测试平台 | 被测模块 | 状态 |
|---------|---------|------|
| `tb_inf_controller.v` | 红外控制器 | ✓ PASS |
| `tb_led_controller.v` | LED控制器 | ✓ PASS |
| `tb_fifo_controller.v` | FIFO控制器 | ✓ PASS |
| `tb_seq_detector.v` | 序列检测器 | ✓ PASS |

## 贡献者

- 杨烙奇 (03230924)
- 张泽睿 (03230918)

## 许可

本项目为课程设计作品，仅供学习参考。
```

---

### Task 4: Initialize git repository

**Files:**
- Create: `.git/` (via git init)

Not currently a git repo. Initialize and configure.

- [ ] **Step 1: Initialize git repo**

```bash
cd "/run/media/luckyang/NTFS-785G/11.7 eda"
git init
```

- [ ] **Step 2: Verify .gitignore is working**

```bash
git status
```

Expected: Only source files shown, no VCD/VVP/log/mp4/reference files.

- [ ] **Step 3: Verify total tracked size is reasonable**

```bash
git add --dry-run . 2>/dev/null | xargs du -ch 2>/dev/null | tail -1
```

Expected: < 30MB total.

---

### Task 5: Create initial commit

- [ ] **Step 1: Stage all files**

```bash
cd "/run/media/luckyang/NTFS-785G/11.7 eda"
git add .
```

- [ ] **Step 2: Create commit**

```bash
git commit -m "$(cat <<'EOF'
Initial commit: EDA course design project

Infrared remote control decoding and LED display system in Verilog HDL.
- NEC IR protocol decoder with 5-state FSM
- LED controller with 4 display modes and auto-brightness
- Cross-clock FIFO (25MHz/50MHz) with watermark control
- Moore FSM sequence detector ("1011" pattern)
- Simulation scripts for ModelSim and Icarus Verilog
- All 4 testbenches verified: PASS
EOF
)"
```

- [ ] **Step 3: Verify commit**

```bash
git log --oneline
```

---

### Task 6: GitHub remote setup guide

**Files:**
- Modify: `CLAUDE.md` (add GitHub remote info section)

This task documents the steps for pushing to GitHub. The actual push requires the user's GitHub credentials and repo name.

- [ ] **Step 1: Add GitHub instructions to CLAUDE.md**

Add to end of CLAUDE.md:

```markdown
## GitHub

**Push to GitHub:**
```bash
# 1. Create a new empty repo on GitHub (do NOT initialize with README/.gitignore)
# 2. Add remote and push:
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git branch -M main
git push -u origin main
```
```

- [ ] **Step 2: Display push instructions to user**

At completion, present the user with the exact commands needed to push, asking for their GitHub username and desired repo name.

---

### Task 7: Final cleanup verification

- [ ] **Step 1: Check for any files that should not be committed**

```bash
cd "/run/media/luckyang/NTFS-785G/11.7 eda"
git status
```

Expected: Clean working tree after commit, or only untracked files that are properly gitignored.

- [ ] **Step 2: Check file sizes in the commit**

```bash
git ls-tree -r -l HEAD | awk '{print $4, $5}' | sort -k2 -rn | head -15
```

Expected: No files over ~50MB.
