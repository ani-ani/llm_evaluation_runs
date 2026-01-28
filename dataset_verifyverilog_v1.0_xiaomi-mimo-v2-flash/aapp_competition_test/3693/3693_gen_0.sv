module SquareIntersection(
    input clk,
    input rst_n,
    input start,
    input signed [8:0] sq_a_x [0:3],
    input signed [8:0] sq_a_y [0:3],
    input signed [8:0] sq_b_x [0:3],
    input signed [8:0] sq_b_y [0:3],
    output reg result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CALC_EXTREMES = 3'd1;
localparam [2:0] CHECK_POINTS = 3'd2;
localparam [2:0] FINISH = 3'd3;

// Internal registers and wires
reg [2:0] state;
reg [2:0] next_state;

// Registers for bounding box values (scaled coordinates)
reg signed [8:0] a_x_min, a_x_max, a_y_min, a_y_max;
reg signed [9:0] b_u_min, b_u_max; // u range [0, 400]
reg signed [9:0] b_v_min, b_v_max; // v range [-200, 200]

// Point iteration control
reg [2:0] point_idx; // 0 to 4
reg [1:0] coord_idx; // 0 to 3 for corners (center uses 2,2)

// Intermediate values for computation
reg signed [8:0] current_x, current_y;
reg signed [10:0] u_calc, v_calc; // 11 bits for signed range

// Helper logic for min/max of 4 inputs (combinational)
wire signed [8:0] a_x_min_wire [0:3];
wire signed [8:0] a_x_max_wire [0:3];
wire signed [8:0] a_y_min_wire [0:3];
wire signed [8:0] a_y_max_wire [0:3];

// Helper logic for min/max of transformed B vertices (combinational)
wire signed [9:0] b_u_val [0:3];
wire signed [9:0] b_v_val [0:3];

// Generate helper logic for A extremes
assign a_x_min_wire[0] = (sq_a_x[0] < sq_a_x[1]) ? sq_a_x[0] : sq_a_x[1];
assign a_x_min_wire[1] = (sq_a_x[2] < sq_a_x[3]) ? sq_a_x[2] : sq_a_x[3];
assign a_x_min_wire[2] = (a_x_min_wire[0] < a_x_min_wire[1]) ? a_x_min_wire[0] : a_x_min_wire[1];
assign a_x_min_wire[3] = a_x_min_wire[2]; // final

assign a_x_max_wire[0] = (sq_a_x[0] > sq_a_x[1]) ? sq_a_x[0] : sq_a_x[1];
assign a_x_max_wire[1] = (sq_a_x[2] > sq_a_x[3]) ? sq_a_x[2] : sq_a_x[3];
assign a_x_max_wire[2] = (a_x_max_wire[0] > a_x_max_wire[1]) ? a_x_max_wire[0] : a_x_max_wire[1];
assign a_x_max_wire[3] = a_x_max_wire[2];

assign a_y_min_wire[0] = (sq_a_y[0] < sq_a_y[1]) ? sq_a_y[0] : sq_a_y[1];
assign a_y_min_wire[1] = (sq_a_y[2] < sq_a_y[3]) ? sq_a_y[2] : sq_a_y[3];
assign a_y_min_wire[2] = (a_y_min_wire[0] < a_y_min_wire[1]) ? a_y_min_wire[0] : a_y_min_wire[1];
assign a_y_min_wire[3] = a_y_min_wire[2];

assign a_y_max_wire[0] = (sq_a_y[0] > sq_a_y[1]) ? sq_a_y[0] : sq_a_y[1];
assign a_y_max_wire[1] = (sq_a_y[2] > sq_a_y[3]) ? sq_a_y[2] : sq_a_y[3];
assign a_y_max_wire[2] = (a_y_max_wire[0] > a_y_max_wire[1]) ? a_y_max_wire[0] : a_y_max_wire[1];
assign a_y_max_wire[3] = a_y_max_wire[2];

// Transform B coordinates (scaled + 100)
// u = x_scaled + y_scaled, v = x_scaled - y_scaled
// x_scaled = x_orig + 100, y_scaled = y_orig + 100
// u = x_orig + y_orig + 200
// v = x_orig - y_orig
// Range: x_orig/y_orig [-100, 100]
// u: [0, 400] -> fits in 9 bits (signed) or 10 bits
// v: [-200, 200] -> fits in 9 bits (signed) or 10 bits

generate
    genvar i;
    for (i = 0; i < 4; i = i + 1) begin : transform_b
        assign b_u_val[i] = sq_b_x[i] + sq_b_y[i] + 10'sd200;
        assign b_v_val[i] = sq_b_x[i] - sq_b_y[i];
    end
endgenerate

wire signed [9:0] b_u_min_wire, b_u_max_wire, b_v_min_wire, b_v_max_wire;

// Min/Max for B_u
assign b_u_min_wire[0] = (b_u_val[0] < b_u_val[1]) ? b_u_val[0] : b_u_val[1];
assign b_u_min_wire[1] = (b_u_val[2] < b_u_val[3]) ? b_u_val[2] : b_u_val[3];
assign b_u_min_wire[2] = (b_u_min_wire[0] < b_u_min_wire[1]) ? b_u_min_wire[0] : b_u_min_wire[1];

assign b_u_max_wire[0] = (b_u_val[0] > b_u_val[1]) ? b_u_val[0] : b_u_val[1];
assign b_u_max_wire[1] = (b_u_val[2] > b_u_val[3]) ? b_u_val[2] : b_u_val[3];
assign b_u_max_wire[2] = (b_u_max_wire[0] > b_u_max_wire[1]) ? b_u_max_wire[0] : b_u_max_wire[1];

// Min/Max for B_v
assign b_v_min_wire[0] = (b_v_val[0] < b_v_val[1]) ? b_v_val[0] : b_v_val[1];
assign b_v_min_wire[1] = (b_v_val[2] < b_v_val[3]) ? b_v_val[2] : b_v_val[3];
assign b_v_min_wire[2] = (b_v_min_wire[0] < b_v_min_wire[1]) ? b_v_min_wire[0] : b_v_min_wire[1];

assign b_v_max_wire[0] = (b_v_val[0] > b_v_val[1]) ? b_v_val[0] : b_v_val[1];
assign b_v_max_wire[1] = (b_v_val[2] > b_v_val[3]) ? b_v_val[2] : b_v_val[3];
assign b_v_max_wire[2] = (b_v_max_wire[0] > b_v_max_wire[1]) ? b_v_max_wire[0] : b_v_max_wire[1];

// FSM Synchronous Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 1'b0;
        done <= 1'b0;
        a_x_min <= 9'sd0;
        a_x_max <= 9'sd0;
        a_y_min <= 9'sd0;
        a_y_max <= 9'sd0;
        b_u_min <= 10'sd0;
        b_u_max <= 10'sd0;
        b_v_min <= 10'sd0;
        b_v_max <= 10'sd0;
        point_idx <= 3'd0;
        coord_idx <= 2'd0;
        current_x <= 9'sd0;
        current_y <= 9'sd0;
        u_calc <= 11'sd0;
        v_calc <= 11'sd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= CALC_EXTREMES;
                end
            end

            CALC_EXTREMES: begin
                // Capture calculated extremes
                a_x_min <= a_x_min_wire[3];
                a_x_max <= a_x_max_wire[3];
                a_y_min <= a_y_min_wire[3];
                a_y_max <= a_y_max_wire[3];
                b_u_min <= b_u_min_wire[2];
                b_u_max <= b_u_max_wire[2];
                b_v_min <= b_v_min_wire[2];
                b_v_max <= b_v_max_wire[2];
                
                // Reset point iterator
                point_idx <= 3'd0;
                coord_idx <= 2'd0;
                state <= CHECK_POINTS;
            end

            CHECK_POINTS: begin
                // Determine current point (x, y)
                // 0-3: Corners of A (a_x_min/y_min), (a_x_max/y_min), etc.
                // 4: Center of A
                case (point_idx)
                    3'd0: begin // Bottom-Left
                        current_x <= a_x_min;
                        current_y <= a_y_min;
                    end
                    3'd1: begin // Bottom-Right
                        current_x <= a_x_max;
                        current_y <= a_y_min;
                    end
                    3'd2: begin // Top-Left
                        current_x <= a_x_min;
                        current_y <= a_y_max;
                    end
                    3'd3: begin // Top-Right
                        current_x <= a_x_max;
                        current_y <= a_y_max;
                    end
                    3'd4: begin // Center
                        // Center calculation: (min+max)/2
                        current_x <= (a_x_min + a_x_max) >>> 1;
                        current_y <= (a_y_min + a_y_max) >>> 1;
                    end
                    default: begin
                        current_x <= 9'sd0;
                        current_y <= 9'sd0;
                    end
                endcase

                // Calculate u and v for current point
                // x/y are scaled (already in range -100 to 100)
                // u = x + y + 200, v = x - y
                // Need 11 bits to hold potential overflow (200+200=400 fits in 9, but signed logic needs care)
                // Range [-100, 100] -> u [0, 400], v [-200, 200]
                u_calc <= current_x + current_y + 11'sd200;
                v_calc <= current_x - current_y;

                // Check condition (combinational, registered in next cycle or use wired logic)
                // Since we are in sequential block, we can compute condition here and latch result
                if ( (u_calc >= b_u_min) && (u_calc <= b_u_max) &&
                     (v_calc >= b_v_min) && (v_calc <= b_v_max) ) begin
                    result <= 1'b1; // Intersection found
                end
                // If result is already 1, keep it high

                // Move to next point
                if (point_idx < 3'd4) begin
                    point_idx <= point_idx + 3'd1;
                end else begin
                    state <= FINISH;
                end
            end

            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule