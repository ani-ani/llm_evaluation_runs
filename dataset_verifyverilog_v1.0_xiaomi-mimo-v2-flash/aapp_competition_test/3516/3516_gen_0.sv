module MinimumTimeProblem (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] s_x_i [0:7],
    input wire [31:0] s_i [0:7],
    input wire [31:0] a_flat [0:63],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FIND_MIN = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] i, j; // Loop counters
    reg [7:0] visited_mask;
    reg [2:0] max_item;
    reg [31:0] current_cost;
    reg [31:0] min_edge_cost;
    reg [2:0] next_node;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd6;

    // Memory for a[i][j] (n x n)
    reg [31:0] a_reg [0:7][0:7];

    // For bitmask operations
    integer k;

    // Combinational logic to compute edge cost
    wire [31:0] normal_edge_cost;
    wire [31:0] shortcut_edge_cost;
    wire [31:0] best_edge_cost;

    // Access a_reg[max_item][i] or a_reg[0][i] if max_item < 0 (handled logic)
    // Actually, max_item is index. If max_item is 0 (visited node 0), use a[i][0].
    // Normal cost: a[i][max_item] if i > 0. If i=0 (virtual), cost 0.
    // But we iterate i from 1 to n-1.
    // Problem: a_flat is n*(n+1) values. Indices 0 to n for each i.
    // a_reg[i][j] = time for level i using item j.
    // Our graph: to visit node k (level k), edge from visited set.
    // Min cost to k is min over visited nodes l of edge_cost(l, k).
    // Edge l->k:
    // 1. Normal: a[k][j_l] where j_l is max item at l.
    //    Here, j_l is max_item (since we track global max item from visited set).
    //    Wait, Prim's tracks global visited set. The cost to add k depends on the edge.
    //    The edge weight is a[k][max_item].
    // 2. Shortcut: if s_x_i[k] is visited (mask has bit s_x_i[k]), cost is s_i[k].

    // Determine max_item from visited_mask
    // Max item is the highest index bit set in visited_mask.
    // Since n <= 8, we can use a priority encoder logic.
    reg [2:0] current_max_item;
    always @(*) begin
        current_max_item = 3'd0;
        // Find highest set bit
        if (visited_mask[7]) current_max_item = 3'd7;
        else if (visited_mask[6]) current_max_item = 3'd6;
        else if (visited_mask[5]) current_max_item = 3'd5;
        else if (visited_mask[4]) current_max_item = 3'd4;
        else if (visited_mask[3]) current_max_item = 3'd3;
        else if (visited_mask[2]) current_max_item = 3'd2;
        else if (visited_mask[1]) current_max_item = 3'd1;
        else current_max_item = 3'd0;
    end

    // Normal edge cost logic
    // For node i (target), using current max item
    // Note: a_flat mapping. a[i][j] where i is 0..n-1, j is 0..n.
    // a_flat index = i * (n+1) + j.
    // a_reg is 8x8. We populate it.
    // If we try to reach node k using item j, cost is a[k][j].
    // Normal cost: a[k][current_max_item].
    // Note: virtual node 0 corresponds to item 0 availability initially.
    // Item index j corresponds to level j (0..n-1).
    
    assign normal_edge_cost = a_reg[next_node][current_max_item];
    
    // Shortcut edge cost logic
    // If shortcut item s_x_i[next_node] is in visited_mask
    wire shortcut_available;
    assign shortcut_available = visited_mask[s_x_i[next_node]];
    assign shortcut_edge_cost = s_i[next_node];
    
    // Best edge cost for next_node
    assign best_edge_cost = (shortcut_available && (shortcut_edge_cost < normal_edge_cost)) ? 
                            shortcut_edge_cost : normal_edge_cost;

    // Next state and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 3'd0;
            visited_mask <= 8'd0;
            current_cost <= 32'd0;
            min_edge_cost <= 32'hFFFFFFFF;
            next_node <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            // Initialize a_reg to 0
            for (k = 0; k < 8; k = k + 1) begin
                for (int m = 0; m < 8; m = m + 1) begin
                    a_reg[k][m] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    current_cost <= 32'd0;
                    visited_mask <= 8'd0;
                    result <= 32'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Populate a_reg from a_flat
                    // a_flat is 64 entries, but we only use n*(n+1)
                    // We iterate i from 0 to n-1, j from 0 to n
                    // We need a loop counter here
                    // Since we can't use fancy for loops easily with variables in synthesis sometimes,
                    // let's use state logic or just assume it's fast enough for n<=8.
                    // Actually, let's just iterate i and j.
                    // We need a temporary counter for flat indexing.
                    // Let's use 'i' for row, 'j' for col.
                    if (i < n) begin
                        if (j < n + 1) begin
                            a_reg[i][j] <= a_flat[i * (n + 1) + j];
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        // Initialization done
                        i <= 3'd0; // Reset i for main loop
                        j <= 3'd0; // Reset j for inner loop
                        // Start Prim's: Add virtual node 0 to visited
                        visited_mask <= 8'b00000001; // Node 0 visited
                        // Max item is 0 (from node 0)
                        state <= FIND_MIN;
                    end
                end

                FIND_MIN: begin
                    // Find node not in visited with minimum edge cost
                    // Iterate i from 1 to n-1 (nodes to add)
                    // Note: We need to add n-1 nodes (since 0 is already visited)
                    // Total nodes are 1..n-1 (n-1 nodes)
                    // Wait, nodes are 0..n-1. Visited 0. Need 1..n-1 (total n-1 nodes).
                    // Cycle count tracks added nodes.
                    
                    if (i < n) begin
                        // Check if node i is not visited
                        if (!visited_mask[i]) begin
                            // Calculate cost
                            // current_max_item is computed combinationally from visited_mask
                            // best_edge_cost is computed combinationally for next_node = i
                            // We need to compare this cost with min_edge_cost
                            if (best_edge_cost < min_edge_cost) begin
                                min_edge_cost <= best_edge_cost;
                                next_node <= i;
                            end
                        end
                        i <= i + 3'd1;
                    end else begin
                        // Finished scanning all nodes
                        i <= 3'd0; // Reset for next iteration or usage
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Add next_node to visited set
                    visited_mask[next_node] <= 1'b1;
                    // Add cost
                    current_cost <= current_cost + min_edge_cost;
                    // Increment cycle count (number of added nodes)
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Prepare for next round
                    min_edge_cost <= 32'hFFFFFFFF;
                    i <= 3'd0;
                    next_node <= 3'd0;
                    
                    // Check if we are done
                    // We start with 1 node (0). We need to add n-1 nodes.
                    // cycle_count tracks how many we added.
                    // If cycle_count == n-1, we are done.
                    if (cycle_count == n - 3'd1) begin
                        state <= FINISH;
                    end else begin
                        state <= FIND_MIN;
                    end
                end

                FINISH: begin
                    result <= current_cost;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule