module max_diversity (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] partner_frag [0:15],
    input wire [15:0] partner_step [0:15],
    input wire [15:0] partner_awake_frag [0:15],
    input wire [15:0] partner_awake_step [0:15],
    input wire [3:0] n,
    input wire [2:0] k,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] EXPAND       = 4'd1;
    localparam [3:0] SORT_INIT    = 4'd2;
    localparam [3:0] SORT_PASS    = 4'd3;
    localparam [3:0] SORT_WAIT    = 4'd4;
    localparam [3:0] DP_INIT      = 4'd5;
    localparam [3:0] DP_COMPUTE   = 4'd6;
    localparam [3:0] DP_UPDATE    = 4'd7;
    localparam [3:0] FIND_MAX     = 4'd8;
    localparam [3:0] FINISH       = 4'd9;

    reg [3:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd8000; // Safe timeout

    // Expanded states: max 32 (16 partners * 2 states each)
    // We store them in flattened arrays for Icarus compatibility
    reg [15:0] state_frag [0:31];
    reg [15:0] state_step [0:31];
    reg [0:0] state_cost [0:31]; // 1 bit: 0 or 1
    reg [4:0] state_count; // Number of valid states (0-32)
    reg [4:0] sort_limit; // Current upper bound for bubble sort

    // DP Table: dp[i][c]
    // i: state index (0-31), c: cost (0-4)
    // Flattened: dp[i*5 + c]
    // Value: 5 bits (max chain length 16)
    reg [4:0] dp [0:159]; // 32 * 5 = 160 entries
    reg [4:0] max_chain_len;

    // Control variables
    reg [4:0] i, j; // Indices for loops
    reg [2:0] c;    // Cost index
    reg [15:0] temp_frag, temp_step;
    reg temp_cost;
    reg [4:0] dp_idx_curr, dp_idx_prev;
    reg [4:0] len_prev, new_len;
    reg [15:0] cand_frag, cand_step;
    reg cand_cost;
    reg [2:0] c_idx;

    // Initialize all registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            state_count <= 5'd0;
            sort_limit <= 5'd0;
            max_chain_len <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            c <= 3'd0;
            temp_frag <= 16'd0;
            temp_step <= 16'd0;
            temp_cost <= 1'b0;
            dp_idx_curr <= 5'd0;
            dp_idx_prev <= 5'd0;
            len_prev <= 5'd0;
            new_len <= 5'd0;
            cand_frag <= 16'd0;
            cand_step <= 16'd0;
            cand_cost <= 1'b0;
            c_idx <= 3'd0;
            
            // Initialize arrays
            for (int idx = 0; idx < 32; idx = idx + 1) begin
                state_frag[idx] <= 16'd0;
                state_step[idx] <= 16'd0;
                state_cost[idx] <= 1'b0;
            end
            for (int idx = 0; idx < 160; idx = idx + 1) begin
                dp[idx] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    state_count <= 5'd0;
                    sort_limit <= 5'd0;
                    max_chain_len <= 5'd0;
                    // Don't clear arrays here, will be overwritten
                end

                EXPAND: begin
                    // Generate states: (frag, step, 0) and (awake_frag, awake_step, 1)
                    // i iterates 0 to n-1
                    if (i < n) begin
                        // State 1: Unawakened (cost 0)
                        // index = 2*i
                        state_frag[2*i] <= partner_frag[i];
                        state_step[2*i] <= partner_step[i];
                        state_cost[2*i] <= 1'b0;
                        
                        // State 2: Awakened (cost 1) - if awake values are non-zero
                        // index = 2*i + 1
                        state_frag[2*i + 1] <= partner_awake_frag[i];
                        state_step[2*i + 1] <= partner_awake_step[i];
                        
                        // Determine if awakenable (check if any input is non-zero)
                        // Using simple OR reduction
                        if ((partner_awake_frag[i] != 16'd0) || (partner_awake_step[i] != 16'd0)) begin
                            state_cost[2*i + 1] <= 1'b1;
                        end else begin
                            state_cost[2*i + 1] <= 1'b0;
                        end
                        
                        i <= i + 5'd1;
                    end else begin
                        state_count <= {1'b0, n} * 5'd2; // 2*n
                        i <= 5'd0;
                    end
                end

                SORT_INIT: begin
                    sort_limit <= state_count - 5'd1;
                    i <= 5'd0;
                    j <= 5'd0;
                end

                SORT_PASS: begin
                    // Bubble sort: compare j and j+1
                    if (j < sort_limit) begin
                        if (state_frag[j] > state_frag[j+1]) begin
                            // Swap
                            temp_frag <= state_frag[j];
                            temp_step <= state_step[j];
                            temp_cost <= state_cost[j];
                            
                            state_frag[j] <= state_frag[j+1];
                            state_step[j] <= state_step[j+1];
                            state_cost[j] <= state_cost[j+1];
                            
                            state_frag[j+1] <= temp_frag;
                            state_step[j+1] <= temp_step;
                            state_cost[j+1] <= temp_cost;
                        end
                        j <= j + 5'd1;
                    end else begin
                        i <= i + 5'd1;
                        j <= 5'd0;
                        // Reset temp to avoid latch inference
                        temp_frag <= 16'd0;
                        temp_step <= 16'd0;
                        temp_cost <= 1'b0;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table to 0 (already 0 on reset, but safety)
                    // Also set base cases: dp[i][cost_i] = 1
                    if (i < state_count) begin
                        // Calculate index: i * 5 + cost
                        // cost is 1 bit, so either 0 or 1
                        if (state_cost[i]) begin
                            dp[i*5 + 1] <= 5'd1;
                        end else begin
                            dp[i*5 + 0] <= 5'd1;
                        end
                        i <= i + 5'd1;
                    end else begin
                        i <= 5'd0;
                        j <= 5'd0;
                        c <= 3'd0;
                    end
                end

                DP_COMPUTE: begin
                    // Iterate through states i (current)
                    if (i < state_count) begin
                        cand_frag <= state_frag[i];
                        cand_step <= state_step[i];
                        cand_cost <= state_cost[i];
                        j <= 5'd0; // Start checking from previous states
                        c <= 3'd0;
                        next_state <= DP_UPDATE;
                    end else begin
                        next_state <= FIND_MAX;
                    end
                end

                DP_UPDATE: begin
                    // Inner loop: check all previous states j
                    if (j < i) begin
                        // Check domination: frag_j < frag_i AND step_j < step_i
                        if ((state_frag[j] < cand_frag) && (state_step[j] < cand_step)) begin
                            // Transition valid. Try all costs c_idx
                            // Total cost at i = c_idx + cand_cost
                            // Max allowed is k (0-4)
                            for (c_idx = 0; c_idx < 5; c_idx = c_idx + 1) begin
                                if (c_idx + {2'b0, cand_cost} <= k) begin
                                    // Look at dp[j][c_idx]
                                    len_prev <= dp[j*5 + c_idx];
                                    if (len_prev > 0) begin
                                        new_len <= len_prev + 5'd1;
                                        // Update dp[i][c_idx + cost]
                                        if (new_len > dp[i*5 + (c_idx + {2'b0, cand_cost})]) begin
                                            dp[i*5 + (c_idx + {2'b0, cand_cost})] <= new_len;
                                        end
                                    end
                                end
                            end
                        end
                        j <= j + 5'd1;
                    end else begin
                        // Done with state i
                        i <= i + 5'd1;
                        next_state <= DP_COMPUTE;
                    end
                    // Reset values for next iteration to prevent latching
                    len_prev <= 5'd0;
                    new_len <= 5'd0;
                end

                FIND_MAX: begin
                    // Iterate over all dp[i][c] for c <= k
                    if (i < state_count) begin
                        if (c <= k) begin
                            if (dp[i*5 + c] > max_chain_len) begin
                                max_chain_len <= dp[i*5 + c];
                            end
                            c <= c + 3'd1;
                        end else begin
                            c <= 3'd0;
                            i <= i + 5'd1;
                        end
                    end else begin
                        result <= max_chain_len[3:0];
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? EXPAND : IDLE;
            EXPAND: next_state = (i < n) ? EXPAND : SORT_INIT;
            SORT_INIT: next_state = SORT_PASS;
            SORT_PASS: begin
                if (i < state_count - 5'd1) next_state = SORT_PASS;
                else if (j < sort_limit) next_state = SORT_PASS;
                else if (state_count > 5'd0) next_state = SORT_WAIT;
                else next_state = SORT_WAIT; // No states
            end
            SORT_WAIT: next_state = DP_INIT;
            DP_INIT: next_state = (i < state_count) ? DP_INIT : DP_COMPUTE;
            DP_COMPUTE: next_state = (i < state_count) ? DP_UPDATE : FIND_MAX;
            DP_UPDATE: next_state = DP_UPDATE; // Controlled inside block
            FIND_MAX: begin
                if (i < state_count) next_state = FIND_MAX;
                else next_state = FINISH;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
        
        // Override for DP_UPDATE flow control
        if (state == DP_UPDATE) begin
            if (j < i) next_state = DP_UPDATE;
            else next_state = DP_COMPUTE;
        end
        
        // Timeout
        if (cycle_count > MAX_CYCLES) next_state = IDLE;
    end

endmodule