module counter #(parameter N=8) (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire sclr,
    input wire [N-1:0] period,
    output wire [N-1:0] q
);
reg [N-1:0] q_reg,q_nxt;
//-- >g
    assign q = q_reg;
//->q_reg
    always@ (posedge clk, negedge rst_n)
        if(~rst_n)
           q_reg <= 0;
        else
           q_reg <= q_nxt;
//->q nxt
    always@ * begin
        q_nxt = q_reg;
    if (sclr)
        q_nxt = 0;
    else if (en)
        if(q_reg>= period-1)
            q_nxt = 0;
        else
            q_nxt = q_reg + 1;
     
    end
endmodule