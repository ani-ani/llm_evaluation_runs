module eurus_solver(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [7:0] k,
    output reg [29:0] result,
    output reg done
);

    // Constants
    localparam MOD = 30'd1000000007;
    localparam IDLE = 2'b00;
    localparam CALCULATE_PHI = 2'b01;
    localparam CHECK_COUNT = 2'b10;
    localparam DONE = 2'b11;

    // State registers
    reg [1:0] state;
    reg [9:0] current;
    reg [7:0] count;
    reg [29:0] temp_result;

    // Prime list for factorization (primes up to 31)
    localparam [3:0] PRIMES [0:10] = '{5'd2, 5'd3, 5'd5, 5'd7, 5'd11, 5'd13, 5'd17, 5'd19, 5'd23, 5'd29, 5'd31};
    reg [3:0] prime_index;
    reg [9:0] temp_n;
    reg [9:0] temp_p;
    reg [9:0] temp_remainder;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current <= 0;
            count <= 0;
            temp_result <= 0;
            prime_index <= 0;
            temp_n <= 0;
            temp_p <= 0;
            temp_remainder <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current <= n;
                        count <= k;
                        temp_result <= n;
                        state <= CALCULATE_PHI;
                    end
                end
                CALCULATE_PHI: begin
                    if (prime_index == 10) begin
                        // Factorization complete
                        temp_result <= temp_result % MOD;
                        current <= temp_result;
                        state <= CHECK_COUNT;
                    end else begin
                        // Factorization step
                        temp_p <= PRIMES[prime_index];
                        if (temp_n == 1) begin
                            prime_index <= prime_index + 1;
                        end else if (temp_n % temp_p == 0) begin
                            // Found a prime factor
                            temp_remainder <= temp_n / temp_p;
                            if (temp_remainder % temp_p == 0) begin
                                // Remove all occurrences of this prime
                                temp_n <= temp_remainder;
                            end else begin
                                // Update result
                                temp_result <= temp_result / temp_p * (temp_p - 1);
                                temp_n <= temp_remainder;
                                prime_index <= prime_index + 1;
                            end
                        end else begin
                            prime_index <= prime_index + 1;
                        end
                    end
                end
                CHECK_COUNT: begin
                    if (count == 0 || current == 1) begin
                        result <= current;
                        done <= 1;
                        state <= DONE;
                    end else begin
                        temp_result <= current;
                        temp_n <= current;
                        prime_index <= 0;
                        count <= count - 1;
                        state <= CALCULATE_PHI;
                    end
                end
                DONE: begin
                    if (!start) begin
                        done <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Initialize temp_n and temp_result at the start of CALCULATE_PHI
    always @(posedge clk) begin
        if (state == CALCULATE_PHI && prime_index == 0) begin
            temp_n <= current;
            temp_result <= current;
        end
    end

endmodule