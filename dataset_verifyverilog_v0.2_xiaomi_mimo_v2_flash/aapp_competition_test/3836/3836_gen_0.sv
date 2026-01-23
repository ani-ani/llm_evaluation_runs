module debate_selection(
    input clk,
    input rst_n,
    input start,
    input [2:0] count_00, count_01, count_10, count_11,
    input [7:0] inf_00_0, inf_00_1, inf_00_2, inf_00_3, inf_00_4, inf_00_5, inf_00_6, inf_00_7,
    input [7:0] inf_01_0, inf_01_1, inf_01_2, inf_01_3, inf_01_4, inf_01_5, inf_01_6, inf_01_7,
    input [7:0] inf_10_0, inf_10_1, inf_10_2, inf_10_3, inf_10_4, inf_10_5, inf_10_6, inf_10_7,
    input [7:0] inf_11_0, inf_11_1, inf_11_2, inf_11_3, inf_11_4, inf_11_5, inf_11_6, inf_11_7,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SORT = 3'b001;
    localparam SELECT = 3'b010;
    localparam VALIDATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;

    // Sorted influence arrays (registers to hold sorted values)
    reg [7:0] sorted_00 [0:7];
    reg [7:0] sorted_01 [0:7];
    reg [7:0] sorted_10 [0:7];
    reg [7:0] sorted_11 [0:7];

    // Unsorted temporary arrays for sorting
    reg [7:0] temp_00 [0:7];
    reg [7:0] temp_01 [0:7];
    reg [7:0] temp_10 [0:7];
    reg [7:0] temp_11 [0:7];

    // Sorting control
    reg [2:0] sort_idx;
    reg [2:0] sort_pass;
    reg sorting_done;

    // Pool generation control
    reg [3:0] pool_idx; // Max 8 elements per type, pool size up to 24
    reg [3:0] pool_size;
    reg [7:0] pool [0:23]; // Pool of candidates to add after base selection
    reg pool_built;

    // Selection variables
    reg [3:0] sel_idx; // Index into pool for adding candidates
    reg [3:0] sel_count; // Number of items added from pool
    
    // Constraint tracking
    reg [3:0] m; // Total selected count
    reg [3:0] a; // Alice supporters (10 + 11)
    reg [3:0] b; // Bob supporters (01 + 11)
    reg [15:0] current_influence;
    reg constraints_met;

    // Helper variables for sorting comparisons
    reg [7:0] swap_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            valid <= 0;
        end else begin
            state <= next_state;
            
            // FSM Logic
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    result <= 0;
                end
                
                SORT: begin
                    // Bubble sort network logic implemented iteratively
                    // We perform one pass of swaps per clock cycle for pipelining
                    // Or fully combinational sort (logic depth heavy)
                    // Requirement: Latency 200 cycles. We have 4 types * ~28 comparisons = 112 cycles.
                    // Let's do 1 bubble sort pass per clock cycle.
                    
                    if (sort_pass < 8) begin // 8 passes for 8 elements
                        // Type 00
                        if (sort_idx < 7) begin
                            if (temp_00[sort_idx] < temp_00[sort_idx+1]) begin
                                swap_temp <= temp_00[sort_idx];
                                temp_00[sort_idx] <= temp_00[sort_idx+1];
                                temp_00[sort_idx+1] <= swap_temp;
                            end
                            // Type 01
                            if (temp_01[sort_idx] < temp_01[sort_idx+1]) begin
                                swap_temp <= temp_01[sort_idx];
                                temp_01[sort_idx] <= temp_01[sort_idx+1];
                                temp_01[sort_idx+1] <= swap_temp;
                            end
                            // Type 10
                            if (temp_10[sort_idx] < temp_10[sort_idx+1]) begin
                                swap_temp <= temp_10[sort_idx];
                                temp_10[sort_idx] <= temp_10[sort_idx+1];
                                temp_10[sort_idx+1] <= swap_temp;
                            end
                            // Type 11
                            if (temp_11[sort_idx] < temp_11[sort_idx+1]) begin
                                swap_temp <= temp_11[sort_idx];
                                temp_11[sort_idx] <= temp_11[sort_idx+1];
                                temp_11[sort_idx+1] <= swap_temp;
                            end
                        end
                    end
                end

                SELECT: begin
                    // Build the pool from remaining unpaired items
                    // We initialize pool in the transition to SELECT, here we might just verify or do nothing if combinational
                    // The problem asks to "Add top influences from pool until constraints met". 
                    // Since we need sequential behavior, we can process pool adding one by one if needed,
                    // but we can also do it in one cycle if the pool is small (max 16 elements) and logic fits.
                    // Let's build the pool in a sequential manner during SELECT state or a dedicated SETUP state.
                    // Given constraints, let's assume we do the greedy check/add logic in this state.
                    
                    // Actually, the "Build Pool" step is distinct from "Add". 
                    // Step 2 says: create candidate pool. Step 3/4 says: Add top from pool.
                    // Let's implement a pool builder in the first few cycles of SELECT.
                    // But wait, we need to validate constraints. 
                    // Let's calculate M, A, B for the base set (All 11 + Paired 01/10). 
                    // Check if base is valid. If not, we need to add items.
                    
                    // Optimization: Calculate base stats and build pool in parallel if possible, otherwise sequential.
                    // Let's assume a sequential "Add" phase.
                end

                VALIDATE: begin
                    // We will do the addition logic here or in a loop within SELECT.
                    // Let's restructure: SELECT state will iterate adding items from pool.
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = SORT;
            
            SORT: begin
                // 8 passes * 8 cycles per pass = 64 cycles roughly if we iterate index.
                // Let's define the sorting state transition more strictly.
                // We used sort_pass and sort_idx. 
                // If we increment sort_idx every cycle (0 to 7), and sort_pass increments when idx wraps:
                // Total cycles = 8 * 8 = 64.
                if (sort_pass == 4'd8 && sort_idx == 3'd7) next_state = SELECT;
            end
            
            SELECT: begin
                // This state handles building the pool and performing the greedy addition.
                // To stay within 200 cycles, a simple loop is fine.
                // Logic: 
                // 1. Calculate base counts/inf (needs one cycle or pre-computed)
                // 2. Check constraints.
                // 3. If invalid, add next best from pool.
                // 4. Repeat until valid or pool empty.
                // Let's use a sub-state machine or counters inside SELECT.
                // We'll use `pool_built` flag and `sel_idx`.
                
                if (!pool_built) next_state = SELECT; // Stay here while building
                else if (constraints_met || (sel_idx >= pool_size)) next_state = VALIDATE; 
                else next_state = SELECT; // Continue adding
            end
            
            VALIDATE: begin
                next_state = DONE;
            end
            
            DONE: if (!start) next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset internal counters/arrays
            sort_idx <= 0;
            sort_pass <= 0;
            pool_built <= 0;
            pool_size <= 0;
            sel_idx <= 0;
            constraints_met <= 0;
            m <= 0;
            a <= 0;
            b <= 0;
            current_influence <= 0;
            // Initialize temp arrays with inputs on start
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load inputs into temp arrays for sorting
                        temp_00[0] <= inf_00_0; temp_00[1] <= inf_00_1; temp_00[2] <= inf_00_2; temp_00[3] <= inf_00_3;
                        temp_00[4] <= inf_00_4; temp_00[5] <= inf_00_5; temp_00[6] <= inf_00_6; temp_00[7] <= inf_00_7;
                        temp_01[0] <= inf_01_0; temp_01[1] <= inf_01_1; temp_01[2] <= inf_01_2; temp_01[3] <= inf_01_3;
                        temp_01[4] <= inf_01_4; temp_01[5] <= inf_01_5; temp_01[6] <= inf_01_6; temp_01[7] <= inf_01_7;
                        temp_10[0] <= inf_10_0; temp_10[1] <= inf_10_1; temp_10[2] <= inf_10_2; temp_10[3] <= inf_10_3;
                        temp_10[4] <= inf_10_4; temp_10[5] <= inf_10_5; temp_10[6] <= inf_10_6; temp_10[7] <= inf_10_7;
                        temp_11[0] <= inf_11_0; temp_11[1] <= inf_11_1; temp_11[2] <= inf_11_2; temp_11[3] <= inf_11_3;
                        temp_11[4] <= inf_11_4; temp_11[5] <= inf_11_5; temp_11[6] <= inf_11_6; temp_11[7] <= inf_11_7;
                        sort_idx <= 0;
                        sort_pass <= 0;
                    end
                end

                SORT: begin
                    // Perform sort increment
                    sort_idx <= sort_idx + 1;
                    if (sort_idx == 3'd7) begin
                        sort_idx <= 0;
                        sort_pass <= sort_pass + 1;
                    end
                    // Note: The swap logic is combinational in the always block above, but we need to update registers.
                    // Actually, standard bubble sort in hardware usually does comparisons in combinational logic 
                    // and updates registers at the end of the clock.
                    // The previous always block for combinational logic might conflict if we split.
                    // Let's merge the logic to be sequential inside this block for clarity and synthesis safety.
                    
                    // Re-implementing the swap logic here to ensure proper register updates
                    if (sort_pass < 8) begin
                        if (sort_idx < 7) begin
                            // Type 00
                            if (temp_00[sort_idx] < temp_00[sort_idx+1]) begin
                                temp_00[sort_idx] <= temp_00[sort_idx+1];
                                temp_00[sort_idx+1] <= temp_00[sort_idx];
                            end
                            // Type 01
                            if (temp_01[sort_idx] < temp_01[sort_idx+1]) begin
                                temp_01[sort_idx] <= temp_01[sort_idx+1];
                                temp_01[sort_idx+1] <= temp_01[sort_idx];
                            end
                            // Type 10
                            if (temp_10[sort_idx] < temp_10[sort_idx+1]) begin
                                temp_10[sort_idx] <= temp_10[sort_idx+1];
                                temp_10[sort_idx+1] <= temp_10[sort_idx];
                            end
                            // Type 11
                            if (temp_11[sort_idx] < temp_11[sort_idx+1]) begin
                                temp_11[sort_idx] <= temp_11[sort_idx+1];
                                temp_11[sort_idx+1] <= temp_11[sort_idx];
                            end
                        end
                    end
                    
                    // Finalize sorted arrays when sort is done
                    if (sort_pass == 8 && sort_idx == 7) begin
                        // Copy temp to sorted
                        // We can do this in one cycle or pipelined. Let's do it here.
                        sorted_00[0] <= temp_00[0]; sorted_00[1] <= temp_00[1]; sorted_00[2] <= temp_00[2]; sorted_00[3] <= temp_00[3];
                        sorted_00[4] <= temp_00[4]; sorted_00[5] <= temp_00[5]; sorted_00[6] <= temp_00[6]; sorted_00[7] <= temp_00[7];
                        sorted_01[0] <= temp_01[0]; sorted_01[1] <= temp_01[1]; sorted_01[2] <= temp_01[2]; sorted_01[3] <= temp_01[3];
                        sorted_01[4] <= temp_01[4]; sorted_01[5] <= temp_01[5]; sorted_01[6] <= temp_01[6]; sorted_01[7] <= temp_01[7];
                        sorted_10[0] <= temp_10[0]; sorted_10[1] <= temp_10[1]; sorted_10[2] <= temp_10[2]; sorted_10[3] <= temp_10[3];
                        sorted_10[4] <= temp_10[4]; sorted_10[5] <= temp_10[5]; sorted_10[6] <= temp_10[6]; sorted_10[7] <= temp_10[7];
                        sorted_11[0] <= temp_11[0]; sorted_11[1] <= temp_11[1]; sorted_11[2] <= temp_11[2]; sorted_11[3] <= temp_11[3];
                        sorted_11[4] <= temp_11[4]; sorted_11[5] <= temp_11[5]; sorted_11[6] <= temp_11[6]; sorted_11[7] <= temp_11[7];
                        
                        // Initialize selection logic
                        // Base selection: All 11, Pair min(01, 10)
                        // We need to calculate this. Since we are at the end of SORT, we can start SELECT.
                        // We will do the initial calculation in the next cycle (start of SELECT).
                        
                        // Actually, to save a cycle, we can pre-calculate or just set flags.
                        // We need to calculate the pool. Let's do that in SELECT state.
                        pool_built <= 0;
                        pool_idx <= 0;
                        pool_size <= 0;
                        sel_idx <= 0;
                        sel_count <= 0;
                        constraints_met <= 0;
                        result <= 0;
                    end
                end

                SELECT: begin
                    // Phase 1: Build Pool
                    if (!pool_built) begin
                        // Filling logic
                        // We need indices for sorted arrays.
                        // Let's compute local params for clarity (though Verilog doesn't allow localparam based on inputs inside always block easily for indexing).
                        // We'll use variables.
                        
                        // Base counts for pairs
                        reg [3:0] paired_01 = (count_01 < count_10) ? count_01 : count_10;
                        reg [3:0] rem_01 = count_01 - paired_01;
                        reg [3:0] rem_10 = count_10 - paired_01;
                        
                        // We need to fill `pool` array.
                        // We can use a loop variable or just write it out if unrolled.
                        // Since we are in sequential logic, we can write specific indices.
                        // But we need to know `pool_idx`. 
                        // Let's assume we fill `pool` in one go using combinational logic (assign) 
                        // and load into register.
                        
                        // Actually, let's use a wire for the pool content generation.
                        // We will define combinational logic outside this block to generate pool entries.
                        // To keep the code in one block, we can use a `generate` block or just `if-else` chains.
                        // Given the "single block" instruction preference, let's do it manually.
                        
                        // Let's use a variable `p_idx` to fill.
                        // We'll fill `pool` registers.
                        
                        // Since we can't do loops easily in combinational logic inside a sequential block without `genvar`,
                        // and `genvar` is for generate, we will use a flag to "capture" the pool.
                        // Let's define the pool selection logic via a case statement or if-else chain for the index.
                        
                        // Wait, the prompt asks for "efficient Verilog".
                        // It's more efficient to write a helper combinational block.
                        // I will include two always blocks.
                        
                        // Since I must return ONE code string, I will structure it with comments.
                        
                        // Let's assume we fill pool in 1 cycle. 
                        // We need to calculate the values.
                        // We will use `pool_idx` as a temporary counter to write to `pool`.
                        
                        // To be honest, filling a register array of 24 entries sequentially takes 24 cycles.
                        // We don't have that many cycles to waste if we also need to add.
                        // So, we must fill in parallel or fully combinational load.
                        
                        // Let's do this: 
                        // In IDLE, we don't do much. 
                        // In SORT, we sort.
                        // In SELECT, we have `pool_built`.
                        // If `pool_built` is 0, we assert `load_pool` and calculate values.
                        
                        // Actually, let's just calculate the pool content in the combinational block.
                        // I will write the combinational block below the sequential block.
                        // For now, inside the sequential block, I will set `pool_built` to 1 and copy the combinational values.
                        
                        pool_built <= 1;
                        // We need to trigger the calculation. 
                        // Let's just assume the combinational block updates `pool_wire`.
                        // We need to copy `pool_wire` to `pool_reg`.
                        // But we can't reference a reg in the same block it's assigned to for this logic easily without a wire.
                        
                        // Let's do the greedy add logic in SELECT state.
                        // Base stats:
                        // M_base = count_11 + 2 * paired_01
                        // A_base = count_11 + paired_01
                        // B_base = count_11 + paired_01
                        // Inf_base = sum(sorted_11[0..count_11-1]) + sum(sorted_01[0..paired_01-1]) + sum(sorted_10[0..paired_01-1])
                        
                        // We need to calculate these sums.
                        // This is the main bottleneck.
                        // Let's calculate sums in one cycle.
                        // Since count is max 8, we can write out the logic.
                        
                        // Let's define the "Add" step.
                        // We will start with `sel_count = 0`.
                        // Base + Items[0..sel_count-1].
                        
                        // Let's refine the FSM to handle the "Add" loop.
                        // We need to compute the current influence and counts.
                        
                        // To avoid combinational complexity in the sequential block, let's use a staged approach.
                        // STAGE 1 (SELECT): Calculate Base stats. Check constraints.
                        // STAGE 2+ (SELECT): Increment sel_count. Check constraints.
                        
                        // We need to compute sums. 
                        // Let's use a helper combinational block to compute sums of sorted arrays up to a specific index.
                        // But since we are coding, let's inline it.
                        
                        // This is getting complex for a single block. 
                        // Let's stick to the "200 cycles" constraint. We have time.
                        // We will calculate the sums sequentially.
                        // Actually, let's just do the sorting and then a very simple greedy in a loop.
                        
                        // Greedy Loop:
                        // 1. Pick All 11. Update Inf, M, A, B.
                        // 2. Pick Min(01, 10) pairs. Update.
                        // 3. While (constraints not met AND items left in pool):
                        //    Pick best from pool (01_rem, 10_rem, 00).
                        //    Update.
                        
                        // How to track "Pool"?
                        // We can track pointers into the sorted arrays.
                        // ptr_11 = count_11
                        // ptr_01 = min(count_01, count_10)
                        // ptr_10 = min(count_01, count_10)
                        // ptr_00 = 0
                        
                        // Next best is max(sorted_01[ptr_01], sorted_10[ptr_10], sorted_00[ptr_00]).
                        // We check counts to see if pointers are valid.
                        
                        // Let's implement this logic.
                        // We need registers for: current_m, current_a, current_b, current_inf, ptr_01, ptr_10, ptr_00.
                        // Also registers for the base values to restore if we just want to check.
                        // Actually, we just accumulate.
                        
                        // Let's add registers for pointers.
                        reg [3:0] ptr_01_rem, ptr_10_rem, ptr_00_rem;
                        // And base accumulators.
                        reg [15:0] base_inf;
                        reg [3:0] base_m, base_a, base_b;
                        
                        // Let's use a `init_done` flag within SELECT.
                        
                        if (!pool_built) begin
                            // Filling logic
                            // We need indices for sorted arrays.
                            // Let's compute local params for clarity (though Verilog doesn't allow localparam based on inputs inside always block easily for indexing).
                            // We'll use variables.
                            
                            // Base counts for pairs
                            reg [3:0] paired_01 = (count_01 < count_10) ? count_01 : count_10;
                            reg [3:0] rem_01 = count_01 - paired_01;
                            reg [3:0] rem_10 = count_10 - paired_01;
                            
                            // We need to fill `pool` array.
                            // We can use a loop variable or just write it out if unrolled.
                            // Since we are in sequential logic, we can write specific indices.
                            // But we need to know `pool_idx`. 
                            // Let's assume we fill `pool` in one go using combinational logic (assign) 
                            // and load into register.
                            
                            // Actually, let's use a wire for the pool content generation.
                            // We will define combinational logic outside this block to generate pool entries.
                            // To keep the code in one block, we can use a `generate` block or just `if-else` chains.
                            // Given the "single block" instruction preference, let's do it manually.
                            
                            // Let's use a variable `p_idx` to fill.
                            // We'll fill `pool` registers.
                            
                            // Since we can't do loops easily in combinational logic inside a sequential block without `genvar`,
                            // and `genvar` is for generate, we will use a flag to "capture" the pool.
                            // Let's define the pool selection logic via a case statement or if-else chain for the index.
                            
                            // Wait, the prompt asks for "efficient Verilog".
                            // It's more efficient to write a helper combinational block.
                            // I will include two always blocks.
                            
                            // Since I must return ONE code string, I will structure it with comments.
                            
                            // Let's assume we fill pool in 1 cycle. 
                            // We need to calculate the values.
                            // We will use `pool_idx` as a temporary counter to write to `pool`.
                            
                            // To be honest, filling a register array of 24 entries sequentially takes 24 cycles.
                            // We don't have that many cycles to waste if we also need to add.
                            // So, we must fill in parallel or fully combinational load.
                            
                            // Let's do this: 
                            // In IDLE, we don't do much. 
                            // In SORT, we sort.
                            // In SELECT, we have `pool_built`.
                            // If `pool_built` is 0, we assert `load_pool` and calculate values.
                            
                            // Actually, let's just calculate the pool content in the combinational block.
                            // I will write the combinational block below the sequential block.
                            // For now, inside the sequential block, I will set `pool_built` to 1 and copy the combinational values.
                            
                            pool_built <= 1;
                            // We need to trigger the calculation. 
                            // Let's just assume the combinational block updates `pool_wire`.
                            // We need to copy `pool_wire` to `pool_reg`.
                            // But we can't reference a reg in the same block it's assigned to for this logic easily without a wire.
                        end else begin
                            // Pool built. Now add items.
                            // Check constraints.
                            // If valid, go to DONE.
                            // If not valid, add next best.
                            
                            // Wait, the "Build Pool" part of Step 2 implies collecting candidates.
                            // Step 3/4 implies adding them.
                            // We need to merge these. 
                            
                            // Let's assume we have a single "Step 4" equivalent logic:
                            // Calculate initial set.
                            // If valid, done.
                            // Else, sort pool candidates (already sorted in original arrays).
                            // Add next best.
                            // Repeat.
                            
                            // Since sorting is done, we just need to pick the max of available next items.
                            // We need to track indices.
                            // Let's use registers: 
                            // `idx_01`, `idx_10`, `idx_00` initialized to paired_01, paired_01, 0.
                            // `limit_01`, `limit_10`, `limit_00`.
                            
                            // Let's implement the selection in a loop.
                            // We can do 1 addition per cycle.
                            
                            // We need to initialize these limits/pointers first.
                            // Let's introduce a sub-state `SEL_INIT` inside SELECT.
                            // But the prompt said 4 states. We can use counters to emulate sub-states or do it in the first cycle.
                            
                            // Let's assume we enter SELECT. 
                            // Cycle 0: Calculate base stats and initial pointers.
                            // Cycle 1+: Add items.
                            
                            // We need to store the current stats.
                            
                            // Let's change the state machine slightly to fit the behavior.
                            // IDLE -> SORT -> SELECT (do greedy add loop) -> DONE.
                            // We will use `sel_idx` to control the loop.
                            // `sel_idx` will start at 0. 0 means "Check Base". >0 means "Add Item N-1".
                            
                            // Actually, simpler:
                            // 1. Calculate Base Influence, Counts. 
                            // 2. Check Valid.
                            // 3. If Valid, Done. 
                            // 4. If Invalid, identify next best candidate (Combinational logic based on pointers).
                            // 5. Add candidate. Update Influence/Counts. Increment Pointers. 
                            // 6. Go to 2.
                            
                            // Since combinational logic for "Next Best" might be deep, let's do it in steps.
                            // But we have registers.
                            // Let's use the `done` signal logic.
                            
                            // We need to track pointers: `ptr_01`, `ptr_10`, `ptr_00`.
                            // Initially: `ptr_01 = min(c01, c10)`, `ptr_10 = min(c01, c10)`, `ptr_00 = 0`.
                            // Base: `inf = sum(sorted_11[0..c11-1]) + sum(sorted_01[0..ptr_01-1]) + sum(sorted_10[0..ptr_10-1])`.
                            // `m = c11 + 2*ptr_01`. `a = c11 + ptr_01`. `b = c11 + ptr_01`.
                            
                            // If valid, we are done (Result = inf). 
                            // If not, we look at `sorted_01[ptr_01]`, `sorted_10[ptr_10]`, `sorted_00[ptr_00]`.
                            // Pick max. Update pointers. Add to inf. Increment m/a/b.
                            // Repeat check.
                            
                            // This requires knowing the base inf/count. We can calculate base in IDLE or SORT.
                            // Let's calculate base in the first cycle of SELECT.
                            
                            // We will use a flag `base_calculated`.
                            // If `!base_calculated`, do it.
                            // Else, do the add loop.
                            
                            // Calculation of sums is expensive. Let's pre-calculate.
                            // We have 8 elements. 
                            // sum_11 = s_11[0] + ... + s_11[c11-1].
                            // We can do this with a loop or hardcoded cases. 
                            // Let's do it sequentially to save logic area, but we need speed.
                            // 200 cycles is plenty. Let's just use a small counter to sum.
                            
                            // Wait, we already spent ~64 cycles sorting. 
                            // Let's use a few cycles to sum the base.
                            // Then use a loop for the greedy add.
                            
                            // Let's break SELECT into:
                            // 1. Sum Base (using a loop counter `sum_idx`).
                            // 2. Greedy Loop (using `ptr_01`, etc.).
                            
                            // This is getting very detailed. 
                            // Let's finalize the structure.
                            
                            // State: SELECT.
                            // Sub-task 1: Calculate Base.
                            // Sub-task 2: While (!valid) add next.
                            
                            // To keep it simple and within 200 cycles:
                            // Let's calculate Base stats in one cycle (combinational logic inside sequential block).
                            // Use `always @(*)` for calculation, but if I must use one block, I'll write the logic out.
                            
                            // Given the complexity, I will write a second `always` block for combinational logic (helper signals). 
                            // This is standard practice and synthesizable.
                            
                            // Let's stick to the "single block" preference only if strictly necessary, but the prompt implies "Generate a module".
                            // A module usually has multiple blocks.
                            // I will provide the module with separated logic for clarity.
                        end
                    end
                end
                
                DONE: begin
                    // Output logic
                    if (constraints_met) begin
                        valid <= 1;
                        result <= current_influence;
                    end else begin
                        valid <= 0;
                        result <= 0;
                    end
                end
            endcase
        end
    end

    // --- Combinational Logic Helper ---
    // This block handles the complex sums and max comparisons to keep sequential block clean.
    // It calculates values based on current state and registers.
    
    reg [15:0] next_inf;
    reg [3:0] next_m, next_a, next_b;
    reg [7:0] cand_01, cand_10, cand_00;
    reg [7:0] next_best;
    reg is_valid;
    
    // Pointers for pool traversal
    reg [3:0] ptr_01_val, ptr_10_val, ptr_00_val;
    
    // Summation variables
    reg [15:0] sum_11, sum_01_pair, sum_10_pair;
    
    always @(*) begin
        // 1. Calculate Base Sums
        // We need to sum up to count_11 items
        sum_11 = 0;
        if (count_11 > 0) sum_11 = sum_11 + sorted_11[0];
        if (count_11 > 1) sum_11 = sum_11 + sorted_11[1];
        if (count_11 > 2) sum_11 = sum_11 + sorted_11[2];
        if (count_11 > 3) sum_11 = sum_11 + sorted_11[3];
        if (count_11 > 4) sum_11 = sum_11 + sorted_11[4];
        if (count_11 > 5) sum_11 = sum_11 + sorted_11[5];
        if (count_11 > 6) sum_11 = sum_11 + sorted_11[6];
        if (count_11 > 7) sum_11 = sum_11 + sorted_11[7];
        
        // Sum paired 01 (0 to min-1)
        sum_01_pair = 0;
        // We need the paired count. We can calculate it here.
        // This combinational logic assumes sorted arrays are stable.
        reg [2:0] paired = (count_01 < count_10) ? count_01 : count_10;
        
        if (paired > 0) sum_01_pair = sum_01_pair + sorted_01[0];
        if (paired > 1) sum_01_pair = sum_01_pair + sorted_01[1];
        if (paired > 2) sum_01_pair = sum_01_pair + sorted_01[2];
        if (paired > 3) sum_01_pair = sum_01_pair + sorted_01[3];
        if (paired > 4) sum_01_pair = sum_01_pair + sorted_01[4];
        if (paired > 5) sum_01_pair = sum_01_pair + sorted_01[5];
        if (paired > 6) sum_01_pair = sum_01_pair + sorted_01[6];
        if (paired > 7) sum_01_pair = sum_01_pair + sorted_01[7];
        
        // Sum paired 10
        sum_10_pair = 0;
        if (paired > 0) sum_10_pair = sum_10_pair + sorted_10[0];
        if (paired > 1) sum_10_pair = sum_10_pair + sorted_10[1];
        if (paired > 2) sum_10_pair = sum_10_pair + sorted_10[2];
        if (paired > 3) sum_10_pair = sum_10_pair + sorted_10[3];
        if (paired > 4) sum_10_pair = sum_10_pair + sorted_10[4];
        if (paired > 5) sum_10_pair = sum_10_pair + sorted_10[5];
        if (paired > 6) sum_10_pair = sum_10_pair + sorted_10[6];
        if (paired > 7) sum_10_pair = sum_10_pair + sorted_10[7];

        // Base Stats
        reg [15:0] base_inf = sum_11 + sum_01_pair + sum_10_pair;
        reg [3:0] base_m = count_11 + (paired << 1); // 2 * paired
        reg [3:0] base_a = count_11 + paired;
        reg [3:0] base_b = count_11 + paired;
        
        // Pointers for remaining items
        // ptr_01 starts at paired. goes up to count_01-1.
        // ptr_10 starts at paired. goes up to count_10-1.
        // ptr_00 starts at 0. goes up to count_00-1.
        
        // We need to know the current state of the "Add" loop.
        // In the sequential block, we will track how many items we added (`sel_count`).
        // But we need to know WHICH items.
        // We will track pointers in the sequential block.
        // Let's define `cur_ptr_01`, `cur_ptr_10`, `cur_ptr_00`.
        
        // For the combinational check:
        // Current Total = Base + items added so far.
        // The sequential block will update `cur_ptr`.
        // Here we just need to check validity of current state and find next best.
        
        // --- Constraints Check ---
        // We need `current_m`, `current_a`, `current_b`, `current_inf` from sequential block.
        // But we need to check `is_valid`.
        
        // Wait, the sequential block updates `current_...`. 
        // So in combinational block, we compute validity of *next* step? No, validity of *current* step.
        // The sequential block decides if it should stop.
        
        // Logic for Next Best Candidate:
        // Candidates are:
        // 1. `sorted_01[cur_ptr_01]` if `cur_ptr_01 < count_01`
        // 2. `sorted_10[cur_ptr_10]` if `cur_ptr_10 < count_10`
        // 3. `sorted_00[cur_ptr_00]` if `cur_ptr_00 < count_00`
        
        // We need to compare these.
        cand_01 = (cur_ptr_01 < count_01) ? sorted_01[cur_ptr_01] : 0;
        cand_10 = (cur_ptr_10 < count_10) ? sorted_10[cur_ptr_10] : 0;
        cand_00 = (cur_ptr_00 < count_00) ? sorted_00[cur_ptr_00] : 0;
        
        if (cand_01 >= cand_10 && cand_01 >= cand_00) next_best = cand_01;
        else if (cand_10 >= cand_00) next_best = cand_10;
        else next_best = cand_00;
        
        // Determine which pointer to increment based on next_best (if we were to add it)
        // (Used in sequential to update pointers)
        // Not strictly needed here unless we do fully combinational update.
        
        // Calculate validity of `current_...` (from sequential)
        // Note: We need to use the values that will be checked.
        // The sequential block will update registers, then we check them.
        // But checking requires combinational logic.
        // Let's say sequential block updates `current_m` to `next_m`.
        // We calculate `is_valid` based on `next_m`.
        
        // Actually, the sequence is:
        // 1. Sequential block has state (m, a, b, inf).
        // 2. Combinational block computes `is_valid`.
        // 3. Combinational block computes `next_best`.
        // 4. Sequential block uses `is_valid` to go to DONE.
        // 5. If `!is_valid`, sequential block adds `next_best` and increments pointers.
        
        // Wait, `current_...` in sequential block represents the *accumulated* state.
        // So `is_valid` checks if `current_...` is valid.
        
        is_valid = 0;
        if (current_m > 0) begin
            if ((current_a * 2 >= current_m) && (current_b * 2 >= current_m)) is_valid = 1;
        end
        
        // Calculate Next State values (for when we add)
        // We need to know which pointer corresponds to `next_best`.
        // If next_best == cand_01, increment ptr_01.
        // If next_best == cand_10, increment ptr_10.
        // If next_best == cand_00, increment ptr_00.
        
        // We need to handle the case where values are equal.
        // Priority: 01 > 10 > 00 (arbitrary, but deterministic).
        // But we want max influence. If equal, any is fine.
        // But we must update the correct pointer.
        // If cand_01 == cand_10 == next_best, we should probably pick one.
        // Let's say: if cand_01 == next_best, pick 01. else if cand_10 == next_best, pick 10. else 00.
        
        // This is getting too coupled. 
        // Let's just put the "Update Logic" in the sequential block, using the combinational signals.
    end

    // Re-visiting the Sequential Logic to implement the loop cleanly
    // We need registers for pointers and accumulators.
    reg [3:0] cur_ptr_01, cur_ptr_10, cur_ptr_00;
    reg [3:0] loop_counter; // To control initialization vs loop
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            valid <= 0;
            current_influence <= 0;
            current_m <= 0;
            current_a <= 0;
            current_b <= 0;
            loop_counter <= 0;
            sort_idx <= 0;
            sort_pass <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    result <= 0;
                    if (start) begin
                        state <= SORT;
                        // Load inputs to temp arrays (combinational or synchronous load)
                        // We do it here synchronously
                        temp_00[0] <= inf_00_0; temp_00[1] <= inf_00_1; temp_00[2] <= inf_00_2; temp_00[3] <= inf_00_3;
                        temp_00[4] <= inf_00_4; temp_00[5] <= inf_00_5; temp_00[6] <= inf_00_6; temp_00[7] <= inf_00_7;
                        temp_01[0] <= inf_01_0; temp_01[1] <= inf_01_1; temp_01[2] <= inf_01_2; temp_01[3] <= inf_01_3;
                        temp_01[4] <= inf_01_4; temp_01[5] <= inf_01_5; temp_01[6] <= inf_01_6; temp_01[7] <= inf_01_7;
                        temp_10[0] <= inf_10_0; temp_10[1] <= inf_10_1; temp_10[2] <= inf_10_2; temp_10[3] <= inf_10_3;
                        temp_10[4] <= inf_10_4; temp_10[5] <= inf_10_5; temp_10[6] <= inf_10_6; temp_10[7] <= inf_10_7;
                        temp_11[0] <= inf_11_0; temp_11[1] <= inf_11_1; temp_11[2] <= inf_11_2; temp_11[3] <= inf_11_3;
                        temp_11[4] <= inf_11_4; temp_11[5] <= inf_11_5; temp_11[6] <= inf_11_6; temp_11[7] <= inf_11_7;
                        sort_idx <= 0;
                        sort_pass <= 0;
                    end
                end

                SORT: begin
                    // Bubble Sort Logic (synchronous)
                    // We perform 1 swap pass per clock cycle
                    // Sort pass runs 0 to 7 (8 passes)
                    // Sort idx runs 0 to 6 (7 comparisons per pass)
                    
                    if (sort_pass < 8) begin
                        if (sort_idx < 7) begin
                            // Compare and swap
                            if (temp_00[sort_idx] < temp_00[sort_idx+1]) begin
                                temp_00[sort_idx] <= temp_00[sort_idx+1];
                                temp_00[sort_idx+1] <= temp_00[sort_idx];
                            end
                            if (temp_01[sort_idx] < temp_01[sort_idx+1]) begin
                                temp_01[sort_idx] <= temp_01[sort_idx+1];
                                temp_01[sort_idx+1] <= temp_01[sort_idx];
                            end
                            if (temp_10[sort_idx] < temp_10[sort_idx+1]) begin
                                temp_10[sort_idx] <= temp_10[sort_idx+1];
                                temp_10[sort_idx+1] <= temp_10[sort_idx];
                            end
                            if (temp_11[sort_idx] < temp_11[sort_idx+1]) begin
                                temp_11[sort_idx] <= temp_11[sort_idx+1];
                                temp_11[sort_idx+1] <= temp_11[sort_idx];
                            end
                            sort_idx <= sort_idx + 1;
                        end else begin
                            // End of pass
                            sort_idx <= 0;
                            sort_pass <= sort_pass + 1;
                        end
                    end else begin
                        // Sorting Complete
                        // Move to SELECT and initialize
                        state <= SELECT;
                        
                        // Copy sorted temp to sorted registers (optional, but good for clarity)
                        // We can just use temp_... as sorted_... now.
                        // Let's just use temp_... as sorted to save lines.
                        // But we named them `temp` for sorting, `sorted` for usage.
                        // Let's copy.
                        sorted_00[0] <= temp_00[0]; sorted_00[1] <= temp_00[1]; sorted_00[2] <= temp_00[2]; sorted_00[3] <= temp_00[3];
                        sorted_00[4] <= temp_00[4]; sorted_00[5] <= temp_00[5]; sorted_00[6] <= temp_00[6]; sorted_00[7] <= temp_00[7];
                        sorted_01[0] <= temp_01[0]; sorted_01[1] <= temp_01[1]; sorted_01[2] <= temp_01[2]; sorted_01[3] <= temp_01[3];
                        sorted_01[4] <= temp_01[4]; sorted_01[5] <= temp_01[5]; sorted_01[6] <= temp_01[6]; sorted_01[7] <= temp_01[7];
                        sorted_10[0] <= temp_10[0]; sorted_10[1] <= temp_10[1]; sorted_10[2] <= temp_10[2]; sorted_10[3] <= temp_10[3];
                        sorted_10[4] <= temp_10[4]; sorted_10[5] <= temp_10[5]; sorted_10[6] <= temp_10[6]; sorted_10[7] <= temp_10[7];
                        sorted_11[0] <= temp_11[0]; sorted_11[1] <= temp_11[1]; sorted_11[2] <= temp_11[2]; sorted_11[3] <= temp_11[3];
                        sorted_11[4] <= temp_11[4]; sorted_11[5] <= temp_11[5]; sorted_11[6] <= temp_11[6]; sorted_11[7] <= temp_11[7];
                        
                        // Initialize Select Logic
                        loop_counter <= 0; // 0 = Calculate Base, >0 = Greedy Add
                    end
                end

                SELECT: begin
                    if (loop_counter == 0) begin
                        // Calculate Base Accumulation
                        // We do this step-by-step or just use the combinational sums.
                        // Since we have the combinational block `sum_11` etc., we can use them.
                        // But they depend on `sorted` which is now updated.
                        // We need to ensure `sorted` is stable before using.
                        // Since we just copied `sorted`, we can use `sum_11` now.
                        
                        // Initialize Pointers
                        cur_ptr_01 <= (count_01 < count_10) ? count_01 : count_10;
                        cur_ptr_10 <= (count_01 < count_10) ? count_01 : count_10;
                        cur_ptr_00 <= 0;
                        
                        // Set Initial Influence
                        current_influence <= sum_11 + sum_01_pair + sum_10_pair;
                        
                        // Set Initial Counts
                        current_m <= count_11 + (((count_01 < count_10) ? count_01 : count_10) << 1);
                        current_a <= count_11 + ((count_01 < count_10) ? count_01 : count_10);
                        current_b <= count_11 + ((count_01 < count_10) ? count_01 : count_10);
                        
                        // Check Base Validity
                        // We need to check immediately if base is valid.
                        // If base is valid, we can go to DONE (assuming no need to add more, though problem says "add until valid").
                        // If not valid, we need to enter loop.
                        
                        // To handle this in one cycle logic, let's use a flag.
                        // If base is valid, we set done_next cycle?
                        // Or just check in next cycle.
                        
                        // We'll increment loop_counter to enter the Add/Check phase.
                        loop_counter <= 1;
                        
                        // Pre-check base validity
                        if ((current_a * 2 >= current_m) && (current_b * 2 >= current_m) && (current_m > 0)) begin
                             // Base is valid. We might be done, but let's verify if we should add more to maximize.
                             // The problem says "Add top influences from pool until constraints met".
                             // This implies we stop when met. So base valid = done (with base set).
                             // However, if base is valid, we should NOT add more, because adding more might make it invalid.
                             // Wait, the constraints 2a>=m, 2b>=m. Adding a type 11 makes it valid. Adding 01/10/00 makes it harder to satisfy.
                             // So if base is valid, we are done.
                             // But wait, the problem asks to "maximize total influence". 
                             // If we can add items and still remain valid, we should.
                             // Adding 11 keeps valid. Adding pairs (01+10) keeps valid.
                             // Adding single items makes it invalid.
                             // Wait. The problem says "Add top influences from pool until constraints met".
                             // This implies we start from an invalid state? 
                             // "Take all 11" -> Valid.
                             "Pair min" -> Valid.
                             "Remaining ... go to pool".
                             "Add top from pool until constraints met".
                             // This implies the set "All 11 + Paired" is potentially invalid?
                             // No, 2a = 2(c11 + p) >= 2(c11 + p) = m. It's exactly equal.
                             // So base is always valid.
                             // The "Add" step is for the case where we want to add more, but we CANNOT add singles.
                             // So the problem statement might imply:
                             // Base is valid. We stop.
                             // OR, we try to add singles and check if it stays valid? No, it will fail.
                             // Wait, "Constraint check... Valid if 2a>=m AND 2b>=m".
                             // "Add top influences from pool until constraints met".
                             // This implies we add items. If invalid, we continue.
                             // This logic applies if we are building a set from scratch, or if base was invalid.
                             // Base is NEVER invalid.
                             // Maybe the pool contains items that, when added, keep it valid? 
                             // No, adding single type 00 (neither) adds 1 to m, 0 to a/b. 2a >= m might still hold if we have surplus.
                             // Example: m=4, a=4, b=4. 8>=4. Add 00 -> m=5, a=4, b=4. 8>=5. Still valid.
                             // So we can add 00s if we have surplus support.
                             // We can add pairs of 01/10.
                             // We CANNOT add single 01 or 10.
                             // So the pool contains remaining 01, 10, 00.
                             // We should add them greedily while valid.
                             // So we definitely need the loop.
                             
                             // Let's proceed to loop.
                        end
                    end else begin
                        // Loop Phase
                        // Check Validity of *current* set.
                        if ((current_a * 2 >= current_m) && (current_b * 2 >= current_m) && (current_m > 0)) begin
                            // It is valid. 
                            // We can add more? Or we are done?
                            // "Add top influences from pool until constraints met".
                            // This phrasing suggests we ONLY stop when met. 
                            // Since base is met, we should stop immediately if we follow strictly.
                            // BUT "maximize total influence" implies we should keep adding as long as valid.
                            // So we should check if we can add next best and remain valid.
                            // However, checking "if we add X, will it be valid?" is look-ahead.
                            // "Add until constraints met" usually implies we add, check, if invalid, we stop or backtrack.
                            // But we want to maximize. 
                            // Most common interpretation: Add items sequentially. If after adding, constraints are met, keep. 
                            // Wait, constraints are met means "valid". We want valid. 
                            // If we add an item and it becomes invalid, we shouldn't have added it.
                            // But we don't know until we check.
                            // So: 
                            // 1. Tentatively add next best.
                            // 2. Check constraints.
                            // 3. If valid, commit. If invalid, discard and stop.
                            
                            // Let's implement tentative add logic.
                            // Calculate next state values based on `next_best` and `next_...` pointers.
                            
                            // We need to pick the best candidate. Combinational logic `next_best` is available.
                            // If `next_best` is 0 (pool empty), stop.
                            
                            if (next_best == 0) begin
                                state <= DONE;
                                done <= 1; // Optimization: set done here
                                valid <= 1;
                                result <= current_influence;
                            end else begin
                                // Tentative Update
                                // We need to know which pointer to increment.
                                // Logic: 
                                // If cand_01 == next_best, pick 01. (Priority order to resolve ties)
                                // Else if cand_10 == next_best, pick 10.
                                // Else pick 00.
                                
                                // Tentative values
                                reg [15:0] tent_inf;
                                reg [3:0] tent_m, tent_a, tent_b;
                                reg [3:0] next_ptr_01, next_ptr_10, next_ptr_00;
                                
                                tent_inf = current_influence + next_best;
                                tent_m = current_m + 1;
                                tent_a = current_a;
                                tent_b = current_b;
                                
                                // Determine which candidate was picked to update a/b
                                if (cand_01 >= cand_10 && cand_01 >= cand_00) begin
                                    tent_b = tent_b + 1; // Type 01 supports Bob
                                    next_ptr_01 = cur_ptr_01 + 1;
                                    next_ptr_10 = cur_ptr_10;
                                    next_ptr_00 = cur_ptr_00;
                                end else if (cand_10 >= cand_00) begin
                                    tent_a = tent_a + 1; // Type 10 supports Alice
                                    next_ptr_01 = cur_ptr_01;
                                    next_ptr_10 = cur_ptr_10 + 1;
                                    next_ptr_00 = cur_ptr_00;
                                end else begin
                                    // Type 00
                                    next_ptr_01 = cur_ptr_01;
                                    next_ptr_10 = cur_ptr_10;
                                    next_ptr_00 = cur_ptr_00 + 1;
                                end
                                
                                // Check validity of tentative state
                                if ((tent_a * 2 >= tent_m) && (tent_b * 2 >= tent_m)) begin
                                    // Valid! Commit.
                                    current_influence <= tent_inf;
                                    current_m <= tent_m;
                                    current_a <= tent_a;
                                    current_b <= tent_b;
                                    cur_ptr_01 <= next_ptr_01;
                                    cur_ptr_10 <= next_ptr_10;
                                    cur_ptr_00 <= next_ptr_00;
                                    // Loop again
                                end else begin
                                    // Invalid! Stop.
                                    state <= DONE;
                                    done <= 1;
                                    valid <= 1; // Current state is valid, so result is valid
                                    result <= current_influence;
                                end
                            end
                        end else begin
                            // Current state is invalid (should not happen for base, but if we backtrack or something)
                            // Stop. Result 0.
                            state <= DONE;
                            done <= 1;
                            valid <= 0;
                            result <= 0;
                        end
                    end
                end

                DONE: begin
                    // Ensure done is high. (Already set in SELECT transitions)
                    // Wait for start to go low to return to IDLE
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                        valid <= 0;
                    end
                end
            endcase
        end
    end
    
    // Combinational Logic for `next_best` and candidate values
    // This is needed inside the SELECT state logic above.
    // Since I cannot use multiple always blocks easily in the "single code string" format without splitting,
    // I will inline the logic into the sequential block using explicit reg variables.
    // Wait, the logic above references `cand_01`, `cand_10`, `cand_00`, `next_best`.
    // These must be defined and updated continuously.
    // I'll add the combinational block here.
    
    always @(*) begin
        // Candidates
        cand_01 = (cur_ptr_01 < count_01) ? sorted_01[cur_ptr_01] : 8'b0;
        cand_10 = (cur_ptr_10 < count_10) ? sorted_10[cur_ptr_10] : 8'b0;
        cand_00 = (cur_ptr_00 < count_00) ? sorted_00[cur_ptr_00] : 8'b0;
        
        // Next Best (Max)
        if (cand_01 >= cand_10 && cand_01 >= cand_00) next_best = cand_01;
        else if (cand_10 >= cand_00) next_best = cand_10;
        else next_best = cand_00;
        
        // Sums (for initialization)
        // We need to recalculate these based on `sorted` which are regs.
        // But we can't index regs with regs in combinational block easily if `sorted` is a register array.
        // Wait, `sorted_11` etc are `reg [7:0] sorted_XX [0:7]`. This is valid Verilog for synthesis.
        
        // Base sums calculation
        sum_11 = 0;
        if (count_11 > 0) sum_11 = sum_11 + sorted_11[0];
        if (count_11 > 1) sum_11 = sum_11 + sorted_11[1];
        if (count_11 > 2) sum_11 = sum_11 + sorted_11[2];
        if (count_11 > 3) sum_11 = sum_11 + sorted_11[3];
        if (count_11 > 4) sum_11 = sum_11 + sorted_11[4];
        if (count_11 > 5) sum_11 = sum_11 + sorted_11[5];
        if (count_11 > 6) sum_11 = sum_11 + sorted_11[6];
        if (count_11 > 7) sum_11 = sum_11 + sorted_11[7];

        // Paired sums (up to min(count_01, count_10))
        reg [2:0] paired = (count_01 < count_10) ? count_01 : count_10;
        
        sum_01_pair = 0;
        if (paired > 0) sum_01_pair = sum_01_pair + sorted_01[0];
        if (paired > 1) sum_01_pair = sum_01_pair + sorted_01[1];
        if (paired > 2) sum_01_pair = sum_01_pair + sorted_01[2];
        if (paired > 3) sum_01_pair = sum_01_pair + sorted_01[3];
        if (paired > 4) sum_01_pair = sum_01_pair + sorted_01[4];
        if (paired > 5) sum_01_pair = sum_01_pair + sorted_01[5];
        if (paired > 6) sum_01_pair = sum_01_pair + sorted_01[6];
        if (paired > 7) sum_01_pair = sum_01_pair + sorted_01[7];
        
        sum_10_pair = 0;
        if (paired > 0) sum_10_pair = sum_10_pair + sorted_10[0];
        if (paired > 1) sum_10_pair = sum_10_pair + sorted_10[1];
        if (paired > 2) sum_10_pair = sum_10_pair + sorted_10[2];
        if (paired > 3) sum_10_pair = sum_10_pair + sorted_10[3];
        if (paired > 4) sum_10_pair = sum_10_pair + sorted_10[4];
        if (paired > 5) sum_10_pair = sum_10_pair + sorted_10[5];
        if (paired > 6) sum_10_pair = sum_10_pair + sorted_10[6];
        if (paired > 7) sum_10_pair = sum_10_pair + sorted_10[7];
    end

endmodule