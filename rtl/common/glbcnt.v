module glbcnt #(parameter N=8) (
    input wire clk,
    input wire rst_n,
	input wire i_inf,
    input wire en,
    input wire sclr,
    output wire [N-1:0] q
);

wire all_edg;
counter #(.N(N)) counter_glb(
    .clk      (clk    ),
    .rst_n    (rst_n  ),
    .en       (en     ),
    .sclr     (all_edg),
    .period   ({N{1'b1}}),   // max value: free-run, wrap by bit overflow
    .q        (q),
    .tick     ()
);
edge_detect edge_detect_glb(
    .clk          (clk    ),
	.rst_n        (rst_n  ),
	.i_inf        (i_inf  ),
	.pos_edg      (),
	.neg_edg      (),
	.all_edg      (all_edg)
 );

endmodule
