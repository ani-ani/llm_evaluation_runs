module kmeans_1d (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] k [0:7],
    input wire [1:0] m,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PRECOMPUTE  = 3'd1;
    localparam [2:0] DP_INIT     = 3'd2;
    localparam [2:0] DP_COMPUTE  = 3'd3;
    localparam [2:0] OUTPUT      = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // State and counters
    reg [2:0] state, next_state;
    reg [3:0] i_cnt, t_cnt, j_cnt; // Loop counters
    reg [7:0] cycle_limit;

    // Memory for prefix sums (8+1 entries)
    reg [15:0] sum_k [0:8]; // sum_k[0] = 0, sum_k[i] = sum_{j=0}^{i-1} k_j
    // Memory for weighted prefix sums
    reg [23:0] sum_w [0:8]; // sum_w[0] = 0, sum_w[i] = sum_{j=0}^{i-1} j*k_j
    
    // DP memory: dp[i][j]
    // i goes 0..8 (9 values), j goes 0..3 (4 values)
    reg [23:0] dp [0:8][0:3]; // Q16.8 fixed point storage

    // Intermediate calculation registers
    reg [15:0] delta_k;
    reg [23:0] delta_w;
    reg [47:0] temp_sq;      // (delta_w)^2
    reg [47:0] temp_mul;     // temp_sq * 256
    reg [23:0] cost_val;     // Computed cost for cluster
    reg [23:0] candidate_cost; // dp[t][j-1] + cost
    reg [23:0] min_cost;     // Minimum cost for current dp[i][j]
    
    // Temp registers for division
    reg [47:0] div_num;
    reg [15:0] div_den;
    reg [23:0] div_result;
    reg [4:0] div_cnt;
    
    // Flags
    reg computing_division;
    reg update_dp;

    integer idx, jdx;

    // --- Reset & State Transition ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            // Reset memory to avoid Z/X
            for (idx = 0; idx < 9; idx = idx + 1) begin
                sum_k[idx] <= 16'd0;
                sum_w[idx] <= 24'd0;
                for (jdx = 0; jdx < 4; jdx = jdx + 1) begin
                    dp[idx][jdx] <= 24'd0;
                end
            end
        end else begin
            state <= next_state;
            // Default done signal logic
            if (state == IDLE) done <= 1'b0;
            if (state == FINISH) done <= 1'b1;
        end
    end

    // --- Main FSM Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PRECOMPUTE;
            PRECOMPUTE: if (i_cnt == 4'd9) next_state = DP_INIT;
            DP_INIT: next_state = DP_COMPUTE;
            DP_COMPUTE: if (i_cnt == 4'd9 && t_cnt == 4'd8 && j_cnt == m) next_state = OUTPUT;
            OUTPUT: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // --- Data Path ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_cnt <= 4'd0; t_cnt <= 4'd0; j_cnt <= 4'd0;
            cycle_limit <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    i_cnt <= 4'd0;
                    t_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                end
                PRECOMPUTE: begin
                    // Compute sum_k and sum_w
                    if (i_cnt == 4'd0) begin
                        sum_k[0] <= 16'd0;
                        sum_w[0] <= 24'd0;
                    end else begin
                        // sum_k[i] = sum_k[i-1] + k[i-1]
                        // sum_w[i] = sum_w[i-1] + (i-1)*k[i-1]
                        sum_k[i_cnt] <= sum_k[i_cnt-1] + {8'd0, k[i_cnt-1]};
                        sum_w[i_cnt] <= sum_w[i_cnt-1] + {16'd0, (i_cnt-1)} * {8'd0, k[i_cnt-1]};
                    end
                    i_cnt <= i_cnt + 4'd1;
                end
                DP_INIT: begin
                    // Initialize dp[0][0] = 0, others = infinity (max value)
                    // Using max 24'hFFFFFF as infinity
                    for (idx = 0; idx < 9; idx = idx + 1) begin
                        for (jdx = 0; jdx < 4; jdx = jdx + 1) begin
                            if (idx == 0 && jdx == 0) dp[idx][jdx] <= 24'd0;
                            else dp[idx][jdx] <= 24'hFFFFFF;
                        end
                    end
                end
                DP_COMPUTE: begin
                    // DP Loop: dp[i][j] = min(dp[t][j-1] + cost(t, i-1))
                    // i from 1 to 8, j from 1 to m
                    
                    // 1. Precompute delta_k and delta_w for cost(t, i-1)
                    delta_k <= sum_k[i_cnt] - sum_k[t_cnt];
                    delta_w <= sum_w[i_cnt] - sum_w[t_cnt];
                    
                    // 2. Calculate Cost: (delta_w^2 * 256) / delta_k
                    // We use a flag to sequence multiplication and division
                    if (delta_k != 16'd0) begin
                        // Start division cycle if denominator is valid
                        computing_division <= 1'b1;
                        div_num <= {24'd0, delta_w} * {24'd0, delta_w}; // delta_w^2 (48 bit)
                        div_den <= delta_k;
                        div_result <= 24'd0;
                        div_cnt <= 5'd24; // 24 bits precision
                        
                        // Note: In real hardware we would do parallel pipelined calc.
                        // Here we sequence. To save cycles in a real design, 
                        // we'd have dedicated logic. For synthesis:
                        // cost_val = (delta_w * delta_w * 256) / delta_k
                        temp_sq <= {24'd0, delta_w} * {24'd0, delta_w};
                    end
                end
            endcase

            // --- Division and Update Sequence (State Independent) ---
            // This runs in parallel with state checks in a real pipeline, 
            // but for Verilog combinational logic inside always block:
            if (computing_division) begin
                // Implement restoring division or simple shift/sub
                // Using shift-and-subtract (Booth-like)
                if (div_cnt > 0) begin
                    // Algorithm: (N << 24) / D * 256 -> (N * 256 * 256) / D = (N * 65536) / D
                    // Actually requirement: (W^2 * 256) / K
                    // Let's implement: Shift div_num left, subtract den if possible
                    div_num <= div_num << 1;
                    div_result <= div_result << 1;
                    if (div_num[47:23] >= {8'd0, div_den}) begin // Check high 25 bits vs denom 16 bits
                        div_num[47:23] <= div_num[47:23] - {8'd0, div_den};
                        div_result[0] <= 1'b1;
                    end
                    div_cnt <= div_cnt - 5'd1;
                end else begin
                    computing_division <= 1'b0;
                    cost_val <= div_result; // Result is Q8.8
                end
            end
            
            // DP Update Logic
            if (state == DP_COMPUTE && !computing_division && delta_k != 16'd0) begin
                candidate_cost <= dp[t_cnt][j_cnt-1] + cost_val;
                if (candidate_cost < min_cost) begin
                    min_cost <= candidate_cost;
                end
                
                // Check inner loop finish (t loop)
                if (t_cnt == i_cnt - 4'd1) begin
                    // Store min to dp[i][j]
                    dp[i_cnt][j_cnt] <= min_cost;
                    // Reset counters for next iteration
                    t_cnt <= 4'd0;
                    min_cost <= 24'hFFFFFF;
                    
                    // Advance i or j
                    if (i_cnt == 4'd8) begin
                        i_cnt <= 4'd1;
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                    end
                end else begin
                    t_cnt <= t_cnt + 4'd1;
                end
            end
            
            // Handle case where delta_k is 0 (invalid cluster)
            if (state == DP_COMPUTE && delta_k == 16'd0) begin
                 // Invalid cluster, skip (t_cnt advances)
                 if (t_cnt == i_cnt - 4'd1) begin
                    dp[i_cnt][j_cnt] <= min_cost;
                    t_cnt <= 4'd0;
                    min_cost <= 24'hFFFFFF;
                    if (i_cnt == 4'd8) begin
                        i_cnt <= 4'd1;
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                    end
                 end else begin
                    t_cnt <= t_cnt + 4'd1;
                 end
            end

            if (state == OUTPUT) begin
                // Result is dp[8][m] >> 8 (convert Q16.8 to Q8.8)
                result <= dp[8][m][15:0];
            end
        end
    end
endmodule