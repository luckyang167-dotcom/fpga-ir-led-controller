module edge_detect(
    input wire clk,
    input wire rst_n,
    input wire i_inf,
    output wire pos_edg,
    output wire neg_edg,
    output wire all_edg
);

reg [1:0] inf_reg;
wire [1:0] inf_nxt;

//--->inf_reg
always @(posedge clk or negedge rst_n)
    if (~rst_n)
        inf_reg <= 2'b11;
    else
        inf_reg <= inf_nxt;

//--->inf_nxt
assign inf_nxt = {inf_reg[0], i_inf};
//assign inf_nxt = (dir) ? inf_reg + 1 : inf_reg-1;11111111111111

//---pos_edg,neg_edg,all_edg
assign pos_edg = inf_reg[0] & ~inf_reg[1];
assign neg_edg = ~inf_reg[0] & inf_reg[1];
assign all_edg = inf_reg[0] ^ inf_reg[1];

endmodule