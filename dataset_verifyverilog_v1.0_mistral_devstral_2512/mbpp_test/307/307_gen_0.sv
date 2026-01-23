module tuple_modify(
    input [31:0] tuple_str,
    input [7:0] tuple_num,
    input [7:0] tuple_list,
    input tuple_bool,
    input [7:0] append_val,
    input [2:0] m,
    input [7:0] n,
    output [31:0] result_str,
    output [7:0] result_num,
    output [7:0] result_list,
    output result_bool
);

    assign result_str = tuple_str;
    assign result_num = tuple_num;
    assign result_bool = tuple_bool;
    
    always @(*) begin
        if (m == 3'd2) begin
            result_list = n;
        end else begin
            result_list = tuple_list;
        end
    end

endmodule