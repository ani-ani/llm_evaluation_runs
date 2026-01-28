module PrimeFibonacci(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE_FIB = 3'd1;
    localparam [2:0] CHECK_PRIME = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] fib_current, fib_next, fib_temp;
    reg [3:0] prime_count;
    reg [31:0] divisor;
    reg [31:0] sqrt_bound;
    reg [15:0] cycle_count;
    reg is_prime;
    reg [31:0] prime_candidate;

    // Constants
    localparam [15:0] MAX_CYCLES = 16'd2000;

    // Fibonacci initial values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            fib_current <= 32'd1;
            fib_next <= 32'd1;
            prime_count <= 4'd0;
            cycle_count <= 16'd0;
            divisor <= 32'd0;
            sqrt_bound <= 32'd0;
            is_prime <= 1'b0;
            prime_candidate <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_FIB;
                end
            end
            GENERATE_FIB: begin
                next_state = CHECK_PRIME;
            end
            CHECK_PRIME: begin
                if (is_prime && prime_count == n) begin
                    next_state = DONE_STATE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = GENERATE_FIB;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Fibonacci generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fib_current <= 32'd1;
            fib_next <= 32'd1;
        end else if (state == GENERATE_FIB) begin
            fib_temp <= fib_current + fib_next;
            fib_current <= fib_next;
            fib_next <= fib_temp;
            prime_candidate <= fib_temp;
            cycle_count <= cycle_count + 16'd1;
        end
    end

    // Primality check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divisor <= 32'd0;
            sqrt_bound <= 32'd0;
            is_prime <= 1'b0;
        end else if (state == CHECK_PRIME) begin
            if (divisor == 32'd0) begin
                // Initialize primality check
                if (prime_candidate == 32'd1) begin
                    is_prime <= 1'b0; // 1 is not prime
                end else if (prime_candidate == 32'd2) begin
                    is_prime <= 1'b1; // 2 is prime
                end else if ((prime_candidate[0] == 1'b0) || (prime_candidate == 32'd1)) begin
                    is_prime <= 1'b0; // Even or 1
                end else begin
                    // Calculate sqrt bound (approximate)
                    sqrt_bound <= 32'd0;
                    if (prime_candidate >= 32'd4) begin
                        sqrt_bound <= 32'd2;
                    end
                    if (prime_candidate >= 32'd9) begin
                        sqrt_bound <= 32'd3;
                    end
                    if (prime_candidate >= 32'd25) begin
                        sqrt_bound <= 32'd5;
                    end
                    if (prime_candidate >= 32'd169) begin
                        sqrt_bound <= 32'd13;
                    end
                    if (prime_candidate >= 32'd289) begin
                        sqrt_bound <= 32'd17;
                    end
                    if (prime_candidate >= 32'd841) begin
                        sqrt_bound <= 32'd29;
                    end
                    if (prime_candidate >= 32'd961) begin
                        sqrt_bound <= 32'd31;
                    end
                    if (prime_candidate >= 32'd2401) begin
                        sqrt_bound <= 32'd49;
                    end
                    if (prime_candidate >= 32'd6241) begin
                        sqrt_bound <= 32'd79;
                    end
                    if (prime_candidate >= 32'd16129) begin
                        sqrt_bound <= 32'd127;
                    end
                    if (prime_candidate >= 32'd39601) begin
                        sqrt_bound <= 32'd199;
                    end
                    if (prime_candidate >= 32'd100000) begin
                        sqrt_bound <= 32'd316;
                    end
                    if (prime_candidate >= 32'd250000) begin
                        sqrt_bound <= 32'd500;
                    end
                    if (prime_candidate >= 32'd650000) begin
                        sqrt_bound <= 32'd806;
                    end
                    if (prime_candidate >= 32'd1000000) begin
                        sqrt_bound <= 32'd1000;
                    end
                    if (prime_candidate >= 32'd4000000) begin
                        sqrt_bound <= 32'd2000;
                    end
                    if (prime_candidate >= 32'd10000000) begin
                        sqrt_bound <= 32'd3162;
                    end
                    if (prime_candidate >= 32'd25000000) begin
                        sqrt_bound <= 32'd5000;
                    end
                    if (prime_candidate >= 32'd65000000) begin
                        sqrt_bound <= 32'd8062;
                    end
                    if (prime_candidate >= 32'd100000000) begin
                        sqrt_bound <= 32'd10000;
                    end
                    if (prime_candidate >= 32'd200000000) begin
                        sqrt_bound <= 32'd14142;
                    end
                    if (prime_candidate >= 32'd300000000) begin
                        sqrt_bound <= 32'd17320;
                    end
                    if (prime_candidate >= 32'd400000000) begin
                        sqrt_bound <= 32'd20000;
                    end
                    divisor <= 32'd3;
                    is_prime <= 1'b1;
                end
            end else if (divisor <= sqrt_bound) begin
                if (prime_candidate % divisor == 32'd0) begin
                    is_prime <= 1'b0;
                end
                divisor <= divisor + 32'd2;
            end else begin
                if (is_prime) begin
                    prime_count <= prime_count + 4'd1;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            if (prime_count == n) begin
                result <= prime_candidate;
            end else begin
                result <= 32'd0;
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule