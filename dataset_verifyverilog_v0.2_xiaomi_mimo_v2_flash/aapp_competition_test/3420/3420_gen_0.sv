module book_circle (
    input clk,
    input rst_n,
    input start,
    input [3:0] boy_count,
    input [3:0] girl_count,
    input [7:0][7:0] adj_matrix,
    output reg [3:0] result,
    output reg done
);

    // State Encodings
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam PROCESS_BOY = 4'd2;
    localparam PROCESS_MASK = 4'd3;
    localparam CHECK_GIRL = 4'd4;
    localparam UPDATE = 4'd5;
    localparam NEXT_MASK = 4'd6;
    localparam COPY_DP = 4'd7;
    localparam NEXT_BOY = 4'd8;
    localparam DONE = 4'd9;

    // Registers for state and datapath control
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Index registers
    reg [3:0] boy_idx;       // Current boy being processed
    reg [7:0] mask_idx;      // Current mask being processed
    reg [2:0] girl_idx;      // Current girl being checked in mask
    reg [3:0] temp_best;     // Temporary max value holder
    
    // DP Memory: 2 banks for current and next states
    // 256 entries x 4 bits
    reg [3:0] dp_curr [0:255];
    reg [3:0] dp_next [0:255];
    
    // Write enable signals for DP memory
    reg dp_curr_wr_en;
    reg dp_next_wr_en;
    
    // Combinational helper signals
    wire [7:0] mask_without_g;
    wire [7:0] current_bit;
    wire edge_exists;
    wire [3:0] dp_value_without_g;
    wire [3:0] candidate_value;
    wire [3:0] dp_curr_value;
    
    // Helper logic
    assign current_bit = 1 << girl_idx;
    assign mask_without_g = mask_idx & ~current_bit;
    assign edge_exists = (girl_idx < girl_count) ? adj_matrix[boy_idx][girl_idx] : 1'b0;
    assign dp_value_without_g = dp_curr[mask_without_g];
    assign candidate_value = dp_value_without_g + 1'b1;
    assign dp_curr_value = dp_curr[mask_idx];

    // State Transition Logic
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
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = PROCESS_BOY;
            end
            PROCESS_BOY: begin
                if (boy_idx < boy_count) next_state = PROCESS_MASK;
                else next_state = DONE;
            end
            PROCESS_MASK: begin
                if (mask_idx < (1 << girl_count)) begin
                    next_state = CHECK_GIRL;
                end else begin
                    next_state = COPY_DP;
                end
            end
            CHECK_GIRL: begin\`n                // If we have checked all relevant girls, go update
                // Logic: Iterate girl_idx from 0 to girl_count-1
                if (girl_idx < girl_count) begin
                    // If girl is in mask and edge exists, we will process it in CHECK_GIRL state body logic
                    // But strictly, we need to loop here. 
                    // We can use a combinational block to skip bits or just increment state.
                    // Let's stick to simple flow: Check current bit, then go to UPDATE if applicable,
                    // or NEXT_GIRL (but we don't have that state, so let's loop via state logic)
                    // To avoid extra states, we will check if we need to update.
                    next_state = CHECK_GIRL; // Default stay until logic moves us
                    if (edge_exists && (mask_idx & current_bit)) begin
                        // Valid match found in this iteration
                        next_state = UPDATE;
                    end else begin
                        // Move to next girl
                        if (girl_idx == girl_count - 1) next_state = UPDATE; // No valid match found in this boy iteration
                        else next_state = CHECK_GIRL; // Wait, need explicit increment control
                    end
                end else begin
                    // Should not happen in this state if managed correctly
                    next_state = UPDATE;
                end
            end
            UPDATE: begin
                next_state = CHECK_GIRL; // Loop back to check next girl until all girls done
                // Optimization: We need to ensure we exit CHECK_GIRL/UPDATE loop correctly.
                // Let's modify CHECK_GIRL logic to handle iteration internally or add a NEXT_GIRL state.
                // Given the strict state list, let's try a different approach:
                // UPDATE state sets best = max(best, candidate). 
                // Then we check if there are more girls. 
                // If girl_idx < girl_count - 1, go to CHECK_GIRL (to increment girl_idx).
                // If girl_idx == girl_count - 1, go to NEXT_MASK.
            end
            NEXT_MASK: begin
                next_state = PROCESS_MASK;
            end
            COPY_DP: begin
                next_state = NEXT_BOY;
            end
            NEXT_BOY: begin
                next_state = PROCESS_BOY;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Corrected State Logic for CHECK_GIRL/UPDATE/NEXT_GIRL simulation
    // Since the instructions gave a specific list, I must map CHECK_GIRL, UPDATE, and NEXT_GIRL (implied) to handle the loop.
    // Let's redefine the flow inside PROCESS_MASK -> CHECK_GIRL -> UPDATE -> CHECK_GIRL (increment) -> ... -> NEXT_MASK
    
    // Re-defining Next State Logic to strictly match constraints and loop capability
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = PROCESS_BOY;
            PROCESS_BOY: begin
                if (boy_idx < boy_count) next_state = PROCESS_MASK;
                else next_state = DONE;
            end
            PROCESS_MASK: begin
                if (mask_idx < (1 << girl_count)) next_state = CHECK_GIRL;
                else next_state = COPY_DP;
            end
            // CHECK_GIRL state checks if current girl_idx is valid for matching
            CHECK_GIRL: begin
                if (girl_idx < girl_count) begin
                    if ((mask_idx & current_bit) && edge_exists) next_state = UPDATE;
                    else next_state = CHECK_GIRL; // Loop back to self to increment girl_idx (handled in sequential logic)
                end else begin
                    next_state = UPDATE; // Should be done, treat as update no-op or finish
                end
            end
            UPDATE: begin
                // After updating with current girl_idx, move to next girl
                // If girl_idx < girl_count, check next. If we finished loop, move to NEXT_MASK
                if (girl_idx < girl_count) next_state = CHECK_GIRL;
                else next_state = NEXT_MASK;
            end
            NEXT_MASK: next_state = PROCESS_MASK;
            COPY_DP: next_state = NEXT_BOY;
            NEXT_BOY: next_state = PROCESS_BOY;
            DONE: next_state = start ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
            boy_idx <= 4'd0;
            mask_idx <= 8'd0;
            girl_idx <= 3'd0;
            temp_best <= 4'd0;
            // Reset memory (optional but good practice for synthesis)
            // Synthesis tools usually infer BRAM with reset, or we can clear in IDLE
            dp_curr_wr_en <= 1'b0;
            dp_next_wr_en <= 1'b0;
        end else begin
            // Default enables to 0
            dp_curr_wr_en <= 1'b0;
            dp_next_wr_en <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    boy_idx <= 4'd0;
                    mask_idx <= 8'd0;
                    girl_idx <= 3'd0;
                end

                INIT: begin
                    // Reset memory pointers or initialize if needed. 
                    // Since we write sequentially in loops, we can just start loops.
                    // We need to initialize dp_curr[0..255] to 0.
                    // To save states, we can treat the first loop of boy_idx=-1 as init, 
                    // but here we use explicit INIT state.
                    // Let's use a counter for initialization if we need to zero out everything, 
                    // OR rely on the fact that we will overwrite dp_next in the first boy iteration.
                    // However, dp_curr[mask] is used in calc. So dp_curr must be 0 for first boy.
                    // Let's use a temporary counter register for init loop if we want to be safe.
                    // Let's assume we just set a flag or use mask_idx as init counter.
                    // Actually, simpler: in PROCESS_MASK for the first boy, we access dp_curr. dp_curr needs to be 0 initially.
                    // We can start PROCESS_BOY for boy_idx=0, and inside PROCESS_MASK, we treat dp_curr as 0 for all indices initially.
                    // But sequential read of uninitialized regs is bad. 
                    // Let's initialize dp_curr to 0 in a loop inside INIT (using mask_idx). 
                    // Or just rely on synthesis tool to power up as 0 (unsafe). 
                    // Let's use mask_idx to clear dp_curr.
                    if (mask_idx < 256) begin
                        dp_curr[mask_idx] <= 4'd0;
                        mask_idx <= mask_idx + 1'b1;
                    end else begin
                        // Done clearing, proceed to actual start
                        // Wait, we need to transition state based on this. 
                        // Since we are in INIT state, we can't stay here easily without a flag.
                        // Let's just overwrite dp_curr with dp_next in COPY_DP.
                        // For the first boy, dp_curr needs to be 0. 
                        // We can initialize dp_curr in IDLE or use a 'init_done' flag.
                        // Let's assume dp_curr starts as 0 (Xilinx/Altera usually 0).
                        // If we want to be safe, we can add a small init loop in IDLE when start goes high.
                        // Let's stick to the prompt states. 
                    end
                    // Actually, let's handle init in IDLE or simply assume dp_curr is 0 initially (standard FPGA behavior).
                    // To be strictly correct without an init loop state, we can start processing.
                    // However, let's check the loop order. 
                    // If we simply start PROCESS_BOY for boy_idx=0, and in PROCESS_MASK we use dp_curr,
                    // we rely on dp_curr being 0.
                end

                PROCESS_BOY: begin
                    // Reset counters for the boy loop
                    mask_idx <= 8'd0;
                    girl_idx <= 3'd0;
                end

                PROCESS_MASK: begin
                    // Prepare for checking girls for this mask
                    girl_idx <= 3'd0;
                    temp_best <= dp_curr[mask_idx]; // Initialize best with 'no match' case
                end

                CHECK_GIRL: begin
                    // We are iterating girls.
                    // If we are in this state, we check the condition.
                    // If condition is met (match found), we go to UPDATE.
                    // If not, we need to increment girl_idx to check next.
                    // But we can't increment in CHECK_GIRL state if we might transition to UPDATE.
                    // So incrementation logic usually goes in UPDATE or NEXT_GIRL state.
                    // Since we only have CHECK_GIRL and UPDATE, let's handle increment in UPDATE for the case where we don't update?
                    // No, UPDATE is for the 'hit' case. 
                    // Let's refine: 
                    // CHECK_GIRL reads. If hit -> UPDATE. If miss -> increment girl_idx (stay in CHECK_GIRL or go to UPDATE?)
                    // To stay in CHECK_GIRL, we need to increment girl_idx in the combinational block? No.
                    // Let's increment girl_idx in UPDATE state always. 
                    // So CHECK_GIRL decides action based on current girl_idx. 
                    // UPDATE updates temp_best (if hit) and increments girl_idx.
                end

                UPDATE: begin
                    // Increment girl_idx to check next one
                    girl_idx <= girl_idx + 1'b1;
                    
                    // If we found a valid match (handled by transition logic), update temp_best
                    if ((mask_idx[girl_idx] == 1'b1) && (girl_idx < girl_count) && adj_matrix[boy_idx][girl_idx]) begin
                        // Calculate candidate: dp_curr[mask_without_g] + 1
                        // We need to read dp_curr[mask_without_g] synchronously. 
                        // The read happened in previous cycle (CHECK_GIRL).
                        // So we can use the read value dp_value_without_g.
                        if (dp_value_without_g + 1'b1 > temp_best) begin
                            temp_best <= dp_value_without_g + 1'b1;
                        end
                    end
                    
                    // Check if we are done with this mask (all girls checked)
                    // If girl_idx reaches girl_count (after increment), we are done with this mask.
                    // But girl_idx is incremented here, so check if girl_idx == girl_count (next cycle value? No, current).
                    // Wait, if girl_idx was 3, incremented to 4. If girl_count=4, we are done.
                    // But we need to write to dp_next. 
                    // When do we write? When girl_idx == girl_count.
                    // But we transition out of UPDATE based on girl_idx.
                    // Let's write dp_next in UPDATE state if we are finished.
                    // If girl_idx >= girl_count (after increment), we are done with this mask.
                    // But we are in UPDATE state. 
                    // We need to write dp_next[mask_idx] = temp_best.
                    // Should we write here or in NEXT_MASK? 
                    // If we write here, we might write multiple times if we don't check correctly.
                    // Let's move writing to NEXT_MASK state.
                end

                NEXT_MASK: begin
                    // Write the result for the previous mask
                    dp_next[mask_idx] <= temp_best;
                    // Increment mask
                    mask_idx <= mask_idx + 1'b1;
                end

                COPY_DP: begin
                    // Copy dp_next to dp_curr for the next boy iteration
                    // We need a counter or use mask_idx.
                    // We can use mask_idx as a counter for copying.
                    // In PROCESS_MASK, mask_idx goes from 0 to 255.
                    // When PROCESS_MASK finishes (mask_idx overflow), we go COPY_DP.
                    // In COPY_DP, we can iterate mask_idx from 0 to 255 to copy.
                    // Then go NEXT_BOY.
                    // But we just finished PROCESS_MASK where mask_idx is now 256 (or looped)
                    // Let's reset mask_idx to 0 for copy loop.
                    if (mask_idx < 256) begin
                        // Wait, mask_idx is already 256 (1<<8) when we exit PROCESS_MASK.
                        // So we need a separate counter or reuse mask_idx.
                        // Let's use boy_idx to check if it's the first boy? No.
                        // Let's stick to the loop: In COPY_DP, we iterate 0..255.
                        // We can use 'girl_idx' as the copy counter to save bits, or use a temp counter.
                        // Let's use girl_idx {girl_idx, mask_idx[2:0]}? No. 
                        // Let's use a dedicated 'copy_idx' or just use the fact that we have 'girl_idx' free.
                        // Since we need 256 entries, we need 8 bits. girl_idx is only 3 bits. 
                        // We can use mask_idx for copying if we reset it.
                        // In NEXT_BOY we reset mask_idx to 0 for the next boy.
                        // So in COPY_DP, we can set mask_idx to 0 and start copying.
                        // But we need to know when to stop copying.
                        // Let's modify NEXT_MASK to write. 
                        // So COPY_DP doesn't need to write, it needs to overwrite dp_curr.
                        // dp_curr <= dp_next.
                        // Since we can't bulk copy in 1 cycle (no array assignment in always block usually unless blocking),
                        // We need a loop.
                        // Let's treat COPY_DP as a state that runs for 256 cycles.
                        // We need a counter. Let's use mask_idx as the counter.
                        // But we need to preserve the value 0 for the next boy's PROCESS_MASK? 
                        // Yes. So after copy, mask_idx will be 256.
                    end
                end

                NEXT_BOY: begin
                    boy_idx <= boy_idx + 1'b1;
                end

                DONE: begin
                    // Final result is in dp_curr at mask (1<<girl_count)-1
                    result <= dp_curr[(1 << girl_count) - 1'b1];
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- Logic Re-arrangement to fit standard synchronous flow ---
    // The logic above mixes combinational next_state and sequential updates.
    // The CHECK_GIRL -> UPDATE loop is tricky without a NEXT_GIRL state.
    // We can implement it by: 
    // 1. In CHECK_GIRL, we select the next state based on current girl_idx.
    // 2. In UPDATE, we calculate the new temp_best.
    // 3. In UPDATE, we increment girl_idx.
    // 4. In UPDATE, we decide: If girl_idx < girl_count, go to CHECK_GIRL.
    //    If girl_idx >= girl_count, go to NEXT_MASK.

    // Let's refine the sequential block to ensure it synthesizes correctly.
    // I will rewrite the sequential block to be cleaner.

    // We need a way to handle the DP copy. 
    // Let's add a specific counter for the copy loop. 
    // Or use 'girl_idx' as the copy index (since it's 3-bit, we can't do 256 iterations).
    // Let's use 'mask_idx' for the copy loop. 
    // When entering COPY_DP, mask_idx is 256. We reset it to 0.
    // Then we loop. But we need to exit COPY_DP. 
    // If we loop 256 times, mask_idx becomes 256. We need to transition.
    // So: 
    // COPY_DP: if mask_idx < 256, copy dp_next[mask_idx] to dp_curr[mask_idx], increment mask_idx, stay in COPY_DP.
    //          else (mask_idx == 256), go NEXT_BOY.
    // This requires the state machine to stay in COPY_DP for 256 cycles.

    // Let's refine the datapath block with this logic.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
            boy_idx <= 4'd0;
            mask_idx <= 8'd0;
            girl_idx <= 3'd0;
            temp_best <= 4'd0;
            // Initialize memory entries to 0 (assuming synthesis handles arrays)
            // We will initialize dp_curr lazily by writing 0 to it in the first pass if needed,
            // but strictly we should clear it.
            // Let's assume the state machine handles it.
        end else begin
            done <= 1'b0;
            
            case (next_state) // Use next_state for combinational updates to reduce one cycle latency
                INIT: begin
                    // We can initialize dp_curr[0] = 0, etc. 
                    // But let's rely on the fact that for boy_idx=0, we set temp_best = dp_curr[mask].
                    // If dp_curr is undefined, it's bad. 
                    // Let's set a flag or just overwrite dp_curr with 0 in the first iteration.
                    // Actually, simplest is: 
                    // If state==INIT, set boy_idx=0, mask_idx=0. 
                    // In PROCESS_MASK, if boy_idx==0, temp_best = 0 (since dp_curr is init 0).
                    // To be safe, let's explicitly clear dp_curr in IDLE or INIT using a counter.
                    // Since we have many cycles, let's use mask_idx to clear dp_curr in INIT state.
                end
                
                PROCESS_BOY: begin
                    mask_idx <= 8'd0;
                    girl_idx <= 3'd0;
                    // If boy_idx == 0, we need dp_curr to be all 0s.
                    // We can perform the clearing in the first PROCESS_BOY or INIT.
                    // Let's do: if boy_idx == 0, we start a clearing loop. 
                    // But we need to enter PROCESS_MASK. 
                    // Let's skip clearing and assume X is 0 (risky) or use a reset init sequence.
                end
                
                PROCESS_MASK: begin
                    girl_idx <= 3'd0;
                    // Initialize best with 'no match' value.
                    if (boy_idx == 0) temp_best <= 4'd0; 
                    else temp_best <= dp_curr[mask_idx];
                end
                
                CHECK_GIRL: begin
                    // If we are looping, we might need to increment girl_idx here if it was a miss.
                    // But we handle that in UPDATE (which follows CHECK_GIRL if miss).
                    // Actually, let's restructure the CHECK_GIRL/UPDATE loop to be robust.
                    // We will perform check in CHECK_GIRL. 
                    // If match found, go to UPDATE (update best). 
                    // If match not found, go to UPDATE (no update). 
                    // Wait, that's inefficient. 
                    // Let's stick to: 
                    // CHECK_GIRL checks. 
                    // If hit -> UPDATE (updates best). 
                    // If miss -> increment girl_idx (in UPDATE) -> CHECK_GIRL. 
                    // So UPDATE always increments girl_idx.
                    // UPDATE checks if girl_idx >= girl_count. 
                    // If yes, write dp_next and go NEXT_MASK. 
                    // If no, go CHECK_GIRL.
                end
                
                UPDATE: begin
                    // 1. Update Best if hit
                    // 'Hit' condition: mask has bit set, edge exists.
                    // Since we are in UPDATE, the previous state (CHECK_GIRL) transitioned here because it found a match.
                    // Or did it? We need to ensure CHECK_GIRL only transitions to UPDATE on match.
                    // Yes, that simplifies logic.
                    // So if we are in UPDATE, we have a match.
                    // Read dp_curr[mask_without_g] was done in previous cycle? No, synchronous read.
                    // We need to latch dp_curr[mask_without_g] or perform read in UPDATE.
                    // Let's assume dp_curr is synchronous. 
                    // In UPDATE state, we need the value of dp_curr[mask_without_g].
                    // But mask_without_g is derived from current mask_idx and current girl_idx.
                    // However, girl_idx might have already incremented if we are not careful.
                    // Let's assume we keep girl_idx stable during the update.
                    // So in UPDATE state (where we found a match), we calculate:
                    // candidate = dp_curr[mask_without_g] + 1.
                    // temp_best = max(temp_best, candidate).
                    
                    // Wait, we can't read dp_curr asynchronously in always block for synthesis usually (unless net).
                    // So we need to read dp_curr[mask_without_g] in the cycle before update.
                    // But we only have 1 cycle between CHECK_GIRL and UPDATE.
                    // Okay, let's assume dp_curr is a synchronous read block RAM. 
                    // So the data is available one cycle later. 
                    // This means we need to pipeline the read.
                    // Or, since it's a small memory (256x4), we can use LUTRAM or Distributed RAM which is read asynchronously.
                    // Or we can use Flip-Flops. 
                    // 256x4 = 1024 bits. That's small. We can use FFs for speed.
                    // Let's declare dp_curr and dp_next as reg [3:0] array.
                    // Accessing dp_curr[...] in combinational logic gives current value.
                    // So in UPDATE state, we can access dp_curr[mask_without_g].
                    // BUT, mask_without_g uses girl_idx. 
                    // We need to ensure girl_idx is the one that triggered the match.
                    // We can store the 'matching girl' index or keep girl_idx stable.
                    // Let's store the matching girl index temporarily.
                    
                    // Revised approach: 
                    // In CHECK_GIRL: we read dp_curr[mask_without_g].
                    // We can compute candidate value in combinational logic.
                    // If (edge_exists && in_mask) then candidate is valid.
                    // If we stay in CHECK_GIRL (no match), we increment girl_idx.
                    // If we go to UPDATE (match), we update temp_best.
                    
                    // Let's try a simpler iterative method using the 'UPDATE' state to handle both checking and updating.
                    // Wait, the prompt has specific states. Let's try to implement them faithfully.
                    
                    // Let's assume 'dp_curr' is accessible immediately.
                    // In UPDATE state, we have just transitioned from CHECK_GIRL because a match was found.
                    // We need to update temp_best.
                    // We need mask_without_g. 
                    // We need girl_idx to be the one that matched.
                    // We need to know girl_idx in UPDATE. 
                    // Since we transitioned from CHECK_GIRL, girl_idx is valid.
                    
                    // So: 
                    // In UPDATE: 
                    //   if (found_match) temp_best <= max(temp_best, dp_curr[mask_without_g] + 1);
                    //   Then increment girl_idx.
                    //   If girl_idx < girl_count, go CHECK_GIRL.
                    //   Else go NEXT_MASK.
                    //   
                    // Problem: How does UPDATE know 'found_match' if we also go to UPDATE from CHECK_GIRL on miss (to increment)?
                    // We can make CHECK_GIRL go to UPDATE only on hit. 
                    // On miss, CHECK_GIRL increments girl_idx and goes back to CHECK_GIRL.
                    // But we can't increment girl_idx in CHECK_GIRL state (sequential block).
                    // So CHECK_GIRL on miss -> UPDATE (update action: no-op, increment girl_idx) -> CHECK_GIRL.
                    // CHECK_GIRL on hit -> UPDATE (update action: update best, increment girl_idx) -> CHECK_GIRL.
                    // 
                    // This works if we have a signal to distinguish hit/miss in UPDATE.
                    // We can latch the 'hit' signal in CHECK_GIRL.
                    
                    // Let's do this:
                    // In CHECK_GIRL state: 
                    //   Calculate hit = (mask_idx[girl_idx] && adj_matrix[boy_idx][girl_idx]).
                    //   If hit, go UPDATE.
                    //   If not hit, go UPDATE (miss path).
                    //   
                    // In UPDATE state: 
                    //   Use a registered signal 'is_hit' (registered from CHECK_GIRL).
                    //   If is_hit: temp_best <= max(temp_best, dp_curr[mask_without_g] + 1).
                    //   Increment girl_idx.
                    //   If girl_idx < girl_count, go CHECK_GIRL.
                    //   Else go NEXT_MASK.
                    //   (Note: girl_idx incremented, so check if girl_idx (new) < girl_count).
                    
                    // Wait, if girl_idx is 7 and girl_count is 8. 
                    // Check girl_idx 7 (last). 
                    // Hit? Update. Increment to 8. 
                    // 8 < 8? No. Go NEXT_MASK.
                    // Correct.
                    
                    // So we need a register to store 'is_hit'.
                    reg is_hit_reg;
                    
                    // Inside CHECK_GIRL:
                    is_hit_reg <= (mask_idx[girl_idx] && (girl_idx < girl_count) && adj_matrix[boy_idx][girl_idx]);
                    
                    // Inside UPDATE:
                    if (is_hit_reg) begin
                        // We need dp_curr[mask_without_g]. 
                        // We need girl_idx to be the OLD index. But we just incremented girl_idx.
                        // So we need to access using (girl_idx - 1).
                        // Or store old girl_idx.
                        // Let's use (girl_idx - 1).
                        // But if girl_idx is 0 (unsigned wrap)? We handle bounds.
                        // Also need to verify dp_curr is array of regs.
                        
                        if (dp_curr[mask_idx & ~(1'b1 << (girl_idx - 1'b1))] + 1'b1 > temp_best) begin
                            temp_best <= dp_curr[mask_idx & ~(1'b1 << (girl_idx - 1'b1))] + 1'b1;
                        end
                    end
                    
                    girl_idx <= girl_idx + 1'b1;
                    
                    // We need to know when to stop. 
                    // If girl_idx (after increment) >= girl_count.
                    // But we are updating girl_idx now. So next state logic will see new value.
                end
                
                NEXT_MASK: begin
                    dp_next[mask_idx] <= temp_best;
                    mask_idx <= mask_idx + 1'b1;
                end
                
                COPY_DP: begin
                    // We need to copy dp_next to dp_curr.
                    // We need a loop counter. Let's use girl_idx for this (reusing).
                    // Wait, girl_idx is 3 bit. 0-7. We need 0-255.
                    // Let's use boy_idx as temp? No.
                    // Let's use mask_idx as the copy index.
                    // But mask_idx was used for the loop.
                    // In NEXT_MASK, we incremented mask_idx. When it hits 256, we enter COPY_DP.
                    // So in COPY_DP, mask_idx is 256. 
                    // We can reset mask_idx to 0 in COPY_DP.
                    // But we need to know when copy is done.
                    // Let's add a flag or just loop.
                    // We can use the fact that boy_idx increments. 
                    // If we use mask_idx as copy index, we reset it to 0 at start of COPY_DP.
                    // Then in COPY_DP, we do: dp_curr[mask_idx] <= dp_next[mask_idx]; mask_idx++.
                    // If mask_idx == 256, go NEXT_BOY.
                    // This takes 256 cycles.
                    
                    if (mask_idx == 8'd0) begin
                        // First cycle of COPY_DP. Reset logic? 
                        // Actually, we enter COPY_DP when mask_idx is 256 (or 0 if we looped).
                        // Let's enter COPY_DP when mask_idx is 256.
                        // Then we reset mask_idx to 0.
                        // But we need to write dp_curr[0]. 
                        // So let's structure it:
                        // NEXT_MASK checks if mask_idx + 1 >= 256. If so, go COPY_DP. 
                        // But wait, NEXT_MASK does mask_idx++. 
                        // So if mask_idx was 255, NEXT_MASK makes it 256.
                        // Then NEXT_MASK checks next state? No, next state is PROCESS_MASK.
                        // We need to change NEXT_MASK logic: 
                        // If mask_idx + 1 == (1 << girl_count), go COPY_DP.
                        // Else go PROCESS_MASK.
                        // So in COPY_DP, mask_idx is currently at (1<<girl_count).
                        // We reset mask_idx to 0.
                        // Then we start copying.
                        // We write dp_curr[0] = dp_next[0].
                        // Increment mask_idx. 
                        // Stay in COPY_DP until mask_idx == (1<<girl_count).
                    end else begin
                        // Looping in COPY_DP
                        dp_curr[mask_idx] <= dp_next[mask_idx];
                        mask_idx <= mask_idx + 1'b1;
                    end
                end
                
                NEXT_BOY: begin
                    boy_idx <= boy_idx + 1'b1;
                end
                
                DONE: begin
                    result <= dp_curr[(1 << girl_count) - 1'b1];
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // --- Detailed Logic Implementation ---
    // To ensure this compiles and runs correctly, we will implement the sequential logic
    // carefully handling the loop structures.
    
    // We need a few extra registers to manage the DP copy loop.
    reg [7:0] copy_idx;
    
    // We also need to handle the CHECK_GIRL -> UPDATE loop.
    // Since we don't have a NEXT_GIRL state, we use UPDATE to increment girl_idx.
    // We need to remember if we had a match in the current girl index.
    reg matched; 
    
    // Re-write the sequential block cleanly.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            boy_idx <= 4'd0;
            mask_idx <= 8'd0;
            girl_idx <= 3'd0;
            temp_best <= 4'd0;
            matched <= 1'b0;
            copy_idx <= 8'd0;
            // We don't reset memory arrays here, we ensure they are initialized via FSM or assume 0.
            // To be safe, we can clear memory in IDLE if needed, but FPGA BRAM usually init to 0 via bitstream.
            // Let's clear dp_curr/dp_next in IDLE state if we are not resetting.
            // Actually, let's rely on the algorithm: 
            // The first boy (i=0) uses dp_curr. If we don't clear, it's X. 
            // So we must clear dp_curr before using it. 
            // We can do this in IDLE state when start is asserted? No, IDLE waits for start.
            // We can do it in INIT state.
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= INIT;
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Initialize dp_curr to 0. 
                    // We can use mask_idx as counter here.
                    // We need a way to distinguish init from processing.
                    // Let's add a flag or just use the fact that boy_idx=0 means we need init.
                    // Actually, let's use INIT to set a counter and clear.
                    // But we don't have a dedicated counter for this. 
                    // Let's just treat boy_idx=0 as the init phase implicitly.
                    // If boy_idx=0 and we enter PROCESS_BOY, we know we need to treat dp_curr as 0.
                    // So we can skip explicit zeroing if we initialize temp_best to 0 for boy 0.
                    // And ensure we don't read uninitialized dp_curr for boy 0.
                    // For boy 0, we read dp_curr[mask]. But we set temp_best = 0.
                    // We read dp_curr only to get dp_curr[mask_without_g]. 
                    // For boy 0, dp_curr should be 0. 
                    // If we don't clear, it's X. X+1 = X. max(0, X) = X (usually).
                    // So we MUST clear dp_curr.
                    // Let's use a separate initialization loop in INIT state.
                    // We will use mask_idx as the counter.
                    state <= INIT;
                    if (mask_idx < 256) begin
                        dp_curr[mask_idx] <= 4'd0;
                        dp_next[mask_idx] <= 4'd0; // Also clear dp_next just in case
                        mask_idx <= mask_idx + 1'b1;
                    end else begin
                        // Init done
                        mask_idx <= 8'd0;
                        boy_idx <= 4'd0;
                        state <= PROCESS_BOY;
                    end
                end
                
                PROCESS_BOY: begin
                    if (boy_idx < boy_count) begin
                        state <= PROCESS_MASK;
                        mask_idx <= 8'd0;
                    end else begin
                        state <= DONE;
                    end
                end
                
                PROCESS_MASK: begin
                    if (mask_idx < (1 << girl_count)) begin
                        state <= CHECK_GIRL;
                        girl_idx <= 3'd0;
                        temp_best <= dp_curr[mask_idx]; // Don't match boy i
                        matched <= 1'b0;
                    end else begin
                        state <= COPY_DP;
                        copy_idx <= 8'd0;
                    end
                end
                
                CHECK_GIRL: begin
                    // We iterate girl_idx from 0 to girl_count-1
                    // We need to loop. Since we only have CHECK_GIRL and UPDATE, we use UPDATE to increment.
                    // But we must detect if we are done.
                    // If girl_idx >= girl_count, we are done with this mask.
                    if (girl_idx < girl_count) begin
                        // Check if girl is in mask AND edge exists
                        if (mask_idx[girl_idx] && adj_matrix[boy_idx][girl_idx]) begin
                            matched <= 1'b1;
                            state <= UPDATE;
                        end else begin
                            matched <= 1'b0;
                            state <= UPDATE; // Still go to UPDATE to increment girl_idx
                        end
                    end else begin
                        // Done with this mask
                        state <= NEXT_MASK;
                    end
                end
                
                UPDATE: begin
                    // If matched was set in CHECK_GIRL, update temp_best
                    if (matched) begin
                        // We need to read dp_curr[mask_without_g]. 
                        // We need girl_idx from the previous cycle (before increment).
                        // But girl_idx hasn't changed yet. 
                        // We need to compute mask_without_g for the CURRENT girl_idx.
                        // Wait, in CHECK_GIRL we set matched. 
                        // In UPDATE, we want to use the girl_idx that caused the match.
                        // So we can use girl_idx directly.
                        if (dp_curr[mask_idx & ~(1'b1 << girl_idx)] + 1'b1 > temp_best) begin
                            temp_best <= dp_curr[mask_idx & ~(1'b1 << girl_idx)] + 1'b1;
                        end
                    end
                    
                    // Increment girl_idx to check next one
                    girl_idx <= girl_idx + 1'b1;
                    
                    // Loop back to CHECK_GIRL to continue iteration
                    state <= CHECK_GIRL;
                end
                
                NEXT_MASK: begin
                    dp_next[mask_idx] <= temp_best;
                    mask_idx <= mask_idx + 1'b1;
                    state <= PROCESS_MASK;
                end
                
                COPY_DP: begin
                    // We need to copy dp_next to dp_curr.
                    // We have 256 entries. We use copy_idx.
                    // If copy_idx < 256:
                    if (copy_idx < (1 << girl_count)) begin
                        dp_curr[copy_idx] <= dp_next[copy_idx];
                        copy_idx <= copy_idx + 1'b1;
                        state <= COPY_DP; // Stay here
                    end else begin
                        // Done copying
                        state <= NEXT_BOY;
                    end
                end
                
                NEXT_BOY: begin
                    boy_idx <= boy_idx + 1'b1;
                    state <= PROCESS_BOY;
                end
                
                DONE: begin
                    result <= dp_curr[(1 << girl_count) - 1'b1];
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
