module FriendshipGraph(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [21:0] adj_matrix [0:21],
    output reg [4:0] step_count,
    output reg [21:0] steps,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Internal registers
    reg [21:0] current_adj [0:21];
    reg [21:0] current_edges [0:21];
    reg [21:0] selected_nodes;
    reg [4:0] current_step;
    reg [4:0] best_node;
    reg [10:0] max_new_edges;
    reg [10:0] new_edges;
    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 5'd0;
            steps <= 22'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_step <= 5'd0;
            selected_nodes <= 22'd0;
            
            // Initialize adjacency matrix
            for (i = 0; i < 22; i = i + 1) begin
                current_adj[i] <= 22'd0;
                current_edges[i] <= 22'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    current_step <= 5'd0;
                    selected_nodes <= 22'd0;
                    
                    // Load adjacency matrix
                    for (i = 0; i < 22; i = i + 1) begin
                        current_adj[i] <= adj_matrix[i];
                        current_edges[i] <= adj_matrix[i];
                    end
                    
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if all edges exist (graph is complete)
                    reg all_connected;
                    all_connected = 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = i + 1; j < n; j = j + 1) begin
                            if (!current_edges[i][j]) begin
                                all_connected = 1'b0;
                            end
                        end
                    end
                    
                    if (all_connected || current_step >= 22 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Greedy selection: find node that creates most new edges
                        max_new_edges <= 11'd0;
                        best_node <= 5'd0;
                        
                        for (i = 0; i < n; i = i + 1) begin
                            if (!selected_nodes[i]) begin
                                new_edges <= 11'd0;
                                
                                // Count new edges created by selecting node i
                                for (j = 0; j < n; j = j + 1) begin
                                    if (current_adj[i][j] && j != i) begin
                                        for (k = j + 1; k < n; k = k + 1) begin
                                            if (current_adj[i][k] && !current_edges[j][k]) begin
                                                new_edges <= new_edges + 11'd1;
                                            end
                                        end
                                    end
                                end
                                
                                if (new_edges > max_new_edges) begin
                                    max_new_edges <= new_edges;
                                    best_node <= i;
                                end
                            end
                        end
                        
                        // Apply the selected node's effect
                        selected_nodes[best_node] <= 1'b1;
                        steps[current_step] <= best_node;
                        
                        // Update edges: make all friends of best_node connected
                        for (j = 0; j < n; j = j + 1) begin
                            if (current_adj[best_node][j] && j != best_node) begin
                                for (k = j + 1; k < n; k = k + 1) begin
                                    if (current_adj[best_node][k]) begin
                                        current_edges[j][k] <= 1'b1;
                                        current_edges[k][j] <= 1'b1;
                                    end
                                end
                            end
                        end
                        
                        current_step <= current_step + 5'd1;
                    end
                end
                
                FINISH: begin
                    step_count <= current_step;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule