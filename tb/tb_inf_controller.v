`timescale 1ns/1ps  // 时间单位/精度

module tb_inf_controller();

// 1. 信号声明
reg         clk;
reg         rst_n;
reg         i_inf;
wire [31:0] data;
wire        inf_vld;

// 2. 实例化待测试模块（DUT）
inf_controller u_inf_controller(
    .clk      (clk),
    .rst_n    (rst_n),
    .i_inf    (i_inf),
    .data     (data),
    .inf_vld  (inf_vld)
);

// 3. 时钟生成（50MHz，周期20ns）
initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;  // 每10ns翻转一次
end

// 4. 复位信号生成
initial begin
    rst_n = 1'b0;            // 初始复位
    #200 rst_n = 1'b1;       // 200ns后释放复位
end

// 5. 激励生成：模拟红外遥控协议时序
initial begin
    // 初始状态
    i_inf = 1'b1;  // 红外空闲状态为高
    #300;          // 复位释放后等待稳定
    
    // ========== 测试场景1：有效32位数据传输 ==========
    send_inf_frame(32'h12345678);  // 发送自定义32位数据
    
    // 等待帧结束
    #50000;
    
    // ========== 测试场景2：重复码 ==========
    send_repeat_code();
    
    // 等待重复码结束
    #50000;
    
    // ========== 测试场景3：无效时序（9ms引导码不满足） ==========
    send_invalid_9ms();
    
    // ========== 测试场景4：数据位时序异常 ==========
    send_invalid_data_bit();
    
    // 仿真结束
    #100000;
    $display("===== 仿真结束 =====");
    $finish;
end

// 6. 辅助任务：发送完整红外帧（NEC协议）
task send_inf_frame;
    input [31:0] inf_data;
    integer i;
begin
    // 步骤1：9ms低电平（引导码）
    i_inf = 1'b0;
    #180000;  // 9ms = 9000us = 9000000ns（此处按25kHz分频后计数对应调整）
              // 注：根据模块中cnt的25kHz时钟（40us周期），9ms对应225个计数周期
              // 简化为：9ms = 9000us = 9000*20ns/40ns = 4500个clk周期（20ns/clk）
              // 实际仿真中缩短为180000ns（9ms）
    
    // 步骤2：4.5ms高电平（引导码）
    i_inf = 1'b1;
    #90000;   // 4.5ms
    
    // 步骤3：发送32位数据（低位在前）
    for(i=0; i<32; i=i+1) begin
        if(inf_data[i] == 1'b0) begin
            // 0位：0.56ms低 + 0.56ms高
            i_inf = 1'b0;
            #11200;  // 0.56ms
            i_inf = 1'b1;
            #11200;  // 0.56ms
        end else begin
            // 1位：0.56ms低 + 1.69ms高
            i_inf = 1'b0;
            #11200;  // 0.56ms
            i_inf = 1'b1;
            #33800;  // 1.69ms
        end
    end
    
    // 步骤4：帧结束（空闲高电平）
    i_inf = 1'b1;
    #10000;
end
endtask

// 7. 辅助任务：发送重复码（2.25ms高电平）
task send_repeat_code;
begin
    // 9ms低电平
    i_inf = 1'b0;
    #180000;  // 9ms
    
    // 2.25ms高电平（重复码特征）
    i_inf = 1'b1;
    #45000;   // 2.25ms
    
    // 空闲
    i_inf = 1'b1;
    #10000;
end
endtask

// 8. 辅助任务：发送无效9ms引导码（时长不满足）
task send_invalid_9ms;
begin
    // 8ms低电平（不满足9ms要求）
    i_inf = 1'b0;
    #160000;  // 8ms
    
    // 4.5ms高电平
    i_inf = 1'b1;
    #90000;   // 4.5ms
    
    // 后续数据（无效）
    i_inf = 1'b1;
    #10000;
end
endtask

// 9. 辅助任务：发送无效数据位（时序超出0.56/1.69ms范围）
task send_invalid_data_bit;
begin
    // 正常引导码
    i_inf = 1'b0;
    #180000;  // 9ms
    i_inf = 1'b1;
    #90000;   // 4.5ms
    
    // 无效数据位：0.56ms低 + 2ms高（超出1.69ms）
    i_inf = 1'b0;
    #11200;  // 0.56ms
    i_inf = 1'b1;
    #40000;  // 2ms
    
    // 空闲
    i_inf = 1'b1;
    #10000;
end
endtask

// 10. 监测逻辑：打印关键信号
initial begin
    $monitor("Time = %0t | state = %b | bit_cnt = %0d | inf_vld = %b | data = 0x%08x",
             $time, u_inf_controller.state_reg, u_inf_controller.bit_cnt,
             inf_vld, data);
             
    // 检查inf_vld有效时的数据是否正确
    @(posedge inf_vld);
    if(data == 32'h12345678) begin
        $display("===== 数据验证成功：data = 0x%08x =====", data);
    end else begin
        $error("===== 数据验证失败！期望0x12345678，实际0x%08x =====", data);
    end
end

// 11. 波形导出（可选，用于仿真工具查看）
initial begin
    $dumpfile("tb_inf_controller.vcd");  // 生成vcd波形文件
    $dumpvars(0, tb_inf_controller);    // 导出所有信号
end

endmodule
