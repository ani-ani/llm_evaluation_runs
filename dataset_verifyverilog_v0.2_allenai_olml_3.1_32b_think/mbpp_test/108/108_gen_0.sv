module merge_three_sorted_lists (
    input [7:0] list1_size,
    input [7:0] list2_size,
    input [7:0] list3_size,
    input [2:0][7:0] list1,
    input [2:0][7:0] list2,
    input [2:0][7:0] list3,
    output reg [5:0] result_size,
    output reg [23:0][7:0] result
);
    wire [7:0] val1 = (list1_size > 0) ? list1[0] : 8'hFF;
    wire [7:0] val2 = (list2_size > 0) ? list2[0] : 8'hFF;
    wire [7:0] val3 = (list3_size > 0) ? list3[0] : 8'hFF;
    wire [7:0] min_val = min(val1, min(val2, val3));
    wire [2:0] sel = (min_val == val1) ? 3'b000 : (min_val == val2) ? 3'b001 : 3'b010;
    wire valid = min_val < 8'hFF;
    assign result[0] = valid ? min_val : 8'h00;
    assign result_size = valid ? 1 : 0;
endmodule