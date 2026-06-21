module counter #(parameter N=8) (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire sclr,
    input wire [N-1:0] period,
    output wire [N-1:0] q,
	output wire tick
);

reg [N-1:0] q_reg, q_nxt;
//--------->tick
assign tick = (q_reg==period-1)  ? 1'b1 : 1'b0;
//---->q
assign q = q_reg;

// q_reg 寄存器更新
always @(posedge clk,negedge rst_n)
    if (~rst_n)
        q_reg <= 0;
    else
        q_reg <= q_nxt;

// q_nxt 组合逻辑
always @* begin
    q_nxt = q_reg;
    if (sclr)
        q_nxt = 0;
    else if (en)
        if (q_reg >= period - 1)
            q_nxt = 0;
        else
            q_nxt = q_reg + 1;
    end

endmodule