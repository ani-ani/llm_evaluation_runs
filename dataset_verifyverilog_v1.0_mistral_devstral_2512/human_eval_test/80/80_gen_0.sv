module is_happy(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] length,
    output reg is_happy
);

    reg [7:0] chars [0:7];
    assign chars[0] = char_0;
    assign chars[1] = char_1;
    assign chars[2] = char_2;
    assign chars[3] = char_3;
    assign chars[4] = char_4;
    assign chars[5] = char_5;
    assign chars[6] = char_6;
    assign chars[7] = char_7;

    always @(*) begin
        if (length < 3'd3) begin
            is_happy = 1'b0;
        end else begin
            is_happy = 1'b1;
            
            if (length >= 3'd3) begin
                if (chars[0] == chars[1] || chars[0] == chars[2] || chars[1] == chars[2]) begin
                    is_happy = 1'b0;
                end
            end
            
            if (length >= 3'd4) begin
                if (chars[1] == chars[2] || chars[1] == chars[3] || chars[2] == chars[3]) begin
                    is_happy = 1'b0;
                end
            end
            
            if (length >= 3'd5) begin
                if (chars[2] == chars[3] || chars[2] == chars[4] || chars[3] == chars[4]) begin
                    is_happy = 1'b0;
                end
            end
            
            if (length >= 3'd6) begin
                if (chars[3] == chars[4] || chars[3] == chars[5] || chars[4] == chars[5]) begin
                    is_happy = 1'b0;
                end
            end
            
            if (length >= 3'd7) begin
                if (chars[4] == chars[5] || chars[4] == chars[6] || chars[5] == chars[6]) begin
                    is_happy = 1'b0;
                end
            end
            
            if (length >= 3'd8) begin
                if (chars[5] == chars[6] || chars[5] == chars[7] || chars[6] == chars[7]) begin
                    is_happy = 1'b0;
                end
            end
        end
    end
endmodule