module PermutationCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [2:0] k,
    input wire [31:0] p,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // DP table dimensions
    localparam [6:0] MAX_N     = 7'd128;
    localparam [2:0] MAX_K     = 3'd7;
    localparam [0:0] MAX_D     = 1'd1;

    // Internal registers
    reg [2:0] state;
    reg [7:0] i_reg;
    reg [2:0] j_reg;
    reg [0:0] d_reg;
    reg [2:0] new_j_reg;
    reg [0:0] new_d_reg;
    reg [31:0] temp_sum;
    reg [31:0] temp_val;
    reg [31:0] dp [0:127][0:6][0:1];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 8'd0;
            j_reg <= 3'd0;
            d_reg <= 1'd0;
            new_j_reg <= 3'd0;
            new_d_reg <= 1'd0;
            temp_sum <= 32'd0;
            temp_val <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize DP table
            integer i, j, d;
            for (i = 0; i < 128; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    for (d = 0; d < 2; d = d + 1) begin
                        dp[i][j][d] <= 32'd0;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize base case
                    dp[0][0][0] <= 1'b1;
                    dp[0][0][1] <= 1'b1;
                    i_reg <= 8'd1;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute next state
                    if (i_reg < n) begin
                        // Process current i
                        if (j_reg < k && d_reg <= MAX_D) begin
                            // Try extending run
                            if (j_reg < k - 1) begin
                                new_j_reg <= j_reg + 1'b1;
                                new_d_reg <= d_reg;
                                temp_val <= dp[i_reg - 1][j_reg][d_reg];
                                dp[i_reg][new_j_reg][new_d_reg] <= (temp_val + dp[i_reg][new_j_reg][new_d_reg]) % p;
                            end

                            // Try starting new run in opposite direction
                            new_j_reg <= 1'b1;
                            new_d_reg <= ~d_reg;
                            temp_val <= dp[i_reg - 1][j_reg][d_reg] * (i_reg - j_reg);
                            dp[i_reg][new_j_reg][new_d_reg] <= (temp_val + dp[i_reg][new_j_reg][new_d_reg]) % p;

                            // Move to next j,d
                            if (j_reg == k - 1 && d_reg == MAX_D) begin
                                j_reg <= 3'd0;
                                d_reg <= 1'd0;
                                i_reg <= i_reg + 1'b1;
                            end else if (d_reg == MAX_D) begin
                                j_reg <= j_reg + 1'b1;
                                d_reg <= 1'd0;
                            end else begin
                                d_reg <= d_reg + 1'b1;
                            end
                        end
                    end else begin
                        // Sum all valid final states
                        temp_sum <= 32'd0;
                        for (j_reg = 0; j_reg < k; j_reg = j_reg + 1) begin
                            for (d_reg = 0; d_reg < 2; d_reg = d_reg + 1) begin
                                temp_sum <= (temp_sum + dp[n - 1][j_reg][d_reg]) % p;
                            end
                        end
                        result <= temp_sum;
                        state <= FINISH;
                    end

                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule