module mst_mht_weight (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire [7:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [11:0] result,
    output reg done
);

    // State machine declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] FIND_MIN  = 3'd2;
    localparam [2:0] ADD_VERTEX = 3'd3;
    localparam [2:0] UPDATE_DIST = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [7:0] visited;              // Track visited vertices
    reg [11:0] dist [0:7];          // Minimum distances to MST
    reg [3:0] vertex_idx;           // Current vertex index for loops
    reg [3:0] prev_vertex;          // Previous vertex added to MST
    reg [3:0] next_vertex;          // Next vertex to add to MST
    reg [11:0] temp_dist;           // Temporary distance calculation
    reg [11:0] current_min;         // Current minimum distance
    reg [3:0] current_min_idx;      // Index of current minimum
    reg [3:0] iteration_count;      // Track iterations (N-1 times)
    reg [11:0] temp_result;         // Temporary result accumulator
    reg [3:0] calc_vertex;          // Vertex being calculated in distance
    reg [2:0] cycle_counter;        // For MAX_CYCLES protection
    reg signed [8:0] dx, dy;        // For signed subtraction
    reg signed [8:0] abs_dx, abs_dy; // For absolute value
    
    localparam [2:0] MAX_CYCLES = 3'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 12'd0;
            done <= 1'b0;
            visited <= 8'd0;
            vertex_idx <= 4'd0;
            prev_vertex <= 4'd0;
            next_vertex <= 4'd0;
            temp_dist <= 12'd0;
            current_min <= 12'hFFF;
            current_min_idx <= 4'd0;
            iteration_count <= 4'd0;
            temp_result <= 12'd0;
            calc_vertex <= 4'd0;
            cycle_counter <= 3'd0;
            dx <= 9'sd0;
            dy <= 9'sd0;
            abs_dx <= 9'sd0;
            abs_dy <= 9'sd0;
            // Initialize dist array
            dist[0] <= 12'hFFF;
            dist[1] <= 12'hFFF;
            dist[2] <= 12'hFFF;
            dist[3] <= 12'hFFF;
            dist[4] <= 12'hFFF;
            dist[5] <= 12'hFFF;
            dist[6] <= 12'hFFF;
            dist[7] <= 12'hFFF;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start && N > 4'd0 && N <= 4'd8) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Initialize MST with vertex 0
                    visited <= 8'b00000001;  // Vertex 0 visited
                    temp_result <= 12'd0;
                    
                    // Initialize distances for vertex 0 to others
                    if (vertex_idx < N) begin
                        // Calculate distance from vertex 0 to vertex_idx
                        // Get coordinates
                        case (vertex_idx)
                            4'd0: begin dx <= 9'sd0; dy <= 9'sd0; end
                            4'd1: begin dx <= $signed({1'b0, x1}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y1}) - $signed({1'b0, y0}); end
                            4'd2: begin dx <= $signed({1'b0, x2}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y2}) - $signed({1'b0, y0}); end
                            4'd3: begin dx <= $signed({1'b0, x3}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y3}) - $signed({1'b0, y0}); end
                            4'd4: begin dx <= $signed({1'b0, x4}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y4}) - $signed({1'b0, y0}); end
                            4'd5: begin dx <= $signed({1'b0, x5}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y5}) - $signed({1'b0, y0}); end
                            4'd6: begin dx <= $signed({1'b0, x6}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y6}) - $signed({1'b0, y0}); end
                            4'd7: begin dx <= $signed({1'b0, x7}) - $signed({1'b0, x0}); dy <= $signed({1'b0, y7}) - $signed({1'b0, y0}); end
                        endcase
                        
                        // Calculate absolute values
                        if (dx[8]) abs_dx <= -dx; else abs_dx <= dx;
                        if (dy[8]) abs_dy <= -dy; else abs_dy <= dy;
                        
                        vertex_idx <= vertex_idx + 4'd1;
                        next_state <= INIT;
                    end else begin
                        vertex_idx <= 4'd1;  // Start checking from vertex 1
                        next_state <= FIND_MIN;
                    end
                end
                
                FIND_MIN: begin
                    // Find minimum distance vertex not yet visited
                    if (vertex_idx < N && current_min_idx < N) begin
                        if (!visited[vertex_idx] && dist[vertex_idx] < current_min) begin
                            current_min <= dist[vertex_idx];
                            current_min_idx <= vertex_idx;
                        end
                        vertex_idx <= vertex_idx + 4'd1;
                        next_state <= FIND_MIN;
                    end else begin
                        // Check if valid vertex found
                        if (current_min < 12'hFFF && current_min_idx < N) begin
                            next_vertex <= current_min_idx;
                            next_state <= ADD_VERTEX;
                        end else begin
                            // No valid vertex found (shouldn't happen for N>0)
                            next_state <= DONE;
                        end
                    end
                end
                
                ADD_VERTEX: begin
                    // Add vertex to MST
                    visited[next_vertex] <= 1'b1;
                    temp_result <= temp_result + current_min;
                    prev_vertex <= next_vertex;
                    calc_vertex <= 4'd0;
                    cycle_counter <= 3'd0;
                    next_state <= UPDATE_DIST;
                end
                
                UPDATE_DIST: begin
                    // Update distances for unvisited vertices
                    if (calc_vertex < N && cycle_counter < MAX_CYCLES) begin
                        if (!visited[calc_vertex]) begin
                            // Calculate distance from new vertex (prev_vertex) to calc_vertex
                            // Get coordinates based on indices
                            // For each vertex, compute signed difference
                            dx <= get_x(calc_vertex) - get_x(prev_vertex);
                            dy <= get_y(calc_vertex) - get_y(prev_vertex);
                            
                            // Calculate absolute values
                            if (get_x(calc_vertex) - get_x(prev_vertex)[8]) 
                                abs_dx <= -(get_x(calc_vertex) - get_x(prev_vertex));
                            else 
                                abs_dx <= get_x(calc_vertex) - get_x(prev_vertex);
                                
                            if (get_y(calc_vertex) - get_y(prev_vertex)[8]) 
                                abs_dy <= -(get_y(calc_vertex) - get_y(prev_vertex));
                            else 
                                abs_dy <= get_y(calc_vertex) - get_y(prev_vertex);
                            
                            temp_dist <= {4'd0, abs_dx[7:0]} + {4'd0, abs_dy[7:0]};
                            
                            // Update if this distance is smaller
                            if (temp_dist < dist[calc_vertex]) begin
                                dist[calc_vertex] <= temp_dist;
                            end
                        end
                        calc_vertex <= calc_vertex + 4'd1;
                        cycle_counter <= cycle_counter + 3'd1;
                        next_state <= UPDATE_DIST;
                    end else begin
                        // Reset for next iteration
                        current_min <= 12'hFFF;
                        current_min_idx <= 4'd0;
                        vertex_idx <= 4'd0;
                        iteration_count <= iteration_count + 4'd1;
                        
                        // Check if we're done (visited N vertices, which means N-1 iterations + 1 initial)
                        if (iteration_count + 4'd1 >= N - 4'd1) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= FIND_MIN;
                        end
                    end
                end
                
                DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
    
    // Helper functions to get coordinates
    function automatic signed [8:0] get_x(input [3:0] idx);
        case (idx)
            4'd0: get_x = $signed({1'b0, x0});
            4'd1: get_x = $signed({1'b0, x1});
            4'd2: get_x = $signed({1'b0, x2});
            4'd3: get_x = $signed({1'b0, x3});
            4'd4: get_x = $signed({1'b0, x4});
            4'd5: get_x = $signed({1'b0, x5});
            4'd6: get_x = $signed({1'b0, x6});
            4'd7: get_x = $signed({1'b0, x7});
            default: get_x = $signed(9'd0);
        endcase
    endfunction
    
    function automatic signed [8:0] get_y(input [3:0] idx);
        case (idx)
            4'd0: get_y = $signed({1'b0, y0});
            4'd1: get_y = $signed({1'b0, y1});
            4'd2: get_y = $signed({1'b0, y2});
            4'd3: get_y = $signed({1'b0, y3});
            4'd4: get_y = $signed({1'b0, y4});
            4'd5: get_y = $signed({1'b0, y5});
            4'd6: get_y = $signed({1'b0, y6});
            4'd7: get_y = $signed({1'b0, y7});
            default: get_y = $signed(9'd0);
        endcase
    endfunction

endmodule