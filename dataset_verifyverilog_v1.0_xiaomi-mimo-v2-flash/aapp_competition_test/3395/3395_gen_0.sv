module resource_claimer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] graph_in_data,
    input wire [3:0] graph_in_addr,
    input wire graph_in_valid,
    input wire [15:0] iron_mask,
    input wire [15:0] coal_mask,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CONFIG_LOAD   = 4'd1;
    localparam [3:0] BFS_INIT      = 4'd2;
    localparam [3:0] BFS_PROCESS   = 4'd3;
    localparam [3:0] SCAN_INIT     = 4'd4;
    localparam [3:0] SCAN_IRON     = 4'd5;
    localparam [3:0] SCAN_COAL     = 4'd6;
    localparam [3:0] CALC_RESULT   = 4'd7;
    localparam [3:0] FINISH        = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // Configuration registers
    reg [4:0] config_addr; // 0-15 for nodes, 16 for done
    reg [4:0] next_config_addr;
    reg [7:0] edges_reg [0:15]; // Store edges for each node
    
    // BFS registers
    reg [15:0] visited;
    reg [3:0] current_distance;
    reg [4:0] node_idx; // 0-15 for scanning nodes
    reg [3:0] bfs_counter; // Limit iterations to 16
    
    // Distance RAM (16x4 bits)
    reg [3:0] dist_ram [0:15];
    
    // Computation registers
    reg [3:0] min_d_iron;
    reg [3:0] min_d_coal;
    reg [3:0] temp_sum;
    
    // Intermediate signals
    wire [7:0] node_edges;
    assign node_edges = edges_reg[node_idx[3:0]];
    
    // FSM synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            config_addr <= 5'd0;
            visited <= 16'd0;
            current_distance <= 4'd0;
            node_idx <= 5'd0;
            bfs_counter <= 4'd0;
            min_d_iron <= 4'd15;
            min_d_coal <= 4'd15;
            temp_sum <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            // Initialize edges_reg
            edges_reg[0] <= 8'd0;
            edges_reg[1] <= 8'd0;
            edges_reg[2] <= 8'd0;
            edges_reg[3] <= 8'd0;
            edges_reg[4] <= 8'd0;
            edges_reg[5] <= 8'd0;
            edges_reg[6] <= 8'd0;
            edges_reg[7] <= 8'd0;
            edges_reg[8] <= 8'd0;
            edges_reg[9] <= 8'd0;
            edges_reg[10] <= 8'd0;
            edges_reg[11] <= 8'd0;
            edges_reg[12] <= 8'd0;
            edges_reg[13] <= 8'd0;
            edges_reg[14] <= 8'd0;
            edges_reg[15] <= 8'd0;
            // Initialize dist_ram
            dist_ram[0] <= 4'd15;
            dist_ram[1] <= 4'd15;
            dist_ram[2] <= 4'd15;
            dist_ram[3] <= 4'd15;
            dist_ram[4] <= 4'd15;
            dist_ram[5] <= 4'd15;
            dist_ram[6] <= 4'd15;
            dist_ram[7] <= 4'd15;
            dist_ram[8] <= 4'd15;
            dist_ram[9] <= 4'd15;
            dist_ram[10] <= 4'd15;
            dist_ram[11] <= 4'd15;
            dist_ram[12] <= 4'd15;
            dist_ram[13] <= 4'd15;
            dist_ram[14] <= 4'd15;
            dist_ram[15] <= 4'd15;
        end else begin
            state <= next_state;
            config_addr <= next_config_addr;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                CONFIG_LOAD: begin
                    if (graph_in_valid && (graph_in_addr < 4'd16)) begin
                        edges_reg[graph_in_addr] <= graph_in_data;
                    end
                end
                BFS_INIT: begin
                    visited <= 16'd1; // Mark node 0 as visited
                    dist_ram[0] <= 4'd0;
                    current_distance <= 4'd0;
                    bfs_counter <= 4'd0;
                    // Initialize other distances to 15
                    dist_ram[1] <= 4'd15;
                    dist_ram[2] <= 4'd15;
                    dist_ram[3] <= 4'd15;
                    dist_ram[4] <= 4'd15;
                    dist_ram[5] <= 4'd15;
                    dist_ram[6] <= 4'd15;
                    dist_ram[7] <= 4'd15;
                    dist_ram[8] <= 4'd15;
                    dist_ram[9] <= 4'd15;
                    dist_ram[10] <= 4'd15;
                    dist_ram[11] <= 4'd15;
                    dist_ram[12] <= 4'd15;
                    dist_ram[13] <= 4'd15;
                    dist_ram[14] <= 4'd15;
                    dist_ram[15] <= 4'd15;
                end
                BFS_PROCESS: begin
                    bfs_counter <= bfs_counter + 4'd1;
                    // Check if current node has edges to unvisited nodes
                    if ((node_edges != 8'd0) && (node_idx < 5'd16)) begin
                        // For each edge in node_edges (bits 0-7)
                        // Simplified: check all 8 bits against visited
                        if (node_edges[0] && !visited[1] && (current_distance < 4'd15)) begin
                            visited[1] <= 1'b1;
                            dist_ram[1] <= current_distance + 4'd1;
                        end
                        if (node_edges[1] && !visited[2] && (current_distance < 4'd15)) begin
                            visited[2] <= 1'b1;
                            dist_ram[2] <= current_distance + 4'd1;
                        end
                        if (node_edges[2] && !visited[3] && (current_distance < 4'd15)) begin
                            visited[3] <= 1'b1;
                            dist_ram[3] <= current_distance + 4'd1;
                        end
                        if (node_edges[3] && !visited[4] && (current_distance < 4'd15)) begin
                            visited[4] <= 1'b1;
                            dist_ram[4] <= current_distance + 4'd1;
                        end
                        if (node_edges[4] && !visited[5] && (current_distance < 4'd15)) begin
                            visited[5] <= 1'b1;
                            dist_ram[5] <= current_distance + 4'd1;
                        end
                        if (node_edges[5] && !visited[6] && (current_distance < 4'd15)) begin
                            visited[6] <= 1'b1;
                            dist_ram[6] <= current_distance + 4'd1;
                        end
                        if (node_edges[6] && !visited[7] && (current_distance < 4'd15)) begin
                            visited[7] <= 1'b1;
                            dist_ram[7] <= current_distance + 4'd1;
                        end
                        if (node_edges[7] && !visited[8] && (current_distance < 4'd15)) begin
                            visited[8] <= 1'b1;
                            dist_ram[8] <= current_distance + 4'd1;
                        end
                    end
                    // Update current_distance based on visited nodes at next distance
                    // Simplified: increment distance periodically
                    if (bfs_counter == 4'd15) begin
                        current_distance <= current_distance + 4'd1;
                        bfs_counter <= 4'd0;
                    end
                end
                SCAN_INIT: begin
                    min_d_iron <= 4'd15;
                    min_d_coal <= 4'd15;
                    node_idx <= 5'd0;
                end
                SCAN_IRON: begin
                    if ((iron_mask[node_idx[3:0]]) && (visited[node_idx[3:0]])) begin
                        if (dist_ram[node_idx[3:0]] < min_d_iron) begin
                            min_d_iron <= dist_ram[node_idx[3:0]];
                        end
                    end
                    node_idx <= node_idx + 5'd1;
                end
                SCAN_COAL: begin
                    if ((coal_mask[node_idx[3:0]]) && (visited[node_idx[3:0]])) begin
                        if (dist_ram[node_idx[3:0]] < min_d_coal) begin
                            min_d_coal <= dist_ram[node_idx[3:0]];
                        end
                    end
                    node_idx <= node_idx + 5'd1;
                end
                CALC_RESULT: begin
                    if ((min_d_iron == 4'd15) || (min_d_coal == 4'd15)) begin
                        result <= 8'd255; // Impossible
                    end else begin
                        temp_sum <= min_d_iron + min_d_coal;
                    end
                end
                FINISH: begin
                    if ((min_d_iron != 4'd15) && (min_d_coal != 4'd15)) begin
                        result <= {4'd0, temp_sum - 4'd1}; // settlers = sum - 1
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_config_addr = config_addr;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CONFIG_LOAD;
                    next_config_addr = 5'd0;
                end
            end
            CONFIG_LOAD: begin
                if (graph_in_valid) begin
                    if (graph_in_addr < 4'd16) begin
                        // Continue loading
                        next_config_addr = config_addr + 5'd1;
                        if (config_addr >= 5'd15) begin
                            next_state = BFS_INIT;
                        end
                    end else begin
                        // Invalid address, ignore but continue
                        next_config_addr = config_addr + 5'd1;
                        if (config_addr >= 5'd15) begin
                            next_state = BFS_INIT;
                        end
                    end
                end else begin
                    // No valid data, wait or timeout
                    // Simple timeout after 16 cycles
                    if (config_addr >= 5'd16) begin
                        next_state = BFS_INIT;
                    end
                end
            end
            BFS_INIT: begin
                next_state = BFS_PROCESS;
                next_config_addr = 5'd0; // Use config_addr as temp for BFS node scan
            end
            BFS_PROCESS: begin
                // Simple BFS: iterate through all nodes, propagate distances
                // Run for 16 cycles to ensure propagation
                if (bfs_counter == 4'd15) begin
                    // Increment current_distance logic handled in synchronous block
                    // Check if we should continue BFS
                    if (current_distance >= 4'd15) begin
                        next_state = SCAN_INIT;
                    end else begin
                        next_state = BFS_PROCESS;
                    end
                end else begin
                    next_state = BFS_PROCESS;
                end
                // Update node_idx for next iteration
                next_config_addr = config_addr + 5'd1;
                if (next_config_addr >= 5'd16) begin
                    next_config_addr = 5'd0;
                end
            end
            SCAN_INIT: begin
                next_state = SCAN_IRON;
                next_config_addr = 5'd0;
            end
            SCAN_IRON: begin
                if (node_idx >= 5'd15) begin
                    next_state = SCAN_COAL;
                    next_config_addr = 5'd0;
                end else begin
                    next_config_addr = node_idx + 5'd1;
                end
            end
            SCAN_COAL: begin
                if (node_idx >= 5'd15) begin
                    next_state = CALC_RESULT;
                end else begin
                    next_config_addr = node_idx + 5'd1;
                end
            end
            CALC_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Node index assignment for BFS scan
    always @(posedge clk) begin
        if (!rst_n) begin
            node_idx <= 5'd0;
        end else begin
            if (state == BFS_PROCESS) begin
                node_idx <= config_addr; // Use config_addr as the scanning index
            end else if (state == SCAN_INIT) begin
                node_idx <= 5'd0;
            end else if (state == SCAN_IRON || state == SCAN_COAL) begin
                node_idx <= node_idx + 5'd1;
            end
        end
    end

endmodule