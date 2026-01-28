module HopscotchPaths (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [7:0] X,
    input wire [7:0] Y,
    output reg [31:0] result,
    output reg done
);
    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_K    = 3'd1;
    localparam [2:0] CHECK_K   = 3'd2;
    localparam [2:0] COMPUTE_X = 3'd3;
    localparam [2:0] COMPUTE_Y = 3'd4;
    localparam [2:0] ACCUM     = 3'd5;
    localparam [2:0] FINISH    = 3'd6;
    
    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Loop variables
    reg [7:0] k;                  // Current number of hops
    reg [7:0] max_k;              // Maximum valid k
    reg [7:0] n_x;                // N - k*X
    reg [7:0] n_y;                // N - k*Y
    
    // Computation registers for binomial coefficients
    reg [31:0] comb_x;            // C(n_x + k - 1, k - 1)
    reg [31:0] comb_y;            // C(n_y + k - 1, k - 1)
    reg [31:0] term_product;      // comb_x * comb_y
    
    // Iterative binomial computation state
    reg [7:0] bin_n;              // n parameter
    reg [7:0] bin_k;              // k parameter (0 to target_k)
    reg [7:0] target_k;           // Final k value (target_k)
    reg [31:0] current_val;       // Current C(n, k)
    reg [31:0] current_den;       // Current denominator multiplier (k)
    reg [7:0] calc_step;          // Step counter for calculation
    
    // Modular arithmetic registers
    reg [63:0] mul_temp;          // 64-bit for multiplication
    reg [31:0] inv_k;             // Modular inverse of k
    reg [7:0]  current_k;         // k for inverse calculation
    reg [2:0]  inv_state;         // State for modular inverse
    
    // Helper signals
    reg valid_k;
    reg [31:0] next_result;
    
    // Control signals for modular operations
    reg compute_inv;
    reg use_inv;
    
    // Modular Multiplication Function
    function automatic [31:0] mod_mul;
        input [31:0] a;
        input [31:0] b;
        begin
            mod_mul = (a * b) % MOD;
        end
    endfunction
    
    // Modular Addition Function
    function automatic [31:0] mod_add;
        input [31:0] a;
        input [31:0] b;
        reg [32:0] sum;
        begin
            sum = a + b;
            if (sum >= MOD)
                mod_add = sum - MOD;
            else
                mod_add = sum;
        end
    endfunction
    
    // Modular Inverse using Extended Euclidean Algorithm (simplified for small k)
    // Since k <= 255, we can compute iteratively
    // Returns inverse of a mod MOD, assumes MOD is prime and a < MOD
    function automatic [31:0] mod_inv;
        input [31:0] a;
        integer i;
        reg [31:0] t;
        reg [31:0] q;
        reg [31:0] r0, r1, r2;
        reg [31:0] t0, t1, t2;
        begin
            r0 = MOD;
            r1 = a;
            t0 = 32'd0;
            t1 = 32'd1;
            
            while (r1 > 32'd1) begin
                q = r0 / r1;
                r2 = r0 - q * r1;
                t2 = t0 - q * t1;
                
                r0 = r1;
                r1 = r2;
                t0 = t1;
                t1 = t2;
            end
            
            if (t1 < 0)
                t1 = t1 + MOD;
                
            mod_inv = t1;
        end
    endfunction
    
    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_K;
                else
                    next_state = IDLE;
            end
            INIT_K: begin
                next_state = CHECK_K;
            end
            CHECK_K: begin
                if (k > max_k)
                    next_state = FINISH;
                else if (valid_k)
                    next_state = COMPUTE_X;
                else
                    next_state = ACCUM;  // Skip invalid k
            end
            COMPUTE_X: begin
                // Wait for binomial calculation
                if (calc_step >= target_k)  // Calculation complete
                    next_state = COMPUTE_Y;
                else
                    next_state = COMPUTE_X;
            end
            COMPUTE_Y: begin
                // Wait for binomial calculation
                if (calc_step >= target_k)  // Calculation complete
                    next_state = ACCUM;
                else
                    next_state = COMPUTE_Y;
            end
            ACCUM: begin
                next_state = INIT_K;  // Next iteration
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k <= 8'd0;
            max_k <= 8'd0;
            comb_x <= 32'd0;
            comb_y <= 32'd0;
            current_val <= 32'd0;
            calc_step <= 8'd0;
            term_product <= 32'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end
                
                INIT_K: begin
                    // Initialize k to 1
                    k <= 8'd1;
                    // Calculate max_k = N / min(X, Y)
                    if (X < Y)
                        max_k <= N / X;
                    else
                        max_k <= N / Y;
                    // Initialize result accumulator
                    if (start) begin
                        result <= 32'd0;
                    end
                end
                
                CHECK_K: begin
                    // Check if k*X <= N and k*Y <= N
                    valid_k <= ((k * X) <= N) && ((k * Y) <= N);
                    // Prepare parameters for binomial calculation
                    n_x <= N - (k * X);
                    n_y <= N - (k * Y);
                    // For C(n + k - 1, k - 1), target is k - 1
                    target_k <= k - 8'd1;
                end
                
                COMPUTE_X: begin
                    if (calc_step < target_k) begin
                        // Iterative computation of C(n, k)
                        // Formula: C(n, k) = C(n, k-1) * (n - k + 1) / k
                        if (calc_step == 8'd0) begin
                            // Base case: C(n, 0) = 1
                            current_val <= 32'd1;
                        end else begin
                            // Multiply: current_val * (n - calc_step + 1)
                            mul_temp = current_val * (n_x - calc_step + 8'd1);
                            current_val <= mul_temp % MOD;
                            // Prepare for division by (calc_step + 1) in next cycle
                            // We need to compute inverse of (calc_step + 1)
                            current_k <= calc_step + 8'd1;
                        end
                        calc_step <= calc_step + 8'd1;
                    end else if (calc_step == target_k) begin
                        // Final division step (if target > 0)
                        if (target_k > 8'd0) begin
                            // Multiply by inverse of target_k
                            mul_temp = current_val * mod_inv(current_k);
                            current_val <= mul_temp % MOD;
                        end
                        // Store result
                        comb_x <= current_val;
                        // Reset calc_step for next computation
                        calc_step <= 8'd0;
                    end
                end
                
                COMPUTE_Y: begin
                    if (calc_step < target_k) begin
                        if (calc_step == 8'd0) begin
                            current_val <= 32'd1;
                        end else begin
                            mul_temp = current_val * (n_y - calc_step + 8'd1);
                            current_val <= mul_temp % MOD;
                            current_k <= calc_step + 8'd1;
                        end
                        calc_step <= calc_step + 8'd1;
                    end else if (calc_step == target_k) begin
                        if (target_k > 8'd0) begin
                            mul_temp = current_val * mod_inv(current_k);
                            current_val <= mul_temp % MOD;
                        end
                        comb_y <= current_val;
                        calc_step <= 8'd0;
                    end
                end
                
                ACCUM: begin
                    // Multiply comb_x * comb_y
                    term_product <= mod_mul(comb_x, comb_y);
                    // Add to result
                    result <= mod_add(result, term_product);
                    // Increment k
                    k <= k + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update state
            state <= next_state;
        end
    end
endmodule