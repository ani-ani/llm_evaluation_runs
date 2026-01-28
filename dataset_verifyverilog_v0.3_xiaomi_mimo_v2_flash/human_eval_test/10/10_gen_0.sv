module make_palindrome (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input finish_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);
    // State definitions
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_INPUT = 3'd1;
    localparam [2:0] STATE_PROCESS = 3'd2;
    localparam [2:0] STATE_OUTPUT = 3'd3;
    localparam [2:0] STATE_DONE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] length;           // 0-8
    reg [7:0] buffer [0:7];     // Circular buffer
    reg [3:0] out_idx;          // Current index for output
    reg [3:0] append_len;       // Number of chars to append
    reg [3:0] append_start;     // Start index in buffer for appending
    reg output_phase;           // 0: output original, 1: output append
    reg found_palindrome;       // Flag for processing
    reg [3:0] i;                // Loop counter for processing
    reg [3:0] j;                // Loop counter for palindrome check
    reg is_pal;                 // Palindrome check result

    // Integer for loop indices
    integer k;

    // FSM Transition
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_INPUT;
                else
                    next_state = STATE_IDLE;
            end
            STATE_INPUT: begin
                if (finish_in || (length == 8))
                    next_state = STATE_PROCESS;
                else
                    next_state = STATE_INPUT;
            end
            STATE_PROCESS: begin
                next_state = STATE_OUTPUT;
            end
            STATE_OUTPUT: begin
                if (output_phase && (out_idx >= append_len))
                    next_state = STATE_DONE;
                else if (!output_phase && (out_idx >= length))
                    next_state = STATE_OUTPUT;
                else
                    next_state = STATE_OUTPUT;
            end
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            length <= 4'd0;
            out_idx <= 4'd0;
            append_len <= 4'd0;
            append_start <= 4'd0;
            output_phase <= 1'b0;
            found_palindrome <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            is_pal <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                buffer[k] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    if (start) begin
                        length <= 4'd0;
                        out_idx <= 4'd0;
                        append_len <= 4'd0;
                        output_phase <= 1'b0;
                        found_palindrome <= 1'b0;
                        // Initialize buffer (clear previous content)
                        for (k = 0; k < 8; k = k + 1) begin
                            buffer[k] <= 8'd0;
                        end
                    end
                end

                STATE_INPUT: begin
                    if (valid_in && (length < 8)) begin
                        buffer[length] <= char_in;
                        length <= length + 4'd1;
                    end
                end

                STATE_PROCESS: begin
                    // Start checking for suffix palindromes
                    if (length == 0) begin
                        append_len <= 4'd0;
                        found_palindrome <= 1'b1;
                    end else begin
                        // Initialize check for longest suffix (length-1)
                        i <= length;
                        found_palindrome <= 1'b0;
                    end
                end

                STATE_OUTPUT: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    
                    if (!output_phase) begin
                        // Output original string
                        if (out_idx < length) begin
                            char_out <= buffer[out_idx];
                            valid_out <= 1'b1;
                            out_idx <= out_idx + 4'd1;
                        end else begin
                            // Finished original, switch to append
                            output_phase <= 1'b1;
                            out_idx <= 4'd0;
                        end
                    end else begin
                        // Output appended string
                        if (out_idx < append_len) begin
                            // Append is buffer[0] to buffer[append_len-1] reversed
                            // So append[0] = buffer[append_len-1]
                            char_out <= buffer[append_len - 1 - out_idx];
                            valid_out <= 1'b1;
                            out_idx <= out_idx + 4'd1;
                        end
                    end
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase

            // Combinational processing logic embedded in sequential block
            // (Icarus Verilog requires blocking assignments for complex logic)
            if (state == STATE_PROCESS) begin
                if (found_palindrome == 1'b0) begin
                    // We are iterating i from length down to 1
                    // But we need to simulate the loop execution step-by-step
                    // Since we can't use 'break', we use 'found_palindrome' as a flag
                    // and 'i' as the current length of suffix being checked
                    
                    // We need to check if suffix buffer[length-i : length-1] is palindrome
                    // This requires a nested loop which is hard to unroll in pure RTL without blocking
                    // We will simulate the check using state variables
                    
                    // To avoid complex nested loops in pure RTL which can cause timing issues,
                    // we use a combinatorial check for the current 'i' iteration
                    
                    // Check if buffer[j] == buffer[length-1-j] for j=0 to (i-1)/2
                    // We simulate this with j counter
                    
                    if (i > 0) begin
                        if (j < (i >> 1)) begin
                            if (buffer[j] == buffer[length - 1 - j]) begin
                                j <= j + 4'd1;
                            end else begin
                                // Not a palindrome for this i, try next i
                                j <= 4'd0;
                                i <= i - 4'd1;
                            end
                        end else begin
                            // Palindrome found
                            found_palindrome <= 1'b1;
                            append_len <= length - i;
                            append_start <= 0; // Always start from 0 for the prefix to append
                            j <= 4'd0;
                        end
                    end else begin
                        // i reached 0, should not happen if logic correct, but safety
                        found_palindrome <= 1'b1;
                        append_len <= length;
                        append_start <= 0;
                    end
                end
            end else if (state == STATE_IDLE && start) begin
                 // Reset counters for processing
                 j <= 4'd0;
            end
        end
    end

endmodule