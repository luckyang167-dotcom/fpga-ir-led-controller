`timescale 1ns/1ps
`include "counter.v"

module tb_counter();
    // 测试参数
    parameter N = 8;
    parameter CLK_PERIOD = 10;  // 100MHz时钟
    
    // 测试信号
    reg clk;
    reg rst_n;
    reg en;
    reg sclr;
    reg [N-1:0] period;
    wire [N-1:0] q;
    
    // 实例化被测试模块
    counter #(.N(N)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .sclr(sclr),
        .period(period),
        .q(q)
    );
    
    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 测试序列
    initial begin
        // 初始化信号
        initialize();
        
        // 测试1: 异步复位功能
        $display("=== 测试1: 异步复位功能 ===");
        test_reset();
        
        // 测试2: 正常计数功能
        $display("=== 测试2: 正常计数功能 ===");
        test_normal_counting();
        
        // 测试3: 同步清零功能
        $display("=== 测试3: 同步清零功能 ===");
        test_sync_clear();
        
        // 测试4: 使能控制功能
        $display("=== 测试4: 使能控制功能 ===");
        test_enable_control();
        
        // 测试5: 不同周期值测试
        $display("=== 测试5: 不同周期值测试 ===");
        test_different_periods();
        
        // 结束测试
        #100;
        $display("=== 所有测试完成 ===");
        $finish;
    end
    
    // 初始化任务
    task initialize;
        begin
            clk = 0;
            rst_n = 1;
            en = 0;
            sclr = 0;
            period = 8'd10;  // 默认周期为10
            #100;
            rst_n = 0;  // 施加复位
            #100;
            rst_n = 1;  // 释放复位
            #100;
        end
    endtask
    
    // 测试1: 异步复位功能
    task test_reset;
        begin
            $display("时间: %0t, 测试异步复位", $time);
            
            // 先让计数器计数几个周期
            en = 1;
            #(CLK_PERIOD * 3);
            
            // 施加异步复位
            rst_n = 0;
            #10;
            if (q === 0)
                $display("✓ 异步复位成功: q = %0d", q);
            else
                $display("✗ 异步复位失败: q = %0d", q);
            
            // 释放复位
            rst_n = 1;
            #10;
        end
    endtask
    
    // 测试2: 正常计数功能
    task test_normal_counting;
        begin
            $display("时间: %0t, 测试正常计数", $time);
            
            period = 8'd5;  // 设置周期为5
            en = 1;
            sclr = 0;
            
            // 等待完整计数周期
            #(CLK_PERIOD * 8);
            
            // 检查是否在0-5之间循环
            if (q >= 0 && q <= 5)
                $display("✓ 正常计数成功: q = %0d", q);
            else
                $display("✗ 正常计数失败: q = %0d", q);
        end
    endtask
    
    // 测试3: 同步清零功能
    task test_sync_clear;
        begin
            $display("时间: %0t, 测试同步清零", $time);
            
            en = 1;
            sclr = 0;
            
            // 等待计数器计数到3
            wait(q == 3);
            $display("计数器达到3，准备清零");
            
            // 在时钟上升沿前设置清零
            #(CLK_PERIOD/2 - 1);
            sclr = 1;
            #(CLK_PERIOD);
            sclr = 0;
            
            if (q === 0)
                $display("✓ 同步清零成功: q = %0d", q);
            else
                $display("✗ 同步清零失败: q = %0d", q);
        end
    endtask
    
    // 测试4: 使能控制功能
    task test_enable_control;
        begin
            $display("时间: %0t, 测试使能控制", $time);
            
            en = 1;
            sclr = 0;
            
            // 记录当前计数值
            wait(q == 2);
            $display("计数器达到2，禁用使能");
            
            // 禁用使能
            en = 0;
            #(CLK_PERIOD * 3);
            
            if (q === 2)
                $display("✓ 使能控制成功: 禁用时q保持为%0d", q);
            else
                $display("✗ 使能控制失败: q = %0d", q);
            
            // 重新使能
            en = 1;
            #(CLK_PERIOD);
        end
    endtask
    
    // 测试5: 不同周期值测试
    task test_different_periods;
        begin
            $display("时间: %0t, 测试不同周期值", $time);
            
            // 测试周期为3
            period = 8'd3;
            sclr = 1;  // 先清零
            #(CLK_PERIOD);
            sclr = 0;
            
            #(CLK_PERIOD * 6);  // 等待2个完整周期
            
            if (q >= 0 && q <= 3)
                $display("✓ 周期=3测试成功: q = %0d", q);
            else
                $display("✗ 周期=3测试失败: q = %0d", q);
            
            // 测试周期为15
            period = 8'd15;
            sclr = 1;  // 先清零
            #(CLK_PERIOD);
            sclr = 0;
            
            #(CLK_PERIOD * 5);  // 计数几个周期
            
            if (q >= 0 && q <= 15)
                $display("✓ 周期=15测试成功: q = %0d", q);
            else
                $display("✗ 周期=15测试失败: q = %0d", q);
        end
    endtask
    
    // 监视器：实时显示关键信号变化
    initial begin
        $monitor("时间: %0t, rst_n=%b, en=%b, sclr=%b, period=%0d, q=%0d", 
                 $time, rst_n, en, sclr, period, q);
    end
    
    // 生成VCD波形文件
    initial begin
        $dumpfile("counter_wave.vcd");
        $dumpvars(0, tb_counter);
    end

endmodule