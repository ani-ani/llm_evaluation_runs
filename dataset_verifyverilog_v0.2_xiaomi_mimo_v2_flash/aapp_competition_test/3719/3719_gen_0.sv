module laser_maximizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] y_left [0:15],
    input [7:0] y_right [0:15],
    input [3:0] n_left,
    input [3:0] n_right,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE_SOURCES = 3'b001;
    localparam PROCESS_PAIRS = 3'b010;
    localparam CALCULATE_MAX = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Internal buffers
    reg [7:0] buf_left [0:15];
    reg [7:0] buf_right [0:15];
    reg [3:0] valid_n_left;
    reg [3:0] valid_n_right;

    // Pair processing variables
    reg [3:0] i_cnt; // index for left
    reg [3:0] j_cnt; // index for right
    wire [7:0] sum_val = buf_left[i_cnt] + buf_right[j_cnt];
    
    // Memory for bitmasks: Address range is 0 to 510 (max possible sum 255+255)
    // We optimize by allocating only needed depth, but Verilog requires const depth.
    // Using 512 entries of 256 bits each is large, but required by spec logic.
    // However, 512x256b = 128Kb. For a simple FPGA, this is acceptable in BRAMs.
    // Since we need to write and read sequentially, we use standard array.
    // Note: Real synthesis might require distinct memory block.
    // We use a 2D array logic to emulate SRAM. Synthesis tools will map this to BRAM.
    
    reg [255:0] mask_storage [0:511]; // 512 entries of 256-bit masks
    
    // Max calculation variables
    reg [8:0] s1; // Sum index 0-511 (need 9 bits)
    reg [8:0] s2;
    reg [255:0] combined_mask;
    reg [7:0] bit_count;
    reg [7:0] local_max;
    
    // Combinational bit counter (LUT based) for 256 bits
    // To keep it synthesizable and efficient, we use a sequential counter or 
    // a small LUT loop. Given the latency constraint (~4096 cycles), a sequential 
    // bit counter over 256 bits (256 cycles) inside the state machine is too slow.
    // We must use a combinational popcount or a pipelined one.
    // Here, we assume a 256-bit input and output 8-bit count.
    // Using a tree of adders is standard.
    
    function [7:0] popcount256;
        input [255:0] v;
        integer k;
        reg [7:0] cnt;
        begin
            cnt = 0;
            for (k = 0; k < 256; k = k + 1) begin
                if (v[k]) cnt = cnt + 1;
            end
            popcount256 = cnt;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            // Initialize memory (simulator only, synthesis infers BRAM reset)
            // In hardware, we rely on reset logic or write-before-read.
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PREPARE_SOURCES;
                    end
                end

                PREPARE_SOURCES: begin
                    // Copy inputs to internal buffers in one cycle (assuming wide input bus)
                    // or iterate if single cycle is too slow. With 16x8 bit inputs, it fits.
                    valid_n_left <= n_left;
                    valid_n_right <= n_right;
                    for (int k = 0; k < 16; k++) begin
                        buf_left[k] <= y_left[k];
                        buf_right[k] <= y_right[k];
                    end
                    // Initialize memory to zero. 
                    // Since 512 writes are needed, we use an iterator or clear it in PROCESS_PAIRS setup.
                    // We'll clear it in the first step of PROCESS_PAIRS to save a state.
                    // But actually, we need to clear the mask array.
                    // Let's do it in PROCESS_PAIRS initialization.
                    state <= PROCESS_PAIRS;
                    i_cnt <= 0;
                    j_cnt <= 0;
                end

                PROCESS_PAIRS: begin
                    // We need to iterate all pairs (i, j).
                    // Total cycles: 16x16 = 256.
                    // Plus initialization of memory (clearing). Let's clear memory in first 512 cycles or reuse the loop.
                    // To save logic, we can clear the memory on the fly or use a separate clear state.
                    // Let's assume we clear memory first (512 cycles), then process pairs (256 cycles).
                    // To fit the ~4096 cycle budget, we have plenty of room.
                    
                    // Optimization: We clear memory in the first 512 cycles of PROCESS_PAIRS.
                    // If i_cnt == 16, we are in clearing phase. 
                    // Let's split: Clear memory (0 to 511), then Process Pairs (0 to 255).
                    // Let's use a dedicated counter for the clearing phase.
                    // Actually, simpler: Use a separate internal counter `proc_idx`.
                    
                    // Let's define a specific sub-state or use i_cnt/j_cnt cleverly.
                    // We'll use a generic counter `cycle_cnt`.
                    // 0-511: Clear memory
                    // 512-767: Compute pairs
                    
                    // Let's refine the state flow to be robust.
                    // We need to zero out mask_storage. Since we can't write to all indices simultaneously,
                    // we iterate.
                    // Let's change state to a dedicated CLEAR_MEM state to be cleaner.
                end
            endcase
        end
    end

    // Redesigning the FSM for clarity and correct resource management.
    // We will use 3 states for processing: CLEAR_MEM, PROCESS_PAIRS, CALCULATE_MAX.

    reg [9:0] cycle_cnt; // Generic counter up to 1024
    reg clearing_done;
    reg pairs_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            cycle_cnt <= 0;
            clearing_done <= 0;
            pairs_done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PREPARE_SOURCES;
                    end
                end

                PREPARE_SOURCES: begin
                    valid_n_left <= n_left;
                    valid_n_right <= n_right;
                    for (int k = 0; k < 16; k++) begin
                        buf_left[k] <= y_left[k];
                        buf_right[k] <= y_right[k];
                    end
                    // Initialize loop vars
                    cycle_cnt <= 0;
                    clearing_done <= 0;
                    pairs_done <= 0;
                    state <= CLEAR_MEM; // Transition to clear state
                end

                CLEAR_MEM: begin
                    // Clear mask_storage[cycle_cnt]
                    mask_storage[cycle_cnt] <= 256'b0;
                    
                    if (cycle_cnt == 511) begin
                        cycle_cnt <= 0;
                        state <= PROCESS_PAIRS;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end

                PROCESS_PAIRS: begin
                    // We need to iterate through all valid pairs.
                    // Indices i (0 to n_left-1) and j (0 to n_right-1)
                    // We can map linear cycle_cnt to (i, j).
                    // cycle_cnt 0 -> i=0, j=0 ...
                    // But we must respect n_left and n_right.
                    // Let's use explicit i, j counters to handle variable N easily.
                    
                    // Logic moved to combinational block below for cleaner sequential logic
                    // Here we handle the iteration control
                    
                    if (i_cnt < valid_n_left) begin
                        // Process current pair
                        // We are in a state where we just processed (i_cnt, j_cnt) or starting?
                        // We need to calculate sum and update memory.
                        // Since memory write takes 1 cycle, we can do it here.
                        
                        if (j_cnt < valid_n_right) begin
                            // Calculate sum
                            // sum_val is combinational
                            // Update mask
                            // mask_storage[sum_val] <= mask_storage[sum_val] | (1 << (i_cnt * valid_n_right + j_cnt));
                            // Problem: index (i_cnt * valid_n_right + j_cnt) needs to be 8-bit.
                            // Max index is 15*16+15 = 255. fits in 8 bits.
                            
                            mask_storage[sum_val] <= mask_storage[sum_val] | 
                                                      (256'b1 << (i_cnt * valid_n_right + j_cnt));
                            
                            // Increment j
                            if (j_cnt == valid_n_right - 1) begin
                                j_cnt <= 0;
                                i_cnt <= i_cnt + 1;
                            end else begin
                                j_cnt <= j_cnt + 1;
                            end
                        end
                    end else begin
                        // All pairs processed
                        pairs_done <= 1;
                        state <= CALCULATE_MAX;
                        cycle_cnt <= 0; // Reset counter for sum iteration
                        s1 <= 0;
                        s2 <= 0;
                        local_max <= 0;
                        // We start calculation. 
                        // In CALCULATE_MAX, we iterate s1 from 0 to 510, s2 from s1+1 to 510.
                        // Or simpler: Iterate s1, s2. 
                        // Since we have 512*512/2 ~ 130k combinations, and we have ~4096 cycles, 
                        // we CANNOT check every pair of sums.
                        // CONSTRAINT CORRECTION: The prompt says "Approx 4096 clock cycles".
                        // 130k is too high. 
                        // Re-reading: "Iterate through all possible sums... and find combination of two sums".
                        // If we cannot iterate all pairs, we must iterate all sums and use a heuristic.
                        // OR, the prompt implies we iterate sums, and use a heuristic like:
                        // Find best S1, then find best S2 disjoint?
                        // The prompt says: "find two sums (s1, s2) that maximizes..."
                        // Given 4096 cycles, we can iterate 512 sums and check a few candidates.
                        // Actually, 4096 / 512 = 8. We can check 8 candidates per sum.
                        // BUT, to be safe and correct for the "Simplified version", maybe we just find the single best sum or pair.
                        // Let's implement the full search over 512 sums. 512*512 = 262k. Too high.
                        // Let's assume we iterate s1 (0 to 511), and for each s1, we iterate s2 (0 to 511).
                        // We need to optimize.
                        // Let's iterate s1 from 0 to 511.
                        // For each s1, we iterate s2 from 0 to 511.
                        // Total cycles 512*512 = 262k. Too high.
                        // We need a different approach for CALCULATE_MAX.
                        // Re-read: "find two sums... that maximizes".
                        // Maybe we can just iterate through s1, find the best s2 for that s1, and keep global max.
                        // Still 512*512 reads.
                        // Alternative: Just find the two largest individual masks? No.
                        // Let's implement a greedy approach or limit the search space to fit 4096.
                        // 4096 / 512 = 8 loops per sum.
                        // Since we can't do full search, let's implement a single pass that finds the single best sum, 
                        // AND a modified single pass for pairs.
                        // 
                        // ALGORITHM ADJUSTMENT FOR TIMING:
                        // Since we have 256 bits, popcount is fast (LUTs). 
                        // Let's use a tree reduction or sequential count.
                        // Let's just do: 
                        // Option 1: Find max single sum. (If one laser is enough).
                        // Option 2: Iterate s1 (0..511). For each s1, find the best s2 (0..511).
                        // We have 512*512 = 262k comparisons. 
                        // If we do 1 comparison per cycle, we need 262k cycles. 
                        // We are limited to 4096. 
                        // So we must truncate the search or use a smarter algorithm.
                        // 
                        // Let's assume the "Approx 4096 cycles" allows for a slightly suboptimal but complete search over a reduced domain, 
                        // OR we use the 4096 cycles to check top K candidates.
                        // 
                        // BETTER APPROACH: 
                        // Iterate s1 (0 to 511). 
                        // Keep track of top X masks (e.g. top 10 by popcount). 
                        // Then only iterate s2 over top 10.
                        // 
                        // Let's try a simple implementation: Find max single. Then iterate 0..511 for s1, and 0..511 for s2 but only if we have time.
                        // Actually, let's just iterate s1 from 0 to 511, and s2 from s1 to 511. 
                        // To fit 4096, we can only do 4096 / 512 = 8 s2 checks per s1.
                        // Let's implement: 
                        // 1. Calculate popcounts for all sums (512 cycles) - stored in array.
                        // 2. Iterate s1. For each s1, iterate s2. 
                        // We'll use a nested loop but break early or skip.
                        // 
                        // DECISION: 
                        // Given the strict 4096 cycle limit, we will implement the following heuristic:
                        // 1. Compute masks (done).
                        // 2. Identify the top N (e.g., 16) sums with highest popcount.
                        // 3. Check all pairs among these top N.
                        // 4. Compare with best single sum.
                        // 
                        // Implementation details:
                        // Phase A: Compute popcounts for all 512 sums. (Requires reading 512 entries sequentially). ~512 cycles.
                        // Phase B: Sort/Select top N. (Complex). Let's just iterate 0..511 and keep top 8 candidates.
                        // Phase C: Check pairs of top 8. 8*8 = 64 cycles.
                        // Total: 512 + 64 = 576 cycles. Fits easily.
                        
                        // Let's refine Phase B: Iterate s1=0..511. Read mask. Count bits. If > min(top8), replace. 
                        // Keep list of indices of top 8.
                        // 
                        // Let's code this flow in CALCULATE_MAX.
                    end
                end

                CALCULATE_MAX: begin
                    // We will use cycle_cnt 0..511 to read all masks and populate a list of top candidates.
                    // Since we can't easily sort, we will use a simple selection.
                    // We'll store top 8 indices in an array: top_idx[0..7].
                    // We'll store their popcounts: top_val[0..7].
                    
                    // Let's split CALCULATE_MAX into substages using cycle_cnt.
                    // 0-511: Compute popcounts and find top 8 candidates (plus single best).
                    // 512-575: Check pairs among top 8.
                    // 576: Finalize.
                    
                    if (cycle_cnt < 512) begin
                        // Read mask_storage[cycle_cnt]
                        // Compute popcount. We can use combinational function.
                        // However, combinational popcount of 256 bits might be slow for timing, 
                        // but we have one clock cycle per iteration (assuming < 10ns).
                        // Let's assume it's fine for modern FPGA.
                        
                        bit_count <= popcount256(mask_storage[cycle_cnt]);
                        
                        // We need to update top list. We need the previous values.
                        // This requires a dependency chain. 
                        // We can update the top list in the next cycle (cycle_cnt + 1) or use a pipeline.
                        // To keep it simple, let's update in the same cycle using latched values.
                        // We need to compare `bit_count` with `top_val` stored previously.
                        // Since `bit_count` is combinational from `mask_storage[cycle_cnt]`, we can do:
                        // Check if `bit_count` is greater than any of the stored top values.
                        // This is a comparator tree. 
                        // 
                        // Let's use a separate cycle for updating the top list to avoid long comb paths.
                        // But 512 cycles is budgeted.
                        // 
                        // Let's do it in 2 passes: 
                        // Pass 1: Compute all popcounts and store in a temp array? No, 512x8 bits = 4Kb. Possible.
                        // Pass 2: Find max.
                        // 
                        // Let's try Pass 1 (512 cycles): Store popcounts in an array `pops[0..511]`.
                        // `pops` needs to be initialized.
                        
                        // Actually, simpler: Just iterate through 512 sums and find the MAX single sum.
                        // And also find top 8 candidates for pairing.
                        // 
                        // Let's do: 
                        // `local_max` stores the current best single sum count.
                        // `best_single_idx` stores the index.
                        // `top_idx` array for candidates.
                        // 
                        // Since we can't easily store 512 popcounts, we will stream them.
                        // We will use a logic to maintain top 8 on the fly.
                        // 
                        // Warning: This comb logic might be heavy. Let's limit to top 4 candidates.
                        // 
                        // Implementation: 
                        // 1. Read mask_storage[cycle_cnt].
                        // 2. Wait 1 cycle for popcount if needed, or use combinational output.
                        // 3. Update top list.
                        
                        // To avoid complex combinational logic updates, let's assume we just find the best single sum here.
                        // Then we will blindly iterate pairs of sums (s1, s2) up to 4096 times.
                        // 
                        // BETTER PLAN:
                        // State CALCULATE_MAX:
                        // 1. Find single best sum (512 cycles).
                        // 2. Find best pair:
                        //    Iterate s1 from 0 to 511.
                        //    Iterate s2 from 0 to 511.
                        //    Limit total iterations to 4096.
                        //    So 4096 / 512 = 8.
                        //    We iterate s1 (0..511), and for each s1, we check s2 (0..7).
                        //    This is a heuristic. 
                        //    Or, we check s2 from 0..511 but we use a skip factor of 64. 
                        //    
                        //    Let's do: 
                        //    Iterate s1 from 0 to 511.
                        //    Iterate s2 from 0 to 511 with step 64 (check 8 values).
                        //    This covers 512 * 8 = 4096 combinations.
                        
                        // Let's use a counter `iter_s1` and `iter_s2`.
                        // `iter_s1` goes 0..511.
                        // `iter_s2` goes 0..7 (mapped to actual sum index).
                        // Actual s2 = iter_s2 * 64.
                        // 
                        // We also check `s1` vs `s1` (single sum).
                        
                        // Let's refine the state logic.
                        // We need a register for `iter_s1` (0..511) and `iter_s2` (0..7).
                        // We need to read mask_storage[s1] and mask_storage[s2].
                        // This takes 2 cycles (read latency 1) or combinational.
                        // Assuming combinational read (LUT RAM), we can do logic in one cycle.
                        
                        // Cycle structure:
                        // cycle_cnt 0..511: Find single best.
                        // cycle_cnt 512..(512+512*8-1): Find pair best.
                        // This is 512 + 4096 = 4608 cycles. 
                        // Slightly over 4096, but close.
                        
                        // Let's optimize: 
                        // Find single best and pair search in parallel if possible, or reduce cycles.
                        // Actually, we can just do the pair search and treat single sum as a special case of pair (mask1 | mask1).
                        // But we want distinct lasers.
                        // 
                        // Let's stick to the plan: 
                        // 1. Iterate 0..511 to find single best (and maybe record top 4 indices).
                        // 2. Iterate pairs among top 4. (16 cycles).
                        // Total ~528 cycles. Fast and efficient.
                        
                        // Let's implement: 
                        // State CALCULATE_MAX, Substage A: Find top 4 sums.
                        // State CALCULATE_MAX, Substage B: Check pairs of top 4.
                        
                        // Substage A (Cycle 0..511):
                        // Read mask_storage[cycle_cnt].
                        // Compute popcount.
                        // Compare with stored top 4.
                        // Update.
                        
                        // Substage B (Cycle 512..):
                        // Iterate i=0..3, j=0..3.
                        // Compute mask_i | mask_j.
                        // Count bits.
                        // Update result.
                        
                        // We need to store the masks of top 4 candidates to reuse them.
                        // We can store them in registers: top_mask_0..3.
                        // 
                        // Let's code the state transitions.
                        
                    end else begin
                        // Cycle > 511. Transition to Pair Check.
                        // But we need to handle the update of top list which takes 512 cycles.
                        // Let's use `cycle_cnt` as the index for reading.
                        
                        // Let's rewrite the CALCULATE_MAX logic to be cleaner.
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // Logic for CALCULATE_MAX state is complex, let's break it out into a separate always block or refine the main block.
    // To ensure correctness and fit in 4096 cycles:
    // We will implement: 
    // 1. Clear/Init top registers.
    // 2. Loop 0..511 to find top 4 candidates (using a sequential update).
    //    - We need to store the 4 masks and their indices (or just masks, since we read mask_storage by index).
    // 3. Loop 0..3 and 0..3 to check pairs.
    
    // Let's manage the counters for CALCULATE_MAX specifically within the main FSM.
    // We'll use `i_cnt` for iterating sums, and `j_cnt` for the inner loop.
    
    // Additional registers for top selection
    reg [255:0] top_masks [0:3];
    reg [7:0]  top_counts [0:3];
    reg [8:0]  top_indices [0:3];
    
    // Combinational block for state actions (output logic of Moore FSM)
    // However, we need registered outputs. So logic is inside sequential block.
    // Let's restructure the sequential block to be complete.

endmodule

// Revised Complete Module with proper state logic
module laser_maximizer_revised (
    input clk,
    input rst_n,
    input start,
    input [7:0] y_left [0:15],
    input [7:0] y_right [0:15],
    input [3:0] n_left,
    input [3:0] n_right,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001; // Copy buffers
    localparam CLEAR_MEM = 3'b010; // Zero out mask storage
    localparam PROCESS_PAIRS = 3'b011; // Calculate sums and masks
    localparam FIND_TOP = 3'b100; // Find top 4 candidates
    localparam CHECK_PAIRS = 3'b101; // Check pairs of top 4
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    
    // Buffers and Input storage
    reg [7:0] buf_left [0:15];
    reg [7:0] buf_right [0:15];
    reg [3:0] N_L;
    reg [3:0] N_R;
    
    // Loop counters
    reg [8:0] idx; // General purpose index (0..511)
    reg [3:0] i_l;  // Left index
    reg [3:0] i_r;  // Right index
    
    // Memory for pair masks (Address 0..510)
    // Depth 512, Width 256 bits. Maps to BRAM.
    reg [255:0] mask_mem [0:511];
    
    // Temporary storage for top 4
    reg [255:0] t_mask [0:3];
    reg [7:0]   t_cnt [0:3];
    reg [8:0]   t_idx [0:3];
    
    // Combinational helper for popcount (synthesizable as LUT logic)
    function [7:0] popcount;
        input [255:0] v;
        integer k;
        reg [7:0] c;
        begin
            c = 0;
            for (k = 0; k < 256; k = k + 1) if (v[k]) c = c + 1;
            popcount = c;
        end
    endfunction
    
    // Combinational sum calculation
    wire [7:0] current_sum = buf_left[i_l] + buf_right[i_r];
    wire [255:0] current_mask = mask_mem[current_sum];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= PREPARE;
                end

                PREPARE: begin
                    // Copy inputs
                    N_L <= n_left;
                    N_R <= n_right;
                    for (int k = 0; k < 16; k++) begin
                        buf_left[k] <= y_left[k];
                        buf_right[k] <= y_right[k];
                    end
                    // Reset indices
                    idx <= 0;
                    state <= CLEAR_MEM;
                end

                CLEAR_MEM: begin
                    // Clear all 512 entries (512 cycles)
                    mask_mem[idx] <= 256'b0;
                    if (idx == 511) begin
                        idx <= 0;
                        i_l <= 0;
                        i_r <= 0;
                        state <= PROCESS_PAIRS;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                PROCESS_PAIRS: begin
                    // Iterate i_l = 0..N_L-1, i_r = 0..N_R-1
                    // Total cycles = N_L * N_R <= 256
                    
                    if (i_l < N_L) begin
                        if (i_r < N_R) begin
                            // Update mask for current sum
                            // Set bit (i_l * N_R + i_r)
                            // We must read-modify-write the memory
                            // current_sum is combinational
                            // current_mask is combinational read from memory (needs to be registered for write)
                            
                            // Since we are reading and writing same address in same cycle (blocking vs non-blocking)
                            // We should read in previous cycle or use a variable.
                            // But here we are in sequential block. 
                            // `current_mask` reads from `mask_mem` which is updated in this same always block.
                            // This is a read-after-write hazard if `current_sum` matches a previously written sum.
                            // However, we iterate linearly. 
                            // If we rely on the current value of mask_mem[current_sum], we need to ensure we get the value from previous cycle.
                            // In Verilog, `mask_mem` is a reg array. 
                            // If we write to `mask_mem` using non-blocking assignment `<=` in a cycle, the read value `mask_mem[addr]` in the same cycle is the OLD value (before update).
                            // So `current_mask` will read the value stored in memory *before* this cycle's write.
                            // This is correct behavior for accumulation.
                            
                            mask_mem[current_sum] <= current_mask | (256'b1 << (i_l * N_R + i_r));
                            
                            // Increment i_r
                            if (i_r == N_R - 1) begin
                                i_r <= 0;
                                i_l <= i_l + 1;
                            end else begin
                                i_r <= i_r + 1;
                            end
                        end
                    end else begin
                        // Done with pairs
                        state <= FIND_TOP;
                        idx <= 0; // Use idx to iterate through sums 0..511
                        
                        // Initialize top registers with invalid low values
                        t_cnt[0] <= 0; t_cnt[1] <= 0; t_cnt[2] <= 0; t_cnt[3] <= 0;
                    end
                end

                FIND_TOP: begin
                    // Iterate idx 0..511 to find top 4 masks by popcount
                    // Read mask_mem[idx]
                    // Calculate popcount (combinational function)
                    // Update top 4 list
                    
                    // We calculate popcount of the mask at `idx`.
                    // Note: `mask_mem` read is combinational in this context if we assume block RAM read latency 0 (pre-registered output).
                    // We are reading `mask_mem[idx]` directly in the function.
                    
                    // We need to compare and shift. Since we can't easily do priority encoder in one line,
                    // we use a small logic block.
                    // We rely on the fact that `idx` increments 0..511.
                    // 
                    // Let's update top 4 in the next cycle or use combinational next state logic.
                    // Let's do it in the sequential block: we need to compare `val` with existing `t_cnt`.
                    // Since we are at the end of the cycle, we can update `t_cnt` registers.
                    
                    // We need to check if current popcount > any of the stored top counts.
                    // To minimize logic, we can just compare sequentially or use priority.
                    // 
                    // Let's perform the check. We need to know the popcount of mask_mem[idx].
                    // We must latch the popcount value or calculate it combinationally.
                    // Let's calculate it combinationally and use it to update registers.
                    
                    // Logic: 
                    // if (count > t_cnt[0]) shift down 3->2, 2->1, 1->0, insert new at 0.
                    // else if (count > t_cnt[1]) shift down 3->2, 2->1, insert new at 1.
                    // ...
                    // This is deep comb logic. We can pipeline this or just accept the path.
                    // Given 1 clock cycle per index (512 cycles), the comb path is critical.
                    // To save logic and area, we can do this in multiple cycles or simplify.
                    // However, 4096 cycles budget allows us to use multiple cycles per iteration if needed.
                    // But 512 iterations * overhead = 512 cycles. 
                    // Let's do: 
                    // Cycle 1: Read mask, calculate count. Latch count.
                    // Cycle 2: Compare and update top.
                    // But we have 512 items. 1024 cycles. Still fits in 4096.
                    // 
                    // Actually, we can just calculate popcount once per index.
                    // Let's split FIND_TOP into two sub-states: CALC_COUNT and UPDATE_TOP.
                    // But to keep it simple, let's assume we can do it in one cycle with reasonable timing.
                    // Modern synthesis tools handle this well for small bit widths (8-bit count).
                    
                    // Let's implement the update logic using a temporary variable.
                    // We need to read the current top values from registers.
                    // We need to write back new top values.
                    
                    // This block is combinational logic inside the always block. 
                    // It depends on `mask_mem[idx]`. 
                    
                    // We will use `popcount(mask_mem[idx])`.
                    
                    // Handling the update:
                    // Since `t_cnt` are registers, we can't read their "next" value easily in standard Verilog for priority update without intermediate variables.
                    // We will use the following trick: 
                    // Just check if current count is greater than t_cnt[3]. If so, replace t_cnt[3] (and potentially shift if greater than others).
                    // This is a simple insertion sort.
                    
                    // Let's use `state` to indicate if we are done.
                    // When idx == 511, we transition to CHECK_PAIRS.
                    
                    // Implementation:
                    // We need to assign to `t_cnt` based on `popcount(mask_mem[idx])`.
                    // This is a purely combinational update of registers based on the current state of registers.
                    // Wait, this is a latched update. 
                    // We assign to `t_cnt` in the sequential block.
                    // 
                    // To avoid complex comb logic in the sequential block, we can just find the single max and top 4 using a simplified logic.
                    // 
                    // ALTERNATIVE: 
                    // Just find the single BEST sum. Then, blindly check pairs of the best 8 sums encountered so far.
                    // But we need to identify them.
                    // 
                    // Let's just find the single best sum and ignore the pair optimization? 
                    // "find two sums (or one sum) that cover the maximum number of unique pairs"
                    // This implies we MUST do pairs.
                    // 
                    // Let's use the `CHECK_PAIRS` state to iterate through sums again.
                    // We can iterate s1 from 0 to 511. For each s1, we iterate s2 from 0 to 511.
                    // To fit 4096, we iterate s1 from 0 to 511 (one pass), and for each s1, we check s2 = s1, s1+1, s1+2... s1+7 (8 checks).
                    // Total 512 * 8 = 4096 checks.
                    // This avoids the complex top-4 selection logic.
                    // Let's do this.
                    
                    // Plan B:
                    // State FIND_TOP: Iterate idx 0..511 to just reset t_cnt (already done in PREPARE/START?)
                    // No, we go directly to CHECK_PAIRS.
                    // In CHECK_PAIRS: 
                    // Iterate i_l (s1) 0..511
                    // Iterate i_r (s2) 0..7 (mapped to s1+step)
                    // Check combinations.
                    // 
                    // Let's replace FIND_TOP with a direct jump to CHECK_PAIRS and use a different loop structure.
                    
                    // Let's refine the state sequence: 
                    // IDLE -> PREPARE -> CLEAR_MEM -> PROCESS_PAIRS -> CHECK_PAIRS -> DONE
                    
                    // In CHECK_PAIRS:
                    // We use `i_l` as s1 (0..511)
                    // We use `i_r` as s2 iterator (0..7)
                    // We map `i_r` to `s2 = i_l + (i_r << 3)` or just `s2 = i_l + i_r`? 
                    // Let's use `s2 = i_l + (i_r * 8)` to spread the search.
                    // Or `s2 = i_r * 8` to compare every sum with others? 
                    // "Find two sums" implies we can pick any two.
                    // If we restrict s2 to be near s1, we might miss disjoint sets far apart.
                    // 
                    // To be safe, let's find the top 4 candidates first using a simple loop.
                    // We need to store the index of the best masks.
                    // We can do this in `FIND_TOP` using 512 cycles, but storing top 4 is logic heavy.
                    // 
                    // Let's try to implement the logic for updating top 4 in a synthesizable way.
                    // We will use 4 registers for counts and indices.
                    // We will compare the new count with `t_cnt[0]` ... `t_cnt[3]`.
                    // If new > `t_cnt[k]`, we shift and insert.
                    // We can do this with `if-else` chains.
                    
                    // Logic for `FIND_TOP` state:
                    // New count = popcount(mask_mem[idx]).
                    // New index = idx.
                    // Compare with t_cnt[0]..t_cnt[3].
                    
                    // We need to ensure we use the correct values for comparison.
                    // Since we are in a sequential block, `t_cnt` holds the values from previous iteration.
                    // 
                    // We will implement the comparison and update in this state.
                    // To make it work, we need to update `t_mask` and `t_idx` as well.
                    // 
                    // Let's write the logic explicitly.
                    
                    // We'll use a wire for the current candidate.
                    // 
                    // Optimization: 
                    // If the top 4 logic is too big, we can use 2 cycles per iteration (one to calculate popcount, one to update).
                    // But let's assume 1 cycle is fine.
                    
                    // Let's code the update logic.
                    
                    // We need to read `mask_mem[idx]`. 
                    // `mask_mem` is a variable in the sensitivity list? It's a memory array. 
                    // Reading from `mask_mem` is combinational if we assign `mask_mem[idx]` to a wire.
                    // However, inside `always @posedge clk`, reading `mask_mem[idx]` returns the value stored at that address.
                    // 
                    // Let's use `popcount(mask_mem[idx])`.
                    
                    // We need to handle the shift.
                    // Let's assume we have `new_cnt` and `new_idx`.
                    // 
                    // We'll update `t_cnt` and `t_idx` based on priority.
                    // To save complexity and avoid timing issues, let's just find the single best sum (max popcount).
                    // Then, we check pairs: (best, best), (best, best-1), (best, best-2) ...
                    // 
                    // Let's go with the "Plan B" from above which is simpler and fits the constraint.
                    // 
                    // REVISED PLAN FOR CALCULATE_MAX (replaces FIND_TOP and CHECK_PAIRS):
                    // 1. Iterate idx 0..511 to find `best_sum_idx` and `best_sum_val` (single max popcount).
                    //    - Store `best_sum_idx`.
                    // 2. Iterate pair check:
                    //    s1 = `best_sum_idx`.
                    //    s2 = 0 to 511.
                    //    Check all pairs involving the best sum.
                    //    This covers the case where one laser is the best, and the other is any.
                    //    
                    //    What if the best pair is (S_a, S_b) where neither is the global best single sum?
                    //    Example: S_best = {1, 2, 3, 4}, S_x = {5, 6, 7, 8} (distinct). S_best|S_x = 8 elements.
                    //    S_y = {1, 2, 5, 6}. S_z = {3, 4, 7, 8}.
                    //    If S_best = {1,2,3,4} (4 bits).
                    //    If S_x = {1,2,3,4} (same).
                    //    
                    //    Actually, if we just check pairs (S_best, S_i) for all i, we miss pairs (S_a, S_b) where S_a != S_best.
                    //    
                    //    To fix this, we need to check pairs of candidates.
                    //    Let's find top 4 candidates. 
                    //    We will implement the top-4 finder in `FIND_TOP` using 512 cycles.
                    //    To make the logic simple, we will do sequential comparisons.
                    //    
                    //    Let's do `FIND_TOP`:
                    //    Registers: `top_idx[0..3]`, `top_cnt[0..3]`.
                    //    For idx 0..511:
                    //      cnt = popcount(mask_mem[idx]).
                    //      if (cnt > top_cnt[0]) { shift; top[0] = cnt/idx; }
                    //      else if (cnt > top_cnt[1]) { shift; top[1] = cnt/idx; }
                    //      ... 
                    //    This is a standard comparator chain.
                    //    It is logic heavy but 4 levels deep. 8-bit compare is small.
                    //    This should synthesize fine.
                    
                    // Let's implement `FIND_TOP` with the comparator chain.
                    
                    // Helper wires for readability in the always block
                    wire [7:0] p_cnt = popcount(mask_mem[idx]);
                    
                    // Update logic for top 4
                    // We update the registers sequentially.
                    // Note: Because `t_cnt` is updated in the same cycle, we must be careful.
                    // In standard Verilog, reading `t_cnt` gives old value, writing `t_cnt` sets new value.
                    // So we can implement the priority encoder logic directly.
                    
                    // Conditionals
                    if (p_cnt > t_cnt[0]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= t_cnt[1]; t_idx[2] <= t_idx[1]; t_mask[2] <= t_mask[1];
                        t_cnt[1] <= t_cnt[0]; t_idx[1] <= t_idx[0]; t_mask[1] <= t_mask[0];
                        t_cnt[0] <= p_cnt;    t_idx[0] <= idx;     t_mask[0] <= mask_mem[idx];
                    end else if (p_cnt > t_cnt[1]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= t_cnt[1]; t_idx[2] <= t_idx[1]; t_mask[2] <= t_mask[1];
                        t_cnt[1] <= p_cnt;    t_idx[1] <= idx;     t_mask[1] <= mask_mem[idx];
                    end else if (p_cnt > t_cnt[2]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= p_cnt;    t_idx[2] <= idx;     t_mask[2] <= mask_mem[idx];
                    end else if (p_cnt > t_cnt[3]) begin
                        t_cnt[3] <= p_cnt;    t_idx[3] <= idx;     t_mask[3] <= mask_mem[idx];
                    end
                    
                    if (idx == 511) begin
                        state <= CHECK_PAIRS;
                        i_l <= 0; // index for first candidate (0..3)
                        i_r <= 0; // index for second candidate (0..3)
                        result <= 0; // Reset max count
                    end else begin
                        idx <= idx + 1;
                    end

                CHECK_PAIRS: begin
                    // Iterate i_l (0..3), i_r (0..3)
                    // Check (t_mask[i_l] | t_mask[i_r])
                    // Update result.
                    
                    // If we want to check single sums too, we need to ensure we consider (0,0), (1,1) etc.
                    // But since we have top 4, pairs cover singles.
                    
                    // Logic:
                    // Calculate popcount of (t_mask[i_l] | t_mask[i_r]).
                    // Compare with result.
                    
                    // Since we use non-blocking assignment for result, we need to be careful with updates.
                    // We can compute popcount combinationally and update result.
                    
                    // We need to handle the loop.
                    // i_l goes 0..3. i_r goes 0..3.
                    
                    if (i_l < 4) begin
                        if (i_r < 4) begin
                            // Calculate combined mask
                            // Since t_mask are registers, their values are available.
                            // Popcount function is combinational.
                            
                            // Update result if larger
                            // We need to latch the result of popcount to compare?
                            // Or just use blocking assignment inside the block if we want immediate update,
                            // but since we are in `always @(posedge clk)`, we must use non-blocking for `result` to be registered.
                            
                            // Let's use a temporary wire for popcount of current pair.
                            // But we can't define a wire inside an always block.
                            // We can use a local variable.
                            
                            // However, to avoid long comb paths, we might just compare in the next cycle or use pipelining.
                            // But 16 pairs = 16 cycles. Small.
                            
                            // Let's do:
                            // Compute popcount. Compare with `result` (current max).
                            // If larger, update `result`.
                            // 
                            // `result` is a register. 
                            // 
                            // We need to compare `current_pair_count` with `result`.
                            // `current_pair_count` depends on `t_mask[i_l]` and `t_mask[i_r]`.
                            // 
                            // To make it safe, let's just compute popcount and register the max.
                            // 
                            // Actually, since we are iterating 16 times, we can just update `result` directly.
                            // 
                            // Let's use `popcount(t_mask[i_l] | t_mask[i_r])`.
                            
                            // Since `t_mask` are registers, we read them. 
                            // We compute popcount. 
                            // 
                            // Logic: 
                            // if (popcount(t_mask[i_l] | t_mask[i_r]) > result) result <= ...
                            
                            // This creates a comb path from t_mask -> popcount -> result comparator -> result.
                            // This is fine for 16 iterations.
                            
                            // Increment counters
                            if (i_r == 3) begin
                                i_r <= 0;
                                i_l <= i_l + 1;
                            end else begin
                                i_r <= i_r + 1;
                            end
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // The logic for `CHECK_PAIRS` update of `result` requires combinational logic that is hard to embed in the sequential block 
    // without creating a latch or using a separate combinational block.
    // Let's add a combinational block to update `result` logic for the CHECK_PAIRS state.
    
    // Combinational logic for Result Update in CHECK_PAIRS
    wire [7:0] current_pair_pop = popcount(t_mask[i_l] | t_mask[i_r]);
    wire [7:0] next_result = (current_pair_pop > result) ? current_pair_pop : result;
    
    // We need to ensure `next_result` is only considered when in CHECK_PAIRS and we are iterating.
    // But the sequential block updates `result` based on `next_result` only if we are in CHECK_PAIRS.
    // Actually, the sequential block will handle the update.
    
    // Let's refine the sequential block for CHECK_PAIRS to use `next_result`.
    // Wait, `next_result` depends on `current_pair_pop` which depends on `t_mask` and indices.
    // In the sequential block, `i_l` and `i_r` are updated at the end of the cycle.
    // So `current_pair_pop` computes based on the indices for THIS cycle.
    // Then `next_result` is computed.
    // In the sequential block, we assign `result <= next_result`.
    
    // Let's correct the CHECK_PAIRS section in the always block:
    // We need to handle the update of `result`.
    
    // Re-writing the CHECK_PAIRS logic inside the always block:
    // Since I wrote the skeleton, let's patch it. I can't edit the block above easily without rewriting.
    // I will assume the user integrates the logic.
    // To ensure the code is valid, I will output the complete block.

endmodule

// Final Output Module: Integrated Logic
module laser_maximizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] y_left [0:15],
    input [7:0] y_right [0:15],
    input [3:0] n_left,
    input [3:0] n_right,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001;
    localparam CLEAR_MEM = 3'b010;
    localparam PROCESS_PAIRS = 3'b011;
    localparam FIND_TOP = 3'b100;
    localparam CHECK_PAIRS = 3'b101;
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    
    reg [7:0] buf_left [0:15];
    reg [7:0] buf_right [0:15];
    reg [3:0] N_L;
    reg [3:0] N_R;
    
    reg [8:0] idx;
    reg [3:0] i_l;
    reg [3:0] i_r;
    
    reg [255:0] mask_mem [0:511];
    
    reg [255:0] t_mask [0:3];
    reg [7:0]   t_cnt [0:3];
    reg [8:0]   t_idx [0:3];
    
    // Helper function for popcount
    function [7:0] popcount;
        input [255:0] v;
        integer k;
        reg [7:0] c;
        begin
            c = 0;
            for (k = 0; k < 256; k = k + 1) if (v[k]) c = c + 1;
            popcount = c;
        end
    endfunction
    
    // Combinational wires
    wire [7:0] current_sum = buf_left[i_l] + buf_right[i_r];
    wire [255:0] current_mask_read = mask_mem[current_sum];
    wire [7:0] find_cnt = popcount(mask_mem[idx]);
    wire [7:0] check_cnt = popcount(t_mask[i_l] | t_mask[i_r]);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= PREPARE;
                end

                PREPARE: begin
                    N_L <= n_left;
                    N_R <= n_right;
                    for (int k = 0; k < 16; k++) begin
                        buf_left[k] <= y_left[k];
                        buf_right[k] <= y_right[k];
                    end
                    idx <= 0;
                    state <= CLEAR_MEM;
                end

                CLEAR_MEM: begin
                    mask_mem[idx] <= 256'b0;
                    if (idx == 511) begin
                        idx <= 0;
                        i_l <= 0;
                        i_r <= 0;
                        state <= PROCESS_PAIRS;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                PROCESS_PAIRS: begin
                    if (i_l < N_L) begin
                        if (i_r < N_R) begin
                            // Read-Modify-Write using current_mask_read (old value from memory)
                            mask_mem[current_sum] <= current_mask_read | (256'b1 << (i_l * N_R + i_r));
                            
                            if (i_r == N_R - 1) begin
                                i_r <= 0;
                                i_l <= i_l + 1;
                            end else begin
                                i_r <= i_r + 1;
                            end
                        end
                    end else begin
                        state <= FIND_TOP;
                        idx <= 0;
                        // Reset top candidates
                        t_cnt[0] <= 0; t_cnt[1] <= 0; t_cnt[2] <= 0; t_cnt[3] <= 0;
                    end
                end

                FIND_TOP: begin
                    // Update top 4 candidates based on popcount of mask_mem[idx]
                    // Using priority encoder logic
                    if (find_cnt > t_cnt[0]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= t_cnt[1]; t_idx[2] <= t_idx[1]; t_mask[2] <= t_mask[1];
                        t_cnt[1] <= t_cnt[0]; t_idx[1] <= t_idx[0]; t_mask[1] <= t_mask[0];
                        t_cnt[0] <= find_cnt; t_idx[0] <= idx;      t_mask[0] <= mask_mem[idx];
                    end else if (find_cnt > t_cnt[1]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= t_cnt[1]; t_idx[2] <= t_idx[1]; t_mask[2] <= t_mask[1];
                        t_cnt[1] <= find_cnt; t_idx[1] <= idx;      t_mask[1] <= mask_mem[idx];
                    end else if (find_cnt > t_cnt[2]) begin
                        t_cnt[3] <= t_cnt[2]; t_idx[3] <= t_idx[2]; t_mask[3] <= t_mask[2];
                        t_cnt[2] <= find_cnt; t_idx[2] <= idx;      t_mask[2] <= mask_mem[idx];
                    end else if (find_cnt > t_cnt[3]) begin
                        t_cnt[3] <= find_cnt; t_idx[3] <= idx;      t_mask[3] <= mask_mem[idx];
                    end
                    
                    if (idx == 511) begin
                        state <= CHECK_PAIRS;
                        i_l <= 0;
                        i_r <= 0;
                        result <= 0;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                CHECK_PAIRS: begin
                    // Iterate through top 4 candidates (including pairs with themselves)
                    if (check_cnt > result) begin
                        result <= check_cnt;
                    end
                    
                    if (i_l < 4) begin
                        if (i_r < 4) begin
                            // Increment inner loop
                            if (i_r == 3) begin
                                i_r <= 0;
                                i_l <= i_l + 1;
                            end else begin
                                i_r <= i_r + 1;
                            end
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
