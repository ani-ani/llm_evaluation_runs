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
    localparam [2:0] DONE       = 3'd4;
    localparam [2:0] FOUND_CONTINUE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [31:0] prev_fib;
    reg [31:0] curr_fib;
    reg [31:0] next_fib;
    reg [3:0] prime_count;
    reg [31:0] divisor;
    reg [31:0] sqrt_limit;
    reg [31:0] current_test;
    reg prime_flag;
    reg [15:0] cycle_counter;
    
    // Wires
    wire [31:0] sum;
    wire [31:0] limit;
    wire is_divisor;
    
    // Combinational logic
    assign sum = curr_fib + prev_fib;
    assign limit = (current_test > 2048) ? 2048 : current_test;
    assign is_divisor = (current_test % divisor == 0);
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            prev_fib <= 32'd0;
            curr_fib <= 32'd0;
            next_fib <= 32'd0;
            prime_count <= 4'd0;
            divisor <= 32'd0;
            current_test <= 32'd0;
            sqrt_limit <= 32'd0;
            prime_flag <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        prev_fib <= 32'd1;
                        curr_fib <= 32'd1;
                        prime_count <= 4'd0;
                        state <= CALC_FIB;
                    end
                end
                
                CALC_FIB: begin
                    next_fib <= sum;
                    current_test <= sum;
                    state <= CHECK_PRIME;
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // Initialize primality check
                    if (sum <= 32'd1) begin
                        // Not prime, skip to next
                        state <= FOUND_CONTINUE;
                        prime_flag <= 1'b0;
                    end else if (sum == 32'd2) begin
                        // 2 is prime
                        prime_flag <= 1'b1;
                        state <= FOUND;
                    end else if (sum[0] == 0) begin
                        // Even number > 2, not prime
                        prime_flag <= 1'b0;
                        state <= FOUND_CONTINUE;
                    end else begin
                        // Odd number > 2, check primality
                        divisor <= 32'd3;
                        sqrt_limit <= limit;
                        prime_flag <= 1'b1; // Assume prime until proven otherwise
                        state <= CHECK_PRIME;
                    end
                end
                
                CHECK_PRIME: begin
                    if (divisor > sqrt_limit) begin
                        // No divisors found, it's prime
                        prime_flag <= 1'b1;
                        state <= FOUND;
                    end else if (is_divisor) begin
                        // Found a divisor, not prime
                        prime_flag <= 1'b0;
                        state <= FOUND_CONTINUE;
                    end else begin
                        divisor <= divisor + 32'd2; // Only check odd divisors
                        state <= CHECK_PRIME;
                    end
                end
                
                FOUND: begin
                    if (prime_count + 4'd1 == n) begin
                        result <= next_fib;
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        prime_count <= prime_count + 4'd1;
                        state <= FOUND_CONTINUE;
                    end
                end
                
                FOUND_CONTINUE: begin
                    prev_fib <= curr_fib;
                    curr_fib <= next_fib;
                    state <= CALC_FIB;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule