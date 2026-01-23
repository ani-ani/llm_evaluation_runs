module check_last_char_letter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN_STRING = 2'd1;
    localparam [1:0] CHECK_CHAR = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;           // 0-15 for array access
    reg [7:0] char_found;      // Last non-space character found
    reg [3:0] index_found;     // Index of last non-space character
    reg is_letter;             // Flag if char is letter
    reg is_first_char;         // Flag if it's the first non-space character
    reg [3:0] scan_count;      // Counter for 16 characters (4 bits = 0-15)
    reg [5:0] cycle_count;     // Cycle counter for 20 cycle latency

    // Reset and state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            char_found <= 8'd0;
            index_found <= 4'd0;
            is_letter <= 1'b0;
            is_first_char <= 1'b0;
            scan_count <= 4'd0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    index <= 4'd15;
                    char_found <= 8'd0;
                    index_found <= 4'd0;
                    is_letter <= 1'b0;
                    is_first_char <= 1'b0;
                    scan_count <= 4'd0;
                    cycle_count <= 6'd0;
                end
                SCAN_STRING: begin
                    if (char_array[index] != 8'd32) begin
                        char_found <= char_array[index];
                        index_found <= index;
                    end
                    if (index > 4'd0) begin
                        index <= index - 4'd1;
                    end
                    scan_count <= scan_count + 4'd1;
                end
                CHECK_CHAR: begin
                    // Check if character is letter (a-z or A-Z)
                    if ((char_found >= 8'd97 && char_found <= 8'd122) || 
                        (char_found >= 8'd65 && char_found <= 8'd90)) begin
                        is_letter <= 1'b1;
                    end else begin
                        is_letter <= 1'b0;
                    end
                    // Check if it's the first character (no char before it)
                    if (index_found == 4'd15 || index_found == 4'd0) begin
                        // If first char in string, need to check if it's actually the first non-space
                        // We'll check if all chars after it are spaces
                        is_first_char <= 1'b1;  // Assume first initially
                        index <= 4'd0;
                    end else begin
                        is_first_char <= 1'b0;
                        index <= index_found - 4'd1;
                    end
                end
                DONE: begin
                    if (is_letter && (is_first_char || char_array[index_found + 4'd1] == 8'd32)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    cycle_count <= cycle_count + 6'd1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN_STRING;
                end
            end
            SCAN_STRING: begin
                // Scan all 16 characters or until we find a non-space
                // Continue scanning to ensure we get the LAST non-space
                if (scan_count >= 4'd15) begin
                    // Done scanning all characters
                    if (char_found != 8'd0) begin
                        // Found a non-space character
                        next_state = CHECK_CHAR;
                    end else begin
                        // All spaces
                        next_state = DONE;
                    end
                end else begin
                    next_state = SCAN_STRING;
                end
            end
            CHECK_CHAR: begin
                // Move to done after checking
                next_state = DONE;
            end
            DONE: begin
                // Stay in done for exactly 1 cycle
                if (cycle_count >= 6'd1) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule