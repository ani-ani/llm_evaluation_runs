module poly_distance_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] polygon_cnt,
    input wire signed [15:0] vertex_x [0:3][0:3],
    input wire signed [15:0] vertex_y [0:3][0:3],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS_POLYGON = 3'd2;
    localparam [2:0] PROCESS_EDGE = 3'd3;
    localparam [2:0] COMPUTE_DISTANCE = 3'd4;
    localparam [2:0] UPDATE_MIN = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;

    // Counters
    reg [1:0] polygon_idx;
    reg [1:0] vertex_idx;

    // Distance computation registers
    reg signed [15:0] ax, ay;
    reg signed [15:0] bx, by;
    reg signed [15:0] dx, dy;
    reg signed [31:0] dx_sq, dy_sq, dx_dy;
    reg signed [31:0] t_numerator, t_denominator;
    reg signed [15:0] t;
    reg signed [15:0] px, py;
    reg signed [31:0] dist_sq;

    // Minimum distance tracking
    reg signed [31:0] min_dist_sq;

    // Cycle counter for safety
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            polygon_idx <= 2'd0;
            vertex_idx <= 2'd0;
            ax <= 16'd0;
            ay <= 16'd0;
            bx <= 16'd0;
            by <= 16'd0;
            dx <= 16'd0;
            dy <= 16'd0;
            dx_sq <= 32'd0;
            dy_sq <= 32'd0;
            dx_dy <= 32'd0;
            t_numerator <= 32'd0;
            t_denominator <= 32'd0;
            t <= 16'd0;
            px <= 16'd0;
            py <= 16'd0;
            dist_sq <= 32'd0;
            min_dist_sq <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 9'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    polygon_idx <= 2'd0;
                    vertex_idx <= 2'd0;
                    min_dist_sq <= 32'd0;
                    result <= 32'd0;
                    if (polygon_cnt == 4'd0) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= PROCESS_POLYGON;
                    end
                end

                PROCESS_POLYGON: begin
                    vertex_idx <= 2'd0;
                    next_state <= PROCESS_EDGE;
                end

                PROCESS_EDGE: begin
                    // Load current vertex
                    ax <= vertex_x[polygon_idx][vertex_idx];
                    ay <= vertex_y[polygon_idx][vertex_idx];
                    
                    // Load next vertex (wrap around)
                    if (vertex_idx == 2'd3) begin
                        bx <= vertex_x[polygon_idx][2'd0];
                        by <= vertex_y[polygon_idx][2'd0];
                    end else begin
                        bx <= vertex_x[polygon_idx][vertex_idx + 2'd1];
                        by <= vertex_y[polygon_idx][vertex_idx + 2'd1];
                    end
                    
                    next_state <= COMPUTE_DISTANCE;
                end

                COMPUTE_DISTANCE: begin
                    // Compute edge vector (B - A)
                    dx <= bx - ax;
                    dy <= by - ay;
                    
                    // Compute squared components
                    dx_sq <= $signed(dx) * $signed(dx);
                    dy_sq <= $signed(dy) * $signed(dy);
                    dx_dy <= $signed(dx) * $signed(dy);
                    
                    // Compute t (projection parameter)
                    t_numerator <= -$signed(ax) * $signed(dx) - $signed(ay) * $signed(dy);
                    t_denominator <= dx_sq + dy_sq;
                    
                    // Handle zero-length edge
                    if (t_denominator == 32'd0) begin
                        t <= 16'd0;
                    end else begin
                        t <= t_numerator[31:16]; // Q16.16 to Q8.8 conversion
                    end
                    
                    // Clamp t to [0, 1]
                    if (t < 16'd0) begin
                        t <= 16'd0;
                    end else if (t > 16'd256) begin // 1.0 in Q8.8
                        t <= 16'd256;
                    end
                    
                    next_state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    // Compute closest point P = A + t*(B-A)
                    px <= ax + (t * dx) >> 8; // Q8.8 multiplication
                    py <= ay + (t * dy) >> 8;
                    
                    // Compute squared distance
                    dist_sq <= $signed(px) * $signed(px) + $signed(py) * $signed(py);
                    
                    // Update minimum
                    if (polygon_idx == 2'd0 && vertex_idx == 2'd0) begin
                        min_dist_sq <= dist_sq;
                    end else if (dist_sq < min_dist_sq) begin
                        min_dist_sq <= dist_sq;
                    end
                    
                    // Move to next edge
                    if (vertex_idx == 2'd3) begin
                        // Last edge of polygon
                        if (polygon_idx == polygon_cnt - 4'd1) begin
                            next_state <= FINISH;
                        end else begin
                            polygon_idx <= polygon_idx + 2'd1;
                            next_state <= PROCESS_POLYGON;
                        end
                    end else begin
                        vertex_idx <= vertex_idx + 2'd1;
                        next_state <= PROCESS_EDGE;
                    end
                end

                FINISH: begin
                    result <= min_dist_sq;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Safety counter
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 9'd1;
            end else begin
                next_state <= IDLE;
            end
        end
    end

endmodule