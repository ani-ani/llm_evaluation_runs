module knapsack_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] w_total,
    input wire [2:0] d_count,
    input wire [7:0] dish_type,
    input wire [15:0] dish_weight [0:7],
    input wire [15:0] dish_t [0:7],
    input wire [15:0] dish_dt [0:7],
    output reg [31:0] result,
    output reg impossible,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_DP = 3'd1;
    localparam [2:0] PROCESS_DISHES = 3'd2;
    localparam [2:0] CONTINUOUS_PASS = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // DP table (1024 entries, 16-bit signed)
    reg signed [15:0] dp [0:1023];

    // Control signals
    reg [2:0] state, next_state;
    reg [9:0] w_cur, w_next;
    reg [2:0] dish_idx, dish_next;
    reg [9:0] count_cur, count_next;
    reg [15:0] temp_val;
    reg [31:0] max_result;
    reg [9:0] best_w;
    reg [2:0] continuous_idx;

    // Constants
    localparam [15:0] NEG_INF = 16'h8000;
    localparam [9:0] MAX_WEIGHT = 10'd1023;

    // Initialize DP table
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            w_cur <= 10'd0;
            dish_idx <= 3'd0;
            count_cur <= 10'd0;
            continuous_idx <= 3'd0;
            result <= 32'd0;
            impossible <= 1'b0;
            done <= 1'b0;
            max_result <= 32'd0;
            best_w <= 10'd0;

            // Initialize DP array
            for (i = 0; i < 1024; i = i + 1) begin
                dp[i] <= NEG_INF;
            end
            dp[0] <= 16'd0;
        end else begin
            state <= next_state;
            w_cur <= w_next;
            dish_idx <= dish_next;
            count_cur <= count_next;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        w_next = w_cur;
        dish_next = dish_idx;
        count_next = count_cur;
        impossible = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_DP;
                end
            end

            INIT_DP: begin
                next_state = PROCESS_DISHES;
                dish_next = 3'd0;
                w_next = 10'd0;
            end

            PROCESS_DISHES: begin
                if (dish_idx < d_count) begin
                    if (dish_type[dish_idx] == 1'b0) begin
                        // Discrete item processing
                        if (count_cur < (w_total / dish_weight[dish_idx]) && count_cur < 10'd100) begin
                            if (w_cur <= w_total - dish_weight[dish_idx]) begin
                                // Update DP table
                                temp_val = dp[w_cur] + dish_t[dish_idx];
                                if (temp_val > dp[w_cur + dish_weight[dish_idx]]) begin
                                    dp[w_cur + dish_weight[dish_idx]] <= temp_val;
                                end
                                w_next = w_cur + 1'b1;
                                if (w_cur == w_total) begin
                                    w_next = 10'd0;
                                    count_next = count_cur + 1'b1;
                                end
                            else begin
                                w_next = 10'd0;
                                count_next = count_cur + 1'b1;
                            end
                        end else begin
                            w_next = 10'd0;
                            count_next = 10'd0;
                            dish_next = dish_idx + 1'b1;
                        end
                    end else begin
                        // Continuous item - skip in this phase
                        dish_next = dish_idx + 1'b1;
                    end
                end else begin
                    next_state = CONTINUOUS_PASS;
                    continuous_idx = 3'd0;
                    w_cur = 10'd0;
                end
            end

            CONTINUOUS_PASS: begin
                if (continuous_idx < d_count && dish_type[continuous_idx] == 1'b1) begin
                    if (w_cur <= w_total) begin
                        if (dp[w_cur] != NEG_INF) begin
                            // Calculate continuous value
                            temp_val = dish_t[continuous_idx] * (w_total - w_cur) -
                                      (dish_dt[continuous_idx] * (w_total - w_cur) * (w_total - w_cur)) / 2;
                            if (dp[w_cur] + temp_val > max_result) begin
                                max_result = dp[w_cur] + temp_val;
                                best_w = w_cur;
                            end
                        end
                        w_next = w_cur + 1'b1;
                        if (w_cur == w_total) begin
                            w_next = 10'd0;
                            continuous_idx = continuous_idx + 1'b1;
                        end
                    end else begin
                        w_next = 10'd0;
                        continuous_idx = continuous_idx + 1'b1;
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                if (dp[w_total] != NEG_INF) begin
                    result <= dp[w_total];
                    impossible <= 1'b0;
                end else if (max_result != 32'd0) begin
                    result <= max_result;
                    impossible <= 1'b0;
                end else begin
                    result <= 32'd0;
                    impossible <= 1'b1;
                end
                done <= 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule