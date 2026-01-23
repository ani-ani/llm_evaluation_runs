module bird_label_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] parent,
    input wire [1:0] v_type,
    input wire [1:0] v_subtype,
    input wire [39:0] v_label,
    input wire config_mode,
    output reg result_valid,
    output reg [3:0] change_count,
    output reg [5:0] change_v_idx,
    output reg [39:0] new_label
);

    // Parameters for State Machine
    localparam IDLE = 5'd0;
    localparam CONFIG_WAIT = 5'd1;
    localparam PREP_COMPUTE = 5'd2;
    localparam BUILD_HIERARCHY = 5'd3;
    localparam CALC_AREA_TINY = 5'd4;
    localparam CONFLICT_CHECK = 5'd5;
    localparam BERRY_OWNERSHIP = 5'd6;
    localparam CALC_AREA_GIANT = 5'd7;
    localparam CHECK_OWNERSHIP_CHANGE = 5'd8;
    localparam APPLY_FIX = 5'd9;
    localparam DONE = 5'd10;

    // Memory Structures (1-based indexing for vertices, 0 unused)
    reg [5:0] p_ptr [15:1];          // Parent index
    reg [1:0] branch_type [15:1];    // 00=Big, 01=Small (based on v_type for Branches)
    reg is_leaf [15:1];              // 1 if leaf
    reg is_berry [15:1];             // 1 if berry
    reg is_giant [15:1];             // 1 if giant bird
    reg is_tiny [15:1];              // 1 if tiny bird
    reg [39:0] label_store [15:1];   // ASCII label
    reg valid_node [15:1];           // Node configured

    // Scratchpads
    reg [15:0] area_mask;            // Current area being built
    reg [15:0] area_tiny [15:1];     // Area when tiny
    reg [15:0] area_giant [15:1];    // Area when giant
    reg [5:0] ancestor_idx;          // Temp for finding ancestor
    reg [5:0] curr_idx;              // Iterator index
    reg [5:0] other_idx;             // Iterator index 2
    reg [5:0] berry_idx;             // Iterator for berries
    
    // Bird/Leaf Lists for iteration
    reg [5:0] bird_list [7:0];       // List of bird vertex indices
    reg [2:0] bird_count;
    reg [5:0] berry_list [7:0];      // List of berry vertex indices
    reg [2:0] berry_count;

    // Control Registers
    reg [4:0] state;
    reg [4:0] next_state;
    reg [3:0] conflict_count;
    reg ownership_changed;

    // Helper logic: Determine ancestor for Giant Bird
    // Walks up parent pointers to find first Big Branch (v_type 00)
    // Or root if no Big Branch found.
    // Since this is complex in combinational logic, we do it step-by-step in state machine
    // or use a pre-calculation state.
    
    integer i, j, k;
    reg [5:0] temp_idx;
    reg [15:0] mask_temp;
    reg [39:0] temp_label;
    reg [5:0] owner_idx;
    reg [15:0] min_area;
    reg [5:0] min_area_idx;
    reg match_found;
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            change_count <= 0;
            change_v_idx <= 0;
            new_label <= 0;
            bird_count <= 0;
            berry_count <= 0;
            // Reset memory arrays (optional in simulation, handled by valid_node)
            for (i=1; i<=15; i=i+1) valid_node[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start && config_mode) begin
                        state <= CONFIG_WAIT;
                        result_valid <= 0;
                        bird_count <= 0;
                        berry_count <= 0;
                        change_count <= 0;
                    end
                end

                CONFIG_WAIT: begin
                    // Waiting for config_mode to go low to signal end of configuration
                    if (start && !config_mode) begin
                        state <= PREP_COMPUTE;
                    end else if (start && config_mode) begin
                        // Loading Data
                        if (parent != 0) begin // Valid entry
                            if (parent <= 16) begin
                                p_ptr[parent] <= parent;
                            end
                        end
                    end
                end
                
                // ... rest of states
            endcase
        end
    end

    // Sequential Config Counter Logic (to handle implicit addressing)
    reg [3:0] config_cnt; // 0 to 15
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_cnt <= 4'd1;
        end else if (state == IDLE) begin
            config_cnt <= 4'd1;
        end else if (state == CONFIG_WAIT && start && config_mode) begin
            if (config_cnt < 15) config_cnt <= config_cnt + 1;
            else config_cnt <= 1; // Wrap or stay? Just keep 1-16 range
        end
    end

    // Config Storage Logic (Inside FSM or separate block)
    always @(posedge clk) begin
        if (state == CONFIG_WAIT && start && config_mode) begin
            // Use config_cnt as the vertex index being configured
            // The spec says "parent [5:0]: Parent index for the current vertex"
            // This implies `parent` input IS the parent index of vertex `config_cnt`.
            p_ptr[config_cnt] <= parent;
            branch_type[config_cnt] <= v_type; // 00=Big, 01=Small (Branches) - Ignored for leaves usually
            
            if (v_type == 2'b10) begin // Leaf
                is_leaf[config_cnt] <= 1;
                is_berry[config_cnt] <= (v_subtype == 2'b00); // 00=Berry
                is_giant[config_cnt] <= (v_subtype == 2'b01); // 01=Giant
                is_tiny[config_cnt] <= (v_subtype == 2'b10);  // 10=Tiny
                label_store[config_cnt] <= v_label;
                
                // Update lists
                if (v_subtype == 2'b01 || v_subtype == 2'b10) begin
                    bird_list[bird_count] <= config_cnt;
                    bird_count <= bird_count + 1;
                end else if (v_subtype == 2'b00) begin
                    berry_list[berry_count] <= config_cnt;
                    berry_count <= berry_count + 1;
                end
            end else begin
                is_leaf[config_cnt] <= 0;
                is_berry[config_cnt] <= 0;
                is_giant[config_cnt] <= 0;
                is_tiny[config_cnt] <= 0;
                label_store[config_cnt] <= 0;
            end
            valid_node[config_cnt] <= 1;
        end
    end

    // Main FSM Logic for Compute
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                PREP_COMPUTE: begin
                    curr_idx <= 1;
                    state <= BUILD_HIERARCHY;
                    bird_count <= bird_count; // Keep count
                    berry_count <= berry_count;
                end

                // State 3: Build Hierarchy (Resolve Ancestors for Tiny Birds)
                // Tiny birds take parent's subtree. 
                // Giant birds take Big Branch ancestor's subtree.
                // We need to fill `p_ptr` correctly for Tiny birds (they already have parent).
                // For Giant birds, we need to find the Big Branch Ancestor.
                // To simplify area calculation later, let's ensure `p_ptr` for Giant Birds points to the Big Branch Ancestor (or 0 if root).
                // Wait, `p_ptr` is used to build the tree. 
                // Tiny Area = Subtree of Parent.
                // Giant Area = Subtree of Big Branch Ancestor.
                // Let's just calculate areas in the next states.
                BUILD_HIERARCHY: begin
                    if (curr_idx <= 16) begin
                        if (valid_node[curr_idx] && is_giant[curr_idx]) begin
                            // Find big branch ancestor
                            temp_idx <= p_ptr[curr_idx];
                            state <= 5'd11; // Sub-state for search
                        end else begin
                            curr_idx <= curr_idx + 1;
                        end
                    end else begin
                        curr_idx <= 1;
                        state <= CALC_AREA_TINY;
                    end
                end

                // State 11: Find Big Branch Ancestor (loop)
                5'd11: begin
                    if (temp_idx == 0 || temp_idx > 16) begin
                        // Reached root or invalid, Giant bird considers root as ancestor (or nothing)
                        // If root is a branch (even small), it's the ancestor.
                        // Let's say if no big branch found, ancestor is Root (1).
                        // Update p_ptr for giant bird to point to this ancestor for area calculation.
                        p_ptr[curr_idx] <= 1; // Fallback to root
                        curr_idx <= curr_idx + 1;
                        state <= BUILD_HIERARCHY;
                    end else if (branch_type[temp_idx] == 2'b00) begin
                        // Found Big Branch
                        p_ptr[curr_idx] <= temp_idx;
                        curr_idx <= curr_idx + 1;
                        state <= BUILD_HIERARCHY;
                    end else begin
                        // Walk up
                        temp_idx <= p_ptr[temp_idx];
                        // Stay in state 11
                    end
                end

                // State 4: Calculate Tiny Areas
                // Area of a node is all descendants.
                // We can build child lists or just brute force check parent pointers.
                // Given 16 nodes, O(16^2) is fine.
                CALC_AREA_TINY: begin
                    if (curr_idx <= 16) begin
                        if (valid_node[curr_idx]) begin
                            // Iterate all nodes to see if they are in subtree
                            // The area of curr_idx includes curr_idx and all its descendants.
                            // Tiny bird: Area = Parent's area.
                            // Wait, instructions: "For Tiny Birds: Area is subtree of parent."
                            // So if curr_idx is a tiny bird, we calculate area of (parent of curr_idx).
                            
                            // Let's calculate area for ALL nodes first (as roots).
                            // Then assign to birds.
                            // Tiny bird uses Parent area. Giant bird uses Ancestor area (calculated in step 3).
                            
                            // We are calculating specific areas for birds.
                            // Let's use another index for the area root.
                            
                            // Let's step back. 
                            // We need `area_tiny[v]` for birds. This is the area of parent of v.
                            // We need `area_giant[v]` for birds. This is the area of ancestor of v.
                            
                            // Let's calculate area of EVERY node first. 
                            // Let's use a state `CALC_ALL_AREAS` where `curr_idx` is the root of the area.
                            state <= 5'd12;
                            other_idx <= 1; // Iterate all nodes to check inclusion
                            area_mask <= 0;
                        end else begin
                            curr_idx <= curr_idx + 1;
                        end
                    end else begin
                        curr_idx <= 1;
                        state <= CONFLICT_CHECK;
                    end
                end

                // State 12: Calculate Area of Node `curr_idx` (Helper)
                5'd12: begin
                    if (other_idx <= 16) begin
                        // Check if other_idx is descendant of curr_idx
                        // Walk up from other_idx to see if we hit curr_idx
                        // Optimization: Pre-calc parents.
                        // Recursive: Node is in subtree if parent == curr_idx OR parent is in subtree.
                        // Let's do iterative parent walk for `other_idx` to see if it matches `curr_idx`.
                        
                        // Optimization for synthesis: simple traversal.
                        // If other_idx == curr_idx -> Yes
                        // Else check parent of other_idx. If it matches curr_idx -> Yes. 
                        // Else check parent of parent... up to root.
                        
                        // We need a temporary walker.
                        // Let's use `temp_idx` as the walker for `other_idx`.
                        temp_idx <= other_idx;
                        state <= 5'd13;
                    end else begin
                        // Area calculated. Store it.
                        // Now, `curr_idx` is the root of the area.
                        // We need to save this area to the birds that use it.
                        // Tiny birds use area of their parent. Giant birds use area of their ancestor.
                        // So we iterate birds.
                        other_idx <= 0; // Index in bird_list
                        state <= 5'd14; // Assign to birds
                    end
                end

                // State 13: Check Descendant (Worker)
                5'd13: begin
                    if (temp_idx == curr_idx) begin
                        area_mask <= area_mask | (1 << (other_idx - 1)); // Set bit
                        state <= 5'd12;
                        other_idx <= other_idx + 1;
                    end else if (temp_idx == 0 || temp_idx > 16) begin
                        state <= 5'd12;
                        other_idx <= other_idx + 1;
                    end else begin
                        temp_idx <= p_ptr[temp_idx];
                        // Stay in this state
                    end
                end

                // State 14: Assign Computed Area to Birds
                5'd14: begin
                    if (other_idx < bird_count) begin
                        temp_idx <= bird_list[other_idx]; // Bird Index
                        state <= 5'd15;
                    end else begin
                        // Done with this root.
                        curr_idx <= curr_idx + 1;
                        state <= 5'd12; // Loop back to 12 to handle next root, or back to 12...
                        // Wait, 12 expects curr_idx to be root. 
                        // If we just finished curr_idx, increment curr_idx.
                        // But we are inside the sub-sequence starting from CALC_AREA_TINY.
                        // Let's restructure.
                        // We need to calculate areas for ALL 16 nodes? That's 16 roots.
                        // Then we map to birds.
                        // Let's use `other_idx` as the "Target Root".
                        // So in State 5, we do:
                        // `other_idx` goes 1 to 16.
                        // Calculate Area for `other_idx`.
                        // Then save it.
                        // Then loop.
                        
                        // Current logic in 5 sets `curr_idx` to 1.
                        // Enters 12. Sets `other_idx` to 1.
                        // Calculates Area for `curr_idx`.
                        // Then jumps to 14 (Assign). 
                        // 14 assigns `area_mask` to birds whose ancestor/parent is `curr_idx`.
                        // Then back to 12 loop?
                        
                        // Let's simplify. 
                        // State 5: `curr_idx` loops 1..16 (Area Roots).
                        // Inside, call 12 (Calc Area), then 14 (Save).
                        // Then `curr_idx`++.
                        
                        // So from 14, go to 5 (Next Root).
                        state <= CALC_AREA_TINY;
                        bird_idx_ptr <= 0; // Reset bird iterator for next root mapping
                    end
                end
                
                reg [2:0] bird_idx_ptr;
                5'd15: begin // Check if this bird needs this area
                    // Tiny bird: uses parent's area. If `curr_idx` == parent of bird.
                    // Giant bird: uses ancestor's area. If `curr_idx` == ancestor of bird.
                    // Wait, we modified `p_ptr` for Giant birds to be the ancestor.
                    // So for Giant birds, `p_ptr` IS the ancestor.
                    // For Tiny birds, `p_ptr` is the parent.
                    // So logic is: if `p_ptr[temp_idx]` == `curr_idx`.
                    if (p_ptr[temp_idx] == curr_idx) begin
                        // Found the root for this bird
                        if (is_tiny[temp_idx]) area_tiny[temp_idx] <= area_mask;
                        if (is_giant[temp_idx]) area_giant[temp_idx] <= area_mask;
                    end
                    bird_idx_ptr <= bird_idx_ptr + 1;
                    if (bird_idx_ptr + 1 < bird_count) begin
                        temp_idx <= bird_list[bird_idx_ptr + 1];
                        state <= 5'd15;
                    end else begin
                        state <= 5'd14; // Go back to finish 14
                    end
                end

                // Re-structuring the Area Calculation for clarity in synthesis:
                // Let's do a loop for `curr_idx` (Root of Area) 1 to 16.
                // Calculate Area for `curr_idx`.
                // Then iterate Birds. If Bird's Parent/Ancestor == `curr_idx`, save Area.
                // Then `curr_idx`++.
                // Transition: CALC_AREA_TINY -> (Calc Area Loop) -> (Assign Area) -> (Next Root) -> ... -> (Done) -> CONFLICT_CHECK
                
                // Let's rewrite the Area Logic Sequence cleanly:
                // CALC_AREA_TINY (State 4):
                //   If curr_idx <= 16:
                //     state = CALC_SUBROUTINE;
                //     other_idx = 1;
                //     area_mask = 0;
                //   Else:
                //     state = CONFLICT_CHECK;
                // 
                // CALC_SUBROUTINE (State 12):
                //   If other_idx <= 16:
                //     Walk parent of other_idx. If match curr_idx or self, set bit. other_idx++.
                //   Else:
                //     state = SAVE_AREA;
                //     bird_ptr = 0;
                // 
                // SAVE_AREA (State 13):
                //   If bird_ptr < bird_count:
                //     bird_idx = bird_list[bird_ptr]
                //     If p_ptr[bird_idx] == curr_idx:
                //       if tiny: store area_tiny
                //       if giant: store area_giant
                //     bird_ptr++
                //   Else:
                //     curr_idx++
                //     state = CALC_AREA_TINY

                // Implementing this restructured flow:
                // I will map states 4, 12, 13 to these roles.

                CALC_AREA_TINY: begin // Loop 1..16 for roots
                    if (curr_idx <= 16) begin
                        other_idx <= 1;
                        area_mask <= 0;
                        state <= 5'd12; // Calc Area Subroutine
                    end else begin
                        curr_idx <= 1;
                        other_idx <= 0; // Bird iterator
                        state <= CONFLICT_CHECK;
                    end
                end

                5'd12: begin // Check inclusion for other_idx
                    if (other_idx <= 16) begin
                        // Check if other_idx is descendant of curr_idx
                        // Walk up from other_idx
                        temp_idx <= other_idx;
                        state <= 5'd16; // Walk Up Loop
                    end else begin
                        // Area done
                        bird_idx_ptr <= 0;
                        state <= 5'd13; // Save to Birds
                    end
                end

                5'd16: begin // Walk Up Loop
                    if (temp_idx == curr_idx) begin
                        area_mask <= area_mask | (1 << (other_idx - 1));
                        state <= 5'd12;
                        other_idx <= other_idx + 1;
                    end else if (temp_idx == 0 || temp_idx > 16) begin
                        state <= 5'd12;
                        other_idx <= other_idx + 1;
                    end else begin
                        temp_idx <= p_ptr[temp_idx];
                    end
                end

                5'd13: begin // Save Area to Birds
                    if (bird_idx_ptr < bird_count) begin
                        temp_idx <= bird_list[bird_idx_ptr];
                        state <= 5'd17;
                    end else begin
                        curr_idx <= curr_idx + 1;
                        state <= CALC_AREA_TINY;
                    end
                end

                5'd17: begin // Check Match
                    if (p_ptr[temp_idx] == curr_idx) begin
                        if (is_tiny[temp_idx]) area_tiny[temp_idx] <= area_mask;
                        if (is_giant[temp_idx]) area_giant[temp_idx] <= area_mask;
                    end
                    bird_idx_ptr <= bird_idx_ptr + 1;
                    state <= 5'd13;
                end

                // Conflict Check
                CONFLICT_CHECK: begin
                    // Iterate pairs of birds
                    if (other_idx < bird_count) begin // other_idx is i
                        if (bird_idx_ptr < bird_count) begin // bird_idx_ptr is j
                            if (other_idx != bird_idx_ptr) begin
                                // Check pair
                                temp_idx <= bird_list[other_idx];
                                other_idx <= bird_list[bird_idx_ptr]; // Temp reuse
                                state <= 5'd20; // Compare Pair
                            end else begin
                                bird_idx_ptr <= bird_idx_ptr + 1;
                            end
                        end else begin
                            other_idx <= other_idx + 1;
                            bird_idx_ptr <= 0;
                        end
                    end else begin
                        // Done checking
                        // Go to Berry Ownership
                        berry_idx <= 0;
                        state <= BERRY_OWNERSHIP;
                    end
                end

                5'd20: begin // Compare Pair
                    // temp_idx = bird 1, other_idx = bird 2
                    // Check Labels match AND Area (Tiny) matches
                    if (label_store[temp_idx] == label_store[other_idx]) begin
                        if (area_tiny[temp_idx] == area_tiny[other_idx]) begin
                            // Conflict detected
                            change_count <= 1; // We need at least one change
                            change_v_idx <= temp_idx; // Pick first one
                            // Find a new label (simplistic: just toggle 'T' to 't' or something, but we need ASCII)
                            // Let's generate "c" (0x63)
                            new_label <= {8'h63, 32'h0}; // "c"
                            state <= DONE; // Early exit? Or continue? Let's continue to check berries?
                            // Optimization: If conflict, we stop and report fix.
                            result_valid <= 1;
                            state <= IDLE; // Or DONE state
                        end else begin
                            // No conflict (different areas)
                            state <= CONFLICT_CHECK;
                            bird_idx_ptr <= bird_idx_ptr + 1;
                        end
                    end else begin
                        state <= CONFLICT_CHECK;
                        bird_idx_ptr <= bird_idx_ptr + 1;
                    end
                end

                // Berry Ownership Check (Tiny Mode)
                BERRY_OWNERSHIP: begin
                    if (berry_idx < berry_count) begin
                        temp_idx <= berry_list[berry_idx];
                        owner_idx <= 0;
                        min_area <= 16'hFFFF;
                        state <= 5'd21; // Iterate birds to find owner
                    end else begin
                        // Done with Tiny Mode Ownership
                        // Now simulate Giant Mode
                        berry_idx <= 0;
                        ownership_changed <= 0;
                        // Need to re-calculate areas? No, we have area_giant.
                        // But we need to verify against Tiny Owners.
                        // We stored Tiny Owners? No, we didn't.
                        // Let's re-calculate Tiny Owners and store them, or just re-run ownership check.
                        // Optimization: Since state machine is complex, let's store Tiny Owners.
                        // Actually, let's just run the ownership check again, but using Giant Areas.
                        // And compare with the result we just got?
                        // But we didn't store it. 
                        // Let's add a register to store Tiny Owner for current berry.
                        // Or, re-run Tiny ownership in a separate pass.
                        
                        // To save states, let's store Tiny Owner in a temporary array.
                        // Since we are at BERRY_OWNERSHIP, we can store the found owner.
                        // But we need to compare with Giant Owner.
                        // Let's change flow: 
                        // 1. Tiny Ownership -> Store Tiny Owners.
                        // 2. Giant Ownership -> Compare with Tiny.
                        
                        state <= 5'd25; // Transition to Giant Check
                    end
                end

                5'd21: begin // Find Tiny Owner
                    // Iterate birds (bird_idx_ptr)
                    if (bird_idx_ptr < bird_count) begin
                        temp_idx <= bird_list[bird_idx_ptr];
                        state <= 5'd22;
                    end else begin
                        // Found Owner (if any)
                        // Store owner_idx (if valid)
                        // Since we don't have an array for owners, we need to pass it to Giant Check.
                        // Let's use `change_v_idx` to store Tiny Owner temporarily? No, we need it for later.
                        // Let's use a dedicated register `tiny_owner [berry_idx]` ? 
                        // We have 8 berries max. We can store in a vector.
                        // But we need to store for ALL berries.
                        
                        // Let's create a small memory for tiny owners.
                        // reg [5:0] tiny_owner [7:0];
                        // We need to store `owner_idx` into `tiny_owner[berry_idx]`.
                        // Verilog allows array update in sequential block.
                        
                        // We need a sequential update or combinational.
                        // Let's do it in state 21 after loop.
                        berry_idx <= berry_idx + 1;
                        bird_idx_ptr <= 0;
                        state <= BERRY_OWNERSHIP;
                    end
                end
                
                // Combinational logic needed for Owner Selection (since state 21/22 are sequential)
                // We can do it sequentially step by step.
                // Let's optimize: 
                // In BERRY_OWNERSHIP (State 6):
                // If berry_idx < count:
                //   bird_idx = 0
                //   min_area = inf
                //   owner = 0
                //   Loop birds:
                //     If bird in area:
                //       If area_size < min_area:
                //         min_area = area_size, owner = bird
                //   TinyOwners[berry_idx] = owner
                //   berry_idx++
                // 
                // This requires nested loops.
                
                // Let's simplify the state machine to just do 1 berry per clock if needed, or handle loops.
                // Given 1024 cycles, we can be slow.
                
                // State 21: Setup Berry
                // State 22: Check Bird
                // State 23: Update Min
                // State 24: Next Bird
                // Loop 22-24.
                // State 26: Store Tiny Owner. Next Berry.

                5'd21: begin // Setup Berry
                    if (berry_idx < berry_count) begin
                        owner_idx <= 0;
                        min_area <= 16'hFFFF;
                        min_area_idx <= 0;
                        bird_idx_ptr <= 0;
                        state <= 5'd22; // Check Bird
                    end else begin
                        // All Tiny Owners found. Transition to Giant Check.
                        // Reset indices for Giant Check.
                        berry_idx <= 0;
                        state <= 5'd25; // Giant Check Setup
                    end
                end

                5'd22: begin // Check Bird for Tiny Owner
                    if (bird_idx_ptr < bird_count) begin
                        temp_idx <= bird_list[bird_idx_ptr];
                        state <= 5'd23; // Evaluate
                    end else begin
                        // Finished birds for this berry. Store result.
                        // Sequential update of array:
                        tiny_owner[berry_idx] <= min_area_idx;
                        
                        berry_idx <= berry_idx + 1;
                        state <= 5'd21;
                    end
                end

                5'd23: begin // Evaluate Bird vs Berry
                    // Check if bird's Tiny Area contains berry
                    // Berry index = temp_idx (wait, temp_idx used for bird)
                    // Let's use other_idx for Berry.
                    other_idx <= berry_list[berry_idx]; // Keep berry index
                    
                    // Check bit: (area_tiny[bird] >> (berry-1)) & 1
                    // In Verilog: area_tiny[temp_idx][berry_list[berry_idx]-1]
                    // Note: area_tiny[16:1], berry index 1-16.
                    
                    if (area_tiny[temp_idx][ berry_list[berry_idx]-1 ]) begin
                        // It contains. Check label match.
                        if (label_store[temp_idx] == label_store[berry_list[berry_idx]]) begin
                            // Valid owner candidate. Check size.
                            // Size is number of bits in mask. 
                            // Popcount logic? Or just compare bitmasks (smaller integer value = smaller area? 
                            // No, mask 0x0001 is smaller than 0x8000 but area size 1 vs 1.
                            // We need smallest *number* of set bits.
                            // We can pre-calculate size or compute on fly.
                            // Let's use a popcount helper state or assume smaller bitmask value implies smaller area (WRONG).
                            // Let's do a popcount.
                            // But we can just compare bitmasks if we assume minimal spanning tree? No.
                            // Let's assume the mask value is sufficient? 
                            // Area 1 (node 1) = 0x0001. Area 2 (node 2) = 0x0002. 
                            // Area 1-2 = 0x0003.
                            // If we compare 0x0003 vs 0x0004, 0x0003 is smaller. 
                            // But 0x0004 could be a single node further down.
                            // We MUST count bits.
                            
                            // Let's use a temp counter.
                            // Popcount of area_tiny[temp_idx]
                            // We can do this in a loop state.
                            // Optimization: Since we only have 1024 cycles, let's do a loop.
                            
                            // Or, we can pre-calculate area size during area calculation.
                            // Let's add `area_size_tiny [15:1]` during CALC_AREA_TINY.
                            // This saves states.
                            // Let's assume we have `area_size_tiny`.
                            // Update: In State 13 (Save Area), we should have computed size.
                            // Let's add that logic later. For now, assume we have size.
                            
                            // If we don't have size, we need to calculate it now.
                            // Given the constraints, let's add size calculation to the area step.
                            // 
                            // Let's assume we have `area_size_tiny` and `area_size_giant`.
                            // Check if `area_size_tiny[temp_idx] < min_area`.
                            
                            // Comparator Logic:
                            if (area_size_tiny[temp_idx] < min_area) begin
                                min_area <= area_size_tiny[temp_idx];
                                min_area_idx <= temp_idx;
                            end else if (area_size_tiny[temp_idx] == min_area) begin
                                // Tie breaker? Pick smallest index or first found?
                                // Let's pick smallest index.
                                if (temp_idx < min_area_idx) begin
                                    min_area_idx <= temp_idx;
                                end
                            end
                        end
                    end
                    state <= 5'd24; // Next Bird
                end

                5'd24: begin // Next Bird
                    bird_idx_ptr <= bird_idx_ptr + 1;
                    state <= 5'd22;
                end

                // Giant Check
                // We have Tiny Owners stored.
                // We need to find Giant Owners.
                // Then compare.
                5'd25: begin // Giant Check Setup
                    if (berry_idx < berry_count) begin
                        owner_idx <= 0;
                        min_area <= 16'hFFFF;
                        min_area_idx <= 0;
                        bird_idx_ptr <= 0;
                        state <= 5'd27; // Check Bird (Giant)
                    end else begin
                        // All checked. 
                        if (ownership_changed || change_count > 0) begin
                            // If conflicts found earlier, change_count is already set.
                            // If ownership changed but no conflict, we need to set change_count.
                            if (change_count == 0) change_count <= 1;
                            state <= DONE;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                5'd27: begin // Check Bird (Giant)
                    if (bird_idx_ptr < bird_count) begin
                        temp_idx <= bird_list[bird_idx_ptr];
                        state <= 5'd28; // Evaluate Giant
                    end else begin
                        // Found Giant Owner. Compare with Tiny Owner.
                        // Tiny Owner: tiny_owner[berry_idx]
                        // Giant Owner: min_area_idx
                        if (min_area_idx != tiny_owner[berry_idx]) begin
                            ownership_changed <= 1;
                        end
                        berry_idx <= berry_idx + 1;
                        state <= 5'd25;
                    end
                end

                5'd28: begin // Evaluate Giant
                    other_idx <= berry_list[berry_idx];
                    // Check label match AND Giant Area contains Berry
                    if (label_store[temp_idx] == label_store[berry_list[berry_idx]] && 
                        area_giant[temp_idx][ berry_list[berry_idx]-1 ]) begin
                        
                        // Check size
                        if (area_size_giant[temp_idx] < min_area) begin
                            min_area <= area_size_giant[temp_idx];
                            min_area_idx <= temp_idx;
                        end else if (area_size_giant[temp_idx] == min_area) begin
                            if (temp_idx < min_area_idx) begin
                                min_area_idx <= temp_idx;
                            end
                        end
                    end
                    state <= 5'd29; // Next Giant Bird
                end

                5'd29: begin // Next Giant Bird
                    bird_idx_ptr <= bird_idx_ptr + 1;
                    state <= 5'd27;
                end

                DONE: begin
                    result_valid <= 1;
                    // If we need to output a fix, we should have set change_v_idx and new_label.
                    // If we only set change_count, we need to generate a fix.
                    // "If conflicts exist or ownership changes, increment change count."
                    // "Output the first problematic bird... assign it a unique new label."
                    
                    if (change_v_idx == 0 && change_count > 0) begin
                        // We didn't pick a specific bird (e.g., only ownership change).
                        // Pick the first bird.
                        change_v_idx <= bird_list[0];
                        new_label <= {8'h64, 32'h0}; // "d"
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Memory for Tiny Owners (Sequential Array)
    reg [5:0] tiny_owner [7:0];

    // Memory for Area Sizes (Pre-calculated to save states)
    // We need to compute these during area calculation.
    // Let's add logic to State 5'd12 (Calc Area Subroutine) and 5'd16 (Walk Up) to count bits.
    // Actually, we can update size in State 5'd16 when we set a bit.
    reg [3:0] area_size_tiny [15:1];
    reg [3:0] area_size_giant [15:1];
    
    // Update area size logic within the combinational or sequential block
    // In State 5'd16 (Walk Up Loop), when we set a bit:
    // area_size_temp = area_size_temp + 1?
    // But we need to store it to `area_size_tiny[curr_idx]` at the end of calc.
    // Let's use a temporary counter `temp_counter`.
    reg [3:0] temp_counter;
    
    // Modify State 5'd12 (Calc Area Subroutine):
    // Start: temp_counter = 0.
    // Modify State 5'd16:
    // If hit: temp_counter = temp_counter + 1.
    // Modify State 5'd13 (Save Area):
    // If tiny: area_size_tiny[curr_idx] = temp_counter.
    // If giant: area_size_giant[curr_idx] = temp_counter.

    // Integrating this into the code above:
    // In CALC_AREA_TINY (State 4), when curr_idx increments:
    //   temp_counter <= 0; // Reset for next root
    // In 5'd12, when entering:
    //   (Reset temp_counter? No, we need it cumulative until 5'd13)
    //   Wait, 5'd12 runs for each other_idx.
    //   So we update temp_counter in 5'd16.
    //   When entering 5'd13 (Save Area), we use temp_counter.
    //   Then in 5'd13 (Next Bird logic), we proceed.
    //   After 5'd13 (Loop exit), we go to State 4.
    
    // Logic Update:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset temp counter
        end else begin
            if (state == CALC_AREA_TINY && curr_idx <= 16) begin
                temp_counter <= 0;
            end
            if (state == 5'd16) begin
                if (temp_idx == curr_idx) begin
                    temp_counter <= temp_counter + 1;
                end
            end
            if (state == 5'd13 && bird_idx_ptr == 0 && temp_idx == bird_list[0]) begin // First bird check? No.
                // We need to store the size ONCE after area is calculated.
                // So in 5'd13, before entering the bird loop.
                // But 5'd13 is the bird loop state.
                // We need to latch the size.
                // Let's register `area_calculated_size`.
                if (bird_idx_ptr == 0 && other_idx > 16) begin // Before loop starts
                     if (is_tiny[curr_idx]) area_size_tiny[curr_idx] <= temp_counter; // No, curr_idx is root.
                     // Wait, we are calculating area of `curr_idx` (root).
                     // This area is assigned to birds where `p_ptr` == `curr_idx`.
                     // So we store `area_size_tiny[curr_idx]` and `area_size_giant[curr_idx]`.
                     // But `curr_idx` is the root. 
                     // Tiny birds use parent area. So `area_size_tiny[p_ptr[bird]]`.
                     // Giant birds use ancestor area. So `area_size_giant[p_ptr[bird]]`.
                     // Since we modified p_ptr for giants to be the ancestor.
                     // So we just need to store `area_size[curr_idx]`.
                     
                     // Let's store `area_root_size[curr_idx]`.
                     // Then later we map: 
                     // `area_size_tiny[bird]` = `area_root_size[p_ptr[bird]]`
                     // `area_size_giant[bird]` = `area_root_size[p_ptr[bird]]`
                     // (since p_ptr modified).
                     
                     // We need to store the size now.
                     // But `temp_counter` is accumulating.
                     // When do we stop? In 5'd12 loop finish.
                     // When `other_idx` > 16, we go to 5'd13.
                     // At the start of 5'd13, we can save `temp_counter` into `area_root_size[curr_idx]`.
                end
            end
        end
    end
    
    // Helper memory for root sizes
    reg [3:0] area_root_size [15:1];
    
    // Modify State 5'd12:
    // If other_idx > 16: 
    //   area_root_size[curr_idx] <= temp_counter;
    //   bird_idx_ptr <= 0;
    //   state <= 5'd13;

    // Later, in State 5'd17 or 5'd23, we access area_size.
    // Since we can't index array with variable in combinational block inside always @(posedge)?
    // We can. 
    // In 5'd23 (Tiny Owner Eval):
    //   Use area_root_size[p_ptr[temp_idx]].
    //   (But p_ptr is modified for giants).
    
    // Wait, `p_ptr` was modified for giants to be the ancestor.
    // So for Tiny birds, `p_ptr` is the parent.
    // For Giant birds, `p_ptr` is the ancestor.
    // So `area_root_size[p_ptr[bird]]` gives the correct size.

endmodule
