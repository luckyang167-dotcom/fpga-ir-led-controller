`timescale 1ns/1ps

module seq_detector_tb;

// 信号声明
reg clk;
reg rst_n;
reg data_in;
wire o_sq1;
wire o_sq2;

// 实例化被测模块
seq_detector uut (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in),
    .o_sq1(o_sq1),
    .o_sq2(o_sq2)
);

// 时钟生成
initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50MHz时钟，周期20ns
end

// 测试序列
reg [15:0] test_sequence;
integer i;

// 主测试过程
initial begin
    // 初始化
    $display("===== 序列检测器测试开始 =====");
    rst_n = 0;
    data_in = 0;
    #100;
    
    // 释放复位
    rst_n = 1;
    #20;
    
    // 测试1：正常序列1011（重叠有效和无效都应检测到一次）
    $display("\n测试1：输入1011");
    test_sequence = 16'b1011_0000_0000_0000;
    for (i = 0; i < 4; i = i + 1) begin
        data_in = test_sequence[15];
        test_sequence = test_sequence << 1;
        #20;
    end
    #40;
    
    // 测试2：长序列1011011（重叠有效应检测到2次，重叠无效1次）
    $display("\n测试2：输入1011011");
    rst_n = 0;
    #20;
    rst_n = 1;
    #20;
    
    test_sequence = 16'b1011011_0000000;
    for (i = 0; i < 7; i = i + 1) begin
        data_in = test_sequence[15];
        test_sequence = test_sequence << 1;
        #20;
    end
    #60;
    
    // 测试3：连续输入测试
    $display("\n测试3：连续输入测试");
    rst_n = 0;
    #20;
    rst_n = 1;
    #20;
    
    test_sequence = 16'b1011010110110101;
    for (i = 0; i < 16; i = i + 1) begin
        data_in = test_sequence[15];
        test_sequence = test_sequence << 1;
        #20;
    end
    #100;
    
    // 测试4：无匹配序列测试
    $display("\n测试4：无匹配序列测试（输入全0）");
    rst_n = 0;
    #20;
    rst_n = 1;
    #20;
    
    for (i = 0; i < 10; i = i + 1) begin
        data_in = 0;
        #20;
    end
    
    // 测试5：边界条件测试
    $display("\n测试5：边界条件测试");
    rst_n = 0;
    #20;
    rst_n = 1;
    #20;
    
    test_sequence = 16'b1110110110110111;
    for (i = 0; i < 16; i = i + 1) begin
        data_in = test_sequence[15];
        test_sequence = test_sequence << 1;
        #20;
    end
    
    #100;
    $display("\n===== 序列检测器测试完成 =====");
    $finish;
end

// 监控输出
always @(posedge clk) begin
    if (o_sq1) $display("[%t] 检测到重叠有效序列（o_sq1=1）", $time);
    if (o_sq2) $display("[%t] 检测到重叠无效序列（o_sq2=1）", $time);
end

// 生成VCD波形文件
initial begin
    $dumpfile("seq_detector.vcd");
    $dumpvars(0, seq_detector_tb);
end

endmodule