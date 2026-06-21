module fifo_controller (
    input wire wclk,      // 25MHz 写时钟
    input wire rclk,      // 50MHz 读时钟
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output  full,
    output  empty,
    output reg almost_full,
    output reg almost_empty
);

// 状态定义
parameter IDLE = 0, WRITE = 1, READ = 2, FULL = 3, EMPTY = 4;
reg [2:0] state, next_state;

// 双端口RAM，深度16，宽度8
reg [7:0] mem [0:15];
reg [3:0] wptr, rptr;
reg [4:0] count; // 数据计数

// 状态机
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: begin
            if (wr_en && !full) next_state = WRITE;
            else if (rd_en && !empty) next_state = READ;
            else next_state = IDLE;
        end
        WRITE: begin
            if (full) next_state = FULL;
            else next_state = IDLE;
        end
        READ: begin
            if (empty) next_state = EMPTY;
            else next_state = IDLE;
        end
        FULL: begin
            if (rd_en) next_state = READ;
            else next_state = FULL;
        end
        EMPTY: begin
            if (wr_en) next_state = WRITE;
            else next_state = EMPTY;
        end
    endcase
end

// 水位控制逻辑
always @(*) begin
    if (count >= 12) almost_full = 1;
    else almost_full = 0;
    if (count <= 2) almost_empty = 1;
    else almost_empty = 0;
end

// 写指针逻辑
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) wptr <= 0;
    else if (wr_en && !full) begin
        mem[wptr] <= data_in;
        wptr <= wptr + 1;
    end
end

// 读指针逻辑
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) rptr <= 0;
    else if (rd_en && !empty) begin
        data_out <= mem[rptr];
        rptr <= rptr + 1;
    end
end

// 计数器逻辑
always @(*) begin
    if (wptr >= rptr) count = wptr - rptr;
    else count = 16 - rptr + wptr;
end

assign full = (count == 16);
assign empty = (count == 0);

endmodule