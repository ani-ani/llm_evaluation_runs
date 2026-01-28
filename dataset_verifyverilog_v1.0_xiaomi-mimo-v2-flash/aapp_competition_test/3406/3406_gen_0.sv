module castle_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] polygon_verts [0:7][0:1], // 8 vertices, each with x (index 0) and y (index 1)
    input wire [15:0] castle_x,
    input wire [15:0] castle_y,
    input wire [2:0] num_verts,
    output reg result,
    output reg done
);

    // --- Constants & State Definitions ---
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LATCH    = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] UPDATE   = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // --- Internal Registers ---
    reg [2:0] state, next_state;
    reg [15:0] px, py; // Castle point
    reg [15:0] v0x, v0y, v1x, v1y; // Current edge vertices
    reg [2:0] idx; // Vertex index counter
    reg [2:0] num_v; // Latched number of vertices
    reg [3:0] intersections; // Count of ray intersections
    reg is_on_boundary; // Flag for point on edge
    reg [7:0] cycle_count; // Safety counter

    // --- Intermediate Wires for Computations ---
    // Cross product: (v1 - v0) x (p - v0)
    // dx = v1.x - v0.x, dy = v1.y - v0.y
    // rx = p.x - v0.x, ry = p.y - v0.y
    // cross = dx * ry - dy * rx
    wire signed [31:0] dx_s;
    wire signed [31:0] dy_s;
    wire signed [31:0] rx_s;
    wire signed [31:0] ry_s;
    wire signed [31:0] cross_prod;

    // Signed extension for Q8.8 arithmetic
    assign dx_s = {{16{v1x[15]}}, v1x} - {{16{v0x[15]}}, v0x};
    assign dy_s = {{16{v1y[15]}}, v1y} - {{16{v0y[15]}}, v0y};
    assign rx_s = {{16{castle_x[15]}}, castle_x} - {{16{v0x[15]}}, v0x};
    assign ry_s = {{16{castle_y[15]}}, castle_y} - {{16{v0y[15]}}, v0y};
    
    // 32x32 -> 64 product, select middle 32 bits (Q16.16 effectively)
    wire signed [63:0] prod1;
    wire signed [63:0] prod2;
    assign prod1 = dx_s * ry_s;
    assign prod2 = dy_s * rx_s;
    assign cross_prod = (prod1 - prod2) >>> 16;

    // Bounding box check signals
    wire min_x = (v0x < v1x) ? v0x : v1x;
    wire max_x = (v0x > v1x) ? v0x : v1x;
    wire min_y = (v0y < v1y) ? v0y : v1y;
    wire max_y = (v0y > v1y) ? v0y : v1y;
    wire on_segment;
    
    // Logic to determine if point is on the segment
    // Check bounding box first, then colinearity (cross == 0)
    // Since cross_prod is computed, check if it's 0
    // Range check is strict for Q8.8 integers inside
    reg on_segment_reg;
    always @(*) begin
        on_segment_reg = 1'b0;
        if (castle_x >= min_x && castle_x <= max_x && castle_y >= min_y && castle_y <= max_y) begin
            if (cross_prod == 32'd0) begin
                on_segment_reg = 1'b1;
            end
        end
    end
    assign on_segment = on_segment_reg;

    // --- Next State Logic ---
    always @(*) begin
        next_state = state; // Default stay
        case (state)
            IDLE: begin
                if (start) next_state = LATCH;
            end
            LATCH: begin
                next_state = CHECK;
            end
            CHECK: begin
                // If we have processed all edges, go to finish
                if (idx >= num_v) next_state = FINISH;
                else next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = CHECK;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            intersections <= 4'd0;
            is_on_boundary <= 1'b0;
            idx <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize polygon vertices storage
            // Note: In hardware, polygon_verts is an input array.
            // We need to latch specific values into scalar registers.
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    intersections <= 4'd0;
                    is_on_boundary <= 1'b0;
                    idx <= 3'd0;
                    cycle_count <= 8'd0;
                end

                LATCH: begin
                    // Latch castle position and vertex count
                    px <= castle_x;
                    py <= castle_y;
                    num_v <= num_verts;
                    // Load first vertex if valid
                    if (num_verts > 3'd0) begin
                        v0x <= polygon_verts[0][0];
                        v0y <= polygon_verts[0][1];
                    end
                end

                CHECK: begin
                    // Determine next state is handled in combinational logic
                    // Just ensure we load next vertex pair if not done
                    if (idx < num_v && idx != 0) begin
                        v0x <= polygon_verts[idx][0];
                        v0y <= polygon_verts[idx][1];
                    end
                end

                COMPUTE: begin
                    // Load v1 (next vertex in polygon, wrap around if last)
                    if (idx < num_v - 1) begin
                        v1x <= polygon_verts[idx + 1][0];
                        v1y <= polygon_verts[idx + 1][1];
                    end else begin
                        v1x <= polygon_verts[0][0];
                        v1y <= polygon_verts[0][1];
                    end
                end

                UPDATE: begin
                    // Check if point is on boundary
                    if (on_segment) begin
                        is_on_boundary <= 1'b1;
                    end

                    // Ray Casting Logic (Even-Odd Rule)
                    // Ray to the right (+x)
                    // Condition 1: Edge straddles horizontal line at py
                    // ((v0y > py) != (v1y > py))
                    // Condition 2: Intersection x > px
                    // ((v1x - v0x) * (py - v0y) / (v1y - v0y) + v0x) > px
                    // Simplified using cross product for sign check
                    // cross > 0 means v1 is to the right of ray from v0
                    
                    // Note: This implementation uses the sign of the cross product.
                    // Strictly, for ray casting, we check if the point is to the left/right
                    // of the directed edge. 
                    // However, the standard robust algorithm checks if the edge crosses the ray.
                    // 1. Check if py is between v0y and v1y (exclusive of top endpoint to avoid double counting)
                    // 2. Check if the intersection x is to the right of px.

                    // Let's use the cross product wire computed earlier.
                    // (v1 - v0) x (p - v0)
                    // We need to check if the intersection point of the edge with the horizontal line through p
                    // lies to the right of p.

                    // Refined Ray Casting:
                    // Check if edge straddles the horizontal line at py
                    // (v0y > py) ^ (v1y > py)
                    // AND the intersection x is > px
                    
                    // Using the pre-calculated cross product is not directly sufficient for intersection X > px.
                    // We need: (v0.x + (py - v0.y) * (v1.x - v0.x) / (v1.y - v0.y)) > p.x
                    // Multiply by (v1.y - v0.y): 
                    // (v0.x - p.x) * (v1.y - v0.y) + (py - v0.y) * (v1.x - v0.x) > 0 (if v1.y > v0.y)
                    // Rearranging: (p - v0) x (v1 - v0) has the same sign dependency.
                    // Actually, let's stick to the standard robust integer check.

                    wire straddle;
                    wire right_of_edge;
                    wire [15:0] dy_edge;
                    
                    // Safe absolute value logic for dy
                    wire [15:0] v0y_cmp = v0y;
                    wire [15:0] v1y_cmp = v1y;
                    
                    // Check if py is strictly between v0y and v1y
                    // (v0y < py && py < v1y) || (v1y < py && py < v0y)
                    // To avoid precision issues, check if (v0y - py) and (v1y - py) have opposite signs
                    wire signed [16:0] dy0 = {1'b0, v0y} - {1'b0, py}; // Unsigned subtraction logic mapped to signed
                    wire signed [16:0] dy1 = {1'b0, v1y} - {1'b0, py};
                    
                    // Sign check
                    wire sign0 = dy0[16];
                    wire sign1 = dy1[16];
                    assign straddle = (sign0 ^ sign1);

                    // Intersection check: is the intersection x to the right of px?
                    // We computed cross = (v1-v0) x (p-v0) earlier.
                    // If (v1.y > v0.y), cross > 0 implies p is to the left of the edge.
                    // Wait, standard logic:
                    // If edge upward (v1.y > v0.y): point crosses if p.x > intersection_x. (cross < 0)
                    // If edge downward (v1.y < v0.y): point crosses if p.x > intersection_x. (cross > 0)
                    // Combined: check if (v1.y > v0.y) == (cross > 0)
                    
                    wire v1y_gt_v0y = (v1y > v0y);
                    wire cross_pos = (cross_prod > 32'd0);
                    
                    // Intersection condition for ray to +X
                    // (Edge is upward AND cross < 0) OR (Edge is downward AND cross > 0)
                    // Actually simpler: 
                    // if (v1.y > v0.y) return (cross < 0) else return (cross > 0)
                    // Let's derive: 
                    // cross = dx * (py - v0y) - dy * (px - v0x)
                    // We want intersection x > px.
                    // intersection x = v0x + dx * (py - v0y) / dy
                    // px < v0x + dx * (py - v0y) / dy
                    // if dy > 0: px - v0x < dx * (py - v0y) / dy  =>  (px - v0x) * dy < dx * (py - v0y)
                    // (px - v0x) * dy - dx * (py - v0y) < 0  =>  -cross < 0  =>  cross > 0
                    // if dy < 0: inequality flips. (px - v0x) * dy > dx * (py - v0y) => cross < 0
                    // So: (dy > 0 && cross > 0) || (dy < 0 && cross < 0)
                    
                    wire dy_positive = (v1y > v0y);
                    wire dy_negative = (v1y < v0y);
                    
                    wire hit_positive = dy_positive & cross_pos;
                    wire hit_negative = dy_negative & (cross_prod < 32'd0);
                    
                    wire hit = hit_positive | hit_negative;

                    // Update intersection count
                    if (straddle && hit) begin
                        intersections <= intersections + 4'd1;
                    end
                    
                    // Increment index
                    idx <= idx + 3'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    // Inside if intersections is odd
                    // OR if on boundary
                    if (is_on_boundary || (intersections[0] == 1'b1)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
            endcase
            
            // Safety reset if stuck (cycle count limit)
            if (cycle_count > 8'd150) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 1'b0;
            end
        end
    end

endmodule