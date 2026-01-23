module cyclic_decode (
    input clk,
    input rst_n,
    input start,
    input [2:0] str_length,        // Actual length of input string (1-8)
    input [7:0] char_in,           // Current character input (one at a time)
    input char_valid,              // High when char_in is valid
    output reg [7:0] decoded_char, // Decoded character output
    output reg char_out_valid,     // High when decoded_char is valid
    output reg done                // High when entire string is decoded
);

    // State encoding
    localparam IDLE       = 3'b000;
    localparam COLLECTING = 3'b001;
    localparam DECODING   = 3'b010;
    localparam OUTPUTTING = 3'b011;
    localparam DONE       = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Internal registers
    reg [7:0] buffer [0:2];       // Buffer for up to 3 characters
    reg [1:0] buffer_cnt;         // Number of characters currently in buffer (0-3)
    reg [2:0] chars_remaining;    // Total characters left to receive (0-8)
    reg [1:0] output_cnt;         // Counter for outputting characters from buffer
    reg [2:0] group_size;         // Size of the current group being processed

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            decoded_char <= 8'b0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
            buffer[0] <= 8'b0;
            buffer[1] <= 8'b0;
            buffer[2] <= 8'b0;
            buffer_cnt <= 2'b0;
            chars_remaining <= 3'b0;
            output_cnt <= 2'b0;
            group_size <= 3'b0;
        end else begin
            current_state <= next_state;

            // Default outputs
            char_out_valid <= 1'b0;
            done <= 1'b0;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        chars_remaining <= str_length;
                        buffer_cnt <= 2'b0;
                        output_cnt <= 2'b0;
                        done <= 1'b0;
                    end
                end

                COLLECTING: begin
                    if (char_valid && chars_remaining > 0) begin
                        buffer[buffer_cnt] <= char_in;
                        buffer_cnt <= buffer_cnt + 1'b1;
                        chars_remaining <= chars_remaining - 1'b1;
                    end
                end

                DECODING: begin
                    // No register updates needed, just transition
                    // Group size is determined based on remaining count
                    // Logic handled in next_state calculation
                    output_cnt <= 2'b0;
                end

                OUTPUTTING: begin
                    char_out_valid <= 1'b1;
                    output_cnt <= output_cnt + 1'b1;
                    
                    // Determine character to output based on group size and position
                    case (group_size)
                        3'd1: begin
                            // Single character group: input x -> output x
                            decoded_char <= buffer[0];
                        end
                        3'd2: begin
                            // Two character group: input x y -> output x y
                            // output_cnt 0 -> buffer[0], 1 -> buffer[1]
                            decoded_char <= buffer[output_cnt];
                        end
                        3'd3: begin
                            // Three character group: input b c a -> output a b c
                            // Cycle right: buffer[2], buffer[0], buffer[1]
                            // output_cnt 0 -> buffer[2], 1 -> buffer[0], 2 -> buffer[1]
                            case (output_cnt)
                                2'd0: decoded_char <= buffer[2];
                                2'd1: decoded_char <= buffer[0];
                                2'd2: decoded_char <= buffer[1];
                                default: decoded_char <= buffer[2];
                            endcase
                        end
                    endcase
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        group_size = 3'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    if (str_length > 0)
                        next_state = COLLECTING;
                    else
                        next_state = DONE; // Handle empty string case
                end else begin
                    next_state = IDLE;
                end
            end

            COLLECTING: begin
                // Check if we need to collect more or if we have enough to decode
                // Logic: 
                // 1. If buffer_cnt reaches 3, we must decode this full group.
                // 2. If chars_remaining becomes 0, we decode the remaining partial group.
                // 3. Otherwise, keep collecting.
                
                if (buffer_cnt == 3) begin
                    next_state = DECODING;
                    group_size = 3'd3;
                end else if (char_valid && chars_remaining == 0) begin
                    // Just received the last character(s)
                    if (buffer_cnt > 0) begin
                        next_state = DECODING;
                        group_size = {1'b0, buffer_cnt}; // 1, 2, or 3
                    end else begin
                        next_state = DONE; // No chars in buffer (should be caught at start)
                    end
                end else begin
                    // Waiting for more chars or valid signal
                    next_state = COLLECTING;
                end
            end

            DECODING: begin
                // Transition immediately to outputting
                // Determine group size based on buffer_cnt (populated in previous state)
                // We need to know if we are outputting a full group or partial group
                // to control the output counter limit and next state.
                
                if (buffer_cnt == 3) begin
                    group_size = 3'd3;
                end else begin
                    group_size = {1'b0, buffer_cnt}; // 1 or 2
                end
                
                next_state = OUTPUTTING;
            end

            OUTPUTTING: begin
                // Check if all chars in current group are output
                // Standard check: output_cnt reaches group_size
                // For a group of size N, output_cnt goes 0, 1, ... N-1.
                // At N-1, we are outputting the last char. Next cycle output_cnt becomes N.
                
                if (output_cnt == group_size - 1) begin
                    // Last character of this group is being output this cycle
                    if (chars_remaining > 0) begin
                        // More groups to process
                        next_state = COLLECTING;
                    end else begin
                        // No more characters
                        next_state = DONE;
                    end
                end else begin
                    // Still outputting current group
                    next_state = OUTPUTTING;
                end
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule