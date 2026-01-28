module min_cost_solver #(
    parameter MAX_FACTORS = 4,
    parameter MAX_EXP = 3,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 64,
    parameter MOD = 32'd1000000007
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

// State declarations
localparam [3:0] S_IDLE         = 4'd0;
localparam [3:0] S_LOAD         = 4'd1;
localparam [3:0] S_COMPUTE_POW  = 4'd2;
localparam [3:0] S_ENUM         = 4'd3;
localparam [3:0] S_COMPUTE_M    = 4'd4;
localparam [3:0] S_COMPUTE_N    = 4'd5;
localparam [3:0] S_COMPUTE_COST = 4'd6;
localparam [3:0] S_UPDATE_MIN   = 4'd7;
localparam [3:0] S_DONE         = 4'd8;

// Data storage
reg [DATA_WIDTH-1:0] primes [0:3];
reg [DATA_WIDTH-1:0] exps [0:3];
reg [DATA_WIDTH-1:0] valid_factors;
reg [3:0] state, next_state;

// Power storage and indices
reg [15:0] powers [0:3][0:3];
reg [1:0] pow_prime_idx;
reg [1:0] pow_exp_idx;

// Enumeration storage
reg [1:0] a [0:3];
reg [1:0] mult_idx;
reg [RESULT_WIDTH-1:0] M;
reg [RESULT_WIDTH-1:0] N;
reg [RESULT_WIDTH-1:0] cost;
reg [RESULT_WIDTH-1:0] min_cost;
reg loop_done;

integer i, j;

// State transition
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:         if (start) next_state = S_LOAD;
        S_LOAD:         next_state = S_COMPUTE_POW;
        S_COMPUTE_POW:  if (pow_prime_idx >= valid_factors) next_state = S_ENUM;
        S_ENUM:         next_state = S_COMPUTE_M;
        S_COMPUTE_M:    if (mult_idx == valid_factors) next_state = S_COMPUTE_N;
        S_COMPUTE_N:    if (mult_idx == valid_factors) next_state = S_COMPUTE_COST;
        S_COMPUTE_COST: next_state = S_UPDATE_MIN;
        S_UPDATE_MIN:   next_state = (loop_done) ? S_DONE : S_ENUM;
        S_DONE:         next_state = S_IDLE;
        default:        next_state = S_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        result <= {RESULT_WIDTH{1'b0}};
        min_cost <= {RESULT_WIDTH{1'b1}};
        
        for (i = 0; i < 4; i = i + 1) begin
            primes[i] <= {DATA_WIDTH{1'b0}};
            exps[i] <= {DATA_WIDTH{1'b0}};
            a[i] <= 2'd0;
        end
        
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                powers[i][j] <= 16'd0;
            end
        end
        
        pow_prime_idx <= 2'd0;
        pow_exp_idx <= 2'd0;
        mult_idx <= 2'd0;
        M <= {RESULT_WIDTH{1'b0}};
        N <= {RESULT_WIDTH{1'b0}};
        cost <= {RESULT_WIDTH{1'b0}};
        valid_factors <= 2'd0;
        loop_done <= 1'b0;
    end
    else begin
        state <= next_state;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    valid_factors <= factor_count;
                end
            end
            
            S_LOAD: begin
                primes[0] <= prime_0;
                primes[1] <= prime_1;
                primes[2] <= prime_2;
                primes[3] <= prime_3;
                exps[0] <= exp_0;
                exps[1] <= exp_1;
                exps[2] <= exp_2;
                exps[3] <= exp_3;
                pow_prime_idx <= 2'd0;
                pow_exp_idx <= 2'd0;
            end
            
            S_COMPUTE_POW: begin
                if (pow_prime_idx < valid_factors) begin
                    if (pow_exp_idx <= exps[pow_prime_idx]) begin
                        if (pow_exp_idx == 2'd0) begin
                            powers[pow_prime_idx][pow_exp_idx] <= 16'd1;
                        end
                        else begin
                            powers[pow_prime_idx][pow_exp_idx] <= powers[pow_prime_idx][pow_exp_idx-2'd1] * primes[pow_prime_idx];
                        end
                        pow_exp_idx <= pow_exp_idx + 2'd1;
                    end
                    else begin
                        pow_exp_idx <= 2'd0;
                        pow_prime_idx <= pow_prime_idx + 2'd1;
                    end
                end
            end
            
            S_ENUM: begin
                mult_idx <= 2'd0;
                M <= {RESULT_WIDTH{1'b1}};
                N <= {RESULT_WIDTH{1'b1}};
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
                
                // Odemeter increment
                if (a[0] < exps[0]) begin
                    a[0] <= a[0] + 2'd1;
                end
                else begin
                    a[0] <= 2'd0;
                    if (a[1] < exps[1]) begin
                        a[1] <= a[1] + 2'd1;
                    end
                    else begin
                        a[1] <= 2'd0;
                        if (a[2] < exps[2]) begin
                            a[2] <= a[2] + 2'd1;
                        end
                        else begin
                            a[2] <= 2'd0;
                            if (a[3] < exps[3]) begin
                                a[3] <= a[3] + 2'd1;
                            end
                            else begin
                                a[3] <= 2'd0;
                                loop_done <= 1'b1;
                            end
                        end
                    end
                end
            end
            
            S_DONE: begin
                result <= min_cost % MOD;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule