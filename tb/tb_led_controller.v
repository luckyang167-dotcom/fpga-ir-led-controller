`timescale 1ns/1ps  // 时间单位：1ns，精度：1ps

// ------------------------------
// LED控制器Testbench主模块
// ------------------------------
module tb_led_controller;

// 1. 声明测试信号（输入为reg，输出为wire）
reg         clk;
reg         rst_n;
reg  [1:0]  mode;
reg         dir;
reg  [7:0]  speed;
reg  [7:0]  bright;
wire [9:0]  led;

// 2. 生成50MHz时钟（周期20ns）
initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;  // 每10ns翻转一次，周期20ns
end

// 3. 生成异步复位信号（初始低复位，20ns后释放）
initial begin
    rst_n = 1'b0;
    #20;                     // 20ns后释放复位
    rst_n = 1'b1;
end

// 4. 激励序列：分阶段测试不同模式和参数
initial begin
    // 初始状态（idle模式）
    mode   = 2'b00;   // 空闲模式
    dir    = 1'b0;    // 初始方向（左移）
    speed  = 8'd10;   // 初始速度（speed越大，en脉冲越频繁）
    bright = 8'd128;  // 初始亮度（50%占空比）
    #100;              // 等待复位稳定

    // 测试阶段1：闪烁模式（mode=01）
    mode = 2'b01;
    #100000;           // 观察闪烁效果
    speed = 8'd20;     // 加快闪烁速度
    #100000;

    // 测试阶段2：移动模式（mode=10）
    mode = 2'b10;
    dir = 1'b0;        // 左移方向
    #100000;
    dir = 1'b1;        // 右移方向
    #100000;
    speed = 8'd5;      // 减慢移动速度
    #100000;

    // 测试阶段3：计数模式（mode=11）
    mode = 2'b11;
    #100000;
    bright = 8'd64;    // 降低亮度（25%占空比）
    #100000;

    // 测试阶段4：回到空闲模式
    mode = 2'b00;
    #50000;

    // 结束仿真
    $finish;
end

// 5. 实例化被测模块（DUT）
led_controller u_led_controller(
    .clk    (clk),
    .rst_n  (rst_n),
    .mode   (mode),
    .dir    (dir),
    .speed  (speed),
    .bright (bright),
    .led    (led)
);

// 6. 波形打印与文件生成（方便调试）
initial begin
    // 实时打印关键信号值
    $monitor("Time = %0t | mode = %b | dir = %b | speed = %0d | bright = %0d | led = %b",
             $time, mode, dir, speed, bright, led);
    // 生成VCD波形文件（可在Modelsim/Verilator中查看）
    $dumpfile("tb_led_controller.vcd");
    $dumpvars(0, tb_led_controller);
end

endmodule