module secure_network(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] p_mask,
    input edge_valid,
    input [3:0] edge_u,
    input [3:0] edge_v,
    input [11:0] edge_w,
    input edge_end,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);
    // Constants
    localparam [4:0] MAX_EDGES = 5'd32;
    localparam [4:0] MAX_NODES = 5'd16;
    localparam [5:0] MAX_CYCLES = 6'd50;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_EDGES = 3'd1;
    localparam [2:0] SORT_EDGES = 3'd2;
    localparam [2:0] INIT_MST = 3'd3;
    localparam [2:0] PROCESS_EDGES = 3'd4;
    localparam [2:0] CHECK_CONNECTIVITY = 3'd5;
    localparam [2:0] DONE = 3'd6;
    
    // Registers
    reg [2:0] state, next_state;
    reg [4:0] edge_count;
    reg [5:0] cycle_count;
    
    // Edge buffer - 32 entries of {u[3:0], v[3:0], w[11:0]}
    reg [18:0] edge_buf [0:31];
    
    // Sorting registers
    reg [4:0] sort_i, sort_j;
    reg [18:0] temp_edge;
    reg sort_done;
    
    // MST registers
    reg [4:0] mst_idx;
    reg [15:0] total_cost;
    reg [3:0] parent [0:15];
    reg [3:0] degree [0:15];
    reg [3:0] find_u, find_v;
    reg [3:0] root_u, root_v;
    
    // Connectivity check
    reg [3:0] check_node;
    reg [3:0] common_root;
    reg [3:0] conn_idx;
    
    // Helper signals
    reg is_insecure_u, is_insecure_v;
    reg [3:0] u_node, v_node;
    reg [11:0] w_val;
    reg [3:0] find_depth;
    reg find_path [0:31];
    reg [4:0] fp_idx;
    reg [3:0] temp_find;
    
    // Find function with path compression
    function [3:0] find_root(input [3:0] node);
        begin
            temp_find = node;
            // Find root
            while (parent[temp_find] != temp_find) begin
                temp_find = parent[temp_find];
            end
            find_root = temp_find;
        end
    endfunction
    
    // Union function
    function union_nodes(input [3:0] a, input [3:0] b);
        begin
            root_u = find_root(a);
            root_v = find_root(b);
            if (root_u != root_v) begin
                parent[root_u] = root_v;
                union_nodes = 1'b1;
            end else begin
                union_nodes = 1'b0;
            end
        end
    endfunction
    
    // Helper to check if node is insecure
    function check_insecure(input [3:0] node);
        begin
            check_insecure = p_mask[node];
        end
    endfunction
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            edge_count <= 5'd0;
            cycle_count <= 6'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_done <= 1'b0;
            mst_idx <= 5'd0;
            total_cost <= 16'd0;
            check_node <= 4'd0;
            conn_idx <= 4'd0;
            fp_idx <= 5'd0;
            find_depth <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    result <= 16'd0;
                    edge_count <= 5'd0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        state <= READ_EDGES;
                    end
                end
                
                READ_EDGES: begin
                    if (edge_valid && edge_count < MAX_EDGES) begin
                        edge_buf[edge_count] <= {edge_u, edge_v, edge_w};
                        edge_count <= edge_count + 5'd1;
                    end
                    if (edge_end) begin
                        state <= SORT_EDGES;
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                        sort_done <= 1'b0;
                    end
                end
                
                SORT_EDGES: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= INIT_MST;
                    end else if (!sort_done) begin
                        if (sort_j < edge_count - 5'd1) begin
                            // Compare edges[sort_j] and edges[sort_j+1]
                            if (edge_buf[sort_j][11:0] > edge_buf[sort_j+1][11:0]) begin
                                // Swap
                                temp_edge <= edge_buf[sort_j];
                                edge_buf[sort_j] <= edge_buf[sort_j+1];
                                edge_buf[sort_j+1] <= temp_edge;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_i <= sort_i + 5'd1;
                            sort_j <= 5'd0;
                            if (sort_i >= edge_count - 5'd2) begin
                                sort_done <= 1'b1;
                                state <= INIT_MST;
                            end
                        end
                    end
                end
                
                INIT_MST: begin
                    // Initialize parent and degree arrays
                    for (integer i = 0; i < 16; i = i + 1) begin
                        parent[i] <= 4'(i);
                        degree[i] <= 4'd0;
                    end
                    mst_idx <= 5'd0;
                    total_cost <= 16'd0;
                    state <= PROCESS_EDGES;
                end
                
                PROCESS_EDGES: begin
                    if (mst_idx < edge_count) begin
                        u_node <= edge_buf[mst_idx][18:15];
                        v_node <= edge_buf[mst_idx][14:11];
                        w_val <= edge_buf[mst_idx][11:0];
                        
                        // Check bounds
                        if (u_node < n && v_node < n) begin
                            // Check if nodes are in different components
                            root_u = find_root(u_node);
                            root_v = find_root(v_node);
                            
                            if (root_u != root_v) begin
                                // Check degree constraints for insecure nodes
                                is_insecure_u = p_mask[u_node];
                                is_insecure_v = p_mask[v_node];
                                
                                if ((!is_insecure_u || degree[u_node] < 4'd1) && 
                                    (!is_insecure_v || degree[v_node] < 4'd1)) begin
                                    // Add edge
                                    parent[root_u] <= root_v;
                                    degree[u_node] <= degree[u_node] + 4'd1;
                                    degree[v_node] <= degree[v_node] + 4'd1;
                                    total_cost <= total_cost + {4'd0, w_val};
                                end
                            end
                        end
                        mst_idx <= mst_idx + 5'd1;
                    end else begin
                        state <= CHECK_CONNECTIVITY;
                        check_node <= 4'd0;
                    end
                end
                
                CHECK_CONNECTIVITY: begin
                    if (check_node < n) begin
                        common_root = find_root(check_node);
                        if (check_node == 4'd0) begin
                            conn_idx <= common_root;
                        end else begin
                            if (common_root != conn_idx) begin
                                impossible <= 1'b1;
                            end
                        end
                        check_node <= check_node + 4'd1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!impossible) begin
                        result <= total_cost;
                    end else begin
                        result <= 16'hFFFF;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule