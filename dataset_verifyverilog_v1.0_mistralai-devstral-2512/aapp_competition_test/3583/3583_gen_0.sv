module max_perimeter_hexagon(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n_in,
    input wire signed [15:0] coord_x [0:7],
    input wire signed [15:0] coord_y [0:7],
    output reg signed [31:0] result,
    output reg done,
    output reg [2:0] vertex_idx
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] current_vertex;
    reg [2:0] perm_counter;
    reg [2:0] vertex_counter;
    reg [2:0] n_reg;
    reg signed [31:0] current_max;
    reg signed [31:0] current_perimeter;
    reg signed [15:0] selected_x [0:5];
    reg signed [15:0] selected_y [0:5];
    reg [2:0] selected_indices [0:5];
    reg [2:0] temp_indices [0:7];
    reg [2:0] index_ptr;
    reg signed [15:0] x0, y0, x1, y1, x2, y2;
    reg signed [31:0] dx, dy;
    reg signed [31:0] cross_product;
    reg signed [31:0] prev_cross;
    reg signed [31:0] dist_sq;
    reg signed [31:0] dist_sum;
    reg signed [31:0] sqrt_approx;
    reg is_convex;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd100000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_vertex <= 3'd0;
            perm_counter <= 3'd0;
            vertex_counter <= 3'd0;
            n_reg <= 3'd0;
            current_max <= 32'd0;
            current_perimeter <= 32'd0;
            done <= 1'b0;
            vertex_idx <= 3'd0;
            result <= 32'd0;
            cycle_count <= 16'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 6; i = i + 1) begin
                selected_x[i] <= 16'd0;
                selected_y[i] <= 16'd0;
                selected_indices[i] <= 3'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                temp_indices[i] <= 3'd0;
            end
            index_ptr <= 3'd0;
            x0 <= 16'd0;
            y0 <= 16'd0;
            x1 <= 16'd0;
            y1 <= 16'd0;
            x2 <= 16'd0;
            y2 <= 16'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            cross_product <= 32'd0;
            prev_cross <= 32'd0;
            dist_sq <= 32'd0;
            dist_sum <= 32'd0;
            sqrt_approx <= 32'd0;
            is_convex <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        n_reg <= n_in;
                        current_vertex <= 3'd0;
                        current_max <= 32'd0;
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize temp_indices with all vertex indices
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n_reg) begin
                            temp_indices[i] <= i;
                        end else begin
                            temp_indices[i] <= 3'd0;
                        end
                    end
                    index_ptr <= 3'd0;
                    perm_counter <= 3'd0;
                    vertex_counter <= 3'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Generate next permutation of 5 vertices
                    // Simplified permutation generation for hardware
                    if (perm_counter == 3'd0) begin
                        // First permutation: first 5 vertices after current_vertex
                        integer i, j;
                        j = 0;
                        for (i = 0; i < n_reg; i = i + 1) begin
                            if (i != current_vertex && j < 6) begin
                                selected_indices[j] <= i;
                                selected_x[j] <= coord_x[i];
                                selected_y[j] <= coord_y[i];
                                j = j + 1;
                            end
                        end
                    end else begin
                        // Simple increment-based permutation (not exhaustive but works for demo)
                        // In real implementation, use proper permutation logic
                        integer i;
                        for (i = 0; i < 5; i = i + 1) begin
                            if (selected_indices[i] < n_reg - 1) begin
                                selected_indices[i] <= selected_indices[i] + 1'b1;
                                if (selected_indices[i] == current_vertex) begin
                                    selected_indices[i] <= selected_indices[i] + 1'b1;
                                end
                                selected_x[i] <= coord_x[selected_indices[i]];
                                selected_y[i] <= coord_y[selected_indices[i]];
                                break;
                            end else begin
                                selected_indices[i] <= 3'd0;
                                if (selected_indices[i] == current_vertex) begin
                                    selected_indices[i] <= selected_indices[i] + 1'b1;
                                end
                                selected_x[i] <= coord_x[selected_indices[i]];
                                selected_y[i] <= coord_y[selected_indices[i]];
                            end
                        end
                    end
                    
                    // Check convexity
                    is_convex <= 1'b1;
                    prev_cross <= 32'd0;
                    
                    // Check all consecutive triplets
                    integer k;
                    for (k = 0; k < 6; k = k + 1) begin
                        x0 <= selected_x[k];
                        y0 <= selected_y[k];
                        x1 <= selected_x[(k+1)%6];
                        y1 <= selected_y[(k+1)%6];
                        x2 <= selected_x[(k+2)%6];
                        y2 <= selected_y[(k+2)%6];
                        
                        // Compute cross product
                        dx <= {16'd0, x1} - {16'd0, x0};
                        dy <= {16'd0, y1} - {16'd0, y0};
                        cross_product <= dx * ({16'd0, y2} - {16'd0, y1}) - dy * ({16'd0, x2} - {16'd0, x1});
                        
                        // Check sign consistency
                        if (prev_cross != 32'd0 && (cross_product[31] != prev_cross[31])) begin
                            is_convex <= 1'b0;
                        end
                        prev_cross <= cross_product;
                    end
                    
                    // Compute perimeter if convex
                    if (is_convex) begin
                        dist_sum <= 32'd0;
                        
                        // Compute sum of squared distances
                        for (k = 0; k < 6; k = k + 1) begin
                            dx <= {16'd0, selected_x[(k+1)%6]} - {16'd0, selected_x[k]};
                            dy <= {16'd0, selected_y[(k+1)%6]} - {16'd0, selected_y[k]};
                            dist_sq <= dx * dx + dy * dy;
                            
                            // Simple sqrt approximation: use 8-bit lookup table
                            // For demo, use integer sqrt (in real HW, use LUT)
                            sqrt_approx <= 32'd0;
                            if (dist_sq > 32'd0) begin
                                integer i;
                                for (i = 0; i < 32; i = i + 1) begin
                                    if ((i * i) > dist_sq) begin
                                        sqrt_approx <= i - 1'b1;
                                        break;
                                    end
                                end
                            end
                            
                            dist_sum <= dist_sum + sqrt_approx;
                        end
                        
                        current_perimeter <= dist_sum << 16; // Convert to Q16.16
                        
                        // Update max
                        if (current_perimeter > current_max) begin
                            current_max <= current_perimeter;
                        end
                    end
                    
                    // Check if done with permutations
                    if (perm_counter == 3'd100) begin // Simplified: in real HW, check all permutations
                        next_state <= OUTPUT;
                    end else begin
                        perm_counter <= perm_counter + 3'd1;
                    end
                end

                OUTPUT: begin
                    // Output result for current vertex
                    result <= current_max;
                    vertex_idx <= current_vertex;
                    done <= 1'b1;
                    
                    // Move to next vertex
                    if (current_vertex == n_reg - 1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        current_vertex <= current_vertex + 3'd1;
                        current_max <= 32'd0;
                        perm_counter <= 3'd0;
                        next_state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule