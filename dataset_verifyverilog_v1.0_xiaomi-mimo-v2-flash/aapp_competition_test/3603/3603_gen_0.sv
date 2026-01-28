module translator_matcher #(
    parameter M_MAX = 200,
    parameter N_MAX = 100
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_mode,
    input wire [15:0] data_in,
    input wire data_valid,
    output reg done,
    output reg result_valid,
    output reg [15:0] match_out,
    output reg [1:0] status
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CONFIG_LOAD = 3'd1;
    localparam [2:0] COMPUTE     = 3'd2;
    localparam [2:0] OUTPUT      = 3'd3;
    localparam [2:0] DONE        = 3'd4;
    localparam [2:0] IMPOSSIBLE  = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] u, v, i, j, k; // Generic counters
    reg [7:0] m_count;       // Number of translators
    reg [7:0] match_count;
    reg [7:0] temp_node;
    reg [2:0] phase;

    // Memory declarations (BRAM-like)
    // adj_matrix: M_MAX x M_MAX bits. 
    // Packed as [200][200] -> 40000 bits. Not feasible for distributed RAM.
    // Use Sparse Adjacency: Max edges per node is M_MAX, but we will store in a small local RAM.
    // Since M <= 200, let's use 2D packed arrays.
    reg [199:0] adj_matrix [0:199]; // 200 x 200 bits
    
    // match array: stores the matched partner for each translator
    reg [7:0] match_reg [0:199]; // Stores partner ID, 255 means unmatched
    
    // visited array for DFS
    reg visited [0:199];
    
    // Stack for DFS simulation (iterative)
    reg [7:0] stack_ptr;
    reg [7:0] stack [0:255]; // Small stack for DFS path

    // Language storage to build edges
    // lang_map: stores translator ID for each language.
    // Since each language can have multiple translators, we need a list.
    // We will use a linked list approach or simple buffer.
    // For M=200, N=100, we can store first translator and next pointer.
    // lang_head[L] = first translator ID
    reg [7:0] lang_head [0:99]; // Init to 255
    reg [7:0] lang_next [0:199]; // Linked list next pointer

    // Helper signals
    reg dfs_success;
    reg [7:0] current_u;
    reg [7:0] dfs_v;
    
    // Status Encoding
    localparam [1:0] STATUS_IDLE      = 2'b00;
    localparam [1:0] STATUS_PROCESSING = 2'b01;
    localparam [1:0] STATUS_MATCH     = 2'b10;
    localparam [1:0] STATUS_IMPOSSIBLE = 2'b11;

    integer idx;

    // --- FSM Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            status <= STATUS_IDLE;
            match_out <= 16'd0;
            m_count <= 8'd0;
            match_count <= 8'd0;
            phase <= 3'd0;
            u <= 8'd0;
            v <= 8'd0;
            i <= 8'd0;
            k <= 8'd0;
            stack_ptr <= 8'd0;
            current_u <= 8'd0;
            dfs_success <= 1'b0;
            temp_node <= 8'd0;
            
            // Initialize memories
            for (idx = 0; idx < 200; idx = idx + 1) begin
                adj_matrix[idx] <= 200'd0;
                match_reg[idx] <= 8'd255;
                visited[idx] <= 1'b0;
                lang_next[idx] <= 8'd255;
            end
            for (idx = 0; idx < 100; idx = idx + 1) begin
                lang_head[idx] <= 8'd255;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    status <= STATUS_IDLE;
                    if (start) begin
                        if (config_mode) begin // If start with mode=1, go directly to compute (assumes data loaded)
                            // Reset match array for new run
                            for (idx = 0; idx < m_count; idx = idx + 1) begin
                                match_reg[idx] <= 8'd255;
                            end
                            match_count <= 8'd0;
                            u <= 8'd0;
                            state <= COMPUTE;
                            status <= STATUS_PROCESSING;
                        end else begin
                            state <= CONFIG_LOAD;
                            m_count <= 8'd0;
                            status <= STATUS_PROCESSING;
                        end
                    end
                end

                CONFIG_LOAD: begin
                    if (data_valid) begin
                        // data_in contains language ID
                        // We receive 2*M inputs. We track pairs.
                        // However, we need to know which translator is which.
                        // Sequence: T0_L0, T0_L1, T1_L0, T1_L1...
                        // Implicit counter 'i' tracks translator index.
                        // 'phase' 0 -> L0, 1 -> L1.
                        
                        if (phase == 0) begin
                            // Storing L0 for current translator 'i'
                            // Link to language list
                            lang_next[i] <= lang_head[data_in[6:0]]; // Assuming N < 128
                            lang_head[data_in[6:0]] <= i;
                            temp_node <= data_in[6:0]; // Save L0
                            phase <= 1;
                        end else begin
                            // Storing L1 for current translator 'i'
                            // Link to language list
                            lang_next[i] <= lang_head[data_in[6:0]];
                            lang_head[data_in[6:0]] <= i;
                            
                            // For L0, we already linked 'i'. Now we need to update adjacency.
                            // Iterate through translators already in L0 list (excluding i) and add edges.
                            // But we don't have the list of translators for L0 easily accessible 
                            // without scanning lang_head[L0] which might include future translators.
                            // Strategy: Build adjacency in a separate pass or use shared language logic.
                            // Hardware efficient: Just mark shared languages. 
                            // Real Graph Building happens implicitly? No, need edges.
                            // Let's use a simpler approach: Store lang pairs per translator.
                            // During compute, check shared languages.
                            // Optimization: Adjacency Matrix construction now is expensive.
                            // Let's store Lang1[T], Lang2[T] in registers for now.
                            
                            phase <= 0;
                            if (i == 199) begin
                                state <= IDLE; // Finished loading (Max M)
                                done <= 1'b1; // Signal config complete
                                m_count <= i + 1;
                            end else begin
                                i <= i + 1;
                                m_count <= i + 1;
                            end
                        end
                    end
                end

                COMPUTE: begin
                    // Matching Algorithm
                    // Standard algorithm: For each unmatched u, find augmenting path.
                    // We use an iterative DFS for path finding.
                    
                    case (phase)
                        0: begin // Check if we are done with all nodes
                            if (u >= m_count) begin
                                // All nodes processed
                                if (match_count * 2 == m_count) begin
                                    state <= OUTPUT;
                                    v <= 8'd0; // Pointer for output
                                end else begin
                                    state <= IMPOSSIBLE;
                                end
                            end else begin
                                // Check if u is already matched
                                if (match_reg[u] != 8'd255) begin
                                    u <= u + 1;
                                end else begin
                                    // Start DFS for u
                                    // Reset visited
                                    for (idx = 0; idx < m_count; idx = idx + 1) visited[idx] <= 1'b0;
                                    // Push u to stack
                                    stack[0] <= u;
                                    stack_ptr <= 1;
                                    visited[u] <= 1'b1;
                                    current_u <= u;
                                    dfs_success <= 1'b0;
                                    phase <= 1;
                                end
                            end
                        end

                        1: begin // DFS Loop
                            if (stack_ptr == 0) begin
                                // Stack empty, no path found for u
                                phase <= 0;
                                u <= u + 1;
                            end else begin
                                // Pop node (actually peek, we iterate children)
                                temp_node <= stack[stack_ptr - 1];
                                k <= 8'd0; // Neighbor iterator
                                phase <= 2;
                            end
                        end

                        2: begin // Iterate neighbors
                            // Find next unvisited neighbor compatible with temp_node
                            // To be hardware friendly, we build adjacency on the fly or store it.
                            // Since we rejected full adj_matrix, let's check shared languages.
                            // Optimization: Adjacency is symmetric. 
                            // We need a way to find neighbors of temp_node 't' that are compatible.
                            // We can pre-compute adjacency in CONFIG phase if we have enough storage.
                            // 200x200 bits = 40k bits. This is actually small for modern FPGAs (1 BRAM).
                            // Let's stick to CONFIG phase building Adjacency Matrix.
                            // We will do the build in CONFIG phase.
                            
                            // If Adjacency is built:
                            if (k >= m_count) begin
                                // No more neighbors
                                stack_ptr <= stack_ptr - 1; // Pop
                                phase <= 1;
                            end else begin
                                // Check if edge (temp_node, k) exists and k is not visited
                                // adj_matrix check
                                if (adj_matrix[temp_node][k] && !visited[k]) begin
                                    visited[k] <= 1'b1;
                                    // If k is free, we found a path
                                    if (match_reg[k] == 8'd255) begin
                                        // Success! Reconstruct path and flip
                                        // Path ends in k, connected to temp_node (which is stack top)
                                        // We need to backtrack. 
                                        // Actually, standard DFS augmenting path stores parent pointers.
                                        // Simplified: Recursive logic is hard in HW.
                                        // Let's use the standard "Hopcroft-Karp" style matching.
                                        // Or simply: Standard DFS on general graph.
                                        // 
                                        // We found an unmatched neighbor k.
                                        // We need to match temp_node to k.
                                        // But temp_node might be the child of another node in the stack.
                                        // We need to flip matches along the path.
                                        // 
                                        // Let's use the stack to trace back.
                                        // The stack contains the alternating path: u -> ... -> temp_node -> k
                                        // We need to match temp_node with k.
                                        // The node preceding temp_node in stack is its previous match.
                                        
                                        // This requires logic to flip matches backward from stack.
                                        // Let's start a "FLIP" phase.
                                        dfs_v <= k; // The new partner for temp_node
                                        dfs_success <= 1'b1;
                                        phase <= 3; // Go to Flip
                                    end else begin
                                        // k is matched, push it to stack and continue DFS
                                        stack[stack_ptr] <= k;
                                        stack_ptr <= stack_ptr + 1;
                                        phase <= 1; // Restart loop for new top
                                    end
                                end else begin
                                    k <= k + 1; // Check next neighbor
                                end
                            end
                        end

                        3: begin // Flip Matches (Backtrack)
                            // stack contains path: u ... x, y ...
                            // dfs_v is the free node we found (target).
                            // We popped 'temp_node' (which is the node connected to dfs_v) in phase 2?
                            // No, we are at the state where we found a connection.
                            // We need to process the stack.
                            // 
                            // Let's define the Flip logic carefully.
                            // We found a path: u = s[0] -> s[1] -> ... -> s[top] = temp_node -> k
                            // k is free.
                            // We want to match s[top] with k.
                            // s[top-1] is currently matched to s[top]. We need to break that.
                            // s[top-1] needs a new match. It can match to s[top-2], etc.
                            // This is the standard augmenting path flip.
                            
                            // We need to process the stack from top down.
                            // Let's use 'i' as the stack pointer for flipping.
                            // Start with dfs_v (the new end).
                            if (stack_ptr == 0) begin
                                // Only one node in path (u -> k)
                                match_reg[current_u] <= dfs_v;
                                match_reg[dfs_v] <= current_u;
                                match_count <= match_count + 1;
                                dfs_success <= 1'b0; // Reset for next
                                phase <= 0;
                                u <= u + 1;
                            end else begin
                                // stack has at least one node (temp_node)
                                // match temp_node to dfs_v
                                temp_node <= stack[stack_ptr - 1]; // Actually temp_node is stack[stack_ptr-1]
                                // We need to update match_reg for stack[stack_ptr-1] and dfs_v
                                match_reg[stack[stack_ptr - 1]] <= dfs_v;
                                match_reg[dfs_v] <= stack[stack_ptr - 1];
                                dfs_v <= stack[stack_ptr - 1]; // New target for previous node
                                stack_ptr <= stack_ptr - 1;
                                phase <= 4; // Loop
                            end
                        end

                        4: begin // Continue Flipping
                            if (stack_ptr == 0) begin
                                // Match start of path (current_u) with new dfs_v
                                match_reg[current_u] <= dfs_v;
                                match_reg[dfs_v] <= current_u;
                                match_count <= match_count + 1;
                                dfs_success <= 1'b0;
                                phase <= 0;
                                u <= u + 1;
                            end else begin
                                // Flip next pair
                                match_reg[stack[stack_ptr - 1]] <= dfs_v;
                                match_reg[dfs_v] <= stack[stack_ptr - 1];
                                dfs_v <= stack[stack_ptr - 1];
                                stack_ptr <= stack_ptr - 1;
                                // stay in phase 4
                            end
                        end
                    endcase
                end

                OUTPUT: begin
                    // Stream pairs
                    if (v >= m_count) begin
                        state <= DONE;
                        done <= 1'b1;
                        status <= STATUS_MATCH;
                    end else begin
                        if (match_reg[v] > v) begin // Output each pair once (v < partner)
                            match_out <= {v, match_reg[v]};
                            result_valid <= 1'b1;
                            v <= v + 1;
                        end else begin
                            result_valid <= 1'b0;
                            v <= v + 1;
                        end
                    end
                end

                IMPOSSIBLE: begin
                    done <= 1'b1;
                    status <= STATUS_IMPOSSIBLE;
                    state <= IDLE;
                end

                DONE: begin
                    result_valid <= 1'b0;
                    status <= STATUS_IDLE;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // --- Adjacency Matrix Construction Logic (Added to CONFIG phase) ---
            // This logic needs to run during CONFIG_LOAD.
            // If we receive data for T_i_L0, we need to link T_i to all T_j that speak L0.
            // We can do this incrementally.
            // When we finish T_i_L1, we have fully identified T_i.
            // We should update adj_matrix for T_i against all previous translators.
            // 
            // Logic: When phase returns to 0 (start of new translator) or at end of CONFIG:
            // Actually, we need to build edges for T_i based on L0 and L1.
            // This is tricky to do on the fly without storing L0/L1 per translator.
            // Let's add registers for Lang1 and Lang2 for the current translator being built.
        end
    end

    // --- Adjacency Update Logic (Combinational/Sequential Hybrid) ---
    // We need to store the languages for the current translator temporarily.
    reg [7:0] current_l0, current_l1;
    
    // Update: This part should be controlled by a separate process or within the FSM.
    // Let's refine CONFIG_LOAD state to handle adjacency building.
    // We will buffer the two languages for the current translator.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_l0 <= 8'd255;
            current_l1 <= 8'd255;
        end else begin
            if (state == CONFIG_LOAD) begin
                if (data_valid) begin
                    if (phase == 0) begin
                        // Saving L0
                        current_l0 <= data_in[6:0];
                        current_l1 <= 8'd255; // Clear L1
                    end else begin
                        // Saving L1
                        current_l1 <= data_in[6:0];
                        // Now we know T_i fully. 
                        // We can update adjacency with previous translators.
                        // This requires scanning lang_head for L0 and L1 to find matches.
                        // This scan can take many cycles. 
                        // Optimization: We can't scan 200 items every time without stalling CONFIG.
                        // 
                        // Alternative: Build Adjacency in a separate pass after CONFIG.
                        // Or use the fact that M is small (200).
                        // Let's add a SUB_STATE in CONFIG for adjacency building.
                        // When T_i_L1 is received, switch to ADJ_BUILD state.
                        
                        // NOTE: The FSM above assumes CONFIG_LOAD handles everything.
                        // We need to modify the FSM or add more phases.
                        
                        // Let's modify FSM:
                        // CONFIG_LOAD captures data.
                        // When T_i_L1 is done, we need to iterate through lang_head[L0] and lang_head[L1]
                        // and set adj_matrix[i][j] = 1 and adj_matrix[j][i] = 1.
                        // We need to do this for ALL i from 0 to M-1.
                        // 
                        // Let's change strategy:
                        // 1. CONFIG_LOAD: Just store languages in two arrays: LangBuffer0[M], LangBuffer1[M].
                        //    Also increment m_count.
                        // 2. After CONFIG (when start is pressed with config_mode=0), enter ADJ_BUILD state.
                        //    Iterate i from 0 to m_count-1.
                        //      Iterate j from 0 to i-1 (upper triangle).
                        //      Check if shared language.
                        //      If yes, set adj_matrix[i][j] and adj_matrix[j][i].
                    end
                end
            end
        end
    end

endmodule

// Separate module for language buffers to keep things clean in a real scenario,
// but here we integrate or just describe logic.
// Given the prompt constraints, we need to fit everything in one module.
// We need to fix the FSM to handle Adjacency Building.

// RE-WRITING FSM WITH ADJACENCY BUILDING

module translator_matcher_v2 #(
    parameter M_MAX = 200,
    parameter N_MAX = 100
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_mode,
    input wire [15:0] data_in,
    input wire data_valid,
    output reg done,
    output reg result_valid,
    output reg [15:0] match_out,
    output reg [1:0] status
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CONFIG_LOAD = 4'd1;
    localparam [3:0] ADJ_BUILD   = 4'd2; // New state
    localparam [3:0] COMPUTE     = 4'd3;
    localparam [3:0] OUTPUT      = 4'd4;
    localparam [3:0] DONE        = 4'd5;
    localparam [3:0] IMPOSSIBLE  = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] u, v, i, j, k;
    reg [7:0] m_count;
    reg [7:0] match_count;
    reg [2:0] phase;
    reg [1:0] status_reg;

    // Memory
    reg [199:0] adj_matrix [0:199]; 
    reg [7:0] match_reg [0:199]; 
    reg visited [0:199];
    reg [7:0] stack [0:255];
    reg [7:0] stack_ptr;
    
    // Language Buffers for Adjacency Construction
    reg [7:0] lang_buf0 [0:199]; // Lang 1 for each translator
    reg [7:0] lang_buf1 [0:199]; // Lang 2 for each translator
    
    // DFS temp vars
    reg [7:0] dfs_target;
    reg [7:0] current_node;
    reg [7:0] dfs_neighbor;

    // Status Encoding
    localparam [1:0] STATUS_IDLE      = 2'b00;
    localparam [1:0] STATUS_PROCESSING = 2'b01;
    localparam [1:0] STATUS_MATCH     = 2'b10;
    localparam [1:0] STATUS_IMPOSSIBLE = 2'b11;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            status <= STATUS_IDLE;
            match_out <= 16'd0;
            m_count <= 8'd0;
            match_count <= 8'd0;
            phase <= 3'd0;
            u <= 8'd0;
            v <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            stack_ptr <= 8'd0;
            // Init memories
            for (idx = 0; idx < 200; idx = idx + 1) begin
                adj_matrix[idx] <= 200'd0;
                match_reg[idx] <= 8'd255;
                visited[idx] <= 1'b0;
                lang_buf0[idx] <= 8'd255;
                lang_buf1[idx] <= 8'd255;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        if (config_mode) begin
                            // Run matching immediately (assuming data loaded or persistent)
                            // Reset match info
                            for (idx = 0; idx < m_count; idx = idx + 1) begin
                                match_reg[idx] <= 8'd255;
                            end
                            match_count <= 8'd0;
                            u <= 8'd0;
                            status <= STATUS_PROCESSING;
                            state <= COMPUTE;
                        end else begin
                            // Load new data
                            m_count <= 8'd0;
                            phase <= 3'd0;
                            status <= STATUS_PROCESSING;
                            state <= CONFIG_LOAD;
                        end
                    end
                end

                CONFIG_LOAD: begin
                    if (data_valid) begin
                        // Receive T0_L0, T0_L1, T1_L0, T1_L1...
                        if (phase == 0) begin
                            lang_buf0[m_count] <= data_in[7:0]; // Store L0
                            phase <= 1;
                        end else begin
                            lang_buf1[m_count] <= data_in[7:0]; // Store L1
                            phase <= 0;
                            m_count <= m_count + 1;
                        end
                    end else if (start && config_mode == 0) begin
                        // Start signal ends loading (or timeout)
                        // Transition to Adjacency Build
                        i <= 8'd0;
                        j <= 8'd0;
                        // Clear Adj Matrix (implicitly done at reset, but ensure correctness if reuse)
                        // Actually we just overwrite relevant rows.
                        state <= ADJ_BUILD;
                    end
                end

                ADJ_BUILD: begin
                    // Build adj_matrix based on lang_buf0 and lang_buf1
                    // Loop: for i in 0..m_count-1, for j in 0..i-1
                    // Check shared language
                    
                    if (i >= m_count) begin
                        // Done building
                        u <= 8'd0;
                        match_count <= 8'd0;
                        state <= COMPUTE;
                    end else if (j >= i) begin
                        // Next i
                        i <= i + 1;
                        j <= 8'd0;
                        // Reset row j pointer (not needed as j starts from 0)
                    end else begin
                        // Compare T_i and T_j
                        if ((lang_buf0[i] == lang_buf0[j]) || (lang_buf0[i] == lang_buf1[j]) ||
                            (lang_buf1[i] == lang_buf0[j]) || (lang_buf1[i] == lang_buf1[j])) begin
                            // Set bit in matrix
                            adj_matrix[i][j] <= 1'b1;
                            adj_matrix[j][i] <= 1'b1;
                        end
                        j <= j + 1;
                    end
                end

                COMPUTE: begin
                    case (phase)
                        0: begin // Check completion
                            if (u >= m_count) begin
                                if (match_count * 2 == m_count) begin
                                    state <= OUTPUT;
                                    v <= 8'd0;
                                end else begin
                                    state <= IMPOSSIBLE;
                                end
                            end else begin
                                if (match_reg[u] != 8'd255) begin
                                    u <= u + 1;
                                end else begin
                                    // Start DFS for u
                                    for (idx = 0; idx < m_count; idx = idx + 1) visited[idx] <= 1'b0;
                                    stack[0] <= u;
                                    stack_ptr <= 1;
                                    visited[u] <= 1'b1;
                                    current_node <= u;
                                    phase <= 1;
                                end
                            end
                        end

                        1: begin // DFS Loop
                            if (stack_ptr == 0) begin
                                // No augmenting path found for u
                                phase <= 0;
                                u <= u + 1;
                            end else begin
                                dfs_neighbor <= 8'd0; // Start scanning neighbors from 0
                                phase <= 2;
                            end
                        end

                        2: begin // Scan Neighbors
                            // Use stack[stack_ptr-1] as source
                            if (dfs_neighbor >= m_count) begin
                                // No valid neighbor found, pop stack
                                stack_ptr <= stack_ptr - 1;
                                phase <= 1;
                            end else begin
                                // Check edge and visited
                                if (adj_matrix[stack[stack_ptr-1]][dfs_neighbor] && !visited[dfs_neighbor]) begin
                                    visited[dfs_neighbor] <= 1'b1;
                                    if (match_reg[dfs_neighbor] == 8'd255) begin
                                        // Found free node
                                        dfs_target <= dfs_neighbor;
                                        phase <= 3; // Flip
                                    end else begin
                                        // Push matched node to stack
                                        stack[stack_ptr] <= dfs_neighbor;
                                        stack_ptr <= stack_ptr + 1;
                                        phase <= 1; // Restart search from new node
                                    end
                                end else begin
                                    dfs_neighbor <= dfs_neighbor + 1;
                                end
                            end
                        end

                        3: begin // Flip Matches
                            // Logic: 
                            // Path is in stack: s[0]...s[k-1] (top)
                            // Match s[k-1] with dfs_target (which was connected to s[k-1])
                            // Then match s[k-2] with old_match(s[k-1])? No, DFS logic.
                            // Actually, standard augmenting path:
                            // We have path u -> ... -> v (free)
                            // Stack contains u...v_parent.
                            // We need to flip edges.
                            // Iterative flip:
                            // new_partner = dfs_target
                            // for idx from stack_ptr-1 down to 0:
                            //   node = stack[idx]
                            //   old_partner = match_reg[node]
                            //   match_reg[node] = new_partner
                            //   match_reg[new_partner] = node
                            //   new_partner = old_partner
                            // 
                            // This requires knowing old_partner of the node in stack.
                            // We can read it.
                            
                            // Let's use 'i' as index for flipping.
                            // i starts at stack_ptr-1
                            i <= stack_ptr - 1;
                            dfs_target <= dfs_target; // This is the partner for stack[stack_ptr-1]
                            phase <= 4;
                        end

                        4: begin // Perform Flipping
                            if (i == 8'd255) begin // Check underflow or loop end
                                // Done flipping
                                match_count <= match_count + 1;
                                phase <= 0;
                                u <= u + 1;
                            end else begin
                                temp_node <= stack[i]; // The node to re-match
                                // Match stack[i] with dfs_target
                                match_reg[stack[i]] <= dfs_target;
                                match_reg[dfs_target] <= stack[i];
                                // Prepare for next iteration
                                // The next target is the OLD partner of stack[i]
                                // But we just overwrote match_reg[stack[i]], so we can't read it.
                                // We need to store the OLD partner before overwriting.
                                // 
                                // Correction for Flip:
                                // The standard recursion is:
                                // match(u, v) {
                                //    old_match_v = match[v];
                                //    match[v] = u;
                                //    match[u] = v;
                                //    if (old_match_v != -1) match(u', old_match_v); // u' is parent of u
                                // }
                                // 
                                // Stack structure:
                                // u (root) -> x (child) -> y (child) -> ... -> z (last matched) -> v (free)
                                // We found v connected to z.
                                // match(z, v).  Parent of z is y.
                                // match(y, old_match(z)). Parent of y is x.
                                // ...
                                
                                // We need to read match_reg[stack[i]] BEFORE overwriting.
                                // Let's read it into a temp register.
                                dfs_neighbor <= match_reg[stack[i]]; // This is the OLD partner
                                
                                match_reg[stack[i]] <= dfs_target;
                                match_reg[dfs_target] <= stack[i];
                                
                                dfs_target <= dfs_neighbor; // The old partner becomes the new target for the parent
                                
                                if (i == 0) begin
                                    // We matched the root u (stack[0])
                                    // Note: stack[0] is always u. 
                                    // If i==0, we are done. The chain is closed.
                                    match_count <= match_count + 1;
                                    phase <= 0;
                                    u <= u + 1;
                                end else begin
                                    i <= i - 1;
                                end
                            end
                        end
                    endcase
                end

                OUTPUT: begin
                    if (v >= m_count) begin
                        state <= DONE;
                        done <= 1'b1;
                        status <= STATUS_MATCH;
                    end else begin
                        if (match_reg[v] > v) begin
                            match_out <= {v, match_reg[v]};
                            result_valid <= 1'b1;
                            v <= v + 1;
                        end else begin
                            result_valid <= 1'b0;
                            v <= v + 1;
                        end
                    end
                end

                IMPOSSIBLE: begin
                    done <= 1'b1;
                    status <= STATUS_IMPOSSIBLE;
                    state <= IDLE;
                end

                DONE: begin
                    result_valid <= 1'b0;
                    status <= STATUS_IDLE;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule