module TunnelLengthCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] island_x [0:15],
    input wire [15:0] island_y [0:15],
    input wire [15:0] island_r [0:15],
    input wire [15:0] palm_x [0:7],
    input wire [15:0] palm_y [0:7],
    input wire [15:0] palm_h [0:7],
    input wire [3:0] n_islands,
    input wire [3:0] n_palms,
    input wire [15:0] k,
    input wire n_inputs_ready,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Internal registers for computation
    reg [3:0] i, j, p, q;
    reg [15:0] island1_x, island1_y, island1_r;
    reg [15:0] island2_x, island2_y, island2_r;
    reg [15:0] palm1_x, palm1_y, palm1_h;
    reg [15:0] palm2_x, palm2_y, palm2_h;
    reg [31:0] dist_sq_islands;
    reg [31:0] dist_sq_palms;
    reg [31:0] height_sum;
    reg [31:0] k_height_sum;
    reg [15:0] tunnel_length;
    reg connected;
    reg [15:0] min_tunnel_sum;
    reg [15:0] edge_count;
    reg [15:0] edge_list [0:119];
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];
    reg [3:0] components;
    reg [3:0] edge_index;
    reg [3:0] sorted_edge_index;
    reg [15:0] sorted_edges [0:119];
    reg [3:0] selected_edges;
    reg [15:0] total_tunnel_length;
    reg all_connected;

    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            p <= 4'd0;
            q <= 4'd0;
            island1_x <= 16'd0;
            island1_y <= 16'd0;
            island1_r <= 16'd0;
            island2_x <= 16'd0;
            island2_y <= 16'd0;
            island2_r <= 16'd0;
            palm1_x <= 16'd0;
            palm1_y <= 16'd0;
            palm1_h <= 16'd0;
            palm2_x <= 16'd0;
            palm2_y <= 16'd0;
            palm2_h <= 16'd0;
            dist_sq_islands <= 32'd0;
            dist_sq_palms <= 32'd0;
            height_sum <= 32'd0;
            k_height_sum <= 32'd0;
            tunnel_length <= 16'd0;
            connected <= 1'b0;
            min_tunnel_sum <= 16'd0;
            edge_count <= 16'd0;
            for (edge_index = 0; edge_index < 120; edge_index = edge_index + 1) begin
                edge_list[edge_index] <= 16'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
            end
            components <= 4'd0;
            edge_index <= 4'd0;
            sorted_edge_index <= 4'd0;
            for (edge_index = 0; edge_index < 120; edge_index = edge_index + 1) begin
                sorted_edges[edge_index] <= 16'd0;
            end
            selected_edges <= 4'd0;
            total_tunnel_length <= 16'd0;
            all_connected <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start && n_inputs_ready) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Initialize Union-Find
                    if (cycle_count == 16'd1) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i;
                            rank[i] <= 4'd0;
                        end
                        components <= n_islands;
                        edge_count <= 16'd0;
                    end
                    
                    // Build edge list
                    if (cycle_count > 16'd1 && cycle_count <= 16'd1 + 16*16) begin
                        i <= (cycle_count - 16'd2) / 16;
                        j <= (cycle_count - 16'd2) % 16;
                        
                        if (i < n_islands && j < n_islands && i != j) begin
                            island1_x <= island_x[i];
                            island1_y <= island_y[i];
                            island1_r <= island_r[i];
                            island2_x <= island_x[j];
                            island2_y <= island_y[j];
                            island2_r <= island_r[j];
                            
                            // Compute distance squared between islands
                            dist_sq_islands <= ($signed(island1_x) - $signed(island2_x)) ** 2 + 
                                              ($signed(island1_y) - $signed(island2_y)) ** 2;
                            
                            // Check if connected via palms
                            connected <= 1'b0;
                            for (p = 0; p < n_palms; p = p + 1) begin
                                for (q = 0; q < n_palms; q = q + 1) begin
                                    if (p != q) begin
                                        palm1_x <= palm_x[p];
                                        palm1_y <= palm_y[p];
                                        palm1_h <= palm_h[p];
                                        palm2_x <= palm_x[q];
                                        palm2_y <= palm_y[q];
                                        palm2_h <= palm_h[q];
                                        
                                        dist_sq_palms <= ($signed(palm1_x) - $signed(palm2_x)) ** 2 + 
                                                        ($signed(palm1_y) - $signed(palm2_y)) ** 2;
                                        height_sum <= $signed(palm1_h) + $signed(palm2_h);
                                        k_height_sum <= $signed(k) * height_sum;
                                        
                                        if (dist_sq_palms <= k_height_sum) begin
                                            connected <= 1'b1;
                                        end
                                    end
                                end
                            end
                            
                            if (!connected) begin
                                tunnel_length <= $signed(island1_r) + $signed(island2_r);
                                if (dist_sq_islands > tunnel_length * tunnel_length) begin
                                    edge_list[edge_count] <= $signed(dist_sq_islands) - tunnel_length * tunnel_length;
                                    edge_count <= edge_count + 16'd1;
                                end
                            end
                        end
                    end
                    
                    // Sort edges
                    if (cycle_count > 16'd1 + 16*16 && cycle_count <= 16'd1 + 16*16 + 120*120) begin
                        sorted_edge_index <= (cycle_count - 16'd1 - 16*16 - 16'd1) / 120;
                        edge_index <= (cycle_count - 16'd1 - 16*16 - 16'd1) % 120;
                        
                        if (sorted_edge_index < edge_count && edge_index < edge_count && sorted_edge_index != edge_index) begin
                            if (edge_list[sorted_edge_index] > edge_list[edge_index]) begin
                                sorted_edges[sorted_edge_index] <= edge_list[edge_index];
                                sorted_edges[edge_index] <= edge_list[sorted_edge_index];
                            end else begin
                                sorted_edges[sorted_edge_index] <= edge_list[sorted_edge_index];
                                sorted_edges[edge_index] <= edge_list[edge_index];
                            end
                        end
                    end
                    
                    // Union-Find to find minimum tunnel length
                    if (cycle_count > 16'd1 + 16*16 + 120*120 && cycle_count <= 16'd1 + 16*16 + 120*120 + 120) begin
                        edge_index <= cycle_count - 16'd1 - 16*16 - 120*120 - 16'd1;
                        
                        if (edge_index < edge_count) begin
                            i <= sorted_edges[edge_index][15:12];
                            j <= sorted_edges[edge_index][11:8];
                            
                            if (find(i) != find(j)) begin
                                union(i, j);
                                total_tunnel_length <= total_tunnel_length + sorted_edges[edge_index][15:0];
                                selected_edges <= selected_edges + 4'd1;
                            end
                        end
                    end
                    
                    // Check if all connected
                    if (cycle_count > 16'd1 + 16*16 + 120*120 + 120) begin
                        all_connected <= 1'b1;
                        for (i = 1; i < n_islands; i = i + 1) begin
                            if (find(i) != find(0)) begin
                                all_connected <= 1'b0;
                            end
                        end
                        
                        if (all_connected) begin
                            result <= total_tunnel_length;
                        end else begin
                            result <= 16'hFFFF;
                        end
                        
                        state <= FINISH;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
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

    // Union-Find functions
    function [3:0] find(input [3:0] x);
        if (parent[x] != x) begin
            parent[x] = find(parent[x]);
        end
        find = parent[x];
    endfunction

    task union(input [3:0] x, input [3:0] y);
        reg [3:0] x_root, y_root;
        begin
            x_root = find(x);
            y_root = find(y);
            
            if (x_root == y_root) begin
                return;
            end
            
            if (rank[x_root] < rank[y_root]) begin
                parent[x_root] = y_root;
            end else if (rank[x_root] > rank[y_root]) begin
                parent[y_root] = x_root;
            end else begin
                parent[y_root] = x_root;
                rank[x_root] = rank[x_root] + 4'd1;
            end
            
            components = components - 4'd1;
        end
    endtask

endmodule