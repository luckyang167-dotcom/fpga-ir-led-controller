# CLAUDE.md — FPGA IR LED Controller

## 项目概述

FPGA 红外遥控 LED 显示控制器。基于 Verilog HDL 的 NEC 协议红外解码 + 4 模式 10 位 LED 显示控制系统，目标器件为 Altera Cyclone V。

## 目录结构

```
rtl/              → 可综合 RTL 源码
  common/         → 公共模块 (counter, edge_detect, glbcnt, pwm)
  infrared/       → inf_controller.v (NEC 解码 5 状态 FSM)
  display/        → led_controller.v (4 模式 LED 控制器)
  fifo/           → fifo_controller.v (异步 FIFO, 16×8)
  seq_detector/   → seq_detector.v ("1011" Moore FSM)
  top/            → top_system.v (顶层集成)
tb/               → 测试平台 (4 个)
sim/              → 仿真脚本 (ModelSim + Icarus Verilog)
fpga/             → Quartus II 工程文件
exercises/        → 独立实验练习
docs/             → 课程设计报告
```

## 关键设计规范

- **FSM**: 双进程（`always @(posedge clk, negedge rst_n)` 时序 + `always @(*)` 组合），独热码 `localparam`
- **复位**: 异步复位，低有效 `rst_n`
- **时钟**: 50MHz 系统时钟，25MHz FIFO 写时钟
- **参数化**: `#(parameter N=...)` 语法

## 模块依赖关系

```
top_system
├── inf_controller
│   ├── counter #(11)    → 50MHz→25kHz 分频
│   ├── edge_detect      → 红外边沿检测
│   └── glbcnt           → 脉宽计数
│       ├── counter #(8)
│       └── edge_detect
├── led_controller
│   ├── counter #(26)    → 刷新率/速度控制
│   └── pwm #(10)        → 8-bit 非线性 PWM
│       └── counter #(8)
└── (internal FSM)       → 键码→参数映射
```

## 红外遥控按键映射

| 键码  | 功能         |
|-------|-------------|
| 0x01  | 模式切换      |
| 0x02  | 速度增加      |
| 0x03  | 亮度减小      |
| 0x04  | 亮度增加      |
| 0x05  | 亮度模式切换   |
| 0x07  | 方向切换      |

## 仿真命令

```bash
# Icarus Verilog
bash sim/run_iverilog.sh
gtkwave *.vcd

# ModelSim
bash sim/run_all.sh
vsim -do sim/tb_controller.do
```

## FPGA 烧录

Quartus II 13.1 打开 `fpga/main/11_28test1.qpf` → Start Compilation → Programmer

## 常见问题

- **QSF 中的 VERILOG_FILE 路径**：`1/` 前缀是 Quartus 自动生成的相对路径映射，指向 `rtl/` 目录下的文件
- **SignalTap II**：工程中已配置，可观察 `i_inf` 触发和 `bright`/`dir` 信号
- **PWM 非线性亮度**：`duty<128` 时 `duty²/64`，`duty≥128` 时 `128+(duty-128)×2`
- **速度非线性映射**：`speed<128` 时 `speed²/32`，`speed≥128` 时 `512+(speed-128)×8`
