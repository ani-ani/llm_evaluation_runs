module cat_chase_verifier (
    input        [3:0]  valid_mice_mask,
    input        [4:0][15:0] x_coords,
    input        [4:0][15:0] y_coords,
    input        [4:0][15:0] deadlines,
    input        [4:0][15:0] velocities,
    output reg            success
);

    // Internal signals for pipeline stages
    // Stage 1: Calculations for mouse 0
    wire [15:0] dx0 = x_coords[0];
    wire [15:0] dy0 = y_coords[0];
    wire [16:0] dist0 = dx0[15] ? (17'h10000 - dx0) : dx0; // |dx|: Q16.0 (effectively)
    wire [16:0] dist0_y = dy0[15] ? (17'h10000 - dy0) : dy0;
    wire [17:0] manhattan0 = dist0 + dist0_y; // Q16.0, max 32 bits required but fits 18 bits for valid inputs
    wire [31:0] time0 = (manhattan0 << 16) / velocities[0]; // (dist << 16) / vel -> Q16.16
    wire        cond0 = valid_mice_mask[0] && (time0 > deadlines[0]);

    // Stage 2: Calculations for mouse 1 (depends on time 0)
    wire [15:0] dx1 = x_coords[1] - x_coords[0];
    wire [15:0] dy1 = y_coords[1] - y_coords[0];
    wire [16:0] dist1 = dx1[15] ? (17'h10000 - dx1) : dx1;
    wire [16:0] dist1_y = dy1[15] ? (17'h10000 - dy1) : dy1;
    wire [17:0] manhattan1 = dist1 + dist1_y;
    wire [31:0] time1 = (manhattan1 << 16) / velocities[1];
    wire [31:0] current_time1 = time0 + time1;
    wire        cond1 = valid_mice_mask[1] && (current_time1 > deadlines[1]);

    // Stage 3: Calculations for mouse 2
    wire [15:0] dx2 = x_coords[2] - x_coords[1];
    wire [15:0] dy2 = y_coords[2] - y_coords[1];
    wire [16:0] dist2 = dx2[15] ? (17'h10000 - dx2) : dx2;
    wire [16:0] dist2_y = dy2[15] ? (17'h10000 - dy2) : dy2;
    wire [17:0] manhattan2 = dist2 + dist2_y;
    wire [31:0] time2 = (manhattan2 << 16) / velocities[2];
    wire [31:0] current_time2 = current_time1 + time2;
    wire        cond2 = valid_mice_mask[2] && (current_time2 > deadlines[2]);

    // Stage 4: Calculations for mouse 3
    wire [15:0] dx3 = x_coords[3] - x_coords[2];
    wire [15:0] dy3 = y_coords[3] - y_coords[2];
    wire [16:0] dist3 = dx3[15] ? (17'h10000 - dx3) : dx3;
    wire [16:0] dist3_y = dy3[15] ? (17'h10000 - dy3) : dy3;
    wire [17:0] manhattan3 = dist3 + dist3_y;
    wire [31:0] time3 = (manhattan3 << 16) / velocities[3];
    wire [31:0] current_time3 = current_time2 + time3;
    wire        cond3 = valid_mice_mask[3] && (current_time3 > deadlines[3]);

    // Combinational Output Logic
    // success is 1 if no failure condition (cond) is met for valid mice
    always @(*) begin
        success = 1'b1;
        if (cond0) success = 1'b0;
        if (cond1) success = 1'b0;
        if (cond2) success = 1'b0;
        if (cond3) success = 1'b0;
    end

endmodule