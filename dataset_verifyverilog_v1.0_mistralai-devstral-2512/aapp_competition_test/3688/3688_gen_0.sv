module shopping_route(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [4:0] m,
    input wire [15:0] din_x,
    input wire [15:0] din_y,
    input wire [3:0] din_type,
    input wire din_valid,
    output reg din_ready,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // Parameters
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] DP = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    localparam MAX_N = 5'd16;
    localparam MAX_M = 5'd16;
    localparam MAX_MASK = 16'd65535;
    localparam MAX_CYCLES = 16'd1000000;

    // State and control
    reg [1:0] state;
    reg [15:0] cycle_count;

    // Candidate storage
    reg signed [15:0] cand_x [0:15];
    reg signed [15:0] cand_y [0:15];
    reg [3:0] cand_type [0:15];
    reg [4:0] cand_count;

    // DP table: dp[mask][i] = min vertical moves
    reg [15:0] dp [0:65535][0:15];
    reg [15:0] next_dp [0:65535][0:15];

    // Load FSM
    reg [4:0] load_idx;

    // DP FSM
    reg [15:0] mask;
    reg [4:0] i;
    reg [4:0] j;
    reg [4:0] k;

    // Temporary variables
    reg signed [16:0] abs_diff_x;
    reg signed [16:0] abs_diff_y;
    reg transition_cost;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            load_idx <= 5'd0;
            cand_count <= 5'd0;
            mask <= 16'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            din_ready <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;

            // Initialize candidate storage
            for (k = 0; k < 16; k = k + 1) begin
                cand_x[k] <= 16'd0;
                cand_y[k] <= 16'd0;
                cand_type[k] <= 4'd0;
            end

            // Initialize DP table
            for (k = 0; k < 65536; k = k + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dp[k][j] <= 16'd65535;
                    next_dp[k][j] <= 16'd65535;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    din_ready <= 1'b0;
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        load_idx <= 5'd0;
                        cand_count <= 5'd0;
                    end
                end

                LOAD: begin
                    din_ready <= 1'b1;
                    if (din_valid && load_idx < n) begin
                        cand_x[load_idx] <= din_x;
                        cand_y[load_idx] <= din_y;
                        cand_type[load_idx] <= din_type;
                        load_idx <= load_idx + 5'd1;
                        cand_count <= cand_count + 5'd1;
                    end else if (load_idx >= n) begin
                        state <= DP;
                        cycle_count <= 16'd0;
                        mask <= 16'd0;
                        i <= 5'd0;
                        j <= 5'd0;

                        // Initialize base case: start from (0,0) to each candidate
                        for (k = 0; k < cand_count; k = k + 1) begin
                            abs_diff_x = (cand_x[k] > 16'd0) ? cand_x[k] : -cand_x[k];
                            abs_diff_y = (cand_y[k] > 16'd0) ? cand_y[k] : -cand_y[k];
                            if (abs_diff_x < abs_diff_y) begin
                                dp[1 << (cand_type[k] - 1)][k] <= 16'd1;
                            end else begin
                                dp[1 << (cand_type[k] - 1)][k] <= 16'd0;
                            end
                        end
                    end
                end

                DP: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Iterate through all masks
                        if (mask == 16'd0) begin
                            mask <= 16'd1;
                        end else if (mask < (1 << m) - 1) begin
                            // For each mask, update next_dp
                            for (k = 0; k < 65536; k = k + 1) begin
                                for (j = 0; j < 16; j = j + 1) begin
                                    next_dp[k][j] <= 16'd65535;
                                end
                            end

                            for (i = 0; i < cand_count; i = i + 1) begin
                                if (dp[mask][i] != 16'd65535) begin
                                    for (j = 0; j < cand_count; j = j + 1) begin
                                        if (i != j && !(mask & (1 << (cand_type[j] - 1)))) begin
                                            abs_diff_x = (cand_x[j] > cand_x[i]) ? cand_x[j] - cand_x[i] : cand_x[i] - cand_x[j];
                                            abs_diff_y = (cand_y[j] > cand_y[i]) ? cand_y[j] - cand_y[i] : cand_y[i] - cand_y[j];
                                            transition_cost = (abs_diff_x < abs_diff_y) ? 1'b1 : 1'b0;
                                            if (dp[mask][i] + transition_cost < next_dp[mask | (1 << (cand_type[j] - 1))][j]) begin
                                                next_dp[mask | (1 << (cand_type[j] - 1))][j] <= dp[mask][i] + transition_cost;
                                            end
                                        end
                                    end
                                end
                            end

                            // Copy next_dp to dp
                            for (k = 0; k < 65536; k = k + 1) begin
                                for (j = 0; j < 16; j = j + 1) begin
                                    dp[k][j] <= next_dp[k][j];
                                end
                            end

                            mask <= mask + 16'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    // Compute final result: min over all masks with all items
                    reg [15:0] min_result;
                    reg [15:0] return_cost;
                    min_result <= 16'd65535;

                    for (k = 0; k < cand_count; k = k + 1) begin
                        if (dp[(1 << m) - 1][k] != 16'd65535) begin
                            abs_diff_x = (cand_x[k] > 16'd0) ? cand_x[k] : -cand_x[k];
                            abs_diff_y = (cand_y[k] > 16'd0) ? cand_y[k] : -cand_y[k];
                            return_cost = (abs_diff_x < abs_diff_y) ? 16'd1 : 16'd0;
                            if (dp[(1 << m) - 1][k] + return_cost < min_result) begin
                                min_result <= dp[(1 << m) - 1][k] + return_cost;
                            end
                        end
                    end

                    result <= min_result;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule