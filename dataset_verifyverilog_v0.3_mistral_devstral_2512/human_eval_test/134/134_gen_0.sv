module check_last_char_letter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] SCAN_STRING = 2'd1;
    localparam [1:0] CHECK_CHAR  = 2'd2;
    localparam [1:0] DONE_STATE  = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index;  // 4-bit index for 16 characters
    reg [7:0] last_char;
    reg [7:0] prev_char;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // Character constants
    localparam [7:0] SPACE = 8'd32;
    localparam [7:0] LOWER_A = 8'd97;
    localparam [7:0] LOWER_Z = 8'd122;
    localparam [7:0] UPPER_A = 8'd65;
    localparam [7:0] UPPER_Z = 8'd90;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            last_char <= 8'd0;
            prev_char <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= SCAN_STRING;
                        index <= 4'd15;  // Start from end of string
                        last_char <= 8'd0;
                        prev_char <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN_STRING: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (index == 4'd0) begin
                        // Reached beginning of string
                        if (last_char == 8'd0) begin
                            // No non-space character found
                            result <= 1'b0;
                            next_state <= DONE_STATE;
                        end else begin
                            // Check if first character is a letter
                            if ((last_char >= LOWER_A && last_char <= LOWER_Z) ||
                                (last_char >= UPPER_A && last_char <= UPPER_Z)) begin
                                result <= 1'b1;
                            end else begin
                                result <= 1'b0;
                            end
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        // Check current character
                        if (char_array[index] != SPACE) begin
                            if (last_char == 8'd0) begin
                                // First non-space character found
                                last_char <= char_array[index];
                                prev_char <= char_array[index - 1];
                            end
                            index <= index - 4'd1;
                        end else begin
                            // Space character
                            if (last_char != 8'd0) begin
                                // Found last non-space character
                                next_state <= CHECK_CHAR;
                            end else begin
                                index <= index - 4'd1;
                            end
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end

                CHECK_CHAR: begin
                    cycle_count <= cycle_count + 4'd1;
                    // Check if last_char is a letter
                    if ((last_char >= LOWER_A && last_char <= LOWER_Z) ||
                        (last_char >= UPPER_A && last_char <= UPPER_Z)) begin
                        // Check if previous character is space or we're at start
                        if (prev_char == SPACE || index == 4'd0) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end else begin
                        result <= 1'b0;
                    end
                    next_state <= DONE_STATE;
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end
endmodule