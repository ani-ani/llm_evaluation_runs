module chocolate_box_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_SUM = 4'd1;
    localparam [3:0] FACTORIZE = 4'd2;
    localparam [3:0] COMPUTE_COST = 4'd3;
    localparam [3:0] FINISH = 4'd4;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Sum calculation
    reg [23:0] total_sum;
    reg [3:0] sum_idx;

    // Prime factorization
    reg [23:0] current_num;
    reg [11:0] factor_idx;
    reg [23:0] factors [0:7];
    reg [7:0] num_factors;
    reg [11:0] divisor_idx;
    reg [23:0] current_divisor;

    // Cost computation
    reg [23:0] min_cost;
    reg [23:0] current_cost;
    reg [23:0] running_remainder;
    reg [3:0] box_idx;
    reg [23:0] half_k;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            total_sum <= 24'd0;
            sum_idx <= 4'd0;
            current_num <= 24'd0;
            factor_idx <= 12'd0;
            num_factors <= 8'd0;
            divisor_idx <= 12'd0;
            current_divisor <= 24'd0;
            min_cost <= 24'd0;
            current_cost <= 24'd0;
            running_remainder <= 24'd0;
            box_idx <= 4'd0;
            half_k <= 24'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALC_SUM;
                    end
                end

                CALC_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (sum_idx < len) begin
                        total_sum <= total_sum + arr[sum_idx];
                        sum_idx <= sum_idx + 4'd1;
                    end else begin
                        sum_idx <= 4'd0;
                        if (total_sum == 24'd0 || total_sum == 24'd1) begin
                            result <= 16'd-1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            current_num <= total_sum;
                            state <= FACTORIZE;
                        end
                    end
                end

                FACTORIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (factor_idx < 8 && current_num > 24'd1) begin
                        reg [11:0] i;
                        reg [23:0] temp_num;
                        temp_num = current_num;
                        for (i = 2; i <= 24'd46340; i = i + 12'd1) begin
                            if (temp_num % i == 24'd0) begin
                                factors[factor_idx] <= i;
                                factor_idx <= factor_idx + 12'd1;
                                num_factors <= num_factors + 8'd1;
                                temp_num = temp_num / i;
                                i = 12'd1;
                            end
                        end
                        if (temp_num > 24'd1) begin
                            factors[factor_idx] <= temp_num;
                            factor_idx <= factor_idx + 12'd1;
                            num_factors <= num_factors + 8'd1;
                        end
                        current_num <= 24'd0;
                        factor_idx <= 12'd0;
                        state <= COMPUTE_COST;
                    end else begin
                        if (num_factors == 8'd0) begin
                            result <= 16'd-1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= COMPUTE_COST;
                        end
                    end
                end

                COMPUTE_COST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (divisor_idx < num_factors) begin
                        current_divisor <= factors[divisor_idx];
                        if (divisor_idx == 12'd0) begin
                            min_cost <= 24'd0;
                        end
                        current_cost <= 24'd0;
                        running_remainder <= 24'd0;
                        box_idx <= 4'd0;
                        half_k <= current_divisor / 24'd2;
                        state <= COMPUTE_COST;
                    end else begin
                        if (min_cost == 24'd0) begin
                            result <= 16'd-1;
                        end else begin
                            result <= min_cost[15:0];
                        end
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Cost computation logic
            if (state == COMPUTE_COST && divisor_idx < num_factors) begin
                if (box_idx < len) begin
                    running_remainder <= (running_remainder + arr[box_idx]) % current_divisor;
                    if (running_remainder <= half_k) begin
                        current_cost <= current_cost + running_remainder;
                    end else begin
                        current_cost <= current_cost + (current_divisor - running_remainder);
                    end
                    box_idx <= box_idx + 4'd1;
                end else begin
                    if (min_cost == 24'd0 || current_cost < min_cost) begin
                        min_cost <= current_cost;
                    end
                    divisor_idx <= divisor_idx + 12'd1;
                    state <= COMPUTE_COST;
                end
            end

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                result <= 16'd-1;
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end

endmodule