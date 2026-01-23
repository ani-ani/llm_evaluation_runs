module min_cost_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] factor_count,
    input wire [7:0] prime_0,
    input wire [7:0] prime_1,
    input wire [7:0] prime_2,
    input wire [7:0] prime_3,
    input wire [7:0] exp_0,
    input wire [7:0] exp_1,
    input wire [7:0] exp_2,
    input wire [7:0] exp_3,
    output reg [63:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] S_IDLE              = 4'd0;
    localparam [3:0] S_LOAD              = 4'd1;
    localparam [3:0] S_COMPUTE_POWERS    = 4'd2;
    localparam [3:0] S_ENUMERATE         = 4'd3;
    localparam [3:0] S_COMPUTE_M         = 4'd4;
    localparam [3:0] S_COMPUTE_N         = 4'd5;
    localparam [3:0] S_COMPUTE_COST      = 4'd6;
    localparam [3:0] S_UPDATE_MIN        = 4'd7;
    localparam [3:0] S_DONE              = 4'd8;
    localparam [3:0] S_CHECK_DONE        = 4'd9;

    // State register
    reg [3:0] state;

    // Input storage registers
    reg [7:0] primes [0:3];
    reg [7:0] exps [0:3];
    reg [1:0] valid_factors;

    // Power table: 4 primes x 4 exponents (0-3) -> 16-bit values
    reg [15:0] powers [0:3][0:3];
    reg [1:0] power_prime_idx;
    reg [1:0] power_exp_idx;

    // Enumeration registers
    reg [1:0] a [0:3];
    reg [1:0] mult_idx;
    reg [63:0] M;
    reg [63:0] N;
    reg [63:0] cost;
    reg [63:0] min_cost;

    // Next state logic
    always @(*) begin
        case (state)
            S_IDLE: next_state = start ? S_LOAD : S_IDLE;
            S_LOAD: next_state = S_COMPUTE_POWERS;
            S_COMPUTE_POWERS: begin
                if (power_prime_idx < valid_factors) begin
                    if (power_exp_idx <= exps[power_prime_idx]) begin
                        next_state = S_COMPUTE_POWERS;
                    end else begin
                        if (power_prime_idx == valid_factors - 1'b1)
                            next_state = S_ENUMERATE;
                        else
                            next_state = S_COMPUTE_POWERS;
                    end
                end else begin
                    next_state = S_ENUMERATE;
                end
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
            S_UPDATE_MIN: next_state = S_CHECK_DONE;
            S_CHECK_DONE: begin
                if (enumeration_done)
                    next_state = S_DONE;
                else
                    next_state = S_ENUMERATE;
            end
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // State transition and initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 64'd0;
            valid_factors <= 2'd0;
            power_prime_idx <= 2'd0;
            power_exp_idx <= 2'd0;
            mult_idx <= 2'd0;
            M <= 64'd0;
            N <= 64'd0;
            cost <= 64'd0;
            min_cost <= 64'hFFFF_FFFF_FFFF_FFFF;
            a[0] <= 2'd0; a[1] <= 2'd0; a[2] <= 2'd0; a[3] <= 2'd0;
            primes[0] <= 8'd0; primes[1] <= 8'd0; primes[2] <= 8'd0; primes[3] <= 8'd0;
            exps[0] <= 8'd0; exps[1] <= 8'd0; exps[2] <= 8'd0; exps[3] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    min_cost <= 64'hFFFF_FFFF_FFFF_FFFF;
                end
                
                S_LOAD: begin
                    // Store input values into registers
                    primes[0] <= prime_0;
                    primes[1] <= prime_1;
                    primes[2] <= prime_2;
                    primes[3] <= prime_3;
                    exps[0] <= exp_0;
                    exps[1] <= exp_1;
                    exps[2] <= exp_2;
                    exps[3] <= exp_3;
                    valid_factors <= factor_count;
                end
                
                S_COMPUTE_POWERS: begin
                    if (power_prime_idx < valid_factors) begin
                        if (power_exp_idx <= exps[power_prime_idx]) begin
                            // Compute power
                            if (power_exp_idx == 2'd0) begin
                                powers[power_prime_idx][power_exp_idx] <= 16'd1;
                            end else begin
                                powers[power_prime_idx][power_exp_idx] <= powers[power_prime_idx][power_exp_idx - 2'd1] * primes[power_prime_idx];
                            end
                            power_exp_idx <= power_exp_idx + 2'd1;
                        end else begin
                            // Move to next prime
                            power_exp_idx <= 2'd0;
                            power_prime_idx <= power_prime_idx + 2'd1;
                        end
                    end
                end
                
                S_ENUMERATE: begin
                    mult_idx <= 2'd0;
                    M <= 64'd1;
                    N <= 64'd1;
                end
                
                S_COMPUTE_M: begin
                    if (mult_idx < valid_factors) begin
                        M <= M * powers[mult_idx][a[mult_idx]];
                        mult_idx <= mult_idx + 2'd1;
                    end
                end
                
                S_COMPUTE_N: begin
                    if (mult_idx < valid_factors) begin
                        N <= N * powers[mult_idx][exps[mult_idx] - a[mult_idx]];
                        mult_idx <= mult_idx + 2'd1;
                    end
                end
                
                S_COMPUTE_COST: begin
                    cost <= M + N;
                end
                
                S_UPDATE_MIN: begin
                    if (cost < min_cost) begin
                        min_cost <= cost;
                    end
                    // Increment odometer (a values)
                    if (valid_factors > 2'd0) begin
                        if (a[0] < exps[0]) begin
                            a[0] <= a[0] + 2'd1;
                        end else begin
                            a[0] <= 2'd0;
                            if (valid_factors > 2'd1) begin
                                if (a[1] < exps[1]) begin
                                    a[1] <= a[1] + 2'd1;
                                end else begin
                                    a[1] <= 2'd0;
                                    if (valid_factors > 2'd2) begin
                                        if (a[2] < exps[2]) begin
                                            a[2] <= a[2] + 2'd1;
                                        end else begin
                                            a[2] <= 2'd0;
                                            if (valid_factors > 2'd3) begin
                                                if (a[3] < exps[3]) begin
                                                    a[3] <= a[3] + 2'd1;
                                                end else begin
                                                    a[3] <= 2'd0;
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
                    result <= min_cost % 64'd1000000007;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combination logic for enumeration_done signal
    reg enumeration_done;
    always @(*) begin
        enumeration_done = 1'b1;
        if (valid_factors > 2'd0 && a[0] < exps[0]) enumeration_done = 1'b0;
        if (valid_factors > 2'd1 && a[1] < exps[1]) enumeration_done = 1'b0;
        if (valid_factors > 2'd2 && a[2] < exps[2]) enumeration_done = 1'b0;
        if (valid_factors > 2'd3 && a[3] < exps[3]) enumeration_done = 1'b0;
    end

endmodule