module rocket_safety_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] engine1_x [0:7],
    input [15:0] engine1_y [0:7],
    input [2:0] engine1_count,
    input [15:0] engine2_x [0:7],
    input [15:0] engine2_y [0:7],
    input [2:0] engine2_count,
    output reg safe,
    output reg done
);

    // State encoding
    localparam IDLE = 0;
    localparam FIND_MIN_Y = 1;
    localparam SORT_POINTS = 2;
    localparam BUILD_HULL = 3;
    localparam COMPARE_HULLS = 4;
    localparam DONE = 5;

    reg [2:0] state;
    
    // Engine 1 processing registers
    reg [2:0] idx1;
    reg [15:0] min_y_val1;
    reg [2:0] min_y_idx1;
    reg [15:0] p1_x [0:7];
    reg [15:0] p1_y [0:7];
    reg [2:0] sorted_idx1 [0:7]; // Indices into original arrays
    reg [2:0] hull1 [0:7];
    reg [2:0] h_count1;
    reg [2:0] s_count1; // sorted count
    reg [2:0] pivot_idx1;
    
    // Engine 2 processing registers
    reg [2:0] idx2;
    reg [15:0] min_y_val2;
    reg [2:0] min_y_idx2;
    reg [15:0] p2_x [0:7];
    reg [15:0] p2_y [0:7];
    reg [2:0] sorted_idx2 [0:7];
    reg [2:0] hull2 [0:7];
    reg [2:0] h_count2;
    reg [2:0] s_count2;
    reg [2:0] pivot_idx2;
    
    // Comparison registers
    reg [2:0] compare_idx;
    reg [2:0] match_count;
    reg matched;
    reg [2:0] offset;
    reg [2:0] shift;
    
    // Cross product computation (signed 48-bit to prevent overflow)
    wire signed [47:0] cross1;
    wire signed [47:0] cross2;
    wire signed [47:0] cross_comp1;
    wire signed [47:0] cross_comp2;
    
    // Temporary coordinates for angle sort comparison
    reg [15:0] ax, ay, bx, by;
    
    // Cross product for sorting: (bx - ax) * (by - ay) - (bx - ax) * (by - ay)
    // Actually: (b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x)
    wire signed [31:0] dx1 = {16'b0, p1_x[idx1]} - {16'b0, p1_x[pivot_idx1]};
    wire signed [31:0] dy1 = {16'b0, p1_y[idx1]} - {16'b0, p1_y[pivot_idx1]};
    wire signed [31:0] dx2 = {16'b0, p1_x[idx2]} - {16'b0, p1_x[pivot_idx1]};
    wire signed [31:0] dy2 = {16'b0, p1_y[idx2]} - {16'b0, p1_y[pivot_idx1]};
    
    assign cross1 = (dx1 * dy2) - (dy1 * dx2);
    
    wire signed [31:0] dx1_e2 = {16'b0, p2_x[idx2]} - {16'b0, p2_x[pivot_idx2]};
    wire signed [31:0] dy1_e2 = {16'b0, p2_y[idx2]} - {16'b0, p2_y[pivot_idx2]};
    wire signed [31:0] dx2_e2 = {16'b0, p2_x[idx2]} - {16'b0, p2_x[pivot_idx2]}; // Same point for bubble sort
    
    // Cross product for hull build
    wire signed [47:0] hull_cross1;
    wire signed [47:0] hull_cross2;
    
    // For hull building: need previous 2 points and current
    // hull[h_count-2], hull[h_count-1], current point
    wire signed [31:0] hdx1 = (h_count1 >= 2) ? 
        ({16'b0, p1_x[sorted_idx1[h_count1-1]]} - {16'b0, p1_x[sorted_idx1[h_count1-2]]}) : 0;
    wire signed [31:0] hdy1 = (h_count1 >= 2) ? 
        ({16'b0, p1_y[sorted_idx1[h_count1-1]]} - {16'b0, p1_y[sorted_idx1[h_count1-2]]}) : 0;
    wire signed [31:0] hdx1_2 = (h_count1 >= 1) ? 
        ({16'b0, p1_x[sorted_idx1[idx1]]} - {16'b0, p1_x[sorted_idx1[h_count1-1]]}) : 0;
    wire signed [31:0] hdy1_2 = (h_count1 >= 1) ? 
        ({16'b0, p1_y[sorted_idx1[idx1]]} - {16'b0, p1_y[sorted_idx1[h_count1-1]]}) : 0;
        
    assign hull_cross1 = (hdx1 * hdy1_2) - (hdy1 * hdx1_2);
    
    wire signed [31:0] hdx2 = (h_count2 >= 2) ? 
        ({16'b0, p2_x[sorted_idx2[h_count2-1]]} - {16'b0, p2_x[sorted_idx2[h_count2-2]]}) : 0;
    wire signed [31:0] hdy2 = (h_count2 >= 2) ? 
        ({16'b0, p2_y[sorted_idx2[h_count2-1]]} - {16'b0, p2_y[sorted_idx2[h_count2-2]]}) : 0;
    wire signed [31:0] hdx2_2 = (h_count2 >= 1) ? 
        ({16'b0, p2_x[sorted_idx2[idx2]]} - {16'b0, p2_x[sorted_idx2[h_count2-1]]}) : 0;
    wire signed [31:0] hdy2_2 = (h_count2 >= 1) ? 
        ({16'b0, p2_y[sorted_idx2[idx2]]} - {16'b0, p2_y[sorted_idx2[h_count2-1]]}) : 0;
        
    assign hull_cross2 = (hdx2 * hdy2_2) - (hdy2 * hdx2_2);

    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            safe <= 0;
            done <= 0;
            idx1 <= 0;
            idx2 <= 0;
            h_count1 <= 0;
            h_count2 <= 0;
            s_count1 <= 0;
            s_count2 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= FIND_MIN_Y;
                        idx1 <= 0;
                        idx2 <= 0;
                        // Initialize min values to max
                        min_y_val1 <= 32'h7FFFFFFF;
                        min_y_val2 <= 32'h7FFFFFFF;
                        min_y_idx1 <= 0;
                        min_y_idx2 <= 0;
                        
                        // Copy inputs to internal registers
                        for (i = 0; i < 8; i = i + 1) begin
                            p1_x[i] <= engine1_x[i];
                            p1_y[i] <= engine1_y[i];
                            p2_x[i] <= engine2_x[i];
                            p2_y[i] <= engine2_y[i];
                        end
                    end
                end
                
                FIND_MIN_Y: begin
                    // Process Engine 1
                    if (idx1 < engine1_count) begin
                        if (p1_y[idx1] < min_y_val1) begin
                            min_y_val1 <= p1_y[idx1];
                            min_y_idx1 <= idx1;
                        end else if (p1_y[idx1] == min_y_val1) begin
                            // Tiebreaker: smaller x
                            if (p1_x[idx1] < p1_x[min_y_idx1]) begin
                                min_y_idx1 <= idx1;
                            end
                        end
                        idx1 <= idx1 + 1;
                    end
                    
                    // Process Engine 2
                    if (idx2 < engine2_count) begin
                        if (p2_y[idx2] < min_y_val2) begin
                            min_y_val2 <= p2_y[idx2];
                            min_y_idx2 <= idx2;
                        end else if (p2_y[idx2] == min_y_val2) begin
                            if (p2_x[idx2] < p2_x[min_y_idx2]) begin
                                min_y_idx2 <= idx2;
                            end
                        end
                        idx2 <= idx2 + 1;
                    end
                    
                    if (idx1 >= engine1_count - 1 && idx2 >= engine2_count - 1) begin
                        state <= SORT_POINTS;
                        idx1 <= 0;
                        idx2 <= 0;
                        s_count1 <= 0;
                        s_count2 <= 0;
                        pivot_idx1 <= min_y_idx1;
                        pivot_idx2 <= min_y_idx2;
                    end
                end
                
                SORT_POINTS: begin
                    // Sort by polar angle using bubble sort (simplified for 8 points)
                    // First, build array of indices excluding pivot
                    
                    if (s_count1 < engine1_count - 1) begin
                        // Find next point in angular order
                        reg found;
                        reg [15:0] min_angle_x;
                        reg [15:0] min_angle_y;
                        reg [2:0] min_angle_idx;
                        reg signed [47:0] min_cross;
                        
                        found = 0;
                        min_cross = 48'h7FFFFFFFFFFFFF; // Large positive
                        
                        // Find point with minimum angle (smallest cross product, or closer if equal)
                        for (i = 0; i < engine1_count; i = i + 1) begin
                            if (i != pivot_idx1) begin
                                // Check if already sorted
                                reg already_sorted;
                                already_sorted = 0;
                                for (j = 0; j < s_count1; j = j + 1) begin
                                    if (sorted_idx1[j] == i) already_sorted = 1;
                                end
                                
                                if (!already_sorted) begin
                                    // Calculate cross with pivot (0,0)
                                    // Actually we need angle relative to pivot
                                    // Use cross product to compare angles
                                    // Let A = pivot, B = current_min, C = i
                                    
                                    reg signed [47:0] cross_val;
                                    if (s_count1 == 0) begin
                                        // First point after pivot
                                        cross_val = 0;
                                    end else begin
                                        // Compare with last sorted point
                                        // cross = (B-A)x(C-A)
                                        // where B = sorted_idx1[s_count1-1], C = i
                                        // Actually we want to find the point with minimum angle from pivot
                                        // Use atan2 approximation or cross product comparison
                                        
                                        // Simplified: compare cross product of vectors from pivot
                                        // vec1 = sorted[pivot_idx1] -> point B
                                        // vec2 = sorted[pivot_idx1] -> point C
                                        // cross = vec1 x vec2
                                        
                                        wire signed [31:0] v1x = {16'b0, p1_x[sorted_idx1[s_count1-1]]} - {16'b0, p1_x[pivot_idx1]};
                                        wire signed [31:0] v1y = {16'b0, p1_y[sorted_idx1[s_count1-1]]} - {16'b0, p1_y[pivot_idx1]};
                                        wire signed [31:0] v2x = {16'b0, p1_x[i]} - {16'b0, p1_x[pivot_idx1]};
                                        wire signed [31:0] v2y = {16'b0, p1_y[i]} - {16'b0, p1_y[pivot_idx1]};
                                        
                                        // This doesn't work in always block directly
                                        // Need to handle this differently
                                    end
                                end
                            end
                        end
                        
                        // Alternate implementation: use index-based sorting
                        // Build sorted_idx1 based on angular order
                        // For simplicity, use a multi-pass bubble sort on angles
                        
                        // For now, let's do a simpler approach:
                        // Store all points (except pivot) in sorted_idx1
                        // Then sort them using bubble sort
                        
                        if (s_count1 == 0) begin
                            // Fill initial array
                            reg [2:0] fill_idx;
                            fill_idx = 0;
                            for (i = 0; i < engine1_count; i = i + 1) begin
                                if (i != pivot_idx1) begin
                                    sorted_idx1[fill_idx] <= i;
                                    fill_idx = fill_idx + 1;
                                end
                            end
                            s_count1 <= engine1_count - 1;
                        end else begin
                            // Bubble sort pass on sorted_idx1
                            // Compare angle of sorted_idx1[i] and sorted_idx1[i+1] relative to pivot_idx1
                            if (idx1 < s_count1 - 1) begin
                                // Get cross product
                                wire signed [31:0] v1x = {16'b0, p1_x[sorted_idx1[idx1]]} - {16'b0, p1_x[pivot_idx1]};
                                wire signed [31:0] v1y = {16'b0, p1_y[sorted_idx1[idx1]]} - {16'b0, p1_y[pivot_idx1]};
                                wire signed [31:0] v2x = {16'b0, p1_x[sorted_idx1[idx1+1]]} - {16'b0, p1_x[pivot_idx1]};
                                wire signed [31:0] v2y = {16'b0, p1_y[sorted_idx1[idx1+1]]} - {16'b0, p1_y[pivot_idx1]};
                                wire signed [47:0] cross_val = (v1x * v2y) - (v1y * v2x);
                                
                                // If cross < 0, point 2 is to the right (smaller angle) - swap
                                // Actually: cross > 0 means counter-clockwise (larger angle)
                                // We want ascending angle order
                                // cross < 0: swap (point 2 is smaller angle)
                                
                                // Can't use wire in if statement in always block
                                // Need temp registers
                                
                                // Simplified: use pre-calculated cross
                                // Store cross in temp and use it
                                
                                // Since we can't use combinational logic inside always for control,
                                // let's pre-calculate the comparison in separate logic
                                // For now, do a simpler bubble sort with embedded calculation
                                
                                reg swap;
                                swap = 0;
                                
                                // Manual calculation for comparison
                                // cross = (a.x * b.y - a.y * b.x)
                                // where a = p[sorted_idx1[idx1]] - pivot, b = p[sorted_idx1[idx1+1]] - pivot
                                
                                // This is getting complex, let's use a different approach
                                // Use a single cycle sorting network or brute force
                                
                                // Since max 7 points to sort, we can do brute force in 7 cycles
                                // Just track the minimum angle point in each cycle
                            end
                            
                            idx1 <= idx1 + 1;
                            if (idx1 >= s_count1 - 1) begin
                                // Reset for next pass or finish
                                idx1 <= 0;
                                // Need to track if sorting is done
                                // For now, assume 1 pass is enough (not correct but for structure)
                                // Actually need multiple passes for bubble sort
                                
                                // Let's simplify: assume we just copy indices in order
                                // and skip actual sorting (this is a simplified version)
                                // For production, this needs proper sorting
                                
                                // To make it synthesizable and correct:
                                // We'll do angular sort in 3 stages per engine:
                                // 1. Find min angle point
                                // 2. Add to sorted array
                                // 3. Repeat
                            end
                        end
                    end
                    
                    // Actually, let's rewrite SORT_POINTS completely with a cleaner approach
                    // This is getting too complex for inline logic
                end
                
                // For better code structure, let's use a simplified approach
                // The above implementation is getting messy. Let me fix it.
                
                BUILD_HULL: begin
                    // Graham scan
                    // Need to handle both engines
                    // This state will be split
                end
                
                COMPARE_HULLS: begin
                    // Compare hulls
                end
                
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Additional combinational logic needed
    // Let me rewrite this module with a cleaner structure

endmodule

// Redesigned module with proper state machine
module rocket_safety_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] engine1_x [0:7],
    input [15:0] engine1_y [0:7],
    input [2:0] engine1_count,
    input [15:0] engine2_x [0:7],
    input [15:0] engine2_y [0:7],
    input [2:0] engine2_count,
    output reg safe,
    output reg done
);

    // State encoding
    localparam IDLE = 0;
    localparam LOAD_POINTS = 1;
    localparam FIND_MIN_Y1 = 2;
    localparam FIND_MIN_Y2 = 3;
    localparam SORT_ENGINE1 = 4;
    localparam SORT_ENGINE2 = 5;
    localparam BUILD_HULL1 = 6;
    localparam BUILD_HULL2 = 7;
    localparam COMPARE = 8;
    localparam COMPLETE = 9;

    reg [3:0] state;
    
    // Data storage
    reg [15:0] e1_x [0:7];
    reg [15:0] e1_y [0:7];
    reg [15:0] e2_x [0:7];
    reg [15:0] e2_y [0:7];
    reg [2:0] e1_cnt;
    reg [2:0] e2_cnt;
    
    // Min Y finding
    reg [2:0] min_idx1, min_idx2;
    reg [15:0] min_y1, min_y2;
    reg [2:0] counter;
    
    // Sorting
    reg [2:0] sorted1 [0:7];
    reg [2:0] sorted2 [0:7];
    reg [2:0] sorted_count1;
    reg [2:0] sorted_count2;
    reg [2:0] sort_i, sort_j;
    reg [15:0] temp_x, temp_y;
    reg [2:0] temp_idx;
    
    // Hull building
    reg [2:0] hull1 [0:7];
    reg [2:0] hull2 [0:7];
    reg [2:0] hull_cnt1, hull_cnt2;
    reg [2:0] hull_idx;
    
    // Comparison
    reg [2:0] match_idx, match_shift;
    reg found_match;
    reg [2:0] match_count;
    
    // Helper wires for cross product (combinational)
    wire signed [47:0] cross_e1;
    wire signed [47:0] cross_e2;
    wire signed [47:0] hull_cross1;
    wire signed [47:0] hull_cross2;
    wire signed [47:0] compare_cross;
    
    // Cross product for angle comparison: (b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x)
    // For sorting: compare sorted2[sort_j] and sorted2[sort_j+1] relative to pivot min_idx2
    wire signed [31:0] dx1_sort = e1_x[sorted1[sort_j]] - e1_x[min_idx1];
    wire signed [31:0] dy1_sort = e1_y[sorted1[sort_j]] - e1_y[min_idx1];
    wire signed [31:0] dx1_sort_next = e1_x[sorted1[sort_j+1]] - e1_x[min_idx1];
    wire signed [31:0] dy1_sort_next = e1_y[sorted1[sort_j+1]] - e1_y[min_idx1];
    assign cross_e1 = (dx1_sort * dy1_sort_next) - (dy1_sort * dx1_sort_next);
    
    wire signed [31:0] dx2_sort = e2_x[sorted2[sort_j]] - e2_x[min_idx2];
    wire signed [31:0] dy2_sort = e2_y[sorted2[sort_j]] - e2_y[min_idx2];
    wire signed [31:0] dx2_sort_next = e2_x[sorted2[sort_j+1]] - e2_x[min_idx2];
    wire signed [31:0] dy2_sort_next = e2_y[sorted2[sort_j+1]] - e2_y[min_idx2];
    assign cross_e2 = (dx2_sort * dy2_sort_next) - (dy2_sort * dx2_sort_next);
    
    // Cross product for hull: turn at last hull point (p[h-2] -> p[h-1] -> p[curr])
    // If > 0, left turn (keep), if <= 0, right turn (pop)
    wire signed [31:0] hdx1 = e1_x[sorted1[hull_idx]] - e1_x[sorted1[hull_cnt1-1]];
    wire signed [31:0] hdy1 = e1_y[sorted1[hull_idx]] - e1_y[sorted1[hull_cnt1-1]];
    wire signed [31:0] hdx1_prev = e1_x[sorted1[hull_cnt1-1]] - e1_x[sorted1[hull_cnt1-2]];
    wire signed [31:0] hdy1_prev = e1_y[sorted1[hull_cnt1-1]] - e1_y[sorted1[hull_cnt1-2]];
    assign hull_cross1 = (hdx1_prev * hdy1) - (hdy1_prev * hdx1);
    
    wire signed [31:0] hdx2 = e2_x[sorted2[hull_idx]] - e2_x[sorted2[hull_cnt2-1]];
    wire signed [31:0] hdy2 = e2_y[sorted2[hull_idx]] - e2_y[sorted2[hull_cnt2-1]];
    wire signed [31:0] hdx2_prev = e2_x[sorted2[hull_cnt2-1]] - e2_x[sorted2[hull_cnt2-2]];
    wire signed [31:0] hdy2_prev = e2_y[sorted2[hull_cnt2-1]] - e2_y[sorted2[hull_cnt2-2]];
    assign hull_cross2 = (hdx2_prev * hdy2) - (hdy2_prev * hdx2);
    
    // Edge length comparison for congruence
    wire signed [47:0] dx1_compare = e1_x[hull1[match_idx]] - e1_x[hull1[(match_idx+1)%hull_cnt1]];
    wire signed [47:0] dy1_compare = e1_y[hull1[match_idx]] - e1_y[hull1[(match_idx+1)%hull_cnt1]];
    wire signed [47:0] dx2_compare = e2_x[hull2[(match_idx + match_shift)%hull_cnt2]] - 
                                     e2_x[hull2[(match_idx + match_shift + 1)%hull_cnt2]];
    wire signed [47:0] dy2_compare = e2_y[hull2[(match_idx + match_shift)%hull_cnt2]] - 
                                     e2_y[hull2[(match_idx + match_shift + 1)%hull_cnt2]];
    
    wire signed [95:0] len1_sq = dx1_compare * dx1_compare + dy1_compare * dy1_compare;
    wire signed [95:0] len2_sq = dx2_compare * dx2_compare + dy2_compare * dy2_compare;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            safe <= 0;
            done <= 0;
            counter <= 0;
            sorted_count1 <= 0;
            sorted_count2 <= 0;
            hull_cnt1 <= 0;
            hull_cnt2 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_POINTS;
                        counter <= 0;
                    end
                end
                
                LOAD_POINTS: begin
                    // Load all points from inputs
                    if (counter < 8) begin
                        e1_x[counter] <= engine1_x[counter];
                        e1_y[counter] <= engine1_y[counter];
                        e2_x[counter] <= engine2_x[counter];
                        e2_y[counter] <= engine2_y[counter];
                        counter <= counter + 1;
                    end else begin
                        e1_cnt <= engine1_count;
                        e2_cnt <= engine2_count;
                        counter <= 0;
                        state <= FIND_MIN_Y1;
                        min_y1 <= 32'h7FFFFFFF;
                        min_y2 <= 32'h7FFFFFFF;
                    end
                end
                
                FIND_MIN_Y1: begin
                    if (counter < e1_cnt) begin
                        if (e1_y[counter] < min_y1 || 
                            (e1_y[counter] == min_y1 && e1_x[counter] < e1_x[min_idx1])) begin
                            min_y1 <= e1_y[counter];
                            min_idx1 <= counter;
                        end
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        state <= FIND_MIN_Y2;
                    end
                end
                
                FIND_MIN_Y2: begin
                    if (counter < e2_cnt) begin
                        if (e2_y[counter] < min_y2 || 
                            (e2_y[counter] == min_y2 && e2_x[counter] < e2_x[min_idx2])) begin
                            min_y2 <= e2_y[counter];
                            min_idx2 <= counter;
                        end
                        counter <= counter + 1;
                    end else begin
                        // Initialize sorted arrays with pivot
                        sorted1[0] <= min_idx1;
                        sorted2[0] <= min_idx2;
                        sorted_count1 <= 1;
                        sorted_count2 <= 1;
                        // Fill remaining slots with indices 0-7 excluding pivot
                        counter <= 0;
                        sort_i <= 1;
                        state <= SORT_ENGINE1;
                    end
                end
                
                SORT_ENGINE1: begin
                    // Build list of all points except pivot
                    if (counter < e1_cnt) begin
                        if (counter != min_idx1) begin
                            sorted1[sort_i] <= counter;
                            sort_i <= sort_i + 1;
                            sorted_count1 <= sorted_count1 + 1;
                        end
                        counter <= counter + 1;
                    end else begin
                        // Now sort by angle (bubble sort)
                        // This needs multiple passes, do one pass per cycle
                        if (sorted_count1 > 2) begin
                            if (sort_j < sorted_count1 - 2) begin
                                // Compare angle of sorted1[sort_j+1] and sorted1[sort_j+2] relative to min_idx1
                                // cross_e1 is positive if sort_j+2 has larger angle than sort_j+1
                                if (cross_e1 < 0) begin
                                    // Swap
                                    temp_idx <= sorted1[sort_j+1];
                                    sorted1[sort_j+1] <= sorted1[sort_j+2];
                                    sorted1[sort_j+2] <= temp_idx;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 0;
                                // Check if sorted (flag needed)
                                // For simplicity, do fixed number of passes
                                if (sort_i < 10) begin // Multiple passes
                                    sort_i <= sort_i + 1;
                                end else begin
                                    counter <= 0;
                                    sort_i <= 1;
                                    sort_j <= 0;
                                    state <= SORT_ENGINE2;
                                end
                            end
                        end else begin
                            // 2 or fewer points, skip sorting
                            counter <= 0;
                            state <= SORT_ENGINE2;
                        end
                    end
                end
                
                SORT_ENGINE2: begin
                    // Same for engine 2
                    if (counter < e2_cnt) begin
                        if (counter != min_idx2) begin
                            sorted2[sort_i] <= counter;
                            sort_i <= sort_i + 1;
                            sorted_count2 <= sorted_count2 + 1;
                        end
                        counter <= counter + 1;
                    end else begin
                        if (sorted_count2 > 2) begin
                            if (sort_j < sorted_count2 - 2) begin
                                if (cross_e2 < 0) begin
                                    temp_idx <= sorted2[sort_j+1];
                                    sorted2[sort_j+1] <= sorted2[sort_j+2];
                                    sorted2[sort_j+2] <= temp_idx;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 0;
                                if (sort_i < 10) begin
                                    sort_i <= sort_i + 1;
                                end else begin
                                    // Done sorting both
                                    hull_cnt1 <= 0;
                                    hull_cnt2 <= 0;
                                    hull_idx <= 0;
                                    state <= BUILD_HULL1;
                                end
                            end
                        end else begin
                            state <= BUILD_HULL1;
                        end
                    end
                end
                
                BUILD_HULL1: begin
                    // Graham scan for engine 1
                    if (hull_idx < sorted_count1) begin
                        // Get current point
                        reg [2:0] curr_idx = sorted1[hull_idx];
                        
                        if (hull_cnt1 < 2) begin
                            // Push first two points
                            hull1[hull_cnt1] <= curr_idx;
                            hull_cnt1 <= hull_cnt1 + 1;
                            hull_idx <= hull_idx + 1;
                        end else begin
                            // Check if turn is counter-clockwise (cross > 0)
                            if (hull_cross1 > 0) begin
                                hull1[hull_cnt1] <= curr_idx;
                                hull_cnt1 <= hull_cnt1 + 1;
                                hull_idx <= hull_idx + 1;
                            end else begin
                                // Pop from hull
                                hull_cnt1 <= hull_cnt1 - 1;
                            end
                        end
                    end else begin
                        hull_idx <= 0;
                        state <= BUILD_HULL2;
                    end
                end
                
                BUILD_HULL2: begin
                    // Graham scan for engine 2
                    if (hull_idx < sorted_count2) begin
                        reg [2:0] curr_idx = sorted2[hull_idx];
                        
                        if (hull_cnt2 < 2) begin
                            hull2[hull_cnt2] <= curr_idx;
                            hull_cnt2 <= hull_cnt2 + 1;
                            hull_idx <= hull_idx + 1;
                        end else begin
                            if (hull_cross2 > 0) begin
                                hull2[hull_cnt2] <= curr_idx;
                                hull_cnt2 <= hull_cnt2 + 1;
                                hull_idx <= hull_idx + 1;
                            end else begin
                                hull_cnt2 <= hull_cnt2 - 1;
                            end
                        end
                    end else begin
                        // Prepare for comparison
                        // Check if counts match (first check)
                        if (hull_cnt1 != hull_cnt2) begin
                            safe <= 0;
                            state <= COMPLETE;
                        end else if (hull_cnt1 < 3) begin
                            // Need at least 3 points for polygon
                            safe <= 0;
                            state <= COMPLETE;
                        end else begin
                            match_idx <= 0;
                            match_shift <= 0;
                            found_match <= 0;
                            state <= COMPARE;
                        end
                    end
                end
                
                COMPARE: begin
                    // Check congruence by comparing edge lengths
                    // If hulls are congruent, there exists a rotation/translation
                    // We check edge length sequences
                    
                    if (match_shift < hull_cnt1) begin
                        // Try this shift
                        if (match_idx < hull_cnt1) begin
                            // Compare edge from hull1[match_idx] to hull1[match_idx+1]
                            // with hull2[match_idx+shift] to hull2[match_idx+shift+1]
                            if (len1_sq == len2_sq) begin
                                match_idx <= match_idx + 1;
                            end else begin
                                // Mismatch, try next shift
                                match_shift <= match_shift + 1;
                                match_idx <= 0;
                            end
                        end else begin
                            // All edges matched
                            found_match <= 1;
                            safe <= 1;
                            state <= COMPLETE;
                        end
                    end else begin
                        // Tried all shifts, no match
                        safe <= 0;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule