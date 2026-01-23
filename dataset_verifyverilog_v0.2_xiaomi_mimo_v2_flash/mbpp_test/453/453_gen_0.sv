module sum_even_factors (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    output reg [7:0] result,
    output reg done
);

    parameter MAX_ITER = 16;

    // States
    localparam IDLE = 0;
    localparam CHECK_ODD = 1;
    localparam FACTOR_LOOP = 2;
    localparam DIVIDE_CHECK = 3;
    localparam COMPUTE_SUM = 4;
    localparam MULTIPLY_RESULT = 5;
    localparam ITERATE_I = 6;
    localparam DONE = 7;

    reg [2:0] state;

    // Internal Registers
    reg [5:0] i;
    reg [5:0] n_rem;
    reg [7:0] acc_sum;
    reg [7:0] geo_sum;
    reg [7:0] pow_i;
    reg [3:0] loop_cnt;
    reg is_rem_factor;

    // Combinational Check for Loop Continuation in COMPUTE_SUM
    // Checks if (n_rem / i) is divisible by i
    wire should_loop_compute;
    assign should_loop_compute = ((n_rem / i) % i == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 6'd2;
            n_rem <= 6'd0;
            acc_sum <= 8'd0;
            geo_sum <= 8'd0;
            pow_i <= 8'd0;
            loop_cnt <= 4'd0;
            is_rem_factor <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_rem <= n;
                        i <= 6'd2;
                        acc_sum <= 8'd1; // Identity for multiplication
                        loop_cnt <= 4'd0;
                        is_rem_factor <= 1'b0;
                        state <= CHECK_ODD;
                    end
                end

                CHECK_ODD: begin
                    if (n[0]) begin
                        acc_sum <= 8'd0;
                        state <= DONE;
                    end else begin
                        state <= FACTOR_LOOP;
                    end
                end

                FACTOR_LOOP: begin
                    // Termination Check: i*i > n_rem or loop_cnt >= MAX_ITER
                    if ((i * i > n_rem) || (loop_cnt >= MAX_ITER)) begin
                        if (n_rem >= 2) begin
                            is_rem_factor <= 1'b1;
                            geo_sum <= n_rem + 1;
                            state <= MULTIPLY_RESULT;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DIVIDE_CHECK;
                    end
                end

                DIVIDE_CHECK: begin
                    if ((n_rem % i) == 0) begin
                        state <= COMPUTE_SUM;
                        // Initialize Sum Calculation
                        if (i == 6'd2) begin
                            geo_sum <= 2;
                            pow_i <= 2;
                        end else begin
                            geo_sum <= 1;
                            pow_i <= 1;
                        end
                    end else begin
                        state <= ITERATE_I;
                    end
                end

                COMPUTE_SUM: begin
                    // Perform one iteration of sum calculation and division
                    n_rem <= n_rem / i;
                    geo_sum <= geo_sum + pow_i;
                    pow_i <= pow_i * i;

                    // Check if we need to loop again for this 'i'
                    // Condition checks if the *next* n_rem (which is n_rem/i) is divisible by i
                    if (should_loop_compute) begin
                        state <= COMPUTE_SUM;
                    end else begin
                        state <= MULTIPLY_RESULT;
                        is_rem_factor <= 1'b0;
                    end
                end

                MULTIPLY_RESULT: begin
                    acc_sum <= acc_sum * geo_sum;
                    if (is_rem_factor) begin
                        state <= DONE;
                    end else begin
                        state <= ITERATE_I;
                    end
                end

                ITERATE_I: begin
                    i <= i + 1;
                    loop_cnt <= loop_cnt + 1;
                    state <= FACTOR_LOOP;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= acc_sum;
                end
            endcase
        end
    end
endmodule