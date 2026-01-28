module PermutationCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [2:0] k,
    input wire [31:0] p,
    output reg [31:0] result,
    output reg done
);

// State declarations
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] INIT       = 4'd1;
localparam [3:0] COMPUTE_I  = 4'd2;
localparam [3:0] COMPUTE_J  = 4'd3;
localparam [3:0] COMPUTE_D  = 4'd4;
localparam [3:0] CALC_SUM   = 4'd5;
localparam [3:0] STORE      = 4'd6;
localparam [3:0] CHECK_DONE = 4'd7;
localparam [3:0] SUM_RESULT = 4'd8;
localparam [3:0] FINISH     = 4'd9;

reg [3:0] state, next_state;

// Registers for loop variables
reg [7:0] i_idx;
reg [2:0] j_idx;
reg d_idx;
reg [31:0] cycle_counter;
localparam [31:0] MAX_CYCLES = 32'd2000;

// DP table storage - using internal registers for n <= 128
// dp[i][j][d] stored as: dp[i][j][d] where i=0..127, j=0..6, d=0..1
reg [31:0] dp [0:127][0:6][0:1];

// Temporary computation registers
reg [31:0] sum_temp;
reg [31:0] new_value;
reg [31:0] dp_prev_inc;
reg [31:0] dp_prev_dec;
reg [31:0] dp_prev_j_inc;
reg [31:0] dp_prev_j_dec;
reg [31:0] dp_curr;

// Helper signals
reg computation_done;
reg [31:0] max_i;
reg [31:0] max_j;

// Intermediate modulo calculation
reg [63:0] temp_sum;
reg [31:0] temp_result;

integer idx_i, idx_j, idx_d;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        i_idx <= 8'd0;
        j_idx <= 3'd0;
        d_idx <= 1'b0;
        cycle_counter <= 32'd0;
        sum_temp <= 32'd0;
        new_value <= 32'd0;
        dp_prev_inc <= 32'd0;
        dp_prev_dec <= 32'd0;
        dp_prev_j_inc <= 32'd0;
        dp_prev_j_dec <= 32'd0;
        dp_curr <= 32'd0;
        temp_sum <= 64'd0;
        temp_result <= 32'd0;
        computation_done <= 1'b0;
        max_i <= 32'd0;
        max_j <= 32'd0;
        // Initialize DP table to zero
        for (idx_i = 0; idx_i < 128; idx_i = idx_i + 1) begin
            for (idx_j = 0; idx_j < 7; idx_j = idx_j + 1) begin
                dp[idx_i][idx_j][0] <= 32'd0;
                dp[idx_i][idx_j][1] <= 32'd0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 32'd0;
                if (start && n > 8'd0 && k > 3'd0 && k <= 3'd7) begin
                    state <= INIT;
                end else begin
                    state <= IDLE;
                end
            end

            INIT: begin
                // Reset DP table and initialize base case
                for (idx_i = 0; idx_i < 128; idx_i = idx_i + 1) begin
                    for (idx_j = 0; idx_j < 7; idx_j = idx_j + 1) begin
                        dp[idx_i][idx_j][0] <= 32'd0;
                        dp[idx_i][idx_j][1] <= 32'd0;
                    end
                end
                // Initialize dp[1][1][0] = dp[1][1][1] = 1
                dp[1][1][0] <= 32'd1;
                dp[1][1][1] <= 32'd1;
                i_idx <= 8'd2;  // Start from i=2
                state <= COMPUTE_I;
                max_i <= {24'd0, n};
                max_j <= {29'd0, k};
                cycle_counter <= 32'd1;
            end

            COMPUTE_I: begin
                if (i_idx <= n) begin
                    j_idx <= 3'd1;  // Start j from 1
                    state <= COMPUTE_J;
                end else begin
                    state <= SUM_RESULT;
                end
            end

            COMPUTE_J: begin
                if (j_idx <= max_j[2:0] && j_idx < i_idx[2:0]) begin
                    d_idx <= 1'b0;  // Start d from 0
                    state <= COMPUTE_D;
                end else begin
                    i_idx <= i_idx + 8'd1;
                    state <= COMPUTE_I;
                end
            end

            COMPUTE_D: begin
                if (d_idx <= 1'b1) begin
                    // Compute dp[i][j][d] based on previous states
                    sum_temp <= 32'd0;
                    
                    // For d=0 (increasing) or d=1 (decreasing)
                    // Case 1: Extend from run with same direction
                    if (j_idx > 3'd1) begin
                        // dp[i-1][j-1][d]
                        dp_prev_inc <= dp[i_idx - 8'd1][j_idx - 3'd1][d_idx];
                    end else begin
                        dp_prev_inc <= 32'd0;
                    end
                    
                    // Case 2: Start new run from opposite direction or shorter runs
                    // For each t from 1 to k-1 where t != j
                    dp_prev_dec <= 32'd0;
                    dp_prev_j_inc <= 32'd0;
                    dp_prev_j_dec <= 32'd0;
                    
                    // We need to sum over all previous t
                    // This will be done in next state
                    state <= CALC_SUM;
                end else begin
                    j_idx <= j_idx + 3'd1;
                    state <= COMPUTE_J;
                end
            end

            CALC_SUM: begin
                // Sum dp[i-1][t][d] for all valid t
                // Also sum dp[i-1][t][~d] for transition to new direction
                temp_sum <= 64'd0;
                
                // Add extending run
                if (j_idx > 3'd1) begin
                    temp_sum <= temp_sum + dp_prev_inc;
                end
                
                // Add from other t values (new run starts)
                // This is complex - we'll compute in loops
                // For efficiency, we compute partial sums
                for (idx_j = 1; idx_j < 7; idx_j = idx_j + 1) begin
                    if (idx_j < i_idx[2:0] && idx_j < max_j[2:0] && idx_j != j_idx[2:0]) begin
                        // Same direction continuation
                        temp_sum <= temp_sum + dp[i_idx - 8'd1][idx_j][d_idx];
                        // Different direction (switch)
                        temp_sum <= temp_sum + dp[i_idx - 8'd1][idx_j][~d_idx];
                    end
                end
                
                // Apply modulo p
                if (p != 32'd0) begin
                    temp_result <= temp_sum % p;
                end else begin
                    temp_result <= temp_sum[31:0];
                end
                
                state <= STORE;
            end

            STORE: begin
                dp[i_idx][j_idx][d_idx] <= temp_result;
                d_idx <= d_idx + 1'b1;
                state <= COMPUTE_D;
            end

            SUM_RESULT: begin
                // Sum all dp[n][j][d] for valid j
                sum_temp <= 32'd0;
                for (idx_j = 1; idx_j < 7; idx_j = idx_j + 1) begin
                    if (idx_j <= max_j[2:0]) begin
                        sum_temp <= sum_temp + dp[n][idx_j][0];
                        sum_temp <= sum_temp + dp[n][idx_j][1];
                    end
                end
                state <= CHECK_DONE;
            end

            CHECK_DONE: begin
                // Apply final modulo
                if (p != 32'd0) begin
                    result <= sum_temp % p;
                end else begin
                    result <= sum_temp[31:0];
                end
                done <= 1'b1;
                state <= FINISH;
            end

            FINISH: begin
                done <= 1'b0;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
        
        // Safety: prevent infinite loops
        cycle_counter <= cycle_counter + 32'd1;
        if (cycle_counter >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            state <= SUM_RESULT;  // Force computation to finish
        end
    end
end

endmodule