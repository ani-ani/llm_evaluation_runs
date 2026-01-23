module barry_bruce (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [3:0] k_in,
    input [15:0] seq_in,
    input [127:0] costs_in,
    output reg [7:0] min_cost,
    output reg impossible,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CHECK_BRUCE = 3'b010;
    localparam UPDATE_MIN = 3'b011;
    localparam NEXT_MASK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Registers for inputs
    reg [4:0] n_reg;
    reg [3:0] k_reg;
    reg [15:0] seq_reg;
    reg [127:0] costs_reg;
    
    // Barry's iteration state
    reg [15:0] barry_mask;
    reg [15:0] barry_seq;
    reg [7:0] current_cost;
    
    // Bruce's iteration state
    reg [15:0] bruce_mask;
    reg [15:0] check_seq;
    reg bruce_found_fix;
    reg [3:0] pop_count; 
    
    // Helper: Popcount for 4-bit (Bruce moves up to 8, but we iterate bits)
    wire [3:0] bruce_popcount;
    assign bruce_popcount = bruce_mask[0] + bruce_mask[1] + bruce_mask[2] + bruce_mask[3] + 
                            bruce_mask[4] + bruce_mask[5] + bruce_mask[6] + bruce_mask[7] +
                            bruce_mask[8] + bruce_mask[9] + bruce_mask[10] + bruce_mask[11] +
                            bruce_mask[12] + bruce_mask[13] + bruce_mask[14] + bruce_mask[15];

    // Helper: Balance check logic (Combinational)
    // Returns 1 if sequence is balanced, 0 otherwise
    reg is_balanced;
    integer i;
    reg signed [5:0] bal;
    reg [15:0] temp_seq;
    reg [3:0] open_count;
    
    always @(*) begin
        temp_seq = check_seq;
        bal = 0;
        is_balanced = 1;
        open_count = 0;
        
        // Check n_reg bits
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n_reg) begin
                if (temp_seq[i]) bal = bal + 1; // '(' is 1
                else bal = bal - 1; // ')' is 0
                
                if (bal < 0) is_balanced = 0;
                if (temp_seq[i]) open_count = open_count + 1;
            end
        end
        
        if (bal != 0) is_balanced = 0;
        // Also need equal number of parens, which is implied by bal==0 and total length n
        // But let's be strict: total open must be n/2
        if (n_reg[0]) is_balanced = 0; // n must be even, otherwise impossible
        if (open_count != n_reg[4:1]) is_balanced = 0; // n/2
    end

    // Helper: Cost Calculation for Barry (Combinational)
    // This calculates the cost of the current Barry mask
    reg [7:0] temp_cost_sum;
    always @(*) begin
        temp_cost_sum = 0;
        // Only sum bits that are set in barry_mask AND within n_reg
        // Since costs are packed, we can index them.
        // We must unroll or use a loop.
        for (i = 0; i < 16; i = i + 1) begin
            if (barry_mask[i] && (i < n_reg)) begin
                temp_cost_sum = temp_cost_sum + costs_reg[i*8 +: 8];
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_cost <= 8'hFF; // Initialize to max (infinity)
            impossible <= 0;
            valid <= 0;
            barry_mask <= 0;
            bruce_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    impossible <= 0;
                    min_cost <= 8'hFF; // Reset min cost
                    if (start) begin
                        state <= SETUP;
                        n_reg <= n_in;
                        k_reg <= k_in;
                        seq_reg <= seq_in;
                        costs_reg <= costs_in;
                    end
                end

                SETUP: begin
                    // Initialize Barry's iteration
                    // Start with mask 0 (Barry does nothing)
                    barry_mask <= 0;
                    barry_seq <= seq_reg;
                    current_cost <= 0;
                    bruce_mask <= 0;
                    state <= CHECK_BRUCE;
                end

                CHECK_BRUCE: begin
                    // Exhaustive check for Bruce
                    // Logic: Iterate bruce_mask from 0 to (1<<n)-1, check popcount <= k_reg
                    // If valid mask found that balances check_seq, mark bruce_found_fix = 1
                    // This is a 2-stage process: incrementing bruce_mask and checking
                    
                    // We need to handle the check logic here. 
                    // Since we need to iterate all Bruce masks, we can use a nested loop structure or a flat iteration.
                    // To save latency, we will combine the increment and check logic.
                    
                    // First, check current bruce_mask
                    if (bruce_mask < (1 << n_reg)) begin
                        // Check if popcount <= k_reg
                        if (bruce_popcount <= k_reg) begin
                            // Check if this mask fixes the sequence
                            // Apply flips to check_seq (which is barry_seq)
                            // We need to compute the flipped sequence temporarily
                            // To avoid combinational loops, let's do the check state by state.
                            
                            // We will use the combinational logic 'is_balanced' computed on 'check_seq' XOR 'bruce_mask'
                            // But 'check_seq' is a register. We need to XOR logic.
                            // Let's perform the XOR in the previous cycle or compute it now.
                            
                            // Let's compute the temporary sequence for the check
                            if (is_balanced) begin // Check result of previous cycle or combinational wire?
                                // Actually, we should compute is_balanced based on (check_seq ^ bruce_mask)
                                // Let's rely on the combinational block above, but we need to feed it the correct sequence.
                                // Since 'check_seq' is registered, we can't change it every cycle without latency.
                                // Let's calculate the condition manually here for speed/area in the sequential block.
                                
                                // Calculate balance for (check_seq ^ bruce_mask)
                                // This needs a small loop or logic.
                                // Let's rely on the fact that k is small. 
                                // Actually, let's use a separate always block or wire for the current flipped sequence.
                                // Let's assume the combinational logic 'is_balanced' is sensitive to 'check_seq' and 'bruce_mask'.
                                // We'll update 'check_seq' temporarily? No.
                                // Let's perform the check inside the sequential block using a local variable.
                                
                                // Re-calculate balance for current bruce_mask
                                // Optimization: Use a 'calc_done' flag or similar.
                                // For this constraint, let's unroll the check logic slightly.
                                
                                // Let's assume 'is_balanced' logic in combinational block uses 'check_seq' and 'bruce_mask'.
                                // We must ensure 'check_seq' is not x.
                                // Since 'check_seq' is 'barry_seq', it is valid.
                                // The combinational block 'is_balanced' calculates on 'check_seq' XOR 'bruce_mask' implicitly? 
                                // No, the block above calculates 'check_seq'. We need to fix the block or logic.
                                
                                // Let's fix the combinational block to check 'check_seq ^ bruce_mask'.
                                // But the block is already written. Let's add a wire for the flipped sequence.
                            end
                            
                            // FIX: We need a wire for the sequence Bruce is checking.
                            wire [15:0] bruce_try_seq = check_seq ^ bruce_mask;
                            
                            // We need to re-evaluate 'is_balanced' concept inside the always block or use a function.
                            // Let's implement a small checker inside the always block to avoid dependency on external latches.
                            
                            // Check logic inline:
                            bal = 0;
                            open_count = 0;
                            is_balanced = 1;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < n_reg) begin
                                    // Apply Bruce flip
                                    if (bruce_mask[i]) begin
                                        // Flip the bit
                                        if (check_seq[i]) begin // was '(' -> becomes ')'
                                            bal = bal - 1;
                                        end else begin // was ')' -> becomes '('
                                            bal = bal + 1;
                                        end
                                    end else begin
                                        // Original bit
                                        if (check_seq[i]) bal = bal + 1;
                                        else bal = bal - 1;
                                    end
                                    
                                    if (bal < 0) is_balanced = 0;
                                    if ((check_seq[i] ^ bruce_mask[i])) open_count = open_count + 1;
                                end
                            end
                            if (bal != 0) is_balanced = 0;
                            if (n_reg[0]) is_balanced = 0;
                            if (open_count != n_reg[4:1]) is_balanced = 0;
                            
                            if (is_balanced) begin
                                bruce_found_fix <= 1;
                                state <= NEXT_MASK; // Found a fix, no need to check more Bruce masks for this Barry
                                bruce_mask <= 0; // Reset for next Barry? No, we just exit.
                            end else begin
                                // Move to next Bruce mask
                                bruce_mask <= bruce_mask + 1;
                            end
                        end else begin
                            // Popcount too high, skip to next
                            bruce_mask <= bruce_mask + 1;
                        end
                    end else begin
                        // Finished iterating all Bruce masks without finding a fix
                        bruce_found_fix <= 0;
                        state <= UPDATE_MIN;
                    end
                end

                UPDATE_MIN: begin
                    // If Bruce could NOT fix it (bruce_found_fix == 0), update min_cost
                    if (!bruce_found_fix) begin
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                    end
                    state <= NEXT_MASK;
                end

                NEXT_MASK: begin
                    // Increment Barry's mask
                    if (barry_mask < (1 << n_reg)) begin
                        barry_mask <= barry_mask + 1;
                        // Calculate new cost and sequence
                        // Need to compute cost of new mask. 
                        // Since we increment, we can update cost incrementally or compute fully.
                        // Combinational 'temp_cost_sum' relies on 'barry_mask'.
                        // So after barry_mask updates, we need to wait one cycle for cost calculation or compute inline.
                        // Let's compute inline to save state.
                        
                        // Compute cost
                        // We can reuse the logic from temp_cost_sum but inside seq block
                        current_cost <= 0; // Placeholder, will calculate in next state or combine
                        // Actually, let's jump to CHECK_BRUCE, but we need the cost/sequence ready.
                        
                        // Let's compute cost based on barry_mask (old or new?)
                        // We are in NEXT_MASK, barry_mask is updated.
                        // We need to compute the cost for this NEW barry_mask.
                        // We also need to compute the modified sequence (barry_seq).
                        // barry_seq is seq_reg ^ barry_mask.
                        
                        // So we need to wait for combinational logic to settle or do it in one cycle.
                        // Let's do it in one cycle by setting a flag or staying in NEXT_MASK for one cycle?
                        // Or combine logic in CHECK_BRUCE.
                        // Let's stay in NEXT_MASK to compute, or just go to CHECK_BRUCE and compute there.
                        
                        // Let's go to CHECK_BRUCE, but we need to know 'current_cost' and 'barry_seq' for THIS mask.
                        // So we must compute them now.
                        // 'barry_mask' is updated. 
                        // 'barry_seq' = seq_reg ^ barry_mask.
                        barry_seq <= seq_reg ^ (barry_mask + 1); // Wait, barry_mask was incremented in this block.
                        // Let's assume we incremented barry_mask. 
                        // So we use (barry_mask) because it was updated.
                        barry_seq <= seq_reg ^ barry_mask;
                        
                        // Calculate cost
                        // We need a loop to sum costs.
                        // Since we are in sequential logic, we can't loop easily without latency.
                        // However, 16 bits is small. We can unroll the addition or use a accumulator.
                        // But we are in one state. 
                        // Let's rely on the combinational 'temp_cost_sum' which is triggered by 'barry_mask'.
                        // But 'barry_mask' updates here. 
                        // Timing: barry_mask updates -> temp_cost_sum updates -> current_cost updates.
                        // This is a register-to-register path. It should work if we stay in this state or move to next.
                        // Let's move to CHECK_BRUCE and assign current_cost <= temp_cost_sum.
                        // BUT, we are in the same cycle. 
                        // To be safe and simple, let's add a CALC state.
                        state <= CHECK_BRUCE;
                        bruce_mask <= 0; // Reset Bruce counter
                        // Update cost from combinational logic. Note: barry_mask has been incremented.
                        current_cost <= temp_cost_sum;
                        
                        // Special case: If barry_mask was just set to 0 in SETUP, we go to CHECK_BRUCE.
                        // If we are here from NEXT_MASK, barry_mask is incremented.
                        // So we need to handle the first iteration (mask 0) correctly.
                        // In SETUP, we set barry_mask=0, then go to CHECK_BRUCE.
                        // So CHECK_BRUCE handles mask 0.
                        // When we come here, we incremented mask. So we need to process this new mask.
                        
                        // Wait, logic check:
                        // SETUP -> CHECK_BRUCE (mask 0)
                        // If mask 0 not finished (iterating Bruce), stay in CHECK_BRUCE.
                        // When mask 0 done, we go to UPDATE_MIN.
                        // UPDATE_MIN -> NEXT_MASK.
                        // NEXT_MASK increments mask (0 -> 1). Sets barry_seq. Sets current_cost.
                        // Then -> CHECK_BRUCE.
                        // So this flow works.
                        
                    end else begin
                        // Done iterating Barry's masks
                        state <= DONE;
                    end
                    
                    // Special handling for 'impossible' logic
                    // If we finished SETUP (mask 0) and moved to NEXT_MASK, it means mask 0 was processed.
                    // If min_cost is still 0xFF, it means mask 0 didn't work (Bruce could fix).
                    // We continue. 
                end

                DONE: begin
                    valid <= 1;
                    // Check if we found any solution
                    if (min_cost == 8'hFF) begin
                        impossible <= 1;
                        min_cost <= 8'h00; // Or some indicator? Spec says output '?' logic.
                        // In this context, we output impossible=1.
                        // If we want to output 'min_cost' as '?' (likely 0 or max), let's stick to spec.
                        // Spec: "If impossible output '?'". Since we can't output '?', we set impossible high.
                        // Usually min_cost is undefined in this case. Let's keep it as 0 or whatever.
                    end
                    // Stay in DONE until reset
                end
            endcase
        end
    end

    // Fix for combinational block dependency:
    // The block above depends on 'check_seq' and 'bruce_mask'.
    // In the sequential block, we assign 'check_seq' only in SETUP (barry_seq).
    // But we update 'barry_seq' in NEXT_MASK. 
    // However, we jump to CHECK_BRUCE immediately after NEXT_MASK.
    // So the combinational block 'is_balanced' might see old 'check_seq' if we don't register it.
    // We updated 'barry_seq' in NEXT_MASK. 
    // 'check_seq' is not assigned in the code above! 
    // We used 'barry_seq' to update the sequence.
    // We need to map 'check_seq' to 'barry_seq'.
    
    // Let's add a connection:
    always @(*) begin
        check_seq = barry_seq; // 'check_seq' is the sequence Barry created.
    end

endmodule

// Helper module or logic for popcount isn't strictly needed as we did it inline, 
// but let's ensure the popcount logic in the sequential block works.
// In the sequential block 'CHECK_BRUCE', we used bruce_popcount wire.
// We should define that wire properly.

module barry_bruce_wrapper (
    // We already defined the module. 
    // Just need to ensure the bruce_popcount wire is accessible.
    // Since it's inside the module, it's fine.
);
endmodule

// Re-reading the requirements: 
// "Use all provided details (interface, functional description, design requirements, etc.) as needed."
// "Only return Verilog code thats synthesizable."
// "Your response must be a valid JSON object..."

// I will clean up the code to ensure it compiles and fits the logic described.
// I realize the combinational block for 'is_balanced' in the code draft used a loop 'for (i = 0; i < 16; i = i + 1)'.
// In the sequential block CHECK_BRUCE, I re-calculated the logic.
// To be cleaner, I should stick to the sequential block logic.

// Let's refine the sequential logic for correctness.
// The combinational block 'is_balanced' is technically unused or mismatched.
// I will remove the separate combinational block and rely on the logic inside CHECK_BRUCE.

// Corrected Module Code:
module barry_bruce (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [3:0] k_in,
    input [15:0] seq_in,
    input [127:0] costs_in,
    output reg [7:0] min_cost,
    output reg impossible,
    output reg valid
);

    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CHECK_BRUCE = 3'b010;
    localparam UPDATE_MIN = 3'b011;
    localparam NEXT_MASK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [4:0] n_reg;
    reg [3:0] k_reg;
    reg [15:0] seq_reg;
    reg [127:0] costs_reg;
    
    reg [15:0] barry_mask;
    reg [15:0] barry_seq;
    reg [7:0] current_cost;
    
    reg [15:0] bruce_mask;
    reg bruce_found_fix;
    
    // Combinational helper for Bruce check
    reg [3:0] pop_count;
    integer j;
    
    always @(*) begin
        pop_count = 0;
        for (j = 0; j < 16; j = j + 1) begin
            if (bruce_mask[j] && (j < n_reg)) pop_count = pop_count + 1;
        end
    end

    // Cost helper
    reg [7:0] cost_sum;
    integer i;
    always @(*) begin
        cost_sum = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (barry_mask[i] && (i < n_reg)) begin
                cost_sum = cost_sum + costs_reg[i*8 +: 8];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_cost <= 8'hFF;
            impossible <= 0;
            valid <= 0;
            barry_mask <= 0;
            bruce_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    impossible <= 0;
                    min_cost <= 8'hFF;
                    if (start) begin
                        state <= SETUP;
                        n_reg <= n_in;
                        k_reg <= k_in;
                        seq_reg <= seq_in;
                        costs_reg <= costs_in;
                    end
                end

                SETUP: begin
                    barry_mask <= 0;
                    // Calculate for mask 0 (no flips) immediately
                    barry_seq <= seq_reg;
                    current_cost <= 0;
                    // Wait, cost for mask 0 is 0. So we can go to CHECK_BRUCE.
                    state <= CHECK_BRUCE;
                    bruce_mask <= 0;
                end

                CHECK_BRUCE: begin
                    // Check current Bruce mask
                    // 1. Check if we exhausted all Bruce masks
                    if (bruce_mask >= (1 << n_reg)) begin
                        bruce_found_fix <= 0;
                        state <= UPDATE_MIN;
                    end else begin
                        // 2. Check popcount constraint
                        if (pop_count <= k_reg) begin
                            // 3. Check balance
                            // Compute balance of (barry_seq ^ bruce_mask)
                            // We do this inline to avoid combinational loop issues
                            // We need a local variable for balance check
                            // Since this is always block, we can compute it.
                            
                            // Balance check logic
                            bal = 0;
                            open_cnt = 0;
                            is_bal = 1;
                            for (int k = 0; k < 16; k++) begin
                                if (k < n_reg) begin
                                    bit_val = barry_seq[k] ^ bruce_mask[k];
                                    if (bit_val) bal = bal + 1;
                                    else bal = bal - 1;
                                    if (bal < 0) is_bal = 0;
                                    if (bit_val) open_cnt = open_cnt + 1;
                                end
                            end
                            if (bal != 0) is_bal = 0;
                            if (n_reg[0]) is_bal = 0;
                            if (open_cnt != n_reg[4:1]) is_bal = 0;
                            
                            if (is_bal) begin
                                bruce_found_fix <= 1;
                                state <= NEXT_MASK;
                            end else begin
                                bruce_mask <= bruce_mask + 1;
                            end
                        end else begin
                            bruce_mask <= bruce_mask + 1;
                        end
                    end
                end

                UPDATE_MIN: begin
                    if (!bruce_found_fix) begin
                        // If current cost is lower than min_cost, update it.
                        // Note: current_cost holds cost of barry_mask from previous iteration (or initial).
                        // Actually, we update current_cost in NEXT_MASK.
                        // For mask 0, current_cost was 0.
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                    end
                    state <= NEXT_MASK;
                end

                NEXT_MASK: begin
                    // Increment Barry mask
                    // If we just processed mask X, we want to process X+1.
                    // But we need to check if we are done.
                    // We process mask 0 in SETUP/CHECK_BRUCE.
                    // Then we go to NEXT_MASK. 
                    // So barry_mask should be incremented.
                    
                    // Check if we just finished the last mask?
                    // If barry_mask was (1<<n)-1, we are done.
                    // But we enter NEXT_MASK after processing barry_mask.
                    
                    if (barry_mask == ((1 << n_reg) - 1)) begin
                        state <= DONE;
                    end else begin
                        barry_mask <= barry_mask + 1;
                        // We need to calculate cost and seq for the NEW mask.
                        // We will wait one cycle for combinational logic to propagate?
                        // Or we can do it in the next state.
                        // Let's use a CALC state or just do it here assuming logic is fast.
                        // Since cost_sum is combinational on barry_mask, and we just assigned barry_mask <= barry_mask + 1,
                        // cost_sum will reflect the NEW mask value.
                        // So we can assign current_cost <= cost_sum;
                        // And barry_seq <= seq_reg ^ (barry_mask + 1)? No, barry_mask is updated, so use barry_mask.
                        
                        // Problem: barry_mask updates at the end of the cycle.
                        // cost_sum is sensitive to barry_mask. 
                        // At this moment, barry_mask is still OLD value (before increment).
                        // So cost_sum is OLD cost.
                        // We need to calculate cost for NEW barry_mask.
                        // We can calculate (barry_mask + 1) logic, but it's messy.
                        // Better to stay in NEXT_MASK for one cycle to compute, or go to a temporary state.
                        // Given the constraint of 2^16 cycles, 1 extra cycle doesn't matter.
                        // Let's stay in NEXT_MASK but we need a way to know we are calculating.
                        // Or, we can update barry_mask, then in the next cycle (CHECK_BRUCE) we update current_cost.
                        // But CHECK_BRUCE uses current_cost only for UPDATE_MIN.
                        // So we can update current_cost in CHECK_BRUCE using cost_sum, but cost_sum is based on barry_mask.
                        
                        // Let's modify the flow slightly.
                        // In NEXT_MASK, we increment barry_mask.
                        // Then we go to a state (or back to CHECK_BRUCE) where we update current_cost and barry_seq.
                        // But CHECK_BRUCE needs barry_seq.
                        
                        // Solution:
                        // Stay in NEXT_MASK for 1 cycle to let barry_mask settle, then update registers.
                        // But we can't stay in same state easily without a flag.
                        // Let's add a state CALC_COST or reuse SETUP.
                        // Let's just combine logic: 
                        // We will update barry_mask. 
                        // Then we will jump to CHECK_BRUCE.
                        // In CHECK_BRUCE, before the loop, we will update current_cost and barry_seq based on the NEW barry_mask.
                        // Wait, if we update them in CHECK_BRUCE, we might overwrite intermediate steps if we stay in CHECK_BRUCE (iterating Bruce masks).
                        
                        // So the correct sequence is:
                        // NEXT_MASK -> CALC -> CHECK_BRUCE.
                        // CALC state: updates barry_seq and current_cost using barry_mask (which was incremented).
                        
                        state <= 3'b110; // Temporary CALC state
                    end
                end
                
                3'b110: begin // CALC state
                    // barry_mask was incremented in NEXT_MASK.
                    // Now compute corresponding values.
                    barry_seq <= seq_reg ^ barry_mask;
                    current_cost <= cost_sum;
                    // Reset Bruce mask
                    bruce_mask <= 0;
                    state <= CHECK_BRUCE;
                end

                DONE: begin
                    valid <= 1;
                    if (min_cost == 8'hFF) impossible <= 1;
                end
            endcase
        end
    end
    
    // Internal variables for balance check inside always block
    reg signed [5:0] bal;
    reg [3:0] open_cnt;
    reg is_bal;
    reg bit_val;
    
    // Note: The loop 'for (int k = 0; k < 16; k++)' inside always block is valid SystemVerilog.
    // But standard Verilog requires genvar or unrolled loops. 
    // To be strictly Verilog compatible and synthesizable without SV features, we should unroll or use a helper function.
    // However, the prompt says "SystemVerilog code".
    // If strictly Verilog, we can't declare int k inside.
    // Let's use a local integer 'k' defined at the top of the module.

endmodule

// Let's rewrite the module to be cleaner and strictly Verilog compliant where possible, using a helper task or logic.
// But nested loops in combinational logic are tricky.
// We can implement the Bruce check as a separate always block or function.
// Given the size (n=16), unrolling is feasible but verbose.

// Re-optimized structure to fit in one module without extra states if possible, but we need CALC state.

module barry_bruce_final (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [3:0] k_in,
    input [15:0] seq_in,
    input [127:0] costs_in,
    output reg [7:0] min_cost,
    output reg impossible,
    output reg valid
);

    localparam IDLE = 0;
    localparam SETUP = 1;
    localparam CHECK_BRUCE = 2;
    localparam UPDATE_MIN = 3;
    localparam NEXT_MASK = 4;
    localparam CALC_COST = 5;
    localparam DONE = 6;

    reg [3:0] state;
    reg [4:0] n_reg;
    reg [3:0] k_reg;
    reg [15:0] seq_reg;
    reg [127:0] costs_reg;

    reg [15:0] barry_mask;
    reg [15:0] barry_seq;
    reg [7:0] current_cost;

    reg [15:0] bruce_mask;
    reg bruce_found_fix;
    
    integer i;

    // Helper: Combinational cost sum
    reg [7:0] cost_sum;
    always @(*) begin
        cost_sum = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (barry_mask[i] && (i < n_reg)) begin
                cost_sum = cost_sum + costs_reg[i*8 +: 8];
            end
        end
    end

    // Helper: Combinational popcount for Bruce
    reg [3:0] pop_count;
    always @(*) begin
        pop_count = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (bruce_mask[i] && (i < n_reg)) pop_count = pop_count + 1;
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_cost <= 8'hFF;
            impossible <= 0;
            valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    impossible <= 0;
                    min_cost <= 8'hFF;
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        seq_reg <= seq_in;
                        costs_reg <= costs_in;
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    barry_mask <= 0;
                    // For mask 0, cost is 0, seq is original
                    barry_seq <= seq_reg;
                    current_cost <= 0;
                    bruce_mask <= 0;
                    bruce_found_fix <= 0; // Reset flag
                    state <= CHECK_BRUCE;
                end

                CHECK_BRUCE: begin
                    // Check current Bruce mask validity and balance
                    // 1. Increment logic or Check logic
                    
                    // If we just finished checking a mask (i.e., check done), we increment.
                    // But we need to check the CURRENT mask first.
                    
                    // Let's define a local variable for the check result
                    reg is_balanced;
                    reg signed [5:0] bal;
                    reg [3:0] open_cnt;
                    reg [15:0] temp_seq;
                    integer k;
                    
                    is_balanced = 1;
                    bal = 0;
                    open_cnt = 0;
                    temp_seq = barry_seq ^ bruce_mask;
                    
                    // Balance check
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < n_reg) begin
                            if (temp_seq[k]) bal = bal + 1;
                            else bal = bal - 1;
                            if (bal < 0) is_balanced = 0;
                            if (temp_seq[k]) open_cnt = open_cnt + 1;
                        end
                    end
                    if (bal != 0) is_balanced = 0;
                    if (n_reg[0]) is_balanced = 0; // n must be even
                    if (open_cnt != n_reg[4:1]) is_balanced = 0; // must have n/2 open
                    
                    // Check popcount
                    if (pop_count > k_reg) is_balanced = 0;
                    
                    // Logic Flow
                    if (bruce_mask >= (1 << n_reg)) begin
                        // Exhausted all masks without finding a fix
                        state <= UPDATE_MIN;
                    end else if (is_balanced) begin
                        // Found a fix for current mask
                        bruce_found_fix <= 1;
                        state <= NEXT_MASK;
                    end else begin
                        // Current mask not a fix, try next
                        bruce_mask <= bruce_mask + 1;
                        // Stay in CHECK_BRUCE
                    end
                end

                UPDATE_MIN: begin
                    if (!bruce_found_fix) begin
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                    end
                    state <= NEXT_MASK;
                end

                NEXT_MASK: begin
                    // Increment Barry mask
                    if (barry_mask == ((1 << n_reg) - 1)) begin
                        state <= DONE;
                    end else begin
                        barry_mask <= barry_mask + 1;
                        state <= CALC_COST;
                    end
                end

                CALC_COST: begin
                    // Update current_cost and barry_seq based on new barry_mask
                    barry_seq <= seq_reg ^ barry_mask;
                    current_cost <= cost_sum;
                    // Reset Bruce flags
                    bruce_mask <= 0;
                    bruce_found_fix <= 0;
                    state <= CHECK_BRUCE;
                end

                DONE: begin
                    valid <= 1;
                    if (min_cost == 8'hFF) begin
                        impossible <= 1;
                    end
                end
            endcase
        end
    end
endmodule
