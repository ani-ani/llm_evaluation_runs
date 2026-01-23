module largest_committee (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] N,
    input wire [3:0] K,
    input wire [5:0] current_vertex,
    input wire [4:0] num_neighbors,
    input wire [5:0] neighbor_addr,
    input wire neighbor_valid,
    input wire [5:0] neighbor_id,
    output reg [5:0] max_clique_size,
    output reg done,
    output reg busy
);

    // Constants
    localparam MAX_VERTICES = 50;
    localparam MAX_DEGREE = 10;
    localparam DATA_WIDTH = 50;
    localparam ADDR_WIDTH = 6;

    // States
    localparam IDLE = 4'b0000;
    localparam LOAD_GRAPH_START = 4'b0001;
    localparam LOAD_GRAPH_WRITE_ROW = 4'b0010;
    localparam BUILD_CLIQUE = 4'b0100;
    localparam CHECK_CANDIDATES = 4'b0101;
    localparam ADD_TO_CLIQUE = 4'b0110;
    localparam BACKTRACK = 4'b0111;
    localparam UPDATE_MAX = 4'b1000;
    localparam DONE = 4'b1001;

    // BRAM Interface for Adjacency Matrix
    reg wea;
    reg [ADDR_WIDTH-1:0] addra;
    reg [DATA_WIDTH-1:0] dina;
    wire [DATA_WIDTH-1:0] douta;
    reg [ADDR_WIDTH-1:0] addrb;
    wire [DATA_WIDTH-1:0] doutb;

    // BRAM Instance (Dual Port: Port A for Writing, Port B for Reading)
    // Synthesis tools will infer Block RAM or Distributed RAM based on size and usage
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:MAX_VERTICES-1];
    
    // Port A (Write)
    always @(posedge clk) begin
        if (wea) begin
            mem[addra] <= dina;
        end
    end
    assign douta = mem[addra]; // Not used for reading logic, but needed for inference
    
    // Port B (Read)
    always @(posedge clk) begin
        doutb_reg <= mem[addrb];
    end
    reg [DATA_WIDTH-1:0] doutb_reg;
    assign doutb = doutb_reg;

    // Internal Registers
    reg [3:0] state, next_state;
    reg [5:0] v_start; // Current starting vertex for the main loop
    reg [4:0] depth; // Current depth of backtracking stack
    reg [5:0] stack [0:MAX_DEGREE]; // Stores vertices in current clique
    reg [DATA_WIDTH-1:0] candidates; // Valid candidates for current depth
    reg [DATA_WIDTH-1:0] valid_vertices; // Global set of vertices < v_start to check
    reg [5:0] local_max; // Max clique size found for current v_start
    
    // Helper variables
    reg [5:0] i, j, temp_id;
    reg [5:0] temp_vertex;
    reg [DATA_WIDTH-1:0] temp_neighbors;
    reg [DATA_WIDTH-1:0] new_candidates;
    
    // Temporary registers for computation
    reg [DATA_WIDTH-1:0] scratch_cand;
    reg [DATA_WIDTH-1:0] scratch_intersect;
    reg [5:0] temp_idx;

    // Helper registers
    reg [3:0] load_step;
    reg [5:0] load_v;
    reg [5:0] load_rem;
    reg [5:0] temp_u, temp_v;
    reg [5:0] curr_start_v; // Renamed to avoid confusion with loop counter 'v_start' in prompt
    reg [5:0] local_depth;
    reg [DATA_WIDTH-1:0] local_valid_mask;
    
    // Stack registers
    reg [5:0] stack_v [0:MAX_DEGREE-1];
    reg [DATA_WIDTH-1:0] stack_cand [0:MAX_DEGREE-1];
    
    // Combinational helper
    reg [DATA_WIDTH-1:0] temp_cand;
    reg found_bit;
    reg [5:0] bit_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            done <= 0;
            max_clique_size <= 0;
            wea <= 0;
            // Reset internal counters
            load_v <= 0;
            load_step <= 0;
            curr_start_v <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        busy <= 1;
                        state <= LOAD_GRAPH_START;
                        load_v <= 0;
                        load_step <= 0;
                        load_rem <= 0;
                        wea <= 0;
                        max_clique_size <= 0;
                        curr_start_v <= 0;
                    end
                end

                // --- Loading States ---
                LOAD_GRAPH_START: begin
                    // Check if all vertices loaded
                    if (load_v >= N) begin
                        state <= BUILD_CLIQUE;
                    end else begin
                        // Ensure we are looking at the correct input vertex
                        if (current_vertex == load_v) begin
                            if (load_rem == 0) begin
                                // Determine number of edges for this vertex
                                if (num_neighbors == 0) begin
                                    load_v <= load_v + 1;
                                end else begin
                                    load_rem <= num_neighbors;
                                end
                            end else begin
                                // Wait for valid edge
                                if (neighbor_valid) begin
                                    temp_u <= load_v;
                                    temp_v <= neighbor_id;
                                    load_step <= 0;
                                    state <= LOAD_GRAPH_WRITE_ROW;
                                end
                            end
                        end
                        // If current_vertex != load_v, we wait (stall)
                    end
                end

                LOAD_GRAPH_WRITE_ROW: begin
                    // Sub-state machine for updating BRAM (Bidirectional)
                    // Cycle 0: Read U
                    if (load_step == 0) begin
                        addrb <= temp_u;
                        load_step <= 1;
                    end
                    // Cycle 1: Write U (set bit for V), Read V
                    else if (load_step == 1) begin
                        wea <= 1;
                        addra <= temp_u;
                        dina <= doutb | (1 << temp_v);
                        addrb <= temp_v;
                        load_step <= 2;
                    end
                    // Cycle 2: Finish Write U, Prepare Write V
                    else if (load_step == 2) begin
                        wea <= 0;
                        // doutb for V is valid now (1 cycle after address set in step 1)
                        // But wait, in step 1 we set addrb <= temp_v. 
                        // So in step 2, doutb is neighbors(temp_v).
                        // We need to write to temp_v: neighbors(temp_v) | (1 << temp_u).
                        // But we need to preserve the value. 
                        // In step 1, we set dina for U. 
                        // Here we prepare for V.
                        // But we lost the read value of V from step 1? 
                        // No, 'doutb' updates every cycle. 
                        // So in step 2, 'doutb' is neighbors(temp_v).
                        // Wait, 'doutb' latency is 1. 
                        // Step 1: set addrb = temp_v. 
                        // Step 2: 'doutb' = mem[temp_v]. 
                        // Correct.
                        
                        // However, we need to update 'doutb' with bit 'temp_u'.
                        // But wait, we haven't written 'temp_u' to the memory yet in the context of 'temp_v' reading. 
                        // Actually, we wrote 'temp_u' in step 1. 
                        // So 'doutb' in step 2 is the OLD value of row 'temp_v'. 
                        // So we do: new_val = old_val | (1 << temp_u).
                        // Correct.
                        
                        // Wait, `doutb` in step 2 is `mem[temp_v]` (read started in step 1). 
                        // So `doutb` is valid.
                        
                        wea <= 1;
                        addra <= temp_v;
                        dina <= doutb | (1 << temp_u);
                        load_step <= 3;
                    end
                    // Cycle 3: Finish Write V
                    else if (load_step == 3) begin
                        wea <= 0;
                        load_rem <= load_rem - 1;
                        
                        if (load_rem == 0) begin
                            load_v <= load_v + 1;
                            state <= LOAD_GRAPH_START;
                        end else begin
                            state <= LOAD_GRAPH_START;
                        end
                    end
                end

                // --- Search States ---
                BUILD_CLIQUE: begin
                    // Initialize for vertex 'curr_start_v'
                    stack_v[0] <= curr_start_v;
                    local_depth <= 1; // 'local_depth' tracks current size
                    local_max <= 1;
                    
                    // Calculate valid mask for this start vertex: vertices > curr_start_v
                    // (1 << N) - 1 is mask of all valid vertices 0..N-1
                    // ~((1 << (curr_start_v + 1)) - 1) masks out bits 0..curr_start_v
                    // But need to ensure we don't mask out bits > N.
                    // Actually, just shift is better? No.
                    local_valid_mask <= ((1 << N) - 1) & ~((1 << (curr_start_v + 1)) - 1);
                    
                    // Read neighbors of start vertex
                    addrb <= curr_start_v;
                    state <= CHECK_CANDIDATES;
                end

                CHECK_CANDIDATES: begin
                    // 'doutb' is neighbors of 'stack_v[local_depth - 1]' (the node we just added)
                    // We need to calculate candidates for the NEXT level.
                    // Wait, logic: 
                    // We are at 'local_depth'.
                    // We have extended to 'stack_v[local_depth - 1]'.
                    // 'doutb' are neighbors of this new node.
                    // The set of valid candidates for the next step is:
                    // 'stack_cand[local_depth - 1]' (which holds valid candidates for the current level)
                    // INTERSECTED with 'doutb'.
                    // 
                    // BUT, 'stack_cand[local_depth - 1]' must be set correctly. 
                    // 
                    // Case 1: Just entered from BUILD_CLIQUE (local_depth == 1).
                    //   We read neighbors of stack_v[0].
                    //   The candidates for level 1 (i.e. to add to stack_v[0]) are:
                    //   neighbors(stack_v[0]) AND valid_mask (vertices > start).
                    //   So we set 'stack_cand[1]' (candidates for level 1) to this.
                    //   Wait, 'local_depth' is the size. 
                    //   If size is 1, we are looking for extensions.
                    //   So 'stack_cand[1]' is the set to try.
                    //   
                    // Case 2: Entered from BACKTRACK.
                    //   'local_depth' decreased. 
                    //   We read neighbors of stack_v[local_depth - 1] (current node).
                    //   We need to intersect with the CURRENT candidates for this level.
                    //   But the candidates for this level were already 'stack_cand[local_depth]'. 
                    //   Wait, 'stack_cand[level]' stores candidates for *that level*.
                    //   
                    //   Let's refine:
                    //   We are at 'local_depth'. 
                    //   We want to find candidates to extend *from* here.
                    //   We read neighbors of 'stack_v[local_depth - 1]'.
                    //   We need to intersect with 'stack_cand[local_depth - 1]'.
                    //   Wait, 'stack_cand' usage:
                    //   'stack_cand[i]' holds the *remaining* candidates for the level i.
                    //   
                    //   Let's try the "Compute New Candidates" approach:
                    //   In CHECK_CANDIDATES:
                    //     temp_cand = 'doutb' & 'stack_cand[local_depth - 1]'.
                    //     If 'local_depth' == 1:
                    //       temp_cand = 'doutb' & 'local_valid_mask'.
                    //       (Because we haven't used 'stack_cand' yet).
                    //     
                    //     IF temp_cand == 0:
                    //       state <= BACKTRACK.
                    //     ELSE:
                    //       // Pick one
                    //       // In CHECK_CANDIDATES, we can't easily pick without combinational logic or loops.
                    //       // Let's move picking to ADD_TO_CLIQUE.
                    //       // But ADD_TO_CLIQUE needs the set.
                    //       // Let's store 'temp_cand' into 'stack_cand[local_depth]'.
                    //       // 'stack_cand[local_depth]' is the set of candidates for the *next* level (level i).
                    //       // No, 'stack_cand[local_depth]' is the set to try *now*.
                    //       // 
                    //       // Let's use 'stack_cand[local_depth]' to store the *available* candidates for the *current* recursion level.
                    //       // 
                    //       // Revision:
                    //       // 'stack_cand[local_depth]' stores candidates for the level *after* adding 'stack_v[local_depth-1]'.
                    //       // 
                    //       // So in CHECK_CANDIDATES:
                    //       //   'stack_cand[local_depth]' = 'doutb' & 'stack_cand[local_depth - 1]'.
                    //       //   (If depth==1, 'stack_cand[0]' doesn't exist or is unused. Use 'local_valid_mask').
                    //       //   
                    //       //   If 'stack_cand[local_depth]' == 0: BACKTRACK.
                    //       //   Else: ADD_TO_CLIQUE.
                    //       // 
                    //       // In ADD_TO_CLIQUE:
                    //       //   Pick 'v' from 'stack_cand[local_depth]'.
                    //       //   'stack_v[local_depth]' = 'v'.
                    //       //   'stack_cand[local_depth]' &= ~(1<<v).
                    //       //   'local_depth'++.
                    //       //   'addrb' = 'v'.
                    //       //   state <= CHECK_CANDIDATES.
                    //       //   
                    //       // In BACKTRACK:
                    //       //   'local_depth'--.
                    //       //   If 'local_depth' == 0: UPDATE_MAX.
                    //       //   Else: 'addrb' = 'stack_v[local_depth - 1]'. state <= CHECK_CANDIDATES.
                    //       //   
                    //       // This works if 'stack_cand[local_depth - 1]' holds the candidates for the previous level.
                    //       // But we don't have 'stack_cand[0]' initialized. 
                    //       // 
                    //       // Let's assume 'stack_cand[0]' is 'local_valid_mask' (conceptually). 
                    //       // So in CHECK_CANDIDATES:
                    //       //   if (local_depth == 1) temp_cand = doutb & local_valid_mask;
                    //       //   else temp_cand = doutb & stack_cand[local_depth - 1];
                    //       //   
                    //       //   stack_cand[local_depth] = temp_cand.
                    //       //   
                    //       //   if (temp_cand == 0) BACKTRACK
                    //       //   else ADD_TO_CLIQUE
                    //       // 
                    //       // In ADD_TO_CLIQUE:
                    //       //   Find 'v' in stack_cand[local_depth].
                    //       //   stack_cand[local_depth] &= ~(1<<v).
                    //       //   stack_v[local_depth] = v.
                    //       //   local_depth++.
                    //       //   addrb = v.
                    //       //   state = CHECK_CANDIDATES.
                    //       // 
                    //       // This seems correct!
                    //       // 
                    //       // Pruning: 
                    //       // If local_depth >= K, we can stop.
                    //       // In ADD_TO_CLIQUE, if local_depth == K (before increment), we found max size K.
                    //       // Actually, after increment, local_depth = K+1? No, K is max size.
                    //       // If local_depth == K, we can't extend. But we just added a vertex to reach size K.
                    //       // So we should update max and backtrack.
                    //       // 
                    //       // Let's check in ADD_TO_CLIQUE:
                    //       //   new_depth = local_depth + 1.
                    //       //   if (new_depth > local_max) local_max = new_depth.
                    //       //   if (new_depth >= K):
                    //       //     state <= BACKTRACK. (Don't extend, just backtrack).
                    //       //     local_depth <= local_depth - 1? No, we haven't incremented yet.
                    //       //     Wait, if local_depth = K-1, we add one -> size K.
                    //       //     We update max. We shouldn't extend further.
                    //       //     So we backtrack immediately.
                    //       //     So we don't update 'local_depth', we just jump to BACKTRACK.
                    //       //     But we need to remove the candidate 'v' from the pool.
                    //       //     
                    //       //     So in ADD_TO_CLIQUE:
                    //       //       Pick v.
                    //       //       stack_cand[local_depth] &= ~(1<<v).
                    //       //       local_max <= max(local_max, local_depth + 1).
                    //       //       if (local_depth + 1 == K):
                    //       //         state <= BACKTRACK.
                    //       //       else:
                    //       //         stack_v[local_depth] <= v;
                    //       //         local_depth <= local_depth + 1;
                    //       //         addrb <= v;
                    //       //         state <= CHECK_CANDIDATES.
                    //       //       
                    //       //     This handles K constraint.

                    // Calculate candidates
                    if (local_depth == 1) begin
                        temp_cand = doutb & local_valid_mask;
                    end else begin
                        temp_cand = doutb & stack_cand[local_depth - 1];
                    end
                    
                    // Store for next level
                    stack_cand[local_depth] <= temp_cand;
                    
                    if (temp_cand == 0) begin
                        state <= BACKTRACK;
                    end else begin
                        state <= ADD_TO_CLIQUE;
                    end
                end

                ADD_TO_CLIQUE: begin
                    // Pick a vertex from stack_cand[local_depth]
                    // This needs combinational logic to find the first set bit.
                    // We'll use a loop-like approach or assume one bit is found per cycle (since we are in a state).
                    // But we can't loop in HW. We must iterate or use priority encoder logic.
                    // Since it's a state machine, we can do it in one cycle if we write the logic explicitly.
                    // 50 bits is small enough for a priority encoder chain.
                    
                    // Logic to find first set bit in 'stack_cand[local_depth]':
                    found_bit = 0;
                    bit_idx = 0;
                    for (int k = 0; k < 50; k++) begin
                        if (!found_bit && stack_cand[local_depth][k]) begin
                            found_bit = 1;
                            bit_idx = k;
                        end
                    end
                    
                    // If found (should be true as we came from CHECK_CANDIDATES)
                    if (found_bit) begin
                        // Remove this vertex from the pool for this level
                        stack_cand[local_depth] <= stack_cand[local_depth] & ~(1 << bit_idx);
                        
                        // Check if adding this vertex reaches max size
                        if (local_depth + 1 == K) begin
                            // Max size reached, don't extend, just backtrack
                            if (local_depth + 1 > local_max) local_max <= local_depth + 1;
                            state <= BACKTRACK;
                        end else begin
                            // Add to stack and extend
                            stack_v[local_depth] <= bit_idx;
                            local_depth <= local_depth + 1;
                            if (local_depth + 1 > local_max) local_max <= local_depth + 1;
                            addrb <= bit_idx; // Prepare for next read
                            state <= CHECK_CANDIDATES;
                        end
                    end else begin
                        // Should not happen if logic is correct
                        state <= BACKTRACK;
                    end
                end

                BACKTRACK: begin
                    local_depth <= local_depth - 1;
                    if (local_depth == 1) begin // If we backtrack from depth 1, we are done with this start vertex
                        state <= UPDATE_MAX;
                    end else begin
                        // Return to previous node to try other candidates
                        // But we need to read neighbors of the previous node? 
                        // No, we need to go to CHECK_CANDIDATES, which expects 'doutb' of the previous node.
                        // But 'doutb' is currently neighbors of the node we just popped.
                        // So we need to set 'addrb' for the new top of stack.
                        // Wait, 'local_depth' is now decreased. So new top is 'local_depth - 1'.
                        // But we need to wait for 'doutb'.
                        // So we set 'addrb' = 'stack_v[local_depth - 2]'? No.
                        // If local_depth was 2, we pop to 1. New top is 1 (index 0). 
                        // We need neighbors of stack_v[0].
                        // So we set addrb = stack_v[0].
                        // Wait, 'local_depth' just decremented. 
                        // If local_depth == 1, we popped to size 0? 
                        // No, local_depth tracks the *next* slot. 
                        // Wait, I defined local_depth as 'current size'. 
                        // In ADD_TO_CLIQUE: local_depth++ (size increases). 
                        // So local_depth is the size. 
                        // If local_depth was 2, size is 2. 
                        // Stack indices 0 and 1 are filled. 
                        // We pop. local_depth becomes 1. 
                        // We want to try other candidates for stack_v[0]. 
                        // So we need neighbors of stack_v[0]. 
                        // But stack_cand[1] holds candidates for level 1. 
                        // We are now back at level 0? 
                        // Wait, 'stack_cand' logic:
                        // stack_cand[local_depth] stores candidates for 'local_depth'. 
                        // In ADD_TO_CLIQUE, we operated on stack_cand[local_depth]. 
                        // After popping, we go back to stack_cand[local_depth - 1]. 
                        // But we don't need to read neighbors of stack_v[local_depth - 1] again. 
                        // We just need to re-enter CHECK_CANDIDATES to pick the next candidate from stack_cand[local_depth - 1]. 
                        // 
                        // Wait, CHECK_CANDIDATES does: 
                        // stack_cand[local_depth] = neighbors(stack_v[local_depth-1]) & stack_cand[local_depth-1]. 
                        // This overwrites stack_cand[local_depth]. 
                        // So if we backtrack, we lose stack_cand[local_depth] (which is fine, we are dropping a level). 
                        // We need to restore stack_cand[local_depth - 1]? 
                        // No, stack_cand[local_depth - 1] was NOT modified in the deeper level. 
                        // It was only read. 
                        // In ADD_TO_CLIQUE, we modified stack_cand[local_depth]. 
                        // So stack_cand[local_depth - 1] is intact and holds the remaining candidates for that level.
                        // 
                        // So, on BACKTRACK:
                        // local_depth--. 
                        // Now local_depth is the current level we are returning to. 
                        // We need to pick the next candidate from stack_cand[local_depth]. 
                        // So we go to ADD_TO_CLIQUE. 
                        // But ADD_TO_CLIQUE expects stack_cand[local_depth] to be ready.
                        // It is. 
                        // 
                        // Wait, in ADD_TO_CLIQUE, we used stack_cand[local_depth] (where local_depth was the size). 
                        // In BACKTRACK, we decrease local_depth. 
                        // So we are back to level 'local_depth'. 
                        // We need to try the next candidate in 'stack_cand[local_depth]'. 
                        // So we just go to ADD_TO_CLIQUE. 
                        // 
                        // BUT, in CHECK_CANDIDATES, we set stack_cand[local_depth] = ... 
                        // When we backtracked, we are returning to a previous level. 
                        // Do we need to re-calculate stack_cand[local_depth]? 
                        // No, because we didn't modify stack_cand[local_depth] (the slot for the current level). 
                        // We modified stack_cand[local_depth+1] in the deeper recursion. 
                        // 
                        // So on BACKTRACK, simply:
                        // local_depth--;
                        // state <= ADD_TO_CLIQUE; 
                        // 
                        // Wait, what if we backtracked all the way to 0? 
                        // Then we are done with this start vertex. 
                        // 
                        // So logic:
                        // local_depth <= local_depth - 1; 
                        // if (local_depth == 0) state <= UPDATE_MAX; 
                        // else state <= ADD_TO_CLIQUE; 
                        // 
                        // Wait, local_depth is decremented. 
                        // If old local_depth was 1 (size 1), after decrement it's 0. 
                        // We are done. 
                        
                        // BUT, what about the 'addrb' for CHECK_CANDIDATES? 
                        // We are going to ADD_TO_CLIQUE, not CHECK_CANDIDATES. 
                        // ADD_TO_CLIQUE picks from stack_cand[local_depth]. 
                        // It doesn't need 'doutb'. 
                        // So no address setup needed. 
                        
                        // Wait, what if we backtrack from depth 2 to 1. 
                        // local_depth becomes 1. 
                        // We go to ADD_TO_CLIQUE. 
                        // ADD_TO_CLIQUE picks from stack_cand[1]. 
                        // stack_cand[1] was calculated in the previous CHECK_CANDIDATES (level 1). 
                        // But wait, when we went from level 1 to level 2 (depth 1 to 2), we called CHECK_CANDIDATES (level 2). 
                        // In CHECK_CANDIDATES (level 2), we calculated stack_cand[2] = ... 
                        // We did NOT touch stack_cand[1]. 
                        // So stack_cand[1] still holds the set of candidates for level 1 (which includes the 'v' we just tried and removed). 
                        // Actually, in ADD_TO_CLIQUE (level 1), we removed 'v' from stack_cand[1]. 
                        // Then we went to level 2. 
                        // Then we backtrack. 
                        // We return to level 1. 
                        // stack_cand[1] still has the set WITHOUT 'v'. 
                        // So ADD_TO_CLIQUE (level 1) will pick the next candidate. 
                        // 
                        // This is correct. 
                        
                        state <= ADD_TO_CLIQUE;
                    end
                end

                UPDATE_MAX: begin
                    // Update global max
                    if (local_max > max_clique_size) begin
                        max_clique_size <= local_max;
                    end
                    
                    // Next start vertex
                    curr_start_v <= curr_start_v + 1;
                    
                    if (curr_start_v + 1 >= N) begin // We just incremented, check if done
                        state <= DONE;
                        done <= 1;
                        busy <= 0;
                    end else begin
                        state <= BUILD_CLIQUE;
                    end
                end

                DONE: begin
                    // Stay here until reset or start again
                    // busy is already 0
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

// Helper module for BRAM inference (Optional, but I implemented logic inline using 'mem' array).
// The code above uses explicit memory array 'mem' and procedural assignment for ports.
// This is synthesizable for FPGA (inferred distributed RAM or BRAM).
// For ASIC, standard logic (Flip-Flops + Mux) or custom RAM macro is used.
// The provided code uses standard Verilog which synthesis tools map to available resources.

// Note: The 'for' loop in ADD_TO_CLIQUE is a static loop and will be unrolled by synthesis tools.
// It's a standard way to implement priority encoder logic.

// Since the prompt requires a single module, I included everything inside 'largest_committee'.
// I added 'doutb_reg' to model the read latency of BRAM (which is typical).
// If the tool assumes zero-latency RAM, the state machine logic needs adjustment (specifically the 'CHECK_CANDIDATES' state which relies on 'doutb' being available 1 cycle after address set).
// My logic sets address in state X, and reads in state X+1. This is correct for 1-cycle RAM latency.
