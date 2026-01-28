module shortest_cycle_finder (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [63:0] graph,
    output reg done,
    output reg [2:0] cycle_length,
    output reg [23:0] cycle
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BFS_INIT = 3'd2;
    localparam [2:0] BFS_PROCESS = 3'd3;
    localparam [2:0] NEXT_START = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [2:0] current_start;        // Current start node for BFS
    reg [2:0] current_distance;     // Current BFS distance
    reg [7:0] current_set;          // Nodes at current distance
    reg [7:0] next_set;             // Nodes for next distance
    reg [2:0] current_node;         // Currently processing node
    reg [2:0] neighbor_idx;         // Current neighbor index
    reg [2:0] dist [0:7];           // Distance from start node
    reg [2:0] parent [0:7];         // Parent in BFS tree
    reg [2:0] best_cycle_len;       // Best cycle length found
    reg [23:0] best_cycle;          // Best cycle (packed)
    reg [2:0] temp_cycle [0:7];     // Temporary cycle storage
    reg [2:0] temp_idx;             // Temp index for reconstruction
    reg [7:0] neighbor_mask;        // Mask for neighbor bits
    reg [2:0] bfs_node;             // Node for BFS processing
    reg bfs_found_node;             // Flag for found node
    reg [2:0] i;                    // Loop variable
    reg [2:0] j;                    // Loop variable

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_start <= 3'd0;
            current_distance <= 3'd0;
            current_set <= 8'd0;
            next_set <= 8'd0;
            current_node <= 3'd0;
            neighbor_idx <= 3'd0;
            best_cycle_len <= 3'd7; // Initialize with max+1
            best_cycle <= 24'd0;
            temp_idx <= 3'd0;
            done <= 1'b0;
            cycle_length <= 3'd0;
            cycle <= 24'd0;
            neighbor_mask <= 8'd0;
            bfs_node <= 3'd0;
            bfs_found_node <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        best_cycle_len <= 3'd7;
                        best_cycle <= 24'd0;
                        current_start <= 3'd0;
                        // Initialize distances
                        for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                            dist[i] <= 3'd7;
                            parent[i] <= 3'd0;
                        end
                        // Initialize temp_cycle
                        for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                            temp_cycle[i] <= 3'd0;
                        end
                    end
                end
                
                INIT: begin
                    // Prepare for next start node
                    current_start <= current_start + 3'd1;
                end
                
                BFS_INIT: begin
                    // Initialize BFS for current_start
                    current_distance <= 3'd0;
                    current_set <= (8'd1 << current_start);
                    next_set <= 8'd0;
                    dist[current_start] <= 3'd0;
                    // Initialize distances to 7 (infinity)
                    for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                        if (i != current_start)
                            dist[i] <= 3'd7;
                    end
                end
                
                BFS_PROCESS: begin
                    if (current_set != 8'd0) begin
                        // Find first set bit in current_set
                        bfs_found_node <= 1'b0;
                        for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                            if (!bfs_found_node && current_set[i]) begin
                                bfs_node <= i;
                                bfs_found_node <= 1'b1;
                            end
                        end
                    end else if (current_distance < 4'd7) begin
                        // Move to next distance level
                        current_distance <= current_distance + 3'd1;
                        current_set <= next_set;
                        next_set <= 8'd0;
                    end
                end
                
                NEXT_START: begin
                    // Move to next start node or finish
                    if (current_start >= n - 3'd1) begin
                        // All start nodes processed
                        if (best_cycle_len == 3'd7) begin
                            cycle_length <= 3'd0;
                            cycle <= 24'd0;
                        end else begin
                            cycle_length <= best_cycle_len;
                            cycle <= best_cycle;
                        end
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                end
            endcase
            
            // Process neighbor logic (moved from separate always block)
            if (state == BFS_PROCESS && bfs_found_node && current_set != 8'd0) begin
                current_node <= bfs_node;
                neighbor_idx <= 3'd0;
                neighbor_mask <= 8'd0;
                // Clear the processed bit from current_set
                current_set[bfs_node] <= 1'b0;
            end
            
            if (state == BFS_PROCESS && current_set == 8'd0 && bfs_found_node == 1'b0 && neighbor_idx < n) begin
                // Get neighbor bits for current_node
                neighbor_mask <= 8'd0;
                for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                    if (i < n && graph[current_node * 3'd8 + i]) begin
                        neighbor_mask[i] <= 1'b1;
                    end
                end
                
                // Process neighbor
                if (neighbor_mask[neighbor_idx]) begin
                    if (neighbor_idx == current_start && dist[current_node] != 3'd7) begin
                        // Found cycle
                        best_cycle_len <= dist[current_node] + 3'd1;
                        // Reconstruct cycle
                        temp_idx <= dist[current_node];
                        temp_cycle[dist[current_node]] <= current_start;
                        for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                            if (j < dist[current_node]) begin
                                temp_cycle[j] <= parent[current_node];
                            end
                        end
                        // Pack temp_cycle into best_cycle
                        best_cycle[23:21] <= temp_cycle[7];
                        best_cycle[20:18] <= temp_cycle[6];
                        best_cycle[17:15] <= temp_cycle[5];
                        best_cycle[14:12] <= temp_cycle[4];
                        best_cycle[11:9] <= temp_cycle[3];
                        best_cycle[8:6] <= temp_cycle[2];
                        best_cycle[5:3] <= temp_cycle[1];
                        best_cycle[2:0] <= temp_cycle[0];
                    end else if (dist[neighbor_idx] > current_distance + 3'd1) begin
                        dist[neighbor_idx] <= current_distance + 3'd1;
                        parent[neighbor_idx] <= current_node;
                        next_set <= next_set | (8'd1 << neighbor_idx);
                    end
                end
                neighbor_idx <= neighbor_idx + 3'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = BFS_INIT;
            BFS_INIT: next_state = BFS_PROCESS;
            BFS_PROCESS: begin
                if (current_set == 8'd0 && bfs_found_node == 1'b0 && neighbor_idx >= n && current_distance >= 4'd7)
                    next_state = NEXT_START;
                else if (current_set == 8'd0 && bfs_found_node == 1'b0 && neighbor_idx >= n)
                    next_state = BFS_PROCESS; // Continue to next distance
            end
            NEXT_START: begin
                if (current_start >= n - 3'd1)
                    next_state = DONE;
                else
                    next_state = INIT;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule