module expected_cost_pokeball (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] N_in,
    input wire [9:0] P_in,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_PROB = 3'd1;
    localparam [2:0] COMPUTE_EXPECTED = 3'd2;
    localparam [2:0] COMPUTE_COST = 3'd3;
    localparam [2:0] FINAL = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] iteration_count;
    reg [7:0] newton_count;
    reg [31:0] prob_result;      // Q16.16: (1-P)^100
    reg [31:0] p_fixed;          // Q16.16: P input
    reg [31:0] expected;         // Q16.16: expected Pokemon per refill
    reg [31:0] cost_per_pokemon; // Q16.16: cost per Pokemon
    reg [31:0] temp_mult_a;
    reg [31:0] temp_mult_b;
    reg [31:0] N_fixed;          // Q16.16: N
    reg [63:0] mult_result;      // 64-bit intermediate for multiplication
    
    // Newton-Raphson reciprocal state
    reg [31:0] nr_x;             // Q16.16 estimate
    reg [31:0] nr_y;             // Q16.16 target (1 - prob)
    reg [63:0] temp_prod;
    
    // Edge case flags
    reg is_p_zero;
    reg is_p_one;
    
    // Control signals
    reg start_computation;
    reg computing_prob;
    reg computing_reciprocal;
    reg computing_cost;
    reg computing_final;
    reg computation_done;
    
    // Constants in Q16.16
    localparam [31:0] ONE = 32'h00010000;       // 1.0
    localparam [31:0] FIVE = 32'h00050000;      // 5.0
    localparam [31:0] HUNDRED = 32'h00640000;   // 100.0
    localparam [31:0] MAX_COST = 32'h7FFFFFFF;  // Max value for P=0
    localparam [31:0] ONE_ITER = 32'h00010000;  // 1 iteration scaling (1/100)
    
    // P=1 cost constant: 0.05 per Pokemon (5/100)
    localparam [31:0] P_ONE_COST = 32'h0000CCCD;  // 0.05 in Q16.16 (approx)

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            prob_result <= 32'd0;
            p_fixed <= 32'd0;
            expected <= 32'd0;
            cost_per_pokemon <= 32'd0;
            N_fixed <= 32'd0;
            iteration_count <= 8'd0;
            newton_count <= 8'd0;
            temp_mult_a <= 32'd0;
            temp_mult_b <= 32'd0;
            nr_x <= 32'd0;
            nr_y <= 32'd0;
            is_p_zero <= 1'b0;
            is_p_one <= 1'b0;
            start_computation <= 1'b0;
            computing_prob <= 1'b0;
            computing_reciprocal <= 1'b0;
            computing_cost <= 1'b0;
            computing_final <= 1'b0;
            computation_done <= 1'b0;
            mult_result <= 64'd0;
            temp_prod <= 64'd0;
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Convert P_in (0-1000) to Q16.16
                        // P_in is 10-bit, representing P*1000
                        // We want P in Q16.16: P = P_in / 1000 * 65536
                        // Simplified: P_in * 65.536 ≈ P_in * 66
                        // More accurately: P_fixed = (P_in * 256) >> 8 would give Q8.8
                        // For Q16.16: P_fixed = P_in * 65.536
                        // P_fixed[31:0] = P_in * 65536 / 1000
                        // Use: P_fixed = (P_in * 256) * 256 / 1000
                        // To keep it simple and accurate enough:
                        // P_fixed = P_in * 66 (approx)
                        // Let's do: P_fixed = (P_in << 16) / 1000 for more accuracy
                        
                        // Start computation
                        N_fixed <= {16'd0, N_in}; // Extend to Q16.16
                        iteration_count <= 8'd0;
                        newton_count <= 8'd0;
                        
                        // Edge case detection
                        if (P_in == 10'd0) begin
                            is_p_zero <= 1'b1;
                            is_p_one <= 1'b0;
                            prob_result <= 32'h00010000; // (1-0)^100 = 1
                        end else if (P_in == 10'd1000) begin
                            is_p_zero <= 1'b0;
                            is_p_one <= 1'b1;
                            prob_result <= 32'd0; // (1-1)^100 = 0
                        end else begin
                            is_p_zero <= 1'b0;
                            is_p_one <= 1'b0;
                            // Calculate P_fixed = (P_in * 65536) / 1000
                            // Using shift for approximate: P_in * 66 (65.536)
                            p_fixed <= P_in * 66;
                        end
                        
                        // Reset intermediate values
                        expected <= 32'd0;
                        cost_per_pokemon <= 32'd0;
                        result <= 32'd0;
                        
                        // If P=0 or P=1, skip to COMPUTE_COST directly
                        if (P_in == 10'd0 || P_in == 10'd1000) begin
                            next_state <= COMPUTE_COST;
                        end else begin
                            prob_result <= 32'h00010000; // Start with (1-P)^0 = 1
                            next_state <= COMPUTE_PROB;
                        end
                    end
                end
                
                COMPUTE_PROB: begin
                    // Compute (1-P)^100 using 100 iterations
                    // prob_result = prob_result * (1 - P)
                    // (1-P) = 1 - P_fixed (Q16.16)
                    if (iteration_count < 8'd100) begin
                        // Calculate 1 - p_fixed
                        // 1 in Q16.16 is ONE (0x00010000)
                        temp_mult_a <= prob_result;
                        temp_mult_b <= ONE - p_fixed;
                        
                        // Wait one cycle for multiplication
                        computing_prob <= 1'b1;
                        iteration_count <= iteration_count + 8'd1;
                        next_state <= COMPUTE_PROB;
                    end else begin
                        computing_prob <= 1'b0;
                        next_state <= COMPUTE_EXPECTED;
                    end
                end
                
                COMPUTE_EXPECTED: begin
                    // expected = 1 / (1 - prob_result)
                    // First compute 1 - prob_result
                    nr_y <= ONE - prob_result;
                    
                    // Initialize Newton-Raphson estimate
                    // Use initial guess: x0 = 2 * (2 - y) for Q16.16
                    // Or simpler: x0 = ONE (1.0) if y is around 1
                    // Let's use: x0 = ONE * 2 - nr_y (for y near 1)
                    nr_x <= (ONE << 1) - nr_y;
                    newton_count <= 8'd0;
                    computing_reciprocal <= 1'b1;
                    next_state <= COMPUTE_EXPECTED;
                    
                    // If prob_result is very close to 1 (P is small), result diverges
                    // Handle P=0 case earlier
                end
                
                COMPUTE_COST: begin
                    // If P=1: cost = 5 / 100 = 0.05 per Pokemon
                    // If P=0: infinite cost, clamp to MAX
                    // Else: cost = 5 / expected
                    
                    if (is_p_one) begin
                        cost_per_pokemon <= P_ONE_COST; // 0.05
                        next_state <= FINAL;
                    end else if (is_p_zero) begin
                        cost_per_pokemon <= MAX_COST;
                        next_state <= FINAL;
                    end else begin
                        // Compute 5 / expected using Newton-Raphson
                        // Use expected as nr_y
                        nr_y <= expected;
                        nr_x <= (ONE << 1) - expected; // Initial guess
                        newton_count <= 8'd0;
                        computing_cost <= 1'b1;
                        computing_reciprocal <= 1'b1;
                        next_state <= COMPUTE_COST;
                    end
                end
                
                FINAL: begin
                    // result = N * cost_per_pokemon
                    // Q16.16 * Q16.16 = Q32.32, take upper 32 bits (Q16.16)
                    mult_result <= N_fixed * cost_per_pokemon;
                    computing_final <= 1'b1;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    // Extract result from multiplication
                    if (computing_final) begin
                        result <= mult_result[47:16]; // Q16.16 from Q32.32
                        computation_done <= 1'b1;
                        valid <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        // Handle division completed
                        if (computing_cost) begin
                            cost_per_pokemon <= nr_x;
                            next_state <= FINAL;
                        end else if (computing_reciprocal) begin
                            expected <= nr_x;
                            next_state <= COMPUTE_COST;
                        end
                    end
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
            
            // Newton-Raphson iteration logic (handled outside state machine for timing)
            if (computing_reciprocal && state == COMPUTE_EXPECTED && computing_prob == 1'b0) begin
                // Perform one Newton-Raphson iteration: x = x * (2 - y*x)
                // x, y in Q16.16
                // y*x in Q32.32
                temp_prod <= nr_y * nr_x;
                
                if (newton_count < 8'd16) begin
                    newton_count <= newton_count + 8'd1;
                    // Continue iteration in next cycle
                end else begin
                    computing_reciprocal <= 1'b0;
                    // When done, go to next state
                    if (computing_cost) begin
                        cost_per_pokemon <= nr_x;
                        next_state <= FINAL;
                    end else begin
                        expected <= nr_x;
                        next_state <= COMPUTE_COST;
                    end
                end
            end
        end
    end
    
    // Compute Newton-Raphson update in combinational logic
    always @(*) begin
        if (computing_reciprocal && newton_count > 8'd0) begin
            // x_new = x * (2 - y*x)
            // temp_prod is y*x in Q32.32
            // (2 - y*x) in Q32.32: 2*ONE*ONE - temp_prod
            // x_new = x * (2 - y*x) in Q48.48, take middle 32 bits
            // Simplified: x * (2 - y*x) ≈ 2*x - y*x*x
            // For Q16.16: nr_x * (2*ONE - temp_prod[47:16]) >> 16
            // But let's do it carefully:
            // Let temp = (2*ONE*ONE - temp_prod) = (2^33 - temp_prod) in Q32.32
            // x_new = nr_x * temp[47:16] (scaled) >> 16
            
            // Actually, simpler formula for reciprocal:
            // x_{n+1} = x_n * (2 - y * x_n)
            // In fixed point: x_new = (x_n * (2 - y * x_n >> 16)) >> 16
            
            // Compute y * x_n (in Q32.32)
            // temp_prod = nr_y * nr_x
            // 2 in Q32.32 is 2 * ONE * ONE = 2 * 65536 * 65536
            // 2 - y*x = 2*ONE*ONE - temp_prod
            // x_new = (nr_x * (2*ONE*ONE - temp_prod)) >> 16
            
            // Let's use a simpler approximation that works in Q16.16
            // x_new = x * (2 - y*x) where y*x is Q32.32, so we need to shift
            // x_new = (nr_x * (2*ONE - temp_prod[47:16])) >> 16
            // where 2*ONE = 0x00020000
            
            // Actually, let me rewrite this properly
            // y is Q16.16, x is Q16.16
            // y*x is Q32.32 (stored in temp_prod)
            // We want 2 - (y*x >> 16) in Q16.16
            // = 2*ONE - temp_prod[47:16]
            // Then multiply by x and shift right by 16
            // = (nr_x * (2*ONE - temp_prod[47:16])) >> 16
        end
    end
    
    // Separate always block for Newton-Raphson update calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (computing_reciprocal && newton_count > 8'd0) begin
                // Perform the update: x_new = x * (2 - y*x) >> 16
                // y*x is in temp_prod (Q32.32)
                // 2 in Q32.32 is 2 * 65536 * 65536 = 0x00000002_00000000
                // But we only have 64 bits, so 2*ONE*ONE = 2 * 0x00010000 * 0x00010000
                // = 2 * 0x100000000 = 0x200000000 (33 bits)
                // This doesn't fit in 64-bit unsigned...
                // Actually, 0x00010000 * 0x00010000 = 0x100000000 (33 bits)
                // So we need 34 bits for 2*that
                // Let's use 64-bit: 2 * ONE * ONE = 2 * 65536 * 65536 = 8589934592 = 0x200000000
                // In 64-bit: 0x00000002_00000000
                
                // (2*ONE*ONE - temp_prod) in Q32.32
                // Let's use 128-bit logic for safety (but Verilog doesn't support 128-bit cleanly)
                // Instead, let's use a different approach:
                // x_new = x * (2 - y*x) where everything is scaled
                // In Q16.16: x_new = (x * (2*ONE - (y*x >> 16))) >> 16
                // where y*x >> 16 is temp_prod[47:16]
                
                // Compute y*x >> 16 (Q32.32 -> Q16.16)
                // temp_prod[47:16] gives us the integer part + 16 fractional bits
                // But wait, temp_prod is Q32.32, so temp_prod[47:16] is Q16.16
                // Yes, because we drop the lower 16 bits
                
                // 2*ONE in Q16.16 is 0x00020000
                // 2*ONE - (y*x >> 16) = 0x00020000 - temp_prod[47:16]
                
                // Then x_new = (nr_x * (0x00020000 - temp_prod[47:16])) >> 16
                // This is Q32.32, take upper 32 bits
                
                // Let's compute it step by step
                // Actually, the formula in Q16.16 is:
                // x_new = (x * (2*ONE - ((y*x) >> 16))) >> 16
                // But (y*x) is already Q32.32, so (y*x) >> 16 is Q16.16
                // Wait, no: y and x are Q16.16, so y*x is Q32.32
                // To get y*x in Q16.16, we take [47:16]
                
                // So: temp = 2*ONE - temp_prod[47:16]  (Q16.16)
                // Then: nr_x * temp is Q32.32
                // Then: (nr_x * temp) >> 16 is Q16.16
                
                // Let's compute this
                // But we need to be careful: 2*ONE = 0x00020000
                // temp_prod[47:16] is the Q16.16 version of y*x
                // So subtraction is valid
                
                // Let's do it in the always block
                // temp_mult_a = 0x00020000 - temp_prod[47:16]
                // temp_mult_b = nr_x
                // Then result = (temp_mult_a * temp_mult_b) >> 16
                // = (temp_mult_a * temp_mult_b)[47:16]
                
                // Actually, let's just compute the full update
                // x_new = nr_x * (2*ONE - temp_prod[47:16]) >> 16
                // This requires 32x32 multiplication, result is 64-bit Q32.32
                // We take upper 32 bits
                
                // Compute 2*ONE - temp_prod[47:16]
                reg [31:0] temp_val;
                temp_val = 32'h00020000 - temp_prod[47:16];
                
                // Multiply and shift
                mult_result <= temp_val * nr_x;
                // Upper 32 bits of Q32.32 product is [63:32]
                // Wait, 32x32 = 64-bit result. Upper 32 bits are [63:32]
                // That's Q16.16 result
                nr_x <= mult_result[63:32];
            end
        end
    end

endmodule