module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] q,
    input wire [15:0] row_col_packed,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // DSU parameters
    localparam [7:0] MAX_NODES = 8'd200;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] q_counter; // Counts from 0 to q-1
    reg [7:0] total_nodes;
    reg [7:0] merge_count;
    reg [7:0] parent [0:199];
    reg [7:0] rank [0:199];
    
    // Combinational signals for DSU
    wire [7:0] row_val;
    wire [7:0] col_val;
    wire [7:0] node_a;
    wire [7:0] node_b;
    wire [7:0] root_a;
    wire [7:0] root_b;
    wire do_merge;
    
    // Helper signals for DSU operations
    reg dsu_find_root_a;
    reg dsu_find_root_b;
    reg dsu_union_start;
    reg [7:0] dsu_root_a;
    reg [7:0] dsu_root_b;
    
    // Path compression registers
    reg [7:0] path_stack [0:199];
    reg [7:0] stack_ptr;
    reg path_done;

    // Assignments
    assign row_val = row_col_packed[15:8];
    assign col_val = row_col_packed[7:0];
    assign node_a = row_val; // rows: 0 to n-1 (mapped directly)
    assign node_b = col_val + 8'd200; // columns: n to n+m-1 (offset by 200)
    
    // Initialize parent and rank arrays (done in reset)
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers and arrays
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            q_counter <= 4'd0;
            total_nodes <= 8'd0;
            merge_count <= 8'd0;
            dsu_find_root_a <= 1'b0;
            dsu_find_root_b <= 1'b0;
            dsu_union_start <= 1'b0;
            dsu_root_a <= 8'd0;
            dsu_root_b <= 8'd0;
            stack_ptr <= 8'd0;
            path_done <= 1'b0;
            
            // Initialize DSU arrays
            for (i = 0; i < 200; i = i + 1) begin
                parent[i] <= 8'd0;
                rank[i] <= 8'd0;
                path_stack[i] <= 8'd0;
            end
            // Set parent[i] = i for all i (0 to 199)
            // We do this in a loop in the reset block
            for (i = 0; i < 200; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    q_counter <= 4'd0;
                    merge_count <= 8'd0;
                    dsu_find_root_a <= 1'b0;
                    dsu_find_root_b <= 1'b0;
                    dsu_union_start <= 1'b0;
                    stack_ptr <= 8'd0;
                    path_done <= 1'b0;
                    
                    if (start) begin
                        state <= READ;
                        // Reset parent/rank arrays for new operation
                        for (i = 0; i < 200; i = i + 1) begin
                            parent[i] <= i;
                            rank[i] <= 8'd0;
                        end
                    end
                end

                READ: begin
                    if (q_counter < q) begin
                        // Read one element pair
                        // Start DSU union process
                        dsu_find_root_a <= 1'b1;
                        dsu_find_root_b <= 1'b1;
                        dsu_union_start <= 1'b1;
                        q_counter <= q_counter + 4'd1;
                    end else begin
                        state <= COMPUTE;
                        dsu_find_root_a <= 1'b0;
                        dsu_find_root_b <= 1'b0;
                        dsu_union_start <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // Calculate number of nodes (n + m)
                    // We need to estimate n and m from the data
                    // Since we have rows 0..n-1 and cols 0..m-1
                    // We can compute max index seen so far
                    // But simplified: total_nodes is the number of unique nodes involved
                    // For a bipartite graph with edges (r, c), nodes are rows and cols
                    // Total nodes in the graph = n + m
                    // We can calculate n = max(row) + 1, m = max(col) + 1
                    // However, since we don't track max seen, we just use the property:
                    // Components = (n + m) - merges
                    // We need n and m. Let's assume we track them during READ.
                    // Actually, let's just count unique nodes seen.
                    
                    // Let's refine: We need (n+m). 
                    // Since input gives (row, col) where row in 0..n-1, col in 0..m-1
                    // And we mapped rows to 0..n-1 and cols to 200..200+m-1
                    // We can compute n = max_row + 1, m = max_col + 1
                    // We need to track max_row and max_col during READ.
                    // Adding registers for max_row and max_col.
                    
                    // Logic: count unique parents in DSU for indices 0 to 199
                    // But wait, if n and m are not given, we must infer them.
                    // The problem says "n x m table". We read (row-1, col-1).
                    // So max(row-1) = n-1, max(col-1) = m-1.
                    // We need to track these maxima.
                    // Let's add: reg [7:0] max_row, max_col;
                    // Initialize to 0. Update in READ.
                    
                    // Let's perform component counting here.
                    // Iterate i from 0 to 199.
                    // If parent[i] == i, it's a root.
                    // But we must check if node i was actually used (exists in graph).
                    // Since we only created nodes for edges, we can count roots for all potential nodes?
                    // No, n and m are known from data range.
                    
                    // Let's stick to the formula: Components = (n + m) - merges
                    // We need n and m.
                    // Let's add logic to find n and m during READ phase.
                    // It requires iterating back over the inputs or storing max.
                    // Storing max is cheaper.
                    
                    // Wait, if we reset parents to i for all 0..199, 
                    // we can't just count roots in 0..n+m-1 because n+m is unknown.
                    // We must know n and m.
                    // Let's add two registers: max_row_seen and max_col_seen.
                    // Initialize to 0.
                    // In READ, if row_val > max_row_seen, update it. Same for col.
                    // Then n = max_row_seen + 1, m = max_col_seen + 1.
                    // Total nodes = (max_row_seen + 1) + (max_col_seen + 1) = max_row_seen + max_col_seen + 2.
                    
                    // Revised State Machine for READ:
                    // Update max_row_seen, max_col_seen.
                    // Do DSU union.
                    
                    // Let's implement DSU logic explicitly in combinational blocks or sequential?
                    // With 1 cycle per read, we can do:
                    // 1. Find root of node_a (path compression needed?)
                    // 2. Find root of node_b (path compression needed?)
                    // 3. Union if different.
                    // Finding root takes O(log N) or O(alpha(N)) if naive, but with path compression.
                    // Since we have 1 cycle, we might need a multi-cycle state machine for FIND/UNION.
                    // But the prompt says "read q elements sequentially (1 per cycle)".
                    // This implies the union operation must fit in 1 cycle.
                    // With N=200, we can do a simple iterative find without recursion.
                    // We can implement the find logic in a combinational block driven by the current nodes.
                    // But Verilog needs explicit loops for synthesis.
                    // We can unroll the loop or use a sequential state machine for DSU operations.
                    // Given the constraints (1 cycle per read), let's try a sequential approach for the DSU operation itself if 1 cycle is tight, OR assume a combinational find.
                    // Combinational find for 200 nodes is large but doable in logic.
                    // However, the "Processing" section says "read q elements sequentially (1 per cycle) and update DSU".
                    // This implies the read and update happen together.
                    // If we use a nested FSM for DSU, we might exceed 1 cycle.
                    // Let's try to implement the DSU update in the same cycle as read.
                    // We need:
                    // 1. Find root of node_a (ignoring path compression for simplicity, or using a loop over 200 cycles?)
                    // No, 1 cycle means logic depth.
                    // We can do: root_a = node_a; while(parent[root_a] != root_a) root_a = parent[root_a];
                    // This is recursive. Unrolling is hard.
                    // Alternative: The prompt implies a standard setup. 
                    // Let's use a 2-stage or 3-stage approach inside READ if needed, 
                    // but the description suggests a simpler flow: 
                    // "After q cycles, compute components". 
                    // This confirms READ takes exactly q cycles.
                    
                    // How to do DSU in 1 cycle?
                    // We can't easily do path compression in 1 cycle without a lot of logic.
                    // We can do simple find (without compression) which is O(log N) depth (chains).
                    // 200 depth is too deep for logic (violates timing).
                    // So we MUST use a sequential FSM for the union operation, or use multiple cycles per read.
                    // But the prompt says "1 per cycle".
                    // Wait, if we use a DSU with path compression, we can store the parent array.
                    // To find root: iterative read. We need a loop. 
                    // With 200 nodes, a simple loop in sequential logic takes 200 cycles per find.
                    // This is too slow (q * 200 cycles).
                    
                    // Interpretation: The "1 per cycle" might mean we *initiate* the update per cycle, 
                    // but the DSU logic itself might take more than 1 cycle? 
                    // No, standard interpretation is logic executes in 1 cycle.
                    // For N=200, we can implement the find logic using a priority encoder or LUT-based approach if available, but standard Verilog synthesis for "find" is sequential.
                    // However, in FPGAs/ASICs, 200 depth is bad.
                    // Let's re-read: "DSU with up to 200 nodes".
                    // Maybe we are allowed to take 1 cycle for the *operation* which includes the loop? 
                    // No, that's impossible for 200 iterations.
                    // Let's assume we use a Sequential FSM for the DSU operation, but the prompt says "Processing: When start=1, read q elements sequentially (1 per cycle)... After q cycles, compute components".
                    // This implies the READ phase is exactly q cycles long.
                    // This implies the DSU update logic must fit in 1 cycle.
                    // How? 
                    // Maybe we don't need path compression. Just linking roots.
                    // If we don't compress, find is O(depth).
                    // With random unions, depth is small (log N).
                    // 200 nodes, depth ~ 8.
                    // We can unroll the loop: 
                    // root_a = parent[node_a]; root_a = parent[root_a]; ... (8 times)
                    // This is synthesizable and fast.
                    // Let's do that.
                    // We need to find root_a and root_b.
                    // We can use a combinational block with unrolled logic.
                    // But we need to generate 8 levels of muxing.
                    // Since the code generation is automated, let's write a sequential loop in the always block that runs 8 times? 
                    // No, we can't have loops that run at runtime in combinational logic (unrolled at compile time) unless we use `for` generate or unroll manually.
                    // Let's use a simple sequential state machine for the READ phase: 
                    // State READ_0: Capture inputs, calculate node_a, node_b.
                    // State READ_1: Find root A (1st step).
                    // ...
                    // This would make READ phase longer than q cycles.
                    // UNLESS... we process one element per cycle, but the DSU logic is pipelined.
                    // But the prompt says "After q cycles, compute components".
                    // This is strict.
                    
                    // Let's reconsider the "1 cycle" constraint. 
                    // Perhaps we just do: 
                    // root_a = node_a; for(i=0; i<8; i++) if(parent[root_a] != root_a) root_a = parent[root_a];
                    // This unrolled loop takes ~8 cycles of logic delay. 
                    // If the clock period is generous enough, this fits in 1 cycle.
                    // Or, we use a look-up table approach? No.
                    // Let's try to implement the find logic using a `for` loop inside the combinational logic or always block? 
                    // Icarus Verilog (mentioned in prompt) supports `for` loops in generate or sequential contexts but unrolls them.
                    // If we write:
                    // always @(*) begin
                    //   r = node_a;
                    //   for (k=0; k<200; k=k+1) if (parent[r] != r) r = parent[r];
                    // end
                    // This unrolls to 200 comparisons. This is 200 LUTs deep. Too slow.
                    // 
                    // Let's assume the testbench expects a standard DSU implementation.
                    // Often in these problems, "1 cycle" means the state transition happens, and if the operation is complex, we use a separate FSM state.
                    // But the prompt says: "Processing: When start=1, read q elements sequentially (1 per cycle) and update DSU. After q cycles, compute components".
                    // This strongly suggests that `q` iterations happen in `q` cycles.
                    // 
                    // Strategy: 
                    // Use a sequential logic block for DSU update that spans multiple cycles? 
                    // No, that violates "After q cycles".
                    // 
                    // Strategy: 
                    // Since N=200 is small, we can use a bit-vector representation or parallel logic.
                    // But DSU find is inherently sequential.
                    // 
                    // Perhaps we are overthinking the complexity of the DSU.
                    // We can do Union-Find with naive linking (no path compression, no rank).
                    // Just: if (parent[a] != parent[b]) parent[parent[a]] = parent[b].
                    // Find: while (parent[x] != x) x = parent[x];
                    // If we don't do path compression, the tree can be unbalanced.
                    // Max depth 200. We can't loop 200 times in 1 cycle.
                    // 
                    // However, if we assume the clock frequency is low enough that a chain of 200 logic gates works (unlikely), we can do it.
                    // Or, maybe we are supposed to implement this in software-like sequential logic, and "1 cycle" refers to the initiation interval, not total latency.
                    // But "After q cycles" implies total latency = q.
                    // 
                    // Let's look at the "DSU handles up to 200 nodes".
                    // Maybe we just connect the roots directly? 
                    // No, we need to find roots.
                    // 
                    // Let's assume the intention is to implement the logic as efficiently as possible, possibly using a small state machine for the union operation that runs inside the READ state.
                    // If we use a separate FSM state for DSU (e.g. FIND_A, FIND_B, UNION), the READ phase takes 3*q cycles.
                    // This contradicts "After q cycles".
                    // 
                    // Let's try to implement the find logic using a priority encoder or a tree reduction? 
                    // No, standard DSU is the way.
                    // 
                    // Compromise: Implement the find logic as a combinational loop that is *reasonably* sized.
                    // Or, since N=200 is small, we can use a recursive definition (unrolled).
                    // Let's write the logic for `root_a` and `root_b` in the combinational block.
                    // We need to trace the path.
                    // Since we update `parent` array every cycle, we can just look at the current values.
                    // 
                    // Let's try this: 
                    // In the READ state, we perform:
                    // 1. Find root of node_a (using a small sequential loop that takes 1 cycle? No).
                    // 2. Find root of node_b.
                    // 3. Union.
                    // 
                    // Maybe the prompt implies we don't need path compression, and the graph is mostly acyclic or shallow.
                    // Let's implement a simple `find` function that loops `MAX_DEPTH` times (e.g. 8 times) to handle average cases.
                    // This is a common optimization for DSU in hardware.
                    // 
                    // Let's refine the FSM states for READ:
                    // Since we need to do DSU in 1 cycle, we will rely on combinational logic for the find (unrolled for a fixed depth, say 8).
                    // If the tree is deeper than 8, the find won't reach the root, but we will link to an intermediate node.
                    // This is incorrect DSU behavior.
                    // 
                    // Alternative: 
                    // The prompt might imply a multi-cycle operation per read, but the text "1 per cycle" is explicit.
                    // Let's assume the prompt allows for a multi-cycle FSM within the READ state, but the *count* of `q` cycles corresponds to `q` elements processed.
                    // Wait, that doesn't make sense.
                    // 
                    // Let's go with the simplest interpretation: 
                    // READ state is entered `q` times. 
                    // Inside READ, we have a sub-FSM or sequential logic that takes 1 cycle to update the DSU.
                    // How? 
                    // We can use the `parent` array directly. 
                    // If we just do:
                    // root_a = parent[node_a];
                    // root_b = parent[node_b];
                    // if (root_a != root_b) parent[root_a] = root_b;
                    // This works only if `parent[node_a]` is the root.
                    // This implies we must maintain the invariant that `parent[x]` is always the root.
                    // This requires path compression on every update.
                    // Path compression requires updating all nodes on the path.
                    // 
                    // Let's use a different approach: 
                    // Since N=200 is small, we can perform the DSU operations using a purely combinational block that takes 1 cycle of logic delay.
                    // We will implement `find` using a loop that unrolls to a chain of MUXes.
                    // Depth 200 is too deep. 
                    // We will limit the loop to 8 iterations (assuming small tree depth or using heuristic).
                    // This is risky. 
                    // 
                    // Let's look at the constraints again. 
                    // "Use 16-bit inputs for rows/cols (scaled)."
                    // This suggests we might have larger values, but we map to 0..199.
                    // 
                    // Let's try to implement a standard DSU with a sequential FSM for the union operation, and interpret "1 per cycle" as "1 element processed per cycle (including the time for DSU)". 
                    // This implies the clock is fast enough or the DSU is pipelined.
                    // No, "After q cycles" means total time = q cycles.
                    // 
                    // Let's assume we are allowed to use a separate `compute` block that is purely combinational and runs in 1 cycle.
                    // We will implement the `find` logic using a `for` loop in the combinational block. 
                    // Icarus Verilog requires `genvar` for generate loops, or explicit unrolling.
                    // We can manually unroll 8 times. 
                    // 
                    // What if we just use a queue-based approach? No.
                    // 
                    // Let's write the code for the DSU update assuming it takes 1 cycle (using simple linking without full path compression, just linking roots).
                    // We will add a `max_depth` check or just hope the graph is balanced.
                    // Or, we can use a "Union by Rank" which helps balance.
                    // 
                    // Revised Plan:
                    // 1. IDLE: Reset everything.
                    // 2. READ (q cycles):
                    //    - In each cycle, we compute node indices.
                    //    - We perform DSU find (root_a, root_b) and union.
                    //    - We will implement the find using a `for` loop in the combinational logic that is unrolled (e.g. 8 iterations).
                    //    - This gives us a rough approximation if depth > 8, but it's the best we can do in 1 cycle.
                    //    - Wait, if we do `parent[root_a] = root_b`, we are linking roots. 
                    //    - We need to find the roots. 
                    //    - Let's try to implement the find in the `always` block using a `for` loop that runs at simulation time (unrolled).
                    //    - Since we can't use `break`, we use a flag.
                    //    - We will iterate 8 times. 
                    //    - This limits the DSU to trees of depth 8 (or 8-16 depending on logic).
                    //    - With N=200, depth can be up to 200 without compression. 
                    //    - With Union by Rank, depth is log N (~8). 
                    //    - So 8 iterations is sufficient for Union-by-Rank!
                    //    - Yes! If we use Union by Rank, the tree height is at most O(log N). For N=200, log2(200) < 8.
                    //    - So we can hardcode 8 iterations for the find operation.
                    //    - This fits in 1 cycle.
                    //    - Perfect.

                    // DSU Logic in READ state:
                    // We need to calculate root_a and root_b.
                    // Since this is combinational logic inside the sequential block, we calculate next state logic or register outputs.
                    // We need to update `parent` and `rank`.
                    // We need to read `parent` array, which is a reg array.
                    // We need to write to `parent` array.
                    // 
                    // Structure:
                    // always @(*) for next state logic?
                    // No, standard DSU update is sequential (depends on previous `parent` values).
                    // So we do it in the sequential block.
                    // In READ state:
                    // 1. Calculate node_a, node_b (wires).
                    // 2. Find root_a (using a loop over 8 steps).
                    // 3. Find root_b (using a loop over 8 steps).
                    // 4. If root_a != root_b, union (compare ranks).
                    // 
                    // Code structure:
                    // reg [7:0] temp_root_a, temp_root_b;
                    // reg [7:0] i_iter;
                    // always @(*) begin
                    //   temp_root_a = node_a;
                    //   for (i_iter = 0; i_iter < 8; i_iter = i_iter + 1) begin
                    //     if (parent[temp_root_a] != temp_root_a)
                    //       temp_root_a = parent[temp_root_a];
                    //   end
                    //   ...
                    // end
                    // But we cannot use `temp_root_a` to index `parent` in the same combinational block if `temp_root_a` changes in the loop? 
                    // Actually, we can. It's a combinational dependency chain.
                    // However, `parent` is a `reg` array. We can read it.
                    // But `temp_root_a` is updated in the loop. 
                    // We need to unroll the loop or use a generate block.
                    // 
                    // Let's try to generate the logic using a `for` loop inside the `always` block. 
                    // Icarus Verilog might not support loops inside `always` blocks that aren't generate loops.
                    // Standard Verilog allows loops in `always` blocks; they are unrolled by the synthesizer.
                    // We will try writing it with a `for` loop.
                    // 
                    // Let's refine the READ state logic:
                    // We will compute `root_a` and `root_b` combinationaly within the block.
                    // 
                    // Wait, `parent` is a memory array. 
                    // In Icarus Verilog, array access in loops can be tricky.
                    // We will manually unroll the loop for 8 iterations to be safe and compatible.
                    
                    // Manual unrolling logic for find:
                    // r = node_a;
                    // r = (parent[r] != r) ? parent[r] : r;
                    // r = (parent[r] != r) ? parent[r] : r;
                    // ...
                    // 8 times.
                    // 
                    // We need to do this for `root_a` and `root_b`.
                    // Since we are in a sequential block, we can use intermediate regs to store the current root value.
                    // 
                    // Let's implement this in the READ state.
                    // We will calculate `root_a` and `root_b` in the combinational logic preceding the `always` block, or inside the `always` block using a `begin` block with local variables.
                    // Actually, we can do it all in the sequential `always` block.
                    // 
                    // Let's add the logic for `max_row` and `max_col` tracking to compute `n` and `m`.
                    // Regs: max_row_seen, max_col_seen.
                    // 
                    // Let's write the code.

                end

                FINISH: begin
                    // Calculate components
                    // components = (n + m) - merges
                    // n = max_row_seen + 1
                    // m = max_col_seen + 1
                    // result = components - 1
                    // Handle edge case: if q=0, result = n+m-1? No, if no edges, components = n+m. ans = n+m-1.
                    // If q>0 and graph connected, ans = 0.
                    
                    // We need to compute this. 
                    // Let's compute total_nodes = max_row_seen + max_col_seen + 2.
                    // Result = total_nodes - merge_count - 1.
                    // If result is negative? No, min components is 1 (if all connected), then -1 = 0.
                    
                    result <= (max_row_seen + max_col_seen + 8'd2 - merge_count) - 8'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for DSU find and union (updates are sequential in READ state)
    // We need to implement the find logic.
    // Since we can't easily use loops in combinational logic for Icarus, we will implement the find logic inside the sequential block for the READ state.
    // Actually, we can use a helper combinational block if we use intermediate regs.
    // 
    // Let's define the logic inside the READ state update.
    // 
    // We need to handle the case where q=0.
    // If q=0, we go directly to FINISH?
    // The state machine should handle that.
    
    // Let's implement the DSU logic inside the READ state.
    // Since we can't use `for` loops easily in Icarus inside procedural blocks (they need to be unrolled or generate), 
    // we will unroll the find logic manually for 8 iterations.
    
    // We need to declare the intermediate registers for the find process.
    // Since we need to read `parent` array which is updated in the previous cycle, we are good.
    
    // Let's refine the FSM logic to include DSU operations.
    
    // We need `max_row_seen` and `max_col_seen` registers.
    // Declare them.
    
    // Wait, the `always` block above is already defined. 
    // I need to modify the `READ` state logic.
    // Since I cannot edit the previous block in this response format easily, I will rewrite the entire module.
    
    // Let's refine the `READ` state logic in the main `always` block.
    // 
    // In `READ` state:
    // if (q_counter < q) ...
    // We need to:
    // 1. Update max_row_seen, max_col_seen.
    // 2. Find root of node_a.
    // 3. Find root of node_b.
    // 4. Union.
    // 
    // Let's use a helper combinational block to calculate roots.
    // Since `parent` is updated every cycle, we can read it.
    // But `parent` is a `reg` array. We can read it in combinational logic.
    // 
    // Let's structure the code properly.

endmodule

// Helper module or internal logic? We need internal logic.
// Since we need to do find (path compression), we might need to update the path.
// But in 1 cycle, we can only update the root's parent (union).
// To do path compression, we need to update intermediate nodes.
// If we don't do path compression, we must do Union by Rank to keep trees flat.
// Union by Rank: attach smaller tree to larger tree.
// This keeps height O(log N).
// For N=200, height < 8.
// We can search up to 8 levels.

// Let's implement the logic.

module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] q,
    input wire [15:0] row_col_packed,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    // DSU parameters
    localparam [7:0] MAX_NODES = 8'd200;
    localparam [3:0] FIND_DEPTH = 4'd8;

    // Registers
    reg [2:0] state;
    reg [3:0] q_counter;
    reg [7:0] merge_count;
    reg [7:0] max_row_seen;
    reg [7:0] max_col_seen;
    
    // DSU arrays (parent and rank)
    reg [7:0] parent [0:199];
    reg [7:0] rank [0:199];

    // Intermediate registers for DSU operations (pipeline inside state)
    // Since we do everything in 1 cycle, we need combinational logic to compute roots.
    // We can use always @(*) blocks for that.
    
    // Inputs decoding
    wire [7:0] row_val;
    wire [7:0] col_val;
    wire [7:0] node_a;
    wire [7:0] node_b;

    assign row_val = row_col_packed[15:8];
    assign col_val = row_col_packed[7:0];
    assign node_a = row_val;
    assign node_b = col_val + 8'd200;

    // Combinational logic for DSU Find (Unrolled for 8 levels)
    // We need to find root for node_a and node_b.
    // Since this is combinational, it depends on `parent` array.
    // We must be careful with array indexing in combinational logic.
    
    reg [7:0] root_a;
    reg [7:0] root_b;
    
    integer i; // For loop initialization if needed

    // Manual unrolling of find for 8 levels
    // We need temporary variables for the chain.
    // Since we can't use loops easily in Icarus for synthesis (generate loops are ok, procedural loops are unrolled but might be tricky with arrays),
    // let's write the unrolled logic.
    
    // Logic for root_a:
    // r = node_a;
    // r = (parent[r] != r) ? parent[r] : r;
    // ...
    // 8 times.
    
    always @(*) begin
        // Find root for node_a
        root_a = node_a;
        // Level 1
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 2
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 3
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 4
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 5
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 6
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 7
        if (parent[root_a] != root_a) root_a = parent[root_a];
        // Level 8
        if (parent[root_a] != root_a) root_a = parent[root_a];

        // Find root for node_b
        root_b = node_b;
        // Level 1
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 2
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 3
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 4
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 5
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 6
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 7
        if (parent[root_b] != root_b) root_b = parent[root_b];
        // Level 8
        if (parent[root_b] != root_b) root_b = parent[root_b];
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            q_counter <= 4'd0;
            merge_count <= 8'd0;
            max_row_seen <= 8'd0;
            max_col_seen <= 8'd0;
            // Initialize DSU
            for (i = 0; i < 200; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    q_counter <= 4'd0;
                    merge_count <= 8'd0;
                    max_row_seen <= 8'd0;
                    max_col_seen <= 8'd0;
                    
                    // Initialize DSU for new run
                    for (i = 0; i < 200; i = i + 1) begin
                        parent[i] <= i;
                        rank[i] <= 8'd0;
                    end

                    if (start) begin
                        state <= READ;
                    end
                end

                READ: begin
                    if (q_counter < q) begin
                        // Process one element
                        q_counter <= q_counter + 4'd1;

                        // 1. Update Max dimensions
                        if (row_val > max_row_seen) max_row_seen <= row_val;
                        if (col_val > max_col_seen) max_col_seen <= col_val;

                        // 2. DSU Union (using calculated roots from combinational block)
                        if (root_a != root_b) begin
                            // Union by Rank
                            if (rank[root_a] < rank[root_b]) begin
                                parent[root_a] <= root_b;
                            end else if (rank[root_a] > rank[root_b]) begin
                                parent[root_b] <= root_a;
                            end else begin
                                parent[root_b] <= root_a;
                                rank[root_a] <= rank[root_a] + 8'd1;
                            end
                            merge_count <= merge_count + 8'd1;
                        end
                    end else begin
                        // Done reading all q elements
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Calculate result: (n + m) - merges - 1
                    // n = max_row_seen + 1
                    // m = max_col_seen + 1
                    // Total nodes = max_row_seen + max_col_seen + 2
                    result <= (max_row_seen + max_col_seen + 8'd2 - merge_count) - 8'd1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule