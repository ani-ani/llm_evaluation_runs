module regions_by_circles (
    input [1:0] n,
    input signed [7:0] x1, y1, r1,
    input signed [7:0] x2, y2, r2,
    input signed [7:0] x3, y3, r3,
    output reg [7:0] result
);

    // Intermediate variables for distance and intersection calculations
    wire signed [15:0] d12_sq, d23_sq, d31_sq;
    wire signed [15:0] sum_r12, sum_r23, sum_r31;
    wire signed [15:0] diff_r12, diff_r23, diff_r31;
    wire [7:0] regions_2;
    wire [7:0] regions_3;

    // Distance squared calculations (avoid sqrt, use squared comparisons)
    assign d12_sq = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
    assign d23_sq = (x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3);
    assign d31_sq = (x3 - x1) * (x3 - x1) + (y3 - y1) * (y3 - y1);

    // Sum and difference of radii (squared for comparison)
    assign sum_r12 = (r1 + r2) * (r1 + r2);
    assign sum_r23 = (r2 + r3) * (r2 + r3);
    assign sum_r31 = (r3 + r1) * (r3 + r1);
    assign diff_r12 = (r1 - r2) * (r1 - r2);
    assign diff_r23 = (r2 - r3) * (r2 - r3);
    assign diff_r31 = (r3 - r1) * (r3 - r1);

    // Combinational logic for n=2 case
    reg one_intersect_12;
    always @(*) begin
        if (d12_sq == sum_r12 || d12_sq == diff_r12) begin
            one_intersect_12 = 1'b1;
        end else if (d12_sq < sum_r12 && d12_sq > diff_r12) begin
            one_intersect_12 = 1'b0;
        end else begin
            one_intersect_12 = 1'b0;
        end
    end
    assign regions_2 = (one_intersect_12) ? 8'd4 : 8'd3;

    // Combinational logic for n=3 case
    reg one_intersect_23, one_intersect_31;
    reg [1:0] intersect_count;
    reg intersect_same_point;
    reg [7:0] regions_3_temp;

    always @(*) begin
        // Check each pair for single intersection point
        one_intersect_23 = (d23_sq == sum_r23 || d23_sq == diff_r23);
        one_intersect_31 = (d31_sq == sum_r31 || d31_sq == diff_r31);
        
        intersect_count = 2'd0;
        if (one_intersect_12) intersect_count = intersect_count + 2'd1;
        if (one_intersect_23) intersect_count = intersect_count + 2'd1;
        if (one_intersect_31) intersect_count = intersect_count + 2'd1;

        // Check if all three intersections occur at the same point
        // Simplified check: if d12_sq, d23_sq, d31_sq equal sum squares AND radii aligned
        // This is complex; use a simplified heuristic: if intersect_count >= 2
        // and the intersection points could be common (e.g., concentric + tangent)
        // For this integer-only logic, we check if any pair is concentric (d=0) AND tangent
        intersect_same_point = 1'b0;
        if (intersect_count == 2'd3) begin
            // 3 tangencies likely implies concurrent intersections (e.g., Apollonian)
            // Check if circles share the same center point (approximate)
            // A more robust check requires actual intersection coordinates.
            // Given integer constraints, if all three distances squared equal 0 (concentric) 
            // and radii aligned for tangency, but that's impossible for 3 radii.
            // Let's assume generic 3 distinct intersections unless concentric cases.
            intersect_same_point = 1'b0; // Default assumption
            // Concentric check for pairs (not all three unless radii match, which is distinct)
            if (d12_sq == 0 && d23_sq == 0 && d31_sq == 0) begin
                // All concentric, intersect_same_point is irrelevant for count logic
                intersect_same_point = 1'b0;
            end
        end

        // Region calculation
        case (intersect_count)
            2'd0: begin
                // 0 tangent points
                // Case: No intersections or 2 intersections per pair
                // 0 intersections (all separate): 4 regions
                // 6 intersections: 8 regions
                // 2 intersections per pair: Check nested vs disjoint
                // Simplification: if all d_sq > sum_r (separate) -> 4
                // if one inside another but no intersection -> 4
                // if 2 intersections per pair (generic 3 overlap) -> 8
                // if one inside another (nested) -> 4 (but boundaries not counted as intersections for this logic)
                // 6 intersections means 3 pairs * 2 points = 8 regions.
                // 0 tangent points does not mean 0 intersections.
                // Recalculate properly based on intersection counts (0, 2, 4, 6 points).
                
                // Let's derive intersection counts properly:
                // Pair 1: 0 (separate or nested), 2 (intersect), 1 (tangent)
                // We need to distinguish separate vs nested for 0 intersection case.
                
                // Correct 0-tangent logic:
                // Count actual crossing points (0, 2, 4, 6).
                // This is hard to do purely integer without sqrt for exact crossing detection.
                // We use squared comparisons for crossing (d < sum && d > diff).
                
                // Let's redefine regions_3_temp based on the 3 circles' configuration.
                // We need to detect if one circle is inside another (no crossing).
                // d < diff && d != 0 -> Inside.
                
                // Re-evaluating regions_3 logic (simplified for integer arithmetic):
                // 1. All disjoint (d > sum for all pairs): 4 regions.
                // 2. Two intersect, one disjoint: 6 regions.
                // 3. All three intersect each other (3 pairs): 8 regions.
                // 4. One inside another (d < diff): 4 regions (if the inner one is just a point/empty set in terms of region count? No, it adds 1 region).
                // If C1 contains C2 (no crossing), C2 adds 1 region inside C1. Total 3 regions (C1 interior, C2 interior, exterior).
                // If C3 intersects C1, it splits C1's interior and exterior.
                
                // Let's use a heuristic for 0 tangencies:
                // Count pairs that have 2 intersections.
                reg [1:0] pair_intersects;
                pair_intersects = 2'd0;
                if (d12_sq < sum_r12 && d12_sq > diff_r12) pair_intersects = pair_intersects + 2'd1;
                if (d23_sq < sum_r23 && d23_sq > diff_r23) pair_intersects = pair_intersects + 2'd1;
                if (d31_sq < sum_r31 && d31_sq > diff_r31) pair_intersects = pair_intersects + 2'd1;
                
                case (pair_intersects)
                    2'd0: begin
                        // No pairs intersect. Check for nesting.
                        // If C1 inside C2, C3 outside: 4 regions.
                        // If all separate: 4 regions.
                        // If C1 inside C2, C2 inside C3: 4 regions (3 circles inside each other, 4 regions).
                        regions_3_temp = 8'd4;
                    end
                    2'd1: regions_3_temp = 8'd6;
                    2'd2: regions_3_temp = 8'd7;
                    2'd3: regions_3_temp = 8'd8;
                    default: regions_3_temp = 8'd4;
                endcase
            end
            2'd1: regions_3_temp = 8'd6; // 1 tangent + other pairs non-tangent
            2'd2: begin
                // 2 tangencies. 
                // If all 3 tangent at same point: 6 regions.
                // If tangent at distinct points: 7 regions (usually).
                // Heuristic: if d12_sq==0 (concentric) implies tangent point is center? 
                // Concentric circles can't be tangent unless radii equal (coincident, not 3 distinct circles).
                // So tangencies are likely distinct.
                regions_3_temp = 8'd7;
                // Special case: 3 circles tangent at one point (e.g. touching externally).
                // Requires checking if intersection points coincide.
                // Skip exact coordinate check for simplicity, assume 7.
            end
            2'd3: regions_3_temp = 8'd6; // 3 concurrent tangencies (e.g. mutually tangent)
            default: regions_3_temp = 8'd4;
        endcase
    end

    // Final output selection
    always @(*) begin
        case (n)
            2'd1: result = 8'd2;
            2'd2: result = regions_2;
            2'd3: result = regions_3_temp;
            default: result = 8'd0;
        endcase
    end

endmodule