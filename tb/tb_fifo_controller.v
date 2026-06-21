`timescale 1ns/1ps

module fifo_controller_tb;

// 信号声明
reg wclk;        // 25MHz写时钟
reg rclk;        // 50MHz读时钟
reg rst_n;
reg wr_en;
reg rd_en;
reg [7:0] data_in;
wire [7:0] data_out;
wire full;
wire empty;
wire almost_full;
wire almost_empty;

// 实例化被测模块
fifo_controller uut (
    .wclk(wclk),
    .rclk(rclk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty),
    .almost_full(almost_full),
    .almost_empty(almost_empty)
);

// 写时钟生成 (25MHz，周期40ns)
initial begin
    wclk = 0;
    forever #20 wclk = ~wclk;
end

// 读时钟生成 (50MHz，周期20ns)
initial begin
    rclk = 0;
    forever #10 rclk = ~rclk;
end

// 测试数据生成
integer write_count = 0;
integer read_count = 0;

// 主测试过程
initial begin
    // 初始化
    $display("===== FIFO控制器测试开始 =====");
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    data_in = 8'h00;
    #100;
    
    // 释放复位
    rst_n = 1;
    #100;
    
    // 测试1：基本写操作
    $display("\n测试1：基本写操作（写入8个数据）");
    for (write_count = 0; write_count < 8; write_count = write_count + 1) begin
        wr_en = 1;
        data_in = write_count + 1;  // 写入1~8
        @(posedge wclk);
        #5;
        $display("[%t] 写入数据: %h", $time, data_in);
    end
    wr_en = 0;
    #200;
    
    // 测试2：基本读操作
    $display("\n测试2：基本读操作（读取8个数据）");
    for (read_count = 0; read_count < 8; read_count = read_count + 1) begin
        rd_en = 1;
        @(posedge rclk);
        #5;
        $display("[%t] 读取数据: %h", $time, data_out);
    end
    rd_en = 0;
    #200;
    
    // 测试3：同时读写操作
    $display("\n测试3：同时读写操作");
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;
    
    fork
        // 写进程
        begin
            for (write_count = 0; write_count < 20; write_count = write_count + 1) begin
                wr_en = 1;
                data_in = 8'hA0 + write_count;
                @(posedge wclk);
                #5;
                if (full) begin
                    $display("[%t] FIFO已满，暂停写入", $time);
                    wr_en = 0;
                    @(posedge wclk);
                end
            end
            wr_en = 0;
        end
        
        // 读进程
        begin
            #100;  // 等待一些数据写入
            for (read_count = 0; read_count < 15; read_count = read_count + 1) begin
                rd_en = 1;
                @(posedge rclk);
                #5;
                if (empty) begin
                    $display("[%t] FIFO为空，暂停读取", $time);
                    rd_en = 0;
                    @(posedge rclk);
                end
            end
            rd_en = 0;
        end
    join
    #200;
    
    // 测试4：水位控制测试
    $display("\n测试4：水位控制测试");
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;
    
    // 写入数据直到almost_full
    $display("[%t] 开始写入直到almost_full信号有效", $time);
    write_count = 0;
    while (!almost_full) begin
        wr_en = 1;
        data_in = write_count;
        @(posedge wclk);
        #5;
        write_count = write_count + 1;
    end
    $display("[%t] almost_full有效，当前写入数据量: %d", $time, write_count);
    wr_en = 0;
    
    // 读取数据直到almost_empty
    $display("[%t] 开始读取直到almost_empty信号有效", $time);
    read_count = 0;
    while (!almost_empty) begin
        rd_en = 1;
        @(posedge rclk);
        #5;
        read_count = read_count + 1;
    end
    $display("[%t] almost_empty有效，当前读取数据量: %d", $time, read_count);
    rd_en = 0;
    #200;
    
    // 测试5：边界条件测试（写满和读空）
    $display("\n测试5：边界条件测试");
    rst_n = 0;
    #50;
    rst_n = 1;
    #50;
    
    // 写满FIFO
    $display("[%t] 开始写满FIFO", $time);
    write_count = 0;
    while (!full) begin
        wr_en = 1;
        data_in = 8'hFF - write_count;
        @(posedge wclk);
        #5;
        write_count = write_count + 1;
    end
    $display("[%t] FIFO已满，共写入 %d 个数据", $time, write_count);
    wr_en = 0;
    #100;
    
    // 读空FIFO
    $display("[%t] 开始读空FIFO", $time);
    read_count = 0;
    while (!empty) begin
        rd_en = 1;
        @(posedge rclk);
        #5;
        read_count = read_count + 1;
    end
    $display("[%t] FIFO已空，共读取 %d 个数据", $time, read_count);
    rd_en = 0;
    
    #200;
    $display("\n===== FIFO控制器测试完成 =====");
    $finish;
end

// 监控FIFO状态（仅在状态变化时打印，减少仿真输出）
reg prev_full, prev_empty, prev_almost_full, prev_almost_empty;
always @(posedge wclk or posedge rclk) begin
    if (full      && !prev_full)      $display("[%t] FIFO状态: FULL", $time);
    if (empty     && !prev_empty)     $display("[%t] FIFO状态: EMPTY", $time);
    if (almost_full  && !prev_almost_full)  $display("[%t] FIFO状态: ALMOST_FULL", $time);
    if (almost_empty && !prev_almost_empty) $display("[%t] FIFO状态: ALMOST_EMPTY", $time);
    prev_full = full;
    prev_empty = empty;
    prev_almost_full = almost_full;
    prev_almost_empty = almost_empty;
end

// 生成VCD波形文件
initial begin
    $dumpfile("fifo_controller.vcd");
    $dumpvars(0, fifo_controller_tb);
end

endmodule