module count_distinct_subsets (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] x_i,
    input wire [7:0] y_i,
    input wire valid_i,
    input wire done_i,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INPUT_POINTS  = 3'd1;
    localparam [2:0] SORT_X        = 3'd2;
    localparam [2:0] GET_UNIQUE_X  = 3'd3;
    localparam [2:0] ENUMERATE     = 3'd4;
    localparam [2:0] COUNT_SUBSETS = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    reg [2:0] state, next_state;
    
    // Input buffer: store all points
    reg [7:0] x_reg [0:15];  // x coordinates
    reg [7:0] y_reg [0:15];  // y coordinates
    reg [3:0] point_count;   // Number of points received (≤16)
    reg [3:0] input_index;   // Current input index
    
    // Sorting registers
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp_x, temp_y;
    reg sorting_done;
    
    // Unique X extraction registers
    reg [7:0] unique_x [0:15];  // Sorted unique x values
    reg [3:0] unique_count;     // Number of unique x values
    reg [3:0] unique_idx;
    reg [3:0] scan_idx;
    reg extraction_done;
    
    // Enumeration registers (for left/right x boundaries)
    reg [3:0] left_ptr;
    reg [3:0] right_ptr;
    reg [3:0] point_idx;
    reg [15:0] subset_bitset;  // 16-bit bitset for current subset
    reg [15:0] prev_bitset;    // Previous bitset for comparison
    reg subset_valid;
    reg counting_done;
    
    // Accumulation registers
    reg [15:0] acc_count;      // Accumulated result
    reg [15:0] local_count;    // Count for current (left,right) pair
    reg comparison_done;
    reg [3:0] y_idx;           // Index for sorting y values
    reg [3:0] y_sort_idx;      // For y-sorting logic
    reg [7:0] y_values [0:15]; // Y values of current subset
    reg [3:0] y_sub_count;     // Count of points in current subset
    reg [3:0] y_sorted_idx;    // Index for sorting loop
    reg [3:0] threshold_idx;   // Index for threshold enumeration
    reg [15:0] threshold_mask; // Mask for current threshold
    reg [3:0] distinct_count;  // Count of distinct subsets for current (left,right)
    reg [15:0] seen_masks [0:15]; // Store seen masks (max 16)
    reg [3:0] seen_count;      // Number of seen masks
    reg [3:0] seen_idx;
    reg mask_found;
    reg threshold_loop_done;
    
    // Cycle counter for timeout prevention
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            point_count <= 4'd0;
            input_index <= 4'd0;
            acc_count <= 16'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;  // done is pulsed, default 0
            cycle_counter <= cycle_counter + 8'd1;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    result <= 16'd0;
                    if (start) begin
                        point_count <= 4'd0;
                        input_index <= 4'd0;
                    end
                end
                
                INPUT_POINTS: begin
                    if (valid_i && input_index < 4'd16) begin
                        x_reg[input_index] <= x_i;
                        y_reg[input_index] <= y_i;
                        input_index <= input_index + 4'd1;
                    end
                    if (done_i) begin
                        point_count <= input_index;
                    end
                end
                
                SORT_X: begin
                    // Bubble sort: sort by x, then y (stable)
                    if (sort_j > 4'd0 && sort_i < sort_j) begin
                        if (x_reg[sort_i] > x_reg[sort_i + 4'd1]) begin
                            // Swap x
                            temp_x <= x_reg[sort_i];
                            x_reg[sort_i] <= x_reg[sort_i + 4'd1];
                            x_reg[sort_i + 4'd1] <= temp_x;
                            // Swap y
                            temp_y <= y_reg[sort_i];
                            y_reg[sort_i] <= y_reg[sort_i + 4'd1];
                            y_reg[sort_i + 4'd1] <= temp_y;
                        end else if (x_reg[sort_i] == x_reg[sort_i + 4'd1]) begin
                            // Secondary sort by y if x equal
                            if (y_reg[sort_i] > y_reg[sort_i + 4'd1]) begin
                                temp_y <= y_reg[sort_i];
                                y_reg[sort_i] <= y_reg[sort_i + 4'd1];
                                y_reg[sort_i + 4'd1] <= temp_y;
                            end
                        end
                    end
                    sorting_done <= 1'b0;
                end
                
                GET_UNIQUE_X: begin
                    // Extract unique x values from sorted array
                    if (scan_idx < point_count) begin
                        if (scan_idx == 4'd0) begin
                            unique_x[unique_count] <= x_reg[0];
                            unique_count <= unique_count + 4'd1;
                        end else if (x_reg[scan_idx] != x_reg[scan_idx - 4'd1]) begin
                            unique_x[unique_count] <= x_reg[scan_idx];
                            unique_count <= unique_count + 4'd1;
                        end
                    end
                    extraction_done <= 1'b0;
                end
                
                ENUMERATE: begin
                    // Reset for enumeration
                    if (left_ptr >= unique_count - 4'd2) begin
                        // All left/right pairs done
                    end else if (right_ptr >= unique_count - 4'd1) begin
                        // Next left
                    end
                    counting_done <= 1'b0;
                end
                
                COUNT_SUBSETS: begin
                    // Collect points in (unique_x[left_ptr], unique_x[right_ptr]) range
                    // Sort y values, then count distinct subsets by y-thresholds
                    if (threshold_loop_done) begin
                        // Add distinct_count to acc_count with overflow check
                        if (acc_count + distinct_count > 16'd65535) begin
                            acc_count <= 16'd65535;  // Saturate
                        end else begin
                            acc_count <= acc_count + distinct_count;
                        end
                    end
                    comparison_done <= 1'b0;
                end
                
                FINISH: begin
                    result <= acc_count;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INPUT_POINTS;
            
            INPUT_POINTS: if (done_i) next_state = SORT_X;
            
            SORT_X: begin
                // Bubble sort completion condition
                if (sort_j == point_count && point_count > 4'd0) begin
                    next_state = GET_UNIQUE_X;
                end else begin
                    next_state = SORT_X;
                end
            end
            
            GET_UNIQUE_X: begin
                if (scan_idx >= point_count) begin
                    next_state = ENUMERATE;
                end else begin
                    next_state = GET_UNIQUE_X;
                end
            end
            
            ENUMERATE: begin
                if (left_ptr >= unique_count - 4'd2 && right_ptr >= unique_count - 4'd1) begin
                    next_state = FINISH;
                end else begin
                    next_state = COUNT_SUBSETS;
                end
            end
            
            COUNT_SUBSETS: begin
                if (comparison_done) begin
                    next_state = ENUMERATE;
                end else begin
                    next_state = COUNT_SUBSETS;
                end
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sorting control logic (combinational)
    always @(*) begin
        if (state == SORT_X) begin
            if (sort_j == 4'd0) begin
                // Initialize sort
                if (sort_i < point_count - 4'd1) begin
                    sort_i = sort_i + 4'd1;
                end else begin
                    sort_i = 4'd0;
                    sort_j = sort_j + 4'd1;
                end
            end else if (sort_i < sort_j - 4'd1) begin
                sort_i = sort_i + 4'd1;
            end else begin
                sort_i = 4'd0;
                sort_j = sort_j + 4'd1;
            end
        end
    end
    
    // Unique X extraction control
    always @(*) begin
        if (state == GET_UNIQUE_X) begin
            if (scan_idx < point_count) begin
                scan_idx = scan_idx + 4'd1;
            end else begin
                extraction_done = 1'b1;
            end
        end else begin
            scan_idx = 4'd0;
            unique_count = 4'd0;
        end
    end
    
    // Enumeration control
    always @(*) begin
        if (state == ENUMERATE) begin
            if (left_ptr < unique_count - 4'd2) begin
                if (right_ptr < unique_count - 4'd1) begin
                    right_ptr = right_ptr + 4'd1;
                end else begin
                    left_ptr = left_ptr + 4'd1;
                    right_ptr = left_ptr + 4'd1;
                end
            end else begin
                // Done
            end
        end else begin
            // Reset pointers if not enumerating
            if (state != COUNT_SUBSETS) begin
                left_ptr = 4'd0;
                right_ptr = 4'd0;
            end
        end
    end
    
    // Subset counting logic (combinational blocks)
    always @(*) begin
        if (state == COUNT_SUBSETS) begin
            // Step 1: Collect points in range
            subset_bitset = 16'd0;
            y_sub_count = 4'd0;
            for (point_idx = 4'd0; point_idx < point_count; point_idx = point_idx + 4'd1) begin
                if (x_reg[point_idx] > unique_x[left_ptr] && x_reg[point_idx] < unique_x[right_ptr]) begin
                    subset_bitset = subset_bitset | (16'd1 << point_idx);
                    y_values[y_sub_count] = y_reg[point_idx];
                    y_sub_count = y_sub_count + 4'd1;
                end
            end
            
            // Step 2: If no points, skip
            if (y_sub_count == 4'd0) begin
                distinct_count = 4'd0;
                comparison_done = 1'b1;
            end else begin
                // Step 3: Sort y values (bubble sort)
                for (y_sorted_idx = 4'd0; y_sorted_idx < y_sub_count; y_sorted_idx = y_sorted_idx + 4'd1) begin
                    for (y_idx = 4'd0; y_idx < y_sub_count - y_sorted_idx - 4'd1; y_idx = y_idx + 4'd1) begin
                        if (y_values[y_idx] > y_values[y_idx + 4'd1]) begin
                            temp_y = y_values[y_idx];
                            y_values[y_idx] = y_values[y_idx + 4'd1];
                            y_values[y_idx + 4'd1] = temp_y;
                        end
                    end
                end
                
                // Step 4: Enumerate thresholds (after each y value)
                distinct_count = 4'd0;
                seen_count = 4'd0;
                threshold_loop_done = 1'b0;
                
                // Only count after first threshold (a >= y1 means no points)
                // So thresholds are a = y_i for i = 0 to y_sub_count-1
                // Points above threshold: those with y > a
                // For threshold at index t (a = y[t]), points with index > t are included
                // Since sorted ascending, y[t] = y[t], points with y > y[t] have index > t
                // Actually, points with y > a means y > y[t], so indices > t
                // But we need distinct subsets. For sorted unique y values:
                // - a < y[0]: all y_sub_count points
                // - y[0] <= a < y[1]: points with y > a = y_sub_count - 1 points (indices 1..end)
                // - ...
                // - y[k] <= a < y[k+1]: points with index > k
                // - a >= y[y_sub_count-1]: 0 points (empty, but we exclude empty subsets)
                
                // However, we need to handle duplicate y values.
                // Better approach: for each possible threshold equal to a y value,
                // compute the mask of points above it, count distinct non-empty masks.
                
                for (threshold_idx = 4'd0; threshold_idx < y_sub_count; threshold_idx = threshold_idx + 4'd1) begin
                    // Build mask for points with y > y_values[threshold_idx]
                    threshold_mask = 16'd0;
                    for (point_idx = 4'd0; point_idx < y_sub_count; point_idx = point_idx + 4'd1) begin
                        if (y_values[point_idx] > y_values[threshold_idx]) begin
                            threshold_mask = threshold_mask | (16'd1 << point_idx);
                        end
                    end
                    
                    // Check if mask is non-empty and not seen before
                    if (threshold_mask != 16'd0) begin
                        mask_found = 1'b0;
                        for (seen_idx = 4'd0; seen_idx < seen_count; seen_idx = seen_idx + 4'd1) begin
                            if (seen_masks[seen_idx] == threshold_mask) begin
                                mask_found = 1'b1;
                            end
                        end
                        if (!mask_found && seen_count < 4'd16) begin
                            seen_masks[seen_count] = threshold_mask;
                            seen_count = seen_count + 4'd1;
                            distinct_count = distinct_count + 4'd1;
                        end
                    end
                end
                
                // Also consider the full set (threshold < min_y)
                // This is the subset for a < y_values[0]
                // We need to check if this subset has been counted
                // The full set is all points in range, which is subset_bitset
                if (subset_bitset != 16'd0) begin
                    mask_found = 1'b0;
                    for (seen_idx = 4'd0; seen_idx < seen_count; seen_idx = seen_idx + 4'd1) begin
                        if (seen_masks[seen_idx] == subset_bitset) begin
                            mask_found = 1'b1;
                        end
                    end
                    if (!mask_found) begin
                        distinct_count = distinct_count + 4'd1;
                    end
                end
                
                threshold_loop_done = 1'b1;
                comparison_done = 1'b1;
            end
        end else begin
            subset_bitset = 16'd0;
            y_sub_count = 4'd0;
            distinct_count = 4'd0;
            comparison_done = 1'b0;
            threshold_loop_done = 1'b0;
        end
    end

endmodule