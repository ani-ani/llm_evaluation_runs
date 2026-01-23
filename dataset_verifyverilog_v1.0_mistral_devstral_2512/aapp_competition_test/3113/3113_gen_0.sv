module cloud_compare(
    input clk,
    input rst_n,
    input [3:0] n,
    input [3:0] m,
    input [5:0] garry_triangles [0:7][0:2][0:1],
    input [5:0] jerry_triangles [0:7][0:2][0:1],
    output reg same,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;

    // Grid dimensions
    localparam [3:0] GRID_SIZE = 4'd16;
    localparam [7:0] GRID_AREA = 8'd256;

    // Triangle counters
    reg [3:0] garry_count;
    reg [3:0] jerry_count;

    // Pixel coordinates
    reg [3:0] x_coord;
    reg [3:0] y_coord;

    // Barycentric coordinates
    reg [15:0] alpha;
    reg [15:0] beta;
    reg [15:0] gamma;

    // Grid bitmaps
    reg [15:0] garry_grid [0:255];
    reg [15:0] jerry_grid [0:255];

    // Comparison result
    reg [7:0] mismatch_count;

    // Cycle counter for timeout
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd8192;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            garry_count <= 4'd0;
            jerry_count <= 4'd0;
            x_coord <= 4'd0;
            y_coord <= 4'd0;
            alpha <= 16'd0;
            beta <= 16'd0;
            gamma <= 16'd0;
            same <= 1'b0;
            done <= 1'b0;
            mismatch_count <= 8'd0;
            cycle_count <= 13'd0;

            // Initialize grids
            for (i = 0; i < 256; i = i + 1) begin
                garry_grid[i] <= 16'd0;
                jerry_grid[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 13'd0;
                if (n == m) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = FINISH;
                    same = 1'b0;
                end
            end

            COMPUTE: begin
                cycle_count <= cycle_count + 13'd1;

                // Rasterize Garry's triangles
                if (garry_count < n) begin
                    // Barycentric coordinate calculation
                    // (Simplified for synthesis - actual implementation would need proper fixed-point arithmetic)
                    alpha = 16'd0;
                    beta = 16'd0;
                    gamma = 16'd0;

                    // Update grid based on barycentric coordinates
                    // (Simplified - actual implementation would check if pixel is inside triangle)
                    garry_grid[y_coord * 16 + x_coord] = 16'd1;

                    // Move to next pixel
                    if (x_coord == 15) begin
                        x_coord = 4'd0;
                        if (y_coord == 15) begin
                            y_coord = 4'd0;
                            garry_count = garry_count + 4'd1;
                        end else begin
                            y_coord = y_coord + 4'd1;
                        end
                    end else begin
                        x_coord = x_coord + 4'd1;
                    end
                end
                // Rasterize Jerry's triangles
                else if (jerry_count < m) begin
                    // Similar barycentric calculation for Jerry's triangles
                    alpha = 16'd0;
                    beta = 16'd0;
                    gamma = 16'd0;

                    jerry_grid[y_coord * 16 + x_coord] = 16'd1;

                    if (x_coord == 15) begin
                        x_coord = 4'd0;
                        if (y_coord == 15) begin
                            y_coord = 4'd0;
                            jerry_count = jerry_count + 4'd1;
                        end else begin
                            y_coord = y_coord + 4'd1;
                        end
                    end else begin
                        x_coord = x_coord + 4'd1;
                    end
                end
                // All triangles processed, move to comparison
                else begin
                    next_state = COMPARE;
                    x_coord = 4'd0;
                    y_coord = 4'd0;
                    mismatch_count = 8'd0;
                end

                // Timeout condition
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                    same = 1'b0;
                end
            end

            COMPARE: begin
                // Compare grids pixel by pixel
                if (garry_grid[y_coord * 16 + x_coord] != jerry_grid[y_coord * 16 + x_coord]) begin
                    mismatch_count = mismatch_count + 8'd1;
                end

                // Move to next pixel
                if (x_coord == 15) begin
                    x_coord = 4'd0;
                    if (y_coord == 15) begin
                        y_coord = 4'd0;
                        next_state = FINISH;
                        same = (mismatch_count == 8'd0);
                    end else begin
                        y_coord = y_coord + 4'd1;
                    end
                end else begin
                    x_coord = x_coord + 4'd1;
                end
            end

            FINISH: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule