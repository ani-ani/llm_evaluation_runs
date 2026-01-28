module expected_area (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,   // number of vertices (1..8)
    input [3:0] k,   // number of vertices to choose (3..8)
    input real x [0:7],
    input real y [0:7],
    output real result,
    output done
);

    // Parameters
    parameter MAX_N = 8;
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_S = 4'd1;
    localparam [3:0] COMPUTE_P = 4'd2;
    localparam [3:0] NEXT_D = 4'd3;
    localparam [3:0] DONE = 4'd4;

    // Combination ROM: comb[a][b] = C(a,b)
    real comb [0:MAX_N][0:MAX_N];

    integer i, j, a;
    initial begin
        // Initialize combination table
        for (i = 0; i <= MAX_N; i = i + 1) begin
            for (j = 0; j <= MAX_N; j = j + 1) begin
                if (j > i) begin
                    comb[i][j] = 0.0;
                end else if (j == 0) begin
                    comb[i][j] = 1.0;
                end else begin
                    real val = 1.0;
                    for (a = 0; a < j; a = a + 1) begin
                        val = val * (i - a) / (a + 1);
                    end
                    comb[i][j] = val;
                end
            end
        end
    end

    // Registers
    reg [3:0] state;
    reg [3:0] d;          // current distance
    reg [3:0] i_idx;      // current index i for loop
    reg [3:0] max_d_reg;  // max d for which p_d > 0
    reg [3:0] a_reg;      // a = n - d - 1
    real total_area;
    real S_d;
    real p_d;
    real C_n_k;
    real result_reg;
    reg done_reg;

    // Wires
    wire [3:0] j_idx;     // j = (i + d) % n
    assign j_idx = (i_idx + d < n) ? (i_idx + d) : (i_idx + d - n);

    wire real term;
    assign term = x[i_idx] * y[j_idx] - x[j_idx] * y[i_idx];

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done_reg <= 0;
            total_area <= 0.0;
            S_d <= 0.0;
            p_d <= 0.0;
            result_reg <= 0.0;
            d <= 4'd0;
            i_idx <= 4'd0;
            max_d_reg <= 4'd0;
            a_reg <= 4'd0;
            C_n_k <= 0.0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 0;
                    if (start) begin
                        // Initialize computation
                        total_area <= 0.0;
                        // Compute max_d = n - k + 1 (ensure non-negative)
                        max_d_reg <= (n > k-1) ? (n - k + 1) : 0;
                        // Store C(n,k)
                        C_n_k <= comb[n][k];
                        // Set d to 1
                        d <= 1;
                        // Reset i and S_d
                        i_idx <= 0;
                        S_d <= 0.0;
                        state <= COMPUTE_S;
                    end
                end

                COMPUTE_S: begin
                    // Accumulate term into S_d
                    S_d <= S_d + term;
                    // Increment i
                    i_idx <= i_idx + 1;
                    // Check if we have processed all vertices
                    if (i_idx + 1 < n) begin
                        // Continue looping
                        state <= COMPUTE_S;
                    end else begin
                        // Finished all i for this d
                        state <= COMPUTE_P;
                    end
                end

                COMPUTE_P: begin
                    // Compute p_d
                    if (d > max_d_reg) begin
                        p_d <= 0.0;
                    end else begin
                        a_reg <= n - d - 1;
                        // p_d = C(a_reg, k-2) / C_n_k
                        p_d <= comb[a_reg][k-2] / C_n_k;
                    end
                    // Update total_area
                    total_area <= total_area + S_d * p_d;
                    // Move to next d
                    state <= NEXT_D;
                end

                NEXT_D: begin
                    d <= d + 1;
                    // Reset i and S_d for next distance
                    i_idx <= 0;
                    S_d <= 0.0;
                    // Check if we have processed all distances
                    if (d < n - 1) begin
                        state <= COMPUTE_S;
                    end else begin
                        // Compute final result
                        result_reg <= -0.5 * total_area;
                        state <= DONE;
                        done_reg <= 1;
                    end
                end

                DONE: begin
                    // Wait for next start
                    if (start) begin
                        // Re-initialize as in IDLE
                        done_reg <= 0;
                        total_area <= 0.0;
                        max_d_reg <= (n > k-1) ? (n - k + 1) : 0;
                        C_n_k <= comb[n][k];
                        d <= 1;
                        i_idx <= 0;
                        S_d <= 0.0;
                        state <= COMPUTE_S;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output assignments
    assign result = result_reg;
    assign done = done_reg;

endmodule