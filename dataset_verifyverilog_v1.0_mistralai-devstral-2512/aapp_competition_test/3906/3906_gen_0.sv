module picture_counter(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'h3B9ACA07;
    localparam [15:0] MAX_CYCLES = 16'd65535;

    // States
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_FIB_N = 3'd1;
    localparam [2:0] CALC_FIB_M = 3'd2;
    localparam [2:0] COMBINE    = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;

    // State machine
    reg [2:0] state, next_state;

    // Fibonacci calculation registers
    reg [31:0] fib_prev_n, fib_curr_n;
    reg [31:0] fib_prev_m, fib_curr_m;
    reg [15:0] counter_n, counter_m;

    // Intermediate results
    reg [31:0] fib_n_result, fib_m_result;
    reg [31:0] temp_result;

    // Modulo subtraction helper
    function [31:0] mod_sub;
        input [31:0] a, b;
        begin
            if (a >= b) begin
                mod_sub = a - b;
            end else begin
                mod_sub = a + MOD - b;
            end
        end
    endfunction

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_FIB_N;
                end else begin
                    next_state = IDLE;
                end
            end

            CALC_FIB_N: begin
                if (counter_n == n) begin
                    next_state = CALC_FIB_M;
                end else begin
                    next_state = CALC_FIB_N;
                end
            end

            CALC_FIB_M: begin
                if (counter_m == m) begin
                    next_state = COMBINE;
                end else begin
                    next_state = CALC_FIB_M;
                end
            end

            COMBINE: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            fib_prev_n <= 32'd1;
            fib_curr_n <= 32'd2;
            fib_prev_m <= 32'd1;
            fib_curr_m <= 32'd2;
            counter_n <= 16'd0;
            counter_m <= 16'd0;
            fib_n_result <= 32'd0;
            fib_m_result <= 32'd0;
            temp_result <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                CALC_FIB_N: begin
                    if (counter_n == 16'd0) begin
                        fib_prev_n <= 32'd1;  // F(0) = 1
                        fib_curr_n <= 32'd2;  // F(1) = 2
                        counter_n <= counter_n + 16'd1;
                    end else if (counter_n < n) begin
                        // Compute next Fibonacci number
                        fib_curr_n <= mod_sub(fib_prev_n + fib_curr_n, MOD);
                        fib_prev_n <= fib_curr_n - fib_prev_n;
                        counter_n <= counter_n + 16'd1;
                    end
                end

                CALC_FIB_M: begin
                    if (counter_m == 16'd0) begin
                        fib_prev_m <= 32'd1;  // F(0) = 1
                        fib_curr_m <= 32'd2;  // F(1) = 2
                        counter_m <= counter_m + 16'd1;
                    end else if (counter_m < m) begin
                        // Compute next Fibonacci number
                        fib_curr_m <= mod_sub(fib_prev_m + fib_curr_m, MOD);
                        fib_prev_m <= fib_curr_m - fib_prev_m;
                        counter_m <= counter_m + 16'd1;
                    end
                end

                COMBINE: begin
                    // Store final Fibonacci results
                    fib_n_result <= fib_curr_n;
                    fib_m_result <= fib_curr_m;

                    // Apply formula: ((fib_n + fib_m - 1) * 2) mod MOD
                    temp_result <= mod_sub(fib_n_result + fib_m_result, 32'd1);
                    temp_result <= mod_sub(temp_result + temp_result, MOD);
                    result <= temp_result;
                end

                OUTPUT: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule