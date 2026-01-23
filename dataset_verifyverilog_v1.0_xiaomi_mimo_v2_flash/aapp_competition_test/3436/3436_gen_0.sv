module compute_F(
    input clk,
    input rst_n,
    input start,
    input [3:0] x,
    input [3:0] y,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Constants
    localparam [31:0] MOD = 32'd1000000007;

    // State and control registers
    reg [1:0] state, next_state;
    reg [3:0] i, j;          // Current cell coordinates
    reg [3:0] next_i, next_j;
    reg [31:0] dp [0:8][0:8]; // 9x9 DP array
    reg [31:0] temp_result;
    reg done_internal;
    reg [4:0] cycle_count;    // To track progress (max 9*9=81)

    // Combinational logic for DP value calculation
    wire [31:0] dp_i_m1_j;   // dp[i-1][j] if i>0
    wire [31:0] dp_i_m2_j;   // dp[i-2][j] if i>=2
    wire [31:0] dp_i_j_m1;   // dp[i][j-1] if j>0
    wire [31:0] dp_i_j_m2;   // dp[i][j-2] if j>=2

    assign dp_i_m1_j = (i > 0) ? dp[i-1][j] : 32'd0;
    assign dp_i_m2_j = (i >= 2) ? dp[i-2][j] : 32'd0;
    assign dp_i_j_m1 = (j > 0) ? dp[i][j-1] : 32'd0;
    assign dp_i_j_m2 = (j >= 2) ? dp[i][j-2] : 32'd0;

    // State transition logic (combinational)
    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        done_internal = 1'b0;
        temp_result = result;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    next_i = 4'd0;
                    next_j = 4'd0;
                end
            end

            COMPUTE: begin
                // Compute current cell dp[i][j]
                // Base cases for i=0 or j=0 handled implicitly by dependency logic
                // dp[0][0] = 0 (default)
                // dp[0][1] = 1, dp[1][0] = 1 are handled by the formulas below

                if (i == 4'd0 && j == 4'd0) begin
                    // dp[0][0] is already 0 (default)
                end
                // For i>=2, j=0: dp[i][0] = (dp[i-1][0] + dp[i-2][0]) % MOD
                else if (j == 4'd0 && i >= 2) begin
                    temp_result = (dp_i_m1_j + dp_i_m2_j) % MOD;
                end
                // For i=0, j>=2: dp[0][j] = (dp[0][j-1] + dp[0][j-2]) % MOD
                else if (i == 4'd0 && j >= 2) begin
                    temp_result = (dp_i_j_m1 + dp_i_j_m2) % MOD;
                end
                // For general case (i>=1, j>=1) AND boundary cases (i=0,j=1) and (i=1,j=0)
                // Note: dp[0][1] and dp[1][0] depend on dp[0][0] which is 0
                else begin
                    temp_result = (dp_i_m1_j + dp_i_j_m1) % MOD;
                end

                // Determine next cell (row-major)
                if (j == 4'd8) begin
                    next_j = 4'd0;
                    next_i = i + 4'd1;
                end else begin
                    next_j = j + 4'd1;
                    next_i = i;
                end

                // Check completion condition: done when we just computed dp[x][y]
                // AND the next state would be beyond the target or just finished it
                // We compute dp[i][j] now. If (i==x && j==y), we are done with calculation.
                // We need to register this value and move to DONE state.
                if (i == x && j == y) begin
                    next_state = DONE_STATE;
                end
                // Safety timeout (though logic guarantees exit for x,y <= 8)
                else if (cycle_count > 8'd81) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done_internal = 1'b1;
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
            i <= 4'd0;
            j <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize DP array to 0
            for (int r = 0; r < 9; r = r + 1) begin
                for (int c = 0; c < 9; c = c + 1) begin
                    dp[r][c] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            done <= done_internal;

            if (state == IDLE && start) begin
                cycle_count <= 8'd0;
                // Reset DP array explicitly on new start if desired, though logic overwrites
            end else if (state == COMPUTE) begin
                cycle_count <= cycle_count + 8'd1;
                dp[i][j] <= temp_result;
                // If this was the target cell, store it to result output
                if (i == x && j == y) begin
                    result <= temp_result;
                end
            end
        end
    end

endmodule