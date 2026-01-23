module safe_rocket(
    input [1:0] size_a,
    input [7:0] ax0, ay0,
    input [7:0] ax1, ay1,
    input [7:0] ax2, ay2,
    input [7:0] ax3, ay3,
    input [1:0] size_b,
    input [7:0] bx0, by0,
    input [7:0] bx1, by1,
    input [7:0] bx2, by2,
    input [7:0] bx3, by3,
    output reg safe
);

    // Internal signals for vertices (used in always block)
    reg signed [8:0] a_vx [0:3];
    reg signed [8:0] a_vy [0:3];
    reg signed [8:0] b_vx [0:3];
    reg signed [8:0] b_vy [0:3];
    
    // Edge vectors (9-bit signed)
    reg signed [8:0] a_ex [0:3];
    reg signed [8:0] a_ey [0:3];
    reg signed [8:0] b_ex [0:3];
    reg signed [8:0] b_ey [0:3];
    
    // Computed properties (18-bit signed/unsigned)
    reg signed [17:0] a_dot [0:3];
    reg signed [17:0] a_cross [0:3];
    reg [17:0] a_len2 [0:3];
    reg signed [17:0] b_dot [0:3];
    reg signed [17:0] b_cross [0:3];
    reg [17:0] b_len2 [0:3];
    
    // Loop counters
    integer i, j, k, shift;
    reg match;
    
    // Local parameters for states (if needed for FSM, but this is combinational)
    localparam [1:0] SIZE_2 = 2'd2;
    localparam [1:0] SIZE_3 = 2'd3;
    localparam [1:0] SIZE_4 = 2'd4;

    always @(*) begin
        // Initialize vertex arrays
        // Polygon A
        a_vx[0] = {1'b0, ax0};
        a_vy[0] = {1'b0, ay0};
        a_vx[1] = {1'b0, ax1};
        a_vy[1] = {1'b0, ay1};
        a_vx[2] = {1'b0, ax2};
        a_vy[2] = {1'b0, ay2};
        a_vx[3] = {1'b0, ax3};
        a_vy[3] = {1'b0, ay3};
        
        // Polygon B
        b_vx[0] = {1'b0, bx0};
        b_vy[0] = {1'b0, by0};
        b_vx[1] = {1'b0, bx1};
        b_vy[1] = {1'b0, by1};
        b_vx[2] = {1'b0, bx2};
        b_vy[2] = {1'b0, by2};
        b_vx[3] = {1'b0, bx3};
        b_vy[3] = {1'b0, by3};
        
        // Default safe = 0
        safe = 1'b0;
        
        // Step 1: Check sizes
        if (size_a == size_b) begin
            
            case (size_a)
                SIZE_2: begin
                    // Check squared distance between two points
                    // Distance^2 = (x1-x0)^2 + (y1-y0)^2
                    // For 8-bit coordinates, diff is 9-bit signed
                    // Squared is 18-bit unsigned
                    reg signed [8:0] a_dx, a_dy;
                    reg signed [8:0] b_dx, b_dy;
                    reg [17:0] a_dist2, b_dist2;
                    
                    a_dx = a_vx[1] - a_vx[0];
                    a_dy = a_vy[1] - a_vy[0];
                    a_dist2 = (a_dx * a_dx) + (a_dy * a_dy);
                    
                    b_dx = b_vx[1] - b_vx[0];
                    b_dy = b_vy[1] - b_vy[0];
                    b_dist2 = (b_dx * b_dx) + (b_dy * b_dy);
                    
                    if (a_dist2 == b_dist2) begin
                        safe = 1'b1;
                    end
                end
                
                SIZE_3, SIZE_4: begin
                    // Step 2a: Translate to origin (vertex 0 at origin)
                    // Translated vertices: w_i = v_i - v_0
                    reg signed [8:0] a_wx [0:3];
                    reg signed [8:0] a_wy [0:3];
                    reg signed [8:0] b_wx [0:3];
                    reg signed [8:0] b_wy [0:3];
                    
                    // Translate A
                    for (k = 0; k < 4; k = k + 1) begin
                        a_wx[k] = a_vx[k] - a_vx[0];
                        a_wy[k] = a_vy[k] - a_vy[0];
                    end
                    
                    // Translate B
                    for (k = 0; k < 4; k = k + 1) begin
                        b_wx[k] = b_vx[k] - b_vx[0];
                        b_wy[k] = b_vy[k] - b_vy[0];
                    end
                    
                    // Step 2b: Compute edge vectors and properties for A
                    for (k = 0; k < 4; k = k + 1) begin
                        integer next_idx;
                        reg signed [8:0] ex, ey, next_ex, next_ey;
                        
                        if (k < size_a) begin
                            next_idx = (k + 1) % size_a;
                            
                            // Edge vector from k to next
                            a_ex[k] = a_wx[next_idx] - a_wx[k];
                            a_ey[k] = a_wy[next_idx] - a_wy[k];
                            
                            // Length squared (unsigned 18-bit)
                            a_len2[k] = (a_ex[k] * a_ex[k]) + (a_ey[k] * a_ey[k]);
                            
                            // Next edge for dot/cross
                            ex = a_ex[k];
                            ey = a_ey[k];
                            next_ex = a_ex[next_idx];
                            next_ey = a_ey[next_idx];
                            
                            // Dot product (signed 18-bit)
                            a_dot[k] = (ex * next_ex) + (ey * next_ey);
                            
                            // Cross product (signed 18-bit)
                            a_cross[k] = (ex * next_ey) - (ey * next_ex);
                        end else begin
                            a_ex[k] = 9'sd0;
                            a_ey[k] = 9'sd0;
                            a_len2[k] = 18'd0;
                            a_dot[k] = 18'sd0;
                            a_cross[k] = 18'sd0;
                        end
                    end
                    
                    // Step 2b: Compute edge vectors and properties for B
                    for (k = 0; k < 4; k = k + 1) begin
                        integer next_idx;
                        reg signed [8:0] ex, ey, next_ex, next_ey;
                        
                        if (k < size_b) begin
                            next_idx = (k + 1) % size_b;
                            
                            // Edge vector from k to next
                            b_ex[k] = b_wx[next_idx] - b_wx[k];
                            b_ey[k] = b_wy[next_idx] - b_wy[k];
                            
                            // Length squared (unsigned 18-bit)
                            b_len2[k] = (b_ex[k] * b_ex[k]) + (b_ey[k] * b_ey[k]);
                            
                            // Next edge for dot/cross
                            ex = b_ex[k];
                            ey = b_ey[k];
                            next_ex = b_ex[next_idx];
                            next_ey = b_ey[next_idx];
                            
                            // Dot product (signed 18-bit)
                            b_dot[k] = (ex * next_ex) + (ey * next_ey);
                            
                            // Cross product (signed 18-bit)
                            b_cross[k] = (ex * next_ey) - (ey * next_ex);
                        end else begin
                            b_ex[k] = 9'sd0;
                            b_ey[k] = 9'sd0;
                            b_len2[k] = 18'd0;
                            b_dot[k] = 18'sd0;
                            b_cross[k] = 18'sd0;
                        end
                    end
                    
                    // Step 2e: Check cyclic shifts
                    // For each shift s in 0..(size-1)
                    match = 1'b0;
                    for (shift = 0; shift < 4; shift = shift + 1) begin
                        reg shift_ok;
                        shift_ok = 1'b1;
                        
                        // Check if this shift works for all i
                        for (i = 0; i < 4; i = i + 1) begin
                            integer a_idx, b_idx;
                            
                            if (i < size_a && shift_ok) begin
                                a_idx = i;
                                b_idx = (i + shift) % size_a;
                                
                                // Check if properties match
                                if (a_len2[a_idx] != b_len2[b_idx] ||
                                    a_dot[a_idx] != b_dot[b_idx] ||
                                    a_cross[a_idx] != b_cross[b_idx]) begin
                                    shift_ok = 1'b0;
                                end
                            end
                        end
                        
                        // If any shift worked, we have a match
                        if (shift_ok) begin
                            match = 1'b1;
                        end
                    end
                    
                    safe = match;
                end
                
                default: begin
                    // Invalid size (shouldn't happen based on spec, but be safe)
                    safe = 1'b0;
                end
            endcase
        end
    end

endmodule