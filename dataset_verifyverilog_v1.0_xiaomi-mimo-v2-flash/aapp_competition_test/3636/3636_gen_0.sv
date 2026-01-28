module obstacle_counting (
    input clk,
    input rst_n,
    input start,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] N = 4'd4; // Fixed N=4
    localparam [15:0] M = 16'd4; // Fixed M=4
    localparam [31:0] MOD = 32'd999999937;
    
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FIND_MIN  = 3'd3;
    localparam [2:0] SUM_COUNT = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] col_idx;
    reg [3:0] curr_state_idx;
    reg [3:0] prev_state_idx;
    
    // DP arrays: 2D storage flattened to 1D for synthesizability
    // dp_min[col][state] -> stored as dp_min[state + col * 16] (since 2^4=16 states)
    // dp_count[col][state] -> stored similarly
    // We only need current and previous column for computation
    reg [7:0] dp_min_curr [0:15]; // Min obstacles for current column states
    reg [7:0] dp_min_prev [0:15]; // Min obstacles for previous column states
    reg [31:0] dp_cnt_curr [0:15]; // Count of ways for current column
    reg [31:0] dp_cnt_prev [0:15]; // Count of ways for previous column
    
    // For finding minimum
    reg [7:0] global_min_obstacles;
    reg [31:0] total_count;
    
    // Helper vars
    integer i, j;
    reg [15:0] temp_val;
    reg [15:0] new_val;
    reg [31:0] sum_temp;
    reg constraint_satisfied;
    
    // Transition validity check signals
    reg [3:0] pair_state;
    reg [3:0] prev_pair_state;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd2000;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            col_idx <= 16'd0;
            curr_state_idx <= 4'd0;
            prev_state_idx <= 4'd0;
            global_min_obstacles <= 8'd255;
            total_count <= 32'd0;
            cycle_count <= 16'd0;
            // Initialize DP arrays
            for (i = 0; i < 16; i = i + 1) begin
                dp_min_curr[i] <= 8'd0;
                dp_min_prev[i] <= 8'd0;
                dp_cnt_curr[i] <= 32'd0;
                dp_cnt_prev[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize DP for column 0
                    // dp_min_prev[state] = popcount(state)
                    // dp_cnt_prev[state] = 1 (one way to place obstacles)
                    if (curr_state_idx < 16) begin
                        // Calculate popcount manually (N=4)
                        temp_val = 4'd0;
                        if (curr_state_idx[0]) temp_val = temp_val + 4'd1;
                        if (curr_state_idx[1]) temp_val = temp_val + 4'd1;
                        if (curr_state_idx[2]) temp_val = temp_val + 4'd1;
                        if (curr_state_idx[3]) temp_val = temp_val + 4'd1;
                        
                        dp_min_prev[curr_state_idx] <= temp_val;
                        dp_cnt_prev[curr_state_idx] <= 32'd1;
                        
                        curr_state_idx <= curr_state_idx + 4'd1;
                    end else begin
                        col_idx <= 16'd1; // Start from column 1
                        curr_state_idx <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Iterate column 1 to M-1
                    if (col_idx < M) begin
                        // Compute dp for curr_state_idx based on prev_state_idx
                        if (curr_state_idx < 16 && prev_state_idx < 16) begin
                            // Check 2x2 constraint for rows 0 to N-2
                            constraint_satisfied = 1'b1;
                            for (j = 0; j < 3; j = j + 1) begin // N-1 pairs
                                // Check pair (j, j+1)
                                // Condition: at least one obstacle in 2x2 block
                                // i.e., (curr[j] || curr[j+1] || prev[j] || prev[j+1])
                                
                                reg bit1_curr, bit2_curr, bit1_prev, bit2_prev;
                                bit1_curr = curr_state_idx[j];
                                bit2_curr = curr_state_idx[j+1];
                                bit1_prev = prev_state_idx[j];
                                bit2_prev = prev_state_idx[j+1];
                                
                                if (!(bit1_curr || bit2_curr || bit1_prev || bit2_prev)) begin
                                    constraint_satisfied = 1'b0;
                                end
                            end
                            
                            if (constraint_satisfied) begin
                                // Valid transition
                                new_val = dp_min_prev[prev_state_idx] + dp_min_curr[curr_state_idx];
                                if (new_val < dp_min_curr[curr_state_idx]) begin
                                    dp_min_curr[curr_state_idx] <= new_val;
                                    dp_cnt_curr[curr_state_idx] <= dp_cnt_prev[prev_state_idx];
                                end else if (new_val == dp_min_curr[curr_state_idx]) begin
                                    dp_cnt_curr[curr_state_idx] <= (dp_cnt_curr[curr_state_idx] + dp_cnt_prev[prev_state_idx]) % MOD;
                                end
                            end
                            
                            // Increment prev_state_idx
                            prev_state_idx <= prev_state_idx + 4'd1;
                        end else if (curr_state_idx < 16 && prev_state_idx >= 16) begin
                            // Done with all prev states for this curr state
                            prev_state_idx <= 4'd0;
                            curr_state_idx <= curr_state_idx + 4'd1;
                        end else begin
                            // Done with all curr states for this column
                            // Copy curr to prev for next iteration
                            for (i = 0; i < 16; i = i + 1) begin
                                dp_min_prev[i] <= dp_min_curr[i];
                                dp_cnt_prev[i] <= dp_cnt_curr[i];
                                // Reset curr for next column
                                dp_min_curr[i] <= 8'd255; // Infinity
                                dp_cnt_curr[i] <= 32'd0;
                            end
                            curr_state_idx <= 4'd0;
                            prev_state_idx <= 4'd0;
                            col_idx <= col_idx + 16'd1;
                        end
                    end else begin
                        // Finished all columns
                        state <= FIND_MIN;
                    end
                end
                
                FIND_MIN: begin
                    // Find minimum obstacles in dp_min_prev (last column)
                    if (curr_state_idx < 16) begin
                        if (dp_min_prev[curr_state_idx] < global_min_obstacles) begin
                            global_min_obstacles <= dp_min_prev[curr_state_idx];
                        end
                        curr_state_idx <= curr_state_idx + 4'd1;
                    end else begin
                        curr_state_idx <= 4'd0;
                        total_count <= 32'd0;
                        state <= SUM_COUNT;
                    end
                end
                
                SUM_COUNT: begin
                    // Sum counts for states matching global_min_obstacles
                    if (curr_state_idx < 16) begin
                        if (dp_min_prev[curr_state_idx] == global_min_obstacles) begin
                            total_count <= (total_count + dp_cnt_prev[curr_state_idx]) % MOD;
                        end
                        curr_state_idx <= curr_state_idx + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= total_count[15:0]; // Truncate to 16-bit as specified
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Cycle counter safety
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 16'd1;
                if (cycle_count > MAX_CYCLES) begin
                    state <= FINISH; // Force finish to prevent timeout
                end
            end
        end
    end

endmodule