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
localparam [3:0] MAX_NODES = 4'd8;
localparam [3:0] MAX_EDGES = 4'd16;

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] READ_GRAPH = 4'd1;
localparam [3:0] FIND_PATHS = 4'd2;
localparam [3:0] CALCULATE_DISTANCE = 4'd3;
localparam [3:0] APPLY_DEVICE = 4'd4;
localparam [3:0] UPDATE_MIN = 4'd5;
localparam [3:0] COMPLETE = 4'd6;

// Internal registers
reg [3:0] current_state, next_state;
reg [3:0] node_count;
reg [3:0] current_node;
reg [3:0] path_nodes [0:7];
reg [3:0] path_length;
reg [2:0] device_node;
reg [15:0] current_distance;
reg [15:0] best_distance;
reg [2:0] search_depth;
reg [2:0] calc_step;
reg [2:0] search_node;
reg [2:0] pair_index;
reg [2:0] i;

// Gravity registers
reg signed [15:0] modified_gravity [0:7];
reg signed [15:0] original_gravity [0:7];

// UW Distance Calculation Registers
reg signed [15:0] gravity_seq [0:7];
reg signed [15:0] cap_seq [0:6];
reg signed [15:0] pot_seq [0:6];
reg signed [15:0] ind_seq [0:6];
reg signed [31:0] intermediate [0:6];
reg signed [31:0] total_sum;
reg signed [31:0] sum_temp;

// Human-Alien pair tracking
reg [2:0] human_nodes [0:7];
reg [2:0] alien_nodes [0:7];
reg [2:0] human_count;
reg [2:0] alien_count;
reg [2:0] current_human;
reg [2:0] current_alien;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        min_distance <= 16'hFFFF;
        done <= 1'b0;
        node_count <= 4'd0;
        best_distance <= 16'hFFFF;
        device_node <= 3'd0;
        current_node <= 4'd0;
        search_depth <= 3'd0;
        calc_step <= 3'd0;
        search_node <= 3'd0;
        pair_index <= 3'd0;
        i <= 3'd0;
        path_length <= 4'd0;
        current_distance <= 16'd0;
        human_count <= 3'd0;
        alien_count <= 3'd0;
        current_human <= 3'd0;
        current_alien <= 3'd0;
        total_sum <= 32'd0;
        sum_temp <= 32'd0;
        for (i = 0; i < 8; i = i + 1) begin
            modified_gravity[i] <= 16'd0;
            original_gravity[i] <= 16'd0;
            gravity_seq[i] <= 16'd0;
            cap_seq[i] <= 16'd0;
            pot_seq[i] <= 16'd0;
            ind_seq[i] <= 16'd0;
            intermediate[i] <= 32'd0;
            human_nodes[i] <= 3'd0;
            alien_nodes[i] <= 3'd0;
            path_nodes[i] <= 4'd0;
        end
    end else begin
        current_state <= next_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    node_count <= 4'd0;
                    best_distance <= 16'hFFFF;
                    device_node <= 3'd0;
                    current_node <= 4'd0;
                    human_count <= 3'd0;
                    alien_count <= 3'd0;
                    current_human <= 3'd0;
                    current_alien <= 3'd0;
                    calc_step <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        modified_gravity[i] <= 16'd0;
                        original_gravity[i] <= 16'd0;
                    end
                end
            end
            
            READ_GRAPH: begin
                if (node_count < MAX_NODES) begin
                    // Store gravity values as 16-bit signed
                    original_gravity[node_count] <= {{8{gravity_in[node_count][7]}}, gravity_in[node_count]};
                    modified_gravity[node_count] <= {{8{gravity_in[node_count][7]}}, gravity_in[node_count]};
                    // Collect human and alien nodes
                    if (human_mask[node_count]) begin
                        human_nodes[human_count] <= node_count;
                        human_count <= human_count + 1;
                    end
                    if (alien_mask[node_count]) begin
                        alien_nodes[alien_count] <= node_count;
                        alien_count <= alien_count + 1;
                    end
                    node_count <= node_count + 1;
                end
            end
            
            FIND_PATHS: begin
                // Find path from current_human to current_alien
                // Simplified direct connection path for hardware
                if (current_human < human_count && current_alien < alien_count) begin
                    path_length <= 4'd2;
                    path_nodes[0] <= human_nodes[current_human];
                    path_nodes[1] <= alien_nodes[current_alien];
                end
            end
            
            CALCULATE_DISTANCE: begin
                case (calc_step)
                    3'd0: begin
                        // Calculate sequences for path length 2
                        if (path_length >= 2) begin
                            cap_seq[0] <= modified_gravity[path_nodes[1]] + modified_gravity[path_nodes[0]];
                            pot_seq[0] <= modified_gravity[path_nodes[1]] - modified_gravity[path_nodes[0]];
                            ind_seq[0] <= modified_gravity[path_nodes[1]] * modified_gravity[path_nodes[0]];
                        end
                        calc_step <= 3'd1;
                    end
                    3'd1: begin
                        // Calculate pot * (cap^2 - ind)
                        if (path_length >= 2) begin
                            intermediate[0] <= pot_seq[0] * ((cap_seq[0] * cap_seq[0]) - ind_seq[0]);
                        end
                        calc_step <= 3'd2;
                    end
                    3'd2: begin
                        // Sum intermediate values
                        total_sum <= 32'd0;
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i < (path_length - 1)) begin
                                total_sum <= total_sum + intermediate[i];
                            end
                        end
                        calc_step <= 3'd3;
                    end
                    3'd3: begin
                        // Take absolute value and convert to 16-bit
                        if (total_sum[31]) begin
                            current_distance <= -total_sum[15:0];
                        end else begin
                            current_distance <= total_sum[15:0];
                        end
                        calc_step <= 3'd0;
                    end
                    default: calc_step <= 3'd0;
                endcase
            end
            
            APPLY_DEVICE: begin
                // Apply gravity dispersal device effects
                // Device at device_node: -1 to that node, +1 to neighbors
                modified_gravity[device_node] <= modified_gravity[device_node] - 16'd1;
                if (device_node > 0) begin
                    modified_gravity[device_node - 1] <= modified_gravity[device_node - 1] + 16'd1;
                end
                if (device_node < 7) begin
                    modified_gravity[device_node + 1] <= modified_gravity[device_node + 1] + 16'd1;
                end
            end
            
            UPDATE_MIN: begin
                if (current_distance < best_distance) begin
                    best_distance <= current_distance;
                end
                // Reset modified_gravity for next device position
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < MAX_NODES) begin
                        modified_gravity[i] <= original_gravity[i];
                    end
                end
            end
            
            COMPLETE: begin
                min_distance <= best_distance;
                done <= 1'b1;
            end
        endcase
    end
end

// State transition logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (start) next_state = READ_GRAPH;
            else next_state = IDLE;
        end
        READ_GRAPH: begin
            if (node_count >= MAX_NODES) next_state = FIND_PATHS;
            else next_state = READ_GRAPH;
        end
        FIND_PATHS: begin
            if (current_human >= human_count || current_alien >= alien_count) begin
                next_state = APPLY_DEVICE;
            end else begin
                next_state = CALCULATE_DISTANCE;
            end
        end
        CALCULATE_DISTANCE: begin
            if (calc_step == 3'd3) next_state = UPDATE_MIN;
            else next_state = CALCULATE_DISTANCE;
        end
        APPLY_DEVICE: begin
            next_state = CALCULATE_DISTANCE;
        end
        UPDATE_MIN: begin
            if (device_node < 7) begin
                next_state = APPLY_DEVICE;
            end else begin
                next_state = COMPLETE;
            end
        end
        COMPLETE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

endmodule