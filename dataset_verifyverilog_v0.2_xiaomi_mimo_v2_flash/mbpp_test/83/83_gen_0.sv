module char_from_string (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] len,
    output reg [7:0] result_char
);

    // Internal signals for processed values and sums
    reg [4:0] v0, v1, v2, v3, v4, v5, v6, v7;
    wire [7:0] sum;
    wire [7:0] mod_res;
    wire [7:0] mapped_char;

    // Combinational Logic for ASCII-to-Value Conversion
    // Value = (char - 8'h61 + 1) if char is within 'a'-'z' range and index < len, else 0
    always @(*) begin
        // char_0
        if (len > 3'd0 && char_0 >= 8'h61 && char_0 <= 8'h7A)
            v0 = char_0 - 8'h61 + 1'b1;
        else
            v0 = 5'd0;

        // char_1
        if (len > 3'd1 && char_1 >= 8'h61 && char_1 <= 8'h7A)
            v1 = char_1 - 8'h61 + 1'b1;
        else
            v1 = 5'd0;

        // char_2
        if (len > 3'd2 && char_2 >= 8'h61 && char_2 <= 8'h7A)
            v2 = char_2 - 8'h61 + 1'b1;
        else
            v2 = 5'd0;

        // char_3
        if (len > 3'd3 && char_3 >= 8'h61 && char_3 <= 8'h7A)
            v3 = char_3 - 8'h61 + 1'b1;
        else
            v3 = 5'd0;

        // char_4
        if (len > 3'd4 && char_4 >= 8'h61 && char_4 <= 8'h7A)
            v4 = char_4 - 8'h61 + 1'b1;
        else
            v4 = 5'd0;

        // char_5
        if (len > 3'd5 && char_5 >= 8'h61 && char_5 <= 8'h7A)
            v5 = char_5 - 8'h61 + 1'b1;
        else
            v5 = 5'd0;

        // char_6
        if (len > 3'd6 && char_6 >= 8'h61 && char_6 <= 8'h7A)
            v6 = char_6 - 8'h61 + 1'b1;
        else
            v6 = 5'd0;

        // char_7
        if (len > 3'd7 && char_7 >= 8'h61 && char_7 <= 8'h7A)
            v7 = char_7 - 8'h61 + 1'b1;
        else
            v7 = 5'd0;
    end

    // Summing logic
    // Max sum = 8 * 26 = 208, fits in 8 bits
    assign sum = v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7;

    // Modulo 26 Logic (Combinational Subtraction Loop)
    // Since the sum fits in 8 bits, we can unroll the subtraction loop.
    // Max iterations required for 208 is 7 (since 7*26=182, 8*26=208).
    wire [7:0] res0;
    wire [7:0] res1;
    wire [7:0] res2;
    wire [7:0] res3;
    wire [7:0] res4;
    wire [7:0] res5;

    assign res0 = sum;
    assign res1 = (res0 >= 8'd26) ? (res0 - 8'd26) : res0;
    assign res2 = (res1 >= 8'd26) ? (res1 - 8'd26) : res1;
    assign res3 = (res2 >= 8'd26) ? (res2 - 8'd26) : res2;
    assign res4 = (res3 >= 8'd26) ? (res3 - 8'd26) : res3;
    assign res5 = (res4 >= 8'd26) ? (res4 - 8'd26) : res4;
    assign mod_res = (res5 >= 8'd26) ? (res5 - 8'd26) : res5;

    // Mapping Logic
    // 0 -> 'z' (8'h7A)
    // Else -> 'a' + (mod_res - 1)
    always @(*) begin
        if (mod_res == 8'd0)
            result_char = 8'h7A; // 'z'
        else
            result_char = 8'h61 + mod_res - 8'd1; // 'a' + val - 1
    end

endmodule
