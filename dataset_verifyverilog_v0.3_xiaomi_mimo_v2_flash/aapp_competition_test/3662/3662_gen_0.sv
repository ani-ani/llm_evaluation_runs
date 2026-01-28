module TreePlanner (
    input clk,
    input rst_n,
    input start,
    input [13:0] L,       // Road length (0-10000)
    input [4:0] W,        // Road width (0-20)
    input [13:0] pos_0, pos_1, pos_2, pos_3, pos_4, pos_5, pos_6, pos_7, // Sorted positions (max 8 trees)
    output reg [31:0] result, // Q16.16 fixed-point result
    output reg done
);

// Parameters
localparam MAX_N = 8;
localparam K = 4'd4; // MAX_N / 2 = 4
localparam [3:0] MAX_INDEX = 4'd7; // 0-7

// State machine
localparam [2:0] IDLE       = 3'b000;
localparam [2:0] INIT_DP    = 3'b001;
localparam [2:0] COMPUTE    = 3'b010;
localparam [2:0] UPDATE_DP  = 3'b011;
localparam [2:0] DONE_STATE = 3'b100;
reg [2:0] state, next_state;

// DP state tracking
reg [3:0] i, j; // i = left assigned, j = right assigned
reg [3:0] init_cnt; // Counter for DP table initialization
reg [3:0] current_tree_idx; // i + j - 1

// DP table [0..4][0..4] - using packed arrays for Icarus compatibility
reg [31:0] dp_0, dp_1, dp_2, dp_3, dp_4;
reg [31:0] next_dp_0, next_dp_1, next_dp_2, next_dp_3, next_dp_4;

// Current position lookup
reg [13:0] current_pos_raw;
reg [31:0] current_pos_fp;

// Fixed-point constants
reg [31:0] W_fp; // W in Q16.16
reg [31:0] left_target_fp;
reg [31:0] right_target_fp;
reg [31:0] dist_left;
reg [31:0] dist_right;
reg [31:0] candidate1, candidate2;

// Counter for cycle limiting
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Function to read current position from inputs
function [13:0] get_pos;
    input [3:0] idx;
    begin
        case (idx)
            4'd0: get_pos = pos_0;
            4'd1: get_pos = pos_1;
            4'd2: get_pos = pos_2;
            4'd3: get_pos = pos_3;
            4'd4: get_pos = pos_4;
            4'd5: get_pos = pos_5;
            4'd6: get_pos = pos_6;
            4'd7: get_pos = pos_7;
            default: get_pos = 14'd0;
        endcase
    end
endfunction

// Function to get a specific DP value
function [31:0] get_dp;
    input [3:0] row;
    input [3:0] col;
    begin
        if (row == 4'd0) get_dp = dp_0;
        else if (row == 4'd1) get_dp = dp_1;
        else if (row == 4'd2) get_dp = dp_2;
        else if (row == 4'd3) get_dp = dp_3;
        else get_dp = dp_4;
    end
endfunction

// Function to get target position in Q16.16
function [31:0] get_target;
    input [3:0] row; // i or j
    input [13:0] L;
    input is_left; // 1 for left (i), 0 for right (j)
    begin
        if (row == 4'd0) begin
            get_target = 32'd0;
        end else if (K <= 3'd1) begin
            get_target = 32'd0;
        end else begin
            // Calculate (row * L) / (K-1) then shift left by 16
            // row*L can be up to 4*10000 = 40000 (fits in 16 bits)
            // K-1 = 3 (fits in 4 bits)
            get_target = ((row * L) / 3) << 16;
        end
    end
endfunction

// Combinational logic for state transition and next state logic
reg [1:0] dp_update_counter; // 0, 1, 2
reg [31:0] prev_dp_val;

always @(*) begin
    // Default assignments
    next_state = state;
    next_dp_0 = dp_0;
    next_dp_1 = dp_1;
    next_dp_2 = dp_2;
    next_dp_3 = dp_3;
    next_dp_4 = dp_4;
    
    // Calculate current tree position
    current_pos_raw = get_pos(current_tree_idx);
    current_pos_fp = {18'b0, current_pos_raw}; // Convert to Q16.16
    
    // Calculate targets
    left_target_fp = get_target(i, L, 1'b1);
    right_target_fp = get_target(j, L, 1'b0);
    
    // Calculate distances
    dist_left = 32'd0;
    dist_right = 32'd0;
    
    if (i > 4'd0) begin
        if (current_pos_fp >= left_target_fp)
            dist_left = current_pos_fp - left_target_fp;
        else
            dist_left = left_target_fp - current_pos_fp;
    end
    
    if (j > 4'd0) begin
        if (current_pos_fp >= right_target_fp)
            dist_right = (current_pos_fp - right_target_fp) + {W, 16'b0};
        else
            dist_right = (right_target_fp - current_pos_fp) + {W, 16'b0};
    end
    
    // Get previous DP values for updates
    if (i > 4'd0) begin
        prev_dp_val = (i == 4'd1) ? dp_0 : 
                     (i == 4'd2) ? dp_1 : 
                     (i == 4'd3) ? dp_2 : 
                     (i == 4'd4) ? dp_3 : dp_4;
        prev_dp_val = (j == 4'd0) ? prev_dp_val : 
                     (j == 4'd1) ? dp_1 : 
                     (j == 4'd2) ? dp_2 : 
                     (j == 4'd3) ? dp_3 : dp_4;
    end
    
    // State machine logic
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT_DP;
            end
        end
        
        INIT_DP: begin
            // Initialize DP table to max value
            if (init_cnt <= 4'd4) begin
                case (init_cnt)
                    4'd0: next_dp_0 = 32'h7FFFFFFF;
                    4'd1: next_dp_1 = 32'h7FFFFFFF;
                    4'd2: next_dp_2 = 32'h7FFFFFFF;
                    4'd3: next_dp_3 = 32'h7FFFFFFF;
                    4'd4: next_dp_4 = 32'h7FFFFFFF;
                endcase
                // Continue initialization
            end else begin
                // Set dp[0][0] = 0
                next_dp_0 = 32'd0;
                next_state = COMPUTE;
                i = 4'd0;
                j = 4'd0;
                current_tree_idx = 4'd0;
            end
        end
        
        COMPUTE: begin
            // Check if we have processed all trees
            if (current_tree_idx >= MAX_INDEX) begin
                // Done computing
                next_state = DONE_STATE;
            end else begin
                // Calculate candidate values
                candidate1 = 32'h7FFFFFFF;
                candidate2 = 32'h7FFFFFFF;
                
                // Get DP value at [i-1][j] if i > 0
                if (i > 4'd0) begin
                    // Read dp[i-1][j]
                    if (i == 4'd1) begin // i-1=0
                        if (j == 4'd0) prev_dp_val = dp_0;
                        else if (j == 4'd1) prev_dp_val = dp_1;
                        else if (j == 4'd2) prev_dp_val = dp_2;
                        else if (j == 4'd3) prev_dp_val = dp_3;
                        else prev_dp_val = dp_4;
                    end else if (i == 4'd2) begin // i-1=1
                        if (j == 4'd0) prev_dp_val = dp_1;
                        else if (j == 4'd1) prev_dp_val = dp_2;
                        else if (j == 4'd2) prev_dp_val = dp_3;
                        else if (j == 4'd3) prev_dp_val = dp_4;
                    end else if (i == 4'd3) begin // i-1=2
                        if (j == 4'd0) prev_dp_val = dp_2;
                        else if (j == 4'd1) prev_dp_val = dp_3;
                        else if (j == 4'd2) prev_dp_val = dp_4;
                    end else if (i == 4'd4) begin // i-1=3
                        if (j == 4'd0) prev_dp_val = dp_3;
                        else if (j == 4'd1) prev_dp_val = dp_4;
                    end
                    
                    candidate1 = prev_dp_val + dist_left;
                end
                
                // Get DP value at [i][j-1] if j > 0
                if (j > 4'd0) begin
                    // Read dp[i][j-1]
                    if (i == 4'd0) begin
                        if (j == 4'd1) prev_dp_val = dp_0;
                        else if (j == 4'd2) prev_dp_val = dp_1;
                        else if (j == 4'd3) prev_dp_val = dp_2;
                        else if (j == 4'd4) prev_dp_val = dp_3;
                    end else if (i == 4'd1) begin
                        if (j == 4'd1) prev_dp_val = dp_1;
                        else if (j == 4'd2) prev_dp_val = dp_2;
                        else if (j == 4'd3) prev_dp_val = dp_3;
                        else if (j == 4'd4) prev_dp_val = dp_4;
                    end else if (i == 4'd2) begin
                        if (j == 4'd1) prev_dp_val = dp_2;
                        else if (j == 4'd2) prev_dp_val = dp_3;
                        else if (j == 4'd3) prev_dp_val = dp_4;
                    end else if (i == 4'd3) begin
                        if (j == 4'd1) prev_dp_val = dp_3;
                        else if (j == 4'd2) prev_dp_val = dp_4;
                    end else if (i == 4'd4) begin
                        if (j == 4'd1) prev_dp_val = dp_4;
                    end
                    
                    candidate2 = prev_dp_val + dist_right;
                end
                
                // Update DP table at [i][j]
                next_state = UPDATE_DP;
            end
        end
        
        UPDATE_DP: begin
            // Read current DP value
            prev_dp_val = 32'h7FFFFFFF;
            if (i == 4'd0) prev_dp_val = dp_0;
            else if (i == 4'd1) prev_dp_val = dp_1;
            else if (i == 4'd2) prev_dp_val = dp_2;
            else if (i == 4'd3) prev_dp_val = dp_3;
            else if (i == 4'd4) prev_dp_val = dp_4;
            
            // Take minimum
            if (candidate1 < candidate2) begin
                if (candidate1 < prev_dp_val)
                    prev_dp_val = candidate1;
            end else begin
                if (candidate2 < prev_dp_val)
                    prev_dp_val = candidate2;
            end
            
            // Write back to DP table
            if (i == 4'd0) next_dp_0 = prev_dp_val;
            else if (i == 4'd1) next_dp_1 = prev_dp_val;
            else if (i == 4'd2) next_dp_2 = prev_dp_val;
            else if (i == 4'd3) next_dp_3 = prev_dp_val;
            else if (i == 4'd4) next_dp_4 = prev_dp_val;
            
            // Move to next (i,j) pair
            if (i < K && j == K) begin
                // Move to next i, reset j
                i = i + 4'd1;
                j = 4'd0;
                current_tree_idx = i + j; // i+j-1 + 1
            end else if (j < K) begin
                // Increment j
                j = j + 4'd1;
                current_tree_idx = i + j; // i+j-1 + 1
            end else begin
                // Should not reach here, but go to done
                next_state = DONE_STATE;
            end
            
            next_state = COMPUTE;
        end
        
        DONE_STATE: begin
            // Output result is dp[K][K]
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        init_cnt <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        current_tree_idx <= 4'd0;
        cycle_count <= 8'd0;
        
        // Initialize all DP registers
        dp_0 <= 32'h7FFFFFFF;
        dp_1 <= 32'h7FFFFFFF;
        dp_2 <= 32'h7FFFFFFF;
        dp_3 <= 32'h7FFFFFFF;
        dp_4 <= 32'h7FFFFFFF;
        
        W_fp <= 32'd0;
        current_pos_fp <= 32'd0;
        left_target_fp <= 32'd0;
        right_target_fp <= 32'd0;
        dist_left <= 32'd0;
        dist_right <= 32'd0;
        candidate1 <= 32'd0;
        candidate2 <= 32'd0;
        prev_dp_val <= 32'd0;
        
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        if (cycle_count >= MAX_CYCLES) begin
            state <= DONE_STATE;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
        
        // Update DP registers
        dp_0 <= next_dp_0;
        dp_1 <= next_dp_1;
        dp_2 <= next_dp_2;
        dp_3 <= next_dp_3;
        dp_4 <= next_dp_4;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    init_cnt <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    current_tree_idx <= 4'd0;
                    cycle_count <= 8'd0;
                end
            end
            
            INIT_DP: begin
                if (init_cnt <= 4'd4) begin
                    init_cnt <= init_cnt + 4'd1;
                end
            end
            
            COMPUTE: begin
                // Pre-calculate values for next cycle
                W_fp <= {W, 16'b0};
                
                if (current_tree_idx < MAX_INDEX) begin
                    current_pos_fp <= {18'b0, get_pos(current_tree_idx)};
                    left_target_fp <= get_target(i, L, 1'b1);
                    right_target_fp <= get_target(j, L, 1'b0);
                end
            end
            
            UPDATE_DP: begin
                // Read current DP value for comparison
                if (i == 4'd0) prev_dp_val <= dp_0;
                else if (i == 4'd1) prev_dp_val <= dp_1;
                else if (i == 4'd2) prev_dp_val <= dp_2;
                else if (i == 4'd3) prev_dp_val <= dp_3;
                else if (i == 4'd4) prev_dp_val <= dp_4;
            end
            
            DONE_STATE: begin
                // Read result from dp[K][K] = dp[4][4] = dp_4
                result <= dp_4;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule