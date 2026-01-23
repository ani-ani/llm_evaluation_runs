module conveyor_path_finder (
    input [31:0] ax_q16,
    input [31:0] ay_q16,
    input [31:0] bx_q16,
    input [31:0] by_q16,
    input [31:0] cx_q16,
    input [31:0] cy_q16,
    input [31:0] dx_q16,
    input [31:0] dy_q16,
    output [31:0] min_time_q16
);

    // Internal signals for distances and times
    wire [31:0] dist_ab;
    wire [31:0] dist_ac;
    wire [31:0] dist_cd;
    wire [31:0] dist_db;
    
    wire [63:0] time_ac_full;
    wire [63:0] time_cd_full;
    wire [63:0] time_db_full;
    wire [63:0] path_conveyor_full;
    
    wire [31:0] path_conveyor;
    wire [31:0] path_direct;

    // 1. Calculate Euclidean distances
    // Use iterative CORDIC for sqrt(dx^2 + dy^2)
    
    // Dist AB
    calc_distance u_dist_ab (
        .x1(ax_q16), .y1(ay_q16),
        .x2(bx_q16), .y2(by_q16),
        .dist(dist_ab)
    );
    
    // Dist AC
    calc_distance u_dist_ac (
        .x1(ax_q16), .y1(ay_q16),
        .x2(cx_q16), .y2(cy_q16),
        .dist(dist_ac)
    );
    
    // Dist CD
    calc_distance u_dist_cd (
        .x1(cx_q16), .y1(cy_q16),
        .x2(dx_q16), .y2(dy_q16),
        .dist(dist_cd)
    );
    
    // Dist DB
    calc_distance u_dist_db (
        .x1(dx_q16), .y1(dy_q16),
        .x2(bx_q16), .y2(by_q16),
        .dist(dist_db)
    );

    // 2. Calculate Path Times
    // Direct path: time = distance / 1.0 = distance (already in Q16.16)
    assign path_direct = dist_ab;

    // Conveyor path: distance(A,C) + distance(C,D)/2.0 + distance(D,B)
    // We need to calculate distance(C,D)/2.0. 
    // In Q16.16, dividing by 2 is a right shift by 1.
    wire [31:0] dist_cd_half;
    assign dist_cd_half = dist_cd >> 1;

    // Sum of the three legs (Assumption: Sum fits in 32 bits for standard coordinate ranges)
    // For coordinate range 0-1000, max distance ~1414. Sum ~4242. Fits in 12 integer bits.
    assign path_conveyor = dist_ac + dist_cd_half + dist_db;

    // 3. Select Minimum
    // Comparing two 32-bit unsigned numbers
    assign min_time_q16 = (path_conveyor < path_direct) ? path_conveyor : path_direct;

endmodule

// Helper module for Euclidean distance calculation using iterative CORDIC
module calc_distance (
    input [31:0] x1, y1,
    input [31:0] x2, y2,
    output [31:0] dist
);
    // Calculate delta x and y
    wire signed [31:0] dx = x2 - x1;
    wire signed [31:0] dy = y2 - y1;
    
    // Take absolute values for CORDIC (unsigned sqrt)
    wire [31:0] abs_dx = dx[31] ? -dx : dx;
    wire [31:0] abs_dy = dy[31] ? -dy : dy;
    
    // Determine which is larger for vector normalization
    // Note: Comparing unsigned values
    wire swap = abs_dx < abs_dy;
    
    wire [31:0] major = swap ? abs_dy : abs_dx;
    wire [31:0] minor = swap ? abs_dx : abs_dy;
    
    // CORDIC calculation
    // Initial vector (major, minor). We want Magnitude = major * sqrt(1 + (minor/major)^2)
    // Or simply iterate standard rotation: x = magnitude * cos(theta), y = magnitude * sin(theta)
    // Here we use the approximation: magnitude = x + (y >> n) / theta_n
    
    reg [31:0] x_reg [0:14];
    reg [31:0] y_reg [0:14];
    
    // Precompute 1/theta for 15 stages (approx 0.60725...)
    // In Q16.16, 0.60725 is 39802
    wire [31:0] init_scale = 32'd39802;
    
    // Initialize: x0 = major, y0 = minor
    always @(*) begin
        x_reg[0] = major;
        y_reg[0] = minor;
    end
    
    // Iterative stages (15 stages for reasonable precision)
    integer i;
    always @(*) begin
        for (i = 0; i < 14; i = i + 1) begin
            if (y_reg[i][31] == 1'b0) begin
                // y >= 0, rotate clockwise (reduce angle)
                x_reg[i+1] = x_reg[i] + (y_reg[i] >> (i+1));
                y_reg[i+1] = y_reg[i] - (x_reg[i] >> (i+1));
            end else begin
                // y < 0, rotate counter-clockwise (increase angle)
                x_reg[i+1] = x_reg[i] - (y_reg[i] >> (i+1));
                y_reg[i+1] = y_reg[i] + (x_reg[i] >> (i+1));
            end
        end
    end
    
    // Result scaling: magnitude = x_final * 0.607...
    // Multiply x_reg[14] by init_scale (Q16.16 * Q16.16 = Q32.32), take upper 32 bits (Q16.16)
    wire [63:0] scaled_result = x_reg[14] * init_scale;
    
    assign dist = scaled_result[47:16]; // Shift right by 16 to get Q16.16

endmodule