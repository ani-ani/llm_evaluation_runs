module GraphDecorator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [3:0] num_edges,
    input wire [3:0] graph_edges [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] VALIDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Edge cost encoding: 2 bits per edge (00=0, 01=1, 10=2)
    reg [1:0] edge_costs [0:15];
    reg [3:0] current_edge;
    reg [1:0] current_cost;
    reg [2:0] state;
    reg [15:0] min_cost;
    reg [15:0] current_total;
    reg [15:0] cycle_count;
    reg [3:0] i, j, k;
    reg [3:0] node_degrees [0:7];
    reg [3:0] edge_list [0:15];
    reg [3:0] node1, node2;
    reg valid_assignment;
    reg [3:0] cycle_nodes [0:7];
    reg [3:0] cycle_length;
    reg [3:0] visited [0:7];
    reg [3:0] path [0:7];
    reg [3:0] path_len;
    reg [15:0] cycle_sum;
    reg [3:0] u, v, w;
    reg [1:0] c1, c2;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            min_cost <= 16'd0;
            current_total <= 16'd0;
            cycle_count <= 16'd0;
            current_edge <= 4'd0;
            current_cost <= 2'd0;
            valid_assignment <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                edge_costs[i] <= 2'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                node_degrees[i] <= 4'd0;
                visited[i] <= 4'd0;
                path[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        min_cost <= 16'd0;
                        current_total <= 16'd0;
                        cycle_count <= 16'd0;
                        current_edge <= 4'd0;
                        current_cost <= 2'd0;
                        valid_assignment <= 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            edge_costs[i] <= 2'd0;
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            node_degrees[i] <= 4'd0;
                            visited[i] <= 4'd0;
                            path[i] <= 4'd0;
                        end
                    end
                end

                INIT: begin
                    // Initialize edge list and node degrees
                    for (i = 0; i < 16; i = i + 1) begin
                        edge_list[i] <= graph_edges[i];
                    end
                    for (i = 0; i < 8; i = i + 1) begin
                        node_degrees[i] <= 4'd0;
                    end
                    for (i = 0; i < num_edges; i = i + 1) begin
                        node1 <= edge_list[i][3:0];
                        node2 <= edge_list[i][7:4];
                        node_degrees[node1] <= node_degrees[node1] + 4'd1;
                        node_degrees[node2] <= node_degrees[node2] + 4'd1;
                    end
                    state <= CHECK;
                end

                CHECK: begin
                    // Check if current assignment is valid
                    valid_assignment <= 1'b1;
                    
                    // Check node constraints
                    for (u = 0; u < num_nodes; u = u + 1) begin
                        if (node_degrees[u] >= 2) begin
                            // Find two edges incident to u
                            j <= 4'd0;
                            k <= 4'd0;
                            for (i = 0; i < num_edges; i = i + 1) begin
                                node1 <= edge_list[i][3:0];
                                node2 <= edge_list[i][7:4];
                                if (node1 == u || node2 == u) begin
                                    if (j == 4'd0) begin
                                        j <= i;
                                    end else if (k == 4'd0) begin
                                        k <= i;
                                    end
                                end
                            end
                            if (j != 4'd0 && k != 4'd0) begin
                                c1 <= edge_costs[j];
                                c2 <= edge_costs[k];
                                if ((c1 + c2) % 3 == 2'd1) begin
                                    valid_assignment <= 1'b0;
                                end
                            end
                        end
                    end
                    
                    // Check cycle constraints
                    if (valid_assignment) begin
                        // Simple cycle detection for small graphs
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            // Reset visited and path
                            for (j = 0; j < 8; j = j + 1) begin
                                visited[j] <= 4'd0;
                                path[j] <= 4'd0;
                            end
                            path_len <= 4'd0;
                            visited[i] <= 4'd1;
                            path[0] <= i;
                            path_len <= path_len + 4'd1;
                            
                            // DFS to find cycles
                            for (j = 0; j < num_nodes; j = j + 1) begin
                                if (visited[j] == 4'd0) begin
                                    // Check if there's an edge from last node in path to j
                                    node1 <= path[path_len - 4'd1];
                                    for (k = 0; k < num_edges; k = k + 1) begin
                                        if ((edge_list[k][3:0] == node1 && edge_list[k][7:4] == j) ||
                                            (edge_list[k][7:4] == node1 && edge_list[k][3:0] == j)) begin
                                            visited[j] <= 4'd1;
                                            path[path_len] <= j;
                                            path_len <= path_len + 4'd1;
                                            
                                            // Check if j connects back to i (cycle)
                                            for (k = 0; k < num_edges; k = k + 1) begin
                                                if ((edge_list[k][3:0] == j && edge_list[k][7:4] == i) ||
                                                    (edge_list[k][7:4] == j && edge_list[k][3:0] == i)) begin
                                                    // Found a cycle
                                                    cycle_sum <= 16'd0;
                                                    for (w = 0; w < path_len; w = w + 1) begin
                                                        node1 <= path[w];
                                                        node2 <= path[(w + 4'd1) % path_len];
                                                        for (k = 0; k < num_edges; k = k + 1) begin
                                                            if ((edge_list[k][3:0] == node1 && edge_list[k][7:4] == node2) ||
                                                                (edge_list[k][7:4] == node1 && edge_list[k][3:0] == node2)) begin
                                                                cycle_sum <= cycle_sum + edge_costs[k];
                                                            end
                                                        end
                                                    end
                                                    if (cycle_sum[0] == 1'b0) begin
                                                        valid_assignment <= 1'b0;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if (valid_assignment) begin
                        state <= VALIDATE;
                    end else begin
                        // Increment cost for current edge
                        current_cost <= current_cost + 2'd1;
                        if (current_cost == 2'd3) begin
                            current_cost <= 2'd0;
                            current_edge <= current_edge + 4'd1;
                            if (current_edge == num_edges) begin
                                state <= FINISH;
                            end
                        end
                        edge_costs[current_edge] <= current_cost;
                    end
                end

                VALIDATE: begin
                    // Calculate total cost
                    current_total <= 16'd0;
                    for (i = 0; i < num_edges; i = i + 1) begin
                        current_total <= current_total + edge_costs[i];
                    end
                    
                    // Update min_cost
                    if (min_cost == 16'd0 || current_total < min_cost) begin
                        min_cost <= current_total;
                    end
                    
                    // Move to next assignment
                    current_cost <= current_cost + 2'd1;
                    if (current_cost == 2'd3) begin
                        current_cost <= 2'd0;
                        current_edge <= current_edge + 4'd1;
                        if (current_edge == num_edges) begin
                            state <= FINISH;
                        end
                    end
                    edge_costs[current_edge] <= current_cost;
                    state <= CHECK;
                end

                FINISH: begin
                    if (min_cost == 16'd0) begin
                        result <= 16'hFFFF;
                    end else begin
                        result <= min_cost;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule