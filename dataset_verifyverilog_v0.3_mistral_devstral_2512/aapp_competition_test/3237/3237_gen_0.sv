module min_cost_solver #(
    parameter MAX_FACTORS = 4,
    parameter MAX_EXP = 3,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 64,
    parameter MOD = 1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] factor_count,
    input wire [DATA_WIDTH-1:0] prime_0,
    input wire [DATA_WIDTH-1:0] prime_1,
    input wire [DATA_WIDTH-1:0] prime_2,
    input wire [DATA_WIDTH-1:0] prime_3,
    input wire [DATA_WIDTH-1:0] exp_0,
    input wire [DATA_WIDTH-1:0] exp_1,
    input wire [DATA_WIDTH-1:0] exp_2,
    input wire [DATA_WIDTH-1:0] exp_3,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// Internal state machine states
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_LOAD = 4'd1;
localparam [3:0] S_COMPUTE_POWERS = 4'd2;
localparam [3:0] S_ENUMERATE = 4'd3;
localparam [3:0] S_COMPUTE_M = 4'd4;
localparam [3:0] S_COMPUTE_N = 4'd5;
localparam [3:0] S_COMPUTE_COST = 4'd6;
localparam [3:0] S_UPDATE_MIN = 4'd7;
localparam [3:0] S_DONE = 4'd8;

// Registers for input storage
reg [DATA_WIDTH-1:0] primes_0;
reg [DATA_WIDTH-1:0] primes_1;
reg [DATA_WIDTH-1:0] primes_2;
reg [DATA_WIDTH-1:0] primes_3;
reg [DATA_WIDTH-1:0] exps_0;
reg [DATA_WIDTH-1:0] exps_1;
reg [DATA_WIDTH-1:0] exps_2;
reg [DATA_WIDTH-1:0] exps_3;
reg [1:0] valid_factors;

// Power storage
reg [15:0] powers_0_0;
reg [15:0] powers_0_1;
reg [15:0] powers_0_2;
reg [15:0] powers_0_3;
reg [15:0] powers_1_0;
reg [15:0] powers_1_1;
reg [15:0] powers_1_2;
reg [15:0] powers_1_3;
reg [15:0] powers_2_0;
reg [15:0] powers_2_1;
reg [15:0] powers_2_2;
reg [15:0] powers_2_3;
reg [15:0] powers_3_0;
reg [15:0] powers_3_1;
reg [15:0] powers_3_2;
reg [15:0] powers_3_3;
reg [1:0] power_prime_idx;
reg [1:0] power_exp_idx;

// Enumeration registers
reg [1:0] a_0;
reg [1:0] a_1;
reg [1:0] a_2;
reg [1:0] a_3;
reg [1:0] mult_idx;
reg [RESULT_WIDTH-1:0] M;
reg [RESULT_WIDTH-1:0] N;
reg [RESULT_WIDTH-1:0] cost;
reg [RESULT_WIDTH-1:0] min_cost;

// State register
reg [3:0] state, next_state;

// Next state logic
always @(*) begin
    case (state)
        S_IDLE: next_state = start ? S_LOAD : S_IDLE;
        S_LOAD: next_state = S_COMPUTE_POWERS;
        S_COMPUTE_POWERS: begin
            if (power_prime_idx < valid_factors) begin
                if (power_exp_idx <= (power_prime_idx == 0 ? exps_0 : (power_prime_idx == 1 ? exps_1 : (power_prime_idx == 2 ? exps_2 : exps_3))))
                    next_state = S_COMPUTE_POWERS;
                else
                    next_state = (power_prime_idx == valid_factors-1) ? S_ENUMERATE : S_COMPUTE_POWERS;
            end else
                next_state = S_ENUMERATE;
        end
        S_ENUMERATE: next_state = S_COMPUTE_M;
        S_COMPUTE_M: begin
            if (mult_idx < valid_factors)
                next_state = S_COMPUTE_M;
            else
                next_state = S_COMPUTE_N;
        end
        S_COMPUTE_N: begin
            if (mult_idx < valid_factors)
                next_state = S_COMPUTE_N;
            else
                next_state = S_COMPUTE_COST;
        end
        S_COMPUTE_COST: next_state = S_UPDATE_MIN;
        S_UPDATE_MIN: begin
            if (enumeration_done)
                next_state = S_DONE;
            else
                next_state = S_ENUMERATE;
        end
        S_DONE: next_state = S_IDLE;
        default: next_state = S_IDLE;
    endcase
end

// State update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_IDLE;
    else
        state <= next_state;
end

// Load inputs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        primes_0 <= 0; primes_1 <= 0; primes_2 <= 0; primes_3 <= 0;
        exps_0 <= 0; exps_1 <= 0; exps_2 <= 0; exps_3 <= 0;
        valid_factors <= 0;
    end else if (state == S_LOAD) begin
        primes_0 <= prime_0; primes_1 <= prime_1; primes_2 <= prime_2; primes_3 <= prime_3;
        exps_0 <= exp_0; exps_1 <= exp_1; exps_2 <= exp_2; exps_3 <= exp_3;
        valid_factors <= factor_count;
    end
end

// Compute powers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        power_prime_idx <= 0;
        power_exp_idx <= 0;
    end else if (state == S_COMPUTE_POWERS) begin
        if (power_prime_idx < valid_factors) begin
            if (power_exp_idx <= (power_prime_idx == 0 ? exps_0 : (power_prime_idx == 1 ? exps_1 : (power_prime_idx == 2 ? exps_2 : exps_3)))) begin
                // Compute power: primes[power_prime_idx] ^ power_exp_idx
                if (power_exp_idx == 0) begin
                    if (power_prime_idx == 0) powers_0_0 <= 16'd1;
                    else if (power_prime_idx == 1) powers_1_0 <= 16'd1;
                    else if (power_prime_idx == 2) powers_2_0 <= 16'd1;
                    else powers_3_0 <= 16'd1;
                end else begin
                    if (power_prime_idx == 0) begin
                        if (power_exp_idx == 1) powers_0_1 <= powers_0_0 * primes_0;
                        else if (power_exp_idx == 2) powers_0_2 <= powers_0_1 * primes_0;
                        else powers_0_3 <= powers_0_2 * primes_0;
                    end else if (power_prime_idx == 1) begin
                        if (power_exp_idx == 1) powers_1_1 <= powers_1_0 * primes_1;
                        else if (power_exp_idx == 2) powers_1_2 <= powers_1_1 * primes_1;
                        else powers_1_3 <= powers_1_2 * primes_1;
                    end else if (power_prime_idx == 2) begin
                        if (power_exp_idx == 1) powers_2_1 <= powers_2_0 * primes_2;
                        else if (power_exp_idx == 2) powers_2_2 <= powers_2_1 * primes_2;
                        else powers_2_3 <= powers_2_2 * primes_2;
                    end else begin
                        if (power_exp_idx == 1) powers_3_1 <= powers_3_0 * primes_3;
                        else if (power_exp_idx == 2) powers_3_2 <= powers_3_1 * primes_3;
                        else powers_3_3 <= powers_3_2 * primes_3;
                    end
                end
                power_exp_idx <= power_exp_idx + 1;
            end else begin
                // Move to next prime
                power_exp_idx <= 0;
                power_prime_idx <= power_prime_idx + 1;
            end
        end
    end
end

// Enumeration and multiplication
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        a_0 <= 0; a_1 <= 0; a_2 <= 0; a_3 <= 0;
        mult_idx <= 0;
        M <= 0;
        N <= 0;
        cost <= 0;
        min_cost <= {RESULT_WIDTH{1'b1}};
        done <= 0;
        result <= 0;
    end else begin
        case (state)
            S_ENUMERATE: begin
                // Initialize multiplication
                mult_idx <= 0;
                M <= 1;
                N <= 1;
            end
            S_COMPUTE_M: begin
                if (mult_idx < valid_factors) begin
                    if (mult_idx == 0) begin
                        if (a_0 == 0) M <= M * powers_0_0;
                        else if (a_0 == 1) M <= M * powers_0_1;
                        else if (a_0 == 2) M <= M * powers_0_2;
                        else M <= M * powers_0_3;
                    end else if (mult_idx == 1) begin
                        if (a_1 == 0) M <= M * powers_1_0;
                        else if (a_1 == 1) M <= M * powers_1_1;
                        else if (a_1 == 2) M <= M * powers_1_2;
                        else M <= M * powers_1_3;
                    end else if (mult_idx == 2) begin
                        if (a_2 == 0) M <= M * powers_2_0;
                        else if (a_2 == 1) M <= M * powers_2_1;
                        else if (a_2 == 2) M <= M * powers_2_2;
                        else M <= M * powers_2_3;
                    end else begin
                        if (a_3 == 0) M <= M * powers_3_0;
                        else if (a_3 == 1) M <= M * powers_3_1;
                        else if (a_3 == 2) M <= M * powers_3_2;
                        else M <= M * powers_3_3;
                    end
                    mult_idx <= mult_idx + 1;
                end
            end
            S_COMPUTE_N: begin
                if (mult_idx < valid_factors) begin
                    if (mult_idx == 0) begin
                        if (exps_0 - a_0 == 0) N <= N * powers_0_0;
                        else if (exps_0 - a_0 == 1) N <= N * powers_0_1;
                        else if (exps_0 - a_0 == 2) N <= N * powers_0_2;
                        else N <= N * powers_0_3;
                    end else if (mult_idx == 1) begin
                        if (exps_1 - a_1 == 0) N <= N * powers_1_0;
                        else if (exps_1 - a_1 == 1) N <= N * powers_1_1;
                        else if (exps_1 - a_1 == 2) N <= N * powers_1_2;
                        else N <= N * powers_1_3;
                    end else if (mult_idx == 2) begin
                        if (exps_2 - a_2 == 0) N <= N * powers_2_0;
                        else if (exps_2 - a_2 == 1) N <= N * powers_2_1;
                        else if (exps_2 - a_2 == 2) N <= N * powers_2_2;
                        else N <= N * powers_2_3;
                    end else begin
                        if (exps_3 - a_3 == 0) N <= N * powers_3_0;
                        else if (exps_3 - a_3 == 1) N <= N * powers_3_1;
                        else if (exps_3 - a_3 == 2) N <= N * powers_3_2;
                        else N <= N * powers_3_3;
                    end
                    mult_idx <= mult_idx + 1;
                end
            end
            S_COMPUTE_COST: begin
                cost <= M + N;
            end
            S_UPDATE_MIN: begin
                if (cost < min_cost)
                    min_cost <= cost;
                // Increment exponent indices (odometer)
                if (valid_factors > 0) begin
                    if (a_0 < exps_0) begin
                        a_0 <= a_0 + 1;
                    end else begin
                        a_0 <= 0;
                        if (valid_factors > 1) begin
                            if (a_1 < exps_1) begin
                                a_1 <= a_1 + 1;
                            end else begin
                                a_1 <= 0;
                                if (valid_factors > 2) begin
                                    if (a_2 < exps_2) begin
                                        a_2 <= a_2 + 1;
                                    end else begin
                                        a_2 <= 0;
                                        if (valid_factors > 3) begin
                                            if (a_3 < exps_3) begin
                                                a_3 <= a_3 + 1;
                                            end else begin
                                                a_3 <= 0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            S_DONE: begin
                result <= min_cost % MOD;
                done <= 1;
            end
            default: begin
                done <= 0;
            end
        endcase
    end
end

// Signal to detect when all combinations have been processed
reg enumeration_done;
always @(*) begin
    enumeration_done = 1;
    if (valid_factors > 0 && a_0 < exps_0) enumeration_done = 0;
    if (valid_factors > 1 && a_1 < exps_1) enumeration_done = 0;
    if (valid_factors > 2 && a_2 < exps_2) enumeration_done = 0;
    if (valid_factors > 3 && a_3 < exps_3) enumeration_done = 0;
end

endmodule