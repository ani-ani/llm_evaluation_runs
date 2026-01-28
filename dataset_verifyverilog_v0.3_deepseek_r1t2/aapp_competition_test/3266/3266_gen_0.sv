module max_flow_solver #(
    parameter MAX_NODES = 8,
    parameter DATA_WIDTH = 32,
    parameter NODE_WIDTH = 3,
    parameter RESULT_WIDTH = 32,
    parameter MAX_AUGMENTATIONS = 16,
    parameter MAX_CYCLES = 10000
)(
    input clk,
    input rst_n,
    input start,
    
    // Configuration interface
    input [NODE_WIDTH-1:0] src_node,
    input [NODE_WIDTH-1:0] dst_node,
    input [NODE_WIDTH-1:0] edge_u,
    input [NODE_WIDTH-1:0] edge_v,
    input [DATA_WIDTH-1:0] edge_cap,
    input load_edge,
    
    // Results
    output reg done,
    output reg [RESULT_WIDTH-1:0] max_flow,
    
    // Edge flow output interface
    output reg [NODE_WIDTH-1:0] flow_src,
    output reg [NODE_WIDTH-1:0] flow_dst,
    output reg [DATA_WIDTH-1:0] flow_amount,
    output reg flow_valid,
    output reg flow_done
);

// State definitions
localparam [3:0] IDLE        = 4'd0;
localparam [3:0] LOAD        = 4'd1;
localparam [3:0] BFS_INIT    = 4'd2;
localparam [3:0] BFS_LOOP    = 4'd3;
localparam [3:0] AUGMENT     = 4'd4;
localparam [3:0] CHECK       = 4'd5;
localparam [3:0] OUTPUT_INIT = 4'd6;
localparam [3:0] OUTPUT_LOOP = 4'd7;
localparam [3:0] COMPLETE    = 4'd8;

reg [3:0] state, next_state;

// Memory arrays
reg [DATA_WIDTH-1:0] capacity [0:MAX_NODES-1][0:MAX_NODES-1];
reg [DATA_WIDTH-1:0] flow [0:MAX_NODES-1][0:MAX_NODES-1];

// BFS registers
reg [NODE_WIDTH-1:0] queue [0:MAX_NODES-1];
reg [NODE_WIDTH-1:0] parent [0:MAX_NODES-1];
reg [MAX_NODES-1:0] visited;
reg [NODE_WIDTH-1:0] bfs_head, bfs_tail;

// Path reconstruction
reg [NODE_WIDTH-1:0] path_nodes [0:MAX_NODES-1];
reg [NODE_WIDTH-1:0] path_length;
reg [DATA_WIDTH-1:0] bottleneck;

// Output scanning
reg [NODE_WIDTH-1:0] scan_i, scan_j;

// Counters
reg [RESULT_WIDTH-1:0] augment_count;
reg [15:0] cycle_counter;

// Flags
reg path_found;
reg output_active;

integer i, j;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        max_flow <= {RESULT_WIDTH{1'b0}};
        flow_valid <= 1'b0;
        flow_done <= 1'b0;
        flow_src <= {NODE_WIDTH{1'b0}};
        flow_dst <= {NODE_WIDTH{1'b0}};
        flow_amount <= {DATA_WIDTH{1'b0}};
        augment_count <= {RESULT_WIDTH{1'b0}};
        cycle_counter <= 16'd0;
        path_found <= 1'b0;
        output_active <= 1'b0;
        
        // Initialize all array elements
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            for (j = 0; j < MAX_NODES; j = j + 1) begin
                capacity[i][j] <= {DATA_WIDTH{1'b0}};
                flow[i][j] <= {DATA_WIDTH{1'b0}};
            end
            queue[i] <= {NODE_WIDTH{1'b0}};
            parent[i] <= {NODE_WIDTH{1'b0}};
            path_nodes[i] <= {NODE_WIDTH{1'b0}};
        end
    
        bfs_head <= {NODE_WIDTH{1'b0}};
        bfs_tail <= {NODE_WIDTH{1'b0}};
        visited <= {MAX_NODES{1'b0}};
        path_length <= {NODE_WIDTH{1'b0}};
        bottleneck <= {DATA_WIDTH{1'b0}};
        scan_i <= {NODE_WIDTH{1'b0}};
        scan_j <= {NODE_WIDTH{1'b0}};
    end
    else begin
        cycle_counter <= cycle_counter + 16'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                flow_done <= 1'b0;
                flow_valid <= 1'b0;
                if (start) begin
                    state <= BFS_INIT;
                    max_flow <= {RESULT_WIDTH{1'b0}};
                    augment_count <= {RESULT_WIDTH{1'b0}};
                end
                else if (load_edge) begin
                    state <= LOAD;
                end
            end
            
            LOAD: begin
                if (!load_edge) begin
                    state <= IDLE;
                end
                capacity[edge_u][edge_v] <= edge_cap;
            end
            
            BFS_INIT: begin
                visited <= {1'b0};
                visited[src_node] <= 1'b1;
                
                // Initialize queue with source
                queue[0] <= src_node;
                parent[src_node] <= src_node;
                bfs_head <= {NODE_WIDTH{1'b0}};
                bfs_tail <= {{(NODE_WIDTH-1){1'b0}}, 1'b1};
                
                path_found <= 1'b0;
                state <= BFS_LOOP;
            end
            
            BFS_LOOP: begin
                if (bfs_head < bfs_tail) begin
                    if (queue[bfs_head] == dst_node) begin
                        path_found <= 1'b1;
                        state <= AUGMENT;
                    end
                    else begin
                        // BFS expansion happens via combinational logic
                        bfs_head <= bfs_head + {{(NODE_WIDTH-1){1'b0}}, 1'b1};
                    end
                end
                else begin
                    state <= CHECK;
                end
            end
            
            AUGMENT: begin
                // Update flow matrix (implementation simplified)
                max_flow <= max_flow + bottleneck;
                augment_count <= augment_count + {{(RESULT_WIDTH-1){1'b0}}, 1'b1};
                state <= CHECK;
            end
            
            CHECK: begin
                if (augment_count >= MAX_AUGMENTATIONS || cycle_counter >= MAX_CYCLES || !path_found) begin
                    state <= OUTPUT_INIT;
                end
                else begin
                    state <= BFS_INIT;
                end
            end
            
            OUTPUT_INIT: begin
                output_active <= 1'b1;
                scan_i <= {NODE_WIDTH{1'b0}};
                scan_j <= {NODE_WIDTH{1'b0}};
                flow_valid <= 1'b0;
                flow_done <= 1'b0;
                state <= OUTPUT_LOOP;
            end
            
            OUTPUT_LOOP: begin
                if (scan_i < MAX_NODES) begin
                    if (scan_j < MAX_NODES) begin
                        flow_valid <= (flow[scan_i][scan_j] != {DATA_WIDTH{1'b0}});
                        flow_src <= scan_i;
                        flow_dst <= scan_j;
                        flow_amount <= flow[scan_i][scan_j];
                        
                        scan_j <= scan_j + {{(NODE_WIDTH-1){1'b0}}, 1'b1};
                        if (scan_j == (MAX_NODES-1)) begin
                            scan_i <= scan_i + {{(NODE_WIDTH-1){1'b0}}, 1'b1};
                            scan_j <= {NODE_WIDTH{1'b0}};
                        end
                    end
                end
                else begin
                    flow_valid <= 1'b0;
                    flow_done <= 1'b1;
                    state <= COMPLETE;
                end
            end
            
            COMPLETE: begin
                done <= 1'b1;
                output_active <= 1'b0;
                if (!start) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Combinational BFS expansion
integer k;
always @(*) begin
    if (state == BFS_LOOP && bfs_head < bfs_tail) begin
        // This block models combinational exploration of neighbors
        // (Actual implementation would require multiple cycles)
        for (k = 0; k < MAX_NODES; k = k + 1) begin
            if (!visited[k] && capacity[queue[bfs_head]][k] > flow[queue[bfs_head]][k]) begin
                visited[k] = 1'b1;
                parent[k] = queue[bfs_head];
                queue[bfs_tail] = k;
                bfs_tail = bfs_tail + {{(NODE_WIDTH-1){1'b0}}, 1'b1};
            end
        end
    end
end

// Path reconstruction
always @(*) begin
    if (path_found) begin
        bottleneck = capacity[parent[dst_node]][dst_node] - flow[parent[dst_node]][dst_node]; // Simplified
    end
    else begin
        bottleneck = {DATA_WIDTH{1'b0}};
    end
end

endmodule