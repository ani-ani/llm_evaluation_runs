module min_vertices_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] K,
    input wire [63:0] vertices [7:0],
    input wire [63:0] points [7:0],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCHING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    
    // Control registers
    reg [7:0] subset_mask;          // Current subset of vertices to test
    reg [3:0] min_vertices;         // Track minimum found
    reg [3:0] valid_count;          // Count of vertices in current subset
    reg [3:0] point_idx;            // Current point being checked
    reg [3:0] vertex_idx;           // Current vertex in polygon for point check
    
    // Status flags
    reg all_points_inside;
    reg subset_valid;
    reg is_subset_complete;
    
    // Intermediate values for cross product calculation
    reg signed [63:0] dx1, dy1;    // Edge vector
    reg signed [63:0] dx2, dy2;    // Point to vertex vector
    reg signed [127:0] cross_prod; // Cross product result
    reg cross_sign;                 // Sign of cross product (0=neg, 1=pos)
    reg sign_consistent;           // All cross products have same sign
    reg first_cross_set;           // First cross product sign captured
    reg first_cross_sign;          // Reference sign
    
    // Helper array to map subset mask to ordered vertices
    reg [2:0] ordered_vertices [7:0]; // Stores indices of selected vertices in order
    reg [2:0] vertex_count;           // Number of selected vertices
    reg [2:0] ordered_idx;            // Current index in ordered list
    
    // Sequential state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            done <= 1'b0;
            subset_mask <= 8'b0;
            min_vertices <= 4'b15; // Initialize to max (N <= 8, 15 is safe)
            point_idx <= 4'b0;
            vertex_idx <= 4'b0;
            valid_count <= 4'b0;
            is_subset_complete <= 1'b0;
            first_cross_set <= 1'b0;
            first_cross_sign <= 1'b0;
            sign_consistent <= 1'b0;
            vertex_count <= 3'b0;
            ordered_idx <= 3'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        subset_mask <= 8'b0;
                        min_vertices <= 4'b15;
                        done <= 1'b0;
                        // Start with first subset (0 is skipped, we increment first)
                    end
                end
                
                SEARCHING: begin
                    // Main iteration logic
                    if (!is_subset_complete) begin
                        // Iterate subsets systematically
                        subset_mask <= subset_mask + 1;
                        
                        if (subset_mask == 8'hFF) begin
                            is_subset_complete <= 1'b1;
                        end
                    end else if (state == SEARCHING && is_subset_complete) begin
                        // Done iterating all subsets
                        state <= DONE;
                        done <= 1'b1;
                        result <= min_vertices;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
            
            // Reset counters when moving to new subset
            if (state == SEARCHING && !is_subset_complete) begin
                point_idx <= 4'b0;
                vertex_idx <= 4'b0;
                first_cross_set <= 1'b0;
                sign_consistent <= 1'b1; // Assume valid until proven otherwise
                ordered_idx <= 3'b0;
            end
        end
    end
    
    // Combinational logic for state machine
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SEARCHING;
            end
            SEARCHING: begin
                if (is_subset_complete) next_state = DONE;
                else next_state = SEARCHING;
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end
    
    // Build ordered vertex list from subset mask
    integer i;
    always @(*) begin
        vertex_count = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (subset_mask[i]) begin
                ordered_vertices[vertex_count] = i;
                vertex_count = vertex_count + 1;
            end
        end
    end
    
    // Count valid vertices in subset
    integer j;
    always @(*) begin
        valid_count = 0;
        for (j = 0; j < 8; j = j + 1) begin
            if (subset_mask[j]) valid_count = valid_count + 1;
        end
    end
    
    // Point-in-polygon check logic (single cycle per check, pipelined state transitions)
    // We assume sequential checking: for each point, check all edges of subset polygon
    always @(*) begin
        // Default values
        cross_prod = 0;
        cross_sign = 0;
        all_points_inside = 1'b1;
        subset_valid = 1'b0;
        
        // Calculate cross product for current edge and point
        if (vertex_idx < vertex_count && vertex_idx >= 0 && point_idx < K) begin
            // Get current and next vertex (handle wrap-around)
            reg [2:0] v_idx0 = ordered_vertices[vertex_idx];
            reg [2:0] v_idx1 = ordered_vertices[(vertex_idx + 1) % vertex_count];
            
            // Extract coordinates
            reg signed [31:0] x0 = vertices[v_idx0][63:32];
            reg signed [31:0] y0 = vertices[v_idx0][31:0];
            reg signed [31:0] x1 = vertices[v_idx1][63:32];
            reg signed [31:0] y1 = vertices[v_idx1][31:0];
            reg signed [31:0] px = points[point_idx][63:32];
            reg signed [31:0] py = points[point_idx][31:0];
            
            // Edge vector: (x1 - x0, y1 - y0)
            dx1 = { {32{x1[31]}}, x1 } - { {32{x0[31]}}, x0 };
            dy1 = { {32{y1[31]}}, y1 } - { {32{y0[31]}}, y0 };
            
            // Point to vertex vector: (px - x0, py - y0)
            dx2 = { {32{px[31]}}, px } - { {32{x0[31]}}, x0 };
            dy2 = { {32{py[31]}}, py } - { {32{y0[31]}}, y0 };
            
            // Cross product: dx1 * dy2 - dy1 * dx2
            cross_prod = (dx1 * dy2) - (dy1 * dx2);
            cross_sign = cross_prod[127]; // Sign bit
            
            // Check consistency
            if (vertex_idx == 0) begin
                // First edge, set reference sign
                first_cross_set = 1'b1;
                first_cross_sign = cross_sign;
                sign_consistent = 1'b1;
            end else begin
                // Compare with reference
                if (first_cross_sign != cross_sign) begin
                    sign_consistent = 1'b0;
                end
            end
        end
        
        // Determine if current point is inside
        if (vertex_idx == vertex_count && vertex_count > 0) begin
            // Finished checking all edges for this point
            if (!sign_consistent || vertex_count < 3) begin
                all_points_inside = 1'b0;
            end else begin
                all_points_inside = 1'b1;
            end
        end
        
        // Check if subset is valid (all points inside)
        if (vertex_count >= 3 && valid_count > 0 && point_idx == K && K > 0 && all_points_inside) begin
            subset_valid = 1'b1;
        end else if (vertex_count >= 3 && K == 0) begin
            // If no points, any subset of 3+ vertices is valid
            subset_valid = 1'b1;
        end
    end
    
    // Sequential logic for point checking progression
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            point_idx <= 4'b0;
            vertex_idx <= 4'b0;
        end else if (state == SEARCHING && !is_subset_complete) begin
            // Process points sequentially
            if (point_idx < K) begin
                // Process edges sequentially for current point
                if (vertex_idx <= vertex_count) begin
                    vertex_idx <= vertex_idx + 1;
                    if (vertex_idx == vertex_count) begin
                        // Move to next point
                        vertex_idx <= 0;
                        point_idx <= point_idx + 1;
                    end
                end
            end else if (K == 0) begin
                // No points, just need valid count
                point_idx <= 0;
                vertex_idx <= 0;
            end
            
            // Update minimum if valid subset found
            if (subset_valid && valid_count < min_vertices) begin
                min_vertices <= valid_count;
            end
        end
    end

endmodule