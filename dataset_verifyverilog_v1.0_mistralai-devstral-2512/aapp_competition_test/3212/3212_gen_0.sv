module SnakePathFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] snake_x [0:15],
    input wire [11:0] snake_y [0:15],
    input wire [11:0] snake_d [0:15],
    input wire [3:0] snake_count,
    output reg done,
    output reg success,
    output reg [11:0] entry_y,
    output reg [11:0] exit_y
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE = 3'd1;
    localparam [2:0] CHECK_SNAKES = 3'd2;
    localparam [2:0] UPDATE_SEARCH = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Registered inputs
    reg [11:0] snake_x_reg [0:15];
    reg [11:0] snake_y_reg [0:15];
    reg [11:0] snake_d_reg [0:15];
    reg [3:0] snake_count_reg;

    // Search variables
    reg [11:0] low_y, high_y, mid_y;
    reg [11:0] current_entry_y, current_exit_y;
    reg [11:0] best_entry_y, best_exit_y;
    reg found_valid_path;

    // Snake check variables
    reg [4:0] snake_index;
    reg snake_blocks;

    // Iteration counter
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd12;

    // Fixed-point scaling factor (Q8.4)
    localparam [15:0] SCALE_FACTOR = 16'd16;

    // Register initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            success <= 1'b0;
            entry_y <= 12'd0;
            exit_y <= 12'd0;

            // Initialize all registered inputs
            for (integer i = 0; i < 16; i = i + 1) begin
                snake_x_reg[i] <= 12'd0;
                snake_y_reg[i] <= 12'd0;
                snake_d_reg[i] <= 12'd0;
            end
            snake_count_reg <= 4'd0;

            // Initialize search variables
            low_y <= 12'd0;
            high_y <= 12'd1000;
            mid_y <= 12'd0;
            current_entry_y <= 12'd0;
            current_exit_y <= 12'd0;
            best_entry_y <= 12'd0;
            best_exit_y <= 12'd0;
            found_valid_path <= 1'b0;

            // Initialize snake check variables
            snake_index <= 5'd0;
            snake_blocks <= 1'b0;

            // Initialize iteration counter
            iteration_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Input registration on start
    always @(posedge clk) begin
        if (start) begin
            for (integer i = 0; i < 16; i = i + 1) begin
                snake_x_reg[i] <= snake_x[i];
                snake_y_reg[i] <= snake_y[i];
                snake_d_reg[i] <= snake_d[i];
            end
            snake_count_reg <= snake_count;
        end
    end

    // Main FSM logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize search
                    low_y = 12'd0;
                    high_y = 12'd1000;
                    found_valid_path = 1'b0;
                    iteration_count = 4'd0;
                    next_state = CALCULATE;
                end
            end

            CALCULATE: begin
                // Binary search midpoint
                mid_y = (low_y + high_y) >> 1;
                current_entry_y = mid_y;
                current_exit_y = mid_y;  // Start with same y
                snake_index = 5'd0;
                snake_blocks = 1'b0;
                next_state = CHECK_SNAKES;
            end

            CHECK_SNAKES: begin
                if (snake_index < snake_count_reg) begin
                    // Check if current snake blocks the path
                    reg [15:0] dx, dy, distance_sq, radius_sq;
                    reg [15:0] line_y_at_x, vertical_dist_sq;

                    // Calculate line equation: y = m*x + b
                    // m = (exit_y - entry_y) / 1000
                    // For fixed point: m_scaled = (exit_y - entry_y) * SCALE_FACTOR / 1000
                    reg [15:0] m_scaled = ((current_exit_y - current_entry_y) * SCALE_FACTOR) / 12'd1000;

                    // Calculate y at snake_x
                    line_y_at_x = (m_scaled * snake_x_reg[snake_index]) / SCALE_FACTOR + current_entry_y;

                    // Calculate vertical distance squared
                    dy = line_y_at_x - snake_y_reg[snake_index];
                    vertical_dist_sq = dy * dy;

                    // Calculate radius squared (snake_d is diameter, so radius = d/2)
                    radius_sq = (snake_d_reg[snake_index] / 2) * (snake_d_reg[snake_index] / 2);

                    // Check if vertical distance is less than radius
                    if (vertical_dist_sq < radius_sq) begin
                        snake_blocks = 1'b1;
                    end

                    snake_index = snake_index + 5'd1;
                end else begin
                    if (!snake_blocks) begin
                        // Path is valid, update best path
                        found_valid_path = 1'b1;
                        best_entry_y = current_entry_y;
                        best_exit_y = current_exit_y;
                        // Try higher y
                        low_y = mid_y;
                    end else begin
                        // Try lower y
                        high_y = mid_y;
                    end

                    iteration_count = iteration_count + 4'd1;
                    if (iteration_count >= MAX_ITERATIONS || (high_y - low_y) < 12'd1) begin
                        if (found_valid_path) begin
                            success = 1'b1;
                            entry_y = best_entry_y;
                            exit_y = best_exit_y;
                        end else begin
                            success = 1'b0;
                        end
                        next_state = DONE_STATE;
                    end else begin
                        next_state = CALCULATE;
                    end
                end
            end

            UPDATE_SEARCH: begin
                // This state is not used in this simplified version
                next_state = CALCULATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule