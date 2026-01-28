module sort_third(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [7:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    input wire [3:0] length,
    output reg [7:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output reg [7:0] result_8, result_9, result_10, result_11, result_12, result_13, result_14, result_15,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] temp_array [0:15];
    reg [3:0] pass_count;
    reg [3:0] compare_idx;
    reg [3:0] inner_idx;
    reg [7:0] temp_val;
    reg start_d;
    
    // Indices divisible by 3: 0, 3, 6, 9, 12, 15 (6 elements)
    // We compare these as adjacent pairs: (0,3), (3,6), (6,9), (9,12), (12,15)
    
    // Cycle counter to prevent infinite loops
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    // Helper signals for comparison
    wire signed [7:0] val_a;
    wire signed [7:0] val_b;
    wire needs_swap;
    
    // Map compare_idx to actual array indices
    reg [3:0] idx_a, idx_b;
    
    // Detect start pulse (edge detection)
    wire start_pulse;
    assign start_pulse = start && !start_d;
    
    // Signed comparison logic
    assign needs_swap = (val_a > val_b);
    
    // Assign values based on indices
    always @(*) begin
        case (idx_a)
            4'd0: val_a = temp_array[0];
            4'd3: val_a = temp_array[3];
            4'd6: val_a = temp_array[6];
            4'd9: val_a = temp_array[9];
            4'd12: val_a = temp_array[12];
            4'd15: val_a = temp_array[15];
            default: val_a = 8'sd0;
        endcase
        
        case (idx_b)
            4'd0: val_b = temp_array[0];
            4'd3: val_b = temp_array[3];
            4'd6: val_b = temp_array[6];
            4'd9: val_b = temp_array[9];
            4'd12: val_b = temp_array[12];
            4'd15: val_b = temp_array[15];
            default: val_b = 8'sd0;
        endcase
    end
    
    // Map compare_idx to adjacent third indices
    // compare_idx 0: compare 0 and 3
    // compare_idx 1: compare 3 and 6
    // compare_idx 2: compare 6 and 9
    // compare_idx 3: compare 9 and 12
    // compare_idx 4: compare 12 and 15
    always @(*) begin
        case (compare_idx)
            4'd0: begin idx_a = 4'd0; idx_b = 4'd3; end
            4'd1: begin idx_a = 4'd3; idx_b = 4'd6; end
            4'd2: begin idx_a = 4'd6; idx_b = 4'd9; end
            4'd3: begin idx_a = 4'd9; idx_b = 4'd12; end
            4'd4: begin idx_a = 4'd12; idx_b = 4'd15; end
            default: begin idx_a = 4'd0; idx_b = 4'd3; end
        endcase
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pass_count <= 4'd0;
            compare_idx <= 4'd0;
            inner_idx <= 4'd0;
            cycle_count <= 7'd0;
            done <= 1'b0;
            start_d <= 1'b0;
            
            // Initialize temp_array and result to 0
            result_0 <= 8'sd0; result_1 <= 8'sd0; result_2 <= 8'sd0; result_3 <= 8'sd0;
            result_4 <= 8'sd0; result_5 <= 8'sd0; result_6 <= 8'sd0; result_7 <= 8'sd0;
            result_8 <= 8'sd0; result_9 <= 8'sd0; result_10 <= 8'sd0; result_11 <= 8'sd0;
            result_12 <= 8'sd0; result_13 <= 8'sd0; result_14 <= 8'sd0; result_15 <= 8'sd0;
            
            temp_array[0] <= 8'sd0; temp_array[1] <= 8'sd0; temp_array[2] <= 8'sd0; temp_array[3] <= 8'sd0;
            temp_array[4] <= 8'sd0; temp_array[5] <= 8'sd0; temp_array[6] <= 8'sd0; temp_array[7] <= 8'sd0;
            temp_array[8] <= 8'sd0; temp_array[9] <= 8'sd0; temp_array[10] <= 8'sd0; temp_array[11] <= 8'sd0;
            temp_array[12] <= 8'sd0; temp_array[13] <= 8'sd0; temp_array[14] <= 8'sd0; temp_array[15] <= 8'sd0;
        end else begin
            start_d <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    pass_count <= 4'd0;
                    compare_idx <= 4'd0;
                    inner_idx <= 4'd0;
                    cycle_count <= 7'd0;
                    
                    if (start_pulse) begin
                        // Latch input array into temp_array
                        temp_array[0] <= arr_0;
                        temp_array[1] <= arr_1;
                        temp_array[2] <= arr_2;
                        temp_array[3] <= arr_3;
                        temp_array[4] <= arr_4;
                        temp_array[5] <= arr_5;
                        temp_array[6] <= arr_6;
                        temp_array[7] <= arr_7;
                        temp_array[8] <= arr_8;
                        temp_array[9] <= arr_9;
                        temp_array[10] <= arr_10;
                        temp_array[11] <= arr_11;
                        temp_array[12] <= arr_12;
                        temp_array[13] <= arr_13;
                        temp_array[14] <= arr_14;
                        temp_array[15] <= arr_15;
                        
                        // Copy all to result first (preserve non-third indices)
                        result_0 <= arr_0;
                        result_1 <= arr_1;
                        result_2 <= arr_2;
                        result_3 <= arr_3;
                        result_4 <= arr_4;
                        result_5 <= arr_5;
                        result_6 <= arr_6;
                        result_7 <= arr_7;
                        result_8 <= arr_8;
                        result_9 <= arr_9;
                        result_10 <= arr_10;
                        result_11 <= arr_11;
                        result_12 <= arr_12;
                        result_13 <= arr_13;
                        result_14 <= arr_14;
                        result_15 <= arr_15;
                        
                        state <= SORTING;
                    end
                end
                
                SORTING: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Bubble sort: n-1 passes for n=6 elements
                    // We only need 5 passes for 6 elements (indices 0,3,6,9,12,15)
                    if (pass_count < 4'd5 && cycle_count < MAX_CYCLES) begin
                        // Perform one pass
                        if (compare_idx < 4'd5) begin
                            // Compare and swap adjacent third elements
                            if (needs_swap) begin
                                // Swap values
                                temp_array[idx_a] <= temp_array[idx_b];
                                temp_array[idx_b] <= temp_array[idx_a];
                            end
                            compare_idx <= compare_idx + 4'd1;
                        end else begin
                            // End of pass
                            compare_idx <= 4'd0;
                            pass_count <= pass_count + 4'd1;
                        end
                    end else begin
                        // Sorting complete or timeout
                        // Update result array with sorted third elements
                        result_0 <= temp_array[0];
                        result_3 <= temp_array[3];
                        result_6 <= temp_array[6];
                        result_9 <= temp_array[9];
                        result_12 <= temp_array[12];
                        result_15 <= temp_array[15];
                        
                        state <= DONE;
                    end
                end
                
                DONE: begin
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