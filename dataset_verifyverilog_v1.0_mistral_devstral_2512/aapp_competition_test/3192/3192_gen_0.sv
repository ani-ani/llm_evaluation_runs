module shortest_cycle_finder(
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
    reg [2:0] current_start;
    reg [2:0] current_distance;
    reg [7:0] current_set;
    reg [7:0] next_set;
    reg [2:0] current_node;
    reg [2:0] neighbor_idx;
    reg [7:0] dist [0:7];
    reg [2:0] parent [0:7];
    reg [2:0] best_cycle_len;
    reg [23:0] best_cycle;
    reg [2:0] temp_cycle [0:7];
    reg [2:0] temp_idx;

    // Helper to get graph edge
    wire graph_edge = graph[current_node * 8 + neighbor_idx];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_start <= 0;
            current_distance <= 0;
            current_set <= 0;
            next_set <= 0;
            current_node <= 0;
            neighbor_idx <= 0;
            best_cycle_len <= 3'd7;
            best_cycle <= 0;
            temp_idx <= 0;
            done <= 0;
            cycle_length <= 0;
            cycle <= 0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                dist[i] <= 8;
                parent[i] <= 0;
                temp_cycle[i] <= 0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        best_cycle_len <= 3'd7;
                        best_cycle <= 0;
                        current_start <= 0;
                    end
                end
                
                INIT: begin
                    current_start <= current_start + 1;
                end
                
                BFS_INIT: begin
                    current_distance <= 0;
                    current_set <= (1 << current_start);
                    next_set <= 0;
                    dist[current_start] <= 0;
                    
                    // Initialize distances
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i != current_start)
                            dist[i] <= 8;
                    end
                end
                
                BFS_PROCESS: begin
                    if (current_set != 0) begin
                        // Find first set bit in current_set
                        for (i = 0; i < 8; i = i + 1) begin
                            if (current_set[i] && current_node != i) begin
                                current_node <= i;
                                current_set[i] <= 0;
                                neighbor_idx <= 0;
                            end
                        end
                    end else if (current_distance < 4'd8) begin
                        current_distance <= current_distance + 1;
                        current_set <= next_set;
                        next_set <= 0;
                    end
                end
                
                NEXT_START: begin
                    if (current_start >= n - 1) begin
                        if (best_cycle_len == 3'd7) begin
                            cycle_length <= 0;
                            cycle <= 0;
                        end else begin
                            cycle_length <= best_cycle_len;
                            cycle <= best_cycle;
                        end
                        done <= 1;
                    end
                end
            endcase
            
            // Process neighbor
            if (state == BFS_PROCESS && current_set != 0 && neighbor_idx < n) begin
                if (graph_edge) begin
                    if (neighbor_idx == current_start && dist[current_node] != 8) begin
                        // Found cycle
                        if (dist[current_node] + 1 < best_cycle_len) begin
                            best_cycle_len <= dist[current_node] + 1;
                            // Reconstruct cycle
                            temp_cycle[0] <= current_start;
                            temp_cycle[1] <= current_node;
                            temp_idx <= 2;
                            integer j = current_node;
                            for (i = 0; i < 6; i = i + 1) begin
                                if (j == current_start) break;
                                temp_cycle[temp_idx] <= parent[j];
                                temp_idx <= temp_idx + 1;
                                j = parent[j];
                            end
                            // Pack cycle
                            best_cycle <= {temp_cycle[0], temp_cycle[1], temp_cycle[2], 
                                         temp_cycle[3], temp_cycle[4], temp_cycle[5], 
                                         temp_cycle[6], temp_cycle[7]};
                        end
                    end else if (dist[neighbor_idx] > current_distance + 1) begin
                        dist[neighbor_idx] <= current_distance + 1;
                        parent[neighbor_idx] <= current_node;
                        next_set <= next_set | (1 << neighbor_idx);
                    end
                end
                neighbor_idx <= neighbor_idx + 1;
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
                if (current_set == 0 && current_distance >= 4'd8)
                    next_state = NEXT_START;
                else if (current_set == 0)
                    next_state = BFS_PROCESS;
            end
            NEXT_START: begin
                if (current_start >= n - 1)
                    next_state = DONE;
                else
                    next_state = INIT;
            end
            DONE: next_state = IDLE;
        endcase
    end

endmodule