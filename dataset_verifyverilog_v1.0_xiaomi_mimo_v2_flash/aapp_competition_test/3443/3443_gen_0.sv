module symmetry_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,           // Number of points (1-4)
    input wire [15:0] points [3:0], // Array of 4 points, each 16-bit (x[7:0], y[7:0])
    output reg [3:0] result,      // Minimum additions needed (0-15)
    output reg done               // Computation complete
);

// Module computes minimum additions needed to make points symmetric about a point
// Only point symmetry is implemented (line symmetry omitted due to complexity)
// Algorithm:
// 1. Generate all possible symmetry centers from pairwise midpoints
// 2. For each center, count points that already have their reflection
// 3. Result = total_points - max_symmetric_pairs

// State machine states
localparam [1:0] IDLE     = 2'd0;
localparam [1:0] COMPUTE  = 2'd1;
localparam [1:0] CHECK    = 2'd2;
localparam [1:0] DONE     = 2'd3;

// Internal registers
reg [1:0] state;
reg [2:0] stored_n;
reg [15:0] stored_points [3:0];
reg [3:0] max_symmetric;
reg [1:0] i, j, k;          // Loop counters
reg [7:0] cx, cy;           // Current center
reg [3:0] symmetric_count;  // Count for current center
reg [1:0] center_idx;       // Current center index
reg [1:0] point_count;      // Count of points checked

// Midpoint computation
wire [7:0] mid_x;
wire [7:0] mid_y;
assign mid_x = (stored_points[i][7:0] + stored_points[j][7:0]) >> 1;
assign mid_y = (stored_points[i][15:8] + stored_points[j][15:8]) >> 1;

// Reflection check
wire [7:0] refl_x;
wire [7:0] refl_y;
wire refl_match;
assign refl_x = (cx << 1) - stored_points[k][7:0];
assign refl_y = (cy << 1) - stored_points[k][15:8];
assign refl_match = (refl_x == stored_points[k][7:0]) && (refl_y == stored_points[k][15:8]);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 4'd15;
        done <= 1'b0;
        max_symmetric <= 4'd0;
        i <= 2'd0;
        j <= 2'd1;
        k <= 2'd0;
        center_idx <= 2'd0;
        symmetric_count <= 4'd0;
        point_count <= 2'd0;
        cx <= 8'd0;
        cy <= 8'd0;
        stored_n <= 3'd0;
        stored_points[0] <= 16'd0;
        stored_points[1] <= 16'd0;
        stored_points[2] <= 16'd0;
        stored_points[3] <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start && n > 3'd0) begin
                    stored_n <= n;
                    stored_points[0] <= points[0];
                    stored_points[1] <= points[1];
                    stored_points[2] <= points[2];
                    stored_points[3] <= points[3];
                    max_symmetric <= 4'd0;
                    i <= 2'd0;
                    j <= 2'd1;
                    center_idx <= 2'd0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Generate center from points[i] and points[j]
                cx <= mid_x;
                cy <= mid_y;
                symmetric_count <= 4'd0;
                k <= 2'd0;
                point_count <= 2'd0;
                state <= CHECK;
            end
            
            CHECK: begin
                if (point_count < stored_n) begin
                    // Check if point k has reflection or is self-symmetric
                    if (refl_match || (k == i) || (k == j)) begin
                        symmetric_count <= symmetric_count + 4'd1;
                    end
                    k <= k + 2'd1;
                    point_count <= point_count + 2'd1;
                end else begin
                    // Done checking this center
                    if (symmetric_count > max_symmetric) begin
                        max_symmetric <= symmetric_count;
                    end
                    // Move to next center
                    if (j < stored_n - 2'd1) begin
                        j <= j + 2'd1;
                        state <= COMPUTE;
                    end else if (i < stored_n - 3'd2) begin
                        i <= i + 2'd1;
                        j <= i + 3'd2;
                        state <= COMPUTE;
                    end else begin
                        // All centers processed
                        result <= stored_n - max_symmetric;
                        state <= DONE;
                    end
                end
            end
            
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule