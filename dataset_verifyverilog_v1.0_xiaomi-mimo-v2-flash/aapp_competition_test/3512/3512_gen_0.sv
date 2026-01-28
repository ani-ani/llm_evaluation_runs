module tsp_constrained #(
    parameter MAX_N = 15,
    parameter MAX_DIST = 1000
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N_in,
    input wire [9:0] data_in,
    input wire [3:0] row,
    input wire [3:0] col,
    input wire write_en,
    output reg [20:0] min_cost,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] INIT = 4'd2;
    localparam [3:0] DP_LOOP_I = 4'd3;
    localparam [3:0] DP_LOOP_M = 4'd4;
    localparam [3:0] DP_FINAL = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    reg [3:0] state, next_state;
    reg [3:0] N_reg;
    reg [20:0] dp_prev [0:14];  // dp[i-1][k]
    reg [20:0] dp_curr [0:14];  // dp[i][k]
    reg [9:0] dist [0:14][0:14]; // distance matrix
    reg [3:0] i_idx, m_idx, k_idx;
    reg [20:0] min_val, temp_val;
    reg [20:0] cycle_count;
    localparam [20:0] MAX_CYCLES = 21'd2000;
    reg [3:0] load_count, load_row, load_col;

    // Combinational logic for DP computations
    wire [20:0] dp_next_val;
    wire [20:0] dist_im, dist_i_im1;
    assign dist_im = (m_idx < MAX_N && i_idx < MAX_N) ? dist[i_idx][m_idx] : 10'd0;
    assign dist_i_im1 = (i_idx < MAX_N && (i_idx-1) < MAX_N) ? dist[i_idx][i_idx-1] : 10'd0;
    assign dp_next_val = dp_prev[m_idx] + dist_im;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 21'd0;
            N_reg <= 4'd0;
            cycle_count <= 21'd0;
            load_count <= 4'd0;
            load_row <= 4'd0;
            load_col <= 4'd0;
            i_idx <= 4'd0;
            m_idx <= 4'd0;
            k_idx <= 4'd0;
            min_val <= 21'd0;
            temp_val <= 21'd0;
            // Initialize dp arrays
            for (k_idx = 0; k_idx < MAX_N; k_idx = k_idx + 1) begin
                dp_prev[k_idx] <= 21'd0;
                dp_curr[k_idx] <= 21'd0;
            end
            // Initialize distance matrix
            for (load_row = 0; load_row < MAX_N; load_row = load_row + 1) begin
                for (load_col = 0; load_col < MAX_N; load_col = load_col + 1) begin
                    dist[load_row][load_col] <= 10'd0;
                end
            end
        end else begin
            // Cycle counter for safety
            if (state != IDLE) begin
                cycle_count <= cycle_count + 21'd1;
            end else begin
                cycle_count <= 21'd0;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 21'd0;
                    if (start) begin
                        N_reg <= N_in;
                        state <= LOAD;
                        load_count <= 4'd0;
                        load_row <= 4'd0;
                        load_col <= 4'd0;
                    end
                end

                LOAD: begin
                    if (write_en) begin
                        if (row < N_reg && col < N_reg) begin
                            dist[row][col] <= data_in;
                        end
                    end
                    // Keep loading until we receive a start signal (load complete)
                    // Actually, we need a separate load completion signal
                    // For now, if start is deasserted, assume load is done
                    if (!start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize dp[2][1] = dist(1,2)
                    // In 0-indexed: dp[2][1] = dist(1,0) (cities 2 and 1)
                    if (N_reg >= 4'd2) begin
                        dp_prev[1] <= dist[1][0]; // dp[2][1] = dist(1,2) where 1,2 are 0-indexed cities 2,1
                        i_idx <= 4'd2; // Start from i=3 (0-indexed)
                        state <= DP_LOOP_I;
                    end else begin
                        // N < 2, handle edge case
                        min_cost <= 21'd0;
                        state <= FINISH;
                    end
                end

                DP_LOOP_I: begin
                    if (i_idx < N_reg) begin
                        // Initialize dp_curr for this i
                        for (m_idx = 0; m_idx < MAX_N; m_idx = m_idx + 1) begin
                            dp_curr[m_idx] <= 21'h7FFFFF; // Initialize with large value
                        end
                        m_idx <= 4'd0; // Start m from 0
                        state <= DP_LOOP_M;
                    end else begin
                        state <= DP_FINAL;
                    end
                end

                DP_LOOP_M: begin
                    if (m_idx < i_idx - 4'd1) begin
                        // dp[i][m] = dp[i-1][m] + dist(i, i-1)
                        // i_idx is current i (0-indexed)
                        // m_idx is current m (0-indexed)
                        // dist(i, i-1) where i and i-1 are 0-indexed cities i+1 and i
                        if (m_idx < MAX_N && i_idx < MAX_N) begin
                            dp_curr[m_idx] <= dp_prev[m_idx] + dist[i_idx][i_idx-1];
                        end
                        m_idx <= m_idx + 4'd1;
                    end else begin
                        // Compute dp[i][i-1] = min over m of (dp[i-1][m] + dist(i, m))
                        // where i-1 is the other endpoint (0-indexed)
                        min_val <= 21'h7FFFFF;
                        m_idx <= 4'd0;
                        // We'll compute this in next state
                        state <= DP_LOOP_M; // Continue loop
                        // Actually, we need a separate state for this
                        state <= 4'd7; // Temporary state for min computation
                    end
                end

                4'd7: begin // DP_MIN state
                    if (m_idx < i_idx - 4'd1) begin
                        temp_val <= dp_prev[m_idx] + dist[i_idx][m_idx];
                        if (m_idx == 4'd0 || temp_val < min_val) begin
                            min_val <= temp_val;
                        end
                        m_idx <= m_idx + 4'd1;
                    end else begin
                        // Store the result
                        if (i_idx < MAX_N) begin
                            dp_curr[i_idx-1] <= min_val;
                        end
                        // Move to next i
                        for (m_idx = 0; m_idx < MAX_N; m_idx = m_idx + 1) begin
                            if (m_idx < MAX_N) begin
                                dp_prev[m_idx] <= dp_curr[m_idx];
                            end
                        end
                        i_idx <= i_idx + 4'd1;
                        state <= DP_LOOP_I;
                    end
                end

                DP_FINAL: begin
                    // Compute min over k of dp[N-1][k]
                    // N_reg is N (1-indexed), so N-1 is index in 0-indexed
                    if (N_reg > 4'd1) begin
                        k_idx <= 4'd1;
                        min_val <= dp_prev[1]; // Start with k=1
                        state <= 4'd8; // Final min state
                    end else begin
                        min_cost <= 21'd0;
                        state <= FINISH;
                    end
                end

                4'd8: begin // Final min computation
                    if (k_idx < N_reg) begin
                        if (dp_prev[k_idx] < min_val) begin
                            min_val <= dp_prev[k_idx];
                        end
                        k_idx <= k_idx + 4'd1;
                    end else begin
                        min_cost <= min_val;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
                done <= 1'b1;
                min_cost <= 21'd0;
            end
        end
    end

endmodule