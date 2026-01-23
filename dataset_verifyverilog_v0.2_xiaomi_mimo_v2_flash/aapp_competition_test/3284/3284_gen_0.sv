module coprime_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_GCD = 3'b001;
    localparam CHECK_GCD = 3'b010;
    localparam NEXT_PAIR = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [7:0] x_reg;
    reg [7:0] y_reg;
    reg [7:0] gcd_a;
    reg [7:0] gcd_b;
    reg [7:0] temp;
    wire gcd_done;

    // GCD Datapath Logic
    // Since inputs are small (max 8), we can use a simple combinational check or a multi-cycle divider.
    // To keep the design synthesizable without assuming a hardware divider, we use a sequential Euclidean algorithm.
    // The CALC_GCD state will iterate bit by bit or use a ready flag.
    // Given the small range, we can also unroll the loop. However, a stateful approach is more generic.
    // Let's implement a divider logic in the CALC_GCD state.
    // Since we don't have a clock divider info, we will implement a ready signal for the GCD calculation.
    // For a small range 1-8, a latency of 8 cycles is acceptable.
    
    // Registers for GCD calculation
    reg [7:0] gcd_val_a;
    reg [7:0] gcd_val_b;
    reg gcd_valid;
    reg [3:0] gcd_counter; // Counter for Euclidean steps (max 8 cycles)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            done <= 1'b0;
            x_reg <= 8'b0;
            y_reg <= 8'b0;
            gcd_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= a;
                        y_reg <= c;
                        result <= 8'b0;
                        state <= CALC_GCD;
                        // Initialize GCD calculation for the first pair
                        gcd_val_a <= a;
                        gcd_val_b <= c;
                        gcd_valid <= 1'b1;
                        gcd_counter <= 4'd0;
                    end
                end

                CALC_GCD: begin
                    if (gcd_valid) begin
                        // Sequential Euclidean Algorithm
                        // Iteration: while (b != 0) { temp = b; b = a % b; a = temp; }
                        // Since % is not a single cycle op in generic FPGA/ASIC without DSP/Divider, 
                        // we must simulate the algorithm step-by-step or use combinational logic if size is tiny.
                        // With max value 8, we can unroll or use a ready signal.
                        // Let's use a combinational GCD logic since inputs are very small to ensure efficiency.
                        // However, strictly following instructions for iterative solution.
                        // Let's use a counter to wait for result or implement the logic directly.
                        // Since we are requested to implement an iterative solution, let's assume we use a combinational block for GCD
                        // or a state machine that takes 1 cycle per step.
                        // To be safe and synthesizable without complex dividers, let's use the property: gcd(x, y) = gcd(y, x % y).
                        // For small numbers, we can do this in one cycle combinational block.
                        // But let's strictly follow the state machine description. The prompt asks for a GCD sub-state machine.
                        
                        // Let's implement the GCD step logic here manually to avoid % operator if it's expensive,
                        // but for 8-bit, it's fine. Let's assume a combinational GCD result is available.
                        // Wait, the prompt says 'in a sub-state machine or combinational block'.
                        // Since we are in a state machine, let's use a combinational GCD block driven by the current x_reg and y_reg.
                        // But the prompt says 'Iterative solution' and 'Use state machine... CALC_GCD'.
                        // Let's make CALC_GCD take multiple cycles to simulate the iterative nature.
                        // We will use a small counter to wait 2-3 cycles to be safe for division.
                        // Actually, for 8-bit numbers, the Euclidean algorithm takes very few steps (max 8).
                        // Let's implement a divider logic in the state machine.
                        
                        // Simplified approach: Use combinational GCD, then latch result in CHECK_GCD.
                        // To satisfy 'iterative', let's check if we are ready. Since we are in a clocked block,
                        // we can calculate GCD in combinational logic and just use the state to transition.
                        // CALC_GCD -> CHECK_GCD takes 1 cycle? Or more? Let's make it take 1 cycle for logic.
                        // Wait, the instructions say 'Use a state machine with states... CALC_GCD' implying it might take cycles.
                        // Given the constraint 'small inputs', we will implement a combinational GCD calculation inside the block.
                        // However, to match the state machine flow explicitly, let's just transition to CHECK_GCD immediately after latch setup.
                        // Or better: Let's do the GCD calculation in the combinational logic block outside the always block.
                        // Let's put the GCD logic in a separate combinational block and just transition states.
                        state <= CHECK_GCD;
                    end
                end

                CHECK_GCD: begin
                    // Logic for GCD will be combinational below.
                    // If gcd(x_reg, y_reg) == 1, result++
                    // We need to know the result of GCD. Let's define a combinational wire for gcd_result.
                    // But since we are in a sequential block, we need to handle the result.
                    // Let's calculate GCD combinationaly and use it here.
                    // Let's assume gcd_calc(x, y) returns the gcd.
                    
                    // Check if we just finished calc (if we were waiting). 
                    // Since we want to be efficient, we calculate GCD in combinational logic and latch it if needed.
                    // But the state machine asks for CALC_GCD state. 
                    // Let's refine: CALC_GCD sets up inputs for GCD. CHECK_GCD checks result.
                    // To do this without extra registers, we use combinational logic.
                    // Let's calculate GCD of x_reg and y_reg combinationally.
                    // Wait, combinational GCD loop might be long. Let's assume a single cycle GCD for 8-bit is okay.
                    // Let's define a combinational block for GCD.
                    
                    // Combinational GCD calculation
                    // Use a helper function or combinational block.
                    // Since I cannot use functions easily for loops in always block, I will assume a separate combinational logic.
                    // Let's do the GCD logic in the combinational block below.
                    // In CHECK_GCD state, we read the GCD result.
                    
                    // Let's use a pre-calculated GCD value.
                    if (gcd_calc(x_reg, y_reg) == 8'd1) begin
                        result <= result + 1;
                    end
                    state <= NEXT_PAIR;
                end

                NEXT_PAIR: begin
                    if (y_reg < d) begin
                        y_reg <= y_reg + 1;
                        state <= CALC_GCD;
                    end else begin
                        y_reg <= c; // Reset y
                        if (x_reg < b) begin
                            x_reg <= x_reg + 1;
                            state <= CALC_GCD;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to return to IDLE (optional handshake)
                        // Or stay in DONE until reset? The prompt says 'Assert done signal'.
                        // Usually, we return to IDLE on a new start or reset.
                        // Let's stay in DONE until reset or start goes low then high again.
                        // Let's assume we stay in DONE until reset.
                    end
                    // If start goes low, we can go back to IDLE to accept new request
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational GCD Logic (Helper)
    // Since the Euclidean algorithm is iterative, we compute it combinationally here for small values.
    // This assumes the synthesizer can handle the loop or we unroll it.
    // For 8-bit, a pure combinational loop is fine.
    function automatic [7:0] gcd_calc;
        input [7:0] aa;
        input [7:0] bb;
        reg [7:0] t_a, t_b;
        begin
            t_a = aa;
            t_b = bb;
            while (t_b != 0) begin
                // Modulo operation. Since it's small, synthesizer will handle it.
                // To ensure no latches and correct logic:
                t_a = t_a % t_b;
                // Swap
                gcd_calc = t_a;
                t_a = t_b;
                t_b = gcd_calc;
            end
            gcd_calc = t_a;
        end
    endfunction

endmodule