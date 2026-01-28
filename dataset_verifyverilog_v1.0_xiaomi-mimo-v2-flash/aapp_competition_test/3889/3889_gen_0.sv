module hasDuplicate(
    input clk,
    input rst_n,
    input start,
    input [7:0] s_0, s_1, s_2, s_3, s_4, s_5, s_6, s_7,
    input [7:0] s_8, s_9, s_10, s_11, s_12, s_13, s_14, s_15,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET_ARRAY = 3'd1;
    localparam [2:0] PROCESSING = 3'd2;
    localparam [2:0] CHECKING = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i;                          // Character index (0 to 15)
    reg [3:0] counts [0:25];              // 26 elements, 4-bit each
    reg [3:0] j;                          // Index for checking counts
    reg [7:0] current_char;               // Buffer for current character
    reg temp_result;                      // Temporary result during check
    reg [8:0] cycle_count;                // Cycle counter (max 200)
    localparam [8:0] MAX_CYCLES = 9'd200;
    reg [3:0] array_idx;                  // Array index for current character
    reg found_duplicate;                  // Flag for duplicate found

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            current_char <= 8'd0;
            temp_result <= 1'b0;
            cycle_count <= 9'd0;
            array_idx <= 4'd0;
            found_duplicate <= 1'b0;
            // Reset all counts to 0
            for (int k = 0; k < 26; k = k + 1) begin
                counts[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 9'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    found_duplicate <= 1'b0;
                    if (start) begin
                        state <= RESET_ARRAY;
                    end
                end

                RESET_ARRAY: begin
                    // Reset counts array to all zeros
                    if (j < 4'd26) begin
                        counts[j] <= 4'd0;
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= 4'd0;
                        if (len == 4'd1) begin
                            // Special case: if len == 1, result is 1
                            temp_result <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end

                PROCESSING: begin
                    if (cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 9'd1;
                    end

                    if (i < len) begin
                        // Get current character based on index i
                        case (i)
                            4'd0: current_char <= s_0;
                            4'd1: current_char <= s_1;
                            4'd2: current_char <= s_2;
                            4'd3: current_char <= s_3;
                            4'd4: current_char <= s_4;
                            4'd5: current_char <= s_5;
                            4'd6: current_char <= s_6;
                            4'd7: current_char <= s_7;
                            4'd8: current_char <= s_8;
                            4'd9: current_char <= s_9;
                            4'd10: current_char <= s_10;
                            4'd11: current_char <= s_11;
                            4'd12: current_char <= s_12;
                            4'd13: current_char <= s_13;
                            4'd14: current_char <= s_14;
                            4'd15: current_char <= s_15;
                            default: current_char <= 8'd0;
                        endcase
                        
                        // Calculate array index: char - 'a'
                        if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            array_idx <= current_char - 8'd97;
                        end
                        
                        i <= i + 4'd1;
                    end else begin
                        // Finished processing all characters
                        j <= 4'd0;
                        state <= CHECKING;
                    end
                end

                CHECKING: begin
                    if (cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 9'd1;
                    end

                    if (j < 4'd26) begin
                        // Check if any count >= 2
                        if (counts[j] >= 4'd2) begin
                            found_duplicate <= 1'b1;
                        end
                        j <= j + 4'd1;
                    end else begin
                        // Final result
                        temp_result <= found_duplicate;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update counts array (separate combinational logic for actual increment)
            // This is handled in a separate combinational block below
        end
    end

    // Combinational logic to increment counts
    always @(*) begin
        if (state == PROCESSING && i < len) begin
            // Determine current character
            case (i)
                4'd0: current_char = s_0;
                4'd1: current_char = s_1;
                4'd2: current_char = s_2;
                4'd3: current_char = s_3;
                4'd4: current_char = s_4;
                4'd5: current_char = s_5;
                4'd6: current_char = s_6;
                4'd7: current_char = s_7;
                4'd8: current_char = s_8;
                4'd9: current_char = s_9;
                4'd10: current_char = s_10;
                4'd11: current_char = s_11;
                4'd12: current_char = s_12;
                4'd13: current_char = s_13;
                4'd14: current_char = s_14;
                4'd15: current_char = s_15;
                default: current_char = 8'd0;
            endcase
            
            // Check if valid lowercase letter
            if (current_char >= 8'd97 && current_char <= 8'd122) begin
                array_idx = current_char - 8'd97;
            end
        end
    end

    // Sequential logic to actually update counts array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == PROCESSING && i < len) begin
                // Increment the count for current character
                if (current_char >= 8'd97 && current_char <= 8'd122) begin
                    counts[array_idx] <= counts[array_idx] + 4'd1;
                end
            end
        end
    end

endmodule