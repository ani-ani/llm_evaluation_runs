module tuple_append (
    input [31:0] tuple_str,
    input [7:0] tuple_num,
    input [7:0] tuple_list,
    input tuple_bool,
    input [7:0] append_val,
    input [2:0] m,
    input [7:0] n,
    output reg [31:0] result_str,
    output reg [7:0] result_num,
    output reg [7:0] result_list,
    output reg result_bool
);

    // Combinational logic
    always @(*) begin
        // Pass through unchanged elements
        result_str = tuple_str;
        result_num = tuple_num;
        result_bool = tuple_bool;
        
        // Append operation when m == 2
        if (m == 3'd2) begin
            result_list = n;
        end else begin
            result_list = tuple_list;
        end
    end

endmodule