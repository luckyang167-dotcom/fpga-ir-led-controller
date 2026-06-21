module top_system(
     input wire clk,
     input wire rst_n,
     input wire i_inf,
     output wire [9:0] led
);
     wire [31:0] data;
     wire [7:0] code;
     reg [1:0] mode, mode_nxt;
     reg [7:0] bright, bright_nxt, speed, speed_nxt;
     reg dir, dir_nxt;
     wire inf_vld;
     reg [7:0] cnt, cnt_nxt;
     
     // 添加亮度模式寄存器
     reg [1:0] bright_mode, bright_mode_nxt;
     reg [23:0] bright_counter;
     
// 键盘定义扩展
// 1---------->模式切换
// 2---------->速度调节  
// 3---------->亮度调节
// 4---------->亮度模式切换
// up--------->方向切换

//---------时序逻辑
     always@(posedge clk, negedge rst_n)
         if(~rst_n) begin
             mode <= 0;
             speed <= 8'd50;        // 初始速度设为中等
             bright <= 8'd100;      // 初始亮度设为中等
             dir <= 1;
             cnt <= 0;
             bright_mode <= 2'b00;  // 默认固定亮度模式
             bright_counter <= 0;
         end
         else begin
             mode <= mode_nxt;
             speed <= speed_nxt;
             bright <= bright_nxt;
             dir <= dir_nxt;
             cnt <= cnt_nxt;
             bright_mode <= bright_mode_nxt;
             bright_counter <= bright_counter + 1;
         end

assign code = data[23:16];

     always@ * begin
         mode_nxt = mode;
         speed_nxt = speed;
         bright_nxt = bright;
         dir_nxt = dir;
         cnt_nxt = cnt;
         bright_mode_nxt = bright_mode;
         
         if(inf_vld)
             case(code)
                 // 模式切换
                 8'h01: mode_nxt = mode + 1;
                 
                 // 速度调节 - 增加调节幅度
                 8'h02: begin
                     if (speed < 250) 
                         speed_nxt = speed + 5;  // 每次增加5，变化更明显
                     else
                         speed_nxt = 255;
                 end
                 
                 // 亮度减小 - 增加调节幅度
                 8'h03: begin
                     if (bright > 10)
                         bright_nxt = bright - 10; // 每次减少10，变化更明显
                     else
                         bright_nxt = 0;
                 end
                 
                 // 亮度增加 - 增加调节幅度
                 8'h04: begin
                     if (bright < 245)
                         bright_nxt = bright + 10; // 每次增加10，变化更明显
                     else
                         bright_nxt = 255;
                 end
                 
                 // 亮度模式切换
                 8'h05: bright_mode_nxt = bright_mode + 1;
                 
                 // 方向切换
                 8'h07: dir_nxt = ~dir;
                 
                 default: ;
             endcase
     end
     
     // 自动亮度调节逻辑（优化）
     reg [7:0] auto_bright;
     always @(posedge clk or negedge rst_n) begin
         if (!rst_n) begin
             auto_bright <= 8'd128;
         end else begin
             case (bright_mode)
                 // 固定亮度模式：使用手动设置的bright值
                 2'b00: auto_bright <= bright;
                 
                 // 呼吸灯模式 - 优化速度
                 2'b01: begin
                     // 使用更快的呼吸效果
                     if (bright_counter[17]) 
                         auto_bright <= 255 - bright_counter[16:9]; // 使用更快的计数器位
                     else
                         auto_bright <= bright_counter[16:9];
                 end
                 
                 // 渐变模式 - 优化速度
                 2'b10: begin
                     // 使用更快的渐变
                     case (bright_counter[19:17])  // 使用更高的计数器位
                         3'b000: auto_bright <= 8'd0;
                         3'b001: auto_bright <= 8'd64; 
                         3'b010: auto_bright <= 8'd128;
                         3'b011: auto_bright <= 8'd192;
                         3'b100: auto_bright <= 8'd255;
                         3'b101: auto_bright <= 8'd192;
                         3'b110: auto_bright <= 8'd128;
                         3'b111: auto_bright <= 8'd64;
                     endcase
                 end
                 
                 // 闪烁模式 - 优化速度
                 2'b11: begin
                     // 更明显的闪烁
                     auto_bright <= bright_counter[18] ? 8'd255 : 8'd50; // 更大的对比度
                 end
             endcase
         end
     end

inf_controller inf_controller_inst(
     .clk        (clk),
     .rst_n      (rst_n),
     .i_inf      (i_inf),
     .data       (data),
     .inf_vld    (inf_vld)
);

led_controller led_controller_inst(
     .clk        (clk),
     .rst_n      (rst_n),
     .mode       (mode),
     .dir        (dir),
     .speed      (speed),
     .bright     (auto_bright),
     .led        (led)
);

endmodule