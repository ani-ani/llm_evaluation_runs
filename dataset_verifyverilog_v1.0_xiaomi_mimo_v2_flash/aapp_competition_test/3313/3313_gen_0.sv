module gem_collector (
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
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORT      = 3'd1;
    localparam [2:0] DP_INIT   = 3'd2;
    localparam [2:0] DP_LOOP   = 3'd3;
    localparam [2:0] FIND_MAX  = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;  // Outer loop counter
    reg [3:0] j;  // Inner loop counter
    reg [3:0] k;  // DP loop counter
    reg [3:0] m;  // Max search counter
    reg [15:0] sorted_x [0:15];
    reg [15:0] sorted_y [0:15];
    reg [7:0] dp [0:15];
    reg [7:0] temp_max;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Temporary computation registers
    reg [15:0] x_diff;
    reg [15:0] y_diff;
    reg [20:0] r_mult;  // r * |x_diff|, r <= 10, |x_diff| <= 65535
    reg [15:0] temp_x;
    reg [15:0] temp_y;
    reg [7:0] temp_val;
    reg [7:0] temp_val2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            m <= 4'd0;
            cycle_count <= 8'd0;
            temp_max <= 8'd0;
            x_diff <= 16'd0;
            y_diff <= 16'd0;
            r_mult <= 21'd0;
            temp_x <= 16'd0;
            temp_y <= 16'd0;
            temp_val <= 8'd0;
            temp_val2 <= 8'd0;
            // Initialize arrays
            for (int a = 0; a < 16; a = a + 1) begin
                sorted_x[a] <= 16'd0;
                sorted_y[a] <= 16'd0;
                dp[a] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    m <= 4'd0;
                    temp_max <= 8'd0;
                    if (start) begin
                        // Initialize sorted arrays with input data
                        for (int a = 0; a < 16; a = a + 1) begin
                            if (a < n) begin
                                sorted_x[a] <= x[a];
                                sorted_y[a] <= y[a];
                            end else begin
                                sorted_x[a] <= 16'd0;
                                sorted_y[a] <= 16'd0;
                            end
                        end
                        state <= SORT;
                    end else begin
                        state <= IDLE;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (i < n - 4'd1) begin
                        if (j < n - 4'd1 - i) begin
                            // Bubble sort: compare y[j] and y[j+1]
                            if (sorted_y[j] > sorted_y[j + 4'd1]) begin
                                // Swap y
                                temp_y <= sorted_y[j];
                                sorted_y[j] <= sorted_y[j + 4'd1];
                                sorted_y[j + 4'd1] <= temp_y;
                                // Swap x
                                temp_x <= sorted_x[j];
                                sorted_x[j] <= sorted_x[j + 4'd1];
                                sorted_x[j + 4'd1] <= temp_x;
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (i < n) begin
                        dp[i] <= 8'd1;  // Each gem can be collected individually
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd1;  // Start from second gem
                        j <= 4'd0;
                        state <= DP_LOOP;
                    end
                end

                DP_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (i < n) begin
                        if (j < i) begin
                            // Check reachability: r * |x[i] - x[j]| <= y[i] - y[j]
                            // Compute |x[i] - x[j]|
                            if (sorted_x[i] >= sorted_x[j]) begin
                                x_diff <= sorted_x[i] - sorted_x[j];
                            end else begin
                                x_diff <= sorted_x[j] - sorted_x[i];
                            end
                            // Compute r * |x_diff| (need 1 cycle for multiplication)
                            // Next cycle we compute and compare
                            temp_val <= dp[j];  // Store dp[j] for comparison
                            k <= 4'd0;  // Use k as state for computation pipeline
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        temp_max <= 8'd0;
                        state <= FIND_MAX;
                    end
                    // Computation pipeline (when j < i)
                    if (k == 4'd1) begin
                        // Calculate y difference
                        y_diff <= sorted_y[i] - sorted_y[j];
                        // Calculate r * |x_diff|
                        r_mult <= r * x_diff;  // Multiplier
                        k <= 4'd2;
                    end else if (k == 4'd2) begin
                        // Compare: y_diff >= r_mult
                        if (y_diff >= r_mult[15:0]) begin
                            // Reachable, update dp[i]
                            if (dp[i] < (temp_val + 8'd1)) begin
                                dp[i] <= temp_val + 8'd1;
                            end
                        end
                        j <= j + 4'd1;
                        k <= 4'd0;
                    end
                    // Trigger computation pipeline when j < i
                    if (j < i && k == 4'd0) begin
                        k <= 4'd1;
                    end
                end

                FIND_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (m < n) begin
                        if (dp[m] > temp_max) begin
                            temp_max <= dp[m];
                        end
                        m <= m + 4'd1;
                    end else begin
                        result <= temp_max;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule