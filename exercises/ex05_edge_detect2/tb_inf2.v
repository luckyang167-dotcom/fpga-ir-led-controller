`timescale 1ns/1ps
module tb_inf();
    localparam N = 8;
    reg clk                   ;
    reg rst_n                 ;
    reg i_inf,en,sclr         ;
    reg [N-1:0] period        ;
    wire pos_edg              ;
    wire neg_edg              ;
    wire all_edq              ;
    wire [N-1:0] q,q_glb      ;
    localparam PERIOD_CLK = 20;    
    initial begin 
        rst_n = 0;
        i_inf = 1;
		en =1;
		sclr =0;
        #100;
        rst_n = 1;
		//随机信号
        repeat(300) begin
		@(negedge clk) ;
        i_inf = {$random} % 2;
        period = {$random} % 2**N;			
		#(20*2**N);//改为#(20*300)可检查全局计算器
        end		
	        //时钟边界情况测试
	        /*  
			period = 255;			
	        #(20*2**N);
            period = 256;			
	        #(20*2**N); 
	        period = 0;			
	        #(20*2**N);
            period = 1;			
	        #(20*2**N);   
			*/
			//使能测试
		    /* 
             en = {$random} % 2;						 
		     */
            //清零
            /*
             sclr = {$random} % 2;
            */			
        #1000;
        $stop;
		
    end
    
//clk
    always begin  
        clk = 1;
        #(PERIOD_CLK/2);
        clk = 0;
        #(PERIOD_CLK/2);
    end
//inst

edge_detect edge_detect_inst(
    .clk        (clk),
    .rst_n      (rst_n),
    .i_inf      (i_inf),
    .pos_edg    (pos_edg),
    .neg_edg    (neg_edg),
    .all_edg    (all_edg)
);
counter counter_inst (
    .clk              (clk   ),
    .rst_n            (rst_n ),
    .en               (en    ),
    .sclr             (sclr  ),
    .period           (period),
    .q                (q     )
);
glbcnt glbcnt_inst(
    .clk              (clk   ),
	.rst_n            (rst_n ),
	.i_inf            (i_inf ),
	.en               (en    ),
	.sclr             (sclr  ),
	.q                (q_glb     )
);
    
endmodule