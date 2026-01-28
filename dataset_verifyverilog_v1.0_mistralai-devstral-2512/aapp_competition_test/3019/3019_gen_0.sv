module max_revenue_data_sales(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [9:0] S [0:13],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_S = 3'd1;
    localparam [2:0] PRECOMPUTE_SUM = 3'd2;
    localparam [2:0] DP_ITERATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [13:0] mask, submask;
    reg [13:0] current_sum;
    reg [7:0] dp [0:16383];
    reg [7:0] temp_max;
    reg [13:0] i, j;
    reg [7:0] revenue;
    reg [13:0] max_mask;
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd20000;

    // Prime factor lookup function (simplified for small numbers)
    function [7:0] count_prime_factors;
        input [13:0] num;
        reg [7:0] count;
        reg [13:0] n;
        begin
            count = 8'd0;
            n = num;
            if (n == 0) begin
                count = 8'd0;
            end else begin
                // Check divisibility by small primes
                if (n % 2 == 0) count = count + 8'd1;
                if (n % 3 == 0) count = count + 8'd1;
                if (n % 5 == 0) count = count + 8'd1;
                if (n % 7 == 0) count = count + 8'd1;
                if (n % 11 == 0) count = count + 8'd1;
                if (n % 13 == 0) count = count + 8'd1;
                if (n % 17 == 0) count = count + 8'd1;
                if (n % 19 == 0) count = count + 8'd1;
                if (n % 23 == 0) count = count + 8'd1;
                if (n % 29 == 0) count = count + 8'd1;
                if (n % 31 == 0) count = count + 8'd1;
                if (n % 37 == 0) count = count + 8'd1;
            end
            count_prime_factors = count;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            mask <= 14'd0;
            submask <= 14'd0;
            current_sum <= 14'd0;
            result <= 8'd0;
            done <= 1'b0;
            i <= 14'd0;
            j <= 14'd0;
            temp_max <= 8'd0;
            revenue <= 8'd0;
            max_mask <= 14'd0;
            cycle_count <= 14'd0;
            // Initialize dp array
            for (i = 0; i < 16384; i = i + 1) begin
                dp[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    if (start) begin
                        next_state <= LOAD_S;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_S: begin
                    max_mask <= (1 << N) - 1;
                    next_state <= PRECOMPUTE_SUM;
                end

                PRECOMPUTE_SUM: begin
                    if (i < max_mask) begin
                        current_sum <= 14'd0;
                        for (j = 0; j < 14; j = j + 1) begin
                            if (i[j]) begin
                                current_sum <= current_sum + S[j];
                            end
                        end
                        dp[i] <= count_prime_factors(current_sum);
                        i <= i + 1;
                    end else begin
                        i <= 14'd0;
                        next_state <= DP_ITERATE;
                    end
                end

                DP_ITERATE: begin
                    if (mask < max_mask) begin
                        temp_max <= dp[mask];
                        submask <= mask - 1;
                        while (submask != 0) begin
                            if (dp[submask] + dp[mask ^ submask] > temp_max) begin
                                temp_max <= dp[submask] + dp[mask ^ submask];
                            end
                            submask <= (submask - 1) & mask;
                        end
                        dp[mask] <= temp_max;
                        mask <= mask + 1;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= dp[max_mask];
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            cycle_count <= cycle_count + 1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule