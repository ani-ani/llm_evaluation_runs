module max_independent_set (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [7:0] num_edges,
    input [2:0] edge_a [0:7],
    input [2:0] edge_b [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] mask;
    reg [3:0] max_size;
    reg [3:0] current_size;
    reg [3:0] edge_idx;
    reg is_valid;
    reg is_independent;
    reg [3:0] popcount;
    reg update_max;
    reg processing_done;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: next_state = processing_done ? DONE : PROCESSING;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Counter and Logic for Processing
    // processing_done is asserted when mask reaches 255 and logic for that mask is complete
    // In this single-always block logic, we track mask up to 255.
    // We update max_size at the end of the check for each mask.
    // Since we need to check 256 subsets (0 to 255), we stop after processing mask 255.
    // Note: The loop structure inside PROCESSING requires checking if we are done.
    // Since mask counts from 0 to 255, processing_done = (mask == 255) && cycle_end_of_check
    // To strictly follow latency (approx 256 cycles) and instructions to iterate 0..255,
    // we will use a counter. Since we need to check edges for each mask, the total cycles will be more than 256.
    // The instructions say "complete after checking all 256 subsets".
    // We will implement a sequential check per cycle: one edge check per cycle, and popcount, etc.
    // To keep it synthesizable and simple:
    // We will treat the mask as a counter.
    // We need a secondary counter for edges to check independence.
    // We will assume one edge check per clock cycle for the current mask.
    // Popcount can be done in parallel or in a separate cycle. Let's do popcount in parallel with validity check.
    
    // Logic for Mask and Edge Index Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= 8'b0;
            edge_idx <= 4'b0;
            max_size <= 4'b0;
            result <= 4'b0;
            done <= 1'b0;
            is_valid <= 1'b1;
            is_independent <= 1'b1;
            current_size <= 4'b0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        mask <= 8'b0;
                        edge_idx <= 4'b0;
                        max_size <= 4'b0;
                        result <= 4'b0;
                        done <= 1'b0;
                        is_valid <= 1'b1;
                        is_independent <= 1'b1;
                        current_size <= 4'b0;
                        processing_done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    // For the current mask, we need to:
                    // 1. Check validity (only bits < num_nodes)
                    // 2. Check independence (iterate edges)
                    // 3. Count bits (popcount)
                    // 4. Update max_size
                    // 5. Move to next mask
                    
                    // We need a sub-state or cycle counter for the edge checks because we have up to 8 edges.
                    // To minimize logic, let's process one edge per cycle.
                    
                    // We need to initialize flags at the start of a new mask.
                    // Let's use edge_idx == 0 to detect the start of a new mask (conceptually)
                    // However, edge_idx cycles 0 to num_edges-1. 
                    // Let's add a flag or detect when edge_idx wraps.
                    
                    // Let's refine the cycle sequence for a single mask:
                    // Cycle 0: Calculate Popcount, Check Validity. Initialize Independent=1.
                    // Cycle 1..N: Check Edges (decrement Independent if conflict).
                    // Cycle N+1: Update Max. Increment Mask.
                    // This requires a 3-stage pipeline or a counter per mask.
                    
                    // Given the requirement "Latency: Result valid approximately 256 clock cycles",
                    // we might need to be aggressive. 256 cycles for 256 subsets means ~1 cycle/subset.
                    // That implies we can't spend 8 cycles on edges per subset.
                    // BUT the instructions also say "Use a loop through edges to check independence".
                    // Perhaps the "approx 256" is a loose estimate, or we are expected to do pipelining.
                    // However, without a "valid" signal for inputs per cycle, we assume inputs are constant.
                    // Let's try to implement a 1-cycle per edge check.
                    // The total time will be roughly: 256 masks * (1 cycle validity/popcount + num_edges cycles) + 256 update cycles.
                    // Wait, instructions say "complete after checking all 256 subsets".
                    // Let's just iterate strictly. 
                    
                    // Let's use a dedicated register for the sub-process state.
                    // Actually, let's just use `edge_idx` to drive the iteration.
                    // We need to know when we are done with edges.
                    // Since num_edges is an input, we compare `edge_idx` with `num_edges`.
                    // 
                    // Logic Flow:
                    // 1. On transition to PROCESSING or when mask updates:
                    //    - We check validity (mask & ~((1<<num_nodes)-1)).
                    //    - We check popcount.
                    //    - We reset conflict flag.
                    // 2. Then we iterate edges 0 to num_edges-1.
                    // 3. After edges, we update max.
                    // 4. Increment mask.
                    // 5. If mask == 256, set done.
                    
                    // To fit the "256 cycles" approximation (which seems optimistic for 256 * edges),
                    // maybe they just mean the mask counter runs 0-255.
                    // Let's implement the logic that increments mask and processes edges sequentially.
                    
                    // We need a flag to trigger the start of a new mask check.
                    // Let's use a `mask_ready` or similar, but let's do it with logic.
                    
                    // Let's add a specific register to track if we are currently checking edges for a specific mask.
                    // Actually, let's just iterate mask and edge_idx sequentially.
                    // Wait, if we just iterate mask and edge_idx, we check all edges for all masks linearly.
                    // That is 256 * num_edges cycles.
                    // The prompt says "Latency: Result valid approximately 256 clock cycles". 
                    // This implies they might expect the check to be parallel or pipelined.
                    // However, I must implement the logic described.
                    // I will implement a sequential check, but to meet the spirit of "Efficient" and "Brute force",
                    // I will keep the logic simple: one edge check per cycle.
                    // The latency will be roughly 256 * (num_edges + 1).
                    
                    // Let's add a counter for the edge check phase.
                    // We need to separate the state of checking edges vs updating max.
                    // Let's add a sub-state register `sub_state` (not required by prompt but logically necessary for sequential edge checking within PROCESSING).
                    // Prompt asks for specific states IDLE, PROCESSING, DONE.
                    // So logic inside PROCESSING must handle the sub-iterations.
                    
                    // Improvement: Use `edge_idx` as a flag. If edge_idx < num_edges, we are checking edges.
                    // If edge_idx == num_edges, we are done with edges, update max, move to next mask.
                    
                    // Step 1: Check Validity and Popcount.
                    // We can do this when `edge_idx` is reset (e.g., when we just started a new mask).
                    // How to know we just started a new mask? Maybe `edge_idx == 0` is not enough if we loop.
                    // Let's add a flag `checking_current_mask` or assume `mask` increments only after edges are done.
                    
                    // Let's use `edge_idx` to distinguish phases:
                    // Phase A: Edge check (edge_idx 0 to num_edges-1).
                    // Phase B: Update Max (edge_idx = num_edges).
                    // Phase C: Next Mask (edge_idx = num_edges + 1).
                    // Phase D: Check Loop End.
                    
                    // Let's simplify. We will define a register `is_checking_edges`.
                    // But to save logic, let's use `edge_idx` ranges.
                    // Let's define `edge_idx` range 0..15 (internal).
                    // If `edge_idx` < `num_edges`: checking edge.
                    // If `edge_idx` == `num_edges`: update max and increment mask.
                    // 
                    // Implementation detail:
                    // Validity check: Valid if (mask & ~((1 << num_nodes) - 1)) == 0.
                    // Popcount: Use a loop or a small combinational block. Let's use a combinational block for popcount.
                    // Update Max: If valid && independent, compare size.
                    
                    // We need to track `is_independent` and `is_valid` for the current mask.
                    // Since we check edges one by one, `is_independent` will change during the edge loop.
                    // So we need to initialize `is_independent = 1` at the start of a mask.
                    // 
                    // Let's use `edge_idx` as a state counter for the PROCESSING state.
                    // Initialize `edge_idx` to 0 when mask updates.
                    // 
                    // Modified State Logic:
                    // If (edge_idx < num_edges):
                    //   Check edge[edge_idx]. If conflict, set is_independent = 0.
                    //   Increment edge_idx.
                    // Else if (edge_idx == num_edges):
                    //   // This is the first cycle after edges are done (or if num_edges=0)
                    //   // We need to check validity and popcount.
                    //   // Wait, validity and popcount should be done before or parallel to edges.
                    //   // Let's do Popcount and Validity check in the cycle when mask is just set (or edge_idx=0).
                    //   // But if num_edges is large, we might overwrite flags.
                    //   // Let's separate the logic.
                    //   // Let's use `mask_reg` to hold the mask, and `edge_idx` to control the flow.
                    //   
                    //   // Let's try a different approach. 
                    //   // We will use `mask` as the counter.
                    //   // We will use `edge_idx` to count edges checked.
                    //   // We need a flag to indicate we have checked validity/popcount for this mask.
                    //   // Let's call it `meta_done`.
                    //   // 
                    //   // Sequence:
                    //   // 1. Start of mask: `meta_done` = 0, `edge_idx` = 0.
                    //   //    Calculate Popcount, Validity. Set `is_independent` = 1.
                    //   //    Set `meta_done` = 1.
                    //   // 2. Edge Loop: While `edge_idx` < `num_edges`:
                    //   //    Check edge. Update `is_independent`.
                    //   //    Increment `edge_idx`.
                    //   // 3. Post-Edge: When `edge_idx` == `num_edges`:
                    //   //    Update Max.
                    //   //    Increment Mask.
                    //   //    Reset `meta_done`, `edge_idx`.
                    //   //    If Mask == 256, set `processing_done` = 1.
                    //   
                    //   // To implement this without a new state, we can use `edge_idx` and a flag.
                    //   // Let's use `edge_idx` bit 4 (e.g., 5th bit) as a flag: 0 = checking edges, 1 = done/ready to update.
                    //   // Actually, simpler: `edge_idx` is 0 to num_edges.
                    //   // If `edge_idx` == num_edges, we treat it as "Update Max" state.
                    //   // Then we go to "Next Mask" state (implicitly).
                    //   // 
                    //   // Let's use a specific register `phase` (0: meta, 1: edges, 2: update).
                    //   // To strictly follow the "IDLE, PROCESSING, DONE" requirement, we embed this in PROCESSING.
                    //   
                    //   // Let's assume `edge_idx` is the main iterator.
                    //   // But we need to know if we have done the "Init" (popcount/validity) or "Update".
                    //   // 
                    //   // Let's use `edge_idx` range:
                    //   // 0: Do Popcount/Validity, set Independent=1. Then go to 1.
                    //   // 1 to num_edges: Check edges. Then go to num_edges+1.
                    //   // num_edges+1: Update Max. Then increment mask. Reset to 0 (for next mask).
                    //   // 
                    //   // Since `num_edges` changes, we can't hardcode limits easily in simple if/else.
                    //   // 
                    //   // Let's try `update_phase` register.
                    //   // 0: Check Edges (iterates 0 to num_edges-1)
                    //   // 1: Update Max & Next Mask.
                    //   // 
                    //   // Wait, where do we do Popcount/Validity?
                    //   // Validity and Popcount depend ONLY on mask. They are constant for a mask.
                    //   // We can compute them combinationally.
                    //   // `valid = (mask & ~((1 << num_nodes) - 1)) == 0;`
                    //   // `pop = count_ones(mask);`
                    //   // We can just compute these inside the always block when `state == PROCESSING`.
                    //   // 
                    //   // Let's structure the PROCESSING block:
                    //   // 
                    //   // Regs needed:
                    //   // `mask_reg` (8 bit)
                    //   // `edge_idx_reg` (4 bit, 0 to 8)
                    //   // `is_independent_reg` (1 bit)
                    //   // `max_size_reg` (4 bit)
                    //   // `processing_done_reg` (1 bit)
                    //   // 
                    //   // Logic:
                    //   // if (edge_idx_reg == 0) begin
                    //   //   // Check validity and init independence
                    //   //   // We can check validity here.
                    //   //   // We also need to check popcount.
                    //   //   // Actually, we can do popcount at the end too, just before updating max.
                    //   //   // Let's do popcount/validity check in the first cycle of a new mask.
                    //   //   // If !valid, we can skip edge checks? Or just skip update.
                    //   //   // To be consistent, let's skip update if !valid.
                    //   //   // 
                    //   //   // 
                    //   //   // 
                    //   //   // 
                    //   // end
                    //   // 
                    //   // Let's look at the prompt requirements again.
                    //   // "For each subset... it verifies: 1. Subset is independent... 2. Subset is valid..."
                    //   // "Update max_size if current subset has more vertices"
                    //   // 
                    //   // Logic sketch:
                    //   // State PROCESSING:
                    //   //   if (mask == 256) -> next_state = DONE
                    //   //   else begin
                    //   //      if (edge_idx == 0) begin
                    //   //          // Check Validity
                    //   //          // Calculate Popcount
                    //   //          // Set is_independent = 1
                    //   //          // Edge check start
                    //   //      end
                    //   //      else if (edge_idx <= num_edges) begin
                    //   //          // Check edge[edge_idx-1] (if edge_idx > 0)
                    //   //          // Actually, let's make edge_idx iterate 0 to num_edges-1 for edges.
                    //   //          // If edge_idx == 0, we init.
                    //   //          // If edge_idx > 0 and edge_idx <= num_edges, check edges.
                    //   //          // Wait, if num_edges = 0, we skip edge loop.
                    //   //      end
                    //   //      else begin // edge_idx > num_edges (or equivalent condition)
                    //   //          // Update Max
                    //   //          // Increment Mask
                    //   //          // Reset edge_idx
                    //   //      end
                    //   //   end
                    //   // 
                    //   // Let's refine the edge_idx usage.
                    //   // `edge_idx` will index the edge array. Range 0 to 7.
                    //   // We need to know if we are done checking edges for the current mask.
                    //   // Let's add a register `edge_check_done`.
                    //   // Or, use `edge_idx` to iterate until `num_edges`.
                    //   // If `edge_idx` == `num_edges`, we are done with edges.
                    //   // 
                    //   // Proposed Logic inside PROCESSING:
                    //   // 
                    //   // if (mask == 8'hFF) ...
                    //   // 
                    //   // We need to separate the "Update Mask" action from the "Edge Check" loop.
                    //   // 
                    //   // Let's use `edge_idx` as a state machine for the mask check.
                    //   // `edge_idx` value meanings:
                    //   // 0: Init phase (calculate validity, popcount, reset independence).
                    //   // 1 to num_edges: Edge check phase.
                    //   // num_edges + 1: Update max phase.
                    //   // 
                    //   // This requires comparisons against `num_edges`. 
                    //   // Since `num_edges` is up to 8, this is okay.
                    //   // 
                    //   // Let's implement this.
                    //   // 
                    //   // Wait, if `num_edges` changes during operation (unlikely), we should latch it.
                    //   // Assume inputs are stable.
                    //   // 
                    //   // Let's use an internal register `active_mask` to hold the mask we are currently processing.
                    //   // And `mask_counter` to iterate 0..255.
                    //   // 
                    //   // Actually, let's just use `mask` as the counter.
                    //   // 
                    //   // Let's define `sub_state` using `edge_idx` bit 3.
                    //   // 0: check edges (edge_idx[2:0] is index)
                    //   // 1: update max (edge_idx[2:0] unused)
                    //   // But we need to know when we are done with edges.
                    //   // 
                    //   // Let's use `edge_idx` as the index into edge_a/b.
                    //   // And a separate bit `phase_is_update`.
                    //   // 
                    //   // Registers:
                    //   // `mask` (0..255)
                    //   // `idx` (0..7 for edges)
                    //   // `phase` (0: init/check edges, 1: update max)
                    //   // 
                    //   // Let's go with a 3-bit `edge_idx` (0..7) and a 1-bit `update_phase`.
                    //   // `edge_idx` will count up to `num_edges`.
                    //   // `update_phase` will be high when we are updating max.
                    //   // 
                    //   // Logic in PROCESSING:
                    //   // 
                    //   // if (!update_phase) begin
                    //   //   if (edge_idx == 0) begin
                    //   //      // Check Validity
                    //   //      // Check Popcount (compute size)
                    //   //      // Reset independent_flag
                    //   //      // edge_idx++
                    //   //      // Wait, we need to handle num_edges=0 case.
                    //   //      // If num_edges == 0, skip to update immediately.
                    //   //   end else if (edge_idx <= num_edges) begin
                    //   //      // Check edge[edge_idx-1] (wait, edge_idx starts at 1?)
                    //   //      // Let's make edge_idx iterate 0..num_edges-1 for edges.
                    //   //      // If edge_idx < num_edges: check edge[edge_idx], increment.
                    //   //      // If edge_idx == num_edges: switch to update_phase.
                    //   //   end
                    //   // end else begin // update_phase
                    //   //   // Update max_size
                    //   //   // Increment mask
                    //   //   // Reset edge_idx, reset update_phase
                    //   //   // If mask == 256 (or 0 after wrapping?), set processing_done
                    //   // end
                    //   // 
                    //   // This seems clean.
                    //   // 
                    //   // Let's refine `edge_idx` iteration.
                    //   // `edge_idx` goes 0, 1, ... num_edges-1.
                    //   // When `edge_idx` == `num_edges`, we are done with edges.
                    //   // 
                    //   // Implementation:
                    //   // 
                    //   // Registers to update:
                    //   // `mask` (8 bit)
                    //   // `edge_idx` (4 bit, enough for 8 edges + state)
                    //   // `phase` (1 bit: 0=EDGE_CHECK, 1=UPDATE)
                    //   // `is_independent` (1 bit)
                    //   // `current_size` (4 bit)
                    //   // `valid` (1 bit)
                    //   // `max_size` (4 bit)
                    //   // 
                    //   // 
                    //   // Edge Check Logic:
                    //   //   if (phase == EDGE_CHECK) begin
                    //   //     if (edge_idx == 0) begin
                    //   //         // Initial checks for the mask
                    //   //         // valid <= (mask & ~((1<<num_nodes)-1)) == 0;
                    //   //         // current_size <= count_ones(mask);
                    //   //         // is_independent <= 1'b1;
                    //   //         // edge_idx <= edge_idx + 1;
                    //   //         // BUT if num_edges is 0, we need to skip to UPDATE immediately.
                    //   //         // Actually, the check "if (edge_idx < num_edges)" will handle num_edges=0.
                    //   //         // If num_edges=0, edge_idx(0) < 0(false). So we switch to UPDATE.
                    //   //         // But we need to run the validity/popcount check first.
                    //   //         // So we need a step.
                    //   //         // 
                    //   //         // Let's separate Init step.
                    //   //         // Let's use `edge_idx` to count 0..num_edges.
                    //   //         // If `edge_idx` == `num_edges`, we switch to UPDATE.
                    //   //         // 
                    //   //         // If `edge_idx` < `num_edges`:
                    //   //         //   Check edge[edge_idx]
                    //   //         //   edge_idx++
                    //   //         //   // We need to run Init once before this loop.
                    //   //         //   // So we can trigger Init when `edge_idx` == 0, BEFORE checking edges.
                    //   //     end
                    //   //   end
                    //   // 
                    //   // Let's implement Init when `edge_idx` is 0.
                    //   // Then iterate `edge_idx` from 0 to `num_edges-1`.
                    //   // When `edge_idx` hits `num_edges`, switch to UPDATE phase.
                    //   // 
                    //   // To avoid extra registers, we can compute popcount combinationally.
                    //   // `wire [3:0] pop = mask[0] + mask[1] + ... + mask[7];`
                    //   // `wire valid = (mask & ~((1<<num_nodes)-1)) == 0;`
                    //   // This is safer and saves registers.
                    //   // Let's do that.
                    //   // 
                    //   // Combinational logic for Popcount and Validity:
                    //   // wire valid_mask = (mask & ~((1 << num_nodes) - 1)) == 0;
                    //   // wire [3:0] subset_size = mask[0] + mask[1] + ... mask[7];
                    //   // 
                    //   // Sequential Logic:
                    //   // if (phase == EDGE_CHECK) begin
                    //   //   if (edge_idx == 0) begin
                    //   //      // We are just starting a new mask. Initialize independence.
                    //   //      is_independent <= 1'b1;
                    //   //      // We don't need to store valid or size, we just use the wire values at UPDATE phase.
                    //   //      // But wait, we need to increment edge_idx.
                    //   //      // Let's do: if edge_idx < num_edges, check edge, inc edge_idx.
                    //   //      // 
                    //   //      // If num_edges == 0, we go directly to UPDATE? No, because edge_idx(0) is not < 0.
                    //   //      // So we need an else clause.
                    //   //      // 
                    //   //      // Let's structure:
                    //   //      // if (edge_idx < num_edges) begin
                    //   //      //    check edge[edge_idx]; update is_independent; edge_idx++;
                    //   //      // end else begin
                    //   //      //    phase <= UPDATE;
                    //   //      // end
                    //   //      // 
                    //   //      // BUT! When edge_idx == 0, we haven't initialized is_independent yet.
                    //   //      // So we need to initialize it ONCE before the loop.
                    //   //      // 
                    //   //      // Let's use a flag `initialized` or just rely on `edge_idx`.
                    //   //      // If `edge_idx` == 0, set `is_independent` = 1.
                    //   //      // Then, if `edge_idx` < `num_edges`, check edge[edge_idx], inc.
                    //   //      // 
                    //   //      // Wait, if `edge_idx` == 0 and `num_edges` == 0, we go to `else` immediately.
                    //   //      // `is_independent` is set to 1. Then we go to UPDATE.
                    //   //      // 
                    //   //   end
                    //   // end
                    //   // 
                    //   // This logic looks correct.
                    //   // 
                    //   // Update Phase:
                    //   // if (phase == UPDATE) begin
                    //   //   // Check: if valid_mask && is_independent
                    //   //   // Then max_size = max(max_size, subset_size)
                    //   //   // Then mask++
                    //   //   // Then reset phase to EDGE_CHECK, edge_idx to 0.
                    //   //   // If mask == 256, processing_done = 1.
                    //   // end
                    //   // 
                    //   // Let's implement `valid_mask` and `subset_size` as wires.

    // Internal wires
    wire [7:0] validity_filter = ~((1 << num_nodes) - 1);
    wire valid_mask = (mask & validity_filter) == 0;
    
    // Popcount implementation (combinational)
    wire [3:0] subset_size;
    assign subset_size = mask[0] + mask[1] + mask[2] + mask[3] + 
                         mask[4] + mask[5] + mask[6] + mask[7];

    // Combinational logic for edge check
    wire edge_conflict = (mask[edge_a[edge_idx]] && mask[edge_b[edge_idx]]);

    // Registers for internal state
    reg phase; // 0: Edge Check, 1: Update Max
    reg [3:0] edge_idx_reg; // 0 to 8
    reg independent_reg;

    // Next state logic for internal processing (Phase and counters)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= 8'b0;
            max_size <= 4'b0;
            result <= 4'b0;
            done <= 1'b0;
            phase <= 1'b0; // Start in edge check (which initializes)
            edge_idx_reg <= 4'b0;
            independent_reg <= 1'b1;
            processing_done <= 1'b0;
        end else if (state == PROCESSING) begin
            if (phase == 1'b0) begin // Edge Check Phase
                // Initialize independence on first step of a new mask (edge_idx_reg == 0)
                if (edge_idx_reg == 0) begin
                    independent_reg <= 1'b1;
                end

                if (edge_idx_reg < num_edges) begin
                    // Check current edge
                    if (edge_conflict) begin
                        independent_reg <= 1'b0;
                    end
                    edge_idx_reg <= edge_idx_reg + 1;
                end else begin
                    // Done with edges for this mask, switch to Update Phase
                    phase <= 1'b1;
                end
            end else begin // Update Phase
                // Update Max Size if valid and independent
                if (valid_mask && independent_reg) begin
                    if (subset_size > max_size) begin
                        max_size <= subset_size;
                    end
                end

                // Move to next mask
                mask <= mask + 1;
                
                // Check if we are done (mask becomes 255 -> we just processed 255)
                // Wait, mask was 255, we just processed it.
                // Next value is 256 (9'b1_0000_0000). Truncate to 8 bits is 0.
                // We need to detect the end of the loop.
                // We stop after processing mask 255.
                // So if mask == 255, set done flag.
                if (mask == 8'hFF) begin
                    processing_done <= 1'b1;
                end

                // Reset for next mask
                phase <= 1'b0;
                edge_idx_reg <= 4'b0;
            end
        end else if (state == IDLE) begin
            // Reset counters if needed, or hold values
            // On start, registers are reset in the main block (handled by specific reset logic in IDLE check above? No, handled here if we add condition)
            // Let's ensure clean start:
            if (start) begin
                mask <= 8'b0;
                max_size <= 4'b0;
                phase <= 1'b0;
                edge_idx_reg <= 4'b0;
                independent_reg <= 1'b1;
                processing_done <= 1'b0;
            end
        end else if (state == DONE) begin
            // Latch result
            result <= max_size;
            done <= 1'b1;
        end
    end

    // Continuous assignment for done signal logic based on state
    // (The done output is registered in the always block above for cleaner timing)
    
    // Note: The logic above assumes that `valid_mask` and `subset_size` are computed based on the current `mask`.
    // In the Update Phase (phase==1), we use these values. 
    // However, we increment `mask` at the end of the Update Phase.
    // So when `phase` switches to 1, `mask` still holds the mask we just checked.
    // This is correct.

endmodule
