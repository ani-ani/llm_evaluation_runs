module vowels_count (
input clk,
input rst_n,
input start,
input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
input [3:0] valid_len,
output reg [3:0] result,
output reg done
);
wire [7:0] char_bus [8:0];
assign char_bus[0] = char_0;
assign char_bus[1] = char_1;
assign char_bus[2] = char_2;
assign char_bus[3] = char_3;
assign char_bus[4] = char_4;
assign char_bus[5] = char_5;
assign char_bus[6] = char_6;
assign char_bus[7] = char_7;
reg [1:0] state;
reg [3:0] captured_valid_len;
reg [2:0] current_index;
reg [3:0] result_reg;
assign done = (state == 2'b10);
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        captured_valid_len <= 4'd0;
        current_index <= 3'd0;
        result_reg <= 4'd0;
    end else begin
        case (state)
            2'b00: begin
                if (start) begin
                    state <= 2'b01;
                    captured_valid_len <= valid_len;
                    current_index <= 3'd0;
                    result_reg <= 4'd0;
                end
            end
            2'b01: begin
                if (current_index < captured_valid_len) begin
                    wire [7:0] current_char = char_bus[current_index];
                    int is_vowel_or_y;

                    if ( (current_char >= 'a' && current_char <= 'z') && (current_char == 'a' || current_char == 'e' || current_char == 'i' || current_char == 'o' || current_char == 'u') ) begin
                        is_vowel_or_y = 1;
                    end else if ( (current_char >= 'A' && current_char <= 'Z') && (current_char == 'A' || current_char == 'E' || current_char == 'I' || current_char == 'O' || current_char == 'U') ) begin
                        is_vowel_or_y =1;
                    end

                    if ( !is_vowel_or_y && (current_index == (captured_valid_len -1)) && (current_char == 'y' || current_char == 'Y') ) begin
                        is_vowel_or_y =1;
                    end

                    if (is_vowel_or_y) begin
                        result_reg <= result_reg +1;
                    end

                    current_index <= current_index +1;
                end else begin
                    state <= 2'b10;
                end
            end
            2'b10: begin
            end
        endcase
    end
end
assign result = result_reg;
endmodule