module pattern_checker (
    input clk,
    input rst_n,
    input start,
    input [63:0] colors_i,
    input [63:0] patterns_i,
    input [2:0] index,
    input valid,
    input last,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam COLLECT = 3'b010;
    localparam VERIFY = 3'b100;
    localparam COMPLETE = 3'b000;
    
    // Registers for State Machine
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Storage for Pattern-Color pairs
    reg [63:0] stored_patterns [0:7];
    reg [63:0] stored_colors [0:7];
    reg [7:0] valid_mask;
    
    // Verification Registers
    reg [2:0] verify_idx;
    reg [3:0] unique_pattern_count;
    reg [3:0] unique_color_count;
    reg [2:0] j_cnt;
    reg current_is_new_pattern;
    reg current_is_new_color;
    
    // Combinational Conflict Detection
    // Checks if the incoming pattern matches a stored pattern with a DIFFERENT color.
    // This allows updates (same pattern/same color) and many-to-one (different pattern/same color).
    // Many-to-one errors are caught in the VERIFY state via count mismatch.
    reg conflict_detect;
    integer i;
    
    always @(*) begin
        conflict_detect = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (valid_mask[i] && (stored_patterns[i] == patterns_i)) begin
                if (stored_colors[i] != colors_i) begin
                    conflict_detect = 1'b1;
                end
            end
        end
    end
    
    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            valid_mask <= 8'b0;
            done <= 1'b0;
            result <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= COLLECT;
                        valid_mask <= 8'b0;
                    end
                end
                
                COLLECT: begin
                    if (valid) begin
                        if (conflict_detect) begin
                            // Same pattern, different color detected -> Fail immediately
                            result <= 1'b1;
                            done <= 1'b1;
                            current_state <= COMPLETE;
                        end else begin
                            // Store the pair
                            stored_patterns[index] <= patterns_i;
                            stored_colors[index] <= colors_i;
                            valid_mask[index] <= 1'b1;
                            
                            // Transition to VERIFY if this is the last element
                            if (last) begin
                                current_state <= VERIFY;
                                verify_idx <= 3'b0;
                                j_cnt <= 3'b0;
                                unique_pattern_count <= 4'd0;
                                unique_color_count <= 4'd0;
                                current_is_new_pattern <= 1'b1;
                                current_is_new_color <= 1'b1;
                            end
                        end
                    end else if (last) begin
                        // Handle edge case where last is asserted without valid (pipeline empty)
                        current_state <= VERIFY;
                        verify_idx <= 3'b0;
                        j_cnt <= 3'b0;
                        unique_pattern_count <= 4'd0;
                        unique_color_count <= 4'd0;
                        current_is_new_pattern <= 1'b1;
                        current_is_new_color <= 1'b1;
                    end
                end
                
                VERIFY: begin
                    if (verify_idx < 8) begin
                        if (valid_mask[verify_idx]) begin
                            if (j_cnt < verify_idx) begin
                                // Compare with previous entries
                                if (stored_patterns[j_cnt] == stored_patterns[verify_idx]) begin
                                    current_is_new_pattern <= 1'b0;
                                end
                                if (stored_colors[j_cnt] == stored_colors[verify_idx]) begin
                                    current_is_new_color <= 1'b0;
                                end
                                j_cnt <= j_cnt + 1;
                            end else begin
                                // Finished comparing this entry (j_cnt == verify_idx)
                                // Update counters based on uniqueness flags
                                if (current_is_new_pattern) begin
                                    unique_pattern_count <= unique_pattern_count + 1;
                                end
                                if (current_is_new_color) begin
                                    unique_color_count <= unique_color_count + 1;
                                end
                                // Move to next index
                                verify_idx <= verify_idx + 1;
                                j_cnt <= 3'b0;
                                // Reset flags for next index
                                current_is_new_pattern <= 1'b1;
                                current_is_new_color <= 1'b1;
                            end
                        end else begin
                            // Current index not valid, skip it
                            verify_idx <= verify_idx + 1;
                            j_cnt <= 3'b0;
                            // Reset flags for next index (just in case)
                            current_is_new_pattern <= 1'b1;
                            current_is_new_color <= 1'b1;
                        end
                    end else begin
                        // Verification Complete (verify_idx == 8)
                        // Check if pattern count equals color count
                        if (unique_pattern_count == unique_color_count) begin
                            result <= 1'b0; // Pass
                        end else begin
                            result <= 1'b1; // Fail (counts mismatch implies many-to-one mapping)
                        end
                        done <= 1'b1;
                        current_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    // Wait for start signal to restart or reset to restart
                    if (start) begin
                        current_state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: current_state <= IDLE;
            endcase
        end
    end

endmodule