module ExplodingWorms (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] cans_x [0:15],
    input wire [15:0] cans_r [0:15],
    output reg [3:0] results [0:15],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SORT = 4'd1;
    localparam [3:0] CALC_START = 4'd2;
    localparam [3:0] CALC_BFS_LOOP = 4'd3;
    localparam [3:0] CALC_EXPAND = 4'd4;
    localparam [3:0] CALC_COUNT = 4'd5;
    localparam [3:0] OUTPUT = 4'd6;
    localparam [3:0] DONE = 4'd7;

    // Registers
    reg [3:0] state, next_state;
    reg [3:0] i, j, k; // Loop counters
    reg [3:0] target_idx; // Which can we are calculating for (0-15)
    
    // Data storage
    reg signed [15:0] sorted_x [0:15];
    reg [15:0] sorted_r [0:15];
    
    // BFS state
    reg [15:0] visited_mask;
    reg [15:0] current_cans; // Bits representing cans to process (pop from queue)
    reg [15:0] queue_buffer [0:15]; // Circular buffer for queue expansion
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;
    reg [3:0] pop_idx;
    
    // Sort state
    reg [3:0] sort_pass;
    reg [3:0] sort_idx;
    reg signed [15:0] temp_x;
    reg [15:0] temp_r;
    
    // Count state
    reg [3:0] bit_count;
    reg [3:0] bit_cnt_stage;
    reg [15:0] count_temp;
    
    // Cycle counter for safety
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SORT : IDLE;
            
            SORT: begin
                // Bubble sort passes
                if (sort_pass >= 15 && sort_idx >= 15) next_state = CALC_START;
                else next_state = SORT;
            end
            
            CALC_START: next_state = CALC_BFS_LOOP;
            
            CALC_BFS_LOOP: begin
                if (current_cans == 16'd0) next_state = CALC_COUNT;
                else next_state = CALC_EXPAND;
            end
            
            CALC_EXPAND: begin
                // Expand logic: scan all cans
                if (k >= 15) next_state = CALC_BFS_LOOP;
                else next_state = CALC_EXPAND;
            end
            
            CALC_COUNT: begin
                if (bit_cnt_stage >= 4'd4) next_state = OUTPUT;
                else next_state = CALC_COUNT;
            end
            
            OUTPUT: begin
                if (target_idx >= 15) next_state = DONE;
                else next_state = CALC_START;
            end
            
            DONE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // State transition and operation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            target_idx <= 4'd0;
            sort_pass <= 4'd0;
            sort_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            pop_idx <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            current_cans <= 16'd0;
            visited_mask <= 16'd0;
            bit_count <= 4'd0;
            bit_cnt_stage <= 4'd0;
            count_temp <= 16'd0;
            cycle_count <= 12'd0;
            
            // Initialize results
            for (int r = 0; r < 16; r++) begin
                results[r] <= 4'd0;
            end
            // Initialize sorted data buffers
            for (int s = 0; s < 16; s++) begin
                sorted_x[s] <= 16'sd0;
                sorted_r[s] <= 16'd0;
            end
            // Initialize queue buffer
            for (int q = 0; q < 16; q++) begin
                queue_buffer[q] <= 16'd0;
            end
            
        end else begin
            state <= next_state;
            
            // Reset done pulse
            if (state != DONE) done <= 1'b0;
            
            // Cycle counter increment (safety)
            if (start) cycle_count <= 12'd0;
            else if (state != IDLE && state != DONE) begin
                if (cycle_count < MAX_CYCLES) cycle_count <= cycle_count + 12'd1;
            end
            
            case (state)
                IDLE: begin
                    // Waiting for start
                    if (start) begin
                        // Load inputs into sorted buffers
                        for (int idx = 0; idx < 16; idx++) begin
                            sorted_x[idx] <= cans_x[idx];
                            sorted_r[idx] <= cans_r[idx];
                        end
                        sort_pass <= 4'd0;
                        sort_idx <= 4'd0;
                    end
                end
                
                SORT: begin
                    // Bubble sort network: 16 passes
                    // Inner loop: compare adjacent elements
                    // Logic: if sorted_x[sort_idx] > sorted_x[sort_idx+1], swap
                    if (sorted_x[sort_idx] > sorted_x[sort_idx + 1]) begin
                        // Swap X
                        temp_x <= sorted_x[sort_idx];
                        sorted_x[sort_idx] <= sorted_x[sort_idx + 1];
                        sorted_x[sort_idx + 1] <= temp_x;
                        // Swap R
                        temp_r <= sorted_r[sort_idx];
                        sorted_r[sort_idx] <= sorted_r[sort_idx + 1];
                        sorted_r[sort_idx + 1] <= temp_r;
                    end
                    
                    if (sort_idx < 14) begin
                        sort_idx <= sort_idx + 4'd1;
                    end else begin
                        sort_idx <= 4'd0;
                        if (sort_pass < 15) sort_pass <= sort_pass + 4'd1;
                    end
                end
                
                CALC_START: begin
                    // Initialize BFS for current target_idx
                    visited_mask <= 16'd0;
                    current_cans <= 16'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue_count <= 4'd0;
                    
                    // Start BFS with the target can
                    // Since we are processing cans 0..15 as targets, the target index corresponds to the sorted array index
                    // Check if target is valid (it always is 0..15)
                    visited_mask[target_idx] <= 1'b1;
                    current_cans[target_idx] <= 1'b1;
                    k <= 4'd0;
                end
                
                CALC_BFS_LOOP: begin
                    // Pop one can from current_cans
                    if (current_cans != 16'd0) begin
                        // Find first set bit (simple priority encoder logic)
                        // We iterate pop_idx from 0 to 15 to find the bit
                        if (current_cans[pop_idx]) begin
                            // Found bit to pop
                            current_cans[pop_idx] <= 1'b0; // Remove from processing list
                            // This can is now "popped". We need to expand it in CALC_EXPAND.
                            // We use 'j' to store the index of the popped can for expansion
                            j <= pop_idx;
                            k <= 4'd0; // Reset neighbor scanner
                            // Advance pop_idx for next search
                            pop_idx <= 4'd0; // Reset for next pop
                        end else begin
                            if (pop_idx < 15) pop_idx <= pop_idx + 4'd1;
                            else pop_idx <= 4'd0; // Should not happen if logic correct, but safety
                        end
                    end else begin
                        pop_idx <= 4'd0;
                    end
                end
                
                CALC_EXPAND: begin
                    // Expand logic: Scan all cans (index k)
                    if (k < 15) begin
                        k <= k + 4'd1;
                    end
                    
                    // Check distance condition |x[j] - x[k]| <= r[j]
                    // Note: Use sorted_x and sorted_r
                    // Distance calculation
                    // We are checking if can 'j' (popped) explodes can 'k'
                    // Only if k is not already visited
                    
                    if (!visited_mask[k]) begin
                        // Calculate absolute difference
                        // diff = x[j] - x[k]
                        // Need to handle sign
                        // Using 17-bit to handle difference range
                        wire signed [16:0] diff = sorted_x[j] - sorted_x[k];
                        wire [16:0] abs_diff = (diff[16]) ? -diff : diff;
                        
                        // Check <= r[j]
                        // r[j] is 16-bit unsigned. diff fits in 17 bits. 
                        // If abs_diff > 17'hFFFF (impossible for 16-bit inputs), clip.
                        // But diff of two 16-bit signed fits in 17 bits. Max magnitude 65535.
                        // r[j] is 16-bit (max 65535).
                        
                        // Comparison: if (abs_diff <= sorted_r[j])
                        // Extend r to 17 bits for comparison with 17-bit diff
                        if (abs_diff <= {1'b0, sorted_r[j]}) begin
                            // Explosion occurs
                            visited_mask[k] <= 1'b1;
                            // Add to queue (future processing)
                            // We can add directly to current_cans to process in same frame or next
                            // Since we are iterating 'k', adding to current_cans works fine for BFS
                            current_cans[k] <= 1'b1;
                        end
                    end
                end
                
                CALC_COUNT: begin
                    // Popcount logic using 4 stages (divide and conquer)
                    // Stage 0: 16 bits -> 8 pairs of 2-bit sums
                    // Stage 1: 8 bits -> 4 pairs of 3-bit sums
                    // Stage 2: 4 bits -> 2 pairs of 4-bit sums
                    // Stage 3: 2 bits -> 1 sum of 4 bits
                    
                    case (bit_cnt_stage)
                        4'd0: begin
                            // 16 -> 8
                            count_temp[0] <= visited_mask[0] + visited_mask[1];
                            count_temp[1] <= visited_mask[2] + visited_mask[3];
                            count_temp[2] <= visited_mask[4] + visited_mask[5];
                            count_temp[3] <= visited_mask[6] + visited_mask[7];
                            count_temp[4] <= visited_mask[8] + visited_mask[9];
                            count_temp[5] <= visited_mask[10] + visited_mask[11];
                            count_temp[6] <= visited_mask[12] + visited_mask[13];
                            count_temp[7] <= visited_mask[14] + visited_mask[15];
                            bit_cnt_stage <= 4'd1;
                        end
                        4'd1: begin
                            // 8 -> 4 (indices 0-7 now hold 2-bit sums)
                            count_temp[0] <= count_temp[0] + count_temp[1];
                            count_temp[1] <= count_temp[2] + count_temp[3];
                            count_temp[2] <= count_temp[4] + count_temp[5];
                            count_temp[3] <= count_temp[6] + count_temp[7];
                            bit_cnt_stage <= 4'd2;
                        end
                        4'd2: begin
                            // 4 -> 2 (indices 0-3 hold 3-bit sums)
                            count_temp[0] <= count_temp[0] + count_temp[1];
                            count_temp[1] <= count_temp[2] + count_temp[3];
                            bit_cnt_stage <= 4'd3;
                        end
                        4'd3: begin
                            // 2 -> 1 (indices 0-1 hold 4-bit sums)
                            bit_count <= count_temp[0] + count_temp[1];
                            bit_cnt_stage <= 4'd4;
                        end
                    endcase
                end
                
                OUTPUT: begin
                    // Store result
                    results[target_idx] <= bit_count;
                    
                    // Increment target
                    if (target_idx < 15) target_idx <= target_idx + 4'd1;
                    
                    // Reset bit counter for next iteration
                    bit_cnt_stage <= 4'd0;
                end
                
                DONE: begin
                    done <= 1'b1;
                    target_idx <= 4'd0;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= DONE; // Force finish
            end
        end
    end

endmodule