module even_power_sum (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [63:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [4:0] i, next_i; // iteration counter
    reg [63:0] next_result;
    
    // Power calculation pipeline registers
    // 2 cycles setup for power calculation pipeline
    // Power calculation requires: (2*i)^5
    // Pipeline: Stage 0 -> Stage 1 -> Stage 2 (Result valid)
    // Input: 2*i -> Square -> Cube (Pow3) -> Pow4 -> Pow5 -> Accumulate
    // To fit the "2 cycles setup" requirement, we likely need to register the input to the combinatorial chain,
    // or use 2 pipeline stages strictly for the power calc.
    // Since the instruction says "Use combinational logic for power calculation with registered intermediate products",
    // we will break the multiplication into stages.
    // Given 16 cycles for n terms, we can afford a few stages.
    // Let's assume 3 stages of registered math to be safe and robust:
    // Stage 1: 2*i -> x^2, x^3
    // Stage 2: x^3 -> x^4
    // Stage 3: x^4 -> x^5
    // Total latency 3 cycles per term is too slow for 16 terms (48 cycles). Requirement is 16 cycles for terms.
    // This implies the calculation of the power must be done within 1 cycle, or pipelined across the loop.
    // With the loop incrementing every cycle, the pipeline must be filled.
    // Requirement: "Result valid 18 clock cycles after start" (2 setup + 16 cycles for n terms).
    // This means 1 term per cycle throughput.
    // "Use combinational logic for power calculation with registered intermediate products" suggests breaking the huge combinational path.
    // We can use 2 registers in the calculation path (2 cycles setup).
    // Let's define a 3-stage pipeline for the power calculation: 
    // P0: Register Input (2*i), Calc Square and Cube
    // P1: Register Square and Cube, Calc Pow4
    // P2: Register Pow4, Calc Pow5
    // P3: Register Pow5, Add to Result
    // This adds 3 cycles of latency to the accumulation. 
    // If we strictly follow "16 cycles for n terms", we must accumulate 1 term per cycle.
    // If the power calc takes K cycles, we need K stages of pipeline.
    // Let's trace the timing:
    // Start -> Cycle 1: Process term 1 (P0) -> Cycle 2: (P1), Process term 2 (P0) -> ...
    // The instruction says "2 cycles setup".
    // Let's try to fit the power calculation in 2 registered stages (effectively 3 cycles total including result add).
    // But wait, if n=16, and we have 16 cycles for terms, we must issue 1 term per cycle.
    // If we use a 2-cycle deep power calculation pipeline, we just need 2 registers.
    // Let's calculate powers efficiently.
    // x = 2*i (max 32). x^5 = 33554432. Fits in 25 bits.
    // Q16.16 format: value * 65536.
    // Result accumulates up to ~33M * 65536 = 2^52 roughly. Fits in 64 bits.
    
    // Pipeline Stage 0 (Input and early math)
    reg [5:0] s0_x;       // 2*i (max 32, 6 bits)
    reg [4:0] s0_n;
    reg [4:0] s0_i;
    reg [31:0] s0_x2;     // x*x (max 1024, 10 bits)
    
    // Pipeline Stage 1
    reg [31:0] s1_x3;     // x^3 (max 32k, 15 bits)
    reg [31:0] s1_x4;     // x^4 (max1M, 20 bits)
    reg [4:0] s1_i;
    
    // Pipeline Stage 2
    reg [63:0] s2_power_q16; // Final power in Q16.16
    reg [4:0] s2_i;
    reg s2_valid;
    
    // Next stage logic
    wire [5:0] x_wire = 2 * (i + 1); // Calculate next x based on next i
    wire [31:0] x2_wire = x_wire * x_wire;
    wire [31:0] x3_wire = x_wire * x2_wire; // x^3 (needs to be combinational based on S0 output ideally, or fresh input)
    
    // To avoid long paths, we use registered outputs.
    // The main FSM will increment 'i' every cycle when in COMPUTE state.
    // We need to align the pipeline stages with 'i'.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            result <= 0;
            done <= 0;
            // Reset pipeline regs
            s0_x <= 0; s0_x2 <= 0; s0_n <= 0; s0_i <= 0;
            s1_x3 <= 0; s1_x4 <= 0; s1_i <= 0;
            s2_power_q16 <= 0; s2_i <= 0; s2_valid <= 0;
        end else begin
            state <= next_state;
            i <= next_i;
            result <= next_result;
            
            // Pipeline Stage 0: Calculate Square
            // We process the 'i' value that is currently valid for this stage
            // If state is COMPUTE, we feed new data into the pipeline
            if (state == COMPUTE) begin
                s0_x <= x_wire;           // 2*(i+1) because i increments now or next?
                s0_x2 <= x2_wire;         // x*x
                s0_i <= i + 1;            // Track which iteration this is
                s0_n <= n;
            end else begin
                s0_x <= 0;
                s0_x2 <= 0;
                s0_i <= 0;
            end
            
            // Pipeline Stage 1: Calculate x^3 and x^4
            // Input is s0
            if (state == COMPUTE) begin
                // x^3 = s0_x * s0_x2
                s1_x3 <= s0_x * s0_x2;
                // x^4 = s0_x2 * s0_x2
                s1_x4 <= s0_x2 * s0_x2;
                s1_i <= s0_i;
            end else begin
                s1_x3 <= 0;
                s1_x4 <= 0;
                s1_i <= 0;
            end
            
            // Pipeline Stage 2: Calculate x^5 and Format to Q16.16
            // Input is s1
            if (state == COMPUTE) begin
                // x^5 = x^4 * x = s1_x4 * s0_x (Wait, s0_x is delayed? No, need to align)
                // x^3 and x^4 are ready now (based on s0 input). s0_x is available now too.
                // Let's use s1_x4 * s0_x. 
                // But s0_x and s1_x4 are valid at the same time (clock edge).
                // So we need to register s0_x to match s1_x4? 
                // Actually, we can just compute x^5 = s1_x4 * s0_x_registered. 
                // Let's fix the pipeline structure for clarity:
                // S0: Input i. Calc x, x2.
                // S1: Input (x, x2). Calc x3, x4.
                // S2: Input (x, x3, x4). Calc x5, Shift.
                
                // Let's modify S0 to output x, x2. 
                // S1 Input: x, x2. Calc x3, x4. Pass x.
                // S2 Input: x, x3, x4. Calc x5. Pass index.
                
                // Let's refine the 'always' block for pipeline to be cleaner.
                // We will use temporary wires for the calculations at each stage input.
            end
        end
    end
    
    // Combinational Logic for Power Calculation within the pipeline
    wire [63:0] stage1_x3 = s0_x * s0_x2;       // x^3
    wire [63:0] stage1_x4 = s0_x2 * s0_x2;      // x^4
    
    // We need to latch s0_x for stage 2 because stage 1 only outputs x3, x4
    // So we add one more register for x in stage 1
    reg [5:0] s1_x; 
    
    // Re-evaluating the 16-cycle requirement:
    // If we need 1 term per cycle, the pipeline must be filled. 
    // Standard approach: 
    // Cycle 0: IDLE -> COMPUTE. i=1 starts. 
    // Cycle 1: Calc Term 1. i=2.
    // Cycle 16: Calc Term 16. i=17.
    // Cycle 17: Accumulate Term 16 (if not already done). State -> DONE.
    // The instruction says "Result valid 18 clock cycles after start".
    // 2 Setup + 16 Terms. 
    // This implies 2 cycles of setup before the 16 cycles of calculation start?
    // Or 2 cycles of latency per term?
    // "Use combinational logic... with registered intermediate products".
    // This strongly suggests a pipelined multiplier.
    // Let's implement a 3-stage pipeline for the math (S0, S1, S2), which gives 3 cycles latency.
    // To get 1 term per cycle throughput, we pipeline the iterations.
    // The state machine will stay in COMPUTE for n+2 cycles?
    // If n=16, we need 18 cycles total (including setup). 
    // Setup (2) + Calc (16) = 18. 
    // So we stay in COMPUTE for 18 cycles, then go to DONE.
    // Let's make the power calc take exactly 2 cycles of registered logic (so 3 cycles total including output registration).
    // But the instruction says "2 cycles setup, 16 cycles for n terms".
    // If we assume "setup" means the time to fill the pipeline (2 cycles), then terms 1..16 are computed in cycles 3..18.
    // Let's go with a 2-stage pipeline for math (effectively 2 registers deep).
    
    // --- Revised Pipeline Registers ---
    // Stage 0: Inputs (i, n, 2*i, (2*i)^2)
    // Stage 1: Intermediates ((2*i)^3, (2*i)^4) + Pass through (2*i)
    // Stage 2: Final ((2*i)^5 in Q16.16, i)
    
    // We need to update the logic inside the always block based on these signals.
    
    // Wires for pipeline calculations
    wire [63:0] x_wire_long = 2 * (i + 1); // Next value to push into pipeline
    wire [63:0] x2_wire_long = x_wire_long * x_wire_long;
    
    wire [63:0] s0_x_long = s0_x;
    wire [63:0] s0_x2_long = s0_x2;
    
    wire [63:0] s1_x3_wire = s0_x_long * s0_x2_long;
    wire [63:0] s1_x4_wire = s0_x2_long * s0_x2_long;
    
    // To minimize bits, we cast to 64-bit for intermediate multiplication, then truncate for registers.
    // However, we need Q16.16 format at the end.
    // Formula: result = (val * 65536). val = 2*i.
    // We need (2*i)^5 * 65536.
    // (2*i)^5 = 32 * i^5. 
    // Let's stick to the integer multiplication approach, then shift.
    // Actually, let's keep it in integer domain and multiply by 65536 at the end.
    // Note: x <= 32. x^5 <= 33,554,432. 
    // We can easily fit intermediate calculations in 64 bits.
    
    // Re-writing the always block to be cleaner and strictly follow the derived logic
    // We need to handle the reset and update of pipeline registers explicitly.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 5'd0;
            result <= 64'd0;
            done <= 1'b0;
            
            // Clear pipeline
            s0_x <= 6'd0; s0_x2 <= 32'd0; s0_n <= 5'd0; s0_i <= 5'd0;
            s1_x <= 6'd0; s1_x3 <= 32'd0; s1_x4 <= 32'd0; s1_i <= 5'd0;
            s2_power_q16 <= 64'd0; s2_i <= 5'd0; s2_valid <= 1'b0;
        end else begin
            // Default assignments
            next_state = state;
            next_i = i;
            next_result = result;
            done = 1'b0;
            
            // Pipeline advance logic
            // We assume the pipeline is driven by the COMPUTE state.
            // If not in COMPUTE, pipeline flushes.
            
            // Stage 2: Accumulate
            // Logic moved here to be sequential
            if (s2_valid && s2_i <= n) begin
                next_result = result + s2_power_q16;
            end
            
            // State Transition Logic
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state = COMPUTE;
                        next_i = 5'd0; // Start counter at 0. Inside compute we use i+1.
                        next_result = 64'd0;
                        // Pipeline flush start
                    end
                end
                
                COMPUTE: begin
                    // Check if we are done.
                    // We are done when the last term has entered the pipeline.
                    // Pipeline depth is 3 (S0, S1, S2). 
                    // i tracks how many terms have been STARTED.
                    // We start term i+1.
                    // We continue until i == n (meaning we just started term n).
                    // Wait, if i starts at 0:
                    // Cycle 1: i=0, process term 1 (i+1). 
                    // Cycle 16: i=15, process term 16.
                    // Next cycle, i=16. We need to stop accepting new terms.
                    // So condition: if (i >= n) -> Transition to DONE.
                    // But we need to let the pipeline flush.
                    // 2 cycles setup + 16 terms = 18 cycles total.
                    // Let's count 18 cycles in COMPUTE.
                    
                    // Increment i
                    if (i < n) begin
                        next_i = i + 1;
                    end else begin
                        // i == n. 
                        // We have finished issuing terms.
                        // We need to wait for the last term to go through the pipeline.
                        // Pipeline depth = 3. 
                        // So wait 3 more cycles after i hits n.
                        // Or simply stay here for fixed duration.
                        // Let's track a cycle counter or use the pipeline valid signals.
                        // Since we want to be robust, we use the pipeline valids.
                        
                        // Wait until s2_valid goes low (meaning the last term was accumulated).
                        // Actually, s2_valid comes 3 cycles after issue.
                        // If i hits n, we stop issuing (s0 valid goes low next cycle).
                        // s1 valid drops 1 cycle later.
                        // s2 valid drops 1 cycle later.
                        // So 3 cycles after i==n, s2_valid drops.
                        // We should transition to DONE when s2_valid drops.
                        // BUT, we need to output 'done' 18 cycles after start.
                        
                        // Alternative: Use a counter.
                        // Requirement: 2 setup + 16 terms = 18 cycles.
                        // Let's use a cycle counter 'comp_count'.
                        // But we don't have it yet. Let's add it.
                        // Actually, let's use 'i' logic. 
                        // We need to wait 3 cycles after i reaches n.
                        // So we can transition to DONE when (i == n) AND (s2_i == n).
                        // s2_i follows i with a delay of 3.
                        
                        if (s2_i == n) begin
                            next_state = DONE;
                        end
                    end
                end
                
                DONE: begin
                    done = 1'b1;
                    next_state = IDLE;
                    // result is already updated in the pipeline logic above
                end
            endcase
            
            // --- Pipeline Registers Update ---
            
            // Stage 0 (Input Stage)
            // Only advance if in COMPUTE and we have terms left to process
            if (state == COMPUTE && i < n) begin
                // Push new term into pipeline
                s0_i <= i + 1; // The index of the term being processed
                // Calculate 2*(i+1)
                s0_x <= 2 * (i + 1); 
                // Calculate Square immediately (combinational)
                s0_x2 <= (2 * (i + 1)) * (2 * (i + 1));
                s0_n <= n; // Pass through n
            end else begin
                // Flush pipeline input
                s0_i <= 0;
                s0_x <= 0;
                s0_x2 <= 0;
            end
            
            // Stage 1 (Intermediate Stage)
            // Receives output of Stage 0
            // If state is COMPUTE, we propagate. 
            // But we must also propagate if we just stopped accepting new inputs but previous ones are in flight.
            // Since s0 registers only update when (i < n), after i reaches n, s0 becomes 0. 
            // This would kill the pipeline. 
            // We need to keep the pipeline flowing.
            // To fix this, we should not gate the pipeline with (i < n) in the intermediate stages.
            // We gate it only at the input (s0 calculation).
            // However, we need to know WHEN to stop.
            // Let's change strategy: The FSM stays in COMPUTE for exactly 18 cycles.
            // But 'n' is variable. 
            // So we rely on 's0_i' validity. 
            // The issue is: if i == n, we stop pushing to s0. s0 becomes 0. s1 becomes 0. s2 becomes 0. 
            // This misses the last terms.
            // Solution: Keep pushing to s0/s1/s2 as long as s0_i/s1_i/s2_i are valid.
            // We use 's0_i_valid', 's1_i_valid' flags.
            
            // Let's try a simpler approach for the pipeline that handles flush correctly.
            // We will use 'valid' flags for each stage.
            // Reset logic cleared them. We need to implement them properly.
            
            // Re-doing the pipeline logic within the always block:
            
            // Stage 0 Logic:
            // Start new computation if start is asserted (for IDLE->COMPUTE transition handling)
            // OR if in COMPUTE and i < n.
            // Wait, if we are in COMPUTE, we need to process terms. 
            
            // Let's define a 'feed' signal. 
            wire feed = (state == COMPUTE) && (i < n);
            
            // Stage 0:
            // Data is (2*(i+1), (2*(i+1))^2, index)
            if (state == IDLE && start) begin
                // Initial feed for first term
                s0_i <= 1;
                s0_x <= 2;
                s0_x2 <= 4;
            end else if (state == COMPUTE && i < n) begin
                // Subsequent feeds
                s0_i <= i + 2; // i increments in transition logic, so i is the previous count. 
                // Wait, in the state logic above, next_i = i + 1 if (i < n).
                // So on clock edge, i becomes i+1.
                // If we are processing i, we want to push i+1.
                // Let's stick to: s0 processes 'next_i'.
                // In IDLE->COMPUTE, i=0. s0 pushes 1.
                // In COMPUTE (cycle 1), i=1. s0 pushes 2.
                // Correct.
                
                // But wait, if we transition to DONE when s2_i == n, we need to keep the pipeline full.
                // So we should not stop feeding s0 until i >= n.
                // The code above: `if (state == COMPUTE && i < n)` is correct.
                
                s0_i <= i + 1;
                s0_x <= 2 * (i + 1);
                s0_x2 <= (2 * (i + 1)) * (2 * (i + 1));
            end else if (state == DONE) begin
                // Flush
                s0_i <= 0;
                s0_x <= 0;
                s0_x2 <= 0;
            end
            // If state is COMPUTE but i >= n, we don't update s0, so it holds the last value or we can force 0.
            // But we need the pipeline to advance with 0 values to flush.
            // Let's force s0 to 0 if not feeding.
            if (state == COMPUTE && i >= n && s0_i != 0) begin
               // We want to keep s0 active until the last term leaves.
               // Actually, if we just stop updating s0, s0 retains the last value (term n).
               // Which is what we want. 
               // We just need to ensure that when i >= n, we don't overwrite s0 with new garbage.
               // So the condition above `if (feed) ... else if (state == DONE) ...` handles it. 
               // If not feed and not DONE, we do nothing (keep register value).
            end
            
            // Stage 1: Calculate Cube and 4th power
            // Inputs: s0_x, s0_x2, s0_i
            // Logic: x3 = s0_x * s0_x2; x4 = s0_x2 * s0_x2;
            // We only update if s0_i is valid (non-zero) OR if we need to propagate '0' to flush.
            // Let's propagate whatever is in s0.
            
            if (state != IDLE || start) begin // Active or starting
                // Update stage 1 from stage 0
                s1_i <= s0_i;
                s1_x <= s0_x;
                // Perform multiplication registered in stage 1 logic
                s1_x3 <= s0_x * s0_x2;
                s1_x4 <= s0_x2 * s0_x2;
            end else begin
                // Clear if idle
                s1_i <= 0;
                s1_x <= 0;
                s1_x3 <= 0;
                s1_x4 <= 0;
            end
            
            // Stage 2: Calculate x^5 and convert to Q16.16
            // Inputs: s1_x, s1_x3, s1_x4, s1_i
            // Logic: x5 = s1_x4 * s1_x; Q16.16 = x5 << 16
            if (state != IDLE || start) begin
                s2_i <= s1_i;
                // x^5 = x^4 * x. s1_x4 is 32-bit, s1_x is 6-bit. Result fits in 64-bit.
                s2_power_q16 <= (s1_x4 * s1_x) << 16;
                s2_valid <= (s1_i != 0); // Valid if index is non-zero
            end else begin
                s2_i <= 0;
                s2_power_q16 <= 0;
                s2_valid <= 0;
            end
            
            // Finally, handle the result accumulation
            // We do this inside the sequential block to update 'result'
            // We use 'next_result' which was set in the state logic, but we need to ensure it updates on every cycle.
            // The 'next_result' logic earlier checked s2_valid. 
            // Let's strictly separate pipeline update and accumulation update.
            
            // Accumulate logic:
            if (s2_valid && s2_i <= n) begin
                result <= result + s2_power_q16;
            end
            
            // Update State Machine Registers (already done at top of block)
            state <= next_state;
            i <= next_i;
            done <= (state == DONE); // Signal done when in DONE state
            
        end
    end

endmodule
