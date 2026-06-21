module glbcnt(
    input        clk,        // 时钟（上升沿触发）
    input        rst_n,      // 异步复位（低电平有效）
    input        inf_d,      // 边沿检测原始输入（连接到edge_detector的i_inf）
    output reg [18:0] cnt    // 19位计数器输出（0~524287）
);

// 连接edge_detector的双边沿输出（原inf_double）
wire all_edg;  //  renamed from inf_double（与edge_detector端口名一致，更清晰）

// 计数器时序逻辑（保持之前更正的“边沿触发置1”功能）
always@(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        cnt <= 19'd0;  // 复位清0
    end else if(all_edg) begin  // 双边沿触发时置1
        cnt <= 19'd1;
    end else begin
        cnt <= cnt + 19'd1;  // 正常自增
    end
end

// 关键：实例化edge_detector模块（同一目录下直接引用，无需额外路径）
edge_detector edg_inst(  // 实例名可自定义，如edg_inst
    .clk           (clk       ),  // 时钟同源
    .rst_n         (rst_n     ),  // 复位同源
    .i_inf         (inf_d     ),  // glbcnt的inf_d → edge_detector的i_inf
    .poa_edg       (/*unused*/),  // 未使用端口，标记避免告警
    .neg_edg       (/*unused*/),  // 未使用端口，标记避免告警
    .all_edg       (all_edg   )   // 双边沿输出 → 计数器触发信号
);

endmodule