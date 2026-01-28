module prime_fib(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_FIB   = 3'd1;
    localparam [2:0] CHECK_PRIME = 3'd2;
    localparam [2:0] FOUND      = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] prev, curr, next_fib;
    reg [3:0] prime_count;
    reg [15:0] divisor;
    reg [15:0] max_divisor;
    reg is_prime;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            prev <= 32'd1;
            curr <= 32'd1;
            prime_count <= 4'd0;
            divisor <= 16'd0;
            max_divisor <= 16'd0;
            is_prime <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= CALC_FIB;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_FIB: begin
                    next_fib <= curr + prev;
                    next_state <= CHECK_PRIME;
                end

                CHECK_PRIME: begin
                    // Check if next_fib is prime
                    if (next_fib <= 32'd1) begin
                        is_prime <= 1'b0;
                    end else if (next_fib == 32'd2) begin
                        is_prime <= 1'b1;
                    end else if (next_fib[0] == 1'b0) begin
                        is_prime <= 1'b0;
                    end else begin
                        // Calculate max divisor (min of sqrt(next_fib) and 2048)
                        if (next_fib[31:16] > 16'd0) begin
                            max_divisor <= 16'd2048;
                        end else begin
                            max_divisor <= next_fib[15:0] / 16'd32; // Approximate sqrt
                        end
                        divisor <= 16'd3;
                        is_prime <= 1'b1;
                        next_state <= CHECK_PRIME;
                    end

                    if (is_prime) begin
                        next_state <= FOUND;
                    end else begin
                        prev <= curr;
                        curr <= next_fib;
                        next_state <= CALC_FIB;
                    end
                end

                FOUND: begin
                    prime_count <= prime_count + 4'd1;
                    if (prime_count == n) begin
                        result <= next_fib;
                        next_state <= DONE_STATE;
                    end else begin
                        prev <= curr;
                        curr <= next_fib;
                        next_state <= CALC_FIB;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Divisor checking logic
    always @(posedge clk) begin
        if (state == CHECK_PRIME && is_prime && divisor <= max_divisor) begin
            if (next_fib % divisor == 32'd0) begin
                is_prime <= 1'b0;
            end
            divisor <= divisor + 16'd2;
        end
    end

endmodule