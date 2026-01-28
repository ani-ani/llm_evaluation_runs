module max_lcm_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT        = 4'd1;
    localparam [3:0] LOOP_I      = 4'd2;
    localparam [3:0] LOOP_J      = 4'd3;
    localparam [3:0] LOOP_K      = 4'd4;
    localparam [3:0] GCD1_START  = 4'd5;
    localparam [3:0] GCD1_LOOP   = 4'd6;
    localparam [3:0] LCM1        = 4'd7;
    localparam [3:0] GCD2_START  = 4'd8;
    localparam [3:0] GCD2_LOOP   = 4'd9;
    localparam [3:0] LCM2        = 4'd10;
    localparam [3:0] UPDATE      = 4'd11;
    localparam [3:0] DONE_STATE  = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;
    reg [15:0] i_reg, j_reg, k_reg, search_start_reg;
    reg [31:0] max_lcm, current_lcm;
    reg [31:0] gcd_a, gcd_b, gcd_result;
    reg [31:0] mult_a, mult_b, mult_result;
    reg [15:0] divisor;
    reg [31:0] dividend;
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [15:0] gcd_counter;
    reg [31:0] cycle_counter;
    
    // Combinational outputs
    reg [3:0] next_state_comb;
    reg [15:0] i_next, j_next, k_next;
    reg [31:0] max_lcm_next, current_lcm_next;
    reg [31:0] gcd_a_next, gcd_b_next;
    reg [31:0] mult_a_next, mult_b_next;
    reg [15:0] divisor_next;
    reg [31:0] dividend_next;
    reg [31:0] quotient_next;
    reg [31:0] remainder_next;
    reg [15:0] gcd_counter_next;
    reg [31:0] cycle_counter_next;
    reg done_next;
    reg [31:0] result_next;
    
    // Edge case: n < 3
    wire [15:0] safe_n;
    assign safe_n = (n < 16'd3) ? 16'd3 : n;
    
    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 16'd0;
            j_reg <= 16'd0;
            k_reg <= 16'd0;
            search_start_reg <= 16'd0;
            max_lcm <= 32'd0;
            current_lcm <= 32'd0;
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            mult_a <= 32'd0;
            mult_b <= 32'd0;
            divisor <= 16'd0;
            dividend <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            gcd_counter <= 16'd0;
            cycle_counter <= 32'd0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state_comb;
            i_reg <= i_next;
            j_reg <= j_next;
            k_reg <= k_next;
            search_start_reg <= search_start_reg;
            max_lcm <= max_lcm_next;
            current_lcm <= current_lcm_next;
            gcd_a <= gcd_a_next;
            gcd_b <= gcd_b_next;
            mult_a <= mult_a_next;
            mult_b <= mult_b_next;
            divisor <= divisor_next;
            dividend <= dividend_next;
            quotient <= quotient_next;
            remainder <= remainder_next;
            gcd_counter <= gcd_counter_next;
            cycle_counter <= cycle_counter_next;
            done <= done_next;
            result <= result_next;
        end
    end
    
    // Combinational logic
    always @(*) begin
        // Default assignments
        next_state_comb = state;
        i_next = i_reg;
        j_next = j_reg;
        k_next = k_reg;
        max_lcm_next = max_lcm;
        current_lcm_next = current_lcm;
        gcd_a_next = gcd_a;
        gcd_b_next = gcd_b;
        mult_a_next = mult_a;
        mult_b_next = mult_b;
        divisor_next = divisor;
        dividend_next = dividend;
        quotient_next = quotient;
        remainder_next = remainder;
        gcd_counter_next = gcd_counter;
        cycle_counter_next = cycle_counter;
        done_next = done;
        result_next = result;
        
        case (state)
            IDLE: begin
                done_next = 1'b0;
                result_next = 32'd0;
                cycle_counter_next = 32'd0;
                if (start) begin
                    next_state_comb = INIT;
                end
            end
            
            INIT: begin
                // Compute search_start = max(n-63, 1)
                // Using safe_n to handle n < 3
                i_next = safe_n;
                if (safe_n > 16'd63) begin
                    search_start_reg = safe_n - 16'd63;
                end else begin
                    search_start_reg = 16'd1;
                end
                max_lcm_next = 32'd0;
                next_state_comb = LOOP_I;
            end
            
            LOOP_I: begin
                if (i_reg >= search_start_reg) begin
                    j_next = i_reg;
                    next_state_comb = LOOP_J;
                end else begin
                    next_state_comb = DONE_STATE;
                end
            end
            
            LOOP_J: begin
                if (j_reg >= search_start_reg) begin
                    k_next = j_reg;
                    next_state_comb = LOOP_K;
                end else begin
                    // Decrement i and go back
                    if (i_reg > search_start_reg) begin
                        i_next = i_reg - 16'd1;
                        next_state_comb = LOOP_I;
                    end else begin
                        next_state_comb = DONE_STATE;
                    end
                end
            end
            
            LOOP_K: begin
                if (k_reg >= search_start_reg) begin
                    // Pruning: if i*j*k < max_lcm, skip
                    // Check i*j*k < max_lcm
                    // Compute i*j first
                    mult_a_next = {16'd0, i_reg};
                    mult_b_next = {16'd0, j_reg};
                    next_state_comb = GCD1_START;
                end else begin
                    // Decrement j and go back
                    if (j_reg > search_start_reg) begin
                        j_next = j_reg - 16'd1;
                        next_state_comb = LOOP_J;
                    end else begin
                        // Done with this i
                        if (i_reg > search_start_reg) begin
                            i_next = i_reg - 16'd1;
                            next_state_comb = LOOP_I;
                        end else begin
                            next_state_comb = DONE_STATE;
                        end
                    end
                end
            end
            
            GCD1_START: begin
                // Start GCD(i, j)
                // Using 32-bit values
                gcd_a_next = {16'd0, i_reg};
                gcd_b_next = {16'd0, j_reg};
                gcd_counter_next = 16'd0;
                next_state_comb = GCD1_LOOP;
            end
            
            GCD1_LOOP: begin
                // Euclidean algorithm: gcd(a,b) where a >= b
                if (gcd_b_next == 32'd0) begin
                    // GCD complete
                    next_state_comb = LCM1;
                end else begin
                    // Check if we need swap or modulo
                    if (gcd_a_next >= gcd_b_next) begin
                        gcd_a_next = gcd_b_next;
                        gcd_b_next = gcd_a_next % gcd_b_next;
                    end else begin
                        // Swap
                        gcd_a_next = gcd_b_next;
                        gcd_b_next = gcd_a_next;
                    end
                    gcd_counter_next = gcd_counter + 16'd1;
                    if (gcd_counter >= 16'd32) begin
                        next_state_comb = LCM1; // Force exit
                    end
                end
            end
            
            LCM1: begin
                // LCM1 = (i * j) / GCD(i,j)
                // i*j is in mult_a * mult_b (32-bit each, but only lower 16 bits used)
                // Actually, i_reg and j_reg are 16-bit
                // We need 32-bit result: i*j / gcd_result
                // Compute i*j (32-bit) / gcd_result (32-bit)
                // Division by GCD which we computed
                // gcd_result is gcd_a after loop
                divisor_next = gcd_a[15:0]; // GCD is <= 16-bit
                dividend_next = mult_a * mult_b; // i*j
                quotient_next = 32'd0;
                remainder_next = dividend_next;
                next_state_comb = LCM2; // Skip separate division, compute directly
                // Actually, we need to compute LCM2 after this
                // Let's just compute LCM1 directly
                // LCM1 = dividend / divisor
                // Since divisor divides exactly, we can compute
                if (divisor_next != 0) begin
                    // Compute quotient = dividend / divisor
                    quotient_next = dividend_next / divisor_next;
                end else begin
                    quotient_next = 32'd0;
                end
                // Now compute LCM2 with k
                // We need to compute GCD(quotient, k)
                gcd_a_next = quotient_next;
                gcd_b_next = {16'd0, k_reg};
                gcd_counter_next = 16'd0;
                next_state_comb = GCD2_START;
            end
            
            GCD2_START: begin
                // Start GCD(LCM1, k)
                gcd_a_next = quotient_next;
                gcd_b_next = {16'd0, k_reg};
                gcd_counter_next = 16'd0;
                next_state_comb = GCD2_LOOP;
            end
            
            GCD2_LOOP: begin
                // Euclidean algorithm
                if (gcd_b_next == 32'd0) begin
                    next_state_comb = LCM2;
                end else begin
                    if (gcd_a_next >= gcd_b_next) begin
                        gcd_a_next = gcd_b_next;
                        gcd_b_next = gcd_a_next % gcd_b_next;
                    end else begin
                        gcd_a_next = gcd_b_next;
                        gcd_b_next = gcd_a_next;
                    end
                    gcd_counter_next = gcd_counter + 16'd1;
                    if (gcd_counter >= 16'd32) begin
                        next_state_comb = LCM2;
                    end
                end
            end
            
            LCM2: begin
                // LCM2 = LCM1 * k / GCD(LCM1, k)
                // LCM1 is in quotient (from LCM1 stage)
                // GCD(LCM1, k) is in gcd_a
                // Compute LCM1 * k
                // Need 64-bit intermediate
                // LCM1 * k can overflow 32-bit, use 64-bit
                // But result fits in 32-bit per spec
                // LCM1 is 32-bit, k is 16-bit -> 48-bit product
                // Divide by GCD (16-bit max)
                
                // Compute product LCM1 * k
                // Use 64-bit multiplication
                wire [63:0] temp_mult;
                assign temp_mult = quotient_next * {16'd0, k_reg};
                
                // Divide by GCD
                if (gcd_a[15:0] != 0) begin
                    // 64-bit / 16-bit division
                    current_lcm_next = temp_mult / gcd_a[15:0];
                end else begin
                    current_lcm_next = 32'd0;
                end
                
                next_state_comb = UPDATE;
            end
            
            UPDATE: begin
                // Update max_lcm if current_lcm > max_lcm
                if (current_lcm > max_lcm) begin
                    max_lcm_next = current_lcm;
                end
                
                // Move to next k
                if (k_reg > search_start_reg) begin
                    k_next = k_reg - 16'd1;
                    next_state_comb = LOOP_K;
                end else begin
                    // Decrement j
                    if (j_reg > search_start_reg) begin
                        j_next = j_reg - 16'd1;
                        next_state_comb = LOOP_J;
                    end else begin
                        // Done with this i
                        if (i_reg > search_start_reg) begin
                            i_next = i_reg - 16'd1;
                            next_state_comb = LOOP_I;
                        end else begin
                            next_state_comb = DONE_STATE;
                        end
                    end
                end
            end
            
            DONE_STATE: begin
                done_next = 1'b1;
                result_next = max_lcm;
                next_state_comb = IDLE;
            end
            
            default: begin
                next_state_comb = IDLE;
            end
        endcase
    end

endmodule