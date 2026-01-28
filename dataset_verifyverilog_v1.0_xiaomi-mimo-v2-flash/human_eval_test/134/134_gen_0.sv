module check_last_char (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][7:0] char_in,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] SEARCH           = 3'd1;
    localparam [2:0] CHECK_ALPHA      = 3'd2;
    localparam [2:0] VERIFY_BOUNDARY  = 3'd3;
    localparam [2:0] DONE_STATE       = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;              // Current index (0 to 15)
    reg [3:0] index_next;
    reg found_non_space;
    reg found_non_space_next;
    reg is_alpha;
    reg is_alpha_next;
    reg prev_is_space;
    reg prev_is_space_next;
    reg result_reg, result_next;

    // Helper combinational logic to check if character is alphabetical
    always @(*) begin
        // Default: not alphabetical
        is_alpha_next = 1'b0;
        
        // Check ranges A-Z (65-90) and a-z (97-122)
        if ((char_in[index] >= 8'd65 && char_in[index] <= 8'd90) || 
            (char_in[index] >= 8'd97 && char_in[index] <= 8'd122)) begin
            is_alpha_next = 1'b1;
        end
    end

    // Helper combinational logic to check if character is space
    always @(*) begin
        // Check previous character if valid
        prev_is_space_next = 1'b0;
        if (index > 0) begin
            if (char_in[index - 1] == 8'd32) begin
                prev_is_space_next = 1'b1;
            end
        end
    end

    // FSM State Transition Logic
    always @(*) begin
        next_state = state;
        index_next = index;
        found_non_space_next = found_non_space;
        result_next = result_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    index_next = len;  // Start pointing one past the end
                    found_non_space_next = 1'b0;
                    result_next = 1'b0;
                end
            end

            SEARCH: begin
                if (index == 0) begin
                    // Reached beginning without finding non-space
                    next_state = DONE_STATE;
                    result_next = 1'b0;
                end else begin
                    index_next = index - 4'd1;
                    // Check current character (at new index)
                    if (char_in[index - 4'd1] != 8'd32) begin
                        // Found non-space character
                        found_non_space_next = 1'b1;
                        next_state = CHECK_ALPHA;
                    end
                end
            end

            CHECK_ALPHA: begin
                if (is_alpha) begin
                    // Character is alphabetical, check boundary
                    next_state = VERIFY_BOUNDARY;
                end else begin
                    // Not alphabetical, continue searching
                    if (index == 0) begin
                        // Reached beginning without finding alphabetical
                        next_state = DONE_STATE;
                        result_next = 1'b0;
                    end else begin
                        index_next = index - 4'd1;
                        // Check previous character (at new index)
                        if (char_in[index - 4'd1] != 8'd32) begin
                            found_non_space_next = 1'b1;
                            // Stay in CHECK_ALPHA (re-evaluate new char)
                        end else begin
                            // It's a space, continue searching
                            next_state = SEARCH;
                        end
                    end
                end
            end

            VERIFY_BOUNDARY: begin
                // Check if previous character is space or start of string
                if (index == 0 || prev_is_space) begin
                    result_next = 1'b1;  // NOT part of a word
                end else begin
                    result_next = 1'b0;  // IS part of a word
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                // Wait one cycle to output result
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            found_non_space <= 1'b0;
            is_alpha <= 1'b0;
            prev_is_space <= 1'b0;
            result_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= index_next;
            found_non_space <= found_non_space_next;
            is_alpha <= is_alpha_next;
            prev_is_space <= prev_is_space_next;
            result_reg <= result_next;

            // Output logic
            if (state == DONE_STATE && next_state == IDLE) begin
                result <= result_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule