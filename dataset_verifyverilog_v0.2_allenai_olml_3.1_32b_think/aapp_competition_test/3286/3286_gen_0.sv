module robber_language_decoder (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] char_in,
    input [15:0] str_len,
    output reg [31:0] result,
    output reg done,
    output reg error
);

// Internal registers
reg [7:0] buffer [15:0];
reg [31:0] dp [0:16]; // dp[0..length]
reg [15:0] read_count;
reg [15:0] process_i;
reg [15:0] captured_str_len;
reg [31:0] final_result;
reg done_reg;
reg error_reg;
reg [2:0] state; // IDLE=0, READING=1, PROCESSING=2, CALCULATING=3, DONE=4

// State machine logic
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        buffer <= 16'd0;
        dp <= 17'd0; // Initialize all to 0
        read_count <= 16'd0;
        process_i <= 16'd0;
        captured_str_len <= 16'd0;
        final_result <= 32'd0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
        state <= 3'd0; // IDLE
    end else begin
        case(state)
            // IDLE state
            3'd0: begin
                if (start) begin
                    // Capture the current str_len
                    captured_str_len <= str_len;
                    if (captured_str_len == 16'd0) begin
                        // Empty string, result is 1
                        final_result <= 32'd1;
                        // Transition to CALCULATING to add latency
                        state <= 3'd3; // CALCULATING
                    end else if (captured_str_len > 16) begin
                        // Invalid length
                        error_reg <= 1'b1;
                        done_reg <= 1'b1;
                        state <= 3'd4; // DONE
                    end else begin
                        // Valid length, start reading
                        // Initialize registers
                        buffer <= 16'd0;
                        read_count <= 16'd0;
                        process_i <= 16'd0;
                        dp <= 17'd0;
                        final_result <= 32'd0;
                        done_reg <= 1'b0;
                        error_reg <= 1'b0;
                        state <= 3'd1; // READING
                    end
                end else begin
                    // Stay in IDLE
                    state <= 3'd0;
                end
            end
            // READING state: read characters into buffer
            3'd1: begin
                if (read_count < captured_str_len) begin
                    buffer[read_count] <= char_in;
                    read_count <= read_count + 1'd1;
                    state <= 3'd1; // stay in READING
                end else begin
                    // All characters read, move to PROCESSING
                    // Initialize dp[0] =1
                    dp <= {1'd1, 16'd0}; // dp[0]=1, others 0. But if captured_str_len is 0, this path isn't taken.
                    process_i <= 16'd0;
                    state <= 3'd2; // PROCESSING
                end
            end
            // PROCESSING state: compute DP
            3'd2: begin
                if (process_i < captured_str_len) begin
                    // Get current character
                    logic [7:0] current_char = buffer[process_i];
                    if ( (current_char == 'a' || current_char == 'e' || current_char == 'i' || current_char == 'o' || current_char == 'u') ) begin
                        if (process_i + 1 <= captured_str_len) begin
                            dp[process_i + 1] = (dp[process_i + 1] + dp[process_i]) % 1000009;
                        end
                    end else begin // consonant
                        // Option1: move +1
                        if (process_i + 1 <= captured_str_len) begin
                            dp[process_i + 1] = (dp[process_i + 1] + dp[process_i]) % 1000009;
                        end
                        // Option2: check for C+o+C pattern
                        if (process_i + 2 < captured_str_len) begin
                            if (buffer[process_i + 1] == 'o' && !( (buffer[process_i + 2] == 'a' || buffer[process_i + 2] == 'e' || buffer[process_i + 2] == 'i' || buffer[process_i + 2] == 'o' || buffer[process_i + 2] == 'u') )) begin
                                if (process_i + 3 <= captured_str_len) begin
                                    dp[process_i + 3] = (dp[process_i + 3] + dp[process_i]) % 1000009;
                                end
                            end
                        end
                    end
                    // Move to next position
                    process_i <= process_i + 1'd1;
                    state <= 3'd2; // stay in PROCESSING
                end else begin
                    // Finished processing, move to CALCULATING
                    final_result <= dp[captured_str_len];
                    state <= 3'd3; // CALCULATING
                end
            end
            // CALCULATING state: transition to DONE
            3'd3: begin
                // For empty string case, final_result was set in IDLE
                // Just move to DONE
                done_reg <= 1'b1;
                state <= 3'd4; // DONE
            end
            // DONE state: no action, stay there
            3'd4: begin
                // Remain in DONE
                state <= 3'd4;
            end
        endcase
    end
end

assign result = final_result;
assign done = done_reg;
assign error = error_reg;

endmodule