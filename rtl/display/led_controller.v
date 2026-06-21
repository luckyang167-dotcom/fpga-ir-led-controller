module led_controller(
    input wire clk,
    input wire rst_n,
    input wire [1:0] mode,
    input wire dir,
    input wire [7:0] speed,
    input wire [7:0] bright,
    output wire [9:0] led
);
    
    // 关键修改：调整DIV256参数使速度变化更明显
    // 原值：26'd50000 → 新值：26'd1000000，使速度范围更大
    parameter DIV256 = 26'd1000000;  // 大幅增加这个值，使速度变化更明显
    
    localparam [3:0]
        s_idle = 4'b0001,
        s_move = 4'b0010,
        s_flash = 4'b0100,
        s_cnt   = 4'b1000;
        
    reg [3:0] state_reg, state_nxt;
    reg [9:0] led_reg, led_nxt;
    wire [25:0] period;
    wire [9:0] o_pwm;
    wire en;
    
    // 显示模式相关
    reg [1:0] display_mode;
    reg [23:0] display_counter;
    
    //-------------->led
    assign led = led_reg & o_pwm;
    
    //-------------->period (关键优化)
    // 使用非线性映射，使低速更慢，高速更快，变化更明显
    wire [15:0] speed_scaled = (speed < 128) ? 
                              (speed * speed / 32) :  // 低速区域：平方关系，变化更平缓
                              (512 + (speed - 128) * 8); // 高速区域：线性但斜率更大
    
    assign period = (speed != 0) ? (256 * DIV256 / (speed_scaled + 1)) : (256 * DIV256);
    
    //-------------->state_reg,led_reg 和显示模式
    always@(posedge clk, negedge rst_n)
        if(~rst_n) begin
            state_reg <= s_idle;
            led_reg   <= 10'h3fe;
            display_mode <= 2'b00;
            display_counter <= 0;
        end
        else begin
            state_reg <= state_nxt;
            led_reg   <= led_nxt;
            display_counter <= display_counter + 1;
            
            // 根据亮度值自动选择显示模式 - 增加对比度
            if (bright < 30) 
                display_mode <= 2'b00; // 很低亮度
            else if (bright < 100)
                display_mode <= 2'b01; // 低亮度  
            else if (bright < 180)
                display_mode <= 2'b10; // 中亮度
            else
                display_mode <= 2'b11; // 高亮度
        end
        
    //-------------->state_nxt (保持不变)
    always@ * begin
        state_nxt = state_reg;
        case(state_reg)
        s_idle:
            if(mode==2'b10)
                 state_nxt = s_move;
            else if(mode==2'b01)
                 state_nxt = s_flash;
            else if(mode==2'b11)
                 state_nxt = s_cnt;
        s_move:
            if(mode==2'b01)
                 state_nxt = s_flash;
            else if(mode==2'b11)
                 state_nxt = s_cnt;
            else if(mode==2'b00)
                 state_nxt = s_idle;
        s_flash:
            if(mode==2'b10)
                 state_nxt = s_move;
            else if(mode==2'b11)
                 state_nxt = s_cnt;
            else if(mode==2'b00)
                 state_nxt = s_idle;
        s_cnt:
            if(mode==2'b01)
                 state_nxt = s_flash;
            else if(mode==2'b10)
                 state_nxt = s_move;
            else if(mode==2'b00)
                 state_nxt = s_idle;
        endcase
    end

    //---------------->led_nxt (增强显示效果和响应速度)
    always@ * begin
        led_nxt = led_reg;
        if(en)
        case(state_reg)
        s_idle:
            // 空闲状态根据亮度显示不同图案 - 增加对比度
            case(display_mode)
                2'b00: led_nxt = 10'b0000001111; // 很低亮度：只亮4个
                2'b01: led_nxt = 10'b0001111000; // 低亮度：亮中间6个  
                2'b10: led_nxt = 10'b0111111110; // 中亮度：亮8个
                2'b11: led_nxt = 10'b1111111111; // 高亮度：全亮
            endcase
            
        s_flash:
            // 闪烁模式：更快的闪烁响应
            if (display_counter[16])  // 使用更快的计数器位
                led_nxt = ~led_reg;
            else
                led_nxt = led_reg;
                
        s_move:
            if(dir)
               led_nxt = {led_reg[8:0], led_reg[9]};
            else
               led_nxt = {led_reg[0], led_reg[9:1]};
               
        s_cnt:
            // 计数模式：根据速度调整计数变化
            if (speed > 200)
                led_nxt = led_reg + 2'b11; // 高速时每次加3
            else if (speed > 100)
                led_nxt = led_reg + 1'b1;  // 中速时每次加1
            else
                led_nxt = led_reg;         // 低速时保持，变化更明显
        endcase
    end
    
    counter #(.N(26)) counter_led(
        .clk            (clk),
        .rst_n          (rst_n),
        .en             (1'b1),
        .sclr           (1'b0),
        .period         (period),
        .q              (),
        .tick           (en)
    );
    
    pwm pwm_led(
        .clk           (clk),
        .rst_n         (rst_n),
        .duty          (bright),
        .o_pwm         (o_pwm)
    );
endmodule