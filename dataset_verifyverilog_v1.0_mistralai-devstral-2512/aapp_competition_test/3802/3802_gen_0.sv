module LCSWithoutVirus(
    input clk,
    input rst_n,
    input start,
    input [7:0] s1 [0:15],
    input [7:0] s2 [0:15],
    input [7:0] virus [0:7],
    input [3:0] len1,
    input [3:0] len2,
    input [3:0] len3,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_KMP = 3'd1;
    localparam [2:0] COMPUTE_DP = 3'd2;
    localparam [2:0] RECONSTRUCT = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // KMP next table (max 9 states: 0 to len3)
    reg [3:0] kmp_next [0:8];
    reg [3:0] kmp_state;

    // DP arrays
    reg [3:0] F [0:16][0:16][0:8];
    reg [15:0] parent [0:16][0:16][0:8];

    // Tracking max state
    reg [3:0] max_i, max_j, max_k;
    reg [3:0] max_len;

    // Reconstruction
    reg [3:0] i_recon, j_recon, k_recon;
    reg [3:0] result_idx;
    reg [3:0] temp_len;

    // Counters
    reg [3:0] i, j, k;
    reg [3:0] lps_i, lps_j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 16'd0;
            done <= 1'b0;
            result_len <= 4'd0;

            // Initialize KMP table
            for (k = 0; k < 9; k = k + 1) begin
                kmp_next[k] <= 4'd0;
            end

            // Initialize DP arrays
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 17; j = j + 1) begin
                    for (k = 0; k < 9; k = k + 1) begin
                        F[i][j][k] <= 4'd0;
                        parent[i][j][k] <= 16'd0;
                    end
                end
            end

            // Initialize reconstruction registers
            i_recon <= 4'd0;
            j_recon <= 4'd0;
            k_recon <= 4'd0;
            result_idx <= 4'd0;
            temp_len <= 4'd0;

            // Initialize counters
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            lps_i <= 4'd0;
            lps_j <= 4'd0;

            // Initialize max tracking
            max_i <= 4'd0;
            max_j <= 4'd0;
            max_k <= 4'd0;
            max_len <= 4'd0;

            // Initialize result buffer
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end

        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= COMPUTE_KMP;
                    end
                end

                COMPUTE_KMP: begin
                    // Compute KMP next table
                    if (lps_i == 0) begin
                        kmp_next[0] <= 4'd0;
                        lps_i <= 4'd1;
                        lps_j <= 4'd0;
                    end else if (lps_i <= len3) begin
                        if (lps_j > 0 && virus[lps_i-1] == virus[lps_j-1]) begin
                            kmp_next[lps_i] <= lps_j + 4'd1;
                            lps_i <= lps_i + 4'd1;
                            lps_j <= lps_j + 4'd1;
                        end else if (lps_j > 0 && virus[lps_i-1] != virus[lps_j-1]) begin
                            lps_j <= kmp_next[lps_j-1];
                        end else begin
                            kmp_next[lps_i] <= 4'd0;
                            lps_i <= lps_i + 4'd1;
                            lps_j <= lps_j + 4'd1;
                        end
                    end else begin
                        lps_i <= 4'd0;
                        lps_j <= 4'd0;
                        next_state <= COMPUTE_DP;
                    end
                end

                COMPUTE_DP: begin
                    // Initialize base case
                    if (i == 0 && j == 0 && k == 0) begin
                        F[0][0][0] <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                    end

                    // Iterate through DP states
                    if (i <= len1 && j <= len2 && k <= len3) begin
                        // Option 1: Skip s1[i]
                        if (i < len1) begin
                            if (F[i+1][j][k] < F[i][j][k]) begin
                                F[i+1][j][k] <= F[i][j][k];
                                parent[i+1][j][k] <= {i, j, k, 2'd0};
                            end
                        end

                        // Option 2: Skip s2[j]
                        if (j < len2) begin
                            if (F[i][j+1][k] < F[i][j][k]) begin
                                F[i][j+1][k] <= F[i][j][k];
                                parent[i][j+1][k] <= {i, j, k, 2'd1};
                            end
                        end

                        // Option 3: Match s1[i] == s2[j]
                        if (i < len1 && j < len2 && s1[i] == s2[j]) begin
                            // Compute next KMP state
                            kmp_state <= k;
                            while (kmp_state > 0 && s1[i] != virus[kmp_state-1]) begin
                                kmp_state <= kmp_next[kmp_state-1];
                            end
                            if (s1[i] == virus[kmp_state-1]) begin
                                kmp_state <= kmp_state + 4'd1;
                            end

                            // Only update if virus not detected
                            if (kmp_state < len3) begin
                                if (F[i+1][j+1][kmp_state] < F[i][j][k] + 4'd1) begin
                                    F[i+1][j+1][kmp_state] <= F[i][j][k] + 4'd1;
                                    parent[i+1][j+1][kmp_state] <= {i, j, k, 2'd2};
                                end
                            end
                        end

                        // Update max state
                        if (F[i][j][k] > max_len) begin
                            max_len <= F[i][j][k];
                            max_i <= i;
                            max_j <= j;
                            max_k <= k;
                        end

                        // Increment counters
                        if (i < len1) begin
                            i <= i + 4'd1;
                        end else if (j < len2) begin
                            i <= 4'd0;
                            j <= j + 4'd1;
                        end else if (k < len3) begin
                            i <= 4'd0;
                            j <= 4'd0;
                            k <= k + 4'd1;
                        end else begin
                            i <= 4'd0;
                            j <= 4'd0;
                            k <= 4'd0;
                            next_state <= RECONSTRUCT;
                        end
                    end
                end

                RECONSTRUCT: begin
                    // Initialize reconstruction
                    if (result_idx == 0) begin
                        i_recon <= max_i;
                        j_recon <= max_j;
                        k_recon <= max_k;
                        temp_len <= max_len;
                        result_idx <= 4'd0;
                    end

                    // Reconstruct path
                    if (temp_len > 0 && result_idx < 16) begin
                        case (parent[i_recon][j_recon][k_recon][1:0])
                            2'd0: begin // Came from skip s1
                                i_recon <= parent[i_recon][j_recon][k_recon][15:12];
                                j_recon <= parent[i_recon][j_recon][k_recon][11:8];
                                k_recon <= parent[i_recon][j_recon][k_recon][7:4];
                            end
                            2'd1: begin // Came from skip s2
                                i_recon <= parent[i_recon][j_recon][k_recon][15:12];
                                j_recon <= parent[i_recon][j_recon][k_recon][11:8];
                                k_recon <= parent[i_recon][j_recon][k_recon][7:4];
                            end
                            2'd2: begin // Came from match
                                result[result_idx] <= s1[i_recon-1];
                                result_idx <= result_idx + 4'd1;
                                i_recon <= parent[i_recon][j_recon][k_recon][15:12];
                                j_recon <= parent[i_recon][j_recon][k_recon][11:8];
                                k_recon <= parent[i_recon][j_recon][k_recon][7:4];
                                temp_len <= temp_len - 4'd1;
                            end
                        endcase
                    end else begin
                        result_len <= max_len;
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule