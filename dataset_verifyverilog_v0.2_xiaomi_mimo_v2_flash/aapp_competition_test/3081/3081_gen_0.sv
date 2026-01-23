module airline_scheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [1:0] m,
    input wire [15:0] inspection_times [0:3],
    input wire [15:0] flight_times [0:3][0:3],
    input wire [15:0] flight_reqs [0:3][3], // 0: source, 1: dest, 2: depart_time
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_DATA = 3'b001;
    localparam CHECK_ADJ = 3'b010;
    localparam FIND_COMPONENTS = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Internal Registers for data storage (aligned to inputs)
    reg [15:0] int_inspection_times [0:3];
    reg [15:0] int_flight_times [0:3][0:3];
    reg [15:0] int_flight_reqs [0:3][3]; // 0: source, 1: dest, 2: depart_time
    reg [1:0] int_m;
    reg [1:0] int_n;

    // Adjacency Matrix (4x4 max)
    reg adj [0:3][0:3];

    // Component Logic Registers
    reg visited [0:3];
    reg [1:0] i_idx; // Outer loop index for component counting
    reg [1:0] j_idx; // Inner loop index for DFS traversal
    reg [2:0] temp_comp_count;
    
    // Temp variables for calculation
    reg [15:0] arrival_time;
    reg [15:0] flight_i_depart;
    reg [15:0] flight_i_dest_idx;
    reg [15:0] flight_j_source_idx;
    reg [15:0] flight_j_depart;
    
    // Control counters
    reg [1:0] pair_i;
    reg [1:0] pair_j;
    reg [1:0] copy_idx;
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= LOAD_DATA;
                end
                
                LOAD_DATA: begin
                    // Transfer inputs to internal regs in one cycle (m, n are small)
                    int_m <= m;
                    int_n <= n;
                    copy_idx <= 2'b00;
                    state <= CHECK_ADJ;
                    // Reset adjacency and visited
                    pair_i <= 2'b00;
                    pair_j <= 2'b00;
                    i_idx <= 2'b00;
                    temp_comp_count <= 3'b000;
                end
                
                CHECK_ADJ: begin
                    // Loop structure: pair_i from 0 to m-1, pair_j from 0 to m-1
                    if (pair_i < int_m && pair_j < int_m) begin
                        // Perform Compatibility Check
                        flight_i_depart <= int_flight_reqs[pair_i][2];
                        flight_i_dest_idx <= int_flight_reqs[pair_i][1]; // destination of flight i
                        flight_j_source_idx <= int_flight_reqs[pair_j][0]; // source of flight j
                        flight_j_depart <= int_flight_reqs[pair_j][2];
                        
                        // Calculation: arrival_time = depart_i + flight_time(i_dest, j_source) + inspection(j_source)
                        // We need to ensure indices are valid for the array access
                        arrival_time <= int_flight_reqs[pair_i][2] +
                                       int_flight_times[ int_flight_reqs[pair_i][1] ][ int_flight_reqs[pair_j][0] ] +
                                       int_inspection_times[ int_flight_reqs[pair_j][0] ];
                        
                        // Advance Indices
                        if (pair_j == int_m - 1) begin
                            pair_j <= 0;
                            pair_i <= pair_i + 1;
                        end else begin
                            pair_j <= pair_j + 1;
                        end

                        // Check Condition (Logic split to avoid combinational loop in single cycle description)
                        // If comparison holds, set adj bit. Note: if i==j, usually 0 unless specified, we allow but distance might be large.
                    end else begin
                        // Finished Adjacency
                        state <= FIND_COMPONENTS;
                        i_idx <= 0;
                        temp_comp_count <= 0;
                    end
                end

                FIND_COMPONENTS: begin
                    // Step 1: Reset visited if just entering (or use LOAD_DATA to reset, here we maintain state)
                    // Actually, we need to find unvisited nodes and traverse.
                    if (i_idx < int_m) begin
                        if (!visited[i_idx]) begin
                            // Found unvisited node, this is a new component
                            visited[i_idx] <= 1'b1;
                            temp_comp_count <= temp_comp_count + 1;
                            j_idx <= 0; // Start DFS from this node
                            // We need to process reachability. 
                            // Since graph is small, we can do a simple iterative DFS in subsequent cycles.
                            // But we need a sub-state or we just loop. Let's use a flag to indicate we are currently DFS-ing.
                            // However, standard FSM suggests sequential states. 
                            // Let's continue to next state or loop here.
                            // To keep it simple: Just increment i_idx here and rely on adjacency?
                            // No, we need to mark all reachable nodes.
                            // Let's use a sub-loop for DFS.
                        end else begin
                            i_idx <= i_idx + 1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= temp_comp_count;
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset or stay done
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Logic for DFS Traversal inside FIND_COMPONENTS state
    // Since the problem asks for a "DFS-like logic" and we are limited by the "single always block" nature for synthesis,
    // we can expand the state logic or use separate combinational blocks.
    // Let's use a separate always block to handle the DFS traversal triggered by state.
    // However, to strictly adhere to the sequential description, we will expand the state machine logic above to handle traversal.
    // The above logic only marks the start node. We need to traverse edges.
    // Correction: A robust solution needs a stack or iterative traversal. 
    // Given "Sequential Verilog" and "Limited depth", we will implement an iterative DFS using the clock.
    
    // Internal DFS Stack/Queue Registers (Max 4 nodes)
    reg [1:0] stack [0:3];
    reg [1:0] stack_ptr;
    reg processing_dfs;

    // Adjusted logic for FIND_COMPONENTS to handle DFS traversal
    // We will replace the FIND_COMPONENTS state logic in the sequential block conceptually.
    // But since I can only output one block, let's put everything in the single sequential block.
    
    // Re-implementation of the main FSM to include DFS fully:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= LOAD_DATA;
                end

                LOAD_DATA: begin
                    // Copy data
                    int_m <= m;
                    int_n <= n;
                    // Reset Adjacency Matrix
                    adj[0][0] <= 0; adj[0][1] <= 0; adj[0][2] <= 0; adj[0][3] <= 0;
                    adj[1][0] <= 0; adj[1][1] <= 0; adj[1][2] <= 0; adj[1][3] <= 0;
                    adj[2][0] <= 0; adj[2][1] <= 0; adj[2][2] <= 0; adj[2][3] <= 0;
                    adj[3][0] <= 0; adj[3][1] <= 0; adj[3][2] <= 0; adj[3][3] <= 0;
                    // Copy arrays (simple unrolled loops for synthesis)
                    inspection_times[0] <= inspection_times[0]; inspection_times[1] <= inspection_times[1];
                    inspection_times[2] <= inspection_times[2]; inspection_times[3] <= inspection_times[3];
                    flight_times[0][0] <= flight_times[0][0]; flight_times[0][1] <= flight_times[0][1];
                    flight_times[0][2] <= flight_times[0][2]; flight_times[0][3] <= flight_times[0][3];
                    flight_times[1][0] <= flight_times[1][0]; flight_times[1][1] <= flight_times[1][1];
                    flight_times[1][2] <= flight_times[1][2]; flight_times[1][3] <= flight_times[1][3];
                    flight_times[2][0] <= flight_times[2][0]; flight_times[2][1] <= flight_times[2][1];
                    flight_times[2][2] <= flight_times[2][2]; flight_times[2][3] <= flight_times[2][3];
                    flight_times[3][0] <= flight_times[3][0]; flight_times[3][1] <= flight_times[3][1];
                    flight_times[3][2] <= flight_times[3][2]; flight_times[3][3] <= flight_times[3][3];
                    flight_reqs[0][0] <= flight_reqs[0][0]; flight_reqs[0][1] <= flight_reqs[0][1]; flight_reqs[0][2] <= flight_reqs[0][2];
                    flight_reqs[1][0] <= flight_reqs[1][0]; flight_reqs[1][1] <= flight_reqs[1][1]; flight_reqs[1][2] <= flight_reqs[1][2];
                    flight_reqs[2][0] <= flight_reqs[2][0]; flight_reqs[2][1] <= flight_reqs[2][1]; flight_reqs[2][2] <= flight_reqs[2][2];
                    flight_reqs[3][0] <= flight_reqs[3][0]; flight_reqs[3][1] <= flight_reqs[3][1]; flight_reqs[3][2] <= flight_reqs[3][2];
                    
                    // Reset Visited
                    visited[0] <= 0; visited[1] <= 0; visited[2] <= 0; visited[3] <= 0;
                    
                    // Initialize Adjacency Calc
                    pair_i <= 0;
                    pair_j <= 0;
                    state <= CHECK_ADJ;
                end

                CHECK_ADJ: begin
                    if (pair_i < int_m && pair_j < int_m) begin
                        // Calculate Arrival Time
                        arrival_time <= flight_reqs[pair_i][2] +
                                       flight_times[flight_reqs[pair_i][1]][flight_reqs[pair_j][0]] +
                                       inspection_times[flight_reqs[pair_j][0]];
                        
                        // We need to check the condition in the NEXT cycle to use the calculated arrival_time
                        // Or do it combinationally. Let's do it combinationally below and store in the register.
                        // Actually, to keep it purely sequential without complex combo logic, we calculate and set in next cycle.
                        // But for single-cycle update, we can use a temporary wire.
                        
                        // Let's use a helper wire for the condition
                        // Wire definition below:
                        wire can_transition = (flight_reqs[pair_i][2] +
                                             flight_times[flight_reqs[pair_i][1]][flight_reqs[pair_j][0]] +
                                             inspection_times[flight_reqs[pair_j][0]]) <= flight_reqs[pair_j][2];

                        // Update adjacency
                        // Special case: we don't need adjacency to the same flight usually, but problem doesn't forbid it.
                        // We set adj[pair_i][pair_j] if valid
                        if (can_transition) 
                            adj[pair_i][pair_j] <= 1'b1;
                        else 
                            adj[pair_i][pair_j] <= 1'b0;

                        // Increment indices
                        if (pair_j == int_m - 1) begin
                            pair_j <= 0;
                            pair_i <= pair_i + 1;
                        end else begin
                            pair_j <= pair_j + 1;
                        end
                    end else begin
                        // Done with Adjacency
                        state <= FIND_COMPONENTS;
                        i_idx <= 0;
                        result <= 0;
                        // Reset visited for DFS (already reset in LOAD_DATA)
                    end
                end

                FIND_COMPONENTS: begin
                    // DFS Iteration Logic
                    // We iterate through nodes. If unvisited, mark it, increment result, and traverse all reachable nodes.
                    
                    // Optimization: Since m <= 4, we can do this in a few cycles.
                    // Cycle 1: Find unvisited node (i_idx loop)
                    // Cycle 2-N: Traverse its neighbors (j_idx loop)
                    
                    // We implement a simplified iterative DFS without stack to save area/latency.
                    // Since we only need to count components, we can just flood fill.
                    
                    if (i_idx < int_m) begin
                        if (!visited[i_idx]) begin
                            // Found component root
                            visited[i_idx] <= 1'b1;
                            result <= result + 1;
                            // Now start traversal from i_idx
                            // We will use j_idx to scan neighbors of current active node set
                            // We need to find all nodes reachable from i_idx.
                            // Since graph is small, we can just check all pairs (u, v) where u is visited in this component and v is not.
                            // Let's use a "flood fill" approach.
                            
                            // To implement flood fill in one cycle per edge is too slow.
                            // Let's add a sub-state or just re-evaluate.
                            // Given latency constraint "~100 cycles", we have plenty of time.
                            
                            // We will use a loop to expand the visited set for this component.
                            // We need a flag to say "currently expanding component".
                            // Let's add a state FIND_REACHABLE.
                            state <= 3'b101; // FIND_REACHABLE custom state
                            j_idx <= 0; // Neighbor iterator
                        end else begin
                            i_idx <= i_idx + 1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                3'b101: begin // FIND_REACHABLE (Flood fill step)
                    // We iterate through all flights. If a flight is visited (in current component) 
                    // AND another flight is NOT visited AND adj[visited][unvisited] is 1, mark the unvisited one.
                    // Since we can't do nested loops easily, we iterate pair_i for visited check, pair_j for target.
                    
                    // Logic: Check if adj[j_idx][pair_i] is 1 AND visited[j_idx] is 1 AND visited[pair_i] is 0.
                    // Wait, simpler: Iterate through all pairs (u, v). If visited[u] and adj[u][v] and !visited[v], set visited[v]=1.
                    // We do this in a series of cycles. Max 16 cycles for 4x4.
                    
                    // Cycle counter logic implicit in pair_i/pair_j
                    // We need to ensure this loop runs until no new nodes are added.
                    // For "limited depth" (as per prompt), we can just run the scan once or twice.
                    // Or better: just check all unvisited nodes against all visited nodes.
                    // Since graph is small, let's do: Scan all unvisited nodes. If any has an incoming edge from visited set, add it.
                    
                    // Let's define a sub-step: 
                    // Step A: Check if any new node can be added.
                    // Step B: If yes, add it and repeat Step A. If no, go back to FIND_COMPONENTS.
                    
                    // Let's use j_idx as the "unvisited node" we are checking.
                    // And i_idx as the "source" (already visited in this component).
                    
                    // Correction: It's cleaner to just add a new state EXTEND_COMPONENT
                    state <= 3'b110; // EXTEND_COMPONENT
                    j_idx <= 0; // Target node to check
                end

                3'b110: begin // EXTEND_COMPONENT
                    // Check if flight j_idx is unvisited, and if it is reachable from any visited flight (including those just added)
                    if (j_idx < int_m) begin
                        if (!visited[j_idx]) begin
                            // Check reachability from any k where visited[k] is 1
                            // We need a temporary register to store if reachable. Or check sequentially.
                            // Let's use a flag.
                            // Since we are in clocked logic, we check specific pairs.
                            // We'll iterate through 'k' (0 to 3) to see if adj[k][j_idx] && visited[k]
                            // Let's add a sub-state CHECK_REACH
                            // But to save states, we can just do it here if we assume we can check 4 items in one cycle (combinational check)
                            
                            wire reachable = (adj[0][j_idx] && visited[0]) ||
                                            (adj[1][j_idx] && visited[1]) ||
                                            (adj[2][j_idx] && visited[2]) ||
                                            (adj[3][j_idx] && visited[3]);
                            
                            if (reachable) begin
                                visited[j_idx] <= 1'b1;
                                // Need to repeat scan because new node might reach others
                                // We will reset j_idx to 0 and loop again? No, that creates infinite loop risk without flag.
                                // Instead, we just mark it, and assume the outer loop (FIND_COMPONENTS) handles the rest 
                                // OR we loop EXTEND_COMPONENT until no change.
                                // Let's set a flag 'change_detected' and loop back to EXTEND_COMPONENT (j_idx=0).
                                j_idx <= 0; // Restart scan for new connections
                            end else begin
                                j_idx <= j_idx + 1;
                            end
                        end else begin
                            j_idx <= j_idx + 1;
                        end
                    end else begin
                        // Scanned all nodes, no change (or we finished a pass).
                        // We should verify if any nodes were added in this pass. 
                        // If we added a node, we should restart the scan (j_idx=0) to catch transitive connections.
                        // But without a flag, how do we know? 
                        // Simple heuristic for "limited depth": Run the scan twice (max 2 hops).
                        // Or, we can check if we added a node in the last cycle. 
                        // Let's use a 'modified' flag. Since we can't easily do that in one line, 
                        // we will just assume one pass is enough for "limited depth" or run 2 passes.
                        // Let's go back to FIND_COMPONENTS to continue the outer loop.
                        // Wait, if we found a component, we need to mark all reachable nodes BEFORE incrementing i_idx.
                        
                        // Let's go to a state that verifies completion.
                        state <= 3'b111; // CHECK_IF_MORE
                    end
                end
                
                3'b111: begin // CHECK_IF_MORE
                    // Here we can verify if we need to extend further.
                    // Check if any unvisited node is reachable from visited set.
                    // If yes, go back to EXTEND_COMPONENT.
                    // If no, go back to FIND_COMPONENTS.
                    wire has_unreachable =
                        (!visited[0] && ((adj[0][0] && visited[0]) || (adj[1][0] && visited[1]) || (adj[2][0] && visited[2]) || (adj[3][0] && visited[3]))) ||
                        (!visited[1] && ((adj[0][1] && visited[0]) || (adj[1][1] && visited[1]) || (adj[2][1] && visited[2]) || (adj[3][1] && visited[3]))) ||
                        (!visited[2] && ((adj[0][2] && visited[0]) || (adj[1][2] && visited[1]) || (adj[2][2] && visited[2]) || (adj[3][2] && visited[3]))) ||
                        (!visited[3] && ((adj[0][3] && visited[0]) || (adj[1][3] && visited[1]) || (adj[2][3] && visited[2]) || (adj[3][3] && visited[3])));
                    
                    if (has_unreachable) begin
                        state <= 3'b110; // Go back to EXTEND_COMPONENT
                        j_idx <= 0;
                    end else begin
                        state <= FIND_COMPONENTS; // Done with this component
                        i_idx <= i_idx + 1; // Move to next potential root
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule