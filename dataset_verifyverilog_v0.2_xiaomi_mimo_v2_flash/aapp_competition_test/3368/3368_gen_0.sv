module sanitaire(
    input clk,
    input rst_n,
    input start,
    input [7:0] enclosure_count,
    input [7:0] animal_count,
    input [7:0] correct_animal [0:3],
    input [7:0] num_animals [0:3],
    input [7:0] animal_types [0:7],
    input [7:0] enclosure_idx [0:7],
    output reg [1:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam BUILD_GRAPH = 3'b001;
    localparam CHECK_CONNECTIVITY = 3'b010;
    localparam DONE = 3'b011;

    reg [2:0] current_state, next_state;

    // Internal Registers
    reg [3:0] i_idx; // Multipurpose: Build loop, BFS finding start, Verification loop
    reg [3:0] j_idx; // Build loop (flat edges), BFS Queue Head
    reg [2:0] k_idx; // BFS Queue Tail
    reg [3:0] visited_nodes; // Bitmask
    reg [2:0] neighbor_idx; // Neighbor iterator
    
    // Queue (reusing array indices 0..3)
    reg [3:0] queue_storage [0:3];
    
    // Adjacency and Status
    reg adj [0:3][0:3];
    reg incorrect [0:3];
    reg [2:0] total_incorrect;
    
    // Temporary calculations
    reg [7:0] tmp_val1, tmp_val2;
    reg [2:0] src_node;
    reg match_found;

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 2'b0;
            done <= 1'b0;
            i_idx <= 4'b0;
            j_idx <= 4'b0;
            k_idx <= 3'b0;
            visited_nodes <= 4'b0;
            neighbor_idx <= 3'b0;
            total_incorrect <= 3'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 2'b0;
                    if (start) begin
                        i_idx <= 4'b0;
                        j_idx <= 4'b0;
                        k_idx <= 3'b0;
                        total_incorrect <= 3'b0;
                        // Clear data structures
                        // Note: For synthesis, we usually clear control flags, data is overwritten.
                        // But to be safe for this specific design where we accumulate, we assume init to 0.
                        // We explicitly clear incorrect flags here (since they are used in check).
                        incorrect[0] <= 0; incorrect[1] <= 0; incorrect[2] <= 0; incorrect[3] <= 0;
                        adj[0][0] <= 0; adj[0][1] <= 0; adj[0][2] <= 0; adj[0][3] <= 0;
                        adj[1][0] <= 0; adj[1][1] <= 0; adj[1][2] <= 0; adj[1][3] <= 0;
                        adj[2][0] <= 0; adj[2][1] <= 0; adj[2][2] <= 0; adj[2][3] <= 0;
                        adj[3][0] <= 0; adj[3][1] <= 0; adj[3][2] <= 0; adj[3][3] <= 0;
                    end
                end

                BUILD_GRAPH: begin
                    // Step 1: Mark Incorrect (i_idx < animal_count)
                    if (i_idx < animal_count) begin
                        // Check animal type vs correct animal of the enclosure it is in
                        // enclosure_idx[i_idx] is the current enclosure (0-3)
                        if (animal_types[i_idx] != correct_animal[enclosure_idx[i_idx][2:0]]) begin
                            if (!incorrect[enclosure_idx[i_idx][2:0]]) begin
                                total_incorrect <= total_incorrect + 1'b1;
                            end
                            incorrect[enclosure_idx[i_idx][2:0]] <= 1'b1;
                        end
                        i_idx <= i_idx + 1'b1;
                    end 
                    // Step 2: Build Edges (j_idx < animal_count * 4)
                    else if (j_idx < (animal_count << 2)) begin
                        // j_idx represents flat index: animal * 4 + target_enclosure
                        // Extract indices
                        // animal_idx = j_idx[4:2], target_idx = j_idx[1:0]
                        if (j_idx[4:2] < animal_count) begin
                            // Check if this animal creates an edge to target_idx
                            // Condition: animal_types[anim_idx] == correct_animal[target_idx] && enclosure_idx[anim_idx] != target_idx
                            // Use temporary signals for readability in synthesis
                            tmp_val1 <= animal_types[j_idx[4:2]];
                            tmp_val2 <= correct_animal[j_idx[1:0]];
                            src_node <= enclosure_idx[j_idx[4:2]][2:0];
                            
                            // Perform check and update adjacency in next cycle or combinational logic?
                            // Let's do it in next cycle to ensure clean timing (sequential update based on previous cycle read)
                            // Wait, reading inputs (animal_types) directly is fine.
                            
                            if ((animal_types[j_idx[4:2]] == correct_animal[j_idx[1:0]]) && 
                                (enclosure_idx[j_idx[4:2]][2:0] != j_idx[1:0])) begin
                                // Edge: src -> dst
                                case (enclosure_idx[j_idx[4:2]][2:0])
                                    3'd0: adj[0][j_idx[1:0]] <= 1'b1;
                                    3'd1: adj[1][j_idx[1:0]] <= 1'b1;
                                    3'd2: adj[2][j_idx[1:0]] <= 1'b1;
                                    3'd3: adj[3][j_idx[1:0]] <= 1'b1;
                                endcase
                            end
                        end
                        j_idx <= j_idx + 1'b1;
                    end
                end

                CHECK_CONNECTIVITY: begin
                    // If no incorrect enclosures, result FALSE_ALARM
                    if (total_incorrect == 0) begin
                        // Will transition to DONE immediately in next state logic
                    end else begin
                        // BFS Algorithm
                        // Phase A: Find start node (if queue empty)
                        if (k_idx == 0) begin // Queue empty
                            if (i_idx < 4) begin
                                if (incorrect[i_idx]) begin
                                    // Found start
                                    queue_storage[0] <= i_idx;
                                    k_idx <= 1'b1; // Tail = 1
                                    visited_nodes[i_idx] <= 1'b1;
                                    i_idx <= 4'b1000; // Mark phase shift (e.g., value 8)
                                end else begin
                                    i_idx <= i_idx + 1'b1;
                                end
                            end
                        end 
                        // Phase B: Process Queue (BFS)
                        else if (j_idx < k_idx) begin // j_idx is Head, k_idx is Tail
                            // Process queue[j_idx]
                            // Iterate neighbors 0..3
                            if (neighbor_idx < 4) begin
                                // Check adjacency: adj[queue_storage[j_idx]][neighbor_idx]
                                // Check if neighbor is incorrect and unvisited
                                reg is_adj;
                                case (queue_storage[j_idx])
                                    3'd0: is_adj = adj[0][neighbor_idx];
                                    3'd1: is_adj = adj[1][neighbor_idx];
                                    3'd2: is_adj = adj[2][neighbor_idx];
                                    3'd3: is_adj = adj[3][neighbor_idx];
                                endcase
                                
                                if (is_adj && incorrect[neighbor_idx] && !visited_nodes[neighbor_idx]) begin
                                    queue_storage[k_idx] <= neighbor_idx;
                                    k_idx <= k_idx + 1'b1;
                                    visited_nodes[neighbor_idx] <= 1'b1;
                                end
                                neighbor_idx <= neighbor_idx + 1'b1;
                            end else begin
                                // Done with neighbors of current node
                                neighbor_idx <= 3'b0;
                                j_idx <= j_idx + 1'b1; // Move head
                            end
                        end 
                        // Phase C: Verification (BFS done)
                        else begin // j_idx >= k_idx (Queue processed)
                            // Reset i_idx for verification scan (if not already reset)
                            if (i_idx == 4'b1000) i_idx <= 4'b0;
                            
                            if (i_idx < 4) begin
                                if (incorrect[i_idx] && !visited_nodes[i_idx]) begin
                                    result <= 2'b10; // IMPOSSIBLE
                                end else if (i_idx == 3 && !match_found) begin
                                    // If we haven't found a mismatch yet, it's POSSIBLE
                                    // But we need to ensure we don't overwrite IMPOSSIBLE if set earlier.
                                    // Since seq logic runs, result is updated in the same cycle.
                                    // If IMPOSSIBLE is set this cycle, it stays.
                                    if (result != 2'b10) result <= 2'b01;
                                end
                                i_idx <= i_idx + 1'b1;
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        done <= 1'b0;
                        result <= 2'b0;
                        i_idx <= 4'b0;
                        j_idx <= 4'b0;
                        k_idx <= 3'b0;
                        visited_nodes <= 4'b0;
                    end
                end
            endcase
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
            end
            BUILD_GRAPH: begin
                // Transition when both phases complete
                // Phase 1: i_idx >= animal_count
                // Phase 2: j_idx >= animal_count * 4
                if (i_idx >= animal_count && j_idx >= (animal_count << 2)) begin
                    next_state = CHECK_CONNECTIVITY;
                end
            end
            CHECK_CONNECTIVITY: begin
                // If no incorrect, fast transition
                if (total_incorrect == 0) begin
                    next_state = DONE;
                    result = 2'b00; // FALSE ALARM
                end 
                // If verification loop finished (i_idx >= 4 after reset)
                else if (j_idx >= k_idx && k_idx > 0 && i_idx >= 4) begin
                    next_state = DONE;
                    // Result is handled in sequential logic, but we might want to set it here if not set.
                    // However, sequential logic sets it. We just transition.
                end
            end
            DONE: begin
                if (start) next_state = IDLE;
            end
        endcase
    end

endmodule