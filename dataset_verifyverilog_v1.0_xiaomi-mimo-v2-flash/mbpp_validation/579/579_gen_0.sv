module symmetric_difference (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_a [0:7],
    input [7:0] arr_b [0:7],
    input [3:0] len_a,
    input [3:0] len_b,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] OUTPUT_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] idx_a;      // Index for arr_a (0-7)
    reg [3:0] idx_b;      // Index for arr_b (0-7)
    reg [3:0] res_idx;    // Index for result array (0-15)
    reg [3:0] cycle_count; // Prevent infinite loops
    
    // Flags to track element presence
    reg found_in_a;
    reg found_in_b;
    reg skip_element;
    
    // Temporary storage for current element from arr_a
    reg [7:0] current_elem;
    
    // Combinational logic for checking presence in arr_b
    wire found_in_b_wire;
    assign found_in_b_wire = (idx_b < len_b) && (arr_b[idx_b] == current_elem);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            idx_a <= 4'd0;
            idx_b <= 4'd0;
            res_idx <= 4'd0;
            cycle_count <= 4'd0;
            current_elem <= 8'd0;
            found_in_a <= 1'b0;
            found_in_b <= 1'b0;
            skip_element <= 1'b0;
            
            // Initialize result array to zeros
            result[0] <= 8'd0; result[1] <= 8'd0; result[2] <= 8'd0; result[3] <= 8'd0;
            result[4] <= 8'd0; result[5] <= 8'd0; result[6] <= 8'd0; result[7] <= 8'd0;
            result[8] <= 8'd0; result[9] <= 8'd0; result[10] <= 8'd0; result[11] <= 8'd0;
            result[12] <= 8'd0; result[13] <= 8'd0; result[14] <= 8'd0; result[15] <= 8'd0;
            
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Start new computation
                        state <= COMPARE;
                        idx_a <= 4'd0;
                        res_idx <= 4'd0;
                        cycle_count <= 4'd0;
                        result_len <= 4'd0;
                        
                        // Initialize result array
                        result[0] <= 8'd0; result[1] <= 8'd0; result[2] <= 8'd0; result[3] <= 8'd0;
                        result[4] <= 8'd0; result[5] <= 8'd0; result[6] <= 8'd0; result[7] <= 8'd0;
                        result[8] <= 8'd0; result[9] <= 8'd0; result[10] <= 8'd0; result[11] <= 8'd0;
                        result[12] <= 8'd0; result[13] <= 8'd0; result[14] <= 8'd0; result[15] <= 8'd0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check for timeout (max 50 cycles)
                    if (cycle_count >= 4'd49) begin
                        state <= OUTPUT_STATE;
                    end else if (idx_a < len_a) begin
                        // Process element from arr_a
                        current_elem <= arr_a[idx_a];
                        
                        // Skip if element is 0 (padding)
                        if (arr_a[idx_a] == 8'd0) begin
                            skip_element <= 1'b1;
                        end else begin
                            skip_element <= 1'b0;
                            
                            // Check if this element exists in arr_b
                            // Reset found flags
                            found_in_a <= 1'b1;  // Found in arr_a by definition
                            found_in_b <= 1'b0;
                            
                            // Inner loop to check arr_b
                            if (idx_b < len_b) begin
                                if (found_in_b_wire) begin
                                    found_in_b <= 1'b1;
                                end
                                idx_b <= idx_b + 4'd1;
                            end else begin
                                // Finished checking arr_b
                                idx_b <= 4'd0;
                                
                                // If element appears in exactly one tuple, add to result
                                if (found_in_a && !found_in_b && res_idx < 4'd16) begin
                                    result[res_idx] <= current_elem;
                                    res_idx <= res_idx + 4'd1;
                                    result_len <= result_len + 4'd1;
                                end
                                
                                // Move to next element in arr_a
                                idx_a <= idx_a + 4'd1;
                            end
                        end
                    end else if (idx_a >= len_a) begin
                        // Done with arr_a, need to check elements in arr_b that are not in arr_a
                        // Reset for next phase
                        if (idx_b < len_b) begin
                            current_elem <= arr_b[idx_b];
                            
                            // Skip if element is 0
                            if (arr_b[idx_b] == 8'd0) begin
                                skip_element <= 1'b1;
                            end else begin
                                skip_element <= 1'b0;
                                
                                // Check if this element exists in arr_a
                                found_in_b <= 1'b1;
                                found_in_a <= 1'b0;
                                
                                // Inner loop to check arr_a
                                if (idx_a < len_a) begin
                                    // Need to search arr_a again
                                    if (arr_a[idx_a] == arr_b[idx_b]) begin
                                        found_in_a <= 1'b1;
                                    end
                                    idx_a <= idx_a + 4'd1;
                                end else begin
                                    // Finished checking arr_a for this element
                                    // Reset idx_a for next element in arr_b
                                    idx_a <= 4'd0;
                                    
                                    // If element appears in exactly one tuple, add to result
                                    if (found_in_b && !found_in_a && res_idx < 4'd16) begin
                                        result[res_idx] <= arr_b[idx_b];
                                        res_idx <= res_idx + 4'd1;
                                        result_len <= result_len + 4'd1;
                                    end
                                    
                                    // Move to next element in arr_b
                                    idx_b <= idx_b + 4'd1;
                                end
                            end
                        end else begin
                            // All elements processed
                            state <= OUTPUT_STATE;
                        end
                    end
                end
                
                OUTPUT_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    idx_a <= 4'd0;
                    idx_b <= 4'd0;
                    res_idx <= 4'd0;
                    cycle_count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule