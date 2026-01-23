module arcaea_diversity(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] frag [0:7],
    input [7:0] step [0:7],
    input [7:0] frag_awaken [0:7],
    input [7:0] step_awaken [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001;
    localparam ENUMERATE = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam UPDATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;
    
    // Registers for inputs
    reg [2:0] n_reg;
    reg [2:0] k_reg;
    reg [7:0] frag_reg [0:7];
    reg [7:0] step_reg [0:7];
    reg [7:0] frag_awaken_reg [0:7];
    reg [7:0] step_awaken_reg [0:7];
    
    // Combination counter
    reg [7:0] combination; // Bit i = 1 means partner i is awakened
    reg [2:0] awaken_count; // Number of 1s in combination
    reg [2:0] partner_idx; // Index for iterating through partners
    reg [2:0] compare_idx; // Index for comparing partners
    
    // Validity check
    reg combination_valid;
    
    // Diversity calculation
    reg [3:0] current_diversity;
    reg [3:0] max_diversity_reg;
    
    // Partner state storage
    reg [7:0] current_frag [0:7];
    reg [7:0] current_step [0:7];
    
    // Combinational helper signals
    wire [7:0] pair_frag_i;
    wire [7:0] pair_step_i;
    wire [7:0] pair_frag_j;
    wire [7:0] pair_step_j;
    wire i_dominates_j;
    wire j_dominates_i;
    
    // Assign helper wires
    assign pair_frag_i = current_frag[partner_idx];
    assign pair_step_i = current_step[partner_idx];
    assign pair_frag_j = (compare_idx < n_reg) ? current_frag[compare_idx] : 8'b0;
    assign pair_step_j = (compare_idx < n_reg) ? current_step[compare_idx] : 8'b0;
    
    // Dominance conditions: i dominates j if both frag and step are strictly greater
    assign i_dominates_j = (pair_frag_i > pair_frag_j) && (pair_step_i > pair_step_j);
    assign j_dominates_i = (pair_frag_j > pair_frag_i) && (pair_step_j > pair_step_i);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PREPARE;
                else next_state = IDLE;
            end
            PREPARE: begin
                next_state = ENUMERATE;
            end
            ENUMERATE: begin
                if (combination_valid && awaken_count <= k_reg) 
                    next_state = COMPUTE;
                else if (combination == 8'hFF) // All combinations checked
                    next_state = DONE;
                else 
                    next_state = ENUMERATE;
            end
            COMPUTE: begin
                // Iterate through all pairs to count antichain
                if (partner_idx >= n_reg)
                    next_state = UPDATE;
                else
                    next_state = COMPUTE;
            end
            UPDATE: begin
                next_state = ENUMERATE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 4'b0;
            combination <= 8'b0;
            awaken_count <= 3'b0;
            max_diversity_reg <= 4'b0;
            current_diversity <= 4'b0;
            partner_idx <= 3'b0;
            compare_idx <= 3'b0;
            combination_valid <= 1'b0;
            // Reset arrays not strictly needed but good practice
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                PREPARE: begin
                    // Capture inputs
                    n_reg <= n;
                    k_reg <= k;
                    // Copy arrays
                    frag_reg[0] <= frag[0]; frag_reg[1] <= frag[1]; frag_reg[2] <= frag[2]; frag_reg[3] <= frag[3];
                    frag_reg[4] <= frag[4]; frag_reg[5] <= frag[5]; frag_reg[6] <= frag[6]; frag_reg[7] <= frag[7];
                    step_reg[0] <= step[0]; step_reg[1] <= step[1]; step_reg[2] <= step[2]; step_reg[3] <= step[3];
                    step_reg[4] <= step[4]; step_reg[5] <= step[5]; step_reg[6] <= step[6]; step_reg[7] <= step[7];
                    frag_awaken_reg[0] <= frag_awaken[0]; frag_awaken_reg[1] <= frag_awaken[1]; frag_awaken_reg[2] <= frag_awaken[2]; frag_awaken_reg[3] <= frag_awaken[3];
                    frag_awaken_reg[4] <= frag_awaken[4]; frag_awaken_reg[5] <= frag_awaken[5]; frag_awaken_reg[6] <= frag_awaken[6]; frag_awaken_reg[7] <= frag_awaken[7];
                    step_awaken_reg[0] <= step_awaken[0]; step_awaken_reg[1] <= step_awaken[1]; step_awaken_reg[2] <= step_awaken[2]; step_awaken_reg[3] <= step_awaken[3];
                    step_awaken_reg[4] <= step_awaken[4]; step_awaken_reg[5] <= step_awaken[5]; step_awaken_reg[6] <= step_awaken[6]; step_awaken_reg[7] <= step_awaken[7];
                    
                    combination <= 8'b0;
                    max_diversity_reg <= 4'b0;
                    combination_valid <= 1'b1; // 0 is valid (0 awakenings)
                    awaken_count <= 3'b0;
                end
                
                ENUMERATE: begin
                    // Increment combination and check validity
                    if (combination_valid && awaken_count <= k_reg) begin
                        // Move to compute state, keep current combination
                    end else begin
                        // Generate next combination
                        // Simple binary increment
                        combination <= combination + 1;
                        // Recalculate popcount logic or increment counter
                        // Optimized: Popcount of combination + 1
                        // For simplicity in sequential logic, let's just check validity in next cycle or combinational
                        // We will use a separate combinational block to check valid/awaken_count for next state
                    end
                end
                
                COMPUTE: begin
                    // Build current_frag/step arrays based on combination bits
                    // This runs once at start of COMPUTE or iteratively. 
                    // Let's do this combinationally or in PREPARE/ENUMERATE transition.
                    // Actually, doing it iteratively here:
                    // We will fill current_frag/step as we iterate partners
                    
                    // Optimization: Calculate values when entering COMPUTE
                    // But since state transitions are slow, we can do it in the loop or pre-calc.
                    // Let's pre-calculate in ENUMERATE or use combinational logic inside COMPUTE.
                    // We will use combinational logic to select frag/step based on combination bit.
                    
                    // Counting antichain logic:
                    // partner_idx iterates 0 to n-1.
                    // compare_idx iterates 0 to n-1.
                    // We need to track if current partner (partner_idx) is dominated by any previous or next.
                    // Let's use a flag 'is_dominated'.
                    // Wait, standard antichain algorithm: Mark all dominated nodes.
                    // Easier approach:
                    // 1. Fill current_frag/step array (done in combinational block or state logic)
                    // 2. Iterate partner_idx. Check dominance against all compare_idx.
                    // 3. If dominated by anyone, skip. If not, increment count.
                    
                    // Let's implement the dominance check logic.
                    // We need a temp variable to track if the current partner_idx is dominated.
                    // Since we can't easily have local variables in always block without declaring them.
                    // We will use a 'valid_member' register to track the count.
                    
                    if (partner_idx == 0 && compare_idx == 0) begin
                        // Start of compute for this combination
                        // Pre-calculate current_frag/step states here or use combinational logic
                        // Let's do it here incrementally if needed, or purely combinationally for logic simplicity.
                        // Given the prompt says 'Use combinational blocks for dominance checking', we can assume.
                    end
                    
                    // We need to iterate. Logic flow:
                    // Partner Loop: partner_idx 0 -> n-1
                    //   Inner Loop: compare_idx 0 -> n-1
                    //     Check if partner_idx is dominated by compare_idx.
                    //     If yes, mark invalid.
                    //   If not invalid, count++.
                end
                
                UPDATE: begin
                    // Update max_diversity if current is higher
                    if (current_diversity > max_diversity_reg) begin
                        max_diversity_reg <= current_diversity;
                    end
                    
                    // Reset counters for next combination
                    current_diversity <= 4'b0;
                    partner_idx <= 3'b0;
                    compare_idx <= 3'b0;
                end
                
                DONE: begin
                    result <= max_diversity_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational logic for Enumerator and Compute details
    // These update the registers that control the flow
    
    // Helper to calculate popcount of combination
    reg [2:0] popcount;
    integer i;
    always @(*) begin
        popcount = 3'b0;
        for (i = 0; i < 8; i = i + 1) begin
            popcount = popcount + combination[i];
        end
    end
    
    // Combinational block for ENUMERATE and COMPUTE control signals
    // We need to separate combinational next-state-data from sequential update
    // But to keep it simple and synthesizable with one always block, we'll handle specific logic here.
    // Actually, standard practice is to derive next values in combinational logic, then assign in sequential.
    // Let's use a separate always @(*) block for complex logic.
    
    reg [3:0] next_diversity;
    reg [2:0] next_partner_idx;
    reg [2:0] next_compare_idx;
    reg [7:0] next_combination;
    reg [2:0] next_awaken_count;
    reg is_dominated;
    reg [7:0] temp_frag_i, temp_step_i, temp_frag_j, temp_step_j;
    
    always @(*) begin
        // Defaults
        next_combination = combination;
        next_awaken_count = awaken_count;
        next_partner_idx = partner_idx;
        next_compare_idx = compare_idx;
        next_diversity = current_diversity;
        is_dominated = 1'b0;
        
        // State specific combinational logic
        case (state)
            PREPARE: begin
                next_combination = 8'b0;
                next_awaken_count = 3'b0;
                next_partner_idx = 3'b0;
                next_compare_idx = 3'b0;
                next_diversity = 4'b0;
            end
            
            ENUMERATE: begin
                if (combination_valid && awaken_count <= k_reg) begin
                    // Valid, stay same, but state machine will transition to COMPUTE
                    // No change to registers needed for compute start
                end else begin
                    // Increment combination logic
                    next_combination = combination + 1;
                    // Recalculate popcount for new combination
                    // We need popcount of next_combination to check condition in next cycle
                    // Since popcount calculation is combinational, we can use it for check in always block if we are careful.
                    // But we need to update awaken_count register.
                    // Let's calculate popcount of next_combination here.
                    next_awaken_count = 3'b0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (next_combination[i]) next_awaken_count = next_awaken_count + 1;
                    end
                    
                    // Check validity of NEW combination immediately?
                    // In sequential logic, we need to check validity of CURRENT combination to decide transition.
                    // The previous combinational block 'combination_valid' handles current check.
                    // So we just increment here.
                end
            end
            
            COMPUTE: begin
                // Get values for current indices
                // Determine if partner[partner_idx] is awakened
                if (combination[partner_idx]) begin
                    temp_frag_i = frag_awaken_reg[partner_idx];
                    temp_step_i = step_awaken_reg[partner_idx];
                end else begin
                    temp_frag_i = frag_reg[partner_idx];
                    temp_step_i = step_reg[partner_idx];
                end
                
                // Determine values for partner[compare_idx]
                // Note: If compare_idx == partner_idx, we skip (or it won't dominate itself unless >=)
                if (compare_idx < n_reg) begin
                    if (combination[compare_idx]) begin
                        temp_frag_j = frag_awaken_reg[compare_idx];
                        temp_step_j = step_awaken_reg[compare_idx];
                    end else begin
                        temp_frag_j = frag_reg[compare_idx];
                        temp_step_j = step_reg[compare_idx];
                    end
                end else begin
                    temp_frag_j = 8'b0;
                    temp_step_j = 8'b0;
                end
                
                // Check dominance
                // If partner_idx != compare_idx
                if (partner_idx != compare_idx && compare_idx < n_reg) begin
                    // j dominates i if j > i in both
                    if ((temp_frag_j > temp_frag_i) && (temp_step_j > temp_step_i)) begin
                        is_dominated = 1'b1;
                    end
                end
                
                // Update indices and diversity count
                if (compare_idx < n_reg - 1) begin
                    // Continue inner loop
                    next_compare_idx = compare_idx + 1;
                end else begin
                    // End of inner loop
                    next_compare_idx = 3'b0;
                    
                    // If not dominated, increment diversity
                    if (!is_dominated && partner_idx < n_reg) begin
                        next_diversity = current_diversity + 1;
                    end
                    
                    // Move to next partner
                    if (partner_idx < n_reg) begin
                        next_partner_idx = partner_idx + 1;
                    end
                end
            end
            
            UPDATE: begin
                // Reset computed values
                next_partner_idx = 3'b0;
                next_compare_idx = 3'b0;
                next_diversity = 4'b0;
                
                // Generate next combination for next ENUMERATE cycle
                // We must do this here to be ready for ENUMERATE state check
                next_combination = combination + 1;
                next_awaken_count = 3'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (next_combination[i]) next_awaken_count = next_awaken_count + 1;
                end
            end
        endcase
    end
    
    // Validity check combinational
    // Check if current combination has <= k awakenings and valid inputs
    // Also checks if we exceeded max combinations
    // Note: We need to check if the 'next_combination' (which is stored in register after update) is valid.
    // Or we check current combination's validity.
    // In ENUMERATE state, we want to check if current 'combination' (which was just incremented or 0) is valid.
    
    always @(*) begin
        combination_valid = 1'b0;
        if (k_reg <= 4 && n_reg <= 8) begin
            if (awaken_count <= k_reg) begin
                combination_valid = 1'b1;
            end
        end
    end
    
    // Separate sequential update for registers modified by combinational block
    // We need to merge the defaults with the state updates.
    // The previous sequential always block handles general flow.
    // We need to ensure that registers updated in the combinational block are also updated in sequential block.
    // To avoid conflicts, let's integrate the assignments into the main sequential block.
    
    // Re-writing the main sequential block to incorporate computed next values
    // This avoids having two always blocks writing to the same signals.
    
    // Override the previous sequential block content with this integrated version:
    // (I will merge the logic conceptually)
    
    // Let's refine the sequential block to use the combinational logic outputs.
    // We need a way to signal updates. 
    // However, the instructions require valid Verilog. 
    // Let's stick to the standard Single Always Block with Combinational Next Logic style.
    
    // The code below is a consolidated version replacing the two blocks above.
    // (I am writing a new combined block to be correct)

endmodule

// Supporting logic for the state machine:
// Since Verilog requires variables to be defined before use, 
// and we want a single module, we need to be careful with ordering.
// The previous code block was structured to separate concerns.
// To make it strictly correct, we must ensure the sequential block handles the updates.

// Corrected Integrated Module Structure:

`begin_keywords "1800-2017"
module arcaea_diversity_final(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] frag [0:7],
    input [7:0] step [0:7],
    input [7:0] frag_awaken [0:7],
    input [7:0] step_awaken [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001;
    localparam ENUMERATE = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam UPDATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] n_reg;
    reg [2:0] k_reg;
    reg [7:0] frag_reg [0:7];
    reg [7:0] step_reg [0:7];
    reg [7:0] frag_awaken_reg [0:7];
    reg [7:0] step_awaken_reg [0:7];
    reg [7:0] combination;
    reg [2:0] awaken_count;
    reg [2:0] partner_idx;
    reg [2:0] compare_idx;
    reg [3:0] current_diversity;
    reg [3:0] max_diversity_reg;
    
    // Combinational logic for popcount
    integer i;
    reg [2:0] next_awaken_count;
    always @(*) begin
        next_awaken_count = 3'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (combination[i]) next_awaken_count = next_awaken_count + 1;
        end
    end
    
    // Combinational logic for dominance check
    reg [7:0] val_i_frag, val_i_step;
    reg [7:0] val_j_frag, val_j_step;
    reg is_dominated;
    
    always @(*) begin
        // Get values for i
        if (combination[partner_idx]) begin
            val_i_frag = frag_awaken_reg[partner_idx];
            val_i_step = step_awaken_reg[partner_idx];
        end else begin
            val_i_frag = frag_reg[partner_idx];
            val_i_step = step_reg[partner_idx];
        end
        
        // Get values for j
        if (compare_idx < n_reg) begin
            if (combination[compare_idx]) begin
                val_j_frag = frag_awaken_reg[compare_idx];
                val_j_step = step_awaken_reg[compare_idx];
            end else begin
                val_j_frag = frag_reg[compare_idx];
                val_j_step = step_reg[compare_idx];
            end
        end else begin
            val_j_frag = 8'b0;
            val_j_step = 8'b0;
        end
        
        // Check dominance
        is_dominated = 1'b0;
        if (partner_idx != compare_idx && compare_idx < n_reg) begin
            if (val_j_frag > val_i_frag && val_j_step > val_i_step) begin
                is_dominated = 1'b1;
            end
        end
    end

    // State Machine and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'b0;
            combination <= 8'b0;
            awaken_count <= 3'b0;
            max_diversity_reg <= 4'b0;
            current_diversity <= 4'b0;
            partner_idx <= 3'b0;
            compare_idx <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= PREPARE;
                end
                
                PREPARE: begin
                    // Capture Inputs
                    n_reg <= n;
                    k_reg <= k;
                    for (i = 0; i < 8; i = i + 1) begin
                        frag_reg[i] <= frag[i];
                        step_reg[i] <= step[i];
                        frag_awaken_reg[i] <= frag_awaken[i];
                        step_awaken_reg[i] <= step_awaken[i];
                    end
                    // Reset State
                    combination <= 8'b0;
                    awaken_count <= 3'b0;
                    max_diversity_reg <= 4'b0;
                    current_diversity <= 4'b0;
                    partner_idx <= 3'b0;
                    compare_idx <= 3'b0;
                    state <= ENUMERATE;
                end
                
                ENUMERATE: begin
                    // Check validity of CURRENT combination
                    // next_awaken_count combinational signal reflects current combination
                    if (next_awaken_count <= k_reg && next_awaken_count != 0) begin 
                        // If valid and not just the 0 case handled by PREPARE transition? 
                        // Actually, PREPARE sets combo to 0. We should check it.
                        // But we need to count 0 awakenings too. 
                        // Logic: PREPARE sets 0. Check if 0 <= k. Then enter compute.
                        // If invalid (too many awakenings) or just computed, increment.
                        // Let's refine the flow:
                    end
                    
                    // Refined Enumerate Logic:
                    // If combination is valid (awaken_count <= k), go to COMPUTE.
                    // Else, increment.
                    // Stop condition: If combination reaches end (e.g. 2^n) and k is small.
                    // We will loop until combination > 255 (or 2^n).
                    
                    if (next_awaken_count <= k_reg) begin
                        // Valid combination, go compute
                        // Note: We must handle the case where combination is 0.
                        // If n is 0? handled by constraints. 
                        // If n=8, k=4, 0 is valid (0 <= 4).
                        state <= COMPUTE;
                        partner_idx <= 3'b0;
                        compare_idx <= 3'b0;
                        current_diversity <= 4'b0;
                        // Check for 0 awakening case explicitly if needed, but logic handles it.
                        // Special case: if n=0 or k=0, 0 is valid. 
                    end else begin
                        // Invalid (too many awakenings), increment
                        // Also, if we have exhausted all combinations (255 -> 0)??
                        // We check if combination == 8'hFF and we just incremented?
                        // Simpler: Just increment. If we hit 255 and it's invalid, next is 0.
                        // We can stop when combination wraps around to 0.
                        // But we need to distinguish wrap from start.
                        // Let's use a flag or just loop 256 times.
                        // Let's just increment. 
                        combination <= combination + 1;
                        
                        // Check for termination: If we have passed the max possible valid combination?
                        // If combination == 0 (wrapped) and we started at 0 in PREPARE (or after valid), we are done.
                        // Wait, if we start at 0, check valid. If valid, compute. If not, increment.
                        // If we increment 255 -> 0, and 0 is valid, we will re-compute 0.
                        // To prevent infinite loop, we need to know when we are done.
                        // We are done when we have visited all combinations 0..255.
                        // We can use a 'visited_all' flag or counter.
                        // Or simpler: Since n <= 8, we can assume we want to visit all 2^n subsets of n partners.
                        // But input array size is fixed 8. 
                        // If n < 8, we only care about first n bits. 
                        // Actually, we should probably just iterate 2^n times, not 2^8.
                        // Let's use a separate loop counter for 'cycles'.
                        // Let's assume we iterate 256 times for simplicity given n <= 8.
                        // If combination wraps to 0 and we have already computed 0 (valid), we are done.
                        // But we skip invalid. 
                        
                        // Let's change termination: Stop when partner_idx >= n and we are done updating? No.
                        // Let's rely on a timeout or explicit 'all combinations visited'.
                        // We will add a 'cycles' counter or simply stop when combination == 0 after incrementing.
                        
                        // Decision: To keep it simple, iterate 2^n times where n is provided. 
                        // But n is variable. 
                        // Let's use a loop counter 'iter_count'.
                    end
                end
                
                COMPUTE: begin
                    // Dominance Check Logic
                    // If currently dominated, we skip to next partner
                    // If not dominated after checking all j, increment diversity
                    
                    // We need to iterate j. 
                    // Compare_idx loop.
                    // If is_dominated (combinational), we can stop checking for this i? 
                    // Yes, if dominated, we don't care about other j's.
                    // So: if is_dominated, go to next i.
                    // If !is_dominated and compare_idx reaches end, increment count.
                    
                    if (is_dominated) begin
                        // i is dominated, skip to next i
                        if (partner_idx < n_reg) begin
                            partner_idx <= partner_idx + 1;
                            compare_idx <= 3'b0;
                        end else begin
                            state <= UPDATE;
                        end
                    end else begin
                        // Not dominated yet, check next j
                        if (compare_idx < n_reg - 1) begin
                            compare_idx <= compare_idx + 1;
                        end else begin
                            // Finished checking all j, i is not dominated
                            current_diversity <= current_diversity + 1;
                            partner_idx <= partner_idx + 1;
                            compare_idx <= 3'b0;
                        end
                    end
                    
                    // Edge case: if n_reg is 0, skip compute entirely? handled by state transition.
                    // Start condition: partner_idx=0, compare_idx=0.
                    // If n_reg == 0, we shouldn't enter COMPUTE.
                    // If n_reg > 0, enter.
                    if (partner_idx >= n_reg) begin
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    // Update Max
                    if (current_diversity > max_diversity_reg) begin
                        max_diversity_reg <= current_diversity;
                    end
                    
                    // Next Combination
                    if (combination == 8'hFF) begin
                        state <= DONE;
                    end else begin
                        combination <= combination + 1;
                        state <= ENUMERATE;
                    end
                end
                
                DONE: begin
                    result <= max_diversity_reg;
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Reset on start falling edge or wait for reset
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Fix for infinite loop in ENUMERATE:
    // The 'Update' state handles the increment. 
    // In ENUMERATE, we check validity. 
    // But we need to ensure 0 awakening is checked. 
    // PREPARE sets combo=0. Transition to ENUMERATE. 
    // ENUMERATE sees combo=0. next_awaken_count=0. Valid. Go COMPUTE.
    // Compute. Update. Increment combo to 1.
    // Back to ENUMERATE. Check validity. Go COMPUTE or increment.
    // Eventually combo wraps to 0? No, 255 -> 0.
    // If we hit 255, Update sets combo to 0. ENUMERATE sees 0. 
    // This loops.
    // We need to stop after visiting all 2^n possibilities.
    // Let's change Update: If we just incremented to 0, go DONE.
    // Wait, Update does: current_diversity > max. Then sets combination <= combo + 1.
    // If we are at combination = 255, combo + 1 = 0.
    // So after Update, if combo becomes 0, we should be done.
    // So in Update: 
    // if (combination == 8'hFF) state <= DONE; else ...
    
    // Wait, we also need to handle the case where k is small and we skip many combinations.
    // If we are at 255, and it's invalid, Update state is not reached (ENUMERATE increments directly).
    // If we are at 255, invalid, ENUMERATE increments -> 0.
    // Next cycle ENUMERATE checks 0.
    // So we need to track that we visited everything.
    // Let's use a flag or counter.
    // Let's add a 'checked_all' bit that sets when combination becomes 0 again.
    // But if valid combinations exist, we might need to visit them.
    // Let's add a 'passed_zero' flag.
    
    // Re-logic for ENUMERATE/UPDATE termination:
    // Use a 'wrapping' signal. 
    // Actually, since n is max 8, we can just iterate 2^n times.
    // But n is variable. If n=4, we should iterate 16 times, not 256.
    // The prompt says 'enumerate all awakening combinations (2^n possibilities)'.
    // So we should respect n.
    // Let's add a loop counter `loop_cnt` that goes 0 to 2^n - 1.
    // But iterating 2^n cycles might be too fast? No, the state machine does multiple cycles per combination.
    // Let's stick to iterating through the binary code.
    // The cleanest way is to limit the bits we increment? No, inputs are fixed size 8.
    // If n=4, partners 0..3. Bits 4..7 are ignored (forced 0 or don't care).
    // But we need to generate 2^n combinations.
    // If n=4, we want 00000000, 00000001, ... 00001111.
    // We can't just increment to 16 because 16 is 00010000.
    // So we need a specific counter that counts up to 2^n.
    // Let's change `combination` to a shift register or specific counter.
    // Or simpler: In ENUMERATE, if `combination` has any bit set >= n, treat it as invalid and skip? 
    // No, that's not 2^n.
    // We need a counter `comb_index` from 0 to 2^n - 1, and map that to `combination` bits.
    // But that mapping requires logic.
    // Given the latency is `2^8 * n^2`, maybe we just iterate 256 times and mask? 
    // If we iterate 256 times, for n=4, we see 00000000..00001111 (16 valid) and 00010000..11111111 (240 invalid).
    // If we just iterate 256 times, we cover all subsets of 8, and ignore bits >= n by treating partners >= n as missing?
    // The problem says 'partners (max 8)'. Input arrays are size 8. 
    // If n=4, we only care about first 4 inputs.
    // If we iterate 0..255, we might wake up partners 4,5,6,7 which don't exist.
    // The problem implies we have exactly n partners.
    // So we must NOT generate combinations for partners >= n.
    // This means we need a variable-width counter.
    // Simplest synthesizable way: 
    // Use `comb_val` which is `2^n`.
    // Use a register `comb_counter` counting 0 to `comb_val - 1`.
    // Then `combination` is just `comb_counter` (binary).
    // If `comb_counter` reaches `comb_val`, we are done.
    // `comb_val` is 1 << n.
    
    // Let's add `comb_max` and `comb_cnt`.
    // comb_max = 1 << n.
    // comb_cnt = current combination index.
    // combination = comb_cnt (limited to 8 bits, but effectively checks only lower n bits).
    
    // This is much cleaner.
    
    // Let's adjust the code to use `comb_cnt` and `comb_max`.

endmodule
`end_keywords

// Final code structure using the cleaner approach:

module arcaea_diversity(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] frag [0:7],
    input [7:0] step [0:7],
    input [7:0] frag_awaken [0:7],
    input [7:0] step_awaken [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001;
    localparam ENUMERATE = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam UPDATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] n_reg;
    reg [2:0] k_reg;
    reg [7:0] frag_reg [0:7];
    reg [7:0] step_reg [0:7];
    reg [7:0] frag_awaken_reg [0:7];
    reg [7:0] step_awaken_reg [0:7];
    
    // Enumerators
    reg [7:0] combination; // Binary representation of awakening set
    reg [8:0] comb_max;    // 2^n
    reg [8:0] comb_cnt;    // 0 to comb_max-1
    
    // Compute counters
    reg [2:0] partner_idx;
    reg [2:0] compare_idx;
    reg [3:0] current_diversity;
    reg [3:0] max_diversity_reg;
    reg is_dominated; // Local flag for compute loop

    // Helper for popcount
    integer i;
    reg [2:0] awaken_count;
    always @(*) begin
        awaken_count = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (combination[i]) awaken_count = awaken_count + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'b0;
            max_diversity_reg <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= PREPARE;
                end
                
                PREPARE: begin
                    // Copy inputs
                    n_reg <= n;
                    k_reg <= k;
                    for (i = 0; i < 8; i = i + 1) begin
                        frag_reg[i] <= frag[i];
                        step_reg[i] <= step[i];
                        frag_awaken_reg[i] <= frag_awaken[i];
                        step_awaken_reg[i] <= step_awaken[i];
                    end
                    // Setup Enumerators
                    // 2^n calculation
                    comb_max <= 9'b000000001 << n; 
                    comb_cnt <= 9'b0;
                    combination <= 8'b0;
                    // Reset Max
                    max_diversity_reg <= 4'b0;
                    
                    // If n == 0, skip directly to DONE? Or handle 0 partners.
                    // If n=0, no partners, diversity 0.
                    // Let's handle n=0 in IDLE or PREPARE if needed, but let state machine handle it.
                    
                    state <= ENUMERATE;
                end
                
                ENUMERATE: begin
                    // Check if we finished all combinations
                    if (comb_cnt >= comb_max) begin
                        state <= DONE;
                    end else begin
                        // Check validity (awakenings <= k)
                        // comb_cnt is the binary combination (since we iterate 0..2^n-1)
                        // Note: comb_cnt is 9 bits, combination is 8 bits. 
                        // Since n <= 8, comb_cnt[7:0] works. comb_cnt[8] is only for n=8 (256) check.
                        // Wait, 2^n for n=8 is 256. comb_cnt goes 0..255. 
                        // comb_max = 256.
                        // combination <= comb_cnt[7:0].
                        combination <= comb_cnt[7:0];
                        
                        if (awaken_count <= k_reg) begin
                            // Valid combination, start compute
                            state <= COMPUTE;
                            partner_idx <= 3'b0;
                            compare_idx <= 3'b0;
                            current_diversity <= 4'b0;
                            // Handle n=0 case immediately
                            if (n_reg == 3'b0) begin
                                // No partners, antichain size 0
                                current_diversity <= 4'b0;
                                state <= UPDATE; // Skip compute loop
                            end
                        end else begin
                            // Invalid, skip to next
                            comb_cnt <= comb_cnt + 1;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Dominance Check Logic
                    // Get values for i (partner_idx)
                    // Since n_reg <= 8, partner_idx < n_reg implies valid index.
                    
                    // Combinational dominance check logic (inlined for clarity)
                    // We need to calculate is_dominated based on current partner_idx, compare_idx, combination
                    
                    // Values for i
                    // Note: If combination[partner_idx] is 1, use awaked. Else normal.
                    // This block assumes logic is computed combinatorially before this clock edge or inside.
                    // To be safe in sequential block, we calculate 'is_dominated' based on previous cycle or use combinational block.
                    // Let's define the logic explicitly here.
                    
                    // Calculate dominance for current (i, j)
                    is_dominated <= 1'b0; // Default reset for pipeline, but we need state.
                    // Actually, we need to check current (i,j). 
                    // Let's use combinational logic to drive 'is_dominated' and then use it here.
                    // But since we are in sequential block, we should sample inputs.
                    // Let's create a combinational wire `curr_dominated`.
                end
                
                UPDATE: begin
                    // Update max
                    if (current_diversity > max_diversity_reg) begin
                        max_diversity_reg <= current_diversity;
                    end
                    // Next combination
                    comb_cnt <= comb_cnt + 1;
                    state <= ENUMERATE;
                end
                
                DONE: begin
                    result <= max_diversity_reg;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational dominance check for Compute state
    // This logic runs continuously and updates registers or signals used in state machine.
    // Since the state machine iterates (i, j), we need to compute the result of (i, j) comparison.
    // But wait, we can't easily do loops in combinational logic without blocking.
    // The request asks for 'Use combinational blocks for dominance checking within each state'.
    // And 'Parallel comparators'.
    // This suggests checking all pairs for a *fixed* combination to find the antichain size.
    // The prompt's state machine suggestion (ENUMERATE -> COMPUTE -> UPDATE) implies COMPUTE calculates diversity for *one* combination.
    // And it says 'Use parallel comparators'.
    // So, in COMPUTE state, we should calculate the diversity of the current combination fully, then move to UPDATE.
    // This means COMPUTE state might take multiple cycles OR we use a combinational block to calculate it instantly.
    // Given the latency estimate 2^n * n^2, it implies checking n^2 pairs per combination.
    // So COMPUTE state takes n^2 cycles (or n cycles with parallelism).
    // Let's implement the logic:
    // In COMPUTE state, we iterate partners i and j.
    // We need to track 'is_dominated' for current i.
    
    // Let's refine the COMPUTE state logic in the always block to handle the iteration.
    // And use a combinational block to calculate 'is_dominated' for the current (i, j).
    
    wire curr_val_i_frag, curr_val_i_step;
    wire curr_val_j_frag, curr_val_j_step;
    wire curr_dominated;
    
    assign curr_val_i_frag = combination[partner_idx] ? frag_awaken_reg[partner_idx] : frag_reg[partner_idx];
    assign curr_val_i_step = combination[partner_idx] ? step_awaken_reg[partner_idx] : step_reg[partner_idx];
    
    assign curr_val_j_frag = (compare_idx < n_reg) ? (combination[compare_idx] ? frag_awaken_reg[compare_idx] : frag_reg[compare_idx]) : 8'b0;
    assign curr_val_j_step = (compare_idx < n_reg) ? (combination[compare_idx] ? step_awaken_reg[compare_idx] : step_reg[compare_idx]) : 8'b0;
    
    assign curr_dominated = (compare_idx != partner_idx) && (compare_idx < n_reg) &&
                            (curr_val_j_frag > curr_val_i_frag) && (curr_val_j_step > curr_val_i_step);

    // We need to modify the COMPUTE state in the sequential block to use this.
    // Revising the COMPUTE state logic in the always block above:
    
    /*
    COMPUTE: begin
        // We need to process the loops.
        // The loop is: for i in 0..n-1: for j in 0..n-1: if j dominates i, mark i invalid.
        // If i not invalid after all j, count++.
        
        // Since we are in a clocked block, we implement the loop variables.
        // However, we have a race condition if we use 'curr_dominated' directly.
        // 'curr_dominated' reflects the condition for CURRENT values of idx.
        
        // Strategy:
        // 1. If curr_dominated is true, then i is dominated. We can skip to next i.
        //    (Set partner_idx++, reset compare_idx).
        // 2. If curr_dominated is false, we must check next j.
        //    (Increment compare_idx).
        // 3. When compare_idx reaches n (end of loop for current i):
        //    If i was never dominated (we need to track this), increment diversity.
        //    Wait, how do we track 'never dominated'?
        //    If curr_dominated is false for the last j, but true for previous?
        //    We need a flag `i_is_dominated` that persists for the duration of the i loop.
        
        // So, we need a register `i_dominated_flag` that is set if `curr_dominated` is true at any point during j loop.
        
        // Let's update the sequential block with this refined logic.
        // And add `i_dominated_flag` register.
    */

endmodule

// To provide the final code, I will use the refined logic with the `i_dominated_flag`.

module arcaea_diversity (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] frag [0:7],
    input [7:0] step [0:7],
    input [7:0] frag_awaken [0:7],
    input [7:0] step_awaken [0:7],
    output reg [3:0] result,
    output reg done
);

    localparam IDLE = 3'b000, PREPARE = 3'b001, ENUMERATE = 3'b010, 
               COMPUTE = 3'b011, UPDATE = 3'b100, DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] n_reg, k_reg;
    reg [7:0] frag_reg [0:7], step_reg [0:7];
    reg [7:0] frag_awaken_reg [0:7], step_awaken_reg [0:7];
    
    reg [8:0] comb_cnt; 
    wire [7:0] combination; 
    reg [8:0] comb_max;
    
    reg [2:0] partner_idx;
    reg [2:0] compare_idx;
    reg i_dominated_flag;
    reg [3:0] current_diversity;
    reg [3:0] max_diversity_reg;
    
    integer i;
    wire [2:0] awaken_count;
    wire [7:0] val_i_frag, val_i_step;
    wire [7:0] val_j_frag, val_j_step;
    wire curr_dominated;

    // Combinational helper signals
    assign combination = comb_cnt[7:0]; // Lower 8 bits for 8 partners
    
    assign awaken_count = combination[0] + combination[1] + combination[2] + combination[3] + 
                         combination[4] + combination[5] + combination[6] + combination[7];
                         
    assign val_i_frag = combination[partner_idx] ? frag_awaken_reg[partner_idx] : frag_reg[partner_idx];
    assign val_i_step = combination[partner_idx] ? step_awaken_reg[partner_idx] : step_reg[partner_idx];
    
    assign val_j_frag = (compare_idx < n_reg) ? (combination[compare_idx] ? frag_awaken_reg[compare_idx] : frag_reg[compare_idx]) : 8'b0;
    assign val_j_step = (compare_idx < n_reg) ? (combination[compare_idx] ? step_awaken_reg[compare_idx] : step_reg[compare_idx]) : 8'b0;
    
    assign curr_dominated = (compare_idx != partner_idx) && (compare_idx < n_reg) && 
                            (val_j_frag > val_i_frag) && (val_j_step > val_i_step);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'b0;
            max_diversity_reg <= 4'b0;
            comb_cnt <= 9'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= PREPARE;
                end
                
                PREPARE: begin
                    n_reg <= n;
                    k_reg <= k;
                    // Copy arrays (unrolled for synthesis)
                    frag_reg[0] <= frag[0]; frag_reg[1] <= frag[1]; frag_reg[2] <= frag[2]; frag_reg[3] <= frag[3];
                    frag_reg[4] <= frag[4]; frag_reg[5] <= frag[5]; frag_reg[6] <= frag[6]; frag_reg[7] <= frag[7];
                    step_reg[0] <= step[0]; step_reg[1] <= step[1]; step_reg[2] <= step[2]; step_reg[3] <= step[3];
                    step_reg[4] <= step[4]; step_reg[5] <= step[5]; step_reg[6] <= step[6]; step_reg[7] <= step[7];
                    frag_awaken_reg[0] <= frag_awaken[0]; frag_awaken_reg[1] <= frag_awaken[1]; frag_awaken_reg[2] <= frag_awaken[2]; frag_awaken_reg[3] <= frag_awaken[3];
                    frag_awaken_reg[4] <= frag_awaken[4]; frag_awaken_reg[5] <= frag_awaken[5]; frag_awaken_reg[6] <= frag_awaken[6]; frag_awaken_reg[7] <= frag_awaken[7];
                    step_awaken_reg[0] <= step_awaken[0]; step_awaken_reg[1] <= step_awaken[1]; step_awaken_reg[2] <= step_awaken[2]; step_awaken_reg[3] <= step_awaken[3];
                    step_awaken_reg[4] <= step_awaken[4]; step_awaken_reg[5] <= step_awaken[5]; step_awaken_reg[6] <= step_awaken[6]; step_awaken_reg[7] <= step_awaken[7];
                    
                    comb_cnt <= 9'b0;
                    max_diversity_reg <= 4'b0;
                    
                    state <= ENUMERATE;
                end
                
                ENUMERATE: begin
                    // 2^n calculation: 1 << n_reg. 
                    // Since n is 3 bits, 2^n is 1 to 256. 
                    // comb_max holds 2^n.
                    // For n=0, 1<<0 = 1. Loop 0 to 0 (1 iteration).
                    comb_max <= 9'b000000001 << n_reg;
                    
                    // Check if we are done iterating
                    if (comb_cnt >= comb_max) begin
                        state <= DONE;
                    end else begin
                        // Check validity
                        if (awaken_count <= k_reg) begin
                            // Valid combination
                            // Prepare compute loop
                            partner_idx <= 3'b0;
                            compare_idx <= 3'b0;
                            current_diversity <= 4'b0;
                            i_dominated_flag <= 1'b0;
                            
                            if (n_reg == 3'b0) begin
                                state <= UPDATE; // No partners
                            end else begin
                                state <= COMPUTE;
                            end
                        end else begin
                            // Invalid, next combination
                            comb_cnt <= comb_cnt + 1;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Logic for i, j loops
                    // We iterate j (compare_idx) from 0 to n-1
                    // If curr_dominated is true, set i_dominated_flag
                    
                    if (curr_dominated) begin
                        i_dominated_flag <= 1'b1;
                    end
                    
                    if (compare_idx < n_reg - 1) begin
                        // Continue j loop
                        compare_idx <= compare_idx + 1;
                    end else begin
                        // End of j loop for current i
                        // If i was NOT dominated, count it
                        if (!i_dominated_flag && !curr_dominated) begin // Also check the last one
                            current_diversity <= current_diversity + 1;
                        end
                        
                        // Move to next i
                        if (partner_idx < n_reg - 1) begin
                            partner_idx <= partner_idx + 1;
                            compare_idx <= 3'b0;
                            i_dominated_flag <= 1'b0; // Reset flag for next i
                        end else begin
                            // End of i loop
                            state <= UPDATE;
                        end
                    end
                end
                
                UPDATE: begin
                    if (current_diversity > max_diversity_reg) begin
                        max_diversity_reg <= current_diversity;
                    end
                    comb_cnt <= comb_cnt + 1;
                    state <= ENUMERATE;
                end
                
                DONE: begin
                    result <= max_diversity_reg;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
