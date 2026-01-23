module triangular_index (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE      = 3'b000;
    localparam CALC_POW  = 3'b001;
    localparam CALC_SQRT = 3'b010;
    localparam ROUND     = 3'b011;
    localparam DONE      = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers for Q16.16 fixed-point arithmetic
    reg [31:0] val_reg;      // Stores 10^(n-1) or 2*10^(n-1)
    reg [31:0] x_reg;        // Newton-Raphson variable x
    reg [31:0] x_next;       // Next value for x
    reg [31:0] iter_cnt;     // Iteration counter

    // Helper variables
    reg [31:0] pow_temp;
    reg [31:0] sqrt_temp;
    reg [31:0] double_temp;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (n == 0 || n > 4) // Out of range check (optional, assumed 1-4 per prompt)
                        next_state = IDLE;
                    else
                        next_state = CALC_POW;
                end else begin
                    next_state = IDLE;
                end
            end
            CALC_POW: begin
                // 1 cycle to compute 10^(n-1)
                next_state = CALC_SQRT;
            end
            CALC_SQRT: begin
                // Fixed 16 cycles for Newton-Raphson iterations to ensure convergence
                if (iter_cnt < 16)
                    next_state = CALC_SQRT;
                else
                    next_state = ROUND;
            end
            ROUND: begin
                // 1 cycle to round and prepare result
                next_state = DONE;
            end
            DONE: begin
                // 1 cycle to assert done, then back to IDLE (or stay if start is still high)
                if (!start) 
                    next_state = IDLE;
                else 
                    next_state = DONE; // Wait for start to go low
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
            val_reg <= 32'd0;
            x_reg <= 32'd0;
            iter_cnt <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n >= 1 && n <= 4) begin
                        iter_cnt <= 32'd0;
                    end
                end

                CALC_POW: begin
                    // Compute target = 10^(n-1)
                    // n is small, we can use a lookup or simple shift logic.
                    // 10^(n-1): 1, 10, 100, 1000
                    // Stored in Q16.16 format (so 1.0 is 32'h0001_0000)
                    case (n)
                        8'd1: val_reg <= 32'h0001_0000; // 1.0
                        8'd2: val_reg <= 32'h000A_0000; // 10.0
                        8'd3: val_reg <= 32'h0064_0000; // 100.0
                        8'd4: val_reg <= 32'h03E8_0000; // 1000.0
                        default: val_reg <= 32'd0;
                    endcase
                    // Initialize Newton Raphson x_0 = 1.0 / sqrt(2) approx 0.707 -> 0x0000_B504
                    // Actually, standard method: let S = 2 * target. We want sqrt(S).
                    // Initial guess for sqrt(S): if we know range, we can pick better.
                    // Let's just use x0 = S/2 (very rough) or a constant.
                    // Let's use x0 = 0.5 (0x0000_8000) which works for scaling.
                    x_reg <= 32'h0000_8000; 
                    iter_cnt <= 32'd0;
                end

                CALC_SQRT: begin
                    // We are calculating sqrt(2 * 10^(n-1))
                    // Input is in val_reg. Let's double it first.
                    // Actually, let's refine the math:
                    // We want sqrt(2 * 10^(n-1)).
                    // Let S = 2 * target.
                    // Newton Raphson iteration: x_{n+1} = 0.5 * (x_n + S/x_n)
                    
                    // We need to handle S first. Let's compute S in the first iteration of this state or precompute.
                    // To save states, let's compute S during the first iteration of CALC_SQRT logic.
                    // However, val_reg currently holds target. Let's update val_reg to S immediately in this state logic.
                    
                    // Optimization: Inside the loop, we update x_reg.
                    // S is 2*target. Let's keep S in val_reg. But val_reg is currently target.
                    // Let's turn val_reg into S on the first entry to CALC_SQRT.
                    // But we are in the state machine loop. 
                    // Let's use iter_cnt to distinguish first setup from iterations.
                    
                    if (iter_cnt == 0) begin
                        // Convert val_reg (target) to S (2*target) for calculation
                        double_temp = val_reg << 1;
                        val_reg <= double_temp; // Now val_reg is S (2*10^(n-1))
                        
                        // First iteration: x1 = 0.5 * (x0 + S/x0)
                        // x0 is in x_reg (0x0000_8000 = 0.5)
                        // Need division: S / x0. 
                        // Since x0 = 0.5, S / 0.5 = 2*S = 4*target. This is huge. 
                        // Better initial guess: 
                        // Since sqrt(2*1000) approx 45. S approx 2000.
                        // Initial guess x0 = 40 (0x0028_0000) or 60 (0x003C_0000).
                        // Let's use x0 = 0x0000_8000 (0.5) for generic N-R, but we need to scale inputs.
                        // Wait, if inputs are Q16.16, 0.5 is 0x0000_8000. 
                        // S is 2000 (0x007D_0000). 
                        // Division 2000 / 0.5 = 4000. 
                        // This is valid Q16.16 arithmetic. 
                        // But N-R converges to sqrt(S). If x0 is small, x1 becomes large.
                        // Let's just start the iteration.
                        
                        // Optimization: Let's pick a better initial guess to save iterations.
                        // For n=4, S=2000. sqrt(2000)=44.7.
                        // Let's initialize x_reg based on n.
                        case (n)
                            8'd1: x_reg <= 32'h0001_0000; // 1.0
                            8'd2: x_reg <= 32'h0004_0000; // 4.0
                            8'd3: x_reg <= 32'h000E_0000; // 14.0
                            8'd4: x_reg <= 32'h002D_0000; // 45.0
                            default: x_reg <= 32'h0001_0000;
                        endcase
                        // Note: We update iter_cnt only at the end, so this logic repeats?
                        // No, if state is CALC_SQRT and iter_cnt is 0, we do setup.
                        // We need to increment iter_cnt. 
                        // Actually, the loop logic below handles the calculation.
                        // We should do the first calculation here if we set x_reg.
                        // But the prompt asked for Newton Raphson. 
                        // Let's simplify: Use a precomputed lookup for n<=4 as hinted.
                        // "Square root can be approximated using bit-by-bit method or stored results for n=1-4"
                        // Let's implement the bit-by-bit method (restoring) to be generic and efficient.
                        // OR, given the strict 50 cycle latency and small n, a lookup is robust.
                        // But to be educational and follow "Newton-Raphson", let's do it.
                        // Wait, the prompt says "Compute result = round(sqrt(2 * 10^(n-1)))".
                        // The values are: 1, 4, 14, 45.
                        // Let's just use a Lookup Table (LUT) logic since n is 1-4.
                        // It is the most area and power efficient for this specific case.
                        // It takes 0 logic for calculation, 1 cycle for lookup.
                        // However, I will stick to a generic approach that works if n expands slightly.
                        // Let's use the bit-by-bit (non-restoring) square root algorithm.
                        // It takes ~16 cycles for 32-bit numbers.
                    end

                    // Actually, for a robust synthesizable module that doesn't rely on DSPs for div/sqrt,
                    // the bit-by-bit method is standard. Let's implement that.
                    // But wait, the state `CALC_SQRT` was intended for iterative solving.
                    // Let's swap to a Bit-by-Bit Sqrt implementation logic here.
                    // Algorithm:
                    // A = Input (2 * 10^(n-1)). R = Result. 
                    // Iterate 16 times (for 32-bit precision).
                    // R <<= 1. Check if A >= (R << 1) + 1. 
                    // If yes, A = A - ((R << 1) + 1); R += 1.
                    // Let's manage this within the CALC_SQRT state.
                    
                    // Setup on first iteration (iter_cnt == 0)
                    if (iter_cnt == 0) begin
                        // Prepare A: 2 * 10^(n-1). Val_reg currently has target (10^(n-1)).
                        // Multiply by 2.
                        val_reg <= {val_reg[30:0], 1'b0}; // val_reg = S
                        // Initialize R (result) = 0
                        result <= 16'd0; // Use lower part of result register temporarily
                        // We need a temp register for A (accumulator).
                        // Let's use x_reg to store the remainder A.
                        x_reg <= {val_reg[30:0], 1'b0}; // x_reg holds Remainder (A)
                        // Result is stored in lower 16 bits of 'result' temporarily, or another reg.
                        // Let's use a dedicated temp register for the Root.
                        // Reusing 'val_reg' to hold the Root during calculation.
                        val_reg <= 32'd0; // Root = 0
                    end else begin
                        // Standard Non-restoring Square Root Step
                        // 1. Shift Root (val_reg) and Remainder (x_reg) left by 1
                        val_reg <= {val_reg[30:0], 1'b0};
                        x_reg <= {x_reg[30:0], 1'b0};
                        
                        // 2. Check condition (calculated on the shifted values for this cycle)
                        // Temporarily calculate: Root_new = val_reg[31:0]<<1 | 1
                        // We can do this by checking the LSB of the shifted val_reg (which is 0) and adding 1.
                        // Effectively: If x_reg >= (val_reg << 1) + 1 ... wait, we already shifted.
                        // Let's use the classic algorithm:
                        // R = R << 1
                        // A = A << 1
                        // If A >= R + 1 (using updated R and A):
                        //    A = A - (R + 1)
                        //    R = R + 1
                        // Here, R is val_reg. A is x_reg.
                        
                        // We need to check if x_reg >= (val_reg + 1) ??? 
                        // No. R is being shifted. 
                        // Let's calculate 'R + 1' using a wire.
                        // Actually, since val_reg was shifted left, its LSB is 0.
                        // So val_reg + 1 sets LSB to 1.
                        // We compare x_reg against val_reg + 1.
                        
                        if (x_reg >= (val_reg + 1)) begin
                            x_reg <= x_reg - (val_reg + 1);
                            val_reg <= val_reg + 1; // Set the bit in Root
                        end
                        // If not, val_reg remains shifted left (LSB 0), x_reg remains shifted left.
                    end
                    
                    iter_cnt <= iter_cnt + 1;
                end

                ROUND: begin
                    // val_reg holds the Q16.16 square root result.
                    // We need to round to nearest integer.
                    // Integer part is val_reg[31:16].
                    // Fraction part is val_reg[15:0].
                    // If Fraction >= 0x8000, add 1 to Integer.
                    // val_reg is 32-bit. Root is usually small (max 45 for n=4).
                    // Let's perform the rounding.
                    if (val_reg[15]) begin
                        result <= val_reg[31:16] + 1;
                    end else begin
                        result <= val_reg[31:16];
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
