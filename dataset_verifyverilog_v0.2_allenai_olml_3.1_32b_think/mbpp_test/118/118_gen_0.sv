module string_splitter (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_string [15:0],
    output reg [7:0] word1 [15:0],
    output reg [7:0] word2 [15:0],
    output reg [7:0] word3 [15:0],
    output reg [2:0] word_count,
    output reg done
);

reg [7:0] [15:0] captured_input;
reg [15:0] char_index;
reg [1:0] word_index;
reg [2:0] word_count;
reg [7:0] [15:0] word1, word2, word3;
reg [7:0] [15:0] current_word;
reg [3:0] state;
reg [3:0] char_pos;
reg in_word;
reg [2:0] ext_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        captured_input <= 16'b0;
        char_index <= 16'd0;
        word_index <= 2'd0;
        word_count <= 3'd0;
        word1 <= 16{8'b00100000};
        word2 <= word1;
        word3 <= word1;
        current_word <= 16{8'b00100000};
        char_pos <= 4'd0;
        in_word <= 1'b0;
        state <= 4'd0;
        ext_counter <= 3'd4;
    end else begin
        if (state == 4'd0) begin
            if (start) begin
                captured_input <= input_string;
                char_index <= 16'd0;
                word_index <= 2'd0;
                word_count <= 3'd0;
                word1 <= 16{8'b00100000};
                word2 <= word1;
                word3 <= word1;
                current_word <= 16{8'b00100000};
                char_pos <= 4'd0;
                in_word <= 1'b0;
                state <= 4'd1;
            end
            else begin
                state <= 4'd0;
            end
        end else if (state == 4'd1) begin
            if (char_index < 16) begin
                wire [7:0] current_char = captured_input[char_index];
                if (current_char == 8'h20) begin
                    if (in_word) begin
                        if (word_index < 3) begin
                            if (word_index == 0) word1 <= current_word;
                            else if (word_index == 1) word2 <= current_word;
                            else word3 <= current_word;
                            word_index <= word_index + 1;
                            if (word_index < 4) word_count <= word_count + 1;
                        end
                        current_word <= 16{8'b00100000};
                        char_pos <= 4'd0;
                        in_word <= 1'b0;
                    end
                end else begin
                    if (!in_word) begin
                        in_word <= 1'b1;
                        current_word <= 16{8'b00100000};
                        char_pos <= 4'd0;
                    end
                    current_word[char_pos] <= current_char;
                    char_pos <= char_pos + 1;
                end
                char_index <= char_index + 1;
            end else begin
                if (in_word) begin
                    if (word_index < 3) begin
                        if (word_index == 0) word1 <= current_word;
                        else if (word_index == 1) word2 <= current_word;
                        else word3 <= current_word;
                        word_index <= word_index + 1;
                        if (word_index < 4) word_count <= word_count + 1;
                    end
                    current_word <= 16{8'b00100000};
                    char_pos <= 4'd0;
                    in_word <= 1'b0;
                end
                state <= 4'd2;
            end
        end else if (state == 4'd2) begin
            if (ext_counter > 0) begin
                ext_counter <= ext_counter - 1;
            end else begin
                state <= 4'd3;
            end
        end else begin
            done <= 1'b1;
        end
    end
end

assign word_count = word_count;
assign done = done;

endmodule