module find_max_frequency_match(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [8:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_INIT = 3'd1;
    localparam [2:0] SORT_PASS = 3'd2;
    localparam [2:0] EVAL_COUNT = 3'd3;
    localparam [2:0] EVAL_CHECK = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    localparam [2:0] ERROR = 3'd6;

    reg [2:0] state, next_state;
    
    // Sorting registers
    reg [7:0] sorted_data [0:15];
    reg [3:0] sort_idx;
    reg [7:0] temp_val;
    
    // Evaluation registers
    reg [7:0] current_val;
    reg [7:0] current_count;
    reg [7:0] scan_idx;
    reg [8:0] best_match;
    
    // Cycle counter for timeout protection
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;
    
    // Helper signals
    reg swap_needed;
    
    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 9'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                sorted_data[i] <= 8'd0;
            end
            
            sort_idx <= 4'd0;
            temp_val <= 8'd0;
            current_val <= 8'd0;
            current_count <= 8'd0;
            scan_idx <= 4'd0;
            best_match <= 9'd0;
            swap_needed <= 1'b0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    best_match <= 9'd0;
                    
                    if (start) begin
                        // Initialize sorting buffer with input
                        sorted_data[0] <= arr[0];
                        sorted_data[1] <= arr[1];
                        sorted_data[2] <= arr[2];
                        sorted_data[3] <= arr[3];
                        sorted_data[4] <= arr[4];
                        sorted_data[5] <= arr[5];
                        sorted_data[6] <= arr[6];
                        sorted_data[7] <= arr[7];
                        sorted_data[8] <= arr[8];
                        sorted_data[9] <= arr[9];
                        sorted_data[10] <= arr[10];
                        sorted_data[11] <= arr[11];
                        sorted_data[12] <= arr[12];
                        sorted_data[13] <= arr[13];
                        sorted_data[14] <= arr[14];
                        sorted_data[15] <= arr[15];
                        
                        sort_idx <= 4'd0;
                        scan_idx <= 4'd0;
                        current_count <= 8'd0;
                        state <= SORT_INIT;
                    end
                end
                
                SORT_INIT: begin
                    // Initialize for bubble sort pass
                    sort_idx <= 4'd0;
                    cycle_count <= cycle_count + 10'd1;
                    state <= SORT_PASS;
                end
                
                SORT_PASS: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Bubble sort: compare adjacent elements
                    if (sort_idx < len - 4'd1) begin
                        if (sorted_data[sort_idx] > sorted_data[sort_idx + 4'd1]) begin
                            // Swap
                            temp_val <= sorted_data[sort_idx];
                            sorted_data[sort_idx] <= sorted_data[sort_idx + 4'd1];
                            sorted_data[sort_idx + 4'd1] <= temp_val;
                            swap_needed <= 1'b1;
                        end else begin
                            swap_needed <= 1'b0;
                        end
                        sort_idx <= sort_idx + 4'd1;
                        state <= SORT_PASS;
                    end else begin
                        // End of pass
                        if (swap_needed) begin
                            // Need another pass
                            state <= SORT_INIT;
                        end else begin
                            // Sorting complete
                            state <= EVAL_COUNT;
                        end
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                EVAL_COUNT: begin
                    // Count frequency of current value
                    if (scan_idx < len) begin
                        current_val <= sorted_data[scan_idx];
                        current_count <= 8'd1;
                        scan_idx <= scan_idx + 4'd1;
                        state <= EVAL_CHECK;
                    end else begin
                        // Done evaluating all values
                        state <= DONE_STATE;
                    end
                    cycle_count <= cycle_count + 10'd1;
                end
                
                EVAL_CHECK: begin
                    // Count consecutive occurrences
                    if (scan_idx < len && sorted_data[scan_idx] == current_val) begin
                        current_count <= current_count + 8'd1;
                        scan_idx <= scan_idx + 4'd1;
                        state <= EVAL_CHECK;
                    end else begin
                        // Check condition: frequency >= value
                        if (current_count >= current_val && current_val > 8'd0) begin
                            // Update best match (take larger value)
                            if ({1'b0, current_val} > best_match) begin
                                best_match <= {1'b0, current_val};
                            end
                        end
                        // Continue to next value
                        state <= EVAL_COUNT;
                    end
                    cycle_count <= cycle_count + 10'd1;
                end
                
                DONE_STATE: begin
                    // Set result
                    if (best_match > 9'd0) begin
                        result <= best_match;
                    end else begin
                        result <= 9'b111111111; // -1 in 9-bit signed
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule