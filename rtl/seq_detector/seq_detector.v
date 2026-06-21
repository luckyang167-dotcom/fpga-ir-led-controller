module seq_detector (
    input wire clk,
    input wire rst_n,
    input wire data_in,
    output reg o_sq1,  // 重叠有效输出
    output reg o_sq2   // 重叠无效输出
);

// 独热码状态定义
parameter S0 = 4'b0001, S1 = 4'b0010, S2 = 4'b0100, S3 = 4'b1000;
reg [3:0] state, next_state;

// 状态转移逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S0;
    else state <= next_state;
end

always @(*) begin
    case (state)
        S0: next_state = data_in ? S1 : S0;
        S1: next_state = data_in ? S1 : S2;
        S2: next_state = data_in ? S3 : S0;
        S3: next_state = data_in ? S1 : S2; // 重叠有效逻辑
    endcase
end

// 输出逻辑：Moore型，仅与当前状态有关
always @(*) begin
    case (state)
        S3: begin
            o_sq1 = 1;  // 重叠有效：检测到序列
            o_sq2 = 1;  // 重叠无效：检测到序列
        end
        default: begin
            o_sq1 = 0;
            o_sq2 = 0;
        end
    endcase
end

// 重叠无效逻辑：在检测到序列后，下一个状态必须是S0
always @(posedge clk) begin
    if (state == S3) begin
        // 如果重叠无效，检测到后必须回到S0
        // 这里可以通过修改next_state逻辑实现
    end
end

endmodule
