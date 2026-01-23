module mst_weight (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_points,
    input [9:0] points [0:7],
    output reg [15:0] mst_weight,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam EXTRACT = 4'd1;
    localparam COMPUTE_EDGES = 4'd2;
    localparam SORT_EDGES = 4'd3;
    localparam KRUSKAL = 4'd4;
    localparam DONE = 4'd5;

    reg [3:0] state, next_state;

    // Extracted coordinates
    reg [4:0] x_coords [0:7];
    reg [4:0] y_coords [0:7];
    reg [2:0] extract_idx;

    // Edge storage: 28 edges max
    // Format: {weight[5:0], u[2:0], v[2:0]} -> total 11 bits
    reg [10:0] edges [0:27];
    reg [4:0] edge_count; // up to 28
    reg [4:0] compute_idx_u, compute_idx_v;

    // Sorting variables
    reg [4:0] sort_i, sort_j;
    reg [10:0] temp_edge;
    reg swap_flag;
    reg [4:0] sort_limit;

    // Kruskal / Union-Find variables
    reg [2:0] kruskal_idx;
    reg [2:0] parent [0:7];
    reg [2:0] k_u, k_v;
    reg [2:0] root_u, root_v;
    reg find_done;
    reg [1:0] kruskal_phase; // 0: find_u, 1: find_v, 2: union, 3: next_edge
    reg [2:0] find_node;
    reg [2:0] comp_count;

    // Helper: Find root with path compression (iterative logic simulation)
    // Since this is a state machine, we perform find sequentially
    // Compress path for node 'n' and return root
    // We will use a temporary stack/array logic or just recursion via states
    // Given small N, we can do simple traversal in state
    
    // Registers for find operation
    reg [2:0] find_curr;
    reg [2:0] find_root;
    reg [2:0] temp_parent;
    reg [2:0] path_nodes [0:7];
    reg [2:0] path_idx;

    integer i;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = EXTRACT;
            EXTRACT: if (extract_idx == n_points - 1) next_state = COMPUTE_EDGES;
            COMPUTE_EDGES: begin
                // Max 28 edges. Loop logic handled in sequential block
                // We iterate u from 0 to n-2, v from u+1 to n-1
                // If edge_count reaches calculated max, move to sort
                if (edge_count >= ((n_points * (n_points - 1)) >> 1)) next_state = SORT_EDGES;
            end
            SORT_EDGES: begin
                // Bubble sort. Needs O(N^2) passes. 
                // We will implement a standard bubble sort loop
                // To ensure completion, we control loop counters
                // If sort_i reaches 0 and swap_flag cleared, done
                // Or just run for fixed number of cycles (e.g. 28*28) to be safe in HW
                // Let's use a 'sorted' flag logic. 
                // We'll do one swap pass per clock or per few clocks. 
                // Let's assume 1 swap pass per clock for speed, or 1 compare per clock.
                // For 28 elements, 28*28 cycles is fine (784 cycles).
                // Let's detect completion: if sort_i reaches 0 and no swaps in previous pass.
                // Or simpler: run sort for fixed duration (e.g. 400 cycles) then go to KRUSKAL.
                // Let's implement a pass-based sort.
                if (sort_done_signal) next_state = KRUSKAL;
            end
            KRUSKAL: begin
                // Loop through edges. 
                // For each edge, we need to find root of u and v.
                // We will use specific states for find operations or inline logic.
                // Let's use a phase counter inside KRUSKAL state.
                // We'll iterate kruskal_idx.
                // We are done when comp_count == 1 (one tree left) OR edges exhausted.
                // Actually MST needs N-1 edges. 
                if (mst_edges_found == (n_points - 1)) next_state = DONE;
                else if (kruskal_idx >= edge_count) next_state = DONE; // Should not happen ideally
                else next_state = KRUSKAL; // Stay in state, handle logic inside
            end
            DONE: if (!start) next_state = IDLE; // Wait for start to go low
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    reg [4:0] mst_edges_found;
    reg sort_done_signal;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extract_idx <= 0;
            edge_count <= 0;
            compute_idx_u <= 0;
            compute_idx_v <= 0;
            mst_weight <= 0;
            done <= 0;
            mst_edges_found <= 0;
            sort_done_signal <= 0;
            kruskal_idx <= 0;
            // Reset parent array
            for (i = 0; i < 8; i = i + 1) parent[i] <= i;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        mst_weight <= 0;
                        extract_idx <= 0;
                        edge_count <= 0;
                        compute_idx_u <= 0;
                        compute_idx_v <= 1;
                        mst_edges_found <= 0;
                        sort_done_signal <= 0;
                        kruskal_idx <= 0;
                    end
                end

                EXTRACT: begin
                    x_coords[extract_idx] <= points[extract_idx][9:5];
                    y_coords[extract_idx] <= points[extract_idx][4:0];
                    if (extract_idx < 7) extract_idx <= extract_idx + 1;
                end

                COMPUTE_EDGES: begin
                    // Generate edges for all pairs
                    if (compute_idx_u < n_points - 1) begin
                        if (compute_idx_v < n_points) begin
                            // Compute weight
                            // Manhattan: |x1-x2| + |y1-y2|
                            // Using signed arithmetic logic
                            // Max weight 62 fits in 6 bits
                            edges[edge_count] <= {
                                1'b0, // unused
                                1'b0, // unused
                                1'b0, // unused
                                1'b0, // unused
                                1'b0, // unused
                                1'b0, // unused (wait, 6 bits for weight + 3+3 = 12 bits? No, spec said 11 bits total? No spec said tuple, weight is max 62 (6 bits). Spec says {weight, u, v}. 6+3+3=12. Wait, requirement says "Store edges as {weight, u, v} tuples". No width specified. 6+3+3=12. I used 11 earlier. Let's fix width to 12.
                                // Let's use 12 bits. {weight[5:0], u[2:0], v[2:0]}
                            };
                            // Correct width handling in reg declaration:
                            // edges is array of 12 bit items? No, I declared [10:0]. 
                            // Let's correct the reg width to 11 is not enough. 12 bits.
                            // Correction: edges [0:27] declared as [10:0] in header. 
                            // Let's assume we fix it to 11 bits. 6+3+3 = 12. 
                            // 2^4 = 16, 2^5 = 32. Max 62 fits in 6 bits.
                            // Let's redefine edges to [11:0].
                            // But I cannot change header easily in code block if it was written. 
                            // Wait, I can define it inside the block. 
                            // Let's just use 12 bits in logic.
                            // I will use a temp 12-bit vector.
                            edges[edge_count] <= {
                                (x_coords[compute_idx_u] > x_coords[compute_idx_v]) ? 
                                    (x_coords[compute_idx_u] - x_coords[compute_idx_v]) : 
                                    (x_coords[compute_idx_v] - x_coords[compute_idx_u]),
                                (y_coords[compute_idx_u] > y_coords[compute_idx_v]) ? 
                                    (y_coords[compute_idx_u] - y_coords[compute_idx_v]) : 
                                    (y_coords[compute_idx_v] - y_coords[compute_idx_u]),
                                compute_idx_u,
                                compute_idx_v
                            };
                            // Wait, the concatenation order matters. weight[5:0], u[2:0], v[2:0].
                            // My subtraction result needs to be summed.
                            // Let's create a separate sum variable.
                            // Better to do it in two cycles or combinational. 
                            // Let's do a simple combinational adder here.
                            // Assume weight is 6 bits. 
                            // edges[edge_count][5:0] = |x1-x2| + |y1-y2|
                            // edges[edge_count][8:6] = u
                            // edges[edge_count][11:9] = v
                            
                            // Recalculating weight combinational inside sequential block:
                            // This creates a long path, but 8 points is small. 
                            // Let's do it.
                            edges[edge_count][5:0] <= 
                                ((x_coords[compute_idx_u] > x_coords[compute_idx_v]) ? 
                                    (x_coords[compute_idx_u] - x_coords[compute_idx_v]) : 
                                    (x_coords[compute_idx_v] - x_coords[compute_idx_u])) +
                                ((y_coords[compute_idx_u] > y_coords[compute_idx_v]) ? 
                                    (y_coords[compute_idx_u] - y_coords[compute_idx_v]) : 
                                    (y_coords[compute_idx_v] - y_coords[compute_idx_u]));
                            edges[edge_count][8:6] <= compute_idx_u;
                            edges[edge_count][11:9] <= compute_idx_v;

                            edge_count <= edge_count + 1;
                            compute_idx_v <= compute_idx_v + 1;
                        end else begin
                            compute_idx_u <= compute_idx_u + 1;
                            compute_idx_v <= compute_idx_u + 2;
                        end
                    end
                end

                SORT_EDGES: begin
                    // Bubble Sort Network Simulation
                    // We do one swap pass per clock or logic.
                    // Let's use a standard bubble sort loop logic.
                    // Registers: sort_i, sort_j, swap_flag.
                    // Initialize sort_i = edge_count at entry to SORT_EDGES if needed, or manage within.
                    // To make it fit in state, let's just run a single pass per cycle until sorted.
                    
                    // We need to initialize sort_i, sort_j in IDLE or transition.
                    // Let's assume we initialize sort_i = edge_count in the transition to SORT_EDGES.
                    // But transition logic is comb, so we use logic here.
                    
                    // Let's implement: 
                    // If sort_i > 0:
                    //   if sort_j < sort_i:
                    //     compare edges[sort_j-1] and edges[sort_j]... wait standard bubble is j < i.
                    //     Standard: for i from 0 to N-1, for j from 0 to N-i-1.
                    // Let's simplify: Just a flag "sorted".
                    // If we enter SORT_EDGES, we perform swaps. 
                    // We'll use a 'pass' counter.
                    
                    // Let's define local reg for sorting to keep state.
                    // Since I cannot easily declare always_ff inside, I use the main block.
                    // We need to know if we are starting sort. 
                    // Let's track sort stages.
                    
                    // Simplified Bubble Sort Logic:
                    // We will iterate 'bubble_i' from 0 to edge_count-1.
                    // Inside each iteration, we iterate 'bubble_j' from 0 to edge_count-2-bubble_i.
                    // This is too many states for one state machine state unless we compress.
                    // However, requirement says "Uses bubble sort network". 
                    // A "network" implies fixed logic. But we are in a sequential state machine.
                    // So we simulate the network over cycles.
                    // Let's take 28*28 cycles (784). 
                    // We will have inner counters.
                    
                    // To implement inside the single state 'SORT_EDGES':
                    // We need persistent counters.
                    // Let's assume they are declared outside.
                    // sort_i: 0 to edge_count-1
                    // sort_j: 0 to edge_count-2-sort_i
                    
                    // Initialize counters when entering SORT_EDGES.
                    // We need to know if it's the first cycle of SORT_EDGES.
                    // We can detect state transition.
                    
                    // Logic:
                    // if (state changed to SORT_EDGES) reset sort_i=0, sort_j=0.
                    // else:
                    //   if (sort_j < edge_count - 1 - sort_i) begin
                    //     if (edges[sort_j][5:0] > edges[sort_j+1][5:0]) swap;
                    //     sort_j <= sort_j + 1;
                    //   end else begin
                    //     sort_j <= 0;
                    //     sort_i <= sort_i + 1;
                    //   end
                    //   if (sort_i == edge_count - 1) sort_done_signal <= 1;
                    
                    // Handling the 'first cycle' issue:
                    // We can check if sort_i was reset. 
                    // Let's use a flag 'sort_started'. 
                    // Or simply initialize in the transition logic. 
                    // Since transition logic is tricky, let's do it in the first cycle of the state.
                    
                    // Fix: I will declare sort_i, sort_j outside.
                    // Check if we just entered SORT_EDGES.
                    // We can check if state was previously not SORT_EDGES.
                    // Actually, I can just use a local 'sort_initialized' flag.
                    
                    // Let's assume we use 'sort_i' and 'sort_j' registers. 
                    // If we are in SORT_EDGES for the first time (sort_i == 5'h1F or some init value), reset them.
                    // But I reset them in IDLE (sort_i=0). So I need to differentiate.
                    // Let's use a flag 'sorting_active'.
                    // Or, simply handle the init in the state transition logic? 
                    // No, I need to put it in sequential logic.
                    
                    // Let's reset sort_i to a high value (e.g. 31) in IDLE.
                    // If in SORT_EDGES and sort_i > edge_count, then init.
                    // Let's do explicit 'start_sort' signal.
                    // Actually, let's just re-initialize counters when state == SORT_EDGES and edge_count > 0.
                    
                    // Revised plan for SORT_EDGES:
                    // We will iterate. 
                    // We need to store the sorting state.
                    // Let's use a separate always block or just do it step by step.
                    
                    // Let's define:
                    // reg [4:0] sort_pass;
                    // reg [4:0] sort_pos;
                    // 
                    // Logic:
                    // if (state == SORT_EDGES) begin
                    //    if (sort_pass < edge_count) begin
                    //        if (sort_pos < edge_count - 1 - sort_pass) begin
                    //            if (edges[sort_pos][5:0] > edges[sort_pos+1][5:0]) swap edges[sort_pos] and edges[sort_pos+1];
                    //            sort_pos <= sort_pos + 1;
                    //        end else begin
                    //            sort_pos <= 0;
                    //            sort_pass <= sort_pass + 1;
                    //        end
                    //    end else begin
                    //        sort_done_signal <= 1;
                    //    end
                    // end
                    // 
                    // Initialization: 
                    // When moving from COMPUTE_EDGES to SORT_EDGES, sort_pass and sort_pos should be 0.
                    // I can detect this by checking if sort_done_signal was 0 and state becomes SORT_EDGES.
                    // But easier: In IDLE, reset sort_pass = edge_count (invalid), sort_pos = 0.
                    // In SORT_EDGES: if (sort_pass >= edge_count) and (edge_count > 0), set sort_pass=0, sort_pos=0 (first cycle logic). 
                    // Or: use a flag 'sort_initialized'.
                    
                    // Let's try a cleaner approach:
                    // Use a counter 'sort_cycle'.
                    // If state == SORT_EDGES, increment sort_cycle.
                    // Based on sort_cycle, we can derive indices for bubble sort.
                    // Total cycles needed: N(N-1)/2 approx. For 28, 378. 
                    // Let's just run a counter 'sort_timer' from 0 to MAX.
                    // Map timer to indices (i, j) for bubble sort.
                    // This is complex to map.
                    
                    // Let's stick to the iterative counter approach.
                    // I will add 'sort_pass' and 'sort_pos' logic.
                    // Check transition from IDLE/EXTRACT to SORT_EDGES.
                    // In IDLE: sort_pass <= 0; (reset)
                    // In transition to SORT_EDGES (in next_state logic): 
                    //   We can't easily set values here. 
                    //   So in sequential logic inside SORT_EDGES:
                    //   if (first_cycle_flag) begin init; clear flag. end
                    
                    // Let's introduce 'first_cycle_sort' register.
                    // In IDLE: first_cycle_sort <= 1;
                    // In SORT_EDGES:
                    //   if (first_cycle_sort) begin sort_pass <= 0; sort_pos <= 0; first_cycle_sort <= 0; end
                    //   else begin ... sort logic ...
                    //   end
                    
                    // Let's implement the sort logic now.
                    // We need 'sort_pass' and 'sort_pos' registers.
                    // Declare them at top: reg [4:0] sort_pass, sort_pos;
                    // Reg 'first_cycle_sort'.
                    
                    // Implementation:
                    if (first_cycle_sort) begin
                        sort_pass <= 0;
                        sort_pos <= 0;
                        first_cycle_sort <= 0;
                    end else begin
                        if (sort_pass < edge_count) begin
                            if (sort_pos < edge_count - 1 - sort_pass) begin
                                // Compare and swap
                                if (edges[sort_pos][5:0] > edges[sort_pos+1][5:0]) begin
                                    temp_edge <= edges[sort_pos];
                                    edges[sort_pos] <= edges[sort_pos+1];
                                    edges[sort_pos+1] <= temp_edge;
                                end
                                sort_pos <= sort_pos + 1;
                            end else begin
                                sort_pos <= 0;
                                sort_pass <= sort_pass + 1;
                            end
                        end else begin
                            sort_done_signal <= 1;
                        end
                    end
                end

                KRUSKAL: begin
                    // Process edges
                    // We use kruskal_idx to iterate edges.
                    // For each edge, we need to find root of u and v.
                    // Union-Find.
                    // Since we are in a single state, we need to sub-state or multi-cycle logic.
                    // Let's use 'kruskal_phase'.
                    // 0: Load u, start find
                    // 1: Wait/Process find u (need loop)
                    // 2: Load v, start find
                    // 3: Wait/Process find v
                    // 4: Check roots, Union, Add to MST
                    // 5: Next edge
                    
                    // To simplify finding root in hardware (no recursion):
                    // We can do iterative lookup. 
                    // Since depth is small, we can unroll or use a loop in logic.
                    // Let's try to do find in 1 cycle using a combinational path, but that might violate timing if not careful. 
                    // But registers are small (8). 
                    // Let's do explicit path tracing.
                    
                    // Let's refine phases:
                    // phase 0: Get edge data (u, v). k_u = edges[kruskal_idx][8:6], k_v = edges[kruskal_idx][11:9]
                    // phase 1: Find Root U (iterative lookup)
                    // phase 2: Find Root V (iterative lookup)
                    // phase 3: Check if different, if so, union (update parent) and add weight. increment mst_edges_found.
                    // phase 4: Increment kruskal_idx. Reset phase to 0.
                    
                    // To make find efficient (1 cycle), we can use a combinational always block for root finding.
                    // But instructions say "Verilog module". I'll do it sequentially to be safe.
                    
                    // Let's use 'kruskal_phase' register.
                    // 0: Setup
                    // 1: Find U
                    // 2: Find V
                    // 3: Union/Add
                    
                    case (kruskal_phase)
                        0: begin
                            k_u <= edges[kruskal_idx][8:6];
                            k_v <= edges[kruskal_idx][11:9];
                            // Start finding root of u
                            // We will trace parent pointers. 
                            // Since we need to compress, we might store path.
                            // Let's just find root first without compression (Standard Kruskal is fine with path compression but not strictly required if we just want correctness, though efficiency is good).
                            // Without compression, finding root is O(N). With N=8, it's fine.
                            // Let's just trace: curr = k_u; while(parent[curr] != curr) curr = parent[curr];
                            // We can do this in one cycle if we unroll, or multiple cycles.
                            // Let's do multiple cycles for find logic. 
                            // We'll use 'find_node' and 'find_root' registers.
                            kruskal_phase <= 1;
                            find_node <= k_u; // Start node
                        end
                        
                        1: begin // Find Root U
                            if (parent[find_node] == find_node) begin
                                root_u <= find_node;
                                kruskal_phase <= 2;
                                find_node <= k_v; // Setup for V
                            end else begin
                                find_node <= parent[find_node];
                            end
                        end
                        
                        2: begin // Find Root V
                            if (parent[find_node] == find_node) begin
                                root_v <= find_node;
                                kruskal_phase <= 3;
                            end else begin
                                find_node <= parent[find_node];
                            end
                        end
                        
                        3: begin // Union and Add
                            if (root_u != root_v) begin
                                // Add weight to MST
                                // Weight is edges[kruskal_idx][5:0]
                                mst_weight <= mst_weight + {10'b0, edges[kruskal_idx][5:0]};
                                mst_edges_found <= mst_edges_found + 1;
                                // Union (attach root_u to root_v)
                                parent[root_u] <= root_v;
                            end
                            // Next edge
                            kruskal_idx <= kruskal_idx + 1;
                            kruskal_phase <= 0;
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Helper registers for Sort and Kruskal (declared here to ensure scope)
    reg [4:0] sort_pass;
    reg [4:0] sort_pos;
    reg first_cycle_sort;
    
    // Update sort logic to use these registers
    // The logic inside the main always block uses sort_pass, sort_pos, first_cycle_sort.
    // I need to make sure they are reset/initialized correctly.
    
    // Re-writing the SORT_EDGES logic in the main block to be clear:
    // Actually, the logic inside was:
    // if (first_cycle_sort) ...
    // We need to define where first_cycle_sort is reset.
    // In IDLE, set first_cycle_sort = 1.
    
    // Correction to the always block for SORT_EDGES:
    // The previous code in the always block was:
    // if (first_cycle_sort) begin ... end else begin ... end
    // This looks correct provided first_cycle_sort is managed.
    
    // Let's add a block to handle the register updates for sort_pass, sort_pos, first_cycle_sort
    // This is already inside the main always block, but I need to declare the regs.
    // I will declare them at the top of the module with the other regs.

endmodule

// Note: The logic for Manhattan distance calculation inside COMPUTE_EDGES was split into bit selections.
// I need to make sure the weight sum is correct.
// edges[edge_count][5:0] is weight.
// The concatenation in COMPUTE_EDGES needs to be valid. 
// I wrote:
// edges[edge_count][5:0] <= (abs_diff_x + abs_diff_y);
// edges[edge_count][8:6] <= compute_idx_u;
// edges[edge_count][11:9] <= compute_idx_v;
// This matches the format {v[2:0], u[2:0], weight[5:0]}? 
// No, I wrote {weight, u, v} in description. 
// {weight[5:0], u[2:0], v[2:0]} means bits [11:9] = v, [8:6] = u, [5:0] = weight.
// My assignment: [5:0] = weight (Correct). [8:6] = u (Correct). [11:9] = v (Correct).
// Wait, the calculation: 
// edges[edge_count][5:0] <= ...
// edges[edge_count][8:6] <= compute_idx_u; // u
// edges[edge_count][11:9] <= compute_idx_v; // v
// This sets bits 11:9 as v. So edge[11:9] = v. edge[8:6] = u.
// In Kruskal: edges[kruskal_idx][8:6] -> u. edges[kruskal_idx][11:9] -> v.
// Correct match.

// Edge Count Calculation: N(N-1)/2. 
// I used edge_count >= ((n_points * (n_points - 1)) >> 1).
// For N=1, N-1=0, edge_count >= 0. Correct.
// For N=2, N*(N-1)/2 = 1. edge_count >= 1. Correct.

// Kruskal Loop:
// When Kruskal phase 3 ends, we do kruskal_idx++. 
// We check if mst_edges_found == n_points - 1 in Next State Logic.
// If so, go to DONE.
// If kruskal_idx reaches edge_count, go to DONE (handled in next state logic).

// Sort:
// My sort logic writes to temp_edge. 
// It reads edges[sort_pos], edges[sort_pos+1].
// Writes edges[sort_pos], edges[sort_pos+1].
// This is standard.

// Union:
// parent[root_u] = root_v.
// This works.

// Refinements:
// Need to declare 'temp_edge' (already done).
// Need to declare 'first_cycle_sort', 'sort_pass', 'sort_pos' (already noted in thought process, I will insert them in the code).

// The code provided in the final block below incorporates these details.

module mst_weight (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_points,
    input [9:0] points [0:7],
    output reg [15:0] mst_weight,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam EXTRACT = 4'd1;
    localparam COMPUTE_EDGES = 4'd2;
    localparam SORT_EDGES = 4'd3;
    localparam KRUSKAL = 4'd4;
    localparam DONE = 4'd5;

    reg [3:0] state, next_state;

    // Extracted coordinates
    reg [4:0] x_coords [0:7];
    reg [4:0] y_coords [0:7];
    reg [2:0] extract_idx;

    // Edge storage: 28 edges max
    // Format: {weight[5:0], u[2:0], v[2:0]} -> 11 bits? 5:0=6, 8:6=3, 11:9=3. Total 12 bits.
    // Correcting width to 11:0? No, 12 bits. [11:0].
    reg [11:0] edges [0:27];
    reg [4:0] edge_count;
    reg [4:0] compute_idx_u, compute_idx_v;

    // Sorting variables
    reg [4:0] sort_i, sort_j; // Not strictly needed if using pass/pos
    reg [11:0] temp_edge;
    reg [4:0] sort_pass;
    reg [4:0] sort_pos;
    reg first_cycle_sort;
    reg sort_done_signal;

    // Kruskal / Union-Find variables
    reg [2:0] kruskal_idx;
    reg [2:0] parent [0:7];
    reg [2:0] k_u, k_v;
    reg [2:0] root_u, root_v;
    reg [1:0] kruskal_phase; // 0: setup, 1: find_u, 2: find_v, 3: union
    reg [2:0] find_node;
    reg [4:0] mst_edges_found;
    
    integer i;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = EXTRACT;
            EXTRACT: if (extract_idx == n_points - 1 && n_points > 0) next_state = COMPUTE_EDGES;
            COMPUTE_EDGES: begin
                // Calculate max edges: n_points*(n_points-1)/2
                // If edge_count reaches this, go to sort.
                // Need comb logic for this comparison.
                if (edge_count >= ((n_points * (n_points - 1)) >> 1)) next_state = SORT_EDGES;
            end
            SORT_EDGES: begin
                if (sort_done_signal) next_state = KRUSKAL;
            end
            KRUSKAL: begin
                // Check if MST is built (N-1 edges) or no more edges
                // Note: edge_count is number of valid edges. If we processed all, we are done.
                // MST edges found: mst_edges_found == n_points - 1
                // Edge index limit: kruskal_idx >= edge_count
                if (mst_edges_found == (n_points - 1)) next_state = DONE;
                else if (kruskal_idx >= edge_count && kruskal_phase == 0) next_state = DONE; // Ran out of edges
                else next_state = KRUSKAL;
            end
            DONE: if (!start) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extract_idx <= 0;
            edge_count <= 0;
            compute_idx_u <= 0;
            compute_idx_v <= 0;
            mst_weight <= 0;
            done <= 0;
            mst_edges_found <= 0;
            sort_done_signal <= 0;
            kruskal_idx <= 0;
            kruskal_phase <= 0;
            first_cycle_sort <= 1;
            for (i = 0; i < 8; i = i + 1) parent[i] <= i;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        mst_weight <= 0;
                        extract_idx <= 0;
                        edge_count <= 0;
                        compute_idx_u <= 0;
                        compute_idx_v <= 1;
                        mst_edges_found <= 0;
                        sort_done_signal <= 0;
                        kruskal_idx <= 0;
                        kruskal_phase <= 0;
                        first_cycle_sort <= 1;
                        // Reset parents
                        for (i = 0; i < 8; i = i + 1) parent[i] <= i;
                    end
                end

                EXTRACT: begin
                    x_coords[extract_idx] <= points[extract_idx][9:5];
                    y_coords[extract_idx] <= points[extract_idx][4:0];
                    if (extract_idx < 7) extract_idx <= extract_idx + 1;
                end

                COMPUTE_EDGES: begin
                    if (compute_idx_u < n_points - 1) begin
                        if (compute_idx_v < n_points) begin
                            // Compute weight
                            // Handle potential subtraction overflow implicitly by using larger types in calculation
                            // or just assume 5-bit inputs and 6-bit result fits.
                            // |dx| + |dy|
                            edges[edge_count][5:0] <= 
                                ((x_coords[compute_idx_u] > x_coords[compute_idx_v]) ? 
                                    (x_coords[compute_idx_u] - x_coords[compute_idx_v]) : 
                                    (x_coords[compute_idx_v] - x_coords[compute_idx_u])) +
                                ((y_coords[compute_idx_u] > y_coords[compute_idx_v]) ? 
                                    (y_coords[compute_idx_u] - y_coords[compute_idx_v]) : 
                                    (y_coords[compute_idx_v] - y_coords[compute_idx_u]));
                            edges[edge_count][8:6] <= compute_idx_u;
                            edges[edge_count][11:9] <= compute_idx_v;
                            edge_count <= edge_count + 1;
                            compute_idx_v <= compute_idx_v + 1;
                        end else begin
                            compute_idx_u <= compute_idx_u + 1;
                            compute_idx_v <= compute_idx_u + 2;
                        end
                    end
                end

                SORT_EDGES: begin
                    if (first_cycle_sort) begin
                        sort_pass <= 0;
                        sort_pos <= 0;
                        first_cycle_sort <= 0;
                    end else begin
                        if (sort_pass < edge_count) begin
                            if (sort_pos < edge_count - 1 - sort_pass) begin
                                if (edges[sort_pos][5:0] > edges[sort_pos+1][5:0]) begin
                                    temp_edge <= edges[sort_pos];
                                    edges[sort_pos] <= edges[sort_pos+1];
                                    edges[sort_pos+1] <= temp_edge;
                                end
                                sort_pos <= sort_pos + 1;
                            end else begin
                                sort_pos <= 0;
                                sort_pass <= sort_pass + 1;
                            end
                        end else begin
                            sort_done_signal <= 1;
                        end
                    end
                end

                KRUSKAL: begin
                    case (kruskal_phase)
                        0: begin // Setup edge info
                            if (kruskal_idx < edge_count) begin
                                k_u <= edges[kruskal_idx][8:6];
                                k_v <= edges[kruskal_idx][11:9];
                                kruskal_phase <= 1;
                                find_node <= edges[kruskal_idx][8:6];
                            end
                        end
                        1: begin // Find Root U
                            if (parent[find_node] == find_node) begin
                                root_u <= find_node;
                                kruskal_phase <= 2;
                                find_node <= k_v;
                            end else begin
                                find_node <= parent[find_node];
                            end
                        end
                        2: begin // Find Root V
                            if (parent[find_node] == find_node) begin
                                root_v <= find_node;
                                kruskal_phase <= 3;
                            end else begin
                                find_node <= parent[find_node];
                            end
                        end
                        3: begin // Union and Add
                            if (root_u != root_v) begin
                                mst_weight <= mst_weight + {10'b0, edges[kruskal_idx][5:0]};
                                mst_edges_found <= mst_edges_found + 1;
                                parent[root_u] <= root_v; // Union by attaching u's root to v's root
                            end
                            kruskal_idx <= kruskal_idx + 1;
                            kruskal_phase <= 0;
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
