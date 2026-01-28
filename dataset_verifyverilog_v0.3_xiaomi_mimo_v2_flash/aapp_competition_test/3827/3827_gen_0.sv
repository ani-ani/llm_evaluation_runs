module string_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] str_len,
    output reg result,
    output reg done
);

    // ASCII definitions
    localparam [7:0] CHAR_A = 8'h61;
    localparam [7:0] CHAR_B = 8'h62;
    localparam [7:0] CHAR_C = 8'h63;

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] STATE_A  = 2'd1;  // Expecting 'a' or transition to 'b'
    localparam [1:0] STATE_B  = 2'd2;  // Expecting 'b' or transition to 'c'
    localparam [1:0] STATE_C  = 2'd3;  // Expecting 'c' only

    reg [1:0] state;
    reg [4:0] idx;          // Index into char_array (0-15)
    reg [4:0] count_a;
    reg [4:0] count_b;
    reg [4:0] count_c;
    reg error_flag;
    reg done_internal;
    reg result_internal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx <= 5'd0;
            count_a <= 5'd0;
            count_b <= 5'd0;
            count_c <= 5'd0;
            error_flag <= 1'b0;
            done_internal <= 1'b0;
            result_internal <= 1'b0;
            done <= 1'b0;
            result <= 1'b0;
        end else begin
            // Default outputs
            done <= 1'b0;
            result <= result_internal;
            
            case (state)
                IDLE: begin
                    done_internal <= 1'b0;
                    result_internal <= 1'b0;
                    idx <= 5'd0;
                    count_a <= 5'd0;
                    count_b <= 5'd0;
                    count_c <= 5'd0;
                    error_flag <= 1'b0;
                    
                    if (start) begin
                        if (str_len == 5'd0) begin
                            // Empty string is invalid
                            error_flag <= 1'b1;
                            done_internal <= 1'b1;
                            result_internal <= 1'b0;
                            state <= IDLE;
                        end else begin
                            state <= STATE_A;
                        end
                    end
                end
                
                STATE_A: begin
                    if (idx < str_len) begin
                        if (char_array[idx] == CHAR_A) begin
                            count_a <= count_a + 5'd1;
                            idx <= idx + 5'd1;
                            // Stay in STATE_A for more 'a's
                        end else if (char_array[idx] == CHAR_B) begin
                            if (count_a == 5'd0) begin
                                // Must have at least one 'a' before 'b'
                                error_flag <= 1'b1;
                            end
                            count_b <= count_b + 5'd1;
                            idx <= idx + 5'd1;
                            state <= STATE_B;  // Transition to 'b' state
                        end else begin
                            // Invalid character or 'c' without 'b'
                            error_flag <= 1'b1;
                            idx <= idx + 5'd1;
                            if (char_array[idx] == CHAR_C) begin
                                state <= STATE_C;
                            end else begin
                                // Skip remaining characters but stay in error state
                                if (idx + 5'd1 >= str_len) begin
                                    done_internal <= 1'b1;
                                    result_internal <= 1'b0;
                                    state <= IDLE;
                                end
                            end
                        end
                    end else begin
                        // End of string in STATE_A
                        done_internal <= 1'b1;
                        if (error_flag || count_a == 5'd0 || count_b == 5'd0) begin
                            result_internal <= 1'b0;
                        end else begin
                            result_internal <= 1'b0;  // No 'c' present
                        end
                        state <= IDLE;
                    end
                end
                
                STATE_B: begin
                    if (idx < str_len) begin
                        if (char_array[idx] == CHAR_B) begin
                            count_b <= count_b + 5'd1;
                            idx <= idx + 5'd1;
                            // Stay in STATE_B for more 'b's
                        end else if (char_array[idx] == CHAR_C) begin
                            if (count_b == 5'd0) begin
                                // Must have at least one 'b' before 'c'
                                error_flag <= 1'b1;
                            end
                            count_c <= count_c + 5'd1;
                            idx <= idx + 5'd1;
                            state <= STATE_C;  // Transition to 'c' state
                        end else begin
                            // Invalid character
                            error_flag <= 1'b1;
                            idx <= idx + 5'd1;
                            // Continue skipping
                            if (idx + 5'd1 >= str_len) begin
                                done_internal <= 1'b1;
                                result_internal <= 1'b0;
                                state <= IDLE;
                            end
                        end
                    end else begin
                        // End of string in STATE_B
                        done_internal <= 1'b1;
                        if (error_flag || count_a == 5'd0 || count_b == 5'd0) begin
                            result_internal <= 1'b0;
                        end else begin
                            result_internal <= 1'b0;  // No 'c' present
                        end
                        state <= IDLE;
                    end
                end
                
                STATE_C: begin
                    if (idx < str_len) begin
                        if (char_array[idx] == CHAR_C) begin
                            count_c <= count_c + 5'd1;
                            idx <= idx + 5'd1;
                            // Stay in STATE_C for more 'c's
                        end else begin
                            // Invalid character after 'c' starts
                            error_flag <= 1'b1;
                            idx <= idx + 5'd1;
                            // Continue skipping
                            if (idx + 5'd1 >= str_len) begin
                                done_internal <= 1'b1;
                                result_internal <= 1'b0;
                                state <= IDLE;
                            end
                        end
                    end else begin
                        // End of string in STATE_C
                        done_internal <= 1'b1;
                        if (error_flag) begin
                            result_internal <= 1'b0;
                        end else if (count_a == 5'd0 || count_b == 5'd0 || count_c == 5'd0) begin
                            result_internal <= 1'b0;
                        end else if (count_c == count_a || count_c == count_b) begin
                            result_internal <= 1'b1;
                        end else begin
                            result_internal <= 1'b0;
                        end
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    error_flag <= 1'b1;
                end
            endcase
            
            // Generate done pulse when done_internal is set
            if (done_internal && !done) begin
                done <= 1'b1;
            end
        end
    end

endmodule