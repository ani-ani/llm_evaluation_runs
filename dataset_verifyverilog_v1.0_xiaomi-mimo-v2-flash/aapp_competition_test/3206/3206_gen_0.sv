module skyline_builder (
    input clk,
    input rst_n,
    input start,
    input [15:0] block_heights [0:14],
    input [15:0] building_targets [0:14],
    input [3:0] N_val,
    input [3:0] S_val,
    output reg result_valid,
    output reg result_done,
    output reg [3:0] current_building,
    output reg [15:0] blocks_used_mask,
    output reg [3:0] num_blocks_used
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_SUM     = 4'd1;
    localparam [3:0] PARTITION_START = 4'd2;
    localparam [3:0] FIND_SUBSET   = 4'd3;
    localparam [3:0] UPDATE_USED   = 4'd4;
    localparam [3:0] FINISHED      = 4'd5;
    localparam [3:0] IMPOSSIBLE    = 4'd6;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [31:0] sum_blocks, sum_targets;
    reg [31:0] current_target;
    reg [15:0] used_blocks_mask;
    reg [3:0] building_idx;
    reg [15:0] subset_mask;
    reg [15:0] max_subset_mask;
    reg [31:0] subset_sum;
    reg [3:0] num_blocks_in_subset;
    reg found_subset;
    
    // Control
    reg [15:0] i;
    reg [3:0] j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_done <= 1'b0;
            current_building <= 4'd0;
            blocks_used_mask <= 16'd0;
            num_blocks_used <= 4'd0;
            sum_blocks <= 32'd0;
            sum_targets <= 32'd0;
            current_target <= 32'd0;
            used_blocks_mask <= 16'd0;
            building_idx <= 4'd0;
            subset_mask <= 16'd0;
            max_subset_mask <= 16'd0;
            subset_sum <= 32'd0;
            num_blocks_in_subset <= 4'd0;
            found_subset <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_done <= 1'b0;
                    result_valid <= 1'b0;
                    current_building <= 4'd0;
                    blocks_used_mask <= 16'd0;
                    num_blocks_used <= 4'd0;
                    sum_blocks <= 32'd0;
                    sum_targets <= 32'd0;
                    used_blocks_mask <= 16'd0;
                    building_idx <= 4'd0;
                end
                
                CHECK_SUM: begin
                    // Sum all valid block heights
                    if (i < 4'd15 && i < N_val) begin
                        sum_blocks <= sum_blocks + {16'd0, block_heights[i]};
                        i <= i + 4'd1;
                    end else if (i == 4'd15 || i == N_val) begin
                        // Sum all valid building targets
                        if (j < 4'd15 && j < S_val) begin
                            sum_targets <= sum_targets + {16'd0, building_targets[j]};
                            j <= j + 4'd1;
                        end
                    end
                end
                
                PARTITION_START: begin
                    building_idx <= 4'd0;
                    used_blocks_mask <= 16'd0;
                end
                
                FIND_SUBSET: begin
                    // Calculate max mask based on unused blocks
                    // Initialize subset iteration
                    if (subset_mask == 16'd0) begin
                        subset_mask <= 16'd1;
                        max_subset_mask <= 16'd0;
                        // Create mask for unused blocks only
                        max_subset_mask <= (~used_blocks_mask) & ((1 << N_val) - 1);
                    end else begin
                        // Check current subset
                        // Calculate sum of selected blocks
                        subset_sum <= 32'd0;
                        num_blocks_in_subset <= 4'd0;
                        
                        // Summation logic (sequential for hardware efficiency)
                        if (j < N_val) begin
                            if (subset_mask[j]) begin
                                subset_sum <= subset_sum + {16'd0, block_heights[j]};
                                num_blocks_in_subset <= num_blocks_in_subset + 4'd1;
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            // Check if sum matches and blocks are valid (not already used)
                            if (subset_sum == current_target && num_blocks_in_subset > 4'd0) begin
                                found_subset <= 1'b1;
                            end else begin
                                // Generate next subset mask
                                // Skip subsets that use already used blocks
                                // This is handled by mask constraint
                                subset_mask <= subset_mask + 4'd1;
                            end
                        end
                    end
                end
                
                UPDATE_USED: begin
                    used_blocks_mask <= used_blocks_mask | subset_mask;
                    blocks_used_mask <= subset_mask;
                    num_blocks_used <= num_blocks_in_subset;
                    current_building <= building_idx;
                    found_subset <= 1'b0;
                    subset_mask <= 16'd0;
                    j <= 4'd0;
                    building_idx <= building_idx + 4'd1;
                end
                
                FINISHED: begin
                    result_valid <= 1'b1;
                    result_done <= 1'b1;
                end
                
                IMPOSSIBLE: begin
                    result_valid <= 1'b0;
                    result_done <= 1'b1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_SUM;
                    i = 4'd0;
                    j = 4'd0;
                end
            end
            
            CHECK_SUM: begin
                if (i < 4'd15 && i < N_val) begin
                    next_state = CHECK_SUM;
                end else if (j < 4'd15 && j < S_val) begin
                    next_state = CHECK_SUM;
                end else begin
                    if (sum_blocks == sum_targets) begin
                        next_state = PARTITION_START;
                    end else begin
                        next_state = IMPOSSIBLE;
                    end
                end
            end
            
            PARTITION_START: begin
                if (building_idx < S_val) begin
                    current_target = {16'd0, building_targets[building_idx]};
                    next_state = FIND_SUBSET;
                    subset_mask = 16'd0;
                    j = 4'd0;
                end else begin
                    next_state = FINISHED;
                end
            end
            
            FIND_SUBSET: begin
                // Logic: iterate through subsets of unused blocks
                // Max subsets: 2^15 = 32768
                // We need to generate all combinations
                if (subset_mask == 16'd0) begin
                    next_state = FIND_SUBSET;
                end else if (j < N_val) begin
                    next_state = FIND_SUBSET;
                end else begin
                    if (found_subset) begin
                        next_state = UPDATE_USED;
                    end else begin
                        // Check if we've exhausted all subsets
                        // We limit to valid unused blocks
                        // A simple next mask generation
                        // If mask reaches limit or exceeds unused blocks
                        if (subset_mask >= max_subset_mask) begin
                            next_state = IMPOSSIBLE;
                        end else begin
                            subset_mask = subset_mask + 4'd1;
                            // Skip masks that conflict with used blocks
                            while ((subset_mask & used_blocks_mask) != 16'd0 && subset_mask < max_subset_mask) begin
                                subset_mask = subset_mask + 4'd1;
                            end
                            next_state = FIND_SUBSET;
                            j = 4'd0;
                        end
                    end
                end
            end
            
            UPDATE_USED: begin
                next_state = PARTITION_START;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            IMPOSSIBLE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule