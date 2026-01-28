module cylinder_approximation (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] points_x [0:7],
    input [15:0] points_y [0:7],
    input [15:0] points_z [0:7],
    output reg [31:0] result,
    output reg done
);

    // Fixed-point Q16.16 constants
    localparam [31:0] PI_FIXED = 32'h3243F;  // π in Q16.16 (approx 3.14159265 * 65536 = 205887.4)
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Axis direction definitions
    localparam [2:0] AXIS_X_POS   = 3'd0;
    localparam [2:0] AXIS_X_NEG   = 3'd1;
    localparam [2:0] AXIS_Y_POS   = 3'd2;
    localparam [2:0] AXIS_Y_NEG   = 3'd3;
    localparam [2:0] AXIS_Z_POS   = 3'd4;
    localparam [2:0] AXIS_Z_NEG   = 3'd5;
    localparam [2:0] AXIS_XY_POS  = 3'd6;  // +X+Y (normalized)
    localparam [2:0] AXIS_XY_NEG  = 3'd7;  // +X-Y (normalized)
    
    // Normalization factor for diagonal axes (1/sqrt(2) in Q16.16)
    localparam [31:0] NORM_DIAG = 32'hB504;  // 0.70710678 * 65536 ≈ 46341
    localparam [31:0] NORM_XY   = 32'h16A0A; // 1/sqrt(3) for general case if needed
    
    // State machine states
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] RESET_VARS   = 3'd1;
    localparam [2:0] PROJ_INIT    = 3'd2;
    localparam [2:0] PROJ_COMPUTE = 3'd3;
    localparam [2:0] PROJ_ACCUM   = 3'd4;
    localparam [2:0] VOLUME_CALC  = 3'd5;
    localparam [2:0] VOLUME_ACCUM = 3'd6;
    localparam [2:0] FINISH       = 3'd7;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [2:0] axis_idx;           // Current axis being tested (0-7)
    reg [3:0] point_idx;          // Current point being processed
    
    // Intermediate computation registers
    reg [31:0] proj_val;          // Current projection value (Q16.16)
    reg [31:0] min_proj;          // Minimum projection for current axis
    reg [31:0] max_proj;          // Maximum projection for current axis
    reg [31:0] max_dist_sq;       // Maximum squared perpendicular distance
    reg [31:0] current_vol;       // Volume for current axis
    reg [31:0] min_vol;           // Minimum volume across all axes
    reg [31:0] temp_result;       // Temporary accumulator
    reg [31:0] temp_sq;           // Squared intermediate
    
    // Internal signals for computation
    reg [31:0] axis_vec_x, axis_vec_y, axis_vec_z;  // Axis direction vector (normalized Q16.16)
    reg [31:0] dot_product;       // Dot product result
    reg [31:0] perp_dist_sq;      // Perpendicular distance squared
    
    // Wire connections for multiplication
    wire [63:0] mult_result;
    wire [63:0] mult_result_sq;
    wire [63:0] mult_result_vol;
    wire [63:0] mult_result_height;
    
    // Multipliers for different operations
    assign mult_result = (proj_val[31:16] * axis_vec_x[15:0]) + 
                        (proj_val[31:16] * axis_vec_y[15:0]) + 
                        (proj_val[31:16] * axis_vec_z[15:0]);
    
    assign mult_result_sq = temp_result[31:0] * temp_result[31:0];
    assign mult_result_vol = temp_sq[31:0] * temp_result[31:0];
    assign mult_result_height = max_proj[31:0] - min_proj[31:0];
    
    // Integer for loops
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 8'd0;
            axis_idx <= 3'd0;
            point_idx <= 4'd0;
            proj_val <= 32'd0;
            min_proj <= 32'h7FFFFFFF;
            max_proj <= 32'h80000000;
            max_dist_sq <= 32'd0;
            current_vol <= 32'h7FFFFFFF;
            min_vol <= 32'h7FFFFFFF;
            temp_result <= 32'd0;
            temp_sq <= 32'd0;
            axis_vec_x <= 32'd0;
            axis_vec_y <= 32'd0;
            axis_vec_z <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    axis_idx <= 3'd0;
                    point_idx <= 4'd0;
                    result <= 32'd0;
                    min_vol <= 32'h7FFFFFFF;
                    if (start) begin
                        state <= RESET_VARS;
                    end
                end
                
                RESET_VARS: begin
                    // Initialize for new axis or new point processing
                    proj_val <= 32'd0;
                    min_proj <= 32'h7FFFFFFF;
                    max_proj <= 32'h80000000;
                    max_dist_sq <= 32'd0;
                    current_vol <= 32'h7FFFFFFF;
                    point_idx <= 4'd0;
                    
                    // Set axis direction based on axis_idx
                    case (axis_idx)
                        AXIS_X_POS: begin
                            axis_vec_x <= 32'h00010000;  // 1.0 in Q16.16
                            axis_vec_y <= 32'd0;
                            axis_vec_z <= 32'd0;
                        end
                        AXIS_X_NEG: begin
                            axis_vec_x <= 32'hFFFF0000;  // -1.0 in Q16.16 (two's complement)
                            axis_vec_y <= 32'd0;
                            axis_vec_z <= 32'd0;
                        end
                        AXIS_Y_POS: begin
                            axis_vec_x <= 32'd0;
                            axis_vec_y <= 32'h00010000;
                            axis_vec_z <= 32'd0;
                        end
                        AXIS_Y_NEG: begin
                            axis_vec_x <= 32'd0;
                            axis_vec_y <= 32'hFFFF0000;
                            axis_vec_z <= 32'd0;
                        end
                        AXIS_Z_POS: begin
                            axis_vec_x <= 32'd0;
                            axis_vec_y <= 32'd0;
                            axis_vec_z <= 32'h00010000;
                        end
                        AXIS_Z_NEG: begin
                            axis_vec_x <= 32'd0;
                            axis_vec_y <= 32'd0;
                            axis_vec_z <= 32'hFFFF0000;
                        end
                        AXIS_XY_POS: begin
                            // +X+Y normalized by 1/sqrt(2)
                            axis_vec_x <= NORM_DIAG;  // 0.7071
                            axis_vec_y <= NORM_DIAG;  // 0.7071
                            axis_vec_z <= 32'd0;
                        end
                        AXIS_XY_NEG: begin
                            // +X-Y normalized by 1/sqrt(2)
                            axis_vec_x <= NORM_DIAG;   // 0.7071
                            axis_vec_y <= 32'hFFFF0000 - NORM_DIAG + 32'd1;  // -0.7071
                            axis_vec_z <= 32'd0;
                        end
                        default: begin
                            axis_vec_x <= 32'd0;
                            axis_vec_y <= 32'd0;
                            axis_vec_z <= 32'd0;
                        end
                    endcase
                    state <= PROJ_INIT;
                end
                
                PROJ_INIT: begin
                    // Reset for projection computation
                    proj_val <= 32'd0;
                    state <= PROJ_COMPUTE;
                end
                
                PROJ_COMPUTE: begin
                    // Compute dot product for current point
                    if (point_idx < n) begin
                        // Dot product: x*ax + y*ay + z*az
                        // Each multiplication: Q16.16 * Q16.16 = Q32.32, take middle Q16.16
                        temp_result <= 32'd0;
                        temp_result <= temp_result + (
                            ({16'd0, points_x[point_idx]} * axis_vec_x[15:0]) >> 16
                        );
                        temp_result <= temp_result + (
                            ({16'd0, points_y[point_idx]} * axis_vec_y[15:0]) >> 16
                        );
                        temp_result <= temp_result + (
                            ({16'd0, points_z[point_idx]} * axis_vec_z[15:0]) >> 16
                        );
                        state <= PROJ_ACCUM;
                    end else begin
                        state <= VOLUME_CALC;
                    end
                end
                
                PROJ_ACCUM: begin
                    // Update min/max projections
                    if (temp_result < min_proj)
                        min_proj <= temp_result;
                    if (temp_result > max_proj)
                        max_proj <= temp_result;
                    
                    // Now compute perpendicular distance squared
                    // dist^2 = (x - proj*ax)^2 + (y - proj*ay)^2 + (z - proj*az)^2
                    // where proj = (x*ax + y*ay + z*az)
                    
                    // Projected point on axis
                    reg signed [31:0] proj_x, proj_y, proj_z;
                    proj_x = (temp_result * axis_vec_x[15:0]) >>> 16;
                    proj_y = (temp_result * axis_vec_y[15:0]) >>> 16;
                    proj_z = (temp_result * axis_vec_z[15:0]) >>> 16;
                    
                    // Perpendicular components
                    reg signed [31:0] perp_x, perp_y, perp_z;
                    perp_x = points_x[point_idx] - proj_x;
                    perp_y = points_y[point_idx] - proj_y;
                    perp_z = points_z[point_idx] - proj_z;
                    
                    // Square and accumulate
                    temp_sq <= 32'd0;
                    temp_sq <= temp_sq + ((perp_x * perp_x) >>> 16);
                    temp_sq <= temp_sq + ((perp_y * perp_y) >>> 16);
                    temp_sq <= temp_sq + ((perp_z * perp_z) >>> 16);
                    
                    point_idx <= point_idx + 4'd1;
                    state <= RESET_VARS;
                end
                
                VOLUME_CALC: begin
                    // Compute volume for this axis
                    // volume = π * max_dist_sq * (max_proj - min_proj)
                    // max_dist_sq is in Q16.16, height is in Q16.16
                    // Result will be in Q48.48, keep middle 32 bits (Q16.32 -> Q16.16)
                    
                    // First compute height (Q16.16)
                    reg [31:0] height;
                    if (max_proj > min_proj)
                        height = max_proj - min_proj;
                    else
                        height = 32'd0;
                    
                    // Compute π * max_dist_sq (Q16.16 * Q16.16 = Q32.32)
                    temp_result <= (PI_FIXED * max_dist_sq) >>> 16;
                    
                    // Multiply by height
                    temp_result <= (temp_result * height) >>> 16;
                    
                    state <= VOLUME_ACCUM;
                end
                
                VOLUME_ACCUM: begin
                    // Store volume for this axis
                    current_vol <= temp_result;
                    
                    // Update minimum volume
                    if (temp_result < min_vol)
                        min_vol <= temp_result;
                    
                    // Move to next axis or finish
                    if (axis_idx < 3'd7) begin
                        axis_idx <= axis_idx + 3'd1;
                        state <= RESET_VARS;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_vol;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle counter for timeout
            if (state != IDLE && state != FINISH) begin
                if (cycle_count < MAX_CYCLES)
                    cycle_count <= cycle_count + 8'd1;
                else
                    state <= FINISH;  // Timeout - finish with current result
            end
        end
    end
endmodule