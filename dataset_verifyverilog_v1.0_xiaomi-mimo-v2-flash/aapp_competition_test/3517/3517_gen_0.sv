module FindMinTimeModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] step_time [0:15],
    input wire [15:0] adj_matrix [0:15],
    input wire [4:0] N,
    output reg [15:0] result,
    output reg done
);

    // State Definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_ORIG  = 3'd1;
    localparam [2:0] SETUP_LOOP = 3'd2;
    localparam [2:0] CALC_SKIP  = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [15:0] dp [0:15];          // DP array for longest path
    reg [15:0] min_total;
    reg [4:0] remove_idx;
    reg [4:0] step_idx;
    reg [15:0] path_val;
    reg [15:0] best_local;
    reg [4:0] neighbor_idx;
    reg [15:0] candidate;
    
    // Helper wires for 16-bit addition with saturation
    wire [16:0] sum_temp;
    assign sum_temp = dp[neighbor_idx] + step_time[step_idx];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            min_total <= 16'd0;
            remove_idx <= 5'd0;
            step_idx <= 5'd0;
            best_local <= 16'd0;
            neighbor_idx <= 5'd0;
            // Initialize dp array
            dp[0] <= 16'd0; dp[1] <= 16'd0; dp[2] <= 16'd0; dp[3] <= 16'd0;
            dp[4] <= 16'd0; dp[5] <= 16'd0; dp[6] <= 16'd0; dp[7] <= 16'd0;
            dp[8] <= 16'd0; dp[9] <= 16'd0; dp[10] <= 16'd0; dp[11] <= 16'd0;
            dp[12] <= 16'd0; dp[13] <= 16'd0; dp[14] <= 16'd0; dp[15] <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                SETUP_LOOP: begin
                    remove_idx <= 5'd1; // Step 0 is mandatory, skip it
                    min_total <= 16'hFFFF;
                end
                CALC_SKIP: begin
                    // Topological DP logic
                    if (step_idx < N) begin
                        if (step_idx == remove_idx) begin
                            // If we hit the removed node, set DP to 0 (blocked)
                            dp[step_idx] <= 16'd0;
                        end else begin
                            // Path must exist (adjacency check) and predecessor valid
                            if (adj_matrix[neighbor_idx][step_idx] && dp[neighbor_idx] != 0) begin
                                if (sum_temp[16] == 1'b1) begin
                                    dp[step_idx] <= 16'd65535; // Saturation
                                end else begin
                                    if (sum_temp[15:0] > dp[step_idx]) begin
                                        dp[step_idx] <= sum_temp[15:0];
                                    end
                                end
                            end
                        end
                        // Neighbors loop (inner loop)
                        if (neighbor_idx < step_idx - 1) begin
                            neighbor_idx <= neighbor_idx + 5'd1;
                        end else begin
                            // If no predecessors found and not start/removed, result is 0 (invalid path)
                            if (step_idx != 0 && step_idx != remove_idx && dp[step_idx] == 0) begin
                                dp[step_idx] <= 16'd0;
                            end
                            // Next step
                            if (step_idx == 0 && remove_idx != 0) begin
                                dp[0] <= step_time[0]; // Force time for step 0
                            end
                            step_idx <= step_idx + 5'd1;
                            neighbor_idx <= 5'd0;
                        end
                    end
                end
                UPDATE_MIN: begin
                    // Check if path to N-1 is valid (non-zero)
                    if (dp[N-1] != 0) begin
                        if (dp[N-1] < min_total) begin
                            min_total <= dp[N-1];
                        end
                    end
                    // Increment remove_idx
                    if (remove_idx < N - 1) begin
                        remove_idx <= remove_idx + 5'd1;
                    end
                end
                CALC_ORIG: begin
                    // Run DP once for original graph (remove_idx = 16, meaning none removed)
                    if (step_idx < N) begin
                        if (adj_matrix[neighbor_idx][step_idx] && dp[neighbor_idx] != 0) begin
                            if (sum_temp[16] == 1'b1) begin
                                dp[step_idx] <= 16'd65535;
                            end else begin
                                if (sum_temp[15:0] > dp[step_idx]) begin
                                    dp[step_idx] <= sum_temp[15:0];
                                end
                            end
                        end
                        if (neighbor_idx < step_idx - 1) begin
                            neighbor_idx <= neighbor_idx + 5'd1;
                        end else begin
                            if (step_idx == 0) begin
                                dp[0] <= step_time[0];
                            end
                            step_idx <= step_idx + 5'd1;
                            neighbor_idx <= 5'd0;
                        end
                    end else begin
                        // Original time is the baseline minimum
                        min_total <= dp[N-1];
                    end
                end
                FINISH: begin
                    result <= min_total;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_ORIG;
            end
            CALC_ORIG: begin
                if (step_idx >= N && step_idx != 5'd0) next_state = SETUP_LOOP;
            end
            SETUP_LOOP: begin
                next_state = CALC_SKIP;
            end
            CALC_SKIP: begin
                if (step_idx >= N && step_idx != 5'd0) next_state = UPDATE_MIN;
            end
            UPDATE_MIN: begin
                if (remove_idx >= N - 1) next_state = FINISH;
                else next_state = CALC_SKIP;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule