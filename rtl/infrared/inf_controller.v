module inf_controller(
    input wire clk,
    input wire rst_n,
    input wire i_inf,
    output wire [31:0] data,  // 修正：中文冒号改为英文冒号
    output reg inf_vld
);

    // 参数定义
    localparam CNT056MIN = 10;
    localparam CNT056MAX = 20;
    localparam CNT169MIN = 35;
    localparam CNT169MAX = 48;
    localparam CNT225MIN = 50;
    localparam CNT225MAX = 65;
    localparam CNT4_5MIN = 80;
    localparam CNT4_5MAX = 130;
    localparam CNT9MIN   = 160;
    localparam CNT9MAX   = 250;
    
    // 状态定义（独热码编码）
    localparam S_IDLE   = 5'b00001;
    localparam S_9MS    = 5'b00010;
    localparam S_JUDGE  = 5'b00100;
    localparam S_DATA   = 5'b01000;
    localparam S_REPEAT = 5'b10000;

    // 信号声明
    wire flag056, flag169, flag225, flag4_5, flag9;
    wire [7:0] cnt;
    wire div_25k, en, pos_edg, neg_edg, all_edg;
    
    reg [4:0] state_reg, state_nxt;
    reg [5:0] bit_cnt;
    reg [31:0] data_reg, data_nxt;

    // 常量赋值
    assign en = 1'b1;

    // 时间标志判断逻辑
    assign flag056 = (cnt >= CNT056MIN && cnt <= CNT056MAX) ? 1'b1 : 1'b0;
    assign flag169 = (cnt >= CNT169MIN && cnt <= CNT169MAX) ? 1'b1 : 1'b0;
    assign flag225 = (cnt >= CNT225MIN && cnt <= CNT225MAX) ? 1'b1 : 1'b0;
    assign flag4_5 = (cnt >= CNT4_5MIN && cnt <= CNT4_5MAX) ? 1'b1 : 1'b0;
    assign flag9   = (cnt >= CNT9MIN && cnt <= CNT9MAX) ? 1'b1 : 1'b0;

    // 数据输出：有效时输出数据，无效时输出高阻态[1](@ref)
    assign data = (state_reg == S_DATA && bit_cnt == 32 && pos_edg) ? data_reg : 32'bz;

    // 有效信号生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            inf_vld <= 1'b0;
        else if (state_reg == S_DATA && pos_edg && bit_cnt == 32)
            inf_vld <= 1'b1;
        else
            inf_vld <= 1'b0;
    end

    // 数据寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_reg <= 32'b0;
        else
            data_reg <= data_nxt;
    end

    // 数据下一状态逻辑（补全了缺失的end）[1](@ref)
    always @* begin
        data_nxt = data_reg;  // 默认保持原值
        if (state_reg == S_DATA && bit_cnt < 32 && neg_edg && flag056)
            data_nxt[bit_cnt] = 1'b0;
        else if (state_reg == S_DATA && bit_cnt < 32 && neg_edg && flag169)
            data_nxt[bit_cnt] = 1'b1;
        // 添加其他条件的处理...
    end  // 修正：补上缺失的end

    // 位计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 0;
        else if (state_reg == S_IDLE)
            bit_cnt <= 0;
        else if (neg_edg && state_reg == S_DATA && bit_cnt < 32)
            bit_cnt <= bit_cnt + 1;
        else
            bit_cnt <= bit_cnt;
    end

    // 状态寄存器（时序逻辑）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_reg <= S_IDLE;
        else
            state_reg <= state_nxt;
    end

    // 状态转移逻辑（三段式状态机）[7,8](@ref)
    always @* begin
        state_nxt = state_reg;  // 默认保持当前状态
        
        case (state_reg)
            S_IDLE: begin  // 修正：状态标签后用冒号[1](@ref)
                if (neg_edg)
                    state_nxt = S_9MS;
            end
            
            S_9MS: begin  // 修正：状态标签后用冒号
                if (pos_edg && flag9)
                    state_nxt = S_JUDGE;
                else if (pos_edg && !flag9)
                    state_nxt = S_IDLE;
            end
            
            S_JUDGE: begin
                if (neg_edg && flag4_5)
                    state_nxt = S_DATA;
                else if (neg_edg && flag225)
                    state_nxt = S_REPEAT;
                else if (neg_edg && !flag225 && !flag4_5)
                    state_nxt = S_IDLE;
            end
            
            S_DATA: begin
                if (pos_edg && !flag056)
                    state_nxt = S_IDLE;
                else if (neg_edg && !flag056 && !flag169)
                    state_nxt = S_IDLE;
                else if (pos_edg && bit_cnt == 32)
                    state_nxt = S_IDLE;
            end
            
            S_REPEAT: begin
                if (pos_edg)
                    state_nxt = S_IDLE;
            end
            
            default: state_nxt = S_IDLE;  // 添加默认状态，防止锁死[6,8](@ref)
        endcase
    end

    // 分频计数器实例化（修正参数传递语法）[4](@ref)
    counter #(.N(11)) counter_dif_25k(  // 修正：参数传递语法
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .sclr(1'b0),  // 明确指定1'b0
        .period(2000),
        .q(),         // 未连接端口明确空置
        .tick(div_25k)
    );

    // 边沿检测实例化
    edge_detect edge_detect_inf_ctl(
        .clk(clk),
        .rst_n(rst_n),
        .i_inf(i_inf),
        .pos_edg(pos_edg),
        .neg_edg(neg_edg),
        .all_edg(all_edg)
    );

    // 全局计数器实例化
    glbcnt glbcnt_inf_ctl(
        .clk(clk),
        .rst_n(rst_n),
        .i_inf(i_inf),
        .en(div_25k),
        .sclr(1'b0),
        .q(cnt)
    );

endmodule