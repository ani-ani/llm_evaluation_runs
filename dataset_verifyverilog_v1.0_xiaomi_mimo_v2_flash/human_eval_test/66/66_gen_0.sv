module digit_sum(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output reg [15:0] result
);
    // Internal signals for filtered values
    reg [15:0] filtered_0;
    reg [15:0] filtered_1;
    reg [15:0] filtered_2;
    reg [15:0] filtered_3;
    reg [15:0] filtered_4;
    reg [15:0] filtered_5;
    reg [15:0] filtered_6;
    reg [15:0] filtered_7;

    // Combinational always block
    always @(*) begin
        // Process char_0: check if uppercase (0x41-0x5A)
        if (char_0 >= 8'h41 && char_0 <= 8'h5A)
            filtered_0 = {8'd0, char_0};
        else
            filtered_0 = 16'd0;

        // Process char_1
        if (char_1 >= 8'h41 && char_1 <= 8'h5A)
            filtered_1 = {8'd0, char_1};
        else
            filtered_1 = 16'd0;

        // Process char_2
        if (char_2 >= 8'h41 && char_2 <= 8'h5A)
            filtered_2 = {8'd0, char_2};
        else
            filtered_2 = 16'd0;

        // Process char_3
        if (char_3 >= 8'h41 && char_3 <= 8'h5A)
            filtered_3 = {8'd0, char_3};
        else
            filtered_3 = 16'd0;

        // Process char_4
        if (char_4 >= 8'h41 && char_4 <= 8'h5A)
            filtered_4 = {8'd0, char_4};
        else
            filtered_4 = 16'd0;

        // Process char_5
        if (char_5 >= 8'h41 && char_5 <= 8'h5A)
            filtered_5 = {8'd0, char_5};
        else
            filtered_5 = 16'd0;

        // Process char_6
        if (char_6 >= 8'h41 && char_6 <= 8'h5A)
            filtered_6 = {8'd0, char_6};
        else
            filtered_6 = 16'd0;

        // Process char_7
        if (char_7 >= 8'h41 && char_7 <= 8'h5A)
            filtered_7 = {8'd0, char_7};
        else
            filtered_7 = 16'd0;

        // Multi-level adder tree for summation
        // Level 1: 8 -> 4
        result = ((filtered_0 + filtered_1) + (filtered_2 + filtered_3)) +
                 ((filtered_4 + filtered_5) + (filtered_6 + filtered_7));
    end
endmodule