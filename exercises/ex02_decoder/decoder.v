`timescale 1ns/1ps

module nec_ir_decoder_40us (
    input wire clk,                     // 系统时钟 (25kHz = 40μs周期)
    input wire rst_n,                   // 异步复位
    input wire ir_input,                // 红外输入信号
    output reg [7:0] address,           // 解码出的地址
    output reg [7:0] command,           // 解码出的命令
    output reg data_valid,              // 数据有效标志
    output reg repeat_flag,             // 重复码标志
    output wire [2:0] state_debug        // 状态机状态调试输出
);

// ===============================
// 状态定义
// ===============================
localparam [2:0] 
    IDLE        = 3'b000,   // 空闲状态
    LEADER_HIGH = 3'b001,   // 检测引导码高电平
    LEADER_LOW  = 3'b010,   // 检测引导码低电平
    RECEIVE_BIT = 3'b011,   // 接收数据位
    DATA_VALID  = 3'b100,   // 数据有效
    REPEAT_CODE = 3'b101,   // 重复码
    ERROR       = 3'b110;   // 错误状态

// ===============================
// 基于40μs时钟的门限值
// ===============================
localparam CNT_0_56_MIN = 10;   // 0.56ms 最小值 (10 * 40μs = 400μs)
localparam CNT_0_56_MAX = 20;   // 0.56ms 最大值 (20 * 40μs = 800μs)
localparam CNT_1_69_MIN = 35;   // 1.69ms 最小值 (35 * 40μs = 1.4ms)
localparam CNT_1_69_MAX = 48;   // 1.69ms 最大值 (48 * 40μs = 1.92ms)
localparam CNT_2_25_MIN = 50;   // 2.25ms 最小值 (50 * 40μs = 2.0ms)
localparam CNT_2_25_MAX = 65;   // 2.25ms 最大值 (65 * 40μs = 2.6ms)
localparam CNT_4_5_MIN  = 80;   // 4.5ms  最小值 (80 * 40μs = 3.2ms)
localparam CNT_4_5_MAX  = 130;  // 4.5ms  最大值 (130 * 40μs = 5.2ms)
localparam CNT_9_MIN    = 160;  // 9ms    最小值 (160 * 40μs = 6.4ms)
localparam CNT_9_MAX    = 250;  // 9ms    最大值 (250 * 40μs = 10ms)

// ===============================
// 内部信号定义
// ===============================
reg [2:0] current_state, next_state;
reg [7:0] timer;                      // 时间计数器 (8位足够，最大250)
reg [5:0] bit_counter;                // 位计数器 (0-31)
reg [31:0] data_shift;                // 数据移位寄存器
reg ir_input_sync;                    // 同步后的红外输入
reg ir_input_prev;                    // 上一个时钟的红外输入
wire ir_rising_edge;                  // 上升沿检测
wire ir_falling_edge;                 // 下降沿检测

// ===============================
// 输入同步和边沿检测
// ===============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ir_input_sync <= 1'b1;
        ir_input_prev <= 1'b1;
    end else begin
        ir_input_prev <= ir_input_sync;
        ir_input_sync <= ir_input;     // 同步输入信号
    end
end

assign ir_rising_edge  = ir_input_sync & ~ir_input_prev;
assign ir_falling_edge = ~ir_input_sync & ir_input_prev;

// ===============================
// 时间计数器 (40μs为单位)
// ===============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer <= 0;
    end else begin
        if (ir_rising_edge || ir_falling_edge) begin
            timer <= 0;  // 边沿到来时清零计数器
        end else begin
            if (timer < 8'hFF)  // 防止溢出
                timer <= timer + 1;
        end
    end
end

// ===============================
// 状态寄存器
// ===============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// ===============================
// 状态转移逻辑 - 修复：明确列出敏感信号
// ===============================
always @(*) begin
    // 默认保持当前状态
    next_state = current_state;
    
    case (current_state)
        IDLE: begin
            if (ir_falling_edge) begin
                next_state = LEADER_HIGH;
            end
        end
        
        LEADER_HIGH: begin
            if (ir_rising_edge) begin
                // 检查引导码高电平时间 (9ms)
                if ((timer >= CNT_9_MIN) && (timer <= CNT_9_MAX)) begin
                    next_state = LEADER_LOW;
                end else begin
                    next_state = ERROR;
                end
            end
        end
        
        LEADER_LOW: begin
            if (ir_falling_edge) begin
                // 检查是正常数据帧还是重复码
                if ((timer >= CNT_4_5_MIN) && (timer <= CNT_4_5_MAX)) begin
                    next_state = RECEIVE_BIT;  // 正常数据帧
                end else if ((timer >= CNT_2_25_MIN) && (timer <= CNT_2_25_MAX)) begin
                    next_state = REPEAT_CODE;  // 重复码
                end else begin
                    next_state = ERROR;
                end
            end
        end
        
        RECEIVE_BIT: begin
            if (bit_counter == 32) begin
                next_state = DATA_VALID;  // 接收完32位数据
            end else if (timer > CNT_1_69_MAX + 5) begin
                next_state = ERROR;       // 超时错误
            end
        end
        
        DATA_VALID: begin
            next_state = IDLE;
        end
        
        REPEAT_CODE: begin
            next_state = IDLE;
        end
        
        ERROR: begin
            // 错误状态等待下一个下降沿重新开始
            if (ir_falling_edge) begin
                next_state = LEADER_HIGH;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

// ===============================
// 数据接收逻辑
// ===============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_counter <= 0;
        data_shift <= 32'b0;
        address <= 8'b0;
        command <= 8'b0;
        data_valid <= 1'b0;
        repeat_flag <= 1'b0;
    end else begin
        // 默认值
        data_valid <= 1'b0;
        repeat_flag <= 1'b0;
        
        case (current_state)
            IDLE: begin
                bit_counter <= 0;
                data_shift <= 32'b0;
            end
            
            RECEIVE_BIT: begin
                if (ir_falling_edge) begin
                    // 检查数据位脉冲时间 (560μs)
                    if ((timer >= CNT_0_56_MIN) && (timer <= CNT_0_56_MAX)) begin
                        // 脉冲时间正确，现在检查间隔时间判断是0还是1
                        if ((timer >= CNT_0_56_MIN) && (timer <= CNT_0_56_MAX)) begin
                            data_shift <= {data_shift[30:0], 1'b0};  // 逻辑0
                        end else if ((timer >= CNT_1_69_MIN) && (timer <= CNT_1_69_MAX)) begin
                            data_shift <= {data_shift[30:0], 1'b1};  // 逻辑1
                        end
                        bit_counter <= bit_counter + 1;
                    end
                end
            end
            
            DATA_VALID: begin
                // 解析32位数据: [地址反码(8位), 地址(8位), 命令反码(8位), 命令(8位)]
                if (data_shift[23:16] == ~data_shift[31:24] && 
                    data_shift[7:0] == ~data_shift[15:8]) begin
                    address <= data_shift[23:16];  // 地址码
                    command <= data_shift[7:0];    // 命令码
                    data_valid <= 1'b1;
                end
            end
            
            REPEAT_CODE: begin
                repeat_flag <= 1'b1;
                // 保持之前的地址和命令不变
                data_valid <= 1'b1;  // 也可以选择不设置data_valid，只设置repeat_flag
            end
        endcase
    end
end

// 调试输出
assign state_debug = current_state;

endmodule