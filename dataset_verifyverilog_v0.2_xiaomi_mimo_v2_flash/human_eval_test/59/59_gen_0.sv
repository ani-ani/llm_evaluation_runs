module largest_prime_factor(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam INIT_FACTORS = 5'b00010;
    localparam CHECK_PRIME = 5'b00100;
    localparam UPDATE_LARGEST = 5'b01000;
    localparam DONE = 5'b10000;

    reg [4:0] state;
    reg [15:0] n_reg;       // Current value of n (gets divided)
    reg [7:0] divisor;      // Current divisor (2 to 255)
    reg [15:0] largest;     // Largest prime factor found
    reg [15:0] temp;        // Temporary register for division
    reg prime_check;        // Flag for primality check state
    reg [7:0] pc_divisor;   // Inner divisor for primality test
    reg is_prime_flag;      // Result of primality test
    reg [1:0] update_cnt;   // Counter for update cycles
    reg [15:0] divisor_sq;  // Combinational divisor squared
    
    // Combinational logic for divisor squared
    always @(*) begin
        divisor_sq = divisor * divisor;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            divisor <= 8'd0;
            largest <= 16'd0;
            temp <= 16'd0;
            prime_check <= 1'b0;
            pc_divisor <= 8'd0;
            is_prime_flag <= 1'b1;
            update_cnt <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_FACTORS;
                        n_reg <= n;
                    end
                end

                INIT_FACTORS: begin
                    divisor <= 8'd2;
                    largest <= 16'd1;
                    state <= CHECK_PRIME;
                    prime_check <= 1'b0;
                end

                CHECK_PRIME: begin
                    if (!prime_check) begin
                        // Start primality check
                        pc_divisor <= 8'd2;
                        is_prime_flag <= 1'b1;
                        prime_check <= 1'b1;
                    end else begin
                        // Iterative primality check
                        // Check if pc_divisor < divisor
                        if (pc_divisor < divisor) begin
                            // Check if divisor is divisible by pc_divisor
                            if (divisor % pc_divisor == 0) begin
                                is_prime_flag <= 1'b0;
                                // Skip remaining checks by jumping to end state logic
                                pc_divisor <= divisor;
                            end else begin
                                pc_divisor <= pc_divisor + 8'd1;
                            end
                        end else begin
                            // Primality check complete
                            prime_check <= 1'b0;
                            state <= UPDATE_LARGEST;
                            update_cnt <= 2'd0;
                        end
                    end
                end

                UPDATE_LARGEST: begin
                    case (update_cnt)
                        2'd0: begin
                            // Check if prime and divides n_reg
                            if (is_prime_flag && (n_reg % divisor == 0)) begin
                                n_reg <= n_reg / divisor;
                                temp <= n_reg; // Store old n for division result
                            end
                            update_cnt <= 2'd1;
                        end
                        2'd1: begin
                            // Second cycle for division/accumulation
                            if (is_prime_flag && (temp % divisor == 0)) begin
                                largest <= divisor;
                                // Continue dividing
                                n_reg <= temp / divisor;
                                update_cnt <= 2'd2; // Stay in this state to check again
                            end else begin
                                // Move to next divisor
                                if (divisor >= 8'd255) begin
                                    state <= DONE;
                                end else if (divisor_sq > n_reg) begin
                                    state <= DONE;
                                end else begin
                                    divisor <= divisor + 8'd1;
                                    state <= CHECK_PRIME;
                                    prime_check <= 1'b0;
                                end
                            end
                        end
                        2'd2: begin
                            // Check if we need to divide again by same divisor
                            if (n_reg % divisor == 0) begin
                                n_reg <= n_reg / divisor;
                                largest <= divisor;
                                update_cnt <= 2'd2; // Repeat
                            end else begin
                                // Move to next divisor
                                if (divisor >= 8'd255) begin
                                    state <= DONE;
                                end else if (divisor_sq > n_reg) begin
                                    state <= DONE;
                                end else begin
                                    divisor <= divisor + 8'd1;
                                    state <= CHECK_PRIME;
                                    prime_check <= 1'b0;
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    // If n_reg > 1 after division loop, it's the largest prime factor
                    if (n_reg > 1 && n_reg > largest) begin
                        result <= n_reg;
                    end else if (largest == 16'd1 && n_reg > 1) begin
                        // No factors found, n is prime
                        result <= n_reg;
                    end else begin
                        result <= largest;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule