module BalancedParenthesesConcat(
    input clk,
    input rst_n,
    input start,
    input [3:0] str1_len,
    input [7:0] str1_char_0, str1_char_1, str1_char_2, str1_char_3,
    input [7:0] str1_char_4, str1_char_5, str1_char_6, str1_char_7,
    input [7:0] str1_char_8, str1_char_9, str1_char_10, str1_char_11,
    input [7:0] str1_char_12, str1_char_13, str1_char_14, str1_char_15,
    input [3:0] str2_len,
    input [7:0] str2_char_0, str2_char_1, str2_char_2, str2_char_3,
    input [7:0] str2_char_4, str2_char_5, str2_char_6, str2_char_7,
    input [7:0] str2_char_8, str2_char_9, str2_char_10, str2_char_11,
    input [7:0] str2_char_12, str2_char_13, str2_char_14, str2_char_15,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_FIRST   = 3'd1;
    localparam [2:0] CHECK_SECOND  = 3'd2;
    localparam [2:0] VALIDATE      = 3'd3;
    localparam [2:0] FINISH        = 3'd4;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [4:0] balance;        // Signed 5-bit: -16 to +16
    reg negative_detected;    // Flag for negative balance
    reg pass_result;          // Result of current pass
    reg [4:0] char_idx;       // Character index (0-31)
    reg [4:0] str_len;        // Current string length
    reg [4:0] pass_count;     // 0 for str1+str2, 1 for str2+str1
    reg [4:0] cycle_count;    // Prevent infinite loops (max 256)
    
    // Temporary storage for current character
    reg [7:0] current_char;
    
    // Arrays for storing characters (indexed 0-15 for each string)
    reg [7:0] str1_chars [0:15];
    reg [7:0] str2_chars [0:15];
    
    // Helper wires for ASCII comparison
    wire is_open_paren;
    wire is_close_paren;
    assign is_open_paren = (current_char == 8'd40);
    assign is_close_paren = (current_char == 8'd41);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            balance <= 5'sd0;
            negative_detected <= 1'b0;
            pass_result <= 1'b0;
            char_idx <= 5'd0;
            str_len <= 5'd0;
            pass_count <= 5'd0;
            cycle_count <= 5'd0;
            current_char <= 8'd0;
            
            // Initialize character arrays
            str1_chars[0] <= 8'd0;
            str1_chars[1] <= 8'd0;
            str1_chars[2] <= 8'd0;
            str1_chars[3] <= 8'd0;
            str1_chars[4] <= 8'd0;
            str1_chars[5] <= 8'd0;
            str1_chars[6] <= 8'd0;
            str1_chars[7] <= 8'd0;
            str1_chars[8] <= 8'd0;
            str1_chars[9] <= 8'd0;
            str1_chars[10] <= 8'd0;
            str1_chars[11] <= 8'd0;
            str1_chars[12] <= 8'd0;
            str1_chars[13] <= 8'd0;
            str1_chars[14] <= 8'd0;
            str1_chars[15] <= 8'd0;
            
            str2_chars[0] <= 8'd0;
            str2_chars[1] <= 8'd0;
            str2_chars[2] <= 8'd0;
            str2_chars[3] <= 8'd0;
            str2_chars[4] <= 8'd0;
            str2_chars[5] <= 8'd0;
            str2_chars[6] <= 8'd0;
            str2_chars[7] <= 8'd0;
            str2_chars[8] <= 8'd0;
            str2_chars[9] <= 8'd0;
            str2_chars[10] <= 8'd0;
            str2_chars[11] <= 8'd0;
            str2_chars[12] <= 8'd0;
            str2_chars[13] <= 8'd0;
            str2_chars[14] <= 8'd0;
            str2_chars[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input strings into internal arrays
                        str1_chars[0] <= str1_char_0;
                        str1_chars[1] <= str1_char_1;
                        str1_chars[2] <= str1_char_2;
                        str1_chars[3] <= str1_char_3;
                        str1_chars[4] <= str1_char_4;
                        str1_chars[5] <= str1_char_5;
                        str1_chars[6] <= str1_char_6;
                        str1_chars[7] <= str1_char_7;
                        str1_chars[8] <= str1_char_8;
                        str1_chars[9] <= str1_char_9;
                        str1_chars[10] <= str1_char_10;
                        str1_chars[11] <= str1_char_11;
                        str1_chars[12] <= str1_char_12;
                        str1_chars[13] <= str1_char_13;
                        str1_chars[14] <= str1_char_14;
                        str1_chars[15] <= str1_char_15;
                        
                        str2_chars[0] <= str2_char_0;
                        str2_chars[1] <= str2_char_1;
                        str2_chars[2] <= str2_char_2;
                        str2_chars[3] <= str2_char_3;
                        str2_chars[4] <= str2_char_4;
                        str2_chars[5] <= str2_char_5;
                        str2_chars[6] <= str2_char_6;
                        str2_chars[7] <= str2_char_7;
                        str2_chars[8] <= str2_char_8;
                        str2_chars[9] <= str2_char_9;
                        str2_chars[10] <= str2_char_10;
                        str2_chars[11] <= str2_char_11;
                        str2_chars[12] <= str2_char_12;
                        str2_chars[13] <= str2_char_13;
                        str2_chars[14] <= str2_char_14;
                        str2_chars[15] <= str2_char_15;
                        
                        // Reset processing state
                        balance <= 5'sd0;
                        negative_detected <= 1'b0;
                        pass_result <= 1'b0;
                        char_idx <= 5'd0;
                        pass_count <= 5'd0;
                        cycle_count <= 5'd0;
                        result <= 1'b0;
                    end
                end
                
                CHECK_FIRST: begin
                    // Get current character based on pass_count
                    if (pass_count == 5'd0) begin
                        // Check str1 + str2
                        if (char_idx < str1_len) begin
                            current_char <= str1_chars[char_idx];
                        end else begin
                            if (char_idx < 5'd16 + str2_len) begin
                                current_char <= str2_chars[char_idx - str1_len];
                            end
                        end
                    end else begin
                        // Check str2 + str1
                        if (char_idx < str2_len) begin
                            current_char <= str2_chars[char_idx];
                        end else begin
                            if (char_idx < 5'd16 + str1_len) begin
                                current_char <= str1_chars[char_idx - str2_len];
                            end
                        end
                    end
                    
                    // Process character
                    if (is_open_paren) begin
                        balance <= balance + 5'sd1;
                    end else if (is_close_paren) begin
                        balance <= balance - 5'sd1;
                        // Check for negative (don't update negative_detected yet)
                    end
                    
                    char_idx <= char_idx + 5'd1;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                CHECK_SECOND: begin
                    // Check if balance went negative in this cycle
                    if (is_close_paren && balance < 5'sd0) begin
                        negative_detected <= 1'b1;
                    end
                end
                
                VALIDATE: begin
                    // Determine result of current pass
                    // Pass succeeds if: final balance == 0 AND never went negative
                    if (balance == 5'sd0 && !negative_detected) begin
                        pass_result <= 1'b1;
                    end else begin
                        pass_result <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= pass_result;
                end
            endcase
        end
    end

    always @(*) begin
        // Default next state
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_FIRST;
                end
            end
            
            CHECK_FIRST: begin
                // Check if we've processed all characters for this pass
                if (pass_count == 5'd0) begin
                    // First pass: str1 + str2
                    if (char_idx >= str1_len + str2_len) begin
                        next_state = VALIDATE;
                    end else begin
                        next_state = CHECK_SECOND;
                    end
                end else begin
                    // Second pass: str2 + str1
                    if (char_idx >= str2_len + str1_len) begin
                        next_state = VALIDATE;
                    end else begin
                        next_state = CHECK_SECOND;
                    end
                end
                
                // Safety: prevent infinite loops
                if (cycle_count >= 5'd20) begin
                    next_state = VALIDATE;
                end
            end
            
            CHECK_SECOND: begin
                next_state = CHECK_FIRST;
            end
            
            VALIDATE: begin
                // Check if we need to do second pass
                if (pass_count == 5'd0) begin
                    // If first pass succeeded, we're done
                    if (pass_result) begin
                        next_state = FINISH;
                    end else begin
                        // Otherwise do second pass
                        next_state = CHECK_FIRST;
                    end
                end else begin
                    // Second pass done, go to finish
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                // Return to IDLE when done pulse completes
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Handle pass transition in VALIDATE
        if (state == VALIDATE && pass_count == 5'd0 && !pass_result) begin
            // Reset for second pass
            next_state = CHECK_FIRST;
        end
    end

endmodule