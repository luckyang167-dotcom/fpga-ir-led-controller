`timescale 1ns/1ps

module edge_detector (
    input clk,
    input rst_n,
    input i_inf,
    output poa_edg,  // 上升沿检测
    output neg_edg,  // 下降沿检测
    output all_edg   // 双边沿检测
);

// 寄存器用于存储上一个时钟周期的输入值
reg i_inf_prev;

// 边沿检测逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i_inf_prev <= 1'b0;
    end else begin
        i_inf_prev <= i_inf;
    end
end

// 上升沿检测：当前为高电平，前一个周期为低电平
assign poa_edg = i_inf & ~i_inf_prev;

// 下降沿检测：当前为低电平，前一个周期为高电平
assign neg_edg = ~i_inf & i_inf_prev;

// 双边沿检测：任何边沿变化
assign all_edg = i_inf ^ i_inf_prev;

endmodule

// 测试平台
module tb_inf();
    reg clk;
    reg rst_n;
    reg i_inf;
    wire poa_edg;
    wire neg_edg;
    wire all_edg;
    
    localparam PERIOD_CLK = 20;
    
    // 实例化被测试模块
    edge_detector uut (
        .clk(clk),
        .rst_n(rst_n),
        .i_inf(i_inf),
        .poa_edg(poa_edg),
        .neg_edg(neg_edg),
        .all_edg(all_edg)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #(PERIOD_CLK/2) clk = ~clk;
    end
    
    // 测试序列
    initial begin
        // 初始化
        rst_n = 0;
        i_inf = 1;
        #100;
        
        // 释放复位
        rst_n = 1;
        #100;
        
        // 生成随机输入序列
        repeat(1000) begin
            @(negedge clk);
            i_inf = ($random) % 2;
        end
        
        // 结束仿真
        #1000;
        $finish;
    end
    
    // 监视信号变化
    initial begin
        $monitor("Time = %0t, i_inf = %b, poa_edg = %b, neg_edg = %b, all_edg = %b", 
                 $time, i_inf, poa_edg, neg_edg, all_edg);
    end
    
    // 生成VCD文件用于波形查看
    initial begin
        $dumpfile("tb_inf.vcd");
        $dumpvars(0, tb_inf);
    end

endmodule
