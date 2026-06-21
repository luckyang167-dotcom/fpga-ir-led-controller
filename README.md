# FPGA 红外遥控 LED 显示控制器

**FPGA Infrared Remote Control LED Display Controller** — 基于 Verilog HDL 的红外遥控（NEC 协议）解码与 LED 显示控制系统，目标平台为 Altera Cyclone V FPGA。

---

## 📖 项目简介

本项目实现了一个完整的红外遥控 LED 显示控制系统，通过红外接收头采集遥控器信号，经 NEC 协议解码后提取按键码，由顶层状态机映射为 LED 控制器的模式/速度/亮度/方向参数，驱动 10 位 LED 实现多种显示效果。项目作为 EDA 技术课程设计作品，采用可综合的 Verilog HDL 编写，通过 Quartus II 13.1 综合布线和 ModelSim / Icarus Verilog 仿真验证。

## ✨ 功能特性

- **NEC 红外协议解码** — 5 状态 FSM（独热码），支持 9ms 引导码检测、32 位数据接收（地址+反码+命令+反码）、重复码识别
- **4 种 LED 显示模式** — 空闲（idle）| 闪烁（flash）| 移动（move/流水灯）| 计数（count）
- **4 种自动亮度模式** — 固定亮度 | 呼吸灯 | 渐变 | 闪烁（由红外遥控切换）
- **非线性 PWM 亮度曲线** — 低亮度平方关系，高亮度线性斜率加倍，增强视觉对比度
- **速度非线性映射** — 低速区平方关系，高速区线性快速调节，动态范围更大
- **跨时钟域 FIFO** — 写时钟 25MHz / 读时钟 50MHz，深度 16×8bit，水位线 12/2
- **序列检测器** — Moore FSM 检测 "1011" 序列，支持重叠与非重叠模式
- **参数化可重用模块** — counter、edge_detect、pwm、glbcnt 均通过 `#(parameter N=...)` 参数化

## 📋 按键映射

| 遥控器按键 | 功能             | 说明                     |
|-----------|------------------|--------------------------|
| 1         | 模式切换         | idle → flash → move → count |
| 2         | 速度增加         | 每次 +5，范围 0~255        |
| 3         | 亮度减小         | 每次 -10                  |
| 4         | 亮度增加         | 每次 +10                  |
| 5         | 亮度模式切换     | 固定 → 呼吸 → 渐变 → 闪烁   |
| UP (0x07) | 方向切换         | 移动方向翻转               |

## 🔧 硬件框图

```mermaid
graph TB
    subgraph "红外接收 (IR Receiver)"
        IR[(红外接收头)] -->|i_inf| INF
    end

    subgraph "Top System (top_system)"
        INF[inf_controller<br/>NEC解码FSM] -->|32-bit data| TOP[top_system FSM<br/>键码→参数映射]
        
        subgraph "LED Controller (led_controller)"
            LCTL[状态机<br/>mode/speed/dir] --> PWM
            PWM[pwm 非线性] --> LED
        end
        
        TOP -->|mode| LCTL
        TOP -->|speed| LCTL
        TOP -->|dir| LCTL
        TOP -->|auto_bright| PWM
    end

    subgraph "公共模块 (common)"
        CNT[counter N-bit<br/>参量化]
        ED[edge_detect<br/>边沿检测]
        GCNT[glbcnt<br/>脉宽计数器]
    end

    CNT --> INF
    ED --> INF
    GCNT --> INF
    CNT --> LCTL
    CNT --> PWM

    subgraph "FIFO (跨时钟域)"
        FIFO[fifo_controller<br/>16x8 异步FIFO]
    end

    subgraph "序列检测器"
        SEQ[seq_detector<br/>1011 Moore FSM]
    end

    LED[10 LED 输出] -->|led[9:0]| OUT
```

## 📌 引脚定义

| 信号名       | FPGA 引脚    | 方向     | 说明                     |
|------------|-------------|---------|--------------------------|
| `clk`      | PIN_AF14    | 输入     | 50MHz 系统时钟            |
| `rst_n`    | PIN_AJ4     | 输入     | 异步复位，低电平有效        |
| `i_inf`    | PIN_W20     | 输入     | 红外接收头信号输入          |
| `led[9:0]` | —（约束分配）| 输出     | 10 位 LED 指示灯           |

**目标器件**: Altera Cyclone V **5CSXFC6D6F31C6** (896 引脚 FBGA)

## 📁 项目结构

```
fpga-ir-led-controller/
├── rtl/                          # 可综合 RTL 源码
│   ├── common/                   # 公共基础模块
│   │   ├── counter.v             #    参数化 N-bit 计数器
│   │   ├── edge_detect.v         #    边沿检测（上升/下降/双边沿）
│   │   ├── glbcnt.v              #    全局脉宽计数器
│   │   └── pwm.v                 #    8 位 PWM（非线性亮度曲线）
│   ├── infrared/                 # 红外协议解码
│   │   └── inf_controller.v      #    NEC 协议解码 FSM
│   ├── display/                  # LED 显示控制
│   │   └── led_controller.v      #    4 模式 LED 控制器
│   ├── fifo/                     # 跨时钟域 FIFO
│   │   └── fifo_controller.v     #    异步 FIFO（25MHz→50MHz）
│   ├── seq_detector/             # 序列检测器
│   │   └── seq_detector.v        #    "1011" Moore FSM
│   └── top/                      # 顶层系统集成
│       └── top_system.v          #    顶层模块
├── tb/                           # 测试平台
│   ├── tb_inf_controller.v       #    红外解码仿真
│   ├── tb_led_controller.v       #    LED 控制仿真
│   ├── tb_fifo_controller.v      #    FIFO 仿真
│   └── tb_seq_detector.v         #    序列检测仿真
├── sim/                          # 仿真脚本与项目
│   ├── compile.do                #    ModelSim 全量编译脚本
│   ├── run_all.sh                #    ModelSim 一键仿真
│   ├── run_iverilog.sh           #    Icarus Verilog 一键仿真
│   └── modelsim/                 #    ModelSim 项目文件（参考）
├── fpga/                         # Quartus II 工程
│   ├── main/                     #    主课程设计工程
│   │   ├── 11_28test1.qpf        #        工程文件
│   │   └── 11_28test1.qsf        #        设置文件（含引脚分配）
│   └── test1/                    #    早期测试工程
├── exercises/                    # 独立实验练习
│   ├── ex01_counter/             #    计数器练习
│   ├── ex02_decoder/             #    解码器练习
│   ├── ex03_edge_detector/       #    边沿检测练习
│   ├── ex04_glbcnt/              #    脉宽计数练习
│   └── ex05_edge_detect2/        #    边沿检测进阶
├── docs/                         # 课程设计报告
├── README.md                     # 项目说明文档（本文件）
└── CLAUDE.md                     # AI 辅助开发指南
```

## 🔨 构建与烧录

### FPGA 综合（Quartus II 13.1）

1. 打开 Quartus II 13.1（64-bit）
2. 选择 **File → Open Project** → `fpga/main/11_28test1.qpf`
3. 点击 **Processing → Start Compilation**（或 Ctrl+L）
4. 编译完成后，连接 FPGA 开发板（DE1-SoC 或类似 Cyclone V 板）
5. 点击 **Tools → Programmer**，选择 `.sof` 文件并烧录

### 仿真验证

#### Icarus Verilog（Linux 推荐）

```bash
# 安装
sudo apt install iverilog gtkwave

# 运行全部仿真
cd sim
bash run_iverilog.sh

# 查看波形
gtkwave *.vcd
```

#### ModelSim / Questa（Windows）

```bash
# 运行全部 4 个测试平台
bash sim/run_all.sh

# 运行单个测试平台
vsim -do sim/tb_inf_controller.do
vsim -do sim/tb_led_controller.do
vsim -do sim/tb_fifo_controller.do
vsim -do sim/tb_seq_detector.do
```

## 🎮 Demo 效果说明

1. **上电初始**：所有 LED 熄灭（idle 模式），亮度固定为中等
2. **按下遥控器 1**：LED 模式循环切换（idle → flash → move → count）
3. **按下遥控器 2**：速度递增（流水灯/闪烁/计数速度加快）
4. **按下遥控器 3/4**：亮度递减/递增（PWM 占空比变化）
5. **按下遥控器 5**：亮度模式循环（固定 → 呼吸灯 → 渐变 → 闪烁）
6. **按下 UP 键**：流水灯方向翻转

## 🧪 仿真结果

| 测试平台                     | 被测模块           | 测试结果 |
|-----------------------------|-------------------|---------|
| `tb_inf_controller.v`       | 红外解码控制器      | ✅ PASS |
| `tb_led_controller.v`       | LED 显示控制器      | ✅ PASS |
| `tb_fifo_controller.v`      | 异步 FIFO 控制器    | ✅ PASS |
| `tb_seq_detector.v`         | 序列检测器          | ✅ PASS |

## 🛠 技术栈

| 组件             | 工具/版本                    |
|-----------------|-----------------------------|
| HDL 语言         | Verilog HDL (IEEE 1364-2001) |
| FPGA 器件        | Altera Cyclone V 5CSXFC6D6F31C6 |
| 综合工具         | Quartus II 13.1 (64-bit)     |
| 仿真工具         | ModelSim-Altera / Icarus Verilog |
| 调试工具         | Quartus II SignalTap II      |

## 📝 设计规范

- **FSM 风格**：双进程（时序+组合），独热码状态编码
- **复位**：异步复位，低电平有效（`rst_n`），全模块统一
- **时钟域**：FIFO 处理跨时钟域（25MHz ↔ 50MHz），其余单时钟 50MHz
- **参数化**：`#(parameter N=default)` 实现位宽和周期参数化

## 📄 许可

本项目为 EDA 技术课程设计作业，仅供学习参考。
