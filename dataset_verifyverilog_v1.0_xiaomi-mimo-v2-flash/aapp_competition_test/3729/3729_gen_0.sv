module SnowProbabilty (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] f_in,
    input wire [3:0] w_in,
    input wire [3:0] h_in,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MOD_MINUS_ONE = 32'd1000000006;
    
    // States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CALC_TOTAL  = 3'd1;
    localparam [2:0] CALC_VALID  = 3'd2;
    localparam [2:0] MODULAR_INV = 3'd3;
    localparam [2:0] COMPUTE_RES = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Input storage
    reg [3:0] f_reg;
    reg [3:0] w_reg;
    reg [3:0] h_reg;
    
    // Computation registers
    reg [31:0] total_count;
    reg [31:0] valid_count;
    reg [31:0] inv_total;
    
    // Loop counters
    reg [3:0] k;            // Number of stacks (1 to f+w)
    reg [4:0] n_val;        // For nCr calculation (n choose r)
    reg [4:0] r_val;
    reg [31:0] nCr_result;
    reg [31:0] temp_result;
    reg [7:0] loop_counter; // Generic loop counter
    
    // Modular exponentiation registers (for Fermat's little theorem)
    reg [31:0] exp_base;
    reg [31:0] exp_power;
    reg [31:0] exp_result;
    reg exp_done;
    
    // Helper signals
    reg [31:0] nCr_n;
    reg [31:0] nCr_r;
    reg nCr_valid;
    reg nCr_busy;
    
    // Sequential logic for state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            f_reg <= 4'd0;
            w_reg <= 4'd0;
            h_reg <= 4'd0;
            total_count <= 32'd0;
            valid_count <= 32'd0;
            inv_total <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            k <= 4'd0;
            n_val <= 5'd0;
            r_val <= 5'd0;
            nCr_result <= 32'd0;
            temp_result <= 32'd0;
            loop_counter <= 8'd0;
            exp_base <= 32'd0;
            exp_power <= 32'd0;
            exp_result <= 32'd0;
            exp_done <= 1'b0;
            nCr_n <= 32'd0;
            nCr_r <= 32'd0;
            nCr_valid <= 1'b0;
            nCr_busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        f_reg <= f_in;
                        w_reg <= w_in;
                        h_reg <= h_in;
                        total_count <= 32'd0;
                        valid_count <= 32'd0;
                        inv_total <= 32'd0;
                        result <= 32'd0;
                        k <= 4'd1;
                        state <= CALC_TOTAL;
                    end
                end
                
                CALC_TOTAL: begin
                    // Calculate total arrangements: Sum over k=1 to f+w of C(f+w-1, k-1)
                    // Valid only if f+w >= 1
                    if (f_reg + w_reg == 4'd0) begin
                        // No items, 0 arrangements
                        total_count <= 32'd0;
                        // Check if we should go to DONE or VALID calculation
                        // If w=0, probability is 1, so we handle specially
                        if (w_reg == 4'd0) begin
                            state <= DONE_STATE;
                            result <= 32'd1;
                        end else begin
                            state <= CALC_VALID;
                        end
                        k <= 4'd0; // No valid k
                    end else begin
                        if (!nCr_busy && k <= (f_reg + w_reg)) begin
                            nCr_n <= f_reg + w_reg - 4'd1;
                            nCr_r <= k - 4'd1;
                            nCr_valid <= 1'b1;
                            nCr_busy <= 1'b1;
                            temp_result <= 32'd0;
                        end else if (nCr_valid && !nCr_busy) begin
                            // nCr result is ready in nCr_result
                            total_count <= (total_count + nCr_result) % MOD;
                            k <= k + 4'd1;
                            nCr_valid <= 1'b0;
                            if (k > (f_reg + w_reg)) begin
                                // Done with total calculation
                                if (w_reg == 4'd0) begin
                                    // If no wine, probability is 1
                                    state <= DONE_STATE;
                                    result <= 32'd1;
                                end else begin
                                    state <= CALC_VALID;
                                    k <= 4'd1;
                                end
                            end
                        end
                    end
                end
                
                CALC_VALID: begin
                    // Calculate valid arrangements where wine stacks > h
                    // Condition: w > k*(h+1) => w - k*(h+1) >= 0
                    // If true: C(w - k*(h+1) + k - 1, k - 1)
                    // If false: contribution is 0
                    
                    if (k <= (f_reg + w_reg)) begin
                        // Check if wine constraint is possible
                        if (w_reg > k * (h_reg + 4'd1)) begin
                            if (!nCr_busy) begin
                                // Calculate n = w - k*(h+1) + k - 1 = w - k*h - 1
                                // We need to ensure n >= 0
                                // r = k - 1
                                nCr_n <= w_reg - (k * h_reg) - 4'd1;
                                nCr_r <= k - 4'd1;
                                nCr_valid <= 1'b1;
                                nCr_busy <= 1'b1;
                            end else if (nCr_valid && !nCr_busy) begin
                                valid_count <= (valid_count + nCr_result) % MOD;
                                k <= k + 4'd1;
                                nCr_valid <= 1'b0;
                            end
                        end else begin
                            // Constraint not met, skip to next k
                            k <= k + 4'd1;
                        end
                    end else begin
                        // Done with valid calculation
                        if (total_count == 32'd0) begin
                            // Division by zero - shouldn't happen if valid > 0
                            // Return 0 or 1 depending on edge cases
                            if (valid_count == 32'd0) begin
                                // 0/0 case, undefined, return 0
                                state <= DONE_STATE;
                                result <= 32'd0;
                            end else begin
                                // total = 0 but valid > 0, error case
                                state <= DONE_STATE;
                                result <= 32'd0;
                            end
                        end else begin
                            // Compute modular inverse of total_count
                            exp_base <= total_count;
                            exp_power <= MOD_MINUS_ONE;
                            exp_result <= 32'd1;
                            exp_done <= 1'b0;
                            loop_counter <= 8'd0;
                            state <= MODULAR_INV;
                        end
                    end
                end
                
                MODULAR_INV: begin
                    // Fermat's little theorem: a^(MOD-2) mod MOD
                    // Exponentiation by squaring
                    if (!exp_done) begin
                        if (loop_counter < 30) begin // 30 bits for MOD-1
                            if (exp_power[0]) begin
                                exp_result <= (exp_result * exp_base) % MOD;
                            end
                            exp_base <= (exp_base * exp_base) % MOD;
                            exp_power <= exp_power >> 1;
                            loop_counter <= loop_counter + 8'd1;
                        end else begin
                            exp_done <= 1'b1;
                            inv_total <= exp_result;
                        end
                    end else begin
                        state <= COMPUTE_RES;
                    end
                end
                
                COMPUTE_RES: begin
                    // result = (valid_count * inv_total) % MOD
                    result <= (valid_count * inv_total) % MOD;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Handle nCr calculation (combinatorial logic simulation)
            if (nCr_valid && !nCr_busy) begin
                nCr_busy <= 1'b0;
            end else if (nCr_valid && nCr_busy) begin
                // Compute nCr using iterative multiplication
                // C(n, r) = n*(n-1)*...*(n-r+1) / r*(r-1)*...*1
                // For small numbers (n <= 31), we can compute sequentially
                
                if (nCr_n < nCr_r) begin
                    nCr_result <= 32'd0;
                    nCr_busy <= 1'b0;
                end else begin
                    // Special cases
                    if (nCr_r == 32'd0 || nCr_r > nCr_n) begin
                        nCr_result <= 32'd1;
                        nCr_busy <= 1'b0;
                    end else begin
                        // Iterative computation
                        // Simplified for small n (<=31):
                        // We use a lookup or simple calculation
                        case ({nCr_n, nCr_r})
                            // nCr for n <= 15, r <= 15
                            // This is a simplified implementation
                            // For exact calculation, we use a small multiplier
                            default: begin
                                // Generic calculation using loop
                                if (loop_counter < 16) begin
                                    // Implement simple nCr calculation logic
                                    // For this specific problem with n <= 15, r <= 15
                                    // We can use a series of multiplications and divisions
                                    // To avoid complex logic, we'll use a pre-computed approach
                                    // or simplified iterative formula
                                    
                                    // Reset calculation
                                    if (loop_counter == 8'd0) begin
                                        temp_result <= 32'd1;
                                        nCr_busy <= 1'b1;
                                        loop_counter <= 8'd1;
                                    end else if (loop_counter <= nCr_r) begin
                                        // temp_result = temp_result * (n - r + loop_counter) / loop_counter
                                        // But division is hard in sequential logic
                                        // We use the recurrence: C(n, k) = C(n, k-1) * (n - k + 1) / k
                                        // For small k, we can unroll or use pipelined division
                                        
                                        // Simplified: use multiplication only, handle division by small constants
                                        // This is a hardware approximation for small values
                                        
                                        // For the specific case where nCr is small
                                        // We use a direct computation method
                                        // Since max n = 15, r = 15, we can pre-compute or use binary search
                                        
                                        // Using a hardcoded calculation for small nCr
                                        // This is acceptable for n <= 16
                                        case ({nCr_n, nCr_r})
                                            9'd0: nCr_result <= 32'd1; // 0C0
                                            9'd1: nCr_result <= 32'd0; // 0C1 (invalid)
                                            9'd2: nCr_result <= 32'd1; // 1C0
                                            9'd3: nCr_result <= 32'd1; // 1C1
                                            9'd4: nCr_result <= 32'd1; // 2C0
                                            9'd5: nCr_result <= 32'd2; // 2C1
                                            9'd6: nCr_result <= 32'd1; // 2C2
                                            9'd7: nCr_result <= 32'd1; // 3C0
                                            9'd8: nCr_result <= 32'd3; // 3C1
                                            9'd9: nCr_result <= 32'd3; // 3C2
                                            9'd10: nCr_result <= 32'd1; // 3C3
                                            9'd11: nCr_result <= 32'd1; // 4C0
                                            9'd12: nCr_result <= 32'd4; // 4C1
                                            9'd13: nCr_result <= 32'd6; // 4C2
                                            9'd14: nCr_result <= 32'd4; // 4C3
                                            9'd15: nCr_result <= 32'd1; // 4C4
                                            9'd16: nCr_result <= 32'd1; // 5C0
                                            9'd17: nCr_result <= 32'd5; // 5C1
                                            9'd18: nCr_result <= 32'd10; // 5C2
                                            9'd19: nCr_result <= 32'd10; // 5C3
                                            9'd20: nCr_result <= 32'd5; // 5C4
                                            9'd21: nCr_result <= 32'd1; // 5C5
                                            // ... up to 15C15 would be too many cases
                                            // Use generic calculation for larger values
                                            default: begin
                                                // Generic iterative multiplication for nCr
                                                // This uses sequential multiplies and divides
                                                if (loop_counter == 8'd1) begin
                                                    temp_result <= nCr_n;
                                                    loop_counter <= 8'd2;
                                                end else if (loop_counter <= nCr_r) begin
                                                    // Multiply by (n - k + 1)
                                                    temp_result <= (temp_result * (nCr_n - nCr_r + loop_counter)) % MOD;
                                                    // Division by k is trickier
                                                    // For small k, we can use modular inverse of k
                                                    // But k is small (<=15), so we precompute inverses
                                                    case (loop_counter)
                                                        8'd2: temp_result <= (temp_result * 32'd500000004) % MOD; // Inv of 2
                                                        8'd3: temp_result <= (temp_result * 32'd333333336) % MOD; // Inv of 3
                                                        8'd4: temp_result <= (temp_result * 250000002) % MOD; // Inv of 4
                                                        8'd5: temp_result <= (temp_result * 400000003) % MOD; // Inv of 5
                                                        8'd6: temp_result <= (temp_result * 166666668) % MOD; // Inv of 6
                                                        8'd7: temp_result <= (temp_result * 142857144) % MOD; // Inv of 7
                                                        8'd8: temp_result <= (temp_result * 125000001) % MOD; // Inv of 8
                                                        8'd9: temp_result <= (temp_result * 111111112) % MOD; // Inv of 9
                                                        8'd10: temp_result <= (temp_result * 100000001) % MOD; // Inv of 10
                                                        default: temp_result <= 32'd1;
                                                    endcase
                                                    loop_counter <= loop_counter + 8'd1;
                                                end else begin
                                                    nCr_result <= temp_result;
                                                    nCr_busy <= 1'b0;
                                                end
                                            end
                                        endcase
                                    end else begin
                                        nCr_busy <= 1'b0;
                                    end
                                end else begin
                                    nCr_busy <= 1'b0;
                                end
                            end
                        endcase
                    end
                end
            end
        end
    end

endmodule