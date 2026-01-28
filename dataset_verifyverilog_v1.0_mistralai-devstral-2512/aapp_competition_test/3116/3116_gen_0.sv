module CylinderVolumeApproximator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] points_x [0:7],
    input wire [15:0] points_y [0:7],
    input wire [15:0] points_z [0:7],
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] FINISH = 4'd2;
    
    reg [3:0] state;
    reg [7:0] direction;
    reg [7:0] point_idx;
    reg [31:0] min_proj;
    reg [31:0] max_proj;
    reg [31:0] max_dist_sq;
    reg [31:0] current_volume;
    reg [31:0] min_volume;
    reg [31:0] proj;
    reg [31:0] dist_sq;
    reg [31:0] temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Direction vectors (Q16.16 format)
    localparam [15:0] dir_x [0:7] = '{16'd32768, 16'd32768, 16'd0, 16'd0, 16'd0, 16'd0, 16'd23170, 16'd23170};
    localparam [15:0] dir_y [0:7] = '{16'd0, 16'd0, 16'd32768, 16'd32768, 16'd0, 16'd0, 16'd23170, 16'd23170};
    localparam [15:0] dir_z [0:7] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd32768, 16'd32768, 16'd0, 16'd0};
    localparam [15:0] dir_x_neg [0:7] = '{16'd32768, 16'd32768, 16'd0, 16'd0, 16'd0, 16'd0, 16'd23170, 16'd23170};
    localparam [15:0] dir_y_neg [0:7] = '{16'd0, 16'd0, 16'd32768, 16'd32768, 16'd0, 16'd0, 16'd23170, 16'd23170};
    localparam [15:0] dir_z_neg [0:7] = '{16'd0, 16'd0, 16'd0, 16'd0, 16'd32768, 16'd32768, 16'd0, 16'd0};

    // PI constant (Q16.16 format)
    localparam [31:0] PI = 32'd205887;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            direction <= 8'd0;
            point_idx <= 8'd0;
            min_proj <= 32'd0;
            max_proj <= 32'd0;
            max_dist_sq <= 32'd0;
            current_volume <= 32'd0;
            min_volume <= 32'd0;
            proj <= 32'd0;
            dist_sq <= 32'd0;
            temp <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        direction <= 8'd0;
                        point_idx <= 8'd0;
                        min_proj <= 32'd0;
                        max_proj <= 32'd0;
                        max_dist_sq <= 32'd0;
                        min_volume <= 32'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute projection for current point
                    if (direction < 8'd2) begin
                        // X directions
                        temp = $signed(points_x[point_idx]) * $signed(dir_x[direction]);
                    end else if (direction < 8'd4) begin
                        // Y directions
                        temp = $signed(points_y[point_idx]) * $signed(dir_y[direction]);
                    end else if (direction < 8'd6) begin
                        // Z directions
                        temp = $signed(points_z[point_idx]) * $signed(dir_z[direction]);
                    end else begin
                        // Diagonal directions
                        temp = $signed(points_x[point_idx]) * $signed(dir_x[direction]) +
                              $signed(points_y[point_idx]) * $signed(dir_y[direction]);
                    end
                    proj = temp[31:0];

                    // Update min/max projections
                    if (point_idx == 0) begin
                        min_proj <= proj;
                        max_proj <= proj;
                    end else begin
                        if ($signed(proj) < $signed(min_proj)) begin
                            min_proj <= proj;
                        end
                        if ($signed(proj) > $signed(max_proj)) begin
                            max_proj <= proj;
                        end
                    end

                    // Compute distance squared from axis
                    if (direction < 8'd2) begin
                        // X axis: distance is sqrt(y^2 + z^2)
                        temp = $signed(points_y[point_idx]) * $signed(points_y[point_idx]) +
                              $signed(points_z[point_idx]) * $signed(points_z[point_idx]);
                    end else if (direction < 8'd4) begin
                        // Y axis: distance is sqrt(x^2 + z^2)
                        temp = $signed(points_x[point_idx]) * $signed(points_x[point_idx]) +
                              $signed(points_z[point_idx]) * $signed(points_z[point_idx]);
                    end else if (direction < 8'd6) begin
                        // Z axis: distance is sqrt(x^2 + y^2)
                        temp = $signed(points_x[point_idx]) * $signed(points_x[point_idx]) +
                              $signed(points_y[point_idx]) * $signed(points_y[point_idx]);
                    end else begin
                        // Diagonal axis: distance is sqrt((y*z_x - x*z_y)^2 + ...)
                        // Simplified for diagonal directions
                        temp = $signed(points_x[point_idx]) * $signed(points_x[point_idx]) +
                              $signed(points_y[point_idx]) * $signed(points_y[point_idx]) +
                              $signed(points_z[point_idx]) * $signed(points_z[point_idx]);
                    end
                    dist_sq = temp[31:0];

                    // Update max distance squared
                    if ($signed(dist_sq) > $signed(max_dist_sq)) begin
                        max_dist_sq <= dist_sq;
                    end

                    // Move to next point or next direction
                    if (point_idx < n - 1) begin
                        point_idx <= point_idx + 8'd1;
                    end else begin
                        point_idx <= 8'd0;
                        
                        // Calculate volume for this direction
                        temp = $signed(max_proj) - $signed(min_proj);
                        if ($signed(temp) < 0) begin
                            temp = -temp;
                        end
                        
                        // Volume = PI * r^2 * height
                        current_volume = (PI * max_dist_sq) >> 16;
                        current_volume = (current_volume * temp) >> 16;

                        // Track minimum volume
                        if (direction == 0 || $signed(current_volume) < $signed(min_volume)) begin
                            min_volume <= current_volume;
                        end

                        // Move to next direction or finish
                        if (direction < 8'd7) begin
                            direction <= direction + 8'd1;
                            min_proj <= 32'd0;
                            max_proj <= 32'd0;
                            max_dist_sq <= 32'd0;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= min_volume;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule