module pythagorean_triple_counter(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] count,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Iteration counters
    reg [3:0] a_reg, a_next;
    reg [3:0] b_reg, b_next;
    reg [3:0] c_reg, c_next;

    // Squared values
    reg [15:0] a_sq, b_sq, c_sq;
    reg [15:0] sum_sq;

    // Modulo computation
    function [15:0] mod_op;
        input [15:0] dividend;
        input [4:0] divisor;
        reg [15:0] remainder;
        integer i;
        begin
            remainder = dividend;
            for (i = 0; i < 16; i = i + 1) begin
                if (remainder >= divisor)
                    remainder = remainder - divisor;
                else
                    break;
            end
            mod_op = remainder;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            done <= 0;
            a_reg <= 0;
            b_reg <= 0;
            c_reg <= 0;
        end else begin
            current_state <= next_state;
            count <= count + (current_state == COMPUTE && (sum_sq % n) == c_sq) ? 1 : count;
            a_reg <= a_next;
            b_reg <= b_next;
            c_reg <= c_next;
            done <= (current_state == DONE);
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        a_next = a_reg;
        b_next = b_reg;
        c_next = c_reg;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    a_next = 1;
                    b_next = 1;
                    c_next = 1;
                end
            end

            COMPUTE: begin
                // Compute squares and sum
                a_sq = mod_op(a_reg * a_reg, n);
                b_sq = mod_op(b_reg * b_reg, n);
                c_sq = mod_op(c_reg * c_reg, n);
                sum_sq = a_sq + b_sq;

                // Iterate c
                if (c_reg < n - 1) begin
                    c_next = c_reg + 1;
                end else begin
                    c_next = 1;
                    // Iterate b
                    if (b_reg < n - 1) begin
                        b_next = b_reg + 1;
                    end else begin
                        b_next = a_reg + 1;
                        // Iterate a
                        if (a_reg < n - 1) begin
                            a_next = a_reg + 1;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    count = 0;
                    done = 0;
                end
            end
        endcase
    end

endmodule