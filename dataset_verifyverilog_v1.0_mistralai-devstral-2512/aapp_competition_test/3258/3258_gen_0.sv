module CatVelocityCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] m,
    input wire signed [11:0] mouse_x [0:14],
    input wire signed [11:0] mouse_y [0:14],
    input wire [13:0] mouse_s [0:14],
    input wire [3:0] num_mice,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINALIZE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // DP state storage (using block RAM inference)
    reg [31:0] dp [0:32767]; // 2^15 states
    reg [31:0] dist [0:14]; // Distance from origin to each mouse
    reg [31:0] dist_matrix [0:14][0:14]; // Distance between mice

    // Current processing state
    reg [14:0] current_mask;
    reg [3:0] current_mouse;
    reg [3:0] next_mouse;
    reg [7:0] iteration_count;

    // Temporary computation registers
    reg signed [23:0] dx, dy;
    reg [31:0] distance_sq;
    reg [31:0] sqrt_input;
    reg [31:0] sqrt_result;
    reg [31:0] velocity_temp;
    reg [31:0] time_temp;
    reg [31:0] min_velocity;

    // Newton-Raphson sqrt approximation
    reg [31:0] x;
    reg [31:0] x_next;
    reg [5:0] sqrt_iter;

    // Cycle counter for timeout
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd100000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_mask <= 15'd0;
            current_mouse <= 4'd0;
            next_mouse <= 4'd0;
            iteration_count <= 8'd0;
            cycle_count <= 17'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;

            // Initialize DP and distance arrays
            integer i, j;
            for (i = 0; i < 32768; i = i + 1) begin
                dp[i] <= 32'd0;
            end
            for (i = 0; i < 15; i = i + 1) begin
                dist[i] <= 32'd0;
                for (j = 0; j < 15; j = j + 1) begin
                    dist_matrix[i][j] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 17'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= PRECOMPUTE;
                        current_mask <= 15'd0;
                        current_mouse <= 4'd0;
                        next_mouse <= 4'd0;
                        iteration_count <= 8'd0;
                        cycle_count <= 17'd0;
                    end
                end

                PRECOMPUTE: begin
                    // Compute distances from origin to each mouse
                    if (current_mouse < num_mice) begin
                        dx <= mouse_x[current_mouse];
                        dy <= mouse_y[current_mouse];
                        distance_sq <= (dx * dx) + (dy * dy);
                        sqrt_input <= distance_sq;
                        sqrt_iter <= 6'd0;
                        x <= 32'd1 << 15; // Initial guess
                        next_state <= PRECOMPUTE;
                    end else if (current_mouse == 4'd0) begin
                        // Start computing distance matrix
                        current_mouse <= 4'd0;
                        next_mouse <= 4'd1;
                        next_state <= PRECOMPUTE;
                    end else if (next_mouse < num_mice) begin
                        dx <= mouse_x[current_mouse] - mouse_x[next_mouse];
                        dy <= mouse_y[current_mouse] - mouse_y[next_mouse];
                        distance_sq <= (dx * dx) + (dy * dy);
                        sqrt_input <= distance_sq;
                        sqrt_iter <= 6'd0;
                        x <= 32'd1 << 15;
                        next_state <= PRECOMPUTE;
                    end else begin
                        // Move to DP initialization
                        current_mouse <= 4'd0;
                        next_mouse <= 4'd0;
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP for single mouse states
                    if (current_mouse < num_mice) begin
                        // Compute required velocity for this mouse
                        // v = dist / deadline
                        if (mouse_s[current_mouse] > 0) begin
                            velocity_temp <= (dist[current_mouse] << 8) / mouse_s[current_mouse];
                            dp[1 << current_mouse] <= velocity_temp;
                        end else begin
                            dp[1 << current_mouse] <= 32'd0;
                        end
                        current_mouse <= current_mouse + 4'd1;
                        next_state <= DP_INIT;
                    end else begin
                        // Move to DP computation
                        current_mask <= 15'd1;
                        current_mouse <= 4'd0;
                        next_mouse <= 4'd0;
                        iteration_count <= 8'd0;
                        next_state <= DP_COMPUTE;
                    end
                end

                DP_COMPUTE: begin
                    // DP computation: dp[mask][i] = min over j in mask of (dp[mask without i][j] * m^k)
                    // where distance(j,i) / (v_initial * m^k) <= deadline_i
                    if (current_mask < (1 << num_mice)) begin
                        if (current_mouse < num_mice) begin
                            if (next_mouse < num_mice) begin
                                // Check if next_mouse is in current_mask
                                if ((current_mask & (1 << next_mouse)) && (next_mouse != current_mouse)) begin
                                    // Compute required velocity
                                    // v_initial = (dist(j,i) / deadline_i) / m^k
                                    // where k = popcount(mask)
                                    integer k = $clog2(current_mask & ((1 << next_mouse) - 1)) + 1;
                                    reg [31:0] m_power = 32'd1;
                                    integer i;
                                    for (i = 0; i < k; i = i + 1) begin
                                        m_power <= (m_power * m) >> 8; // Q8.8 * Q8.8 = Q16.16, then >>8 to Q8.8
                                    end

                                    if (mouse_s[current_mouse] > 0) begin
                                        velocity_temp <= (dist_matrix[next_mouse][current_mouse] << 8) / mouse_s[current_mouse];
                                        if (m_power > 0) begin
                                            velocity_temp <= (velocity_temp << 8) / m_power; // Q16.16 / Q8.8 = Q8.8
                                        end
                                        if (dp[current_mask] == 32'd0 || velocity_temp < dp[current_mask]) begin
                                            dp[current_mask] <= velocity_temp;
                                        end
                                    end
                                    next_mouse <= next_mouse + 4'd1;
                                    next_state <= DP_COMPUTE;
                                end else begin
                                    next_mouse <= next_mouse + 4'd1;
                                    next_state <= DP_COMPUTE;
                                end
                            end else begin
                                current_mouse <= current_mouse + 4'd1;
                                next_mouse <= 4'd0;
                                next_state <= DP_COMPUTE;
                            end
                        end else begin
                            current_mask <= current_mask + 15'd1;
                            current_mouse <= 4'd0;
                            next_mouse <= 4'd0;
                            next_state <= DP_COMPUTE;
                        end
                    end else begin
                        // Move to finalize
                        current_mask <= 15'd0;
                        min_velocity <= 32'd0;
                        next_state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    // Find minimum velocity across all final states
                    if (current_mask < (1 << num_mice)) begin
                        if (dp[current_mask] > 0 && (min_velocity == 32'd0 || dp[current_mask] < min_velocity)) begin
                            min_velocity <= dp[current_mask];
                        end
                        current_mask <= current_mask + 15'd1;
                        next_state <= FINALIZE;
                    end else begin
                        result <= min_velocity;
                        done <= 1'b1;
                        valid <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Newton-Raphson sqrt approximation
    always @(posedge clk) begin
        if (sqrt_iter < 6'd5) begin
            if (x == 32'd0) begin
                x_next <= 32'd1;
            end else begin
                x_next <= (x + (sqrt_input / x)) >> 1;
            end
            x <= x_next;
            sqrt_iter <= sqrt_iter + 6'd1;
        end else if (sqrt_iter == 6'd5) begin
            sqrt_result <= x_next;
            sqrt_iter <= 6'd6;

            // Store result based on current computation phase
            if (state == PRECOMPUTE && current_mouse < num_mice && next_mouse == 4'd0) begin
                dist[current_mouse] <= sqrt_result;
            end else if (state == PRECOMPUTE && next_mouse < num_mice) begin
                dist_matrix[current_mouse][next_mouse] <= sqrt_result;
                dist_matrix[next_mouse][current_mouse] <= sqrt_result;
            end
        end
    end

    // Timeout check
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
        end
    end

endmodule