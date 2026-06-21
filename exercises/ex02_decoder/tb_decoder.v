`timescale 1ns/1ps
`include "decoder.v"

module tb_nec_decoder_40us();
    // 测试参数
    parameter CLK_PERIOD = 40000;  // 40μs周期 (25kHz)
    
    // 测试信号
    reg clk;
    reg rst_n;
    reg ir_input;
    wire [7:0] address;
    wire [7:0] command;
    wire data_valid;
    wire repeat_flag;
    wire [2:0] state_debug;
    
    // 用于时间显示的中间信号
    integer current_time_us;
    
    // 实例化被测试模块
    nec_ir_decoder_40us uut (
        .clk(clk),
        .rst_n(rst_n),
        .ir_input(ir_input),
        .address(address),
        .command(command),
        .data_valid(data_valid),
        .repeat_flag(repeat_flag),
        .state_debug(state_debug)
    );
    
    // 时钟生成 (25kHz = 40μs周期)
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 更新时间显示
    always @(posedge clk) begin
        current_time_us <= $time / 1000;
    end
    
    // 测试任务：发送一个NEC数据位
    task send_bit;
        input bit_value;
        begin
            // 发送560μs脉冲 (14个时钟周期)
            ir_input = 1'b1;
            #(CLK_PERIOD * 14);
            ir_input = 1'b0;
            
            if (bit_value) begin
                // 逻辑1: 1.69ms空间 (42个时钟周期)
                #(CLK_PERIOD * 42);
            end else begin
                // 逻辑0: 560μs空间 (14个时钟周期)
                #(CLK_PERIOD * 14);
            end
        end
    endtask
    
    // 测试任务：发送引导码
    task send_leader;
        begin
            // 发送9ms脉冲 (225个时钟周期)
            ir_input = 1'b1;
            #(CLK_PERIOD * 225);
            // 发送4.5ms空间 (112个时钟周期)
            ir_input = 1'b0;
            #(CLK_PERIOD * 112);
        end
    endtask
    
    // 主测试序列
    initial begin
        // 生成VCD文件
        $dumpfile("nec_decoder_40us.vcd");
        $dumpvars(0, tb_nec_decoder_40us);
        
        // 初始化
        initialize();
        
        // 测试1: 正常数据帧解码
        $display("=== 测试1: 正常数据帧解码 ===");
        test_normal_frame();
        
        // 结束测试
        #1000000;
        $display("=== 所有测试完成 ===");
        $finish;
    end
    
    // 初始化任务
    task initialize;
        begin
            clk = 0;
            rst_n = 0;
            ir_input = 1'b1;  // 空闲时为高电平
            #(CLK_PERIOD * 10);
            rst_n = 1;
            #(CLK_PERIOD * 10);
        end
    endtask
    
    // 测试正常数据帧
    task test_normal_frame;
        begin
            // 发送引导码
            send_leader();
            
            // 发送32位数据: 地址=0x12, 命令=0x34
            // 地址: 0x12, 地址反码: 0xED
            // 命令: 0x34, 命令反码: 0xCB
            send_bit(0); send_bit(0); send_bit(0); send_bit(1); send_bit(0); send_bit(0); send_bit(1); send_bit(0); // 0x12
            send_bit(1); send_bit(1); send_bit(1); send_bit(0); send_bit(1); send_bit(1); send_bit(0); send_bit(1); // 0xED
            send_bit(0); send_bit(0); send_bit(1); send_bit(1); send_bit(0); send_bit(1); send_bit(0); send_bit(0); // 0x34
            send_bit(1); send_bit(1); send_bit(0); send_bit(0); send_bit(1); send_bit(0); send_bit(1); send_bit(1); // 0xCB
            
            // 等待解码完成
            wait(data_valid == 1'b1);
            #(CLK_PERIOD * 10);
            
            if (address == 8'h12 && command == 8'h34)
                $display("✓ 正常数据帧解码成功: address=0x%h, command=0x%h", address, command);
            else
                $display("✗ 正常数据帧解码失败: address=0x%h, command=0x%h", address, command);
        end
    endtask
    
    // 简化的监视器 - 避免复杂表达式
    initial begin
        forever begin
            #(CLK_PERIOD * 10); // 每400us检查一次
            $display("Time: %0d us, State: %d, IR: %b, Valid: %b, Repeat: %b, Addr: 0x%h, Cmd: 0x%h", 
                     current_time_us, state_debug, ir_input, data_valid, repeat_flag, address, command);
        end
    end

endmodule