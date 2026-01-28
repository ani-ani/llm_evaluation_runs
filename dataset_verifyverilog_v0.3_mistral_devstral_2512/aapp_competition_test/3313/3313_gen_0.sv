module gem_collector(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] r,
    input [15:0] w,
    input [15:0] h,
    input [15:0] x [0:15],
    input [15:0] y [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SORT     = 3'd1;
    localparam [2:0] DP_INIT  = 3'd2;
    localparam [2:0] DP_LOOP  = 3'd3;
    localparam [2:0] FIND_MAX = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Sorted arrays
    reg [15:0] sorted_x [0:15];
    reg [15:0] sorted_y [0:15];

    // DP array
    reg [7:0] dp [0:15];

    // Counters
    reg [3:0] i, j;

    // Temporary registers
    reg [15:0] x_diff, y_diff;
    reg [19:0] r_x_diff;
    reg [15:0] abs_x_diff;
    reg [15:0] temp_x, temp_y;
    reg swap_flag;

    // Bubble sort variables
    reg [3:0] sort_i, sort_j;
    reg [3:0] sort_n;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_n <= 4'd0;
            swap_flag <= 1'b0;
            x_diff <= 16'd0;
            y_diff <= 16'd0;
            r_x_diff <= 20'd0;
            abs_x_diff <= 16'd0;
            temp_x <= 16'd0;
            temp_y <= 16'd0;
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                sorted_x[sort_i] <= 16'd0;
                sorted_y[sort_i] <= 16'd0;
                dp[sort_i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                    // Initialize sorted arrays
                    for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                        sorted_x[sort_i] = x[sort_i];
                        sorted_y[sort_i] = y[sort_i];
                    end
                    sort_n = n;
                    sort_i = 4'd0;
                    sort_j = 4'd0;
                end
            end

            SORT: begin
                if (sort_i < sort_n - 4'd1) begin
                    if (sort_j < sort_n - sort_i - 4'd1) begin
                        if (sorted_y[sort_j] > sorted_y[sort_j + 4'd1]) begin
                            // Swap
                            temp_x = sorted_x[sort_j];
                            temp_y = sorted_y[sort_j];
                            sorted_x[sort_j] = sorted_x[sort_j + 4'd1];
                            sorted_y[sort_j] = sorted_y[sort_j + 4'd1];
                            sorted_x[sort_j + 4'd1] = temp_x;
                            sorted_y[sort_j + 4'd1] = temp_y;
                            swap_flag = 1'b1;
                        end
                        sort_j = sort_j + 4'd1;
                    end else begin
                        sort_j = 4'd0;
                        if (!swap_flag) begin
                            sort_i = sort_i + 4'd1;
                        end
                        swap_flag = 1'b0;
                    end
                end else begin
                    next_state = DP_INIT;
                    i = 4'd0;
                end
            end

            DP_INIT: begin
                if (i < n) begin
                    dp[i] = 8'd1;
                    i = i + 4'd1;
                end else begin
                    next_state = DP_LOOP;
                    i = 4'd1;
                    j = 4'd0;
                end
            end

            DP_LOOP: begin
                if (i < n) begin
                    if (j < i) begin
                        // Calculate differences
                        if (sorted_x[i] >= sorted_x[j]) begin
                            x_diff = sorted_x[i] - sorted_x[j];
                        end else begin
                            x_diff = sorted_x[j] - sorted_x[i];
                        end
                        y_diff = sorted_y[i] - sorted_y[j];
                        r_x_diff = r * x_diff;
                        
                        if (y_diff >= r_x_diff && dp[j] + 8'd1 > dp[i]) begin
                            dp[i] = dp[j] + 8'd1;
                        end
                        j = j + 4'd1;
                    end else begin
                        j = 4'd0;
                        i = i + 4'd1;
                    end
                end else begin
                    next_state = FIND_MAX;
                    i = 4'd0;
                    result = 8'd0;
                end
            end

            FIND_MAX: begin
                if (i < n) begin
                    if (dp[i] > result) begin
                        result = dp[i];
                    end
                    i = i + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Safety: Force done after max cycles
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            done <= 1'b1;
            state <= IDLE;
        end
    end

endmodule