module first_non_repeating_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [7:0],
    output reg [7:0] result,
    output reg found,
    output reg done
);

    // Parameters
    parameter CHAR_COUNT = 8;
    
    // State definitions
    localparam IDLE = 3'b001;
    localparam COUNT_CHARS = 3'b010;
    localparam SEARCH_RESULT = 3'b100;
    localparam COMPLETE = 3'b000; // done signal logic handles this
    
    // Internal registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Index counters for loops
    reg [3:0] i_idx; // outer loop index
    reg [3:0] j_idx; // inner loop index
    reg [3:0] search_idx; // search loop index
    
    // Count array to store occurrences (each position tracks its own count)
    // We will compute counts based on comparing positions
    reg [3:0] count_array [7:0];
    
    // Flag to indicate if current position has been processed
    reg processed [7:0];
    
    // Control flags
    reg counting_done;
    reg searching_done;
    reg result_found;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = COUNT_CHARS;
                else
                    next_state = IDLE;
            end
            COUNT_CHARS: begin
                if (counting_done)
                    next_state = SEARCH_RESULT;
                else
                    next_state = COUNT_CHARS;
            end
            SEARCH_RESULT: begin
                if (searching_done)
                    next_state = COMPLETE;
                else
                    next_state = SEARCH_RESULT;
            end
            COMPLETE: begin
                if (start) // Wait for reset or new start cycle
                    next_state = IDLE;
                else
                    next_state = COMPLETE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 8'h00;
            found <= 1'b0;
            done <= 1'b0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            search_idx <= 4'd0;
            counting_done <= 1'b0;
            searching_done <= 1'b0;
            result_found <= 1'b0;
            // Reset count array and processed flags
            for (int k = 0; k < 8; k++) begin
                count_array[k] <= 4'd0;
                processed[k] <= 1'b0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    result <= 8'h00;
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    search_idx <= 4'd0;
                    counting_done <= 1'b0;
                    searching_done <= 1'b0;
                    result_found <= 1'b0;
                    // Clear count array
                    for (int k = 0; k < 8; k++) begin
                        count_array[k] <= 4'd0;
                        processed[k] <= 1'b0;
                    end
                end
                
                COUNT_CHARS: begin
                    // Algorithm: Compare each character with others to count duplicates
                    // Optimization: Single cycle comparison update
                    
                    // If current i_idx is not processed, initialize count to 1
                    if (!processed[i_idx]) begin
                        count_array[i_idx] <= 4'd1; // At least self
                        processed[i_idx] <= 1'b1;
                        j_idx <= i_idx + 1; // Start comparing with next
                    end else begin
                        // Compare character at i_idx with character at j_idx
                        if (j_idx < 8) begin
                            if (char_array[i_idx] == char_array[j_idx]) begin
                                // Found match, increment both counts
                                count_array[i_idx] <= count_array[i_idx] + 1;
                                count_array[j_idx] <= count_array[j_idx] + 1;
                            end
                            j_idx <= j_idx + 1;
                        end else begin
                            // Finished comparing for i_idx
                            if (i_idx < 7) begin
                                i_idx <= i_idx + 1;
                                processed[i_idx + 1] <= 1'b0; // Ensure next is fresh (though logic handles it)
                            end else begin
                                // All characters processed
                                counting_done <= 1'b1;
                            end
                        end
                    end
                end
                
                SEARCH_RESULT: begin
                    // Find first character with count == 1
                    if (search_idx < 8) begin
                        if (count_array[search_idx] == 4'd1) begin
                            result <= char_array[search_idx];
                            found <= 1'b1;
                            result_found <= 1'b1;
                            searching_done <= 1'b1;
                        end else begin
                            search_idx <= search_idx + 1;
                        end
                    end else begin
                        // Reached end, no result found
                        result <= 8'h00;
                        found <= 1'b0;
                        searching_done <= 1'b1;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    // Result and found signals are already set
                end
            endcase
        end
    end

endmodule