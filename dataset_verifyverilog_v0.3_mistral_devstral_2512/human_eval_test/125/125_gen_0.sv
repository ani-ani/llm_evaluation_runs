module split_words_fsm(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input last_char,
    output reg [15:0] result,
    output reg done,
    output reg is_split_mode
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] char_count;
    reg [15:0] word_count;
    reg [15:0] odd_lower_count;
    reg in_word;
    reg has_delimiter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            is_split_mode <= 1'b0;
            char_count <= 4'd0;
            word_count <= 16'd0;
            odd_lower_count <= 16'd0;
            in_word <= 1'b0;
            has_delimiter <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = SCAN;
                    char_count = 4'd0;
                    word_count = 16'd0;
                    odd_lower_count = 16'd0;
                    in_word = 1'b0;
                    has_delimiter = 1'b0;
                end
            end

            SCAN: begin
                if (valid_in) begin
                    // Check for delimiters
                    if (char_in == 8'h20 || char_in == 8'h2C) begin
                        has_delimiter = 1'b1;
                        if (in_word) begin
                            word_count = word_count + 16'd1;
                            in_word = 1'b0;
                        end
                    end else begin
                        // Check for lowercase letters
                        if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                            // Check if position is odd (0-based: 'a'=0 is odd)
                            if ((char_in - 8'h61) % 2 == 1'b1) begin
                                odd_lower_count = odd_lower_count + 16'd1;
                            end
                        end
                        // Word detection
                        if (!in_word) begin
                            in_word = 1'b1;
                            if (char_count > 4'd0) begin
                                word_count = word_count + 16'd1;
                            end
                        end
                    end
                    char_count = char_count + 4'd1;
                end
                if (last_char) begin
                    // Final word if we were in one
                    if (in_word) begin
                        word_count = word_count + 16'd1;
                    end
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                if (has_delimiter) begin
                    result = word_count;
                    is_split_mode = 1'b1;
                end else begin
                    result = odd_lower_count;
                    is_split_mode = 1'b0;
                end
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule