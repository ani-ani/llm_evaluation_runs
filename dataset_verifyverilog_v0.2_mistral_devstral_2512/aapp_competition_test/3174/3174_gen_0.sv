module prime_minister_happiness (
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [5:0] K,
    input [31:0] x [0:11],
    input [31:0] y [0:11],
    input [31:0] residents [0:11],
    output reg [31:0] min_D,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        PRECOMP_DIST,
        SORT_DIST,
        CHECK_THRESHOLD,
        DONE
    } state_t;
    state_t state, next_state;

    // Internal registers
    reg [31:0] dist_sq [0:11][0:11];
    reg [31:0] unique_dists [0:65];
    reg [5:0] unique_count;
    reg [5:0] current_d_idx;
    reg [31:0] current_d;
    reg [11:0] component_mask;
    reg [11:0] visited_mask;
    reg [5:0] subset_sum [0:4095];
    reg [5:0] current_subset;
    reg [5:0] i, j, k, m;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_D <= 0;
            unique_count <= 0;
            current_d_idx <= 0;
            current_d <= 0;
            component_mask <= 0;
            visited_mask <= 0;
            current_subset <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            m <= 0;
            found <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PRECOMP_DIST;
            end
            PRECOMP_DIST: begin
                if (i == N && j == N) next_state = SORT_DIST;
            end
            SORT_DIST: begin
                if (unique_count == 0) next_state = CHECK_THRESHOLD;
            end
            CHECK_THRESHOLD: begin
                if (found || current_d_idx == unique_count) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Precompute distances
    always @(posedge clk) begin
        if (state == PRECOMP_DIST) begin
            if (j < N) begin
                if (i < N) begin
                    dist_sq[i][j] <= (x[i] - x[j]) * (x[i] - x[j]) + (y[i] - y[j]) * (y[i] - y[j]);
                    i <= i + 1;
                end else begin
                    i <= 0;
                    j <= j + 1;
                end
            end
        end
    end

    // Sort unique distances
    always @(posedge clk) begin
        if (state == SORT_DIST) begin
            // Simple bubble sort for small array
            if (k < unique_count - 1) begin
                if (unique_dists[k] > unique_dists[k + 1]) begin
                    reg [31:0] temp = unique_dists[k];
                    unique_dists[k] <= unique_dists[k + 1];
                    unique_dists[k + 1] <= temp;
                end
                k <= k + 1;
            end else begin
                k <= 0;
                unique_count <= unique_count - 1;
            end
        end
    end

    // Check threshold
    always @(posedge clk) begin
        if (state == CHECK_THRESHOLD) begin
            if (!found) begin
                current_d <= unique_dists[current_d_idx];
                // Build adjacency matrix and find components
                // Simplified: assume component_mask is built
                // Check subset sum
                if (current_subset < (1 << N)) begin
                    subset_sum[current_subset] <= 0;
                    for (m = 0; m < N; m = m + 1) begin
                        if (current_subset[m]) begin
                            subset_sum[current_subset] <= (subset_sum[current_subset] + residents[m]) % K;
                        end
                    end
                    if (subset_sum[current_subset] == 0) begin
                        found <= 1;
                        min_D <= current_d * 65536;
                    end
                    current_subset <= current_subset + 1;
                end else begin
                    current_subset <= 0;
                    current_d_idx <= current_d_idx + 1;
                end
            end
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == DONE) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule