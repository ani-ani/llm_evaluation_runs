module hill_houses (
    input clk,
    input rst_n,
    input start,
    input [6:0] hill_height,
    input valid,
    output reg [5:0] current_k,
    output reg [31:0] min_cost,
    output reg result_valid,
    output reg done
);

    parameter N_MAX = 10;
    parameter K_MAX = 5;
    parameter INF = 32'h7FFFFFFF;

    // States
    localparam IDLE = 3'b000;
    localparam RECV_HILLS = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] state;
    reg [3:0] idx; // 0 to 9
    reg [3:0] num_hills;
    reg [6:0] heights [0:N_MAX-1];
    
    // DP Arrays [0..K_MAX]
    reg [31:0] dp0 [0:K_MAX];
    reg [31:0] dp1 [0:K_MAX];
    reg [31:0] dp2 [0:K_MAX];
    
    reg [2:0] k_cnt; // For output loop

    integer k;
    logic [31:0] next_d0 [0:K_MAX];
    logic [31:0] next_d1 [0:K_MAX];
    logic [31:0] next_d2 [0:K_MAX];
    logic [31:0] c_p_reg;
    logic [6:0] h_prev, h_curr, h_next;
    logic [6:0] target_h;
    logic [6:0] cost_prev, cost_next;
    logic [15:0] cost_placed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result_valid <= 0;
            current_k <= 0;
            min_cost <= 0;
            idx <= 0;
            num_hills <= 0;
            k_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result_valid <= 0;
                    if (start) begin
                        state <= RECV_HILLS;
                        idx <= 0;
                        num_hills <= 0;
                    end
                end

                RECV_HILLS: begin
                    if (valid) begin
                        heights[idx] <= hill_height;
                        idx <= idx + 1;
                        if (idx == N_MAX - 1) begin
                            num_hills <= N_MAX;
                            // Initialize DP tables
                            dp0[0] <= 0;
                            dp1[0] <= INF;
                            dp2[0] <= INF;
                            for (int k_init = 1; k_init <= K_MAX; k_init++) begin
                                dp0[k_init] <= INF;
                                dp1[k_init] <= INF;
                                dp2[k_init] <= INF;
                            end
                            idx <= 0;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    // Calculate Hill Adjacency
                    h_prev = (idx > 0) ? heights[idx-1] : 7'd0;
                    h_curr = heights[idx];
                    h_next = (idx < num_hills - 1) ? heights[idx+1] : 7'd0;
                    
                    target_h = h_curr - 1;
                    cost_prev = (h_prev > target_h) ? (h_prev - target_h) : 7'd0;
                    cost_next = (h_next > target_h) ? (h_next - target_h) : 7'd0;
                    cost_placed = cost_prev + cost_next;
                    c_p_reg = {16'd0, cost_placed, 16'd0};

                    // DP Update Logic
                    // k=0 base
                    next_d0[0] = 0;
                    next_d1[0] = INF;
                    next_d2[0] = INF;

                    for (int k_dp = 1; k_dp <= K_MAX; k_dp++) begin
                        // d1: min(dp0[k-1], dp2[k-1]) + c_p
                        reg [31:0] min_src = (dp0[k_dp-1] < dp2[k_dp-1]) ? dp0[k_dp-1] : dp2[k_dp-1];
                        if (min_src == INF) next_d1[k_dp] = INF;
                        else next_d1[k_dp] = min_src + c_p_reg;

                        // d0: min(dp0[k_dp], dp2[k_dp])
                        next_d0[k_dp] = (dp0[k_dp] < dp2[k_dp]) ? dp0[k_dp] : dp2[k_dp];

                        // d2: dp1[k_dp]
                        next_d2[k_dp] = dp1[k_dp];
                    end

                    // Update Registers
                    for (int k_up = 0; k_up <= K_MAX; k_up++) begin
                        dp0[k_up] <= next_d0[k_up];
                        dp1[k_up] <= next_d1[k_up];
                        dp2[k_up] <= next_d2[k_up];
                    end

                    idx <= idx + 1;
                    if (idx == num_hills - 1) begin
                        state <= OUTPUT;
                        k_cnt <= 1;
                    end
                end

                OUTPUT: begin
                    if (k_cnt <= K_MAX) begin
                        // Calculate min cost for current k
                        reg [31:0] v0, v1, v2, min_v;
                        v0 = dp0[k_cnt];
                        v1 = dp1[k_cnt];
                        v2 = dp2[k_cnt];
                        min_v = v0;
                        if (v1 < min_v) min_v = v1;
                        if (v2 < min_v) min_v = v2;
                        
                        min_cost <= min_v;
                        result_valid <= 1;
                        k_cnt <= k_cnt + 1;
                    end else begin
                        result_valid <= 0;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Current K output assignment
    always @(*) begin
        current_k = {1'b0, k_cnt};
    end

endmodule