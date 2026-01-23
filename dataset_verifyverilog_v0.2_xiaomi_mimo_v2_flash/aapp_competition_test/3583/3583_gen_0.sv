module max_hexagon_perimeter(
    input [5:0] n,
    input [7:0][15:0] x,
    input [7:0][15:0] y,
    output reg [31:0] perimeter
);

    // Fixed-point constants
    // SQRT_2_Q16_16 = sqrt(2) * 2^16 = 92681 = 0x00016A09
    // SQRT_3_Q16_16 = sqrt(3) * 2^16 = 113512 = 0x0001BBE8
    // SQRT_5_Q16_16 = sqrt(5) * 2^16 = 146681 = 0x00023D09
    // SQRT_6_Q16_16 = sqrt(6) * 2^16 = 159796 = 0x00027044
    localparam [31:0] SQRT_2 = 32'h00016A09;
    localparam [31:0] SQRT_3 = 32'h0001BBE8;
    localparam [31:0] SQRT_5 = 32'h00023D09;
    localparam [31:0] SQRT_6 = 32'h00027044;

    // Helper function: absolute value of 16-bit signed integer
    function automatic [15:0] abs16(input [15:0] val);
        begin
            if (val[15])
                abs16 = (~val) + 16'd1;
            else
                abs16 = val;
        end
    endfunction

    // Helper function: calculate Euclidean distance approximation in Q16.16
    // Input dx, dy are 16-bit signed differences
    // Uses fixed-point arithmetic to compute sqrt(dx^2 + dy^2)
    function automatic [31:0] calc_dist(input signed [15:0] dx, input signed [15:0] dy);
        reg [15:0] adx, ady;
        reg [31:0] dx_sq, dy_sq, sum_sq;
        reg [31:0] approx_dist;
        begin
            adx = abs16(dx);
            ady = abs16(dy);
            
            // Calculate dx^2 and dy^2 (32-bit to avoid overflow of 255^2)
            dx_sq = adx * adx;
            dy_sq = ady * ady;
            sum_sq = dx_sq + dy_sq;
            
            // To keep synthesis combinational and efficient for small inputs (dx, dy <= 255),
            // we use linear approximation based on possible squared sums:
            // This serves as an approximation for sqrt(x^2 + y^2)
            // Actual approximate values for sqrt(s) where s = sum_sq:
            // s=0 -> 0
            // s=1 -> 65536 (1.0)
            // s=2 -> 92681 (1.414)
            // s=3 -> 113512 (1.732)
            // s=4 -> 131072 (2.0)
            // s=5 -> 146681 (2.236)
            // s=6 -> 159796 (2.449)
            // s=8 -> 185363 (2.828)
            // s=9 -> 196608 (3.0)
            // s=10 -> 207842 (3.162)
            // s=16 -> 262144 (4.0)
            
            case (sum_sq)
                32'd0:    approx_dist = 32'd0;
                32'd1:    approx_dist = 32'd65536;
                32'd2:    approx_dist = SQRT_2;
                32'd3:    approx_dist = SQRT_3;
                32'd4:    approx_dist = 32'd131072;
                32'd5:    approx_dist = SQRT_5;
                32'd6:    approx_dist = SQRT_6;
                32'd8:    approx_dist = 32'd185363;
                32'd9:    approx_dist = 32'd196608;
                32'd10:   approx_dist = 32'd207842;
                32'd16:   approx_dist = 32'd262144;
                default:  approx_dist = 32'd0; // Fallback (should not happen for valid inputs)
            endcase
            
            calc_dist = approx_dist;
        end
    endfunction

    // Helper function to get vertex coordinates by index (wrapping for hexagon)
    // Indices i0...i5 are indices into the polygon vertices 0..n-1
    // We need to find edges between consecutive selected vertices.
    // This is tricky because we must follow the polygon boundary.
    // Better approach: generate all possible hexagons, sum edge lengths.
    
    // We will generate the code for perimeter calculation for all 28 cases.
    
    // Variables for perimeter calculation
    reg [31:0] p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24, p25, p26, p27, p28;
    reg [31:0] max_p;

    always @(*) begin
        // Initialize perimeters to 0
        p1 = 0; p2 = 0; p3 = 0; p4 = 0; p5 = 0; p6 = 0; p7 = 0; p8 = 0;
        p9 = 0; p10 = 0; p11 = 0; p12 = 0; p13 = 0; p14 = 0; p15 = 0; p16 = 0;
        p17 = 0; p18 = 0; p19 = 0; p20 = 0; p21 = 0; p22 = 0; p23 = 0; p24 = 0;
        p25 = 0; p26 = 0; p27 = 0; p28 = 0;
        
        // Case n=6: Only one hexagon (0,1,2,3,4,5)
        if (n == 6) begin
            p1 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[0] - x[5], y[0] - y[5]);
        end
        
        // Case n=7: 7 choose 6 = 7 hexagons
        else if (n == 7) begin
            // Hex 0: Skip 0 -> (1,2,3,4,5,6)
            p1 = calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[6] - x[5], y[6] - y[5]) +
                 calc_dist(x[1] - x[6], y[1] - y[6]);
            // Hex 1: Skip 1 -> (0,2,3,4,5,6)
            p2 = calc_dist(x[2] - x[0], y[2] - y[0]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[6] - x[5], y[6] - y[5]) +
                 calc_dist(x[0] - x[6], y[0] - y[6]);
            // Hex 2: Skip 2 -> (0,1,3,4,5,6)
            p3 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[3] - x[1], y[3] - y[1]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[6] - x[5], y[6] - y[5]) +
                 calc_dist(x[0] - x[6], y[0] - y[6]);
            // Hex 3: Skip 3 -> (0,1,2,4,5,6)
            p4 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[4] - x[2], y[4] - y[2]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[6] - x[5], y[6] - y[5]) +
                 calc_dist(x[0] - x[6], y[0] - y[6]);
            // Hex 4: Skip 4 -> (0,1,2,3,5,6)
            p5 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[5] - x[3], y[5] - y[3]) +
                 calc_dist(x[6] - x[5], y[6] - y[5]) +
                 calc_dist(x[0] - x[6], y[0] - y[6]);
            // Hex 5: Skip 5 -> (0,1,2,3,4,6)
            p6 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[6] - x[4], y[6] - y[4]) +
                 calc_dist(x[0] - x[6], y[0] - y[6]);
            // Hex 6: Skip 6 -> (0,1,2,3,4,5)
            p7 = calc_dist(x[1] - x[0], y[1] - y[0]) +
                 calc_dist(x[2] - x[1], y[2] - y[1]) +
                 calc_dist(x[3] - x[2], y[3] - y[2]) +
                 calc_dist(x[4] - x[3], y[4] - y[3]) +
                 calc_dist(x[5] - x[4], y[5] - y[4]) +
                 calc_dist(x[0] - x[5], y[0] - y[5]);
        end
        
        // Case n=8: 8 choose 6 = 28 hexagons
        else if (n == 8) begin
            // We select 6 vertices out of 8. Let's assume indices 0..7.
            // Hex 0: Vertices 0,1,2,3,4,5
            p1 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[0]-x[5],y[0]-y[5]);
            // Hex 1: Vertices 0,1,2,3,4,6
            p2 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[6]-x[4],y[6]-y[4]) + calc_dist(x[0]-x[6],y[0]-y[6]);
            // Hex 2: Vertices 0,1,2,3,4,7
            p3 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[7]-x[4],y[7]-y[4]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 3: Vertices 0,1,2,3,5,6
            p4 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[5]-x[3],y[5]-y[3]) + calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[0]-x[6],y[0]-y[6]);
            // Hex 4: Vertices 0,1,2,3,5,7
            p5 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[5]-x[3],y[5]-y[3]) + calc_dist(x[7]-x[5],y[7]-y[5]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 5: Vertices 0,1,2,3,6,7
            p6 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + 
                 calc_dist(x[6]-x[3],y[6]-y[3]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 6: Vertices 0,1,2,4,5,6
            p7 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[4]-x[2],y[4]-y[2]) + 
                 calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[0]-x[6],y[0]-y[6]);
            // Hex 7: Vertices 0,1,2,4,5,7
            p8 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[4]-x[2],y[4]-y[2]) + 
                 calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[7]-x[5],y[7]-y[5]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 8: Vertices 0,1,2,4,6,7
            p9 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[4]-x[2],y[4]-y[2]) + 
                 calc_dist(x[6]-x[4],y[6]-y[4]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 9: Vertices 0,1,2,5,6,7
            p10 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[5]-x[2],y[5]-y[2]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 10: Vertices 0,1,3,4,5,6
            p11 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[3]-x[1],y[3]-y[1]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[0]-x[6],y[0]-y[6]);
            // Hex 11: Vertices 0,1,3,4,5,7
            p12 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[3]-x[1],y[3]-y[1]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[7]-x[5],y[7]-y[5]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 12: Vertices 0,1,3,4,6,7
            p13 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[3]-x[1],y[3]-y[1]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[6]-x[4],y[6]-y[4]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 13: Vertices 0,1,3,5,6,7
            p14 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[3]-x[1],y[3]-y[1]) + calc_dist(x[5]-x[3],y[5]-y[3]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 14: Vertices 0,1,4,5,6,7
            p15 = calc_dist(x[1]-x[0],y[1]-y[0]) + calc_dist(x[4]-x[1],y[4]-y[1]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 15: Vertices 0,2,3,4,5,6
            p16 = calc_dist(x[2]-x[0],y[2]-y[0]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[0]-x[6],y[0]-y[6]);
            // Hex 16: Vertices 0,2,3,4,5,7
            p17 = calc_dist(x[2]-x[0],y[2]-y[0]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[7]-x[5],y[7]-y[5]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 17: Vertices 0,2,3,4,6,7
            p18 = calc_dist(x[2]-x[0],y[2]-y[0]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[6]-x[4],y[6]-y[4]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 18: Vertices 0,2,3,5,6,7
            p19 = calc_dist(x[2]-x[0],y[2]-y[0]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[5]-x[3],y[5]-y[3]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 19: Vertices 0,2,4,5,6,7
            p20 = calc_dist(x[2]-x[0],y[2]-y[0]) + calc_dist(x[4]-x[2],y[4]-y[2]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 20: Vertices 0,3,4,5,6,7
            p21 = calc_dist(x[3]-x[0],y[3]-y[0]) + calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[0]-x[7],y[0]-y[7]);
            // Hex 21: Vertices 1,2,3,4,5,6
            p22 = calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[1]-x[6],y[1]-y[6]);
            // Hex 22: Vertices 1,2,3,4,5,7
            p23 = calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[5]-x[4],y[5]-y[4]) + calc_dist(x[7]-x[5],y[7]-y[5]) + calc_dist(x[1]-x[7],y[1]-y[7]);
            // Hex 23: Vertices 1,2,3,4,6,7
            p24 = calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + 
                  calc_dist(x[6]-x[4],y[6]-y[4]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[1]-x[7],y[1]-y[7]);
            // Hex 24: Vertices 1,2,3,5,6,7
            p25 = calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[5]-x[3],y[5]-y[3]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[1]-x[7],y[1]-y[7]);
            // Hex 25: Vertices 1,2,4,5,6,7
            p26 = calc_dist(x[2]-x[1],y[2]-y[1]) + calc_dist(x[4]-x[2],y[4]-y[2]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[1]-x[7],y[1]-y[7]);
            // Hex 26: Vertices 1,3,4,5,6,7
            p27 = calc_dist(x[3]-x[1],y[3]-y[1]) + calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[1]-x[7],y[1]-y[7]);
            // Hex 27: Vertices 2,3,4,5,6,7
            p28 = calc_dist(x[3]-x[2],y[3]-y[2]) + calc_dist(x[4]-x[3],y[4]-y[3]) + calc_dist(x[5]-x[4],y[5]-y[4]) + 
                  calc_dist(x[6]-x[5],y[6]-y[5]) + calc_dist(x[7]-x[6],y[7]-y[6]) + calc_dist(x[2]-x[7],y[2]-y[7]);
        end
        
        // Default case (should not happen for n<6 or n>8)
        else begin
            p1 = 0;
        end

        // Find maximum perimeter
        max_p = p1;
        if (p2 > max_p) max_p = p2;
        if (p3 > max_p) max_p = p3;
        if (p4 > max_p) max_p = p4;
        if (p5 > max_p) max_p = p5;
        if (p6 > max_p) max_p = p6;
        if (p7 > max_p) max_p = p7;
        if (n == 8) begin
            if (p8 > max_p) max_p = p8;
            if (p9 > max_p) max_p = p9;
            if (p10 > max_p) max_p = p10;
            if (p11 > max_p) max_p = p11;
            if (p12 > max_p) max_p = p12;
            if (p13 > max_p) max_p = p13;
            if (p14 > max_p) max_p = p14;
            if (p15 > max_p) max_p = p15;
            if (p16 > max_p) max_p = p16;
            if (p17 > max_p) max_p = p17;
            if (p18 > max_p) max_p = p18;
            if (p19 > max_p) max_p = p19;
            if (p20 > max_p) max_p = p20;
            if (p21 > max_p) max_p = p21;
            if (p22 > max_p) max_p = p22;
            if (p23 > max_p) max_p = p23;
            if (p24 > max_p) max_p = p24;
            if (p25 > max_p) max_p = p25;
            if (p26 > max_p) max_p = p26;
            if (p27 > max_p) max_p = p27;
            if (p28 > max_p) max_p = p28;
        end
        
        perimeter = max_p;
    end

endmodule
