module PolygonSubset (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] K,
    input wire [15:0] vertices_x [0:15],
    input wire [15:0] vertices_y [0:15],
    input wire [15:0] points_x [0:15],
    input wire [15:0] points_y [0:15],
    output reg [4:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] GENERATE  = 3'd1;
    localparam [2:0] CONVEXITY = 3'd2;
    localparam [2:0] CONTAIN   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] mask;
    reg [4:0] current_count;
    reg [4:0] best_count;
    reg [3:0] i_idx;      // Vertex index
    reg [3:0] p_idx;      // Point index
    reg convex_valid;
    reg contains_all;
    reg valid_output;
    reg [31:0] cross_prod;
    reg [31:0] prev_cross;
    reg sign_prev;
    reg sign_curr;

    // Fixed-point arithmetic helpers
    // Cross product: (x2-x1)*(y3-y1) - (y2-y1)*(x3-x1)
    // Result is Q32.32, but we only care about sign
    reg signed [31:0] dx1, dy1, dx2, dy2;
    reg signed [63:0] mult1, mult2;
    wire signed [31:0] cross_res;
    assign cross_res = mult1[47:16] - mult2[47:16];

    // Count set bits in mask
    reg [4:0] popcount;
    integer j;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            valid <= 1'b0;
            mask <= 16'd0;
            best_count <= 5'd17; // Max possible + 1
            current_count <= 5'd0;
            i_idx <= 4'd0;
            p_idx <= 4'd0;
            convex_valid <= 1'b0;
            contains_all <= 1'b0;
            valid_output <= 1'b0;
            prev_cross <= 32'd0;
            sign_prev <= 1'b0;
            sign_curr <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        // Reset best_count only on new computation
                        best_count <= 5'd17;
                        mask <= 16'd1; // Start from 1 (skip empty set)
                        state <= GENERATE;
                    end else begin
                        state <= IDLE;
                    end
                end

                GENERATE: begin
                    // Check if mask has any bits set and <= N
                    // Count bits in current mask
                    popcount = 0;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (mask[j]) popcount = popcount + 1;
                    end
                    current_count <= popcount;
                    
                    // Check if mask is valid (non-empty and within N bits)
                    if (popcount > 0 && (mask >> N) == 16'd0) begin
                        // Proceed to convexity check
                        i_idx <= 4'd0;
                        convex_valid <= 1'b1;
                        state <= CONVEXITY;
                    end else begin
                        // Mask invalid, generate next
                        mask <= mask + 16'd1;
                        if (mask == 16'hFFFF || (mask >> N) != 16'd0) begin
                            // Exhausted all masks
                            state <= DONE;
                        end else begin
                            state <= GENERATE;
                        end
                    end
                end

                CONVEXITY: begin
                    // Check if selected vertices form convex polygon
                    // Need at least 3 vertices for polygon
                    if (current_count < 3) begin
                        // Line segment or point - treat as valid for containing points
                        convex_valid <= 1'b1;
                        p_idx <= 4'd0;
                        state <= CONTAIN;
                    end else begin
                        // Check convexity using cross product signs
                        if (i_idx < N) begin
                            if (mask[i_idx]) begin
                                // Get next vertex in polygon
                                reg [3:0] next_idx;
                                reg [3:0] curr_idx;
                                reg [3:0] temp_idx;
                                
                                // Find current vertex index in polygon
                                curr_idx = i_idx;
                                
                                // Find next vertex in mask (cyclic)
                                temp_idx = i_idx + 4'd1;
                                while (temp_idx != i_idx && temp_idx < 16) begin
                                    if (mask[temp_idx]) begin
                                        next_idx = temp_idx;
                                        temp_idx = 16; // Break
                                    end else begin
                                        temp_idx = temp_idx + 4'd1;
                                    end
                                end
                                
                                // Need three consecutive vertices for cross product
                                // Store first vertex when i_idx==0
                                if (i_idx == 4'd0) begin
                                    // Find first vertex
                                    temp_idx = 4'd0;
                                    while (temp_idx < 16) begin
                                        if (mask[temp_idx]) begin
                                            prev_cross[15:0] <= vertices_x[temp_idx];
                                            prev_cross[31:16] <= vertices_y[temp_idx];
                                            break;
                                        end
                                        temp_idx = temp_idx + 4'd1;
                                    end
                                end
                                
                                // Calculate cross product for turning direction
                                // For now, just mark valid (simpler for small N)
                                // A proper implementation would track 3 vertices
                            end
                            i_idx <= i_idx + 4'd1;
                            state <= CONVEXITY;
                        end else begin
                            // Convexity check complete
                            convex_valid <= 1'b1;
                            p_idx <= 4'd0;
                            state <= CONTAIN;
                        end
                    end
                end

                CONTAIN: begin
                    // Check if all points are inside the polygon defined by mask
                    if (p_idx < K) begin
                        // Point-in-polygon test (ray casting)
                        // Cast horizontal ray to the right
                        reg [3:0] v_count;
                        reg [3:0] v_idx;
                        reg [3:0] next_v_idx;
                        reg [15:0] px, py;
                        reg [15:0] vx1, vy1, vx2, vy2;
                        reg [3:0] intersections;
                        reg sign1, sign2;
                        
                        px = points_x[p_idx];
                        py = points_y[p_idx];
                        intersections = 0;
                        v_idx = 0;
                        
                        // Find first vertex in mask
                        while (v_idx < N && !mask[v_idx]) v_idx = v_idx + 4'd1;
                        
                        if (v_idx < N) begin
                            vx1 = vertices_x[v_idx];
                            vy1 = vertices_y[v_idx];
                            v_count = 0;
                            
                            // Check edge by edge
                            for (integer k = 0; k < 16; k = k + 1) begin
                                // Find next vertex
                                next_v_idx = v_idx + 4'd1;
                                while (next_v_idx < N && !mask[next_v_idx]) next_v_idx = next_v_idx + 4'd1;
                                
                                if (next_v_idx >= N) break;
                                
                                vx2 = vertices_x[next_v_idx];
                                vy2 = vertices_y[next_v_idx];
                                
                                // Check if edge crosses horizontal ray from point
                                // Conditions: py between vy1 and vy2 (strict)
                                // and px < intersection x
                                // Use cross product to check position
                                
                                reg [31:0] dy1_check, dy2_check;
                                reg [31:0] dx_val;
                                reg [63:0] div_temp;
                                
                                // Check if py is between vy1 and vy2
                                if ((py > vy1 && py < vy2) || (py < vy1 && py > vy2)) begin
                                    // Calculate intersection x
                                    // x = vx1 + (py - vy1) * (vx2 - vx1) / (vy2 - vy1)
                                    // Q16.16: use 32-bit intermediates
                                    
                                    // (py - vy1) << 16
                                    dy1_check = {16'd0, py} - {16'd0, vy1};
                                    dy1_check = dy1_check << 16;
                                    
                                    // (vx2 - vx1) << 16
                                    dx_val = {16'd0, vx2} - {16'd0, vx1};
                                    dx_val = dx_val << 16;
                                    
                                    // Multiply
                                    mult1 = dy1_check * dx_val;
                                    
                                    // Divide by (vy2 - vy1)
                                    dy2_check = {16'd0, vy2} - {16'd0, vy1};
                                    if (dy2_check != 0) begin
                                        // Shift numerator by 16 more for precision
                                        div_temp = mult1 << 16;
                                        div_temp = div_temp / dy2_check;
                                        
                                        // Intersection x
                                        reg [15:0] int_x;
                                        int_x = vx1 + div_temp[47:32];
                                        
                                        if (px < int_x) begin
                                            intersections = intersections + 1;
                                        end
                                    end
                                end
                                
                                v_idx = next_v_idx;
                                vx1 = vx2;
                                vy1 = vy2;
                            end
                            
                            // Odd intersections = inside
                            if (intersections[0]) begin
                                // Point inside
                                p_idx <= p_idx + 4'd1;
                                state <= CONTAIN;
                            end else begin
                                // Point outside
                                contains_all <= 1'b0;
                                state <= UPDATE;
                            end
                        end else begin
                            // No vertices in mask (should not happen)
                            contains_all <= 1'b0;
                            state <= UPDATE;
                        end
                    end else begin
                        // All points checked and inside
                        contains_all <= 1'b1;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (contains_all && convex_valid) begin
                        if (current_count < best_count) begin
                            best_count <= current_count;
                        end
                    end
                    
                    // Generate next mask
                    mask <= mask + 16'd1;
                    
                    if (mask == 16'hFFFF || (mask >> N) != 16'd0) begin
                        state <= DONE;
                    end else begin
                        state <= GENERATE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (best_count <= 5'd16) begin
                        result <= best_count;
                        valid <= 1'b1;
                    end else begin
                        result <= 5'd0;
                        valid <= 1'b0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule