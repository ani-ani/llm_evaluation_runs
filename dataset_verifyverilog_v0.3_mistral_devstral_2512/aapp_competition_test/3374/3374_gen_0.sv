module UW_Distance_Optimizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] gravity_in [0:7],
    input [7:0] connections_in [0:7],
    input human_mask [0:7],
    input alien_mask [0:7],
    output reg [15:0] min_distance,
    output reg done
);

// Parameters
localparam [2:0] MAX_NODES = 3'd8;
localparam [3:0] MAX_EDGES = 4'd16;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] READ_GRAPH = 3'd1;
localparam [2:0] FIND_PATHS = 3'd2;
localparam [2:0] CALCULATE_DISTANCE = 3'd3;
localparam [2:0] APPLY_DEVICE = 3'd4;
localparam [2:0] UPDATE_MIN = 3'd5;
localparam [2:0] COMPLETE = 3'd6;

// Internal registers
reg [2:0] current_state, next_state;
reg [2:0] node_count;
reg [2:0] current_node, next_node;
reg [2:0] path_nodes [0:7]; // Store path nodes
reg [2:0] path_length;
reg [2:0] device_node; // Node where device is placed (0-7)
reg [15:0] current_distance;
reg [15:0] best_distance;
reg [2:0] search_depth;

// Adjacency matrix (8x8, stored as 64-bit for efficiency)
reg [63:0] adjacency;

// UW Distance Calculation Registers
reg signed [15:0] gravity_seq [0:7];
reg signed [15:0] cap_seq [0:6];
reg signed [15:0] pot_seq [0:6];
reg signed [15:0] ind_seq [0:6];
reg signed [31:0] intermediate [0:6];
reg signed [31:0] total_sum;
reg [2:0] calc_step;

// Device effect registers
reg signed [15:0] modified_gravity [0:7];
reg [2:0] affected_nodes [0:7];
reg [2:0] affected_count;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        min_distance <= 16'hFFFF;
        done <= 1'b0;
        node_count <= 3'd0;
        current_node <= 3'd0;
        next_node <= 3'd0;
        path_length <= 3'd0;
        device_node <= 3'd0;
        current_distance <= 16'd0;
        best_distance <= 16'hFFFF;
        search_depth <= 3'd0;
        adjacency <= 64'd0;
        calc_step <= 3'd0;
        affected_count <= 3'd0;
        
        // Initialize arrays
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            gravity_seq[i] <= 16'd0;
            modified_gravity[i] <= 16'd0;
            path_nodes[i] <= 3'd0;
            affected_nodes[i] <= 3'd0;
        end
        for (i = 0; i < 7; i = i + 1) begin
            cap_seq[i] <= 16'd0;
            pot_seq[i] <= 16'd0;
            ind_seq[i] <= 16'd0;
            intermediate[i] <= 32'd0;
        end
    end else begin
        current_state <= next_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    node_count <= 3'd0;
                    best_distance <= 16'hFFFF;
                    device_node <= 3'd0;
                    done <= 1'b0;
                    next_state <= READ_GRAPH;
                end
            end
            
            READ_GRAPH: begin
                // Read gravity values and build adjacency matrix
                if (node_count < MAX_NODES) begin
                    // Store gravity values (simplified)
                    modified_gravity[node_count] <= {8'd0, gravity_in[node_count]};
                    node_count <= node_count + 1'b1;
                end else begin
                    next_state <= FIND_PATHS;
                end
            end
            
            FIND_PATHS: begin
                // Simplified: find all human-alien pairs
                // In hardware, this would use BFS/DFS state machine
                if (current_node < MAX_NODES) begin
                    if (human_mask[current_node]) begin
                        // Start search for alien nodes
                        search_depth <= 3'd0;
                        path_nodes[0] <= current_node;
                        path_length <= 3'd1;
                    end
                    current_node <= current_node + 1'b1;
                end else begin
                    next_state <= APPLY_DEVICE;
                end
            end
            
            CALCULATE_DISTANCE: begin
                // Calculate UW distance for current path
                case (calc_step)
                    3'd0: begin
                        // Calculate sequences
                        integer i;
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i < path_length - 1) begin
                                cap_seq[i] <= modified_gravity[path_nodes[i+1]] + modified_gravity[path_nodes[i]];
                                pot_seq[i] <= modified_gravity[path_nodes[i+1]] - modified_gravity[path_nodes[i]];
                                ind_seq[i] <= modified_gravity[path_nodes[i+1]] * modified_gravity[path_nodes[i]];
                            end else begin
                                cap_seq[i] <= 16'd0;
                                pot_seq[i] <= 16'd0;
                                ind_seq[i] <= 16'd0;
                            end
                        end
                        calc_step <= 3'd1;
                    end
                    3'd1: begin
                        // Calculate pot * (cap^2 - ind)
                        integer i;
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i < path_length - 1) begin
                                intermediate[i] <= pot_seq[i] * ((cap_seq[i] * cap_seq[i]) - ind_seq[i]);
                            end else begin
                                intermediate[i] <= 32'd0;
                            end
                        end
                        calc_step <= 3'd2;
                    end
                    3'd2: begin
                        // Sum intermediate values
                        total_sum <= 32'd0;
                        integer i;
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i < path_length - 1) begin
                                total_sum <= total_sum + intermediate[i];
                            end
                        end
                        calc_step <= 3'd3;
                    end
                    3'd3: begin
                        // Take absolute value
                        current_distance <= (total_sum[31]) ? -total_sum[15:0] : total_sum[15:0];
                        calc_step <= 3'd0;
                        next_state <= UPDATE_MIN;
                    end
                endcase
            end
            
            APPLY_DEVICE: begin
                // Apply gravity dispersal device effects
                // Device at device_node: -1 to that node, +1 to all neighbors
                modified_gravity[device_node] <= modified_gravity[device_node] - 16'd1;
                // Apply to neighbors (simplified)
                if (device_node > 0) modified_gravity[device_node-1] <= modified_gravity[device_node-1] + 16'd1;
                if (device_node < 7) modified_gravity[device_node+1] <= modified_gravity[device_node+1] + 16'd1;
                next_state <= CALCULATE_DISTANCE;
            end
            
            UPDATE_MIN: begin
                if (current_distance < best_distance) begin
                    best_distance <= current_distance;
                end
                // Try next device position
                if (device_node < 7) begin
                    device_node <= device_node + 1'b1;
                    // Reset modified_gravity to original values
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        modified_gravity[i] <= {8'd0, gravity_in[i]};
                    end
                    next_state <= APPLY_DEVICE;
                end else begin
                    next_state <= COMPLETE;
                end
            end
            
            COMPLETE: begin
                min_distance <= best_distance;
                done <= 1'b1;
                next_state <= IDLE;
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule