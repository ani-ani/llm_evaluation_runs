module TopModule(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [5:0] m,
    input [4:0] h,
    input [4:0] u [0:15],
    input [4:0] client1 [0:31],
    input [4:0] client2 [0:31],
    output reg [4:0] result_size,
    output reg [15:0] result_indices,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] BUILD_ADJ = 4'd1;
    localparam [3:0] DFS1_VISIT = 4'd2;
    localparam [3:0] TRANSPOSE = 4'd3;
    localparam [3:0] DFS2_VISIT = 4'd4;
    localparam [3:0] COMPUTE_OUTDEG = 4'd5;
    localparam [3:0] FIND_SINK = 4'd6;
    localparam [3:0] FINISH = 4'd7;
    localparam [3:0] CHECK_TIMER = 4'd8;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Fixed-size arrays
    reg [15:0] adj [0:15];      // Adjacency matrix (directed edges)
    reg [15:0] transpose [0:15]; // Transposed adjacency matrix
    reg visited [0:15];         // Visited flags
    reg [3:0] scc_id [0:15];    // SCC ID for each node (0-15)
    reg [3:0] finish_order [0:15]; // Order of finish times
    reg [3:0] finish_idx;       // Index into finish_order
    reg [3:0] node_ptr;         // Current node for DFS
    reg [3:0] scc_size [0:15];  // Size of each SCC (max 16 SCCs)
    reg [15:0] scc_outdeg [0:15]; // Out-degree of each SCC (bitmask)
    reg [3:0] current_scc;      // Current SCC being processed
    reg [3:0] best_scc;         // Best sink SCC found
    reg [4:0] best_size;        // Size of best SCC

    // Temporary registers for DFS
    reg [15:0] stack [0:15];    // Stack for DFS (bitmask of nodes)
    reg [3:0] stack_ptr;        // Stack pointer
    reg [15:0] stack_mask;      // To check visited in stack
    reg [3:0] neighbor_idx;     // Neighbor iteration index
    reg found;                  // Flag for finding nodes
    reg [3:0] i, j;             // Loop counters

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            result_size <= 5'd0;
            result_indices <= 16'd0;
            done <= 1'b0;
            // Reset all arrays
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                transpose[i] <= 16'd0;
                visited[i] <= 1'b0;
                scc_id[i] <= 4'd0;
                finish_order[i] <= 4'd0;
                scc_size[i] <= 4'd0;
                scc_outdeg[i] <= 16'd0;
                stack[i] <= 16'd0;
            end
            finish_idx <= 4'd0;
            node_ptr <= 4'd0;
            current_scc <= 4'd0;
            best_scc <= 4'd0;
            best_size <= 5'd0;
            stack_ptr <= 4'd0;
            stack_mask <= 16'd0;
            neighbor_idx <= 4'd0;
            found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= BUILD_ADJ;
                    end
                end

                BUILD_ADJ: begin
                    // Build adjacency: edge i->j if (u[i] + 1) % h == u[j]
                    // Use node_ptr as outer loop (i)
                    if (node_ptr < n) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if (u[node_ptr] < h && u[j] < h) begin
                                if (((u[node_ptr] + 5'd1) % h) == u[j]) begin
                                    adj[node_ptr] <= adj[node_ptr] | (1 << j);
                                end
                            end
                        end
                        node_ptr <= node_ptr + 4'd1;
                    end else begin
                        node_ptr <= 4'd0;
                        state <= DFS1_VISIT;
                        // Clear visited for first DFS
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 1'b0;
                        end
                        finish_idx <= 4'd0;
                    end
                end

                DFS1_VISIT: begin
                    // Iterative DFS using stack for node_ptr
                    if (node_ptr < n) begin
                        if (!visited[node_ptr]) begin
                            // Start DFS from node_ptr
                            stack_ptr <= 4'd0;
                            stack[node_ptr] <= (1 << node_ptr); // Push node_ptr
                            stack_ptr <= stack_ptr + 4'd1;
                            visited[node_ptr] <= 1'b1;
                            stack_mask <= (1 << node_ptr);
                            neighbor_idx <= 4'd0;
                            // Save current node being processed
                            stack[stack_ptr] <= (1 << node_ptr);
                        end else begin
                            node_ptr <= node_ptr + 4'd1;
                        end
                    end else begin
                        // All nodes processed, move to transpose
                        node_ptr <= 4'd0;
                        state <= TRANSPOSE;
                    end

                    // DFS loop (if stack is not empty)
                    if (stack_ptr > 0) begin
                        // Peek at top of stack
                        reg [3:0] current;
                        current = 0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (stack[stack_ptr-1] == (1 << i)) current <= i;
                        end
                        // Find next unvisited neighbor
                        reg [15:0] neigh_mask;
                        found <= 1'b0;
                        for (neighbor_idx = 0; neighbor_idx < n; neighbor_idx = neighbor_idx + 1) begin
                            if (!found && (adj[current] & (1 << neighbor_idx)) && !visited[neighbor_idx] && !(stack_mask & (1 << neighbor_idx))) begin
                                found <= 1'b1;
                                visited[neighbor_idx] <= 1'b1;
                                stack_mask <= stack_mask | (1 << neighbor_idx);
                                stack[stack_ptr] <= (1 << neighbor_idx);
                                stack_ptr <= stack_ptr + 4'd1;
                                neighbor_idx <= 4'd0; // Reset search
                            end
                        end
                        if (!found) begin
                            // All neighbors processed, pop and record finish
                            stack_ptr <= stack_ptr - 4'd1;
                            stack_mask <= stack_mask & ~(1 << current);
                            finish_order[finish_idx] <= current;
                            finish_idx <= finish_idx + 4'd1;
                        end
                    end
                end

                TRANSPOSE: begin
                    // Build transpose graph from adjacency
                    if (node_ptr < n) begin
                        // Find all j such that adj[j] has bit node_ptr
                        for (i = 0; i < n; i = i + 1) begin
                            if (adj[i] & (1 << node_ptr)) begin
                                transpose[node_ptr] <= transpose[node_ptr] | (1 << i);
                            end
                        end
                        node_ptr <= node_ptr + 4'd1;
                    end else begin
                        // Reset visited for second DFS
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 1'b0;
                            scc_id[i] <= 4'd0;
                        end
                        current_scc <= 4'd0;
                        node_ptr <= n - 4'd1; // Start from last finished node
                        state <= DFS2_VISIT;
                    end
                end

                DFS2_VISIT: begin
                    // Process nodes in reverse finish order
                    if (node_ptr < 16 && node_ptr != 16'hFFFF) begin
                        reg [3:0] start_node;
                        start_node = finish_order[node_ptr];
                        if (start_node < n && !visited[start_node]) begin
                            // DFS on transpose starting from start_node
                            stack_ptr <= 4'd0;
                            stack[stack_ptr] <= (1 << start_node);
                            stack_ptr <= stack_ptr + 4'd1;
                            visited[start_node] <= 1'b1;
                            scc_id[start_node] <= current_scc;
                            stack_mask <= (1 << start_node);
                            neighbor_idx <= 4'd0;
                        end else begin
                            node_ptr <= (node_ptr == 0) ? 16'hFFFF : node_ptr - 4'd1;
                        end
                    end else if (node_ptr == 16'hFFFF) begin
                        // Post-order: count SCC sizes
                        // Reset for computation
                        for (i = 0; i < 16; i = i + 1) begin
                            scc_size[i] <= 4'd0;
                        end
                        node_ptr <= 4'd0;
                        state <= COMPUTE_OUTDEG;
                    end

                    // DFS loop for transpose
                    if (stack_ptr > 0 && node_ptr < 16) begin
                        reg [3:0] current;
                        current = 0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (stack[stack_ptr-1] == (1 << i)) current <= i;
                        end
                        reg [15:0] neigh_mask;
                        found <= 1'b0;
                        for (neighbor_idx = 0; neighbor_idx < n; neighbor_idx = neighbor_idx + 1) begin
                            if (!found && (transpose[current] & (1 << neighbor_idx)) && !visited[neighbor_idx] && !(stack_mask & (1 << neighbor_idx))) begin
                                found <= 1'b1;
                                visited[neighbor_idx] <= 1'b1;
                                scc_id[neighbor_idx] <= current_scc;
                                stack_mask <= stack_mask | (1 << neighbor_idx);
                                stack[stack_ptr] <= (1 << neighbor_idx);
                                stack_ptr <= stack_ptr + 4'd1;
                                neighbor_idx <= 4'd0;
                            end
                        end
                        if (!found) begin
                            stack_ptr <= stack_ptr - 4'd1;
                            stack_mask <= stack_mask & ~(1 << current);
                            if (stack_ptr == 4'd1 && (node_ptr != 16'hFFFF)) begin
                                // Finished this component
                                current_scc <= current_scc + 4'd1;
                                node_ptr <= (node_ptr == 0) ? 16'hFFFF : node_ptr - 4'd1;
                            end
                        end
                    end
                end

                COMPUTE_OUTDEG: begin
                    // Count SCC sizes
                    if (node_ptr < n) begin
                        reg [3:0] id;
                        id = scc_id[node_ptr];
                        if (id < 16) begin
                            scc_size[id] <= scc_size[id] + 4'd1;
                        end
                        node_ptr <= node_ptr + 4'd1;
                    end else begin
                        node_ptr <= 4'd0;
                        state <= FIND_SINK;
                    end
                    // Compute out-degree in parallel (combinational logic simulation)
                    // This happens over multiple cycles
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (adj[i] & (1 << j)) begin
                                if (scc_id[i] != scc_id[j]) begin
                                    // Add edge to out-degree bitset
                                    scc_outdeg[scc_id[i]] <= scc_outdeg[scc_id[i]] | (1 << scc_id[j]);
                                end
                            end
                        end
                    end
                end

                FIND_SINK: begin
                    // Find SCC with out-degree 0 and minimum size
                    if (node_ptr < 16 && node_ptr < current_scc) begin
                        // Check if this SCC is a sink (outdeg == 0)
                        if (scc_outdeg[node_ptr] == 16'd0) begin
                            if (best_size == 5'd0 || scc_size[node_ptr] < best_size) begin
                                best_scc <= node_ptr;
                                best_size <= {1'b0, scc_size[node_ptr]};
                            end
                        end
                        node_ptr <= node_ptr + 4'd1;
                    end else begin
                        // Mark nodes in best_scc
                        result_size <= best_size;
                        result_indices <= 16'd0;
                        node_ptr <= 4'd0;
                        if (best_size > 5'd0) begin
                            state <= CHECK_TIMER;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                CHECK_TIMER: begin
                    // Fill result_indices for best_scc
                    if (node_ptr < n) begin
                        if (scc_id[node_ptr] == best_scc) begin
                            result_indices <= result_indices | (1 << node_ptr);
                        end
                        node_ptr <= node_ptr + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                    // Check cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule