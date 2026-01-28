module min_total_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] citizen_count,
    input wire [127:0] citizen_x,
    input wire [127:0] citizen_y,
    input wire [15:0] max_dist,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_CITIZENS = 4'd1;
    localparam [3:0] BUILD_CANDIDATES_X = 4'd2;
    localparam [3:0] BUILD_CANDIDATES_Y = 4'd3;
    localparam [3:0] CHECK_COMBINATIONS = 4'd4;
    localparam [3:0] UPDATE_RESULT = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    reg [3:0] state, next_state;

    // Citizen data storage (up to 128 citizens)
    reg [15:0] x_coords [0:127];
    reg [15:0] y_coords [0:127];

    // Candidate coordinates (32 each)
    reg [15:0] candidate_x [0:31];
    reg [15:0] candidate_y [0:31];
    reg [4:0] num_candidates_x, num_candidates_y;

    // Current combination being checked
    reg [4:0] cx_idx, cy_idx;
    reg [15:0] current_cx, current_cy;

    // Distance calculation
    reg [15:0] citizen_idx;
    reg [15:0] dist_x, dist_y, total_dist;
    reg [31:0] current_total;
    reg [31:0] min_total;
    reg valid_combination;

    // Counters and flags
    reg [7:0] cycle_count;
    reg found_valid;

    // Load citizens state
    reg [7:0] load_idx;

    // Build candidates state
    reg [7:0] build_idx;
    reg [15:0] last_x, last_y;

    // Check combinations state
    reg all_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            load_idx <= 8'd0;
            build_idx <= 8'd0;
            cx_idx <= 5'd0;
            cy_idx <= 5'd0;
            citizen_idx <= 16'd0;
            current_total <= 32'd0;
            min_total <= 32'd0;
            num_candidates_x <= 5'd0;
            num_candidates_y <= 5'd0;
            found_valid <= 1'b0;
            valid_combination <= 1'b0;
            all_valid <= 1'b1;

            // Initialize arrays
            integer i;
            for (i = 0; i < 128; i = i + 1) begin
                x_coords[i] <= 16'd0;
                y_coords[i] <= 16'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                candidate_x[i] <= 16'd0;
                candidate_y[i] <= 16'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_CITIZENS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_CITIZENS: begin
                    if (load_idx < citizen_count) begin
                        // Extract x and y coordinates from packed arrays
                        x_coords[load_idx] <= citizen_x[(load_idx * 16) + 15 : load_idx * 16];
                        y_coords[load_idx] <= citizen_y[(load_idx * 16) + 15 : load_idx * 16];
                        load_idx <= load_idx + 8'd1;
                        next_state <= LOAD_CITIZENS;
                    end else begin
                        load_idx <= 8'd0;
                        next_state <= BUILD_CANDIDATES_X;
                    end
                end

                BUILD_CANDIDATES_X: begin
                    if (build_idx < 128 && num_candidates_x < 32) begin
                        if (build_idx < citizen_count) begin
                            if (num_candidates_x == 0 || x_coords[build_idx] != last_x) begin
                                candidate_x[num_candidates_x] <= x_coords[build_idx];
                                last_x <= x_coords[build_idx];
                                num_candidates_x <= num_candidates_x + 5'd1;
                            end
                        end
                        build_idx <= build_idx + 8'd1;
                        next_state <= BUILD_CANDIDATES_X;
                    end else begin
                        build_idx <= 8'd0;
                        last_x <= 16'd0;
                        next_state <= BUILD_CANDIDATES_Y;
                    end
                end

                BUILD_CANDIDATES_Y: begin
                    if (build_idx < 128 && num_candidates_y < 32) begin
                        if (build_idx < citizen_count) begin
                            if (num_candidates_y == 0 || y_coords[build_idx] != last_y) begin
                                candidate_y[num_candidates_y] <= y_coords[build_idx];
                                last_y <= y_coords[build_idx];
                                num_candidates_y <= num_candidates_y + 5'd1;
                            end
                        end
                        build_idx <= build_idx + 8'd1;
                        next_state <= BUILD_CANDIDATES_Y;
                    end else begin
                        build_idx <= 8'd0;
                        last_y <= 16'd0;
                        cx_idx <= 5'd0;
                        cy_idx <= 5'd0;
                        min_total <= 32'd0;
                        found_valid <= 1'b0;
                        next_state <= CHECK_COMBINATIONS;
                    end
                end

                CHECK_COMBINATIONS: begin
                    if (cx_idx < num_candidates_x) begin
                        if (cy_idx < num_candidates_y) begin
                            current_cx <= candidate_x[cx_idx];
                            current_cy <= candidate_y[cy_idx];
                            citizen_idx <= 16'd0;
                            current_total <= 32'd0;
                            all_valid <= 1'b1;
                            next_state <= CHECK_COMBINATIONS;
                        end else begin
                            cy_idx <= 5'd0;
                            cx_idx <= cx_idx + 5'd1;
                            next_state <= CHECK_COMBINATIONS;
                        end
                    end else begin
                        if (found_valid) begin
                            next_state <= UPDATE_RESULT;
                        end else begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                UPDATE_RESULT: begin
                    result <= min_total;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (found_valid) begin
                        impossible <= 1'b0;
                    end else begin
                        impossible <= 1'b1;
                        result <= 32'd0;
                    end
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (cycle_count < 8'd200) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
                next_state <= IDLE;
            end
        end
    end

    // Combinational logic for distance checking
    always @(*) begin
        if (state == CHECK_COMBINATIONS && citizen_idx < citizen_count) begin
            // Calculate Manhattan distance for current citizen
            if (current_cx >= x_coords[citizen_idx]) begin
                dist_x <= current_cx - x_coords[citizen_idx];
            end else begin
                dist_x <= x_coords[citizen_idx] - current_cx;
            end

            if (current_cy >= y_coords[citizen_idx]) begin
                dist_y <= current_cy - y_coords[citizen_idx];
            end else begin
                dist_y <= y_coords[citizen_idx] - current_cy;
            end

            // Check if distance exceeds max_dist
            if (dist_x + dist_y > max_dist) begin
                all_valid = 1'b0;
            end

            // Accumulate total distance
            current_total = current_total + (dist_x + dist_y);
        end
    end

    // State transition logic for checking citizens
    always @(posedge clk) begin
        if (state == CHECK_COMBINATIONS) begin
            if (citizen_idx < citizen_count) begin
                citizen_idx <= citizen_idx + 16'd1;
            end else begin
                if (all_valid) begin
                    valid_combination = 1'b1;
                    if (!found_valid || current_total < min_total) begin
                        min_total <= current_total;
                        found_valid <= 1'b1;
                    end
                end
                cy_idx <= cy_idx + 5'd1;
                citizen_idx <= 16'd0;
            end
        end
    end

endmodule