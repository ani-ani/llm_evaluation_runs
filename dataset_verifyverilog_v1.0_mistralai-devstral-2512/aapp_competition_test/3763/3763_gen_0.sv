module restaurant_table_dp(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [5:0] p_in,
    input wire [4:0] a_in [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_UPDATE = 3'd3;
    localparam [2:0] ACCUMULATE = 3'd4;
    localparam [2:0] FINALIZE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] n_reg;
    reg [5:0] p_reg;
    reg [4:0] a_reg [0:15];
    reg [15:0] result_acc;
    reg [15:0] total_sum;
    reg [15:0] fact_n;

    // DP table: 17x33 (k x s)
    reg [15:0] dp [0:16][0:32];

    // Factorial LUT (0! to 16!)
    reg [19:0] fact_lut [0:16];

    // Counters and indices
    reg [3:0] i_reg;  // Guest index
    reg [3:0] j_reg;  // Guest index
    reg [3:0] k_reg;  // Subset size
    reg [5:0] s_reg;  // Subset sum
    reg [5:0] s_next;

    // Flags
    reg all_fit;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Initialize factorial LUT
    integer idx;
    initial begin
        fact_lut[0] = 20'd1;
        fact_lut[1] = 20'd1;
        fact_lut[2] = 20'd2;
        fact_lut[3] = 20'd6;
        fact_lut[4] = 20'd24;
        fact_lut[5] = 20'd120;
        fact_lut[6] = 20'd720;
        fact_lut[7] = 20'd5040;
        fact_lut[8] = 20'd40320;
        fact_lut[9] = 20'd362880;
        fact_lut[10] = 20'd3628800;
        fact_lut[11] = 20'd39916800;
        fact_lut[12] = 20'd479001600;
        fact_lut[13] = 20'd6227020800;
        fact_lut[14] = 20'd87178291200;
        fact_lut[15] = 20'd1307674368000;
        fact_lut[16] = 20'd20922789888000;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            n_reg <= 4'd0;
            p_reg <= 6'd0;
            result_acc <= 16'd0;
            total_sum <= 16'd0;
            fact_n <= 16'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            s_reg <= 6'd0;
            all_fit <= 1'b0;

            // Initialize DP table
            for (idx = 0; idx < 17; idx = idx + 1) begin
                for (s_reg = 0; s_reg < 33; s_reg = s_reg + 1) begin
                    dp[idx][s_reg] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    n_reg <= n_in;
                    p_reg <= p_in;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        a_reg[idx] <= a_in[idx];
                    end

                    // Check if all guests fit
                    reg [5:0] sum_a;
                    integer i;
                    sum_a = 6'd0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        sum_a = sum_a + a_reg[i];
                    end
                    all_fit = (sum_a <= p_reg);

                    if (all_fit) begin
                        result_acc <= {8'd0, n_reg};
                        next_state <= FINALIZE;
                    end else begin
                        fact_n <= fact_lut[n_reg][15:0];
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table for current guest
                    dp[0][0] <= 16'd256;  // Q8.8: 1.0
                    for (s_reg = 1; s_reg < 33; s_reg = s_reg + 1) begin
                        dp[0][s_reg] <= 16'd0;
                    end
                    for (k_reg = 1; k_reg < 17; k_reg = k_reg + 1) begin
                        for (s_reg = 0; s_reg < 33; s_reg = s_reg + 1) begin
                            dp[k_reg][s_reg] <= 16'd0;
                        end
                    end

                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                    next_state <= DP_UPDATE;
                end

                DP_UPDATE: begin
                    if (j_reg < n_reg && j_reg != i_reg) begin
                        // Update DP table for guest j_reg
                        for (k_reg = n_reg; k_reg > 0; k_reg = k_reg - 1) begin
                            for (s_reg = 32; s_reg >= a_reg[j_reg]; s_reg = s_reg - 1) begin
                                dp[k_reg][s_reg] <= dp[k_reg][s_reg] + dp[k_reg - 1][s_reg - a_reg[j_reg]];
                            end
                        end
                        j_reg <= j_reg + 1;
                    end else begin
                        next_state <= ACCUMULATE;
                    end
                end

                ACCUMULATE: begin
                    reg [15:0] temp_sum;
                    reg [15:0] term;
                    reg [15:0] fact_k;
                    reg [15:0] fact_n1k;
                    reg [15:0] k_scaled;

                    temp_sum = 16'd0;
                    for (k_reg = 0; k_reg < n_reg; k_reg = k_reg + 1) begin
                        fact_k = fact_lut[k_reg][15:0];
                        fact_n1k = fact_lut[n_reg - 1 - k_reg][15:0];
                        k_scaled = {8'd0, k_reg};

                        for (s_reg = 0; s_reg < 33; s_reg = s_reg + 1) begin
                            if (s_reg + a_reg[i_reg] > p_reg) begin
                                term = dp[k_reg][s_reg] * fact_k;
                                term = term * fact_n1k;
                                term = term * k_scaled;
                                temp_sum = temp_sum + term;
                            end
                        end
                    end

                    total_sum = total_sum + temp_sum;

                    // Move to next guest
                    i_reg <= i_reg + 1;
                    if (i_reg < n_reg) begin
                        next_state <= DP_INIT;
                    end else begin
                        next_state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    // Divide by fact_n (shift approximation)
                    reg [15:0] div_result;
                    reg [31:0] temp_div;

                    temp_div = {16'd0, total_sum};
                    div_result = temp_div / fact_n;

                    result_acc <= div_result;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= result_acc;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule