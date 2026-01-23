module digit_sum(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output [15:0] result
);

    wire [7:0] val_0 = (char_0 >= 8'd65 && char_0 <= 8'd90) ? char_0 : 8'd0;
    wire [7:0] val_1 = (char_1 >= 8'd65 && char_1 <= 8'd90) ? char_1 : 8'd0;
    wire [7:0] val_2 = (char_2 >= 8'd65 && char_2 <= 8'd90) ? char_2 : 8'd0;
    wire [7:0] val_3 = (char_3 >= 8'd65 && char_3 <= 8'd90) ? char_3 : 8'd0;
    wire [7:0] val_4 = (char_4 >= 8'd65 && char_4 <= 8'd90) ? char_4 : 8'd0;
    wire [7:0] val_5 = (char_5 >= 8'd65 && char_5 <= 8'd90) ? char_5 : 8'd0;
    wire [7:0] val_6 = (char_6 >= 8'd65 && char_6 <= 8'd90) ? char_6 : 8'd0;
    wire [7:0] val_7 = (char_7 >= 8'd65 && char_7 <= 8'd90) ? char_7 : 8'd0;

    wire [8:0] sum_01 = val_0 + val_1;
    wire [8:0] sum_23 = val_2 + val_3;
    wire [8:0] sum_45 = val_4 + val_5;
    wire [8:0] sum_67 = val_6 + val_7;

    wire [9:0] sum_0123 = sum_01 + sum_23;
    wire [9:0] sum_4567 = sum_45 + sum_67;

    assign result = sum_0123 + sum_4567;

endmodule