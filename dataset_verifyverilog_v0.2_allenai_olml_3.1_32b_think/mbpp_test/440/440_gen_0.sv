module adverb_detector (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg [39:0] word_out,
    output reg found,
    output reg done 
);

// Declare variables
reg [2:0] state;
reg [3:0] position = 0;
reg [3:0] start_pos_reg;
reg [3:0] end_pos_reg;
reg [39:0] word_buf;
reg [4:0] current_word_length;
reg [7:0] last_char;
reg [7:0] last_last_char;
reg [3:0] char_count;

// Position assignment
assign current_position = position - 1;

// State transitions
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0; // IDLE
        position <= 4'd0;
        start_pos_reg <= 4'd0;
        end_pos_reg <= 4'd0;
        word_buf <= 40'd0;
        current_word_length <= 5'd0;
        last_char <= 8'd0;
        last_last_char <= 8'd0;
        found <= 1'b0;
        done <= 1'b0;
    end else begin
        position <= position + (char_valid ? 1 : 0);

        case (state)
            3'd0: // IDLE
                if (start) state <= 3'd1; // SEARCH
                else state <= 3'd0;
            ;
            3'd1: // SEARCH
                if (char_valid && char_in != ' ') begin
                    start_pos_reg <= current_position;
                    state <= 3'd2; // MATCH
                    current_word_length <= 1;
                    last_char <= char_in;
                    last_last_char <= 8'd0;
                    word_buf <= {40{1'b0}}; // Initialize to 0
                end
                else begin
                    state <= 3'd1;
                end
            ;
            3'd2: // MATCH
                if (char_valid) begin
                    if (char_in == ' ' || (position == 15 && char_valid)) begin
                        // Check for 'ly'
                        if (current_word_length >= 2 && last_last_char == 'l' && last_char == 'y') begin
                            end_pos_reg <= current_position;
                            state <= 3'd3; // FOUND
                        end else begin
                            state <= 3'd1; // SEARCH
                        end
                    end else begin
                        current_word_length <= current_word_length + 1;
                        last_last_char <= last_char;
                        last_char <= char_in;
                        if (current_word_length <= 5) begin
                            word_buf <= {word_buf[31:0] << 8, char_in};
                        end
                    end
                end else begin
                    // Handle invalid characters? Assume word continues?
                    // Or treat as word end?
                    if (current_word_length > 0) begin
                        if (last_last_char == 'l' && last_char == 'y') begin
                            end_pos_reg <= current_position;
                            state <= 3'd3;
                        end else begin
                            state <= 3'd1;
                        end
                    end else begin
                        state <= 3'd1;
                    end
                end
            ;
            3'd3: // FOUND
                found <= 1'b1;
                state <= (position == 15 || !char_valid) ? 3'd4 : 3'd3;
            ;
            3'd4: // DONE
                if (!rst_n) state <= 3'd0;
                else begin
                    done <= 1'b1;
                    state <= 3'd4;
                end
            ;
        endcase
    end
end

// Output assignments
assign start_pos = start_pos_reg;
assign end_pos = end_pos_reg;
assign word_out = word_buf;
assign found = found;
assign done = (state == 3'd4);

endmodule