module perfect_squares_rom (
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [15:0] matches
);

    always @(*) begin
        matches = 16'h0000;
        
        if (0 >= a && 0 <= b) matches[0] = 1'b1;
        if (1 >= a && 1 <= b) matches[1] = 1'b1;
        if (4 >= a && 4 <= b) matches[4] = 1'b1;
        if (9 >= a && 9 <= b) matches[9] = 1'b1;
        if (16 >= a && 16 <= b) matches[16] = 1'b1;
        if (25 >= a && 25 <= b) matches[25] = 1'b1;
        if (36 >= a && 36 <= b) matches[36] = 1'b1;
        if (49 >= a && 49 <= b) matches[49] = 1'b1;
        if (64 >= a && 64 <= b) matches[64] = 1'b1;
        if (81 >= a && 81 <= b) matches[81] = 1'b1;
        if (100 >= a && 100 <= b) matches[100] = 1'b1;
        if (121 >= a && 121 <= b) matches[121] = 1'b1;
        if (144 >= a && 144 <= b) matches[144] = 1'b1;
        if (169 >= a && 169 <= b) matches[169] = 1'b1;
        if (196 >= a && 196 <= b) matches[196] = 1'b1;
        if (225 >= a && 225 <= b) matches[225] = 1'b1;
    end

endmodule