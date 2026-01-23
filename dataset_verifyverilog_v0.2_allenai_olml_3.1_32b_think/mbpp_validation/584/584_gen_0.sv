module adverb_finder (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [127:0] text,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg found,
    output reg done
);

localparam IDLE = 3'd0, SCAN = 3'd1, CHECK_LY = 3'd2, VERIFY = 3'd3, DONE = 3'd4;

// Registers
reg [127:0] stored_text;
reg [3:0] current_pos;
reg in_word;
reg [3:0] word_start;
reg [3:0] found_start, found_end;
reg found, done;
reg [4:0] state;

// Next-state and output registers
reg [4:0] state_next;
reg [3:0] found_start_next, found_end_next;
reg found_next, done_next;
reg in_word_next;
reg [3:0] word_start_next;
reg [3:0] current_pos_next;

// Initialize registers on reset
always @(posedge clk) begin
    if (!rst_n) begin
        stored_text <= 128'b0;
        current_pos <= 4'd0;
        in_word <= 1'b0;
        word_start <= 4'd0;
        found_start <= 4'd0;
        found_end <= 4'd0;
        found <= 1'b0;
        done <= 1'b0;
        state <= IDLE;
    end else if (start) begin
        stored_text <= text;
        current_pos <= 4'd0;
        in_word <= 1'b0;
        word_start <= 4'd0;
        found_start <= 4'd0;
        found_end <= 4'd0;
        found <= 1'b0;
        done <= 1'b0;
        state <= SCAN;
    end else begin
        if (state == DONE) begin
            // Stay in DONE
        end else begin
            state <= state;
        end
    end
end

// Combinational logic
always @(*) begin
    state_next = state;
    found_start_next = found_start;
    found_end_next = found_end;
    found_next = found;
    done_next = done;
    in_word_next = in_word;
    word_start_next = word_start;
    current_pos_next = current_pos;

    case (state)
        IDLE: begin
            if (start) begin
                state_next = SCAN;
            end else begin
                state_next = IDLE;
            end
        end
        SCAN: begin
            if (current_pos >= 16) begin
                done_next = 1'b1;
                found_next = 1'b0;
                state_next = DONE;
            end else begin
                int char_val = stored_text >> (current_pos * 8) & 8'hFF;
                if (char_val >= 65 && char_val <= 90 || char_val >= 97 && char_val <= 122) begin
                    if (!in_word) begin
                        in_word_next = 1'b1;
                        word_start_next = current_pos;
                    end
                    in_word_next = 1'b1;
                    current_pos_next = current_pos + 1;
                    state_next = SCAN;
                end else begin
                    in_word_next = 1'b0;
                    current_pos_next = current_pos + 1;
                    state_next = SCAN;
                end

                if (char_val == 8'h6C && in_word) begin
                    current_pos_next = current_pos + 1;
                    state_next = CHECK_LY;
                end
            end
        end
        CHECK_LY: begin
            if (current_pos >= 16) begin
                state_next = SCAN;
                current_pos_next = 16;
            end else begin
                int char_val = stored_text >> (current_pos * 8) & 8'hFF;
                if (char_val == 8'h79) begin
                    found_start_next = word_start;
                    found_end_next = current_pos;
                    found_next = 1'b1;
                    state_next = VERIFY;
                end else begin
                    state_next = SCAN;
                    current_pos_next = current_pos + 1;
                end
            end
        end
        VERIFY: begin
            state_next = DONE;
            done_next = 1'b1;
        end
        DONE: begin
            state_next = DONE;
        end
    endcase
end

// Output assignments
assign start_pos = found_start;
assign end_pos = found_end;

// Update registers
always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        state <= state_next;
        found_start <= found_start_next;
        found_end <= found_end_next;
        found <= found_next;
        done <= done_next;
        in_word <= in_word_next;
        word_start <= word_start_next;
        current_pos <= current_pos_next;
    end
end
endmodule