module tower_coverage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [15:0] x [0:15],
    input wire [15:0] y [0:15],
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_ADJ      = 4'd1;
    localparam [3:0] BFS_INIT      = 4'd2;
    localparam [3:0] BFS_LOOP      = 4'd3;
    localparam [3:0] COMP_SIZES    = 4'd4;
    localparam [3:0] BRIDGE_CHECK  = 4'd5;
    localparam [3:0] CALC_MAX      = 4'd6;
    localparam [3:0] FINISH        = 4'd7;
    localparam [3:0] ERR_STATE     = 4'd8;

    // Control Registers
    reg [3:0] state, next_state;
    reg [4:0] i, j;                 // Loop counters
    reg [3:0] current_comp;         // Current component ID
    reg [4:0] component_count;      // Total number of components found
    reg [5:0] max_result;           // Accumulated max result
    reg [4:0] comp_size [0:15];     // Size of each component
    reg [3:0] comp_id [0:15];       // Component ID for each tower
    reg visited [0:15];             // BFS visited flag
    reg [3:0] queue [0:15];         // BFS queue (FIFO)
    reg [4:0] q_head, q_tail;       // Queue pointers
    reg [4:0] idx0, idx1;           // Indices for pairs

    // Adjacency Matrix (16x16 bits) - flattened to 1D array of 256 bits (but Verilog doesn't support large 1D arrays easily)
    // We'll use 16x16 packed array or 16x16 reg array. Using packed for indexing.
    // Actually, Icarus Verilog struggles with multi-dimensional arrays in loops. 
    // We will use a single 256-bit reg and compute index: i*16 + j
    reg [255:0] adj_matrix;
    
    // Wires for distance calculation (combinational logic)
    wire [15:0] dx, dy;
    wire [31:0] dx_sq, dy_sq, dist_sq;
    wire [31:0] dist_sq_limit_1; // (1.0)^2 in Q8.8 -> 1.0 = 256, 256^2 = 65536
    wire [31:0] dist_sq_limit_2; // (2.0)^2 in Q8.8 -> 2.0 = 512, 512^2 = 262144

    // Distance calculation logic for specific indices (i, j) from input arrays
    assign dx = x[i] - x[j];
    assign dy = y[i] - y[j];
    // Signed multiplication: dx (16-bit) * dx (16-bit) -> 32-bit
    // Icarus Verilog often requires explicit handling or simple concatenation for synthesis
    // For Q8.8, dx is signed 16-bit. Squaring doesn't care about sign, but result is positive.
    // We'll treat dx as signed for subtraction, then absolute for squaring if needed, 
    // but simply multiplying the 16-bit values gives the correct 32-bit result for the square.
    assign dx_sq = $signed(dx) * $signed(dx);
    assign dy_sq = $signed(dy) * $signed(dy);
    assign dist_sq = dx_sq + dy_sq;
    
    // Constants
    // 1.0 in Q8.8 is 256. Square is 256*256 = 65536
    assign dist_sq_limit_1 = 32'd65536;
    // 2.0 in Q8.8 is 512. Square is 512*512 = 262144
    assign dist_sq_limit_2 = 32'd262144;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 6'd0;
            adj_matrix <= 256'd0;
            component_count <= 5'd0;
            max_result <= 6'd0;
            i <= 5'd0;
            j <= 5'd0;
            current_comp <= 4'd0;
            q_head <= 5'd0;
            q_tail <= 5'd0;
            idx0 <= 5'd0;
            idx1 <= 5'd0;
            // Initialize arrays
            // Note: Icarus Verilog requires explicit loop or element-wise assignment for arrays
            // We will handle array initialization in the logic loops if needed, or reset them specifically
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_ADJ;
                        i <= 5'd0;
                        j <= 5'd0;
                    end
                end

                INIT_ADJ: begin
                    // Build Adjacency Matrix
                    // Iterate through all pairs (i, j) where i < n and j < n
                    // Check distance <= 1.0 (dist_sq <= 65536)
                    // We perform one check per cycle
                    if (i < n) begin
                        if (j < n) begin
                            if (i != j) begin
                                if (dist_sq <= dist_sq_limit_1) begin
                                    // Set bit (i*16 + j) to 1
                                    adj_matrix[i*16 + j] <= 1'b1;
                                end else begin
                                    adj_matrix[i*16 + j] <= 1'b0;
                                end
                            end else begin
                                adj_matrix[i*16 + j] <= 1'b0; // No self-loop needed for connectivity
                            end
                            j <= j + 5'd1;
                        end else begin
                            j <= 5'd0;
                            i <= i + 5'd1;
                        end
                    end else begin
                        // Done building adjacency matrix
                        state <= BFS_INIT;
                        i <= 5'd0; // Use i as tower index
                        current_comp <= 4'd0;
                        component_count <= 5'd0;
                    end
                end

                BFS_INIT: begin
                    // Initialize visited array
                    if (i < 5'd16) begin
                        visited[i] <= 1'b0;
                        comp_id[i] <= 4'd0;
                        comp_size[i] <= 5'd0;
                        i <= i + 5'd1;
                    end else begin
                        // Start finding components
                        i <= 5'd0; // Reset i for outer loop
                        state <= BFS_LOOP;
                    end
                end

                BFS_LOOP: begin
                    if (i < n) begin
                        if (!visited[i]) begin
                            // Found a new component
                            visited[i] <= 1'b1;
                            comp_id[i] <= current_comp;
                            comp_size[current_comp] <= 5'd1; // Start count at 1 (including self)
                            
                            // Initialize Queue for BFS
                            q_head <= 5'd0;
                            q_tail <= 5'd1;
                            queue[0] <= i[3:0]; // Push root to queue (cast to 4-bit for array storage)
                            
                            state <= COMP_SIZES; // Go to component sizing
                            j <= 5'd0; // j will be used for queue processing
                        end else begin
                            i <= i + 5'd1;
                        end
                    end else begin
                        // All towers processed
                        component_count <= current_comp + 5'd1;
                        state <= BRIDGE_CHECK;
                        idx0 <= 5'd0; // Index for first tower
                        idx1 <= 5'd1; // Index for second tower
                        max_result <= (n < 16) ? 6'd0 : n + 6'd1; // Base case: if only one component, result is n+1. Initialize to 0 to find max bridge.
                    end
                end

                COMP_SIZES: begin
                    // BFS Expansion
                    if (q_head < q_tail) begin
                        // Dequeue head
                        // j is used to iterate neighbors (0 to n-1)
                        // We need to store current node being processed
                        // Since we can't easily push structs, we re-read queue
                        // However, queue needs to persist. 
                        // We'll use a temporary register for the current node.
                        // Actually, simpler: pop in this cycle, scan neighbors.
                        // But we need to scan neighbors over multiple cycles or parallel.
                        // Given n<=16, we can scan neighbors sequentially.
                        // We need a state to scan neighbors for the current node.
                        // Let's create a new state NEIGHBOR_SCAN.
                        state <= 5'd9; // NEIGHBOR_SCAN (custom state index)
                        j <= 5'd0; // Neighbor index
                    end else begin
                        // Queue empty, component done
                        current_comp <= current_comp + 4'd1;
                        state <= BFS_LOOP;
                        i <= i + 5'd1; // Move to next unvisited node
                    end
                end

                5'd9: begin // NEIGHBOR_SCAN
                    if (j < n) begin
                        // Check if j is neighbor of queue[q_head] and not visited
                        // Access queue[ q_head ] requires reading from the array.
                        // We need to index into queue using q_head.
                        if (adj_matrix[queue[q_head]*16 + j] && !visited[j]) begin
                            visited[j] <= 1'b1;
                            comp_id[j] <= current_comp;
                            comp_size[current_comp] <= comp_size[current_comp] + 5'd1;
                            queue[q_tail] <= j[3:0];
                            q_tail <= q_tail + 5'd1;
                        end
                        j <= j + 5'd1;
                    end else begin
                        // Done scanning neighbors for this node
                        q_head <= q_head + 5'd1;
                        state <= COMP_SIZES;
                    end
                end

                BRIDGE_CHECK: begin
                    // Find max connected towers by placing new tower
                    // Brute force all pairs (i, j) with i < j < n
                    if (idx0 < n - 5'd1) begin
                        if (idx1 < n) begin
                            // Check distance <= 2.0 (dist_sq <= 262144)
                            // AND comp_id differ
                            // Use the combinational dist_sq calculation which depends on i and j inputs
                            // i and j are reg outputs, so dist_sq updates combinational
                            // We need to latch the check result or process immediately.
                            // We can do the check in this cycle.
                            if (comp_id[idx0] != comp_id[idx1]) begin
                                if (dist_sq <= dist_sq_limit_2) begin
                                    // Valid bridge candidate
                                    // Calculate total
                                    // Add sizes of both components + 1 (new tower)
                                    // comp_size is indexed by component ID
                                    // Sum = comp_size[comp_id[idx0]] + comp_size[comp_id[idx1]] + 1
                                    // We compute this in CALC_MAX or here.
                                    // Let's update max_result here.
                                    // Note: comp_size is 5-bit, result is 6-bit.
                                    if (comp_size[comp_id[idx0]] + comp_size[comp_id[idx1]] + 5'd1 > max_result) begin
                                        max_result <= comp_size[comp_id[idx0]] + comp_size[comp_id[idx1]] + 5'd1;
                                    end
                                end
                            end
                            idx1 <= idx1 + 5'd1;
                        end else begin
                            idx0 <= idx0 + 5'd1;
                            idx1 <= idx0 + 5'd2;
                        end
                    end else begin
                        // Check if we need to consider the single component case (n+1)
                        // If component_count == 1, max_result should be n + 1.
                        // Our initial max_result was set to n+1 if n<16 (wait, logic error in comment earlier).
                        // Correct logic: If only 1 component exists, we can connect the new tower to it (distance 0), making n+1.
                        // If component_count > 1, n+1 is impossible (can't connect to disconnected towers unless bridging).
                        // We initialized max_result to 0. We must check the single component case.
                        // Actually, if component_count == 1, any pair check would fail (indices diff), so we handle it here.
                        if (component_count == 5'd1) begin
                            max_result <= n + 6'd1;
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= max_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for indexing in NEIGHBOR_SCAN state
    // We need to know which node we are expanding from to access adj_matrix.
    // We can determine this based on q_head.
    // This is a bit tricky in Verilog without continuous assignments affecting state machine timing.
    // We will assume the logic above for NEIGHBOR_SCAN is slightly incomplete without accessing queue[q_head].
    // To make it synthesizable and explicit:
    // The variable 'queue' is an array of 4-bit values (indices 0-15).
    // In the FSM, we need to calculate the index 'i' for the adjacency check based on queue[q_head].
    // However, sequential logic cannot directly index arrays for combinational dependencies within the same always block without creating a latch or complex logic.
    // 
    // Refined approach for BFS logic in pure synthesizable Verilog:
    // We will keep 'current_node' register to store the node being expanded.
    // When state is COMP_SIZES and queue is not empty, we load 'current_node' from queue[q_head], then transition to NEIGHBOR_SCAN.
    
    // Re-defining the control flow slightly to be strictly sequential:
    // 1. COMP_SIZES: If q_head < q_tail, load current_node = queue[q_head], set j=0, go to NEIGHBOR_SCAN. Else go to BFS_LOOP.
    // 2. NEIGHBOR_SCAN: Check j < n. Check adj_matrix[current_node * 16 + j].
    
    // Let's adjust the code to use a dedicated 'current_node' register.
    // (This note is for logic refinement, the code below integrates this or assumes the previous logic was close enough.
    //  Given the constraints, a slightly unrolled logic is safer).
    
    // Corrected sequential block for BFS (overwriting the previous states 5'd9 handling)
    // We will use 'idx0' temporarily as 'current_node' to avoid adding new registers if possible, 
    // but 'idx0' is used in BRIDGE_CHECK. We need a separate register or reuse 'i' carefully.
    // Let's use 'i' to store the current node in the BFS expansion phase, but 'i' is also the outer loop index.
    // We will use 'j' to store the current node during BFS expansion.
    // Wait, 'j' is the neighbor index.
    // 
    // Let's use a register 'bfs_node' to store the node currently being expanded.
    // Since we can't easily add registers in the text interface, we will assume 'i' is repurposed carefully.
    
    // Final Logic Integration for BFS:
    // In BFS_LOOP, when we find a new root, we start processing it immediately.
    // We need to maintain the queue.
    
    // To ensure robustness:
    // We will add a 'bfs_active' flag or check state flow.
    // The code provided in the main block is a high-level representation. 
    // For strict Icarus Verilog compatibility and synthesis:
    // We must avoid reading/writing arrays in ways that cause inferring latches or combinational loops.
    // The state NEIGHBOR_SCAN (5'd9) reads 'queue[q_head]'.
    // To make this work, we need 'queue[q_head]' to be registered or available.
    // 
    // Final adjustment to the FSM block in the code:
    // I will insert a state 'LOAD_QUEUE' to register the current BFS node before scanning neighbors.

endmodule

// Note: The module above implements the logic. 
// The "code" field in the JSON must contain only the Verilog code.
// I will place the corrected, clean module in the JSON output.

// RE-WRITTEN CLEAN MODULE FOR JSON OUTPUT:
module tower_coverage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [15:0] x [0:15],
    input wire [15:0] y [0:15],
    output reg [5:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_ADJ      = 4'd1;
    localparam [3:0] BFS_START     = 4'd2;
    localparam [3:0] BFS_PROCESS   = 4'd3;
    localparam [3:0] SCAN_NEIGH    = 4'd4;
    localparam [3:0] CHECK_BRIDGE  = 4'd5;
    localparam [3:0] FINISH_STATE  = 4'd6;

    reg [3:0] state, next_state;
    reg [4:0] i, j, k; // General counters
    reg [3:0] current_comp_id;
    reg [5:0] cycle_limit;
    reg [255:0] adj_matrix; // 16x16 flattened
    reg [3:0] comp_id [0:15];
    reg [4:0] comp_size [0:15];
    reg visited [0:15];
    reg [3:0] queue [0:15];
    reg [4:0] q_head, q_tail;
    reg [4:0] node_count;
    
    // Temporary storage for bridge logic
    reg [3:0] temp_comp_a, temp_comp_b;
    reg [5:0] temp_sum;

    // Distance wires
    wire [15:0] dx, dy;
    wire [31:0] dx_sq, dy_sq, dist_sq;
    assign dx = x[i] - x[j];
    assign dy = y[i] - y[j];
    assign dx_sq = $signed(dx) * $signed(dx);
    assign dy_sq = $signed(dy) * $signed(dy);
    assign dist_sq = dx_sq + dy_sq;

    // Constants for Q8.8
    // 1.0 = 256, 1.0^2 = 65536
    // 2.0 = 512, 2.0^2 = 262144
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 6'd0;
            adj_matrix <= 256'd0;
            // Initialize arrays (Icarus requires explicit reset)
            for (k = 0; k < 16; k = k + 1) begin
                comp_id[k] <= 4'd0;
                comp_size[k] <= 5'd0;
                visited[k] <= 1'b0;
                queue[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_ADJ;
                        i <= 5'd0;
                        j <= 5'd0;
                    end
                end

                INIT_ADJ: begin
                    // Build adjacency matrix
                    if (i < n) begin
                        if (j < n) begin
                            if (i != j) begin
                                // Check distance <= 1.0 (65536)
                                // Note: dist_sq depends on i and j which are currently registers
                                // The combinational output updates continuously.
                                if (dist_sq <= 32'd65536) begin
                                    adj_matrix[i*16 + j] <= 1'b1;
                                end else begin
                                    adj_matrix[i*16 + j] <= 1'b0;
                                end
                            end else begin
                                adj_matrix[i*16 + j] <= 1'b0;
                            end
                            j <= j + 5'd1;
                        end else begin
                            j <= 5'd0;
                            i <= i + 5'd1;
                        end
                    end else begin
                        state <= BFS_START;
                        i <= 5'd0;
                        current_comp_id <= 4'd0;
                        // Reset visited for BFS
                        for (k = 0; k < 16; k = k + 1) begin
                            visited[k] <= 1'b0;
                            comp_size[k] <= 5'd0;
                        end
                    end
                end

                BFS_START: begin
                    // Find next unvisited node
                    if (i < n) begin
                        if (!visited[i]) begin
                            // Start new component
                            visited[i] <= 1'b1;
                            comp_id[i] <= current_comp_id;
                            comp_size[current_comp_id] <= 5'd1;
                            queue[0] <= i[3:0];
                            q_head <= 5'd0;
                            q_tail <= 5'd1;
                            state <= BFS_PROCESS;
                        end else begin
                            i <= i + 5'd1;
                        end
                    end else begin
                        // All nodes visited
                        // Start Bridge Check
                        state <= CHECK_BRIDGE;
                        i <= 5'd0;
                        j <= 5'd1;
                        result <= 6'd0;
                        // If only one component, max is n + 1
                        if (current_comp_id == 4'd1) begin // 1 component means IDs 0..0, count is 1
                             // Actually current_comp_id is the ID of the NEXT component. 
                             // If we finished BFS_START loop, current_comp_id is the count of components.
                             // If count is 1, we can fill n+1.
                             result <= n + 6'd1;
                        end
                    end
                end

                BFS_PROCESS: begin
                    if (q_head < q_tail) begin
                        // Pop queue
                        // We need to scan neighbors of queue[q_head]
                        // Since we can't easily read queue[q_head] in combinational logic to drive 'i' for next state 
                        // without creating a dependency loop, we will register the current node.
                        // We will use 'i' to hold the current node being expanded.
                        i <= {1'b0, queue[q_head]}; // Cast 4-bit to 5-bit
                        j <= 5'd0; // Neighbor index
                        q_head <= q_head + 5'd1;
                        state <= SCAN_NEIGH;
                    end else begin
                        // Component done, find next root
                        current_comp_id <= current_comp_id + 4'd1;
                        // Advance i (which was the root of previous component, but we need to find next unvisited)
                        // We need to find the next unvisited index > i (or start from 0 if we iterated).
                        // Since we iterate i from 0 in BFS_START, we can just increment current 'i' (root index) there.
                        // But here we are coming from BFS_PROCESS loop. We need to go back to BFS_START.
                        // We should resume search for unvisited nodes from the last root + 1.
                        // However, BFS_START loop iterates i from 0. We should maintain 'root_node' register.
                        // Let's use 'k' to track the root node search index.
                        k <= k + 5'd1; // k tracks the root index search
                        state <= BFS_START;
                        i <= k + 5'd1; // Continue search from next
                    end
                end

                SCAN_NEIGH: begin
                    // i is the current node (popped from queue)
                    // j is the neighbor index
                    if (j < n) begin
                        if (adj_matrix[i*16 + j] && !visited[j]) begin
                            visited[j] <= 1'b1;
                            comp_id[j] <= current_comp_id;
                            comp_size[current_comp_id] <= comp_size[current_comp_id] + 5'd1;
                            queue[q_tail] <= j[3:0];
                            q_tail <= q_tail + 5'd1;
                        end
                        j <= j + 5'd1;
                    end else begin
                        state <= BFS_PROCESS;
                    end
                end

                CHECK_BRIDGE: begin
                    // Check all pairs (i, j) with i < j < n
                    // If comp_id[i] != comp_id[j] and distance <= 2.0 (sq 262144)
                    // Update result
                    if (i < n - 5'd1) begin
                        if (j < n) begin
                            // Check connection
                            if (comp_id[i] != comp_id[j]) begin
                                // Check distance squared <= 262144
                                // dist_sq is calculated using current i, j
                                if (dist_sq <= 32'd262144) begin
                                    temp_sum <= comp_size[comp_id[i]] + comp_size[comp_id[j]] + 6'd1;
                                    // We need a cycle to compare/update result to avoid combinational path issues
                                    // Or we can do it directly if timing is relaxed. Let's do it directly.
                                    // But max_result update needs to be sequential.
                                    // We'll calculate sum and update in the next cycle or use a separate state.
                                    // Let's just update here.
                                    if (comp_size[comp_id[i]] + comp_size[comp_id[j]] + 5'd1 > result) begin
                                        result <= comp_size[comp_id[i]] + comp_size[comp_id[j]] + 5'd1;
                                    end
                                end
                            end
                            j <= j + 5'd1;
                        end else begin
                            i <= i + 5'd1;
                            j <= i + 5'd2;
                        end
                    end else begin
                        state <= FINISH_STATE;
                    end
                end

                FINISH_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule