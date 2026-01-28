module transport_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] t_cnt,
    input [3:0] n_cnt,
    input [15:0] dmin_t [0:3],
    input signed [15:0] angle_range_t [0:3],
    input [15:0] dist_edge [0:14],
    input signed [15:0] heading_edge [0:14],
    output reg [7:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP table: 16 points x 4 modes
    reg [7:0] dp [0:15][0:3];
    localparam [7:0] INF = 8'd255;

    // Iteration counters
    reg [3:0] i_reg;
    reg [1:0] j_reg;
    reg [1:0] k_reg;

    // Temporary registers for computation
    reg [15:0] dist_sum;
    reg signed [15:0] min_heading;
    reg signed [15:0] max_heading;
    reg [7:0] min_switches;
    reg [7:0] current_min;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    dp[i][j] <= INF;
                end
            end
            
            i_reg <= 4'd0;
            j_reg <= 2'd0;
            k_reg <= 2'd0;
            dist_sum <= 16'd0;
            min_heading <= 16'd0;
            max_heading <= 16'd0;
            min_switches <= 8'd0;
            current_min <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 8'd0;
                    end
                end

                INIT: begin
                    // Initialize DP table
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            dp[i][j] <= INF;
                        end
                    end
                    
                    // Base case: dp[0][j] = 0 for all valid j
                    for (j = 0; j < 4; j = j + 1) begin
                        if (j < t_cnt) begin
                            dp[0][j] <= 8'd0;
                        end
                    end
                    
                    i_reg <= 4'd0;
                    j_reg <= 2'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Iterate through points
                        if (i_reg < n_cnt - 1) begin
                            // Iterate through transport modes
                            if (j_reg < t_cnt) begin
                                // Check if current state is reachable
                                if (dp[i_reg][j_reg] < INF) begin
                                    // Initialize segment tracking
                                    dist_sum <= dist_edge[i_reg];
                                    min_heading <= heading_edge[i_reg];
                                    max_heading <= heading_edge[i_reg];
                                    
                                    // Check if we can extend the segment
                                    if (dist_sum >= dmin_t[j_reg] && 
                                        (max_heading - min_heading) <= angle_range_t[j_reg]) begin
                                        // No switch needed
                                        if (dp[i_reg + 1][j_reg] > dp[i_reg][j_reg]) begin
                                            dp[i_reg + 1][j_reg] <= dp[i_reg][j_reg];
                                        end
                                    end
                                    
                                    // Try switching to other modes
                                    k_reg <= 2'd0;
                                    if (k_reg < t_cnt) begin
                                        if (k_reg != j_reg) begin
                                            if (dp[i_reg + 1][k_reg] > dp[i_reg][j_reg] + 1) begin
                                                dp[i_reg + 1][k_reg] <= dp[i_reg][j_reg] + 1;
                                            end
                                        end
                                        k_reg <= k_reg + 1'b1;
                                    end
                                end
                                j_reg <= j_reg + 1'b1;
                            end else begin
                                j_reg <= 2'd0;
                                i_reg <= i_reg + 1'b1;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    // Find minimum in dp[n_cnt-1][*]
                    current_min <= INF;
                    integer k;
                    for (k = 0; k < 4; k = k + 1) begin
                        if (k < t_cnt && dp[n_cnt - 1][k] < current_min) begin
                            current_min <= dp[n_cnt - 1][k];
                        end
                    end
                    
                    if (current_min < INF) begin
                        result <= current_min;
                        valid <= 1'b1;
                    end else begin
                        result <= 8'd0;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule