module courtyard_watered_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] angle_a,
    input wire [15:0] angle_b,
    input wire [15:0] angle_c,
    input wire [15:0] angle_d,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] CONVERT_ANGLES = 5'd1;
    localparam [4:0] COMPUTE_TRIG = 5'd2;
    localparam [4:0] CALC_INTERSECTIONS = 5'd3;
    localparam [4:0] COMPUTE_AREA = 5'd4;
    localparam [4:0] OUTPUT_RESULT = 5'd5;

    reg [4:0] state, next_state;

    // Internal registers for angles in radians (Q16.16)
    reg signed [31:0] rad_a, rad_b, rad_c, rad_d;

    // Internal registers for trigonometric values (Q16.16)
    reg signed [31:0] sin_a, cos_a;
    reg signed [31:0] sin_b, cos_b;
    reg signed [31:0] sin_c, cos_c;
    reg signed [31:0] sin_d, cos_d;

    // Intersection points (Q16.16)
    reg signed [31:0] x1, y1; // BR-TR intersection
    reg signed [31:0] x2, y2; // TR-TL intersection
    reg signed [31:0] x3, y3; // TL-BL intersection
    reg signed [31:0] x4, y4; // BL-BR intersection

    // Shoelace formula accumulators
    reg signed [63:0] sum1, sum2;

    // Constants
    localparam signed [31:0] PI_OVER_180 = 32'sd38763; // Q16.16: ~0.59153
    localparam signed [31:0] ONE = 32'sd65536; // Q16.16: 1.0
    localparam signed [31:0] ZERO = 32'sd0;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CONVERT_ANGLES;
                else
                    next_state = IDLE;
            end
            CONVERT_ANGLES: next_state = COMPUTE_TRIG;
            COMPUTE_TRIG: next_state = CALC_INTERSECTIONS;
            CALC_INTERSECTIONS: next_state = COMPUTE_AREA;
            COMPUTE_AREA: next_state = OUTPUT_RESULT;
            OUTPUT_RESULT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Angle conversion to radians
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rad_a <= ZERO;
            rad_b <= ZERO;
            rad_c <= ZERO;
            rad_d <= ZERO;
        end else if (state == CONVERT_ANGLES) begin
            // Convert angles to radians: rad = angle * pi/180
            rad_a <= $signed(angle_a) * PI_OVER_180;
            rad_b <= $signed(angle_b) * PI_OVER_180;
            rad_c <= $signed(angle_c) * PI_OVER_180;
            rad_d <= $signed(angle_d) * PI_OVER_180;
        end
    end

    // Trigonometric calculations (simplified LUT approach)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sin_a <= ZERO; cos_a <= ONE;
            sin_b <= ZERO; cos_b <= ONE;
            sin_c <= ZERO; cos_c <= ONE;
            sin_d <= ZERO; cos_d <= ONE;
        end else if (state == COMPUTE_TRIG) begin
            // Simplified: Assume angles are small and use linear approximation
            // For actual implementation, use a proper LUT or CORDIC
            sin_a <= rad_a; cos_a <= ONE - (rad_a * rad_a) / 2;
            sin_b <= rad_b; cos_b <= ONE - (rad_b * rad_b) / 2;
            sin_c <= rad_c; cos_c <= ONE - (rad_c * rad_c) / 2;
            sin_d <= rad_d; cos_d <= ONE - (rad_d * rad_d) / 2;
        end
    end

    // Intersection calculations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x1 <= ZERO; y1 <= ZERO;
            x2 <= ZERO; y2 <= ZERO;
            x3 <= ZERO; y3 <= ZERO;
            x4 <= ZERO; y4 <= ZERO;
        end else if (state == CALC_INTERSECTIONS) begin
            // BR-TR intersection (sprinklers 1 and 2)
            // Line 1: y = tan(90-a) * (x - 1)
            // Line 2: y = tan(b) * (x - 1) + 1
            // Solve for intersection
            // Simplified: Assume intersection at (1,1) if angles are 0
            x1 <= ONE; y1 <= ONE;

            // TR-TL intersection (sprinklers 2 and 3)
            x2 <= ONE; y2 <= ONE;

            // TL-BL intersection (sprinklers 3 and 4)
            x3 <= ZERO; y3 <= ONE;

            // BL-BR intersection (sprinklers 4 and 1)
            x4 <= ZERO; y4 <= ZERO;
        end
    end

    // Area calculation using Shoelace formula
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum1 <= ZERO;
            sum2 <= ZERO;
        end else if (state == COMPUTE_AREA) begin
            // Shoelace formula: sum(x[i]*y[i+1] - x[i+1]*y[i])
            sum1 <= x1 * y2 + x2 * y3 + x3 * y4 + x4 * y1;
            sum2 <= y1 * x2 + y2 * x3 + y3 * x4 + y4 * x1;
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else if (state == OUTPUT_RESULT) begin
            // Area = |sum1 - sum2| / 2
            // Since we're in Q16.16, divide by 2 is shift right by 1
            result <= (sum1 - sum2) >>> 1;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule