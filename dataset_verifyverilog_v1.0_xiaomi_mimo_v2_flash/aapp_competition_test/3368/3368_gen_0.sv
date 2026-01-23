module euler_animal_check(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [15:0][3:0] src,
    input [15:0][3:0] dst,
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] PROCESS_EDGES  = 3'd1;
    localparam [2:0] CHECK_DEGREES  = 3'd2;
    localparam [2:0] CHECK_CONNECT  = 3'd3;
    localparam [2:0] FINISH         = 3'd4;

    // Result encoding
    localparam [1:0] FALSE_ALARM = 2'd0;
    localparam [1:0] POSSIBLE    = 2'd1;
    localparam [1:0] IMPOSSIBLE  = 2'd2;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] cycle_counter;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // Edge processing
    reg [4:0] edge_idx;
    
    // Degree arrays (8 nodes, max degree 16)
    reg [4:0] indeg [0:7];
    reg [4:0] outdeg [0:7];
    reg [4:0] total_deg [0:7];
    
    // Adjacency matrix (8x8 bits)
    reg [7:0] adj [0:7];
    
    // BFS state
    reg [7:0] visited;
    reg [7:0] queue [0:7];
    reg [3:0] queue_front;
    reg [3:0] queue_back;
    reg [3:0] bfs_node;
    reg [3:0] i;
    reg [3:0] j;
    
    // Degree check results
    reg [3:0] start_count;
    reg [3:0] end_count;
    reg degree_error;
    
    // Connectivity check
    reg connectivity_error;
    reg [3:0] node_with_deg;
    reg [7:0] reachable_count;
    reg [3:0] current_node;
    reg [3:0] neighbor;
    reg [7:0] reachable_nodes;

    // Helper function for array access (since Icarus doesn't support some array operations)
    function automatic [7:0] get_adj_row(input [3:0] node);
        begin
            case (node)
                4'd0: get_adj_row = adj[0];
                4'd1: get_adj_row = adj[1];
                4'd2: get_adj_row = adj[2];
                4'd3: get_adj_row = adj[3];
                4'd4: get_adj_row = adj[4];
                4'd5: get_adj_row = adj[5];
                4'd6: get_adj_row = adj[6];
                4'd7: get_adj_row = adj[7];
                default: get_adj_row = 8'd0;
            endcase
        end
    endfunction

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS_EDGES;
                else
                    next_state = IDLE;
            end
            PROCESS_EDGES: begin
                if (edge_idx >= m || cycle_counter >= MAX_CYCLES)
                    next_state = CHECK_DEGREES;
                else
                    next_state = PROCESS_EDGES;
            end
            CHECK_DEGREES: begin
                next_state = CHECK_CONNECT;
            end
            CHECK_CONNECT: begin
                // BFS completes when queue is empty or error detected
                if (queue_front >= queue_back || connectivity_error || cycle_counter >= MAX_CYCLES)
                    next_state = FINISH;
                else
                    next_state = CHECK_CONNECT;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= FALSE_ALARM;
            done <= 1'b0;
            cycle_counter <= 5'd0;
            edge_idx <= 5'd0;
            start_count <= 4'd0;
            end_count <= 4'd0;
            degree_error <= 1'b0;
            connectivity_error <= 1'b0;
            queue_front <= 4'd0;
            queue_back <= 4'd0;
            visited <= 8'd0;
            reachable_nodes <= 8'd0;
            reachable_count <= 8'd0;
            current_node <= 4'd0;
            node_with_deg <= 4'd0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                indeg[i] <= 5'd0;
                outdeg[i] <= 5'd0;
                total_deg[i] <= 5'd0;
                adj[i] <= 8'd0;
                queue[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 5'd0;
                    edge_idx <= 5'd0;
                    start_count <= 4'd0;
                    end_count <= 4'd0;
                    degree_error <= 1'b0;
                    connectivity_error <= 1'b0;
                    queue_front <= 4'd0;
                    queue_back <= 4'd0;
                    visited <= 8'd0;
                    reachable_nodes <= 8'd0;
                    reachable_count <= 8'd0;
                    current_node <= 4'd0;
                    node_with_deg <= 4'd0;
                    // Initialize arrays
                    for (i = 0; i < 8; i = i + 1) begin
                        indeg[i] <= 5'd0;
                        outdeg[i] <= 5'd0;
                        total_deg[i] <= 5'd0;
                        adj[i] <= 8'd0;
                        queue[i] <= 4'd0;
                    end
                end
                
                PROCESS_EDGES: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    if (edge_idx < m) begin
                        // Process edge edge_idx
                        // Update degrees (using src[0]..src[15] and dst[0]..dst[15])
                        // Note: Using case to access array elements
                        case (edge_idx)
                            5'd0: begin
                                outdeg[src[0]] <= outdeg[src[0]] + 5'd1;
                                indeg[dst[0]] <= indeg[dst[0]] + 5'd1;
                                total_deg[src[0]] <= total_deg[src[0]] + 5'd1;
                                total_deg[dst[0]] <= total_deg[dst[0]] + 5'd1;
                                adj[src[0]][dst[0]] <= 1'b1;
                                adj[dst[0]][src[0]] <= 1'b1;
                            end
                            5'd1: begin
                                outdeg[src[1]] <= outdeg[src[1]] + 5'd1;
                                indeg[dst[1]] <= indeg[dst[1]] + 5'd1;
                                total_deg[src[1]] <= total_deg[src[1]] + 5'd1;
                                total_deg[dst[1]] <= total_deg[dst[1]] + 5'd1;
                                adj[src[1]][dst[1]] <= 1'b1;
                                adj[dst[1]][src[1]] <= 1'b1;
                            end
                            5'd2: begin
                                outdeg[src[2]] <= outdeg[src[2]] + 5'd1;
                                indeg[dst[2]] <= indeg[dst[2]] + 5'd1;
                                total_deg[src[2]] <= total_deg[src[2]] + 5'd1;
                                total_deg[dst[2]] <= total_deg[dst[2]] + 5'd1;
                                adj[src[2]][dst[2]] <= 1'b1;
                                adj[dst[2]][src[2]] <= 1'b1;
                            end
                            5'd3: begin
                                outdeg[src[3]] <= outdeg[src[3]] + 5'd1;
                                indeg[dst[3]] <= indeg[dst[3]] + 5'd1;
                                total_deg[src[3]] <= total_deg[src[3]] + 5'd1;
                                total_deg[dst[3]] <= total_deg[dst[3]] + 5'd1;
                                adj[src[3]][dst[3]] <= 1'b1;
                                adj[dst[3]][src[3]] <= 1'b1;
                            end
                            5'd4: begin
                                outdeg[src[4]] <= outdeg[src[4]] + 5'd1;
                                indeg[dst[4]] <= indeg[dst[4]] + 5'd1;
                                total_deg[src[4]] <= total_deg[src[4]] + 5'd1;
                                total_deg[dst[4]] <= total_deg[dst[4]] + 5'd1;
                                adj[src[4]][dst[4]] <= 1'b1;
                                adj[dst[4]][src[4]] <= 1'b1;
                            end
                            5'd5: begin
                                outdeg[src[5]] <= outdeg[src[5]] + 5'd1;
                                indeg[dst[5]] <= indeg[dst[5]] + 5'd1;
                                total_deg[src[5]] <= total_deg[src[5]] + 5'd1;
                                total_deg[dst[5]] <= total_deg[dst[5]] + 5'd1;
                                adj[src[5]][dst[5]] <= 1'b1;
                                adj[dst[5]][src[5]] <= 1'b1;
                            end
                            5'd6: begin
                                outdeg[src[6]] <= outdeg[src[6]] + 5'd1;
                                indeg[dst[6]] <= indeg[dst[6]] + 5'd1;
                                total_deg[src[6]] <= total_deg[src[6]] + 5'd1;
                                total_deg[dst[6]] <= total_deg[dst[6]] + 5'd1;
                                adj[src[6]][dst[6]] <= 1'b1;
                                adj[dst[6]][src[6]] <= 1'b1;
                            end
                            5'd7: begin
                                outdeg[src[7]] <= outdeg[src[7]] + 5'd1;
                                indeg[dst[7]] <= indeg[dst[7]] + 5'd1;
                                total_deg[src[7]] <= total_deg[src[7]] + 5'd1;
                                total_deg[dst[7]] <= total_deg[dst[7]] + 5'd1;
                                adj[src[7]][dst[7]] <= 1'b1;
                                adj[dst[7]][src[7]] <= 1'b1;
                            end
                            5'd8: begin
                                outdeg[src[8]] <= outdeg[src[8]] + 5'd1;
                                indeg[dst[8]] <= indeg[dst[8]] + 5'd1;
                                total_deg[src[8]] <= total_deg[src[8]] + 5'd1;
                                total_deg[dst[8]] <= total_deg[dst[8]] + 5'd1;
                                adj[src[8]][dst[8]] <= 1'b1;
                                adj[dst[8]][src[8]] <= 1'b1;
                            end
                            5'd9: begin
                                outdeg[src[9]] <= outdeg[src[9]] + 5'd1;
                                indeg[dst[9]] <= indeg[dst[9]] + 5'd1;
                                total_deg[src[9]] <= total_deg[src[9]] + 5'd1;
                                total_deg[dst[9]] <= total_deg[dst[9]] + 5'd1;
                                adj[src[9]][dst[9]] <= 1'b1;
                                adj[dst[9]][src[9]] <= 1'b1;
                            end
                            5'd10: begin
                                outdeg[src[10]] <= outdeg[src[10]] + 5'd1;
                                indeg[dst[10]] <= indeg[dst[10]] + 5'd1;
                                total_deg[src[10]] <= total_deg[src[10]] + 5'd1;
                                total_deg[dst[10]] <= total_deg[dst[10]] + 5'd1;
                                adj[src[10]][dst[10]] <= 1'b1;
                                adj[dst[10]][src[10]] <= 1'b1;
                            end
                            5'd11: begin
                                outdeg[src[11]] <= outdeg[src[11]] + 5'd1;
                                indeg[dst[11]] <= indeg[dst[11]] + 5'd1;
                                total_deg[src[11]] <= total_deg[src[11]] + 5'd1;
                                total_deg[dst[11]] <= total_deg[dst[11]] + 5'd1;
                                adj[src[11]][dst[11]] <= 1'b1;
                                adj[dst[11]][src[11]] <= 1'b1;
                            end
                            5'd12: begin
                                outdeg[src[12]] <= outdeg[src[12]] + 5'd1;
                                indeg[dst[12]] <= indeg[dst[12]] + 5'd1;
                                total_deg[src[12]] <= total_deg[src[12]] + 5'd1;
                                total_deg[dst[12]] <= total_deg[dst[12]] + 5'd1;
                                adj[src[12]][dst[12]] <= 1'b1;
                                adj[dst[12]][src[12]] <= 1'b1;
                            end
                            5'd13: begin
                                outdeg[src[13]] <= outdeg[src[13]] + 5'd1;
                                indeg[dst[13]] <= indeg[dst[13]] + 5'd1;
                                total_deg[src[13]] <= total_deg[src[13]] + 5'd1;
                                total_deg[dst[13]] <= total_deg[dst[13]] + 5'd1;
                                adj[src[13]][dst[13]] <= 1'b1;
                                adj[dst[13]][src[13]] <= 1'b1;
                            end
                            5'd14: begin
                                outdeg[src[14]] <= outdeg[src[14]] + 5'd1;
                                indeg[dst[14]] <= indeg[dst[14]] + 5'd1;
                                total_deg[src[14]] <= total_deg[src[14]] + 5'd1;
                                total_deg[dst[14]] <= total_deg[dst[14]] + 5'd1;
                                adj[src[14]][dst[14]] <= 1'b1;
                                adj[dst[14]][src[14]] <= 1'b1;
                            end
                            5'd15: begin
                                outdeg[src[15]] <= outdeg[src[15]] + 5'd1;
                                indeg[dst[15]] <= indeg[dst[15]] + 5'd1;
                                total_deg[src[15]] <= total_deg[src[15]] + 5'd1;
                                total_deg[dst[15]] <= total_deg[dst[15]] + 5'd1;
                                adj[src[15]][dst[15]] <= 1'b1;
                                adj[dst[15]][src[15]] <= 1'b1;
                            end
                            default: begin
                                // No operation
                            end
                        endcase
                        edge_idx <= edge_idx + 5'd1;
                    end
                end
                
                CHECK_DEGREES: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    // Check degree conditions for nodes 0..7
                    if (j < 8) begin
                        // Check node j
                        if (total_deg[j] > 5'd0) begin
                            // Node with edges
                            if (outdeg[j] == indeg[j]) begin
                                // Balanced - no count
                            end else if (outdeg[j] == indeg[j] + 5'd1) begin
                                start_count <= start_count + 4'd1;
                            end else if (indeg[j] == outdeg[j] + 5'd1) begin
                                end_count <= end_count + 4'd1;
                            end else begin
                                degree_error <= 1'b1;
                            end
                        end else begin
                            // No edges - no issue
                        end
                        j <= j + 4'd1;
                    end
                    // Done when all nodes checked
                    if (j >= 8) begin
                        if (start_count > 4'd1 || end_count > 4'd1 || degree_error)
                            result <= IMPOSSIBLE;
                        else
                            result <= POSSIBLE;
                    end
                end
                
                CHECK_CONNECT: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    // BFS from first node with degree > 0
                    if (queue_front == 4'd0 && queue_back == 4'd0) begin
                        // First time - find node with degree
                        if (node_with_deg < 8) begin
                            if (total_deg[node_with_deg] > 5'd0) begin
                                visited[node_with_deg] <= 1'b1;
                                queue[0] <= node_with_deg;
                                queue_back <= 4'd1;
                                queue_front <= 4'd0;
                            end
                            node_with_deg <= node_with_deg + 4'd1;
                        end else if (node_with_deg >= 8) begin
                            // No nodes with degree - graph is empty
                            connectivity_error <= 1'b0;
                        end
                    end else if (queue_front < queue_back) begin
                        // Process front of queue
                        current_node <= queue[queue_front];
                        queue_front <= queue_front + 4'd1;
                    end else if (current_node < 8) begin
                        // Process neighbors of current_node
                        if (neighbor < 8) begin
                            // Check if neighbor is connected
                            if (adj[current_node][neighbor] && !visited[neighbor]) begin
                                visited[neighbor] <= 1'b1;
                                queue[queue_back] <= neighbor;
                                queue_back <= queue_back + 4'd1;
                            end
                            neighbor <= neighbor + 4'd1;
                        end else begin
                            // Done processing neighbors
                            current_node <= 4'd8;
                            neighbor <= 4'd0;
                        end
                    end else begin
                        // Check all nodes with degree for connectivity
                        if (reachable_count < 8) begin
                            if (total_deg[reachable_count] > 5'd0 && !visited[reachable_count]) begin
                                connectivity_error <= 1'b1;
                                result <= IMPOSSIBLE;
                            end
                            reachable_count <= reachable_count + 8'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Keep result as set in previous state
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule