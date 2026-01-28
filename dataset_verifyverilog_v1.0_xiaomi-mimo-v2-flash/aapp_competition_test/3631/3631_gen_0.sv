module BeaconVisibility(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [15:0] beacon_x [0:15],
    input wire [15:0] beacon_y [0:15],
    input wire [15:0] mountain_x [0:15],
    input wire [15:0] mountain_y [0:15],
    input wire [15:0] mountain_r [0:15],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] RESET_GRAPH   = 4'd1;
    localparam [3:0] PAIR_LOOP     = 4'd2;
    localparam [3:0] CHECK_VIS     = 4'd3;
    localparam [3:0] MOUNTAIN_LOOP = 4'd4;
    localparam [3:0] DIST_CALC     = 4'd5;
    localparam [3:0] UPDATE_GRAPH  = 4'd6;
    localparam [3:0] COUNT_COMP    = 4'd7;
    localparam [3:0] BFS_START     = 4'd8;
    localparam [3:0] BFS_PROCESS   = 4'd9;
    localparam [3:0] COUNT_DONE    = 4'd10;

    // Registers for state machine
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] state_counter;
    
    // Graph adjacency matrix (16x16 bits)
    reg [15:0] graph [0:15];
    reg [3:0] i, j, k, l;
    reg [3:0] i_next, j_next, k_next, m_idx;
    
    // BFS variables
    reg [15:0] visited;
    reg [15:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] queue_count;
    reg [3:0] components;
    
    // Fixed-point intermediate calculations
    reg signed [31:0] dx, dy, len_sq, proj;
    reg signed [31:0] cx, cy, r_sq;
    reg signed [31:0] dist_sq;
    reg signed [31:0] temp_x, temp_y;
    
    // Visibility flag
    reg visible;
    reg visible_flag;
    
    // Counter for cycles
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            m_idx <= 4'd0;
            visible_flag <= 1'b0;
            components <= 4'd0;
            visited <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            // Initialize graph
            for (l = 4'd0; l < 4'd16; l = l + 4'd1) begin
                graph[l] <= 16'd0;
            end
        end else begin
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 4'd0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= RESET_GRAPH;
                    end
                end
                
                RESET_GRAPH: begin
                    // Reset adjacency matrix
                    if (i < n && i < 4'd16) begin
                        graph[i] <= 16'd0;
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= PAIR_LOOP;
                    end
                end
                
                PAIR_LOOP: begin
                    if (i < n && i < 4'd16) begin
                        if (j < n && j < 4'd16) begin
                            if (i != j) begin
                                visible_flag <= 1'b1;
                                k <= 4'd0;
                                state <= CHECK_VIS;
                            end else begin
                                j <= j + 4'd1;
                            end
                        end else begin
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end
                    end else begin
                        i <= 4'd0;
                        state <= COUNT_COMP;
                    end
                end
                
                CHECK_VIS: begin
                    if (k < m && k < 4'd16 && visible_flag) begin
                        m_idx <= k;
                        k <= k + 4'd1;
                        state <= MOUNTAIN_LOOP;
                    end else begin
                        if (visible_flag) begin
                            // Set adjacency bit
                            graph[i] <= graph[i] | (16'd1 << j);
                            graph[j] <= graph[j] | (16'd1 << i);
                        end
                        j <= j + 4'd1;
                        state <= PAIR_LOOP;
                    end
                end
                
                MOUNTAIN_LOOP: begin
                    // Check visibility with this mountain
                    // Calculate line segment vector
                    dx <= beacon_x[j] - beacon_x[i];
                    dy <= beacon_y[j] - beacon_y[i];
                    
                    // Mountain center
                    cx <= mountain_x[m_idx];
                    cy <= mountain_y[m_idx];
                    r_sq <= mountain_r[m_idx] * mountain_r[m_idx];
                    
                    state <= DIST_CALC;
                end
                
                DIST_CALC: begin
                    // Calculate projection of mountain center onto line segment
                    // t = (C - A) . (B - A) / |B - A|^2
                    
                    // Get segment squared length
                    len_sq <= dx * dx + dy * dy;
                    
                    // Calculate projection
                    temp_x <= (cx - beacon_x[i]) * dx;
                    temp_y <= (cy - beacon_y[i]) * dy;
                    
                    // Use delay for division and distance calculation
                    state <= UPDATE_GRAPH;
                end
                
                UPDATE_GRAPH: begin
                    // Complete distance calculation
                    // t = proj / len_sq
                    if (len_sq != 32'd0) begin
                        proj <= temp_x + temp_y;
                        
                        // Clamp t to [0, 1]
                        if (proj <= 32'd0) begin
                            // Closest to point A
                            temp_x <= beacon_x[i] - cx;
                            temp_y <= beacon_y[i] - cy;
                        end else if (proj >= len_sq) begin
                            // Closest to point B
                            temp_x <= beacon_x[j] - cx;
                            temp_y <= beacon_y[j] - cy;
                        end else begin
                            // Closest to line
                            // Distance squared = |C-A|^2 - (proj^2)/|B-A|^2
                            temp_x <= (cx - beacon_x[i]) * (cx - beacon_x[i]) + 
                                     (cy - beacon_y[i]) * (cy - beacon_y[i]) - 
                                     (proj * proj) / len_sq;
                        end
                    end
                    
                    // Check if distance < radius
                    // Use simplified check with overflow protection
                    if (len_sq == 32'd0) begin
                        // Same point
                    end else if (proj <= 32'd0) begin
                        dist_sq <= (beacon_x[i] - cx) * (beacon_x[i] - cx) + 
                                  (beacon_y[i] - cy) * (beacon_y[i] - cy);
                        if (dist_sq < r_sq) begin
                            visible_flag <= 1'b0;
                        end
                    end else if (proj >= len_sq) begin
                        dist_sq <= (beacon_x[j] - cx) * (beacon_x[j] - cx) + 
                                  (beacon_y[j] - cy) * (beacon_y[j] - cy);
                        if (dist_sq < r_sq) begin
                            visible_flag <= 1'b0;
                        end
                    end else begin
                        // Line to point distance
                        // Use cross product for perpendicular distance
                        // |(C-A) × (B-A)|^2 / |B-A|^2
                        temp_x <= (cx - beacon_x[i]) * dy - (cy - beacon_y[i]) * dx;
                        // Square and compare
                        dist_sq <= temp_x * temp_x;
                        // Need to divide by len_sq, compare with r_sq * len_sq
                        if (dist_sq < (r_sq * len_sq)) begin
                            visible_flag <= 1'b0;
                        end
                    end
                    
                    state <= CHECK_VIS;
                end
                
                COUNT_COMP: begin
                    // Count connected components using BFS
                    if (i < n && i < 4'd16) begin
                        if (!visited[i]) begin
                            // New component found
                            visited <= visited | (16'd1 << i);
                            components <= components + 4'd1;
                            queue[4'd0] <= i;
                            queue_head <= 4'd0;
                            queue_tail <= 4'd1;
                            queue_count <= 4'd1;
                            state <= BFS_START;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        result <= components;
                        state <= COUNT_DONE;
                    end
                end
                
                BFS_START: begin
                    if (queue_count > 4'd0) begin
                        queue_count <= queue_count - 4'd1;
                        k <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        state <= BFS_PROCESS;
                    end else begin
                        i <= i + 4'd1;
                        state <= COUNT_COMP;
                    end
                end
                
                BFS_PROCESS: begin
                    // Add neighbors to queue
                    if (j < n && j < 4'd16) begin
                        if ((graph[k] >> j) & 16'd1) begin
                            if (!visited[j]) begin
                                visited <= visited | (16'd1 << j);
                                queue[queue_tail] <= j;
                                queue_tail <= queue_tail + 4'd1;
                                queue_count <= queue_count + 4'd1;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        state <= BFS_START;
                    end
                end
                
                COUNT_DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule