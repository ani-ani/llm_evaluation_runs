module SpiralTargetSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] b,
    input wire signed [31:0] tx,
    input wire signed [31:0] ty,
    output reg signed [31:0] x_det,
    output reg signed [31:0] y_det,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Fixed-point constants
    localparam signed [31:0] PI          = 32'sd32478;  // 3.14159265359 in Q16.16
    localparam signed [31:0] TWO_PI      = 32'sd64956;  // 6.28318530718 in Q16.16
    localparam signed [31:0] SIX_PI      = 32'sd194868; // 18.8495559215 in Q16.16
    localparam signed [31:0] STEP        = 32'sd655;    // 0.01 in Q16.16
    localparam signed [31:0] MAX_CYCLES  = 32'sd1000;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [31:0] phi;
    reg [31:0] best_phi;
    reg [31:0] x_det_reg, y_det_reg;
    reg [31:0] x_spiral, y_spiral;
    reg [31:0] vx, vy;
    reg [31:0] t_numerator, t_denominator;
    reg [31:0] t_val;
    reg [31:0] dx, dy;
    reg [31:0] dist_sq;
    reg [31:0] min_dist_sq;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            phi <= 32'd0;
            best_phi <= 32'd0;
            x_det_reg <= 32'd0;
            y_det_reg <= 32'd0;
            x_spiral <= 32'd0;
            y_spiral <= 32'd0;
            vx <= 32'd0;
            vy <= 32'd0;
            t_numerator <= 32'd0;
            t_denominator <= 32'd0;
            t_val <= 32'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            dist_sq <= 32'd0;
            min_dist_sq <= 32'd0;
            found <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        phi <= 32'd0;
                        best_phi <= 32'd0;
                        min_dist_sq <= 32'sd2147483647; // Max value
                        found <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute spiral point: r = b*phi
                    // x = r*cos(phi), y = r*sin(phi)
                    // Using fixed-point cordic approximation
                    compute_spiral_point(phi, b, x_spiral, y_spiral);
                    
                    // Compute velocity vector (derivative)
                    // vx = b*(cos(phi) - phi*sin(phi))
                    // vy = b*(sin(phi) + phi*cos(phi))
                    compute_velocity(phi, b, vx, vy);
                    
                    // Solve for t: x_det + vx*t = tx, y_det + vy*t = ty
                    // t = (tx - x_det)/vx = (ty - y_det)/vy
                    // Cross multiply: (tx - x_det)*vy = (ty - y_det)*vx
                    t_numerator <= (tx - x_spiral) * vy - (ty - y_spiral) * vx;
                    t_denominator <= vx * vx + vy * vy;
                    
                    // Check if denominator is zero (avoid division by zero)
                    if (t_denominator != 32'd0) begin
                        t_val <= (t_numerator << 16) / t_denominator; // Q32.32 / Q16.16 = Q16.16
                    end else begin
                        t_val <= 32'd0;
                    end
                    
                    // Check if t is positive and trajectory hits target
                    if (t_val > 32'd0) begin
                        // Check if line segment intersects spiral
                        // For simplicity, check distance from target to spiral
                        dx <= tx - x_spiral;
                        dy <= ty - y_spiral;
                        dist_sq <= (dx * dx) + (dy * dy);
                        
                        // Update best solution
                        if (dist_sq < min_dist_sq) begin
                            min_dist_sq <= dist_sq;
                            best_phi <= phi;
                            x_det_reg <= x_spiral;
                            y_det_reg <= y_spiral;
                            found <= 1'b1;
                        end
                    end
                    
                    // Increment phi
                    phi <= phi + STEP;
                    
                    // Check if done with all iterations
                    if (phi >= SIX_PI || cycle_count >= MAX_CYCLES) begin
                        if (found) begin
                            next_state <= FINISH;
                        end else begin
                            next_state <= IDLE;
                        end
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                FINISH: begin
                    x_det <= x_det_reg;
                    y_det <= y_det_reg;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Fixed-point cordic approximation for sin/cos
    function automatic void compute_spiral_point(
        input signed [31:0] phi,
        input signed [31:0] b,
        output reg signed [31:0] x,
        output reg signed [31:0] y
    );
        reg signed [31:0] r;
        reg signed [31:0] cos_phi, sin_phi;
        reg signed [31:0] temp_x, temp_y;
        reg signed [31:0] angle;
        reg signed [31:0] k;
        reg [4:0] i;
        
        // Compute r = b*phi
        r = (b * phi) >> 16; // Q16.16 * Q16.16 = Q32.32, shift to Q16.16
        
        // Initialize CORDIC
        temp_x = r;
        temp_y = 32'd0;
        angle = phi;
        
        // CORDIC iterations
        for (i = 0; i < 16; i = i + 1) begin
            if (angle[31]) begin
                temp_x = temp_x + (temp_y >> i);
                temp_y = temp_y - (temp_x >> i);
                angle = angle + (32'sd1 << (15 - i));
            end else begin
                temp_x = temp_x - (temp_y >> i);
                temp_y = temp_y + (temp_x >> i);
                angle = angle - (32'sd1 << (15 - i));
            end
        end
        
        // Final result
        x = temp_x;
        y = temp_y;
    endfunction

    // Compute velocity vector
    function automatic void compute_velocity(
        input signed [31:0] phi,
        input signed [31:0] b,
        output reg signed [31:0] vx,
        output reg signed [31:0] vy
    );
        reg signed [31:0] cos_phi, sin_phi;
        reg signed [31:0] temp_x, temp_y;
        reg signed [31:0] angle;
        reg [4:0] i;
        
        // Compute cos(phi) and sin(phi) using CORDIC
        temp_x = 32'sd32478; // 1.0 in Q16.16
        temp_y = 32'd0;
        angle = phi;
        
        for (i = 0; i < 16; i = i + 1) begin
            if (angle[31]) begin
                temp_x = temp_x + (temp_y >> i);
                temp_y = temp_y - (temp_x >> i);
                angle = angle + (32'sd1 << (15 - i));
            end else begin
                temp_x = temp_x - (temp_y >> i);
                temp_y = temp_y + (temp_x >> i);
                angle = angle - (32'sd1 << (15 - i));
            end
        end
        
        cos_phi = temp_x;
        sin_phi = temp_y;
        
        // vx = b*(cos(phi) - phi*sin(phi))
        // vy = b*(sin(phi) + phi*cos(phi))
        vx = b * ((cos_phi - ((phi * sin_phi) >> 16)) >> 16);
        vy = b * ((sin_phi + ((phi * cos_phi) >> 16)) >> 16);
    endfunction

endmodule