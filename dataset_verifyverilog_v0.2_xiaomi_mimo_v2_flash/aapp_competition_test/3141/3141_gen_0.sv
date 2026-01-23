module drill_min_diameter(
    input clk,
    input rst_n,
    input start,
    input [31:0] flaw_x [0:7],
    input [31:0] flaw_y [0:7],
    output reg [31:0] diameter,
    output reg done
);

    // States
    localparam IDLE = 4'd0;
    localparam CALCULATE_BBOX = 4'd1;
    localparam CALCULATE_CENTER = 4'd2;
    localparam CHECK_SUPPORT = 4'd3;
    localparam REFINE_RADIUS = 4'd4;
    localparam DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [3:0] next_state;

    // Registers for intermediate values
    reg signed [31:0] min_x;
    reg signed [31:0] max_x;
    reg signed [31:0] min_y;
    reg signed [31:0] max_y;
    reg signed [31:0] center_x;
    reg signed [31:0] center_y;
    reg signed [31:0] radius;
    reg [4:0] iter_count; // 0 to 16
    reg [2:0] flaw_idx;   // 0 to 7

    // Combinational helper wires
    reg signed [31:0] diff_x;
    reg signed [31:0] diff_y;
    reg signed [63:0] sq_x;
    reg signed [63:0] sq_y;
    reg signed [63:0] sum_sq;
    reg signed [63:0] approx_dist; // Stored directly as Q32.32 (since we don't have sqrt)

    reg signed [63:0] temp_dist_sq;
    reg signed [63:0] max_dist_sq;
    reg signed [31:0] furthest_x;
    reg signed [31:0] furthest_y;
    reg signed [31:0] temp_center_x;
    reg signed [31:0] temp_center_y;
    reg signed [31:0] temp_radius;

    // Square root logic (combinational approximation)
    wire [63:0] sqrt_in; // Input to sqrt (64 bit)
    wire [31:0] sqrt_out; // Output (32 bit)
    assign sqrt_out = (temp_dist_sq[63:32] > 0) ? temp_dist_sq[63:32] : temp_dist_sq[47:16];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            diameter <= 0;
            done <= 0;
            iter_count <= 0;
            flaw_idx <= 0;
            max_dist_sq <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALCULATE_BBOX;
                        flaw_idx <= 0;
                        // Initialize min/max with first point
                        min_x <= flaw_x[0];
                        max_x <= flaw_x[0];
                        min_y <= flaw_y[0];
                        max_y <= flaw_y[0];
                    end
                end

                CALCULATE_BBOX: begin
                    if (flaw_idx < 7) begin
                        flaw_idx <= flaw_idx + 1;
                        if (flaw_x[flaw_idx + 1] < min_x) min_x <= flaw_x[flaw_idx + 1];
                        if (flaw_x[flaw_idx + 1] > max_x) max_x <= flaw_x[flaw_idx + 1];
                        if (flaw_y[flaw_idx + 1] < min_y) min_y <= flaw_y[flaw_idx + 1];
                        if (flaw_y[flaw_idx + 1] > max_y) max_y <= flaw_y[flaw_idx + 1];
                    end else begin
                        state <= CALCULATE_CENTER;
                        flaw_idx <= 0;
                        // Center = (min + max) / 2. In fixed point, /2 is >> 1.
                        center_x <= (min_x + max_x) >>> 1;
                        center_y <= (min_y + max_y) >>> 1;
                        iter_count <= 0;
                    end
                end

                CALCULATE_CENTER: begin
                    // Start iteration loop
                    if (iter_count < 16) begin
                        state <= CHECK_SUPPORT;
                        flaw_idx <= 0;
                        max_dist_sq <= 0; // Reset max for this iteration
                    end else begin
                        state <= REFINE_RADIUS;
                        flaw_idx <= 0;
                    end
                end

                CHECK_SUPPORT: begin
                    // Find furthest point from current center using squared distance
                    if (flaw_idx < 8) begin
                        diff_x <= flaw_x[flaw_idx] - center_x;
                        diff_y <= flaw_y[flaw_idx] - center_y;
                        flaw_idx <= flaw_idx + 1;
                    end else begin
                        state <= CALCULATE_CENTER;
                        iter_count <= iter_count + 1;
                        center_x <= center_x + ((furthest_x - center_x) >>> 4);
                        center_y <= center_y + ((furthest_y - center_y) >>> 4);
                    end
                end

                REFINE_RADIUS: begin
                    // We need to find the maximum distance from the final center to ANY flaw.
                    if (flaw_idx < 8) begin
                        flaw_idx <= flaw_idx + 1;
                    end else begin
                        state <= DONE_STATE;
                        diameter <= 2 * (max_dist_sq >> 16);
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
        end
    end

    // Combinational Logic for Distance Calculation (Shared)
    always @(*) begin
        reg signed [31:0] dx, dy;
        reg signed [63:0] sx, sy;
        if (state == CHECK_SUPPORT || state == REFINE_RADIUS) begin
            dx = flaw_x[flaw_idx] - center_x;
            dy = flaw_y[flaw_idx] - center_y;
            sx = dx * dx;
            sy = dy * dy;
            temp_dist_sq = sx + sy;
        end else begin
            temp_dist_sq = 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_dist_sq <= 0;
            furthest_x <= 0;
            furthest_y <= 0;
        end else begin
            if (state == CHECK_SUPPORT) begin
                if (temp_dist_sq > max_dist_sq) begin
                    max_dist_sq <= temp_dist_sq;
                    furthest_x <= flaw_x[flaw_idx];
                    furthest_y <= flaw_y[flaw_idx];
                end
            end else if (state == REFINE_RADIUS) begin
                if (flaw_idx == 0) begin
                    max_dist_sq <= temp_dist_sq; // Initialize with first point
                end else begin
                    if (temp_dist_sq > max_dist_sq) begin
                        max_dist_sq <= temp_dist_sq;
                    end
                end
            end
        end
    end

endmodule