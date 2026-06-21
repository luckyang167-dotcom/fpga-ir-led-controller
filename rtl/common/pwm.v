module pwm # (parameter N=10)(
    input wire           clk,
    input wire           rst_n,
    input wire [7:0]     duty,
    output wire [N-1:0]  o_pwm
);
    wire [7:0] cnt;
    
    // 增强亮度对比度：使用非线性映射
    wire [7:0] adjusted_duty;
    
    // 增强对比度的亮度曲线
    assign adjusted_duty = (duty < 128) ? 
                          (duty * duty / 64) :       // 低亮度区域：平方关系
                          (128 + (duty - 128) * 2);  // 高亮度区域：线性但斜率加倍
    
    //------------o_pwm
    assign o_pwm = (cnt < adjusted_duty) ? {N{1'b1}} : {N{1'b0}};

    counter #(.N(8)) counter_pwm(
        .clk            (clk),
        .rst_n          (rst_n),
        .en             (1'b1),
        .sclr           (1'b0),
        .period         (8'd255),
        .q              (cnt),
        .tick           ()
    );
endmodule