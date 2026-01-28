module manhattan_distance_estimator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] vertex_count,
    input wire signed [15:0] vertex_x [0:15],
    input wire signed [15:0] vertex_y [0:15],
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE_POINTS = 3'd1;
    localparam [2:0] CHECK_INSIDE = 3'd2;
    localparam [2:0] ACCUMULATE = 3'd3;
    localparam [2:0] DIVIDE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Constants
    localparam [9:0] N_SAMPLES = 10'd1024;
    localparam [15:0] RAY_X = 16'd10000;

    // Registers
    reg [2:0] state, next_state;
    reg [9:0] sample_counter;
    reg [15:0] lfsr_x, lfsr_y;
    reg signed [15:0] current_x, current_y;
    reg signed [15:0] prev_x, prev_y;
    reg [47:0] accumulator;
    reg inside_current, inside_prev;
    reg [19:0] cycle_count;
    localparam [19:0] MAX_CYCLES = 20'd999999;

    // LFSR for random number generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_x <= 16'd1;
            lfsr_y <= 16'd1;
        end else if (state == GENERATE_POINTS) begin
            // 16-bit LFSR with polynomial x^16 + x^14 + x^13 + x^11 + 1
            lfsr_x <= {lfsr_x[13], lfsr_x[12], lfsr_x[10], lfsr_x[0]} ^ (lfsr_x[15] ^ lfsr_x[14] ^ lfsr_x[13] ^ lfsr_x[11]);
            lfsr_y <= {lfsr_y[13], lfsr_y[12], lfsr_y[10], lfsr_y[0]} ^ (lfsr_y[15] ^ lfsr_y[14] ^ lfsr_y[13] ^ lfsr_y[11]);
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sample_counter <= 10'd0;
            accumulator <= 48'd0;
            inside_current <= 1'b0;
            inside_prev <= 1'b0;
            current_x <= 16'd0;
            current_y <= 16'd0;
            prev_x <= 16'd0;
            prev_y <= 16'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 20'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_POINTS;
                end
            end
            GENERATE_POINTS: begin
                next_state = CHECK_INSIDE;
            end
            CHECK_INSIDE: begin
                if (inside_current) begin
                    next_state = ACCUMULATE;
                end else begin
                    next_state = GENERATE_POINTS;
                end
            end
            ACCUMULATE: begin
                if (sample_counter == N_SAMPLES - 1) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = GENERATE_POINTS;
                end
            end
            DIVIDE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sample counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 10'd0;
        end else if (state == ACCUMULATE && inside_current) begin
            sample_counter <= sample_counter + 10'd1;
        end
    end

    // Cycle counter (safety)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 20'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            cycle_count <= cycle_count + 20'd1;
        end
    end

    // Generate current point from LFSR
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_x <= 16'd0;
            current_y <= 16'd0;
        end else if (state == GENERATE_POINTS) begin
            current_x <= $signed(lfsr_x);
            current_y <= $signed(lfsr_y);
        end
    end

    // Point-in-polygon check using ray casting
    always @(*) begin
        integer i;
        reg [15:0] x_intersect;
        reg inside_flag = 1'b0;
        reg edge_flag = 1'b0;

        if (vertex_count == 0) begin
            inside_flag = 1'b0;
        end else begin
            for (i = 0; i < vertex_count; i = i + 1) begin
                reg [15:0] x1 = vertex_x[i];
                reg [15:0] y1 = vertex_y[i];
                reg [15:0] x2 = vertex_x[(i + 1) % vertex_count];
                reg [15:0] y2 = vertex_y[(i + 1) % vertex_count];

                // Check if point is on vertex
                if ((current_x == x1) && (current_y == y1)) begin
                    edge_flag = 1'b1;
                    inside_flag = 1'b1;
                end

                // Check if point is on edge
                if ((current_y == y1) && (current_y == y2) && 
                    ((current_x >= x1 && current_x <= x2) || (current_x >= x2 && current_x <= x1))) begin
                    edge_flag = 1'b1;
                    inside_flag = 1'b1;
                end

                // Ray casting intersection check
                if ((y1 > current_y) != (y2 > current_y)) begin
                    // Compute intersection
                    if (x1 != x2) begin
                        x_intersect = x1 + (current_y - y1) * (x2 - x1) / (y2 - y1);
                    end else begin
                        x_intersect = x1;
                    end

                    if (current_x <= x_intersect) begin
                        inside_flag = ~inside_flag;
                    end
                end
            end
        end

        inside_current = inside_flag || edge_flag;
    end

    // Accumulate Manhattan distance
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 48'd0;
            prev_x <= 16'd0;
            prev_y <= 16'd0;
            inside_prev <= 1'b0;
        end else if (state == ACCUMULATE && inside_current && inside_prev) begin
            // Compute Manhattan distance: |current_x - prev_x| + |current_y - prev_y|
            reg signed [15:0] dx = current_x - prev_x;
            reg signed [15:0] dy = current_y - prev_y;
            reg signed [16:0] abs_dx = (dx[15] ? -dx : dx);
            reg signed [16:0] abs_dy = (dy[15] ? -dy : dy);
            reg signed [17:0] distance = abs_dx + abs_dy;

            accumulator <= accumulator + {31'd0, distance[17:0]};

            // Update previous point
            prev_x <= current_x;
            prev_y <= current_y;
            inside_prev <= inside_current;
        end else if (state == GENERATE_POINTS && inside_current) begin
            // First valid point
            prev_x <= current_x;
            prev_y <= current_y;
            inside_prev <= inside_current;
        end
    end

    // Final division
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
        end else if (state == DIVIDE) begin
            // Divide by 1024 (right shift by 10)
            result <= accumulator[47:16];
            done <= 1'b1;
        end else if (state == DONE_STATE) begin
            done <= 1'b0;
        end
    end

    // Safety: Force done if max cycles reached
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
            state <= DONE_STATE;
            done <= 1'b1;
        end
    end

endmodule