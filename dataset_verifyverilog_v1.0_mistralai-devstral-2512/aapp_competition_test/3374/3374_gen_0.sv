module UnterwaveDistanceCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] gravity [0:15],
    input wire [15:0] adj_matrix [0:15],
    input wire [15:0] types,
    input wire [3:0] num_nodes,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Counters and control signals
    reg [3:0] src_counter;
    reg [3:0] dst_counter;
    reg [3:0] device_counter;
    reg [3:0] path_counter;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1900;
    
    // Intermediate storage
    reg [15:0] temp_gravity [0:15];
    reg [15:0] temp_adj_matrix [0:15];
    reg [15:0] current_path [0:2];
    reg [31:0] current_distance;
    reg [31:0] min_distance;
    reg [3:0] current_path_length;
    
    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_counter <= 4'd0;
            dst_counter <= 4'd0;
            device_counter <= 4'd0;
            path_counter <= 4'd0;
            cycle_count <= 8'd0;
            min_distance <= 32'd0;
            
            // Initialize temp arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                temp_gravity[i] <= gravity[i];
                temp_adj_matrix[i] <= adj_matrix[i];
            end
        end else begin
            case (state)
                INIT: begin
                    src_counter <= 4'd0;
                    dst_counter <= 4'd0;
                    device_counter <= 4'd0;
                    path_counter <= 4'd0;
                    cycle_count <= 8'd0;
                    min_distance <= 32'd0;
                    
                    // Initialize temp arrays
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_gravity[i] <= gravity[i];
                        temp_adj_matrix[i] <= adj_matrix[i];
                    end
                    next_state = COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all device placements
                    if (device_counter >= num_nodes) begin
                        next_state = FINISH;
                    end else begin
                        // Apply gravity dispersal device effect
                        integer i, j;
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_gravity[i] <= gravity[i];
                        end
                        
                        // Device effect on selected node
                        if (temp_gravity[device_counter] > 16'd1) begin
                            temp_gravity[device_counter] <= temp_gravity[device_counter] - 16'd1;
                        end else begin
                            temp_gravity[device_counter] <= 16'd1;
                        end
                        
                        // Device effect on neighbors
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adj_matrix[device_counter][i] == 1'b1 && temp_gravity[i] < 16'd65535) begin
                                temp_gravity[i] <= temp_gravity[i] + 16'd1;
                            end
                        end
                        
                        // Process all source-destination pairs
                        if (src_counter >= num_nodes) begin
                            src_counter <= 4'd0;
                            if (dst_counter >= num_nodes) begin
                                dst_counter <= 4'd0;
                                device_counter <= device_counter + 4'd1;
                            end else begin
                                dst_counter <= dst_counter + 4'd1;
                            end
                        end else begin
                            // Check if source and destination are different types
                            if (types[src_counter] != types[dst_counter]) begin
                                // Find paths between src and dst
                                if (path_counter == 4'd0) begin
                                    // Direct path (1 hop)
                                    current_path[0] <= src_counter;
                                    current_path[1] <= dst_counter;
                                    current_path_length <= 2'd1;
                                    
                                    // Calculate distance for this path
                                    current_distance <= calculate_path_distance(current_path, current_path_length, temp_gravity);
                                    
                                    // Update minimum distance
                                    if (min_distance == 32'd0 || current_distance < min_distance) begin
                                        min_distance <= current_distance;
                                    end
                                    
                                    path_counter <= path_counter + 4'd1;
                                end else if (path_counter == 4'd1) begin
                                    // 2-hop path via common neighbor
                                    integer k;
                                    reg found_path;
                                    found_path = 1'b0;
                                    
                                    for (k = 0; k < 16; k = k + 1) begin
                                        if (adj_matrix[src_counter][k] == 1'b1 && adj_matrix[k][dst_counter] == 1'b1 && k != src_counter && k != dst_counter) begin
                                            current_path[0] <= src_counter;
                                            current_path[1] <= k;
                                            current_path[2] <= dst_counter;
                                            current_path_length <= 2'd2;
                                            
                                            // Calculate distance for this path
                                            current_distance <= calculate_path_distance(current_path, current_path_length, temp_gravity);
                                            
                                            // Update minimum distance
                                            if (min_distance == 32'd0 || current_distance < min_distance) begin
                                                min_distance <= current_distance;
                                            end
                                            
                                            found_path = 1'b1;
                                            break;
                                        end
                                    end
                                    
                                    if (!found_path) begin
                                        path_counter <= path_counter + 4'd1;
                                    end
                                end else begin
                                    path_counter <= 4'd0;
                                    src_counter <= src_counter + 4'd1;
                                end
                            end else begin
                                path_counter <= 4'd0;
                                src_counter <= src_counter + 4'd1;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= min_distance;
                    done <= 1'b1;
                end
                
                default: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Function to calculate path distance
    function [31:0] calculate_path_distance;
        input [3:0] path [0:2];
        input [1:0] path_length;
        input [15:0] gravity_values [0:15];
        reg [15:0] Cap [0:15];
        reg [15:0] Pot [0:15];
        reg [15:0] Ind [0:15];
        reg [15:0] Term1 [0:15];
        reg [15:0] Term2 [0:15];
        reg [31:0] Prod [0:15];
        reg [31:0] sum;
        integer i;
        
        begin
            sum = 32'd0;
            
            // Calculate sequences
            for (i = 0; i < path_length; i = i + 1) begin
                if (i > 0) begin
                    // Cap sequence
                    if (gravity_values[path[i]] + gravity_values[path[i-1]] > 16'd65535) begin
                        Cap[i] = 16'd65535;
                    end else begin
                        Cap[i] = gravity_values[path[i]] + gravity_values[path[i-1]];
                    end
                    
                    // Pot sequence
                    if (gravity_values[path[i]] > gravity_values[path[i-1]]) begin
                        Pot[i] = gravity_values[path[i]] - gravity_values[path[i-1]];
                    end else begin
                        Pot[i] = gravity_values[path[i-1]] - gravity_values[path[i]];
                    end
                    
                    // Ind sequence
                    Ind[i] = gravity_values[path[i]] * gravity_values[path[i-1]];
                    
                    // Term1 sequence
                    Term1[i] = Cap[i] * Cap[i];
                    
                    // Term2 sequence
                    if (Term1[i] > Ind[i]) begin
                        Term2[i] = Term1[i] - Ind[i];
                    end else begin
                        Term2[i] = 16'd0;
                    end
                    
                    // Prod sequence
                    Prod[i] = Pot[i] * Term2[i];
                    
                    // Sum
                    sum = sum + Prod[i];
                end
            end
            
            calculate_path_distance = sum;
        end
    endfunction
    
endmodule