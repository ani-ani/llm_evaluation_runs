module SmallYTowers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] cost_in [8:0],  // 9x16-bit costs
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] DONE      = 3'd3;
    localparam [2:0] ERROR     = 3'd4;
    
    // FSM state and next state
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Storage for DP tables (9 entries each)
    reg [31:0] dp_prev [0:8];   // dp[n-1][src][dst]
    reg [31:0] dp_prev2 [0:8];  // dp[n-2][src][dst]
    reg [31:0] dp_curr [0:8];   // dp[n][src][dst]
    reg [15:0] cost [0:8];      // cost matrix
    
    // Counters and indices
    reg [3:0] current_n;
    reg [3:0] n_target;
    reg [1:0] src_idx;
    reg [1:0] dst_idx;
    reg [1:0] aux_idx;
    reg [1:0] idx_counter;
    
    // Combinational calculation registers
    reg [31:0] cost1;
    reg [31:0] cost2;
    reg [31:0] temp_result;
    reg [31:0] temp_dp_prev_src_aux;
    reg [31:0] temp_dp_prev_aux_dst;
    reg [31:0] temp_dp_prev2_src_dst;
    reg [31:0] temp_dp_prev_aux_dst2;
    reg [31:0] temp_dp_prev_dst_src;
    reg [31:0] temp_dp_prev2_src_dst2;
    
    // Control signals
    reg calculation_done;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;  // Sufficient for n=10
    
    // Helper function for 2D to 1D index
    function automatic [3:0] get_index(input [1:0] r, input [1:0] c);
    begin
        get_index = {r, c};  // 4-bit index: r[1:0]c[1:0]
    end
    endfunction
    
    // Sequential FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all state and storage
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            n_target <= 4'd0;
            calculation_done <= 1'b0;
            cycle_count <= 4'd0;
            src_idx <= 2'd0;
            dst_idx <= 2'd0;
            idx_counter <= 2'd0;
            
            // Initialize DP tables
            dp_prev[0] <= 32'd0; dp_prev[1] <= 32'd0; dp_prev[2] <= 32'd0;
            dp_prev[3] <= 32'd0; dp_prev[4] <= 32'd0; dp_prev[5] <= 32'd0;
            dp_prev[6] <= 32'd0; dp_prev[7] <= 32'd0; dp_prev[8] <= 32'd0;
            
            dp_prev2[0] <= 32'd0; dp_prev2[1] <= 32'd0; dp_prev2[2] <= 32'd0;
            dp_prev2[3] <= 32'd0; dp_prev2[4] <= 32'd0; dp_prev2[5] <= 32'd0;
            dp_prev2[6] <= 32'd0; dp_prev2[7] <= 32'd0; dp_prev2[8] <= 32'd0;
            
            dp_curr[0] <= 32'd0; dp_curr[1] <= 32'd0; dp_curr[2] <= 32'd0;
            dp_curr[3] <= 32'd0; dp_curr[4] <= 32'd0; dp_curr[5] <= 32'd0;
            dp_curr[6] <= 32'd0; dp_curr[7] <= 32'd0; dp_curr[8] <= 32'd0;
            
            // Initialize cost matrix
            cost[0] <= 16'd0; cost[1] <= 16'd0; cost[2] <= 16'd0;
            cost[3] <= 16'd0; cost[4] <= 16'd0; cost[5] <= 16'd0;
            cost[6] <= 16'd0; cost[7] <= 16'd0; cost[8] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    calculation_done <= 1'b0;
                    cycle_count <= 4'd0;
                    current_n <= 4'd0;
                    
                    if (start) begin
                        // Store target n
                        n_target <= (n > 4'd10) ? 4'd10 : n;
                        // Load cost matrix
                        cost[0] <= cost_in[0]; cost[1] <= cost_in[1]; cost[2] <= cost_in[2];
                        cost[3] <= cost_in[3]; cost[4] <= cost_in[4]; cost[5] <= cost_in[5];
                        cost[6] <= cost_in[6]; cost[7] <= cost_in[7]; cost[8] <= cost_in[8];
                    end
                end
                
                INIT: begin
                    // Initialize dp_prev for n=0 (all zeros) and dp_prev2
                    // Already initialized in reset
                    current_n <= 4'd1;
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Iterative calculation logic
                    // For each (src, dst) pair, compute dp_curr[src][dst]
                    // Use combinational calculation when indices are set
                    if (idx_counter == 2'd0) begin
                        // Computation is done, store result
                        dp_curr[{src_idx, dst_idx}] <= temp_result;
                        
                        // Move to next (src, dst) pair
                        if (dst_idx == 2'd2) begin
                            dst_idx <= 2'd0;
                            if (src_idx == 2'd2) begin
                                // All pairs calculated for this n
                                // Move to next n
                                if (current_n >= n_target) begin
                                    calculation_done <= 1'b1;
                                end else begin
                                    // Update DP tables for next iteration
                                    dp_prev2 <= dp_prev;  // Copy dp_prev to dp_prev2
                                    dp_prev <= dp_curr;   // Copy dp_curr to dp_prev
                                    current_n <= current_n + 4'd1;
                                end
                            end else begin
                                src_idx <= src_idx + 2'd1;
                            end
                        end else begin
                            dst_idx <= dst_idx + 2'd1;
                        end
                        idx_counter <= 2'd1;  // Start next computation
                    end else begin
                        // Prepare for next computation
                        idx_counter <= 2'd0;
                    end
                end
                
                DONE: begin
                    result <= dp_curr[2];  // dp[0][2] -> index 2
                    done <= 1'b1;
                end
                
                ERROR: begin
                    result <= 32'd0;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && (n >= 4'd1) && (n <= 4'd10)) begin
                    next_state = INIT;
                end else if (start) begin
                    next_state = ERROR;
                end
            end
            
            INIT: begin
                next_state = CALCULATE;
            end
            
            CALCULATE: begin
                if (calculation_done || (cycle_count >= MAX_CYCLES)) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Combinational calculation logic
    always @(*) begin
        // Default values
        temp_result = 32'd0;
        temp_dp_prev_src_aux = 32'd0;
        temp_dp_prev_aux_dst = 32'd0;
        temp_dp_prev2_src_dst = 32'd0;
        temp_dp_prev_aux_dst2 = 32'd0;
        temp_dp_prev_dst_src = 32'd0;
        temp_dp_prev2_src_dst2 = 32'd0;
        aux_idx = 3'd0;
        cost1 = 32'd0;
        cost2 = 32'd0;
        
        if (state == CALCULATE && idx_counter == 2'd1) begin
            // Calculate auxiliary rod for this (src, dst)
            if (src_idx != dst_idx) begin
                aux_idx = 3'd3 - src_idx - dst_idx;
                
                // Get dp values for this pair
                temp_dp_prev_src_aux = dp_prev[{src_idx, aux_idx}];
                temp_dp_prev_aux_dst = dp_prev[{aux_idx, dst_idx}];
                temp_dp_prev2_src_dst = dp_prev2[{src_idx, dst_idx}];
                temp_dp_prev_aux_dst2 = dp_prev[{aux_idx, dst_idx}];
                temp_dp_prev_dst_src = dp_prev[{dst_idx, src_idx}];
                temp_dp_prev2_src_dst2 = dp_prev2[{src_idx, dst_idx}];
                
                // Strategy 1: direct move
                cost1 = temp_dp_prev_src_aux + cost[{src_idx, dst_idx}] + temp_dp_prev_aux_dst;
                
                // Strategy 2: through auxiliary (for n>=2)
                if (current_n >= 4'd2) begin
                    cost2 = temp_dp_prev2_src_dst + 
                            cost[{src_idx, aux_idx}] + 
                            temp_dp_prev_aux_dst2 + 
                            cost[{aux_idx, dst_idx}] + 
                            temp_dp_prev_dst_src + 
                            cost[{src_idx, dst_idx}] + 
                            temp_dp_prev2_src_dst2;
                    
                    // Choose minimum
                    temp_result = (cost1 < cost2) ? cost1 : cost2;
                end else begin
                    // For n=1, only strategy 1
                    temp_result = cost1;
                end
            end else begin
                // src == dst, cost is 0
                temp_result = 32'd0;
            end
        end
    end

endmodule