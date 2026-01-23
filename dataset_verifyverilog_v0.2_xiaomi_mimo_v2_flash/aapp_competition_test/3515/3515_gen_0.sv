module chile_shortest_path(
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_nodes,
    input [15:0] y_coords [0:7],
    input [15:0] d_mins [0:7],
    input [15:0] r_times [0:7],
    output reg [15:0] dist [0:7],
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam SELECT_MIN = 3'b001;
    localparam UPDATE_NEIGHBORS = 3'b010;
    localparam CHECK_COMPLETION = 3'b011;
    localparam FINISHED = 3'b100;

    // Registers and Wires
    reg [2:0] state, next_state;
    reg [15:0] dist_reg [0:7];     // Main distance storage
    reg visited [0:7];             // Visited flags
    reg [2:0] u;                   // Current node index
    reg [2:0] v;                   // Neighbor node index
    reg [15:0] min_dist;
    reg [2:0] min_idx;
    reg update_in_progress;
    reg [2:0] iteration_count;     // To limit to 8 iterations
    
    // Computation variables
    reg [15:0] y_u, y_v, d_u, r_u;
    reg signed [16:0] y_diff;     // Signed for absolute value calculation
    reg [15:0] abs_y_diff;
    reg [31:0] calc_dist;          // Extended width for addition
    reg [15:0] weight;
    
    // Output assignment
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            dist[i] = dist_reg[i];
        end
    end

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
                if (start)
                    next_state = SELECT_MIN;
                else
                    next_state = IDLE;
            end
            SELECT_MIN: begin
                // Transition immediately, logic handled in sequential block
                next_state = UPDATE_NEIGHBORS;
            end
            UPDATE_NEIGHBORS: begin
                // Wait for loop to finish (v goes 0->7)
                // Since we are in sequential block, we can count v in the block
                // We assume it takes 8 cycles or we check a flag. 
                // To make it flow nicely: We check if v reached end.
                // But v is updated in sequential block. 
                // Let's use a flag 'update_done' or simply check v in next cycle logic.
                // Better approach: Count v in sequential block, transition when v wraps around.
                // Since we are in combinational next_state, we rely on update_in_progress.
                // Actually, we can just transition to CHECK_COMPLETION when update_in_progress is low.
                // But we need to generate update_in_progress in the state block.
                // Let's stick to a fixed cycle count for robustness or edge detection.
                // Let's assume 8 cycles for v (0 to 7).
                next_state = UPDATE_NEIGHBORS; // Default loop
                if (v == 3'd7) next_state = CHECK_COMPLETION;
            end
            CHECK_COMPLETION: begin
                // Need 1 cycle to check flags and determine next state
                next_state = SELECT_MIN; // Assume loop unless finished
                if (iteration_count == 3'd7 || !valid_nodes[u]) // Should find next min, or stop if no valid nodes left
                    next_state = SELECT_MIN; 
                // Better stop condition: if we have visited all valid nodes or found no valid unvisited nodes.
                // Since max iterations is 8, we just check iteration count or found node validity.
                // Let's follow instruction: "Runs for a fixed maximum of 8 iterations".
                // If in SELECT_MIN we don't find a valid unvisited node, we go to FINISHED.
                if (iteration_count >= 3'd7 || (min_idx == 3'hF && !valid_nodes[0])) // Custom logic needed here
                     next_state = FINISHED;
                // Actually, let's just do 8 iterations total to be safe.
                if (iteration_count == 3'd7)
                    next_state = FINISHED;
                else
                    next_state = SELECT_MIN; 
            end
            FINISHED: begin
                if (!start) next_state = IDLE; // Wait for start to go low to reset
                else next_state = FINISHED;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main Logic (Datapath & Control)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            iteration_count <= 3'd0;
            v <= 3'd0;
            update_in_progress <= 1'b0;
            // Reset distance and visited
            for (int i = 0; i < 8; i++) begin
                dist_reg[i] <= 16'hFFFF;
                visited[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize
                        // Initialize logic inside next state block or here? 
                        // "The module initializes distance to city 0 (city 1 in problem) to 0"
                        dist_reg[0] <= 16'd0; // City 1 is index 0
                        for (int i = 1; i < 8; i++) begin
                            dist_reg[i] <= 16'hFFFF;
                        end
                        // Note: We should keep 'visited' clear. 
                        for (int k = 0; k < 8; k++) visited[k] <= 1'b0;
                        iteration_count <= 3'd0;
                    end
                end

                SELECT_MIN: begin
                    // Logic to find unvisited node with smallest distance
                    // Runs in 1 cycle for simplicity (or unrolled loop)
                    // Since N=8, we can do this in a combinational way or sequential.
                    // To keep state count low, we will do a priority check or rely on a comparator tree.
                    // Here, we do a sequential search in 1 cycle using priority logic or just one iteration.
                    // Actually, with 8 nodes, we can hardcode a priority chain or assume logic propagation.
                    // To be robust and synthesizeable without complex combinational loops:
                    // We will search sequentially in 1 cycle by unrolling or just accept the combinational delay.
                    // Given the cycle budget is generous, let's just set up variables and let the combinational logic pick.
                    // Wait, 'min_dist' and 'min_idx' need to be stable for the update.
                    // Let's find the min in the combinational block driving these registers.
                    // Or, do it here explicitly:
                    min_dist <= 16'hFFFF;
                    min_idx <= 3'hF;
                    
                    // We need to loop 0 to 7. Since we are in a single state transition, we must unroll or use sub-states.
                    // Alternatively, we use a combinational block to find min, and register it here.
                    // Let's rely on a combinational 'find_min' block that updates min_idx/min_dist.
                    // We need to ensure the combinational logic is valid before we latch in UPDATE_NEIGHBORS.
                    // Actually, we can just check against all nodes here (unrolled logic) is hard in Verilog without loops generating logic.
                    // Let's do it carefully: We will just set a flag to perform the update in UPDATE_NEIGHBORS state.
                    // No, we need the 'u' selected. Let's do the selection in SELECT_MIN state.
                    
                    // Manual selection logic (combinational inside always block):
                    if (valid_nodes[0] && !visited[0] && dist_reg[0] < min_dist) begin min_dist <= dist_reg[0]; min_idx <= 0; end
                    if (valid_nodes[1] && !visited[1] && dist_reg[1] < min_dist) begin min_dist <= dist_reg[1]; min_idx <= 1; end
                    if (valid_nodes[2] && !visited[2] && dist_reg[2] < min_dist) begin min_dist <= dist_reg[2]; min_idx <= 2; end
                    if (valid_nodes[3] && !visited[3] && dist_reg[3] < min_dist) begin min_dist <= dist_reg[3]; min_idx <= 3; end
                    if (valid_nodes[4] && !visited[4] && dist_reg[4] < min_dist) begin min_dist <= dist_reg[4]; min_idx <= 4; end
                    if (valid_nodes[5] && !visited[5] && dist_reg[5] < min_dist) begin min_dist <= dist_reg[5]; min_idx <= 5; end
                    if (valid_nodes[6] && !visited[6] && dist_reg[6] < min_dist) begin min_dist <= dist_reg[6]; min_idx <= 6; end
                    if (valid_nodes[7] && !visited[7] && dist_reg[7] < min_dist) begin min_dist <= dist_reg[7]; min_idx <= 7; end
                    
                    // Initialize neighbor index
                    v <= 3'd0;
                end

                UPDATE_NEIGHBORS: begin
                    // Process v, then increment v
                    // If we found a valid min node (u) in previous step
                    if (min_idx != 3'hF) begin
                        // Fetch data for u
                        // Note: Reading arrays with non-constant index usually requires combinational logic or async read RAM.
                        // In Verilog, this creates latches or MUXes. 
                        // We assume y_coords, d_mins, r_times are inputs (regs) or wires.
                        // We need to read them based on u (min_idx from previous cycle).
                        // Actually, u (min_idx) is registered in SELECT_MIN. 
                        // So we use u = min_idx.
                        // But min_idx was updated in SELECT_MIN. Let's register u.
                        // Wait, if I update u in SELECT_MIN, it's available for UPDATE_NEIGHBORS.
                        // However, I need to ensure 'u' is stable. Let's register u in SELECT_MIN.
                        
                        // Let's re-organize: In SELECT_MIN, we register u = min_idx.
                        // In UPDATE_NEIGHBORS, we use that u.
                        
                        // Wait, in the code above, I used 'min_idx' directly. 
                        // Let's register 'u' properly.
                        // Actually, since I'm in UPDATE_NEIGHBORS now, 'min_idx' from previous cycle is 'u' (if I register it).
                        // Let's assume 'u' is registered in the previous state transition.
                        // To fix: I need an explicit 'u_reg'.
                        
                        // Let's assume I add 'reg [2:0] u_reg'.
                        // In SELECT_MIN state: u_reg <= min_idx.
                        // Here: use u_reg.
                        
                        // Let's do the calculation for 'v' (current neighbor).
                        // This block executes for every v (0 to 7) over cycles because state stays UPDATE_NEIGHBORS.
                        // So we need to process v, then v++, etc.
                        // Since I'm in a sequential block, I can update v.
                        
                        // Data fetches (Async read style)
                        y_u <= y_coords[u_reg];
                        y_v <= y_coords[v];
                        d_u <= d_mins[u_reg];
                        r_u <= r_times[u_reg];
                        
                        // Perform calculation (Pipeline it 1 cycle? Or combinational? 
                        // Let's do combinational for distance update logic in next cycle or inside this cycle if timing allows.
                        // To be safe and standard, let's use 1 cycle for calculation and update.
                        // But we need to iterate v. 
                        // Let's break it: Cycle 1: Read inputs. Cycle 2: Update dist.
                        // Since we need 8 cycles for 8 neighbors, and latency is 100-200, this fits.
                        // So we need a 2-stage inside UPDATE_NEIGHBORS or just rely on 'calc_dist' being ready in next cycle.
                        
                        // Actually, let's use a flag 'data_read_done' to advance state.
                        // But to save states, let's just use the fact that inputs are available next cycle.
                        // Wait, if we are in UPDATE_NEIGHBORS, we are iterating 'v'.
                        // We should wait for 'v' loop to finish.
                        // Let's do: 
                        // 1. In UPDATE_NEIGHBORS: Calculate weight and new distance (combinational)
                        // 2. Update dist_reg if condition met (clocked)
                        // 3. Increment v.
                        
                        // Calculation:
                        y_diff <= $signed({1'b0, y_coords[u_reg]}) - $signed({1'b0, y_coords[v]}); // This reads inputs directly to avoid 1 cycle delay for logic
                        // Better: Read inputs directly in combinational logic outside the FSM, or inside block.
                        // Let's read inputs directly inside the block using current indices.
                        
                        y_diff <= $signed(y_coords[u_reg]) - $signed(y_coords[v]);
                    end
                    
                    // Increment v for next iteration (or handle logic to move to next state)
                    // Wait, we need to process v before incrementing.
                    // Since this is sequential block, we update v at the end of the cycle.
                    // We need to check condition 'abs(y_diff) >= d_mins[u_reg]'.
                    // Then calc new_dist.
                    
                    // Let's process the update logic here (combinational assignment to a wire, then clocked update)
                    // or do it in the clocked block with intermediate registers.
                    
                    // Let's do: 
                    // Calculate abs_y_diff combinational (outside or wire).
                    // Let's assume we do:
                    // abs_y_diff = (y_diff[16]) ? -y_diff : y_diff; (careful with width)
                    // Actually, let's just use a combinational block for helper signals or do it in the cycle.
                    
                    // Let's simplify: Update dist_reg based on v from PREVIOUS cycle.
                    // But we need to handle v=0 first.
                    
                    // Let's define helper wires for readability in the response:
                    // (Implied that synthesis tool handles combinational logic)
                    
                    // We will handle the update in the SAME cycle we read data, assuming inputs are valid.
                    // Then increment v.
                    // For v=0, we need to use data read from inputs (which should be static or read by index).
                    
                    // Actually, since this is a sequential block, we can just calculate for current 'v'.
                    // But calculation takes time. 
                    // Given the latency allowance, let's make UPDATE_NEIGHBORS state take 2 cycles per neighbor? No, too slow.
                    // Let's make UPDATE_NEIGHBORS a state that takes 8 cycles total.
                    // In each cycle, we process one v.
                    // But we need to evaluate condition. 
                    // Let's assume inputs y_coords etc are stored in registers (implied by 'input reg').
                    // So reading them is instantaneous.
                    
                    // Implementation:
                    // 1. Calculate abs_diff and check condition.
                    // 2. If valid, update dist_reg[v] = min(dist_reg[v], dist_reg[u] + r_times[u] + abs_diff).
                    // 3. Increment v.
                    
                    // Note: Writing to dist_reg[v] while reading dist_reg[u] is fine if u != v (which is true usually, but we should skip if u==v).
                    // Edge case: u==v? 
                    // Dijkstra usually relaxes edges u->v. If v==u, weight is 0, distance doesn't change. We can skip.
                    
                    // Let's calculate condition and new value:
                    // We need a register to hold the calculated potential distance for v.
                    // Let's call it 'potential_dist'.
                    // We'll calculate it combinational based on current v and registered u.
                    // Since inputs are regs, we can do it inside the sequential block by using current values.
                    // Wait, if we use <= blocking assignments inside always @(posedge), it's sequential.
                    // We need to calculate in the combinational flow before the clock edge.
                    // So we assign 'potential_dist' inside the block, but since it's clocked, it will be delayed.
                    // To avoid delay, we need to drive dist_reg update directly.
                    
                    // Let's structure UPDATE_NEIGHBORS to simply iterate v.
                    // We need to check: if (abs(y_coords[u_reg] - y_coords[v]) >= d_mins[u_reg]) update.
                    // Then v++.
                    
                    // We can do: 
                    // wire [15:0] diff = (y_coords[u_reg] > y_coords[v]) ? (y_coords[u_reg] - y_coords[v]) : (y_coords[v] - y_coords[u_reg]);
                    // wire condition = (diff >= d_mins[u_reg]);
                    // wire [31:0] new_val = dist_reg[u_reg] + r_times[u_reg] + diff;
                    // if (condition && (new_val < dist_reg[v])) dist_reg[v] <= new_val;
                    
                    // But we must ensure we don't overflow 16 bits. Instruction implies 16-bit width for dist.
                    // We clip to 0xFFFF? Or just assume it fits. Let's clamp to 0xFFFF.
                    // If new_val > 16'hFFFF, we treat it as unreachable? No, just store lower 16.
                    // "Outputs updated distances... 0xFFFF if unreachable". 
                    // Unreachable means no path. 
                    // If the calculated distance exceeds 16'hFFFF, it's effectively unreachable or we saturate.
                    // Let's saturate at 0xFFFF.
                    
                    // Execution:
                    // We are in UPDATE_NEIGHBORS. We process 'v'.
                    // To make sure we process v=0, v=1... in sequence:
                    // We will use the combinational logic inside the always block (which is triggered by inputs).
                    // But 'v' is a register. 
                    // So we need to sample 'v' at the start of the cycle, calculate, update, then update v for next cycle.
                    
                    // However, 'v' updates at the end of the always block.
                    // So for cycle 1: v=0. Cycle 2: v=1.
                    // This works.
                    
                    // Let's calculate 'diff', 'cond', 'new_val' based on current 'v' and 'u_reg'.
                    // We do this calculation every cycle in UPDATE_NEIGHBORS.
                    // Since we are in a clocked block, we can't just use combinational flow easily unless we drive wires.
                    // Let's use temporary variables calculated inside the block (blocking assignment style for immediate use).
                    // 
                    // Note: Verilog 'always @(*)' drives wires. Inside 'always @(posedge clk)', we use registers.
                    // Since we are in clocked block, we must assign to dist_reg[v] using the values computed in THIS cycle.
                    // But the values depend on 'v' (which is a reg).
                    // So yes, we can compute inside.
                    
                    // Let's do it:
                    if (min_idx != 3'hF) begin // Only if we found a node
                        // Compute diff
                        // We need signed subtraction for absolute value.
                        // Let's use a function or simple logic.
                        // Since we are in a sequential block, we might want to separate this logic into a combinational block, but for one file, we can do it inline.
                        
                        // Let's define a combinational block for the calculation outside? No, I must provide one block.
                        // I will use a combinational helper logic inside the module but outside the always block.
                        // But instructions say "Wrap your JSON output in...", implying one code block.
                        // I can define auxiliary wires.
                        
                        // Let's define wires for the calculation based on current state and registers:
                        // Actually, I can just do the logic here carefully.
                        // 
                        // To do absolute value in sequential block:
                        // reg [15:0] abs_diff;
                        // if (y_coords[u_reg] > y_coords[v]) abs_diff = y_coords[u_reg] - y_coords[v];
                        // else abs_diff = y_coords[v] - y_coords[u_reg];
                        
                        // Let's perform the update.
                        // We need to update dist_reg[v].
                        // We must be careful not to update v if v is 'unvisited' or irrelevant? 
                        // The problem says: "updates distances to all nodes v where...". It doesn't mention visited status.
                        // Dijkstra relaxes edges from u to all neighbors, visited or not (though visited implies final).
                        // However, usually we don't relax from u to v if v is visited. But we can.
                        // The standard optimization is to not update visited nodes. We will skip visited nodes to save cycles, or update anyway.
                        // Let's check if v is valid (valid_nodes[v]).
                        
                        // Logic:
                        // if (valid_nodes[v] && !visited[v]) begin ... end
                        // But instruction says "updates distances to all nodes v". Let's assume all valid nodes.
                        // Let's skip if v == u_reg (self-loop)
                        // Let's check validity.
                        
                        if (valid_nodes[v] && (v != u_reg)) begin
                            // Compute diff
                            // We need to compute it now. 
                            // Let's use a temporary variable calculated outside the if statement but inside the block.
                            // Since we are in clocked block, we can calculate and use it immediately.
                            
                            // Calculate abs difference:
                            reg [15:0] abs_diff;
                            if (y_coords[u_reg] >= y_coords[v]) 
                                abs_diff = y_coords[u_reg] - y_coords[v];
                            else 
                                abs_diff = y_coords[v] - y_coords[u_reg];
                            
                            // Check condition
                            if (abs_diff >= d_mins[u_reg]) begin
                                // Calculate new distance
                                // weight = r_times[u_reg] + abs_diff
                                // new_total = dist_reg[u_reg] + weight
                                // Need to check for overflow
                                reg [31:0] new_dist_calc;
                                new_dist_calc = dist_reg[u_reg] + r_times[u_reg] + abs_diff;
                                
                                // Update
                                if (new_dist_calc < dist_reg[v]) begin
                                    if (new_dist_calc[31:16] == 0)
                                        dist_reg[v] <= new_dist_calc[15:0];
                                    else
                                        dist_reg[v] <= 16'hFFFF; // Saturate
                                end
                            end
                        end
                    end
                    
                    // Move to next neighbor
                    if (v == 3'd7) begin
                        v <= 3'd0; // Reset for next time, or just transition
                        // Transition happens in next_state logic based on v==7
                    end else begin
                        v <= v + 1;
                    end
                end

                CHECK_COMPLETION: begin
                    // Mark u as visited
                    if (min_idx != 3'hF) begin
                        visited[u_reg] <= 1'b1;
                    end
                    iteration_count <= iteration_count + 1;
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Auxiliary register to store u for the update phase
    // We need to capture u during SELECT_MIN
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_reg <= 3'd0;
        end else if (state == SELECT_MIN) begin
            u_reg <= min_idx;
        end
    end

    // Combinational logic to drive 'u_reg' for the module (helper)
    // The instruction says "Assume all inputs are of type reg unless otherwise specified".
    // I will declare u_reg as internal reg.
    reg [2:0] u_reg;

    // Handling Edge Case: IDLE initialization of dist[0]
    // The code above handles dist_reg[0] <= 0 in IDLE.
    
    // Handling Edge Case: Iteration count limit.
    // CHECK_COMPLETION increments iteration_count.
    // SELECT_MIN logic needs to handle termination if min_idx is F (no valid unvisited).
    // The logic in SELECT_MIN sets min_idx to F if nothing found.
    // CHECK_COMPLETION logic: If min_idx == F, we should stop.
    // But we have iteration_count limit.
    // To handle "no valid unvisited" properly:
    // In CHECK_COMPLETION, if min_idx == 3'hF (implying no valid node found), we should go to FINISHED.
    // The next_state logic for CHECK_COMPLETION says:
    // if (iteration_count == 3'd7) next_state = FINISHED;
    // else next_state = SELECT_MIN;
    // If we didn't find a node, min_idx is F. visited[F] is invalid. 
    // So we should check if min_idx == F.
    
    // Let's adjust CHECK_COMPLETION next_state logic in the combinational block above.
    // Wait, I can't edit the combinational block easily in this response format without being confusing.
    // I will add a modification to the combinational logic for CHECK_COMPLETION.
    // I will use a wire 'found_node' to help.
    // Actually, I'll just assume it works or add a minor fix in the SEQUENTIAL block.
    
    // Let's refine the state machine logic in the combinational block (the first always block) to be more robust.
    // Re-writing the combinational block for next_state slightly:
    // if (state == CHECK_COMPLETION) begin
    //   if (min_idx == 4'hF || iteration_count == 3'd7) next_state = FINISHED;
    //   else next_state = SELECT_MIN;
    // end
    
    // I will include this logic in the code.

endmodule

// The code provided above uses 'u_reg' which needs to be defined. 
// Also, the calculation of 'abs_diff' inside the sequential block of UPDATE_NEIGHBORS is slightly tricky because 'abs_diff' is local.
// Most synthesizers (Synopsys, Vivado) support this: variable declared inside always block used for logic.
// To be strictly Verilog 2001 compliant or safer, I should define them outside.
// Given the constraint of "shortest path", I will stick to the logical flow.

// One detail: The `valid_nodes` is 8-bit, city 1 is bit 0.
// We initialized dist[0]=0. This is correct.

// Let's double check the iteration count.
// If N=8, and city 1 is valid, we do 8 iterations.
// If city 1 is invalid, start is asserted, we init dist[0]=0 (should we? The problem says city 1 to all others. If city 1 is invalid, what to do? 
// The prompt says "valid_nodes indicating which cities exist". 
// Usually start node must be valid. But we follow instructions: "valid_nodes[0] is bit 0 for city 1".
// If city 1 is invalid, we shouldn't run. But the prompt doesn't say to check validity of node 1.
// We proceed with the algorithm. If node 1 is invalid, valid_nodes[0] is 0. In SELECT_MIN, min_idx will be F because valid check fails. 
// Then CHECK_COMPLETION will see min_idx F, go to FINISHED immediately.
// Result: dist[0] = 0, others = FFFF. This is correct behavior.

// Optimization: The calculation of `abs_diff` inside the sequential block of UPDATE_NEIGHBORS is valid for synthesis in most tools.
// However, to be safe and clean, I will move helper logic to standard combinational blocks.

module chile_shortest_path(
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_nodes,
    input [15:0] y_coords [0:7],
    input [15:0] d_mins [0:7],
    input [15:0] r_times [0:7],
    output reg [15:0] dist [0:7],
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam SELECT_MIN = 3'b001;
    localparam UPDATE_NEIGHBORS = 3'b010;
    localparam CHECK_COMPLETION = 3'b011;
    localparam FINISHED = 3'b100;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] dist_reg [0:7];
    reg visited [0:7];
    reg [2:0] u;             // Selected node
    reg [2:0] v;             // Neighbor index
    reg [15:0] min_dist;
    reg [2:0] min_idx;
    reg [2:0] iteration_count;
    
    // Combinational Wires for calculation
    wire [15:0] diff;
    wire [31:0] new_dist_val;
    wire condition_met;
    
    // Output assignment
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) dist[i] = dist_reg[i];
    end

    // --- Combinational Logic for Update Calculation ---
    // Helper for absolute difference (combinational)
    // We use current u and v registers for calculation.
    assign diff = (y_coords[u] > y_coords[v]) ? (y_coords[u] - y_coords[v]) : (y_coords[v] - y_coords[u]);
    
    // Check condition: |y_u - y_v| >= d_mins[u]
    assign condition_met = (diff >= d_mins[u]) && valid_nodes[v] && (u != v);
    
    // Calculate new distance: dist[u] + r_times[u] + diff
    // Check for overflow -> saturate to 0xFFFF
    assign new_dist_val = dist_reg[u] + r_times[u] + diff;
    
    // --- State Transition Logic ---
    always @(*) begin
        case (state)
            IDLE:           next_state = start ? SELECT_MIN : IDLE;
            SELECT_MIN:     next_state = UPDATE_NEIGHBORS;
            UPDATE_NEIGHBORS: begin
                if (v == 3'd7) next_state = CHECK_COMPLETION;
                else next_state = UPDATE_NEIGHBORS;
            end
            CHECK_COMPLETION: begin
                if (iteration_count >= 3'd7 || min_idx == 3'hF) 
                    next_state = FINISHED;
                else 
                    next_state = SELECT_MIN;
            end
            FINISHED:       next_state = start ? FINISHED : IDLE; // Wait for start low to reset
            default:        next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            iteration_count <= 3'd0;
            v <= 3'd0;
            // Reset dist and visited
            for (int i = 0; i < 8; i++) begin
                dist_reg[i] <= 16'hFFFF;
                visited[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        dist_reg[0] <= 16'd0;
                        for (int i = 1; i < 8; i++) dist_reg[i] <= 16'hFFFF;
                        for (int i = 0; i < 8; i++) visited[i] <= 1'b0;
                        iteration_count <= 3'd0;
                    end
                end

                SELECT_MIN: begin
                    // Search for minimum unvisited valid node
                    // Reset min values
                    min_dist <= 16'hFFFF;
                    min_idx <= 3'hF;
                    
                    // Unrolled check for 8 nodes (small N, so this is efficient)
                    if (valid_nodes[0] && !visited[0] && dist_reg[0] < 16'hFFFF && dist_reg[0] < min_dist) begin min_dist <= dist_reg[0]; min_idx <= 0; end
                    if (valid_nodes[1] && !visited[1] && dist_reg[1] < 16'hFFFF && dist_reg[1] < min_dist) begin min_dist <= dist_reg[1]; min_idx <= 1; end
                    if (valid_nodes[2] && !visited[2] && dist_reg[2] < 16'hFFFF && dist_reg[2] < min_dist) begin min_dist <= dist_reg[2]; min_idx <= 2; end
                    if (valid_nodes[3] && !visited[3] && dist_reg[3] < 16'hFFFF && dist_reg[3] < min_dist) begin min_dist <= dist_reg[3]; min_idx <= 3; end
                    if (valid_nodes[4] && !visited[4] && dist_reg[4] < 16'hFFFF && dist_reg[4] < min_dist) begin min_dist <= dist_reg[4]; min_idx <= 4; end
                    if (valid_nodes[5] && !visited[5] && dist_reg[5] < 16'hFFFF && dist_reg[5] < min_dist) begin min_dist <= dist_reg[5]; min_idx <= 5; end
                    if (valid_nodes[6] && !visited[6] && dist_reg[6] < 16'hFFFF && dist_reg[6] < min_dist) begin min_dist <= dist_reg[6]; min_idx <= 6; end
                    if (valid_nodes[7] && !visited[7] && dist_reg[7] < 16'hFFFF && dist_reg[7] < min_dist) begin min_dist <= dist_reg[7]; min_idx <= 7; end
                    
                    // Initialize neighbor index for next state
                    v <= 3'd0;
                    // Store selected node u (needed for update phase)
                    // We register u in the next cycle (UPDATE_NEIGHBORS) or here? 
                    // To use u in UPDATE_NEIGHBORS, we need it stable. 
                    // Let's register u now, so it's ready for the next state.
                    // But min_idx is combinational from the block above? No, we updated min_dist/min_idx with <=
                    // So min_idx is valid at the end of this cycle.
                    // We can assign u <= min_idx; 
                    // But min_idx is a reg. It is valid for the NEXT cycle (UPDATE_NEIGHBORS).
                    u <= min_idx; 
                    // Wait, if I assign u <= min_idx in SELECT_MIN, then in UPDATE_NEIGHBORS, u is valid.
                end

                UPDATE_NEIGHBORS: begin
                    // We process v (current neighbor). 
                    // Data is available from inputs/registers. 
                    // 'u' is the selected node from previous cycle.
                    
                    // Check condition and update distance
                    if (condition_met) begin
                        if (new_dist_val[31:16] == 0) begin
                            if (new_dist_val[15:0] < dist_reg[v]) begin
                                dist_reg[v] <= new_dist_val[15:0];
                            end
                        end else begin
                            // Overflow, saturate to max
                            if (16'hFFFF < dist_reg[v]) begin
                                dist_reg[v] <= 16'hFFFF;
                            end
                        end
                    end
                    
                    // Increment v
                    if (v == 3'd7) begin
                        v <= 3'd0; // Reset for next usage, though state transition handles it
                    end else begin
                        v <= v + 1;
                    end
                end

                CHECK_COMPLETION: begin
                    // Mark u as visited
                    if (min_idx != 3'hF) begin
                        visited[u] <= 1'b1; 
                    end
                    // Increment iteration count (only if we actually processed a node)
                    // Or simply increment to ensure max 8 loops. 
                    // If min_idx was F, we are done anyway.
                    if (min_idx != 3'hF) begin
                        iteration_count <= iteration_count + 1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
