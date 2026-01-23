module tuple_to_string (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] length,
    output [63:0] result
);

    // Combinational logic to select valid characters based on length
    // Characters are packed left-aligned (MSB first)
    always @(*) begin
        case(length)
            3'd0: result = 64'h0000000000000000;
            3'd1: result = {char_0, 56'h0};
            3'd2: result = {char_0, char_1, 48'h0};
            3'd3: result = {char_0, char_1, char_2, 40'h0};
            3'd4: result = {char_0, char_1, char_2, char_3, 32'h0};
            3'd5: result = {char_0, char_1, char_2, char_3, char_4, 24'h0};
            3'd6: result = {char_0, char_1, char_2, char_3, char_4, char_5, 16'h0};
            3'd7: result = {char_0, char_1, char_2, char_3, char_4, char_5, char_6, 8'h0};
            3'd8: result = {char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7};
            default: result = 64'h0000000000000000;
        endcase
    end

endmodule