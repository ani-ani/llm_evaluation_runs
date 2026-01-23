module resource_claim (
    input clk,
    input rst_n,
    input start,
    
    // Graph topology - 16 nodes, each with up to 4 neighbors
    input [3:0] node_count,           // Number of nodes (1-16)
    input [3:0] iron_count,           // Number of iron ore nodes (1-4)
    input [3:0] coal_count,           // Number of coal nodes (1-4)
    
    // Resource locations
    input [3:0] iron_nodes_0,
    input [3:0] iron_nodes_1,
    input [3:0] iron_nodes_2,
    input [3:0] iron_nodes_3,
    input [3:0] coal_nodes_0,
    input [3:0] coal_nodes_1,
    input [3:0] coal_nodes_2,
    input [3:0] coal_nodes_3,
    
    // Graph connectivity - adjacency matrix representation
    input [15:0] adjacency_0,
    input [15:0] adjacency_1,
    input [15:0] adjacency_2,
    input [15:0] adjacency_3,
    input [15:0] adjacency_4,
    input [15:0] adjacency_5,
    input [15:0] adjacency_6,
    input [15:0] adjacency_7,
    input [15:0] adjacency_8,
    input [15:0] adjacency_9,
    input [15:0] adjacency_10,
    input [15:0] adjacency_11,
    input [15:0] adjacency_12,
    input [15:0] adjacency_13,
    input [15:0] adjacency_14,
    input [15:0] adjacency_15,
    
    output reg [7:0] result,          // Minimal settlers needed
    output reg done,                  // Computation complete
    output reg impossible             // No solution possible
);

// State machine
localparam [2:0] IDLE = 3'b000;
localparam [2:0] BFS_IRON = 3'b001;
localparam [2:0] BFS_COAL = 3'b010;
localparam [2:0] COMPUTE = 3'b011;
localparam [2:0] DONE_STATE = 3'b100;

reg [2:0] state, next_state;
reg [3:0] queue [0:15];  // BFS queue
reg [4:0] q_head, q_tail;
reg [7:0] dist_iron [0:15];  // Distance from node 1 to each node (for iron BFS)
reg [7:0] dist_coal [0:15];  // Distance from node 1 to each node (for coal BFS)
reg [3:0] visited;
reg [3:0] current_node;
reg [3:0] target_idx;
reg [7:0] min_settlers;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 8'd0;
        q_head <= 5'd0;
        q_tail <= 5'd0;
        visited <= 4'd0;
        min_settlers <= 8'hFF;
        cycle_count <= 8'd0;
        // Initialize queue
        for (i = 0; i < 16; i = i + 1) begin
            queue[i] <= 4'd0;
        end
        // Initialize distance arrays
        for (i = 0; i < 16; i = i + 1) begin
            dist_iron[i] <= 8'hFF;
            dist_coal[i] <= 8'hFF;
        end
        target_idx <= 4'd0;
        current_node <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    // Initialize BFS for iron
                    for (i = 0; i < 16; i = i + 1) begin
                        dist_iron[i] <= 8'hFF;
                        dist_coal[i] <= 8'hFF;
                    end
                    dist_iron[0] <= 8'd0;  // Node 1 is index 0
                    dist_coal[0] <= 8'd0;
                    visited <= 4'd0;
                    q_head <= 5'd0;
                    q_tail <= 5'd0;
                    target_idx <= 4'd0;
                    state <= BFS_IRON;
                end
            end
            
            BFS_IRON: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (cycle_count >= MAX_CYCLES) begin
                    // Timeout - go to compute
                    state <= COMPUTE;
                end else if (q_head < q_tail) begin
                    // Process current node
                    current_node <= queue[q_head];
                    q_head <= q_head + 5'd1;
                end else if (q_head == q_tail && q_head == 5'd0) begin
                    // First node - add node 0 to queue
                    queue[0] <= 4'd0;
                    q_tail <= 5'd1;
                end else if (target_idx < iron_count) begin
                    // Check if current iron node reached
                    if (dist_iron[get_iron_node(target_idx)] != 8'hFF) begin
                        target_idx <= target_idx + 4'd1;
                    end else begin
                        // Add neighbors to queue
                        for (i = 0; i < 16; i = i + 1) begin
                            if (get_adjacency(current_node, i) && !visited[i] && dist_iron[i] == 8'hFF) begin
                                queue[q_tail] <= i[3:0];
                                q_tail <= q_tail + 5'd1;
                                dist_iron[i] <= dist_iron[current_node] + 8'd1;
                                visited[i] <= 1'b1;
                            end
                        end
                    end
                end else begin
                    // Iron BFS complete, start coal BFS
                    q_head <= 5'd0;
                    q_tail <= 5'd0;
                    visited <= 4'd0;
                    target_idx <= 4'd0;
                    state <= BFS_COAL;
                end
            end
            
            BFS_COAL: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (cycle_count >= MAX_CYCLES) begin
                    state <= COMPUTE;
                end else if (q_head < q_tail) begin
                    current_node <= queue[q_head];
                    q_head <= q_head + 5'd1;
                end else if (q_head == q_tail && q_head == 5'd0) begin
                    queue[0] <= 4'd0;
                    q_tail <= 5'd1;
                end else if (target_idx < coal_count) begin
                    if (dist_coal[get_coal_node(target_idx)] != 8'hFF) begin
                        target_idx <= target_idx + 4'd1;
                    end else begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (get_adjacency(current_node, i) && !visited[i] && dist_coal[i] == 8'hFF) begin
                                queue[q_tail] <= i[3:0];
                                q_tail <= q_tail + 5'd1;
                                dist_coal[i] <= dist_coal[current_node] + 8'd1;
                                visited[i] <= 1'b1;
                            end
                        end
                    end
                end else begin
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Find minimal settlers by combining paths
                min_settlers <= 8'hFF;
                
                // Check all combinations of iron and coal
                for (i = 0; i < 4; i = i + 1) begin
                    if (i < iron_count && dist_iron[get_iron_node(i)] != 8'hFF) begin
                        integer j;
                        for (j = 0; j < 4; j = j + 1) begin
                            if (j < coal_count && dist_coal[get_coal_node(j)] != 8'hFF) begin
                                // Total settlers = iron_dist + coal_dist - 1 (shared starting point)
                                integer total;
                                total = dist_iron[get_iron_node(i)] + dist_coal[get_coal_node(j)] - 1;
                                if (total < min_settlers) begin
                                    min_settlers <= total;
                                end
                            end
                        end
                    end
                end
                
                if (min_settlers == 8'hFF) begin
                    impossible <= 1'b1;
                end else begin
                    result <= min_settlers;
                end
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

// Helper functions to get node values
function automatic [7:0] get_iron_node(input [2:0] idx);
    case (idx)
        3'd0: get_iron_node = {4'd0, iron_nodes_0};
        3'd1: get_iron_node = {4'd0, iron_nodes_1};
        3'd2: get_iron_node = {4'd0, iron_nodes_2};
        3'd3: get_iron_node = {4'd0, iron_nodes_3};
        default: get_iron_node = 8'hFF;
    endcase
endfunction

function automatic [7:0] get_coal_node(input [2:0] idx);
    case (idx)
        3'd0: get_coal_node = {4'd0, coal_nodes_0};
        3'd1: get_coal_node = {4'd0, coal_nodes_1};
        3'd2: get_coal_node = {4'd0, coal_nodes_2};
        3'd3: get_coal_node = {4'd0, coal_nodes_3};
        default: get_coal_node = 8'hFF;
    endcase
endfunction

function automatic get_adjacency(input [3:0] row, input [3:0] col);
    reg [15:0] row_data;
    case (row)
        4'd0: row_data = adjacency_0;
        4'd1: row_data = adjacency_1;
        4'd2: row_data = adjacency_2;
        4'd3: row_data = adjacency_3;
        4'd4: row_data = adjacency_4;
        4'd5: row_data = adjacency_5;
        4'd6: row_data = adjacency_6;
        4'd7: row_data = adjacency_7;
        4'd8: row_data = adjacency_8;
        4'd9: row_data = adjacency_9;
        4'd10: row_data = adjacency_10;
        4'd11: row_data = adjacency_11;
        4'd12: row_data = adjacency_12;
        4'd13: row_data = adjacency_13;
        4'd14: row_data = adjacency_14;
        4'd15: row_data = adjacency_15;
        default: row_data = 16'd0;
    endcase
    get_adjacency = row_data[col];
endfunction

endmodule