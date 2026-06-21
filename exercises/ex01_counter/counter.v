module counter #(parameter N=8)(
    input wire clk,
    input wire rst_n,   // 异步复位（低电平有效）
    input wire en,      // 计数使能
    input wire sclr,    // 同步清零（高电平有效）
    input wire [N-1:0] period,  // 修改：period 位宽应为 N-1:0
    output wire [N-1:0] q
);

reg [N-1:0] q_reg, q_nxt;

// 时序逻辑：寄存器更新
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         // 异步复位（低电平有效）
        q_reg <= 0;
    else 
        q_reg <= q_nxt; // 同步更新
end

// 组合逻辑：计算下一个状态
always @* begin
    q_nxt = q_reg;  // 默认保持当前值
    
    if (sclr)       // 同步清零（最高优先级）
        q_nxt = 0;
    else if (en) begin  // 使能有效
        if (q_reg == period)  // 修改：比较周期值（非 period-1）
            q_nxt = 0;
        else
            q_nxt = q_reg + 1;
    end
end

assign q = q_reg;  // 添加：输出连接

endmodule
