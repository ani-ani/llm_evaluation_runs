module palindrome_checker (
    input reg [63:0] text,
    output reg is_pal
);

always @(*) begin
    is_pal = 1'b1;

    // Pair0: [7:0] vs [63:56]
    if (text[7:0] != 8'd0 && text[63:56] != 8'd0) begin
        if ((text[7:0] ^ text[63:56]) != 8'd0)
            is_pal = 1'b0;
    end

    // Pair1: [15:8] vs [55:48]
    if (text[15:8] != 8'd0 && text[55:48] != 8'd0) begin
        if ((text[15:8] ^ text[55:48]) != 8'd0)
            is_pal = 1'b0;
    end

    // Pair2: [23:16] vs [47:40]
    if (text[23:16] != 8'd0 && text[47:40] != 8'd0) begin
        if ((text[23:16] ^ text[47:40]) != 8'd0)
            is_pal = 1'b0;
    end

    // Pair3: [31:24] vs [39:32]
    if (text[31:24] != 8'd0 && text[39:32] != 8'd0) begin
        if ((text[31:24] ^ text[39:32]) != 8'd0)
            is_pal = 1'b0;
    end
end

endmodule