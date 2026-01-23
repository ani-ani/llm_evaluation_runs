module find_zero (
    input clk,
    input rst_n,
    input start,
    input [4:0] degree,
    input [3:0][15:0] coeffs,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // Constants
    localparam IDLE = 3'b000;
    localparam EVAL_F = 3'b001;
    localparam EVAL_FP = 3'b010;
    localparam COMPUTE_DELTA = 3'b011;
    localparam UPDATE_X = 3'b100;
    localparam DONE = 3'b101;
    localparam ERROR = 3'b110;

    localparam MAX_ITER = 5'd16;
    localparam CONVERGE_THRESHOLD = 16'h00000040; // 2^(-8) in Q16.16

    // State and counters
    reg [2:0] state = IDLE;
    reg [4:0] iter_count = 0;

    // Internal registers
    reg [31:0] x = 0; // Current x in Q16.16
    reg [31:0] fx; // f(x) in Q16.16
    reg [31:0] fpx; // f'(x) in Q16.16
    reg [31:0] delta; // delta in Q16.16

    // Intermediate calculation registers
    reg [31:0] x_pow; // x^i for polynomial evaluation
    reg [31:0] term; // term for polynomial evaluation
    reg [31:0] sum; // sum for polynomial evaluation

    // Division variables
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [4:0] div_iter;

    // Saturate function
    function [31:0] saturate;
        input [31:0] val;
        begin
            if (val > 32'h7FFFFFFF) begin
                saturate = 32'h7FFFFFFF;
            end else if (val < 32'h80000000) begin
                saturate = 32'h80000000;
            end else begin
                saturate = val;
            end
        end
    endfunction

    // Multiply function with saturation
    function [31:0] multiply;
        input [31:0] a, b;
        begin
            multiply = saturate($signed(a) * $signed(b) >> 16);
        end
    endfunction

    // Division approximation (iterative)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_iter <= 0;
            quotient <= 0;
        end else if (state == COMPUTE_DELTA) begin
            if (div_iter == 0) begin
                quotient <= 32'h7FFFFFFF; // Initial guess for 1/divisor
            end else begin
                quotient <= saturate(quotient * (32'h00020000 - multiply(divisor, quotient)));
                div_iter <= div_iter + 1;
                if (div_iter == 5'd8) begin
                    state <= UPDATE_X;
                end
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter_count <= 0;
            x <= 32'h00000000;
            fx <= 0;
            fpx <= 0;
            delta <= 0;
            done <= 0;
            error <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= EVAL_F;
                        iter_count <= 0;
                        x <= 32'h00000000;
                        done <= 0;
                        error <= 0;
                    end
                end

                EVAL_F: begin
                    // Evaluate f(x) = c0 + c1*x + c2*x^2 + ... + cn*x^n
                    sum = 32'h00000000;
                    x_pow = 32'h00010000; // x^0 = 1.0 in Q16.16
                    for (integer i = 0; i <= degree; i = i + 1) begin
                        term = multiply(x_pow, {16'h0000, coeffs[i]});
                        sum = saturate(sum + term);
                        if (i < degree) begin
                            x_pow = multiply(x_pow, x);
                        end
                    end
                    fx <= sum;
                    state <= EVAL_FP;
                end

                EVAL_FP: begin
                    // Evaluate f'(x) = c1 + 2*c2*x + ... + n*cn*x^(n-1)
                    sum = 32'h00000000;
                    x_pow = 32'h00010000; // x^0 = 1.0 in Q16.16
                    for (integer i = 0; i < degree; i = i + 1) begin
                        term = multiply(x_pow, {16'h0000, coeffs[i+1]});
                        term = saturate(term * (i + 1));
                        sum = saturate(sum + term);
                        x_pow = multiply(x_pow, x);
                    end
                    fpx <= sum;
                    state <= COMPUTE_DELTA;
                    div_iter <= 0;
                    dividend <= fx;
                    divisor <= fpx;
                end

                COMPUTE_DELTA: begin
                    // delta = fx / fpx
                    if (divisor == 0) begin
                        state <= ERROR;
                    end else if (div_iter == 5'd8) begin
                        delta <= multiply(fx, quotient);
                        state <= UPDATE_X;
                    end
                end

                UPDATE_X: begin
                    // x_{n+1} = x_n - delta
                    x <= saturate(x - delta);
                    iter_count <= iter_count + 1;

                    // Check convergence
                    if (|fx| < CONVERGE_THRESHOLD || iter_count == MAX_ITER) begin
                        state <= DONE;
                    end else begin
                        state <= EVAL_F;
                    end
                end

                DONE: begin
                    done <= 1;
                    result <= x[31:16]; // Extract Q16.16 result
                    if (start) begin
                        state <= IDLE;
                    end
                end

                ERROR: begin
                    error <= 1;
                    if (start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule