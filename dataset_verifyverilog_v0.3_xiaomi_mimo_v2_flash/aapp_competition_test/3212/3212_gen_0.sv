module buffalo_bill_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] num_snakes,
    input wire [9:0] snake_x0,
    input wire [9:0] snake_y0,
    input wire [9:0] snake_d0,
    input wire [9:0] snake_x1,
    input wire [9:0] snake_y1,
    input wire [9:0] snake_d1,
    input wire [9:0] snake_x2,
    input wire [9:0] snake_y2,
    input wire [9:0] snake_d2,
    input wire [9:0] snake_x3,
    input wire [9:0] snake_y3,
    input wire [9:0] snake_d3,
    output reg path_found,
    output reg [6:0] entry_y_step,
    output reg [6:0] exit_y_step,
    output reg done
);

// Parameters
localparam [9:0] STEP = 10'd10;
localparam [6:0] MAX_Y_STEP = 7'd100;
localparam [9:0] FIELD_SIZE = 10'd1000;

// Internal registers
reg [2:0] state;
reg [9:0] snake_x_reg_0;
reg [9:0] snake_y_reg_0;
reg [9:0] snake_d_reg_0;
reg [9:0] snake_x_reg_1;
reg [9:0] snake_y_reg_1;
reg [9:0] snake_d_reg_1;
reg [9:0] snake_x_reg_2;
reg [9:0] snake_y_reg_2;
reg [9:0] snake_d_reg_2;
reg [9:0] snake_x_reg_3;
reg [9:0] snake_y_reg_3;
reg [9:0] snake_d_reg_3;
reg [2:0] num_snakes_reg;
reg [6:0] y_step;
reg found_entry;
reg found_exit;
reg path_found_reg;
reg [6:0] entry_y_step_reg;
reg [6:0] exit_y_step_reg;
reg done_reg;

// Barrier computation registers and flags
reg [1:0] parent_0;
reg [1:0] parent_1;
reg [1:0] parent_2;
reg [1:0] parent_3;
reg touch_top_0;
reg touch_top_1;
reg touch_top_2;
reg touch_top_3;
reg touch_bottom_0;
reg touch_bottom_1;
reg touch_bottom_2;
reg touch_bottom_3;
reg barrier_detected;
reg [2:0] loop_i;
reg [2:0] loop_j;
reg [2:0] current_root;
reg [31:0] dx_val;
reg [31:0] dy_val;
reg [31:0] dx2_val;
reg [31:0] dy2_val;
reg [31:0] dist_sq_val;
reg [31:0] rad_sum_sq_val;
reg [31:0] rad_sq_val;
reg [16:0] py_val;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] BARRIER_INIT = 3'd1;
localparam [2:0] BARRIER_PAIR = 3'd2;
localparam [2:0] BARRIER_CHECK = 3'd3;
localparam [2:0] LEFT_START = 3'd4;
localparam [2:0] LEFT_LOOP = 3'd5;
localparam [2:0] RIGHT_START = 3'd6;
localparam [2:0] RIGHT_LOOP = 3'd7;
localparam [2:0] DONE_STATE = 3'd8;

// Combinational safety check logic (decoded for synthesis)
reg safe_left_comb;
reg safe_right_comb;

always @(*) begin
    py_val = y_step * STEP;
    
    // Check left side (x=0)
    safe_left_comb = 1'b1;
    if (num_snakes_reg > 3'd0) begin
        dx_val = (10'd0 > snake_x_reg_0) ? (10'd0 - snake_x_reg_0) : (snake_x_reg_0 - 10'd0);
        dy_val = (py_val > snake_y_reg_0) ? (py_val - snake_y_reg_0) : (snake_y_reg_0 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_0 * snake_d_reg_0;
        if (dist_sq_val < rad_sq_val) safe_left_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd1 && safe_left_comb) begin
        dx_val = (10'd0 > snake_x_reg_1) ? (10'd0 - snake_x_reg_1) : (snake_x_reg_1 - 10'd0);
        dy_val = (py_val > snake_y_reg_1) ? (py_val - snake_y_reg_1) : (snake_y_reg_1 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_1 * snake_d_reg_1;
        if (dist_sq_val < rad_sq_val) safe_left_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd2 && safe_left_comb) begin
        dx_val = (10'd0 > snake_x_reg_2) ? (10'd0 - snake_x_reg_2) : (snake_x_reg_2 - 10'd0);
        dy_val = (py_val > snake_y_reg_2) ? (py_val - snake_y_reg_2) : (snake_y_reg_2 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_2 * snake_d_reg_2;
        if (dist_sq_val < rad_sq_val) safe_left_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd3 && safe_left_comb) begin
        dx_val = (10'd0 > snake_x_reg_3) ? (10'd0 - snake_x_reg_3) : (snake_x_reg_3 - 10'd0);
        dy_val = (py_val > snake_y_reg_3) ? (py_val - snake_y_reg_3) : (snake_y_reg_3 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_3 * snake_d_reg_3;
        if (dist_sq_val < rad_sq_val) safe_left_comb = 1'b0;
    end
    
    // Check right side (x=1000)
    safe_right_comb = 1'b1;
    if (num_snakes_reg > 3'd0) begin
        dx_val = (10'd1000 > snake_x_reg_0) ? (10'd1000 - snake_x_reg_0) : (snake_x_reg_0 - 10'd1000);
        dy_val = (py_val > snake_y_reg_0) ? (py_val - snake_y_reg_0) : (snake_y_reg_0 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_0 * snake_d_reg_0;
        if (dist_sq_val < rad_sq_val) safe_right_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd1 && safe_right_comb) begin
        dx_val = (10'd1000 > snake_x_reg_1) ? (10'd1000 - snake_x_reg_1) : (snake_x_reg_1 - 10'd1000);
        dy_val = (py_val > snake_y_reg_1) ? (py_val - snake_y_reg_1) : (snake_y_reg_1 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_1 * snake_d_reg_1;
        if (dist_sq_val < rad_sq_val) safe_right_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd2 && safe_right_comb) begin
        dx_val = (10'd1000 > snake_x_reg_2) ? (10'd1000 - snake_x_reg_2) : (snake_x_reg_2 - 10'd1000);
        dy_val = (py_val > snake_y_reg_2) ? (py_val - snake_y_reg_2) : (snake_y_reg_2 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_2 * snake_d_reg_2;
        if (dist_sq_val < rad_sq_val) safe_right_comb = 1'b0;
    end
    if (num_snakes_reg > 3'd3 && safe_right_comb) begin
        dx_val = (10'd1000 > snake_x_reg_3) ? (10'd1000 - snake_x_reg_3) : (snake_x_reg_3 - 10'd1000);
        dy_val = (py_val > snake_y_reg_3) ? (py_val - snake_y_reg_3) : (snake_y_reg_3 - py_val);
        dx2_val = dx_val * dx_val;
        dy2_val = dy_val * dy_val;
        dist_sq_val = dx2_val + dy2_val;
        rad_sq_val = snake_d_reg_3 * snake_d_reg_3;
        if (dist_sq_val < rad_sq_val) safe_right_comb = 1'b0;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        path_found_reg <= 1'b0;
        entry_y_step_reg <= 7'd0;
        exit_y_step_reg <= 7'd0;
        done_reg <= 1'b0;
        y_step <= 7'd0;
        found_entry <= 1'b0;
        found_exit <= 1'b0;
        loop_i <= 3'd0;
        loop_j <= 3'd0;
        barrier_detected <= 1'b0;
        parent_0 <= 2'd0;
        parent_1 <= 2'd1;
        parent_2 <= 2'd2;
        parent_3 <= 2'd3;
        touch_top_0 <= 1'b0;
        touch_top_1 <= 1'b0;
        touch_top_2 <= 1'b0;
        touch_top_3 <= 1'b0;
        touch_bottom_0 <= 1'b0;
        touch_bottom_1 <= 1'b0;
        touch_bottom_2 <= 1'b0;
        touch_bottom_3 <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done_reg <= 1'b0;
                if (start) begin
                    snake_x_reg_0 <= snake_x0;
                    snake_y_reg_0 <= snake_y0;
                    snake_d_reg_0 <= snake_d0;
                    snake_x_reg_1 <= snake_x1;
                    snake_y_reg_1 <= snake_y1;
                    snake_d_reg_1 <= snake_d1;
                    snake_x_reg_2 <= snake_x2;
                    snake_y_reg_2 <= snake_y2;
                    snake_d_reg_2 <= snake_d2;
                    snake_x_reg_3 <= snake_x3;
                    snake_y_reg_3 <= snake_y3;
                    snake_d_reg_3 <= snake_d3;
                    num_snakes_reg <= num_snakes;
                    state <= BARRIER_INIT;
                    loop_i <= 3'd0;
                end
            end

            BARRIER_INIT: begin
                // Initialize parents and touch flags
                case (loop_i)
                    3'd0: begin
                        parent_0 <= 2'd0;
                        touch_top_0 <= (snake_y_reg_0 + snake_d_reg_0 > FIELD_SIZE);
                        touch_bottom_0 <= (snake_y_reg_0 < snake_d_reg_0);
                    end
                    3'd1: begin
                        parent_1 <= 2'd1;
                        touch_top_1 <= (snake_y_reg_1 + snake_d_reg_1 > FIELD_SIZE);
                        touch_bottom_1 <= (snake_y_reg_1 < snake_d_reg_1);
                    end
                    3'd2: begin
                        parent_2 <= 2'd2;
                        touch_top_2 <= (snake_y_reg_2 + snake_d_reg_2 > FIELD_SIZE);
                        touch_bottom_2 <= (snake_y_reg_2 < snake_d_reg_2);
                    end
                    3'd3: begin
                        parent_3 <= 2'd3;
                        touch_top_3 <= (snake_y_reg_3 + snake_d_reg_3 > FIELD_SIZE);
                        touch_bottom_3 <= (snake_y_reg_3 < snake_d_reg_3);
                    end
                endcase
                
                if (loop_i < 3'd3) begin
                    loop_i <= loop_i + 3'd1;
                end else begin
                    loop_i <= 3'd0;
                    loop_j <= 3'd1;
                    state <= BARRIER_PAIR;
                    barrier_detected <= 1'b0;
                end
            end

            BARRIER_PAIR: begin
                // Check pairwise intersections
                if (loop_i < num_snakes_reg && loop_j < num_snakes_reg) begin
                    // Get X distance
                    if (loop_i == 3'd0) begin
                        if (loop_j == 3'd1) begin
                            dx_val = (snake_x_reg_0 > snake_x_reg_1) ? (snake_x_reg_0 - snake_x_reg_1) : (snake_x_reg_1 - snake_x_reg_0);
                            dy_val = (snake_y_reg_0 > snake_y_reg_1) ? (snake_y_reg_0 - snake_y_reg_1) : (snake_y_reg_1 - snake_y_reg_0);
                        end else if (loop_j == 3'd2) begin
                            dx_val = (snake_x_reg_0 > snake_x_reg_2) ? (snake_x_reg_0 - snake_x_reg_2) : (snake_x_reg_2 - snake_x_reg_0);
                            dy_val = (snake_y_reg_0 > snake_y_reg_2) ? (snake_y_reg_0 - snake_y_reg_2) : (snake_y_reg_2 - snake_y_reg_0);
                        end else begin // loop_j == 3'd3
                            dx_val = (snake_x_reg_0 > snake_x_reg_3) ? (snake_x_reg_0 - snake_x_reg_3) : (snake_x_reg_3 - snake_x_reg_0);
                            dy_val = (snake_y_reg_0 > snake_y_reg_3) ? (snake_y_reg_0 - snake_y_reg_3) : (snake_y_reg_3 - snake_y_reg_0);
                        end
                    end else if (loop_i == 3'd1) begin
                        if (loop_j == 3'd2) begin
                            dx_val = (snake_x_reg_1 > snake_x_reg_2) ? (snake_x_reg_1 - snake_x_reg_2) : (snake_x_reg_2 - snake_x_reg_1);
                            dy_val = (snake_y_reg_1 > snake_y_reg_2) ? (snake_y_reg_1 - snake_y_reg_2) : (snake_y_reg_2 - snake_y_reg_1);
                        end else begin // loop_j == 3'd3
                            dx_val = (snake_x_reg_1 > snake_x_reg_3) ? (snake_x_reg_1 - snake_x_reg_3) : (snake_x_reg_3 - snake_x_reg_1);
                            dy_val = (snake_y_reg_1 > snake_y_reg_3) ? (snake_y_reg_1 - snake_y_reg_3) : (snake_y_reg_3 - snake_y_reg_1);
                        end
                    end else begin // loop_i == 3'd2
                        dx_val = (snake_x_reg_2 > snake_x_reg_3) ? (snake_x_reg_2 - snake_x_reg_3) : (snake_x_reg_3 - snake_x_reg_2);
                        dy_val = (snake_y_reg_2 > snake_y_reg_3) ? (snake_y_reg_2 - snake_y_reg_3) : (snake_y_reg_3 - snake_y_reg_2);
                    end
                    
                    dx2_val = dx_val * dx_val;
                    dy2_val = dy_val * dy_val;
                    dist_sq_val = dx2_val + dy2_val;
                    
                    // Get sum of radii (handle different indices)
                    if (loop_i == 3'd0) begin
                        if (loop_j == 3'd1) rad_sum_sq_val = (snake_d_reg_0 + snake_d_reg_1) * (snake_d_reg_0 + snake_d_reg_1);
                        else if (loop_j == 3'd2) rad_sum_sq_val = (snake_d_reg_0 + snake_d_reg_2) * (snake_d_reg_0 + snake_d_reg_2);
                        else rad_sum_sq_val = (snake_d_reg_0 + snake_d_reg_3) * (snake_d_reg_0 + snake_d_reg_3);
                    end else if (loop_i == 3'd1) begin
                        if (loop_j == 3'd2) rad_sum_sq_val = (snake_d_reg_1 + snake_d_reg_2) * (snake_d_reg_1 + snake_d_reg_2);
                        else rad_sum_sq_val = (snake_d_reg_1 + snake_d_reg_3) * (snake_d_reg_1 + snake_d_reg_3);
                    end else begin
                        rad_sum_sq_val = (snake_d_reg_2 + snake_d_reg_3) * (snake_d_reg_2 + snake_d_reg_3);
                    end
                    
                    if (dist_sq_val < rad_sum_sq_val) begin
                        // Merge sets
                        case (loop_i)
                            3'd0: begin
                                case (loop_j)
                                    3'd1: parent_1 <= parent_0;
                                    3'd2: parent_2 <= parent_0;
                                    3'd3: parent_3 <= parent_0;
                                endcase
                            end
                            3'd1: begin
                                case (loop_j)
                                    3'd2: parent_2 <= parent_1;
                                    3'd3: parent_3 <= parent_1;
                                endcase
                            end
                            3'd2: begin
                                parent_3 <= parent_2;
                            end
                        endcase
                    end
                    
                    // Next pair
                    if (loop_j < 3'd3) begin
                        loop_j <= loop_j + 3'd1;
                    end else begin
                        loop_j <= 3'd0;
                        loop_i <= loop_i + 3'd1;
                    end
                end else begin
                    // Done with pairs
                    state <= BARRIER_CHECK;
                    loop_i <= 3'd0;
                end
            end

            BARRIER_CHECK: begin
                // Check if any snake touches both top and bottom through its root
                case (loop_i)
                    3'd0: begin
                        if (num_snakes_reg > 3'd0) begin
                            current_root = parent_0;
                            if (current_root == 2'd0 && touch_top_0 && touch_bottom_0) barrier_detected <= 1'b1;
                            if (current_root == 2'd1 && touch_top_1 && touch_bottom_1) barrier_detected <= 1'b1;
                            if (current_root == 2'd2 && touch_top_2 && touch_bottom_2) barrier_detected <= 1'b1;
                            if (current_root == 2'd3 && touch_top_3 && touch_bottom_3) barrier_detected <= 1'b1;
                        end
                    end
                    3'd1: begin
                        if (num_snakes_reg > 3'd1) begin
                            current_root = parent_1;
                            if (current_root == 2'd0 && touch_top_0 && touch_bottom_0) barrier_detected <= 1'b1;
                            if (current_root == 2'd1 && touch_top_1 && touch_bottom_1) barrier_detected <= 1'b1;
                            if (current_root == 2'd2 && touch_top_2 && touch_bottom_2) barrier_detected <= 1'b1;
                            if (current_root == 2'd3 && touch_top_3 && touch_bottom_3) barrier_detected <= 1'b1;
                        end
                    end
                    3'd2: begin
                        if (num_snakes_reg > 3'd2) begin
                            current_root = parent_2;
                            if (current_root == 2'd0 && touch_top_0 && touch_bottom_0) barrier_detected <= 1'b1;
                            if (current_root == 2'd1 && touch_top_1 && touch_bottom_1) barrier_detected <= 1'b1;
                            if (current_root == 2'd2 && touch_top_2 && touch_bottom_2) barrier_detected <= 1'b1;
                            if (current_root == 2'd3 && touch_top_3 && touch_bottom_3) barrier_detected <= 1'b1;
                        end
                    end
                    3'd3: begin
                        if (num_snakes_reg > 3'd3) begin
                            current_root = parent_3;
                            if (current_root == 2'd0 && touch_top_0 && touch_bottom_0) barrier_detected <= 1'b1;
                            if (current_root == 2'd1 && touch_top_1 && touch_bottom_1) barrier_detected <= 1'b1;
                            if (current_root == 2'd2 && touch_top_2 && touch_bottom_2) barrier_detected <= 1'b1;
                            if (current_root == 2'd3 && touch_top_3 && touch_bottom_3) barrier_detected <= 1'b1;
                        end
                    end
                endcase
                
                if (loop_i < 3'd3) begin
                    loop_i <= loop_i + 3'd1;
                end else begin
                    if (barrier_detected) begin
                        path_found_reg <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        state <= LEFT_START;
                    end
                end
            end

            LEFT_START: begin
                y_step <= MAX_Y_STEP;
                found_entry <= 1'b0;
                state <= LEFT_LOOP;
            end

            LEFT_LOOP: begin
                if (y_step >= 7'd0 && !found_entry) begin
                    if (safe_left_comb) begin
                        entry_y_step_reg <= y_step;
                        found_entry <= 1'b1;
                    end else begin
                        y_step <= y_step - 7'd1;
                    end
                end else if (y_step < 7'd0) begin
                    path_found_reg <= 1'b0;
                    state <= DONE_STATE;
                end else begin
                    state <= RIGHT_START;
                end
            end

            RIGHT_START: begin
                y_step <= MAX_Y_STEP;
                found_exit <= 1'b0;
                state <= RIGHT_LOOP;
            end

            RIGHT_LOOP: begin
                if (y_step >= 7'd0 && !found_exit) begin
                    if (safe_right_comb) begin
                        exit_y_step_reg <= y_step;
                        found_exit <= 1'b1;
                    end else begin
                        y_step <= y_step - 7'd1;
                    end
                end else if (y_step < 7'd0) begin
                    path_found_reg <= 1'b0;
                    state <= DONE_STATE;
                end else begin
                    path_found_reg <= 1'b1;
                    state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                done_reg <= 1'b1;
            end

            default: state <= IDLE;
        endcase
    end
end

// Output assignments
always @(*) begin
    path_found = path_found_reg;
    entry_y_step = entry_y_step_reg;
    exit_y_step = exit_y_step_reg;
    done = done_reg;
end

endmodule