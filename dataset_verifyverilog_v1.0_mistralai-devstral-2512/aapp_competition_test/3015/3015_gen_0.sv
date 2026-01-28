module ShortestPathGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] start_node,
    input wire [4:0] target_node,
    input wire [5:0] valid_edges,
    input wire [23:0] edge_data [0:31],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [4:0] MAX_EDGES = 5'd32;
    localparam [7:0] MAX_CYCLES = 8'd256;
    localparam [31:0] INFINITY = 32'hFFFFFFFE;
    localparam [31:0] INIT_VAL = 32'h80000000;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    reg [3:0] current_node;
    reg [0:0] current_turn;
    reg [3:0] edge_index;
    reg [3:0] edge_ptr;
    reg [3:0] node_ptr;
    reg [3:0] turn_ptr;
    reg [3:0] next_node;
    reg [15:0] edge_weight;
    reg [31:0] current_dist;
    reg [31:0] next_dist;
    reg [31:0] temp_dist;
    reg [31:0] min_max_val;
    reg [31:0] dist_ram [0:31]; // 16 nodes x 2 turns = 32 entries
    reg [31:0] new_dist_ram [0:31];
    reg [31:0] adjacency [0:255]; // 16x16 adjacency matrix
    reg [15:0] weights [0:255];
    reg [0:0] valid_edge [0:255];
    reg [0:0] has_changes;
    reg [0:0] is_infinite;

    // Initialize adjacency matrix
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_node <= 4'd0;
            current_turn <= 1'b0;
            edge_index <= 4'd0;
            edge_ptr <= 4'd0;
            node_ptr <= 4'd0;
            turn_ptr <= 1'b0;
            next_node <= 4'd0;
            edge_weight <= 16'd0;
            current_dist <= 32'd0;
            next_dist <= 32'd0;
            temp_dist <= 32'd0;
            min_max_val <= 32'd0;
            has_changes <= 1'b0;
            is_infinite <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            
            // Initialize dist_ram and new_dist_ram
            for (i = 0; i < 32; i = i + 1) begin
                dist_ram[i] <= INIT_VAL;
                new_dist_ram[i] <= INIT_VAL;
            end
            
            // Initialize adjacency matrix
            for (i = 0; i < 256; i = i + 1) begin
                adjacency[i] <= 32'd0;
                weights[i] <= 16'd0;
                valid_edge[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Build adjacency matrix from edge_data
                    edge_ptr <= 4'd0;
                    for (i = 0; i < valid_edges; i = i + 1) begin
                        edge_weight <= edge_data[i][23:8];
                        next_node <= edge_data[i][7:4];
                        current_node <= edge_data[i][3:0];
                        
                        // Store edge in adjacency matrix
                        adjacency[{current_node, next_node}] <= 32'd1;
                        weights[{current_node, next_node}] <= edge_weight;
                        valid_edge[{current_node, next_node}] <= 1'b1;
                    end
                    
                    // Initialize target node distances
                    dist_ram[{target_node, 1'b0}] <= 32'd0;
                    dist_ram[{target_node, 1'b1}] <= 32'd0;
                    
                    state <= COMPUTE;
                    cycle_count <= 8'd0;
                    current_node <= 4'd0;
                    current_turn <= 1'b0;
                    has_changes <= 1'b0;
                end
                
                COMPUTE: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        is_infinite <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Process all nodes and turns
                        for (node_ptr = 0; node_ptr < MAX_NODES; node_ptr = node_ptr + 1) begin
                            for (turn_ptr = 0; turn_ptr < 2; turn_ptr = turn_ptr + 1) begin
                                current_node <= node_ptr;
                                current_turn <= turn_ptr;
                                current_dist <= dist_ram[{node_ptr, turn_ptr}];
                                
                                // Initialize min/max value
                                if (turn_ptr == 1'b0) begin
                                    min_max_val <= 32'd0;
                                end else begin
                                    min_max_val <= 32'h7FFFFFFF;
                                end
                                
                                // Check all outgoing edges
                                for (next_node = 0; next_node < MAX_NODES; next_node = next_node + 1) begin
                                    if (valid_edge[{node_ptr, next_node}]) begin
                                        edge_weight <= weights[{node_ptr, next_node}];
                                        temp_dist <= edge_weight + dist_ram[{next_node, ~turn_ptr}];
                                        
                                        // Update min/max based on turn
                                        if (turn_ptr == 1'b0) begin
                                            if (temp_dist > min_max_val) begin
                                                min_max_val <= temp_dist;
                                            end
                                        end else begin
                                            if (temp_dist < min_max_val) begin
                                                min_max_val <= temp_dist;
                                            end
                                        end
                                    end
                                end
                                
                                // Update distance if changed
                                if (min_max_val != current_dist) begin
                                    new_dist_ram[{node_ptr, turn_ptr}] <= min_max_val;
                                    has_changes <= 1'b1;
                                end else begin
                                    new_dist_ram[{node_ptr, turn_ptr}] <= current_dist;
                                end
                            end
                        end
                        
                        // Copy new distances to dist_ram
                        for (i = 0; i < 32; i = i + 1) begin
                            dist_ram[i] <= new_dist_ram[i];
                        end
                        
                        // Check for convergence or infinity
                        if (!has_changes) begin
                            state <= FINISH;
                        end else begin
                            cycle_count <= cycle_count + 8'd1;
                            has_changes <= 1'b0;
                        end
                    end
                end
                
                FINISH: begin
                    // Check if result is infinite
                    if (is_infinite || (dist_ram[{start_node, 1'b0}] == INIT_VAL) || 
                        (dist_ram[{start_node, 1'b0}] > 32'h00FFFFFF)) begin
                        result <= INFINITY;
                    end else begin
                        result <= dist_ram[{start_node, 1'b0}];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule