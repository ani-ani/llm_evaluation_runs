module TotientIteration(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [39:0] n_in,
    input wire [39:0] k_in,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_ITER = 32'd40;
    localparam [31:0] MAX_PRIMES = 32'd16;

    // Precomputed primes (first 16 primes)
    localparam [39:0] PRIMES [0:15] = '
        {40'd2, 40'd3, 40'd5, 40'd7, 40'd11, 40'd13, 40'd17, 40'd19,
         40'd23, 40'd29, 40'd31, 40'd37, 40'd41, 40'd43, 40'd47, 40'd53};

    // Precomputed modular inverses for primes mod 1e9+7
    localparam [31:0] INV [0:15] = '
        {32'd500000004, 32'd333333336, 32'd400000003, 32'd142857144,
         32'd90909091, 32'd76923077, 32'd58823530, 32'd105263158,
         32'd43478261, 32'd34482759, 32'd64516129, 32'd27027027,
         32'd121951220, 32'd23255814, 32'd212765958, 32'd188679245};

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_M = 3'd1;
    localparam [2:0] COMPUTE_TOTIENT = 3'd2;
    localparam [2:0] COMPUTE_PRIME = 3'd3;
    localparam [2:0] COMPUTE_REMAINING = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [39:0] current_n;
    reg [39:0] m_iterations;
    reg [31:0] totient_result;
    reg [31:0] prime_index;
    reg [39:0] temp_n;
    reg [31:0] cycle_count;
    reg [39:0] remaining_factor;
    reg [31:0] inv_temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_n <= 40'd0;
            m_iterations <= 40'd0;
            totient_result <= 32'd1;
            prime_index <= 32'd0;
            temp_n <= 40'd0;
            cycle_count <= 32'd0;
            remaining_factor <= 40'd0;
            inv_temp <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE_M;
                        busy <= 1'b1;
                        current_n <= n_in;
                        m_iterations <= (k_in + 40'd1) >> 1;
                        cycle_count <= 32'd0;
                    end
                end

                COMPUTE_M: begin
                    if (current_n == 40'd1 || m_iterations == 40'd0) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE_TOTIENT;
                        totient_result <= 32'd1;
                        prime_index <= 32'd0;
                        temp_n <= current_n;
                    end
                end

                COMPUTE_TOTIENT: begin
                    if (temp_n == 40'd1) begin
                        next_state <= COMPUTE_M;
                        current_n <= 40'd1;
                        m_iterations <= m_iterations - 40'd1;
                    end else begin
                        next_state <= COMPUTE_PRIME;
                        prime_index <= 32'd0;
                        remaining_factor <= temp_n;
                    end
                end

                COMPUTE_PRIME: begin
                    if (prime_index >= MAX_PRIMES) begin
                        next_state <= COMPUTE_REMAINING;
                    end else begin
                        if (remaining_factor % PRIMES[prime_index] == 40'd0) begin
                            // Apply totient formula: result = result * (p-1) / p
                            totient_result <= (totient_result * (PRIMES[prime_index] - 40'd1)) % MOD;
                            inv_temp <= INV[prime_index];
                            totient_result <= (totient_result * inv_temp) % MOD;
                            // Remove all factors of this prime
                            while (remaining_factor % PRIMES[prime_index] == 40'd0) begin
                                remaining_factor <= remaining_factor / PRIMES[prime_index];
                            end
                        end
                        prime_index <= prime_index + 32'd1;
                    end
                end

                COMPUTE_REMAINING: begin
                    if (remaining_factor > 40'd1) begin
                        // Apply totient for remaining factor
                        totient_result <= (totient_result * (remaining_factor - 40'd1)) % MOD;
                        inv_temp <= mod_inverse(remaining_factor);
                        totient_result <= (totient_result * inv_temp) % MOD;
                    end
                    next_state <= COMPUTE_M;
                    current_n <= totient_result;
                    m_iterations <= m_iterations - 40'd1;
                end

                FINISH: begin
                    result <= current_n % MOD;
                    done <= 1'b1;
                    next_state <= IDLE;
                    busy <= 1'b0;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // Modular inverse function (using extended Euclidean algorithm)
    function [31:0] mod_inverse;
        input [39:0] a;
        reg [39:0] m;
        reg [39:0] x, y;
        reg [39:0] u, v;
        begin
            m = MOD;
            x = 39'd0;
            y = 39'd1;
            u = 39'd1;
            v = 39'd0;

            while (a != 39'd0) begin
                if (m > a) begin
                    m = m - a;
                    u = u - x;
                    v = v - y;
                end else begin
                    a = a - m;
                    x = x - u;
                    y = y - v;
                end
            end

            if (u < 39'd0) begin
                mod_inverse = u + MOD;
            end else begin
                mod_inverse = u;
            end
        end
    endfunction

endmodule