module skiing_probability (
    input clk,
    input rst_n,
    input start,
    input [3:0] edge_valid,
    input [3:0][3:0] edge_src,
    input [3:0][3:0] edge_dst,
    input [3:0][15:0] edge_prob,
    input [2:0] max_k,
    output reg [15:0] result_p0,
    output reg [15:0] result_p1,
    output reg [15:0] result_p2,
    output reg [15:0] result_p3,
    output reg done,
    output reg impossible
);

    // Parameters
    localparam N = 4;
    localparam MAX_WALKS = 3;
    localparam ONE_Q16 = 16'h0001;
    localparam IMPOSSIBLE = 16'hFFFF;

    // States
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PROCESS_EDGES,
        UPDATE_DP,
        CHECK_DONE,
        OUTPUT,
        DONE
    } state_t;

    // State machine
    state_t state;
    reg [15:0] dp [0:N-1][0:MAX_WALKS];
    reg [15:0] new_dp [0:N-1][0:MAX_WALKS];
    reg [3:0] edge_idx;
    reg [3:0] cabin_idx;
    reg [3:0] walk_idx;
    reg [3:0] iteration;
    reg [3:0] max_iterations;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
            result_p0 <= 0;
            result_p1 <= 0;
            result_p2 <= 0;
            result_p3 <= 0;
            edge_idx <= 0;
            cabin_idx <= 0;
            walk_idx <= 0;
            iteration <= 0;
            max_iterations <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        impossible <= 0;
                    end
                end
                INIT: begin
                    // Initialize dp array
                    for (int c = 0; c < N; c++) begin
                        for (int w = 0; w <= MAX_WALKS; w++) begin
                            dp[c][w] <= 0;
                        end
                    end
                    dp[0][0] <= ONE_Q16;
                    state <= PROCESS_EDGES;
                    edge_idx <= 0;
                    cabin_idx <= 0;
                    walk_idx <= 0;
                    iteration <= 0;
                    max_iterations <= max_k + 1;
                end
                PROCESS_EDGES: begin
                    if (edge_idx < 4) begin
                        if (edge_valid[edge_idx]) begin
                            // Skiing: a->b if a < b
                            if (edge_src[edge_idx] < edge_dst[edge_idx]) begin
                                for (int w = 0; w <= MAX_WALKS; w++) begin
                                    if (dp[edge_src[edge_idx]][w] != 0) begin
                                        reg [31:0] product = dp[edge_src[edge_idx]][w] * edge_prob[edge_idx];
                                        reg [15:0] new_val = product[31:16];
                                        if (new_val > new_dp[edge_dst[edge_idx]][w]) begin
                                            new_dp[edge_dst[edge_idx]][w] = new_val;
                                        end
                                    end
                                end
                            end
                            // Walking: a->b or b->a
                            for (int w = 0; w < MAX_WALKS; w++) begin
                                if (dp[edge_src[edge_idx]][w] != 0) begin
                                    if (dp[edge_src[edge_idx]][w] > new_dp[edge_dst[edge_idx]][w+1]) begin
                                        new_dp[edge_dst[edge_idx]][w+1] = dp[edge_src[edge_idx]][w];
                                    end
                                end
                                if (dp[edge_dst[edge_idx]][w] != 0) begin
                                    if (dp[edge_dst[edge_idx]][w] > new_dp[edge_src[edge_idx]][w+1]) begin
                                        new_dp[edge_src[edge_idx]][w+1] = dp[edge_dst[edge_idx]][w];
                                    end
                                end
                            end
                        end
                        edge_idx <= edge_idx + 1;
                    end else begin
                        state <= UPDATE_DP;
                        edge_idx <= 0;
                    end
                end
                UPDATE_DP: begin
                    // Copy new_dp to dp
                    for (int c = 0; c < N; c++) begin
                        for (int w = 0; w <= MAX_WALKS; w++) begin
                            dp[c][w] <= new_dp[c][w];
                            new_dp[c][w] <= 0;
                        end
                    end
                    state <= CHECK_DONE;
                end
                CHECK_DONE: begin
                    iteration <= iteration + 1;
                    if (iteration >= max_iterations) begin
                        state <= OUTPUT;
                    end else begin
                        state <= PROCESS_EDGES;
                    end
                end
                OUTPUT: begin
                    result_p0 <= (dp[N-1][0] == 0) ? IMPOSSIBLE : dp[N-1][0];
                    result_p1 <= (dp[N-1][1] == 0) ? IMPOSSIBLE : dp[N-1][1];
                    result_p2 <= (dp[N-1][2] == 0) ? IMPOSSIBLE : dp[N-1][2];
                    result_p3 <= (dp[N-1][3] == 0) ? IMPOSSIBLE : dp[N-1][3];
                    impossible <= (result_p0 == IMPOSSIBLE && result_p1 == IMPOSSIBLE && result_p2 == IMPOSSIBLE && result_p3 == IMPOSSIBLE);
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule