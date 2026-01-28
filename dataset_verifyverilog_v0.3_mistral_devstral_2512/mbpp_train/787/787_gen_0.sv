module text_match_three(
    input [127:0] text_in,
    input [3:0] length,
    output reg match
);

    integer i;
    always @(*) begin
        match = 1'b0;
        
        for (i = 0; i < 13; i = i + 1) begin
            if (i + 3 < length) begin
                if (text_in[i*8 +: 8] == 8'h61 &&
                    text_in[(i+1)*8 +: 8] == 8'h62 &&
                    text_in[(i+2)*8 +: 8] == 8'h62 &&
                    text_in[(i+3)*8 +: 8] == 8'h62) begin
                    match = 1'b1;
                end
            end
        end
    end

endmodule