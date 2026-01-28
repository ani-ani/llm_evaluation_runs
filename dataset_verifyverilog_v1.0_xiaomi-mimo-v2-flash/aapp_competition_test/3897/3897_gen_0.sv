module FactorizationCount (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_primes,
    input wire [31:0] prime_counts [0:11],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [9:0] MAX_FACT = 10'd1000;
    
    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PRELOAD     = 3'd1;
    localparam [2:0] FETCH       = 3'd2;
    localparam [2:0] COMPUTE_NK  = 3'd3;
    localparam [2:0] LOOKUP_FACT = 3'd4;
    localparam [2:0] CALC_COMB   = 3'd5;
    localparam [2:0] ACCUMULATE  = 3'd6;
    localparam [2:0] DONE_STATE  = 3'd7;
    
    reg [2:0] state, next_state;
    
    // Control registers
    reg [9:0] idx;              // Current prime index
    reg [9:0] fact_idx;         // Index for factorial lookups
    reg [9:0] loop_limit;       // Loop limit
    
    // Data registers
    reg [31:0] c_val;           // Current prime count
    reg [31:0] n_val;           // n = c + N - 1
    reg [31:0] k_val;           // k = N - 1
    reg [31:0] n_minus_k;       // n - k
    reg [31:0] comb_val;        // Computed combination
    reg [31:0] product;         // Accumulated product
    
    // Factorial and inverse factorial storage (0 to 1000)
    reg [31:0] fact [0:1000];
    reg [31:0] inv_fact [0:1000];
    
    // Multiplication pipeline registers
    reg [31:0] mult_a, mult_b;
    reg [31:0] mult_result;
    reg mult_valid;
    reg [2:0] mult_stage;       // 0=idle, 1=first, 2=second, 3=third
    
    // Internal N (fixed during calculation)
    reg [31:0] N_val;
    
    // Step counter for pipeline stages
    reg [2:0] step;
    
    // Integer for loop (for Icarus compatibility)
    integer i;

    // Forward declarations for factorial precomputation
    function automatic [31:0] mod_pow(input [31:0] base, input [31:0] exp, input [31:0] mod);
        reg [31:0] result_temp;
        reg [31:0] b;
        reg [31:0] e;
    begin
        result_temp = 32'd1;
        b = base % mod;
        e = exp;
        while (e > 0) begin
            if (e[0]) begin
                result_temp = (result_temp * b) % mod;
            end
            b = (b * b) % mod;
            e = e >> 1;
        end
        mod_pow = result_temp;
    end
    endfunction

    // Factorial precomputation (combinatorial, run once)
    initial begin
        integer j;
        // Compute factorials
        fact[0] = 32'd1;
        for (j = 1; j <= 1000; j = j + 1) begin
            fact[j] = (fact[j-1] * j) % MOD;
        end
        // Compute inverse factorials
        inv_fact[1000] = mod_pow(fact[1000], MOD - 32'd2, MOD);
        for (j = 999; j >= 0; j = j - 1) begin
            inv_fact[j] = (inv_fact[j+1] * (j + 1)) % MOD;
        end
    end

    // Modular multiplication logic (pipelined)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result <= 32'd0;
            mult_valid <= 1'b0;
            mult_stage <= 3'd0;
            step <= 3'd0;
        end else begin
            mult_valid <= 1'b0;
            
            case (mult_stage)
                3'd0: begin // Idle
                    mult_stage <= 3'd0;
                end
                3'd1: begin // First multiplication (a * b)
                    mult_result <= (mult_a * mult_b) % MOD;
                    mult_stage <= 3'd2;
                end
                3'd2: begin // Second multiplication (previous * c)
                    mult_result <= (mult_result * mult_a) % MOD;
                    mult_stage <= 3'd3;
                end
                3'd3: begin // Third multiplication (previous * d)
                    mult_result <= (mult_result * mult_a) % MOD;
                    mult_valid <= 1'b1;
                    mult_stage <= 3'd0;
                end
                default: mult_stage <= 3'd0;
            endcase
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            product <= 32'd1;
            idx <= 10'd0;
            c_val <= 32'd0;
            n_val <= 32'd0;
            k_val <= 32'd0;
            n_minus_k <= 32'd0;
            comb_val <= 32'd0;
            N_val <= 32'd0;
            fact_idx <= 10'd0;
            mult_stage <= 3'd0;
            loop_limit <= 10'd0;
            step <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PRELOAD;
                        N_val <= {28'd0, num_primes}; // Store N
                        loop_limit <= {6'd0, num_primes};
                    end else begin
                        state <= IDLE;
                    end
                end
                
                PRELOAD: begin
                    // Initialize product to 1
                    product <= 32'd1;
                    idx <= 10'd0;
                    state <= FETCH;
                end
                
                FETCH: begin
                    if (idx < loop_limit) begin
                        // Fetch prime count
                        c_val <= prime_counts[idx];
                        state <= COMPUTE_NK;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                COMPUTE_NK: begin
                    // Compute n = c + N - 1
                    // Compute k = N - 1
                    // Compute n - k
                    n_val <= c_val + N_val - 32'd1;
                    k_val <= N_val - 32'd1;
                    n_minus_k <= c_val;
                    state <= LOOKUP_FACT;
                    step <= 3'd0;
                end
                
                LOOKUP_FACT: begin
                    case (step)
                        3'd0: begin // Setup first multiplication: fact[n] * inv_fact[k]
                            mult_a <= fact[n_val[9:0]];
                            mult_b <= inv_fact[k_val[9:0]];
                            mult_stage <= 3'd1;
                            step <= 3'd1;
                        end
                        3'd1: begin // Wait for result
                            if (mult_valid) begin
                                mult_a <= mult_result;
                                mult_b <= inv_fact[n_minus_k[9:0]];
                                mult_stage <= 3'd1; // Do second multiply
                                step <= 3'd2;
                            end
                        end
                        3'd2: begin // Wait for second result
                            if (mult_valid && mult_stage == 3'd0) begin
                                // If stage reset, calculation is done
                                // But we need to wait for pipeline
                                step <= 3'd3;
                            end
                        end
                        3'd3: begin // Wait one more cycle for pipeline
                            // Actually, we need to capture mult_result when it's done
                            // Let's redesign the step logic
                            step <= 3'd0;
                            state <= CALC_COMB;
                        end
                        default: step <= 3'd0;
                    endcase
                end
                
                CALC_COMB: begin
                    // In original plan: C(n, k) = fact[n] * inv_fact[k] * inv_fact[n-k]
                    // Pipeline:
                    // Step 0: Load fact[n] and inv_fact[k] -> mult_a, mult_b
                    // Step 1: Wait pipeline, then load mult_a=product, mult_b=inv_fact[n-k]
                    // Step 2: Wait pipeline
                    // Step 3: Capture result
                    
                    // Re-implementation for reliability
                    if (step == 3'd0) begin
                        mult_a <= fact[n_val[9:0]];
                        mult_b <= inv_fact[k_val[9:0]];
                        mult_stage <= 3'd1;
                        step <= 3'd1;
                    end else if (step == 3'd1) begin
                        if (mult_valid) begin
                            // mult_result = fact[n] * inv_fact[k]
                            mult_a <= mult_result;
                            mult_b <= inv_fact[n_minus_k[9:0]];
                            mult_stage <= 3'd1; // Start second multiply
                            step <= 3'd2;
                        end
                    end else if (step == 3'd2) begin
                        if (mult_valid) begin
                            // mult_result = (fact[n] * inv_fact[k]) * inv_fact[n-k]
                            comb_val <= mult_result;
                            step <= 3'd0;
                            state <= ACCUMULATE;
                        end
                    end
                end
                
                ACCUMULATE: begin
                    // product = product * comb_val % MOD
                    if (step == 3'd0) begin
                        mult_a <= product;
                        mult_b <= comb_val;
                        mult_stage <= 3'd1;
                        step <= 3'd1;
                    end else if (step == 3'd1) begin
                        if (mult_valid) begin
                            product <= mult_result;
                            idx <= idx + 10'd1;
                            step <= 3'd0;
                            state <= FETCH;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= product;
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