module SWERC_solver (
    input clk, rst_n, start,
    input [3:0] N, P, X, Y,  // Scaled: N<=8, P<=16
    input [3:0] swerc_count,    // Number of SWERC banks
    input [31:0] swerc_list,    // Packed SWERC bank IDs (8 x 4-bit)
    input [31:0] edge_data,     // Packed edge info: 4 x (3-bit a, 3-bit b, 26-bit fee)
    output reg [31:0] result,   // Result: T value or special codes
    output reg done, error
);
    // Fixed-point arithmetic: Q16.16 for fees, Q8.8 for T values
    parameter FEE_WIDTH = 32;
    parameter T_WIDTH = 16;
    parameter MAX_NODES = 8;
    parameter MAX_EDGES = 16;
    
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_INPUT = 3'd1;
    localparam [2:0] COMPUTE_BASE = 3'd2;
    localparam [2:0] BINARY_SEARCH = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    reg [2:0] state;
    
    // Internal storage for graph
    reg [7:0] adj_matrix [0:7][0:7]; // 8x8 adjacency matrix with packed fees
    reg [7:0] swerc_mask; // Bitmask of SWERC nodes
    
    // Computation registers
    reg [15:0] base_cost_swerc, base_cost_all;
    reg [7:0] edge_count_swerc, edge_count_all;
    reg [15:0] T_low, T_high, T_mid;
    reg [7:0] search_iterations;
    
    // Dijkstra state machine states
    localparam [1:0] DIJKSTRA_IDLE = 2'd0;
    localparam [1:0] DIJKSTRA_INIT = 2'd1;
    localparam [1:0] DIJKSTRA_PROCESS = 2'd2;
    localparam [1:0] DIJKSTRA_DONE = 2'd3;
    reg [1:0] dijkstra_state;
    
    // Dijkstra registers
    reg [2:0] current_node;
    reg [7:0] visited [0:7];
    reg [15:0] distance [0:7];
    reg [2:0] min_node;
    reg [15:0] min_distance;
    reg [2:0] dijkstra_counter;
    reg [2:0] dijkstra_target;
    reg [15:0] dijkstra_result;
    
    // Edge unpacking
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result <= 32'd0;
            
            // Initialize Dijkstra registers
            dijkstra_state <= DIJKSTRA_IDLE;
            dijkstra_counter <= 3'd0;
            dijkstra_target <= 3'd0;
            dijkstra_result <= 16'd0;
            
            // Initialize graph and SWERC mask
            swerc_mask <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj_matrix[i][j] <= 8'd0;
                end
            end
            
            // Initialize Dijkstra arrays
            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 8'd0;
                distance[i] <= 16'd32767;
            end
            
            // Initialize computation registers
            base_cost_swerc <= 16'd0;
            base_cost_all <= 16'd0;
            edge_count_swerc <= 8'd0;
            edge_count_all <= 8'd0;
            T_low <= 16'd1;
            T_high <= 16'd1000;
            search_iterations <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE_INPUT;
                        done <= 1'b0;
                        error <= 1'b0;
                    end
                end
                
                PARSE_INPUT: begin
                    // Unpack SWERC list into bitmask
                    swerc_mask <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < swerc_count) begin
                            swerc_mask[i] <= swerc_list[i*4 +: 4][0];
                        end
                    end
                    
                    // Unpack edges into adjacency matrix
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < P) begin
                            reg [2:0] a, b;
                            reg [25:0] fee;
                            a <= edge_data[i*32 +: 3];
                            b <= edge_data[i*32 + 3 +: 3];
                            fee <= edge_data[i*32 + 6 +: 26];
                            adj_matrix[a][b] <= fee[25:18];
                            adj_matrix[b][a] <= fee[25:18];
                        end
                    end
                    
                    state <= COMPUTE_BASE;
                end
                
                COMPUTE_BASE: begin
                    // Compute base costs using Dijkstra
                    dijkstra_state <= DIJKSTRA_INIT;
                    dijkstra_target <= X;
                    state <= COMPUTE_BASE;
                end
                
                BINARY_SEARCH: begin
                    if (T_low <= T_high && search_iterations < 8'd20) begin
                        T_mid <= (T_low + T_high) >> 1;
                        
                        // Check if SWERC path is cheaper with T_mid
                        // Compare: (base_cost_swerc + edge_count_swerc * T_mid)
                        //       vs (base_cost_all + edge_count_all * T_mid)
                        reg [31:0] swerc_total, all_total;
                        swerc_total <= {16'd0, base_cost_swerc} + {16'd0, edge_count_swerc} * {16'd0, T_mid};
                        all_total <= {16'd0, base_cost_all} + {16'd0, edge_count_all} * {16'd0, T_mid};
                        
                        if (swerc_total < all_total) begin
                            T_low <= T_mid + 16'd1;
                        end else begin
                            T_high <= T_mid - 16'd1;
                        end
                        
                        search_iterations <= search_iterations + 8'd1;
                        state <= BINARY_SEARCH;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Special cases: Impossible (result=0), Infinity (result=1), T value
                    if (base_cost_swerc == 16'hFFFF) begin
                        result <= 32'd0; // Impossible
                        error <= 1'b1;
                    end else if (base_cost_all == 16'hFFFF) begin
                        result <= 32'd1; // Infinity
                    end else begin
                        result <= {16'd0, T_low}; // Maximum valid T
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Dijkstra state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dijkstra_state <= DIJKSTRA_IDLE;
        end else begin
            case (dijkstra_state)
                DIJKSTRA_IDLE: begin
                    if (state == COMPUTE_BASE) begin
                        dijkstra_state <= DIJKSTRA_INIT;
                    end
                end
                
                DIJKSTRA_INIT: begin
                    // Initialize for Dijkstra
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 8'd0;
                        distance[i] <= 16'd32767;
                    end
                    distance[X] <= 16'd0;
                    current_node <= X;
                    dijkstra_counter <= 3'd0;
                    dijkstra_state <= DIJKSTRA_PROCESS;
                end
                
                DIJKSTRA_PROCESS: begin
                    if (dijkstra_counter < 3'd8) begin
                        // Find unvisited node with minimum distance
                        min_distance <= 16'd32767;
                        min_node <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (!visited[i] && distance[i] < min_distance) begin
                                min_distance <= distance[i];
                                min_node <= i;
                            end
                        end
                        
                        if (min_distance == 16'd32767) begin
                            dijkstra_state <= DIJKSTRA_DONE;
                        end else begin
                            current_node <= min_node;
                            visited[current_node] <= 8'd1;
                            
                            // Update distances
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!visited[i] && adj_matrix[current_node][i] != 8'd0) begin
                                    reg [15:0] new_dist;
                                    new_dist <= distance[current_node] + adj_matrix[current_node][i];
                                    if (new_dist < distance[i]) begin
                                        distance[i] <= new_dist;
                                    end
                                end
                            end
                            
                            dijkstra_counter <= dijkstra_counter + 3'd1;
                        end
                    end else begin
                        dijkstra_state <= DIJKSTRA_DONE;
                    end
                end
                
                DIJKSTRA_DONE: begin
                    dijkstra_result <= distance[Y];
                    
                    // Store results based on target
                    if (dijkstra_target == X) begin
                        base_cost_all <= dijkstra_result;
                        edge_count_all <= 8'd0; // Simplified
                        
                        // Compute SWERC path
                        dijkstra_target <= 3'd7; // Dummy for SWERC
                        dijkstra_state <= DIJKSTRA_INIT;
                    end else begin
                        base_cost_swerc <= dijkstra_result;
                        edge_count_swerc <= 8'd0; // Simplified
                        state <= BINARY_SEARCH;
                    end
                end
                
                default: dijkstra_state <= DIJKSTRA_IDLE;
            endcase
        end
    end
endmodule