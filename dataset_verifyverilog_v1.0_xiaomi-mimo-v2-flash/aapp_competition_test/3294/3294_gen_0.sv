module poly_distance_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] polygon_cnt,
    input wire signed [15:0] vertex_x [0:3][0:3],
    input wire signed [15:0] vertex_y [0:3][0:3],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] START_POLYGON = 4'd1;
    localparam [3:0] START_EDGE    = 4'd2;
    localparam [3:0] COMPUTE_VECT  = 4'd3;
    localparam [3:0] COMPUTE_DOT1  = 4'd4;
    localparam [3:0] COMPUTE_DOT2  = 4'd5;
    localparam [3:0] COMPUTE_T     = 4'd6;
    localparam [3:0] CLAMP_T       = 4'd7;
    localparam [3:0] COMPUTE_PX    = 4'd8;
    localparam [3:0] COMPUTE_PY    = 4'd9;
    localparam [3:0] COMPUTE_DIST2 = 4'd10;
    localparam [3:0] UPDATE_MIN    = 4'd11;
    localparam [3:0] NEXT_EDGE     = 4'd12;
    localparam [3:0] NEXT_POLYGON  = 4'd13;
    localparam [3:0] FINISH        = 4'd14;
    localparam [3:0] DONE_STATE    = 4'd15;

    reg [3:0] state;
    reg [3:0] next_state;

    // Registers for polygon and vertex indices
    reg [1:0] poly_idx;          // 0 to 3 (max 4 polygons)
    reg [1:0] vertex_idx;        // 0 to 3 (max 4 vertices per polygon)

    // Registers for intermediate calculations
    reg signed [15:0] A_x;
    reg signed [15:0] A_y;
    reg signed [15:0] B_x;
    reg signed [15:0] B_y;
    reg signed [15:0] vec_x;     // B - A
    reg signed [15:0] vec_y;     // B - A
    reg signed [31:0] dot_AA;    // vec . vec (Q16.16)
    reg signed [31:0] dot_AO;    // -A . vec (Q16.16) - origin to line
    reg signed [31:0] t_raw;     // t = -A . vec / (vec . vec) (Q16.16)
    reg signed [31:0] t_clamped; // clamped t in [0, 1] (Q16.16)
    reg signed [31:0] Px;        // closest point X (Q16.16)
    reg signed [31:0] Py;        // closest point Y (Q16.16)
    reg signed [63:0] dist2_temp;// Px^2 + Py^2 (Q32.32)
    reg signed [31:0] dist2;     // dist^2 (Q16.16)

    // Minimum distance tracking
    reg signed [31:0] min_dist2;
    reg min_valid;

    // Control signals
    reg [2:0] cycle_count;       // For timing

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_count <= 3'd0;
        else if (state != next_state)
            cycle_count <= 3'd0;
        else
            cycle_count <= cycle_count + 3'd1;
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        // Default next state
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    if (polygon_cnt == 4'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = START_POLYGON;
                    end
                end
            end

            START_POLYGON: begin
                next_state = START_EDGE;
            end

            START_EDGE: begin
                next_state = COMPUTE_VECT;
            end

            COMPUTE_VECT: begin
                next_state = COMPUTE_DOT1;
            end

            COMPUTE_DOT1: begin
                next_state = COMPUTE_DOT2;
            end

            COMPUTE_DOT2: begin
                if (dot_AA == 32'd0) begin
                    // Degenerate edge (A == B), skip
                    next_state = NEXT_EDGE;
                end else begin
                    next_state = COMPUTE_T;
                end
            end

            COMPUTE_T: begin
                next_state = CLAMP_T;
            end

            CLAMP_T: begin
                next_state = COMPUTE_PX;
            end

            COMPUTE_PX: begin
                next_state = COMPUTE_PY;
            end

            COMPUTE_PY: begin
                next_state = COMPUTE_DIST2;
            end

            COMPUTE_DIST2: begin
                next_state = UPDATE_MIN;
            end

            UPDATE_MIN: begin
                next_state = NEXT_EDGE;
            end

            NEXT_EDGE: begin
                if (vertex_idx == 2'd3) begin
                    next_state = NEXT_POLYGON;
                end else begin
                    next_state = START_EDGE;
                end
            end

            NEXT_POLYGON: begin
                if (poly_idx == (polygon_cnt - 4'd1)) begin
                    next_state = FINISH;
                end else begin
                    next_state = START_POLYGON;
                end
            end

            FINISH: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Control and datapath operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            poly_idx <= 2'd0;
            vertex_idx <= 2'd0;
            A_x <= 16'sd0;
            A_y <= 16'sd0;
            B_x <= 16'sd0;
            B_y <= 16'sd0;
            vec_x <= 16'sd0;
            vec_y <= 16'sd0;
            dot_AA <= 32'sd0;
            dot_AO <= 32'sd0;
            t_raw <= 32'sd0;
            t_clamped <= 32'sd0;
            Px <= 32'sd0;
            Py <= 32'sd0;
            dist2_temp <= 64'sd0;
            dist2 <= 32'sd0;
            min_dist2 <= 32'sd0;
            min_valid <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0; // Default: done is 0 unless in DONE_STATE

            case (state)
                IDLE: begin
                    if (start) begin
                        min_valid <= 1'b0;
                        if (polygon_cnt == 4'd0) begin
                            result <= 32'd0;
                        end
                    end
                end

                START_POLYGON: begin
                    // Initialize for new polygon
                    vertex_idx <= 2'd0;
                end

                START_EDGE: begin
                    // Load vertex A
                    A_x <= vertex_x[poly_idx][vertex_idx];
                    A_y <= vertex_y[poly_idx][vertex_idx];
                    // Load vertex B (next vertex, wrap to 0 if at end)
                    if (vertex_idx == 2'd3) begin
                        B_x <= vertex_x[poly_idx][2'd0];
                        B_y <= vertex_y[poly_idx][2'd0];
                    end else begin
                        B_x <= vertex_x[poly_idx][vertex_idx + 2'd1];
                        B_y <= vertex_y[poly_idx][vertex_idx + 2'd1];
                    end
                end

                COMPUTE_VECT: begin
                    // vec = B - A
                    vec_x <= B_x - A_x;
                    vec_y <= B_y - A_y;
                end

                COMPUTE_DOT1: begin
                    // dot_AA = vec . vec (Q16.16) = (raw*raw) >> 8
                    // raw is 16-bit, product is 32-bit
                    // Shifting right by 8 to convert Q8.8 * Q8.8 -> Q16.16
                    dot_AA <= (vec_x * vec_x + vec_y * vec_y) >>> 8;
                end

                COMPUTE_DOT2: begin
                    // dot_AO = -A . vec (Q16.16)
                    // -A . vec = -(Ax*vx + Ay*vy) = -Ax*vx - Ay*vy
                    // Shifting right by 8
                    dot_AO <= ((-A_x * vec_x) + (-A_y * vec_y)) >>> 8;
                end

                COMPUTE_T: begin
                    // t = dot_AO / dot_AA
                    // Q16.16 / Q16.16 = Q16.16 result
                    if (dot_AA != 32'sd0) begin
                        // Multiply by 65536 (1<<16) to maintain precision
                        t_raw <= (dot_AO * 32'sd65536) / dot_AA;
                    end
                end

                CLAMP_T: begin
                    // Clamp t to [0, 1] in Q16.16
                    if (t_raw < 32'sd0) begin
                        t_clamped <= 32'sd0;
                    end else if (t_raw > 32'sd65536) begin
                        t_clamped <= 32'sd65536;
                    end else begin
                        t_clamped <= t_raw;
                    end
                end

                COMPUTE_PX: begin
                    // Px = Ax + t * vec_x (all Q8.8 for A/vec, t is Q16.16)
                    // Px (Q16.16) = Ax*65536 + vec_x * t
                    Px <= (A_x <<< 16) + (vec_x * t_clamped);
                end

                COMPUTE_PY: begin
                    Py <= (A_y <<< 16) + (vec_y * t_clamped);
                end

                COMPUTE_DIST2: begin
                    // dist2 = Px^2 + Py^2 (Q16.16)
                    // Px is Q16.16, so Px^2 is Q32.32
                    // We want Q16.16 result, so shift right by 16
                    dist2_temp <= (Px * Px) + (Py * Py);
                    dist2 <= (Px * Px + Py * Py) >>> 16;
                end

                UPDATE_MIN: begin
                    if (!min_valid || (dist2 < min_dist2)) begin
                        min_dist2 <= dist2;
                        min_valid <= 1'b1;
                    end
                end

                NEXT_EDGE: begin
                    // Increment vertex index
                    vertex_idx <= vertex_idx + 2'd1;
                end

                NEXT_POLYGON: begin
                    // Increment polygon index
                    poly_idx <= poly_idx + 2'd1;
                end

                FINISH: begin
                    // Set result
                    if (min_valid) begin
                        result <= min_dist2;
                    end else begin
                        result <= 32'd0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Reset indices for next operation
                    poly_idx <= 2'd0;
                    vertex_idx <= 2'd0;
                end
            endcase
        end
    end

endmodule