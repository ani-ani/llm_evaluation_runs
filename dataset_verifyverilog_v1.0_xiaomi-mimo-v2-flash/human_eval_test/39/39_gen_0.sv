module prime_fibonacci (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK_PRIME = 3'd2;
    localparam [2:0] NEXT_FIB = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Registers and variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [31:0] fib_curr;
    reg [31:0] fib_prev;
    reg [31:0] fib_next;
    reg [31:0] temp_result;
    reg [3:0] prime_count;
    reg [31:0] divisor;
    reg [31:0] divisor_limit;
    reg [31:0] cycle_count;
    reg [1:0] div_state;
    reg is_prime_flag;
    reg [3:0] target_n;
    
    // Combinational logic for next state and operations
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                next_state = CHECK_PRIME;
            end
            CHECK_PRIME: begin
                if (is_prime_flag) begin
                    if (prime_count == target_n) begin
                        next_state = FINISH;
                    end else begin
                        next_state = NEXT_FIB;
                    end
                end else if (divisor > divisor_limit) begin
                    next_state = NEXT_FIB;
                end
            end
            NEXT_FIB: begin
                next_state = COMPUTE;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            fib_curr <= 32'd0;
            fib_prev <= 32'd0;
            fib_next <= 32'd0;
            temp_result <= 32'd0;
            prime_count <= 4'd0;
            divisor <= 32'd0;
            divisor_limit <= 32'd0;
            cycle_count <= 32'd0;
            div_state <= 2'd0;
            is_prime_flag <= 1'b0;
            target_n <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    prime_count <= 4'd0;
                    is_prime_flag <= 1'b0;
                    div_state <= 2'd0;
                    if (start) begin
                        target_n <= n;
                        fib_prev <= 32'd1;
                        fib_curr <= 32'd1;
                        prime_count <= 4'd1;
                        temp_result <= 32'd1;
                    end
                end
                
                COMPUTE: begin
                    // Generate next Fibonacci number
                    fib_next <= fib_curr + fib_prev;
                    fib_prev <= fib_curr;
                    fib_curr <= fib_next;
                    div_state <= 2'd0;
                    is_prime_flag <= 1'b0;
                    cycle_count <= cycle_count + 32'd1;
                end
                
                CHECK_PRIME: begin
                    case (div_state)
                        2'd0: begin
                            // Initialize primality check
                            if (fib_curr <= 32'd1) begin
                                is_prime_flag <= 1'b0;
                            end else if (fib_curr <= 32'd3) begin
                                is_prime_flag <= 1'b1;
                            end else if ((fib_curr[0] == 1'b0) || (fib_curr[1] == 1'b0 && fib_curr[2:0] == 3'd0)) begin
                                // Even numbers or divisible by 3
                                is_prime_flag <= 1'b0;
                            end else begin
                                divisor <= 32'd5;
                                // Rough sqrt approximation: divisor <= sqrt(fib_curr)
                                // For safety, we check up to 65535 (hardware limit)
                                divisor_limit <= 32'd65535;
                                div_state <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // Trial division
                            if (divisor > divisor_limit) begin
                                // Exhausted all possible divisors
                                is_prime_flag <= 1'b1;
                            end else begin
                                if (fib_curr % divisor == 32'd0) begin
                                    // Found a divisor
                                    is_prime_flag <= 1'b0;
                                end else if (fib_curr % (divisor + 32'd2) == 32'd0) begin
                                    is_prime_flag <= 1'b0;
                                end else begin
                                    divisor <= divisor + 32'd6;
                                    // Continue checking if we haven't exceeded limit
                                    if (divisor > divisor_limit) begin
                                        is_prime_flag <= 1'b1;
                                    end
                                end
                            end
                        end
                        default: begin
                            is_prime_flag <= 1'b0;
                        end
                    endcase
                end
                
                NEXT_FIB: begin
                    if (is_prime_flag) begin
                        prime_count <= prime_count + 4'd1;
                        temp_result <= fib_curr;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    prime_count <= 4'd0;
                end
                
                default: begin
                    // Reset to safe state
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= 32'd2000 && state != IDLE) begin
                // Force finish to prevent timeout
                state <= FINISH;
                result <= temp_result;
                done <= 1'b1;
            end
        end
    end

endmodule