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
localparam STEP = 10;
localparam MAX_Y_STEP = 100;
localparam FIELD_SIZE = 1000;

// Internal registers
reg [2:0] state;
reg [9:0] snake_x_reg0, snake_x_reg1, snake_x_reg2, snake_x_reg3;
reg [9:0] snake_y_reg0, snake_y_reg1, snake_y_reg2, snake_y_reg3;
reg [9:0] snake_d_reg0, snake_d_reg1, snake_d_reg2, snake_d_reg3;
reg [2:0] num_snakes_reg;
reg [6:0] y_step;
reg found_entry, found_exit;
reg path_found_reg;
reg [6:0] entry_y_step_reg, exit_y_step_reg;
reg done_reg;

// State definitions
localparam IDLE = 0;
localparam BARRIER_COMPUTE = 1;
localparam LEFT_START = 2;
localparam LEFT_LOOP = 3;
localparam RIGHT_START = 4;
localparam RIGHT_LOOP = 5;
localparam DONE = 6;

// Combinational barrier computation
wire barrier_exists_comb;

// Assign outputs
assign path_found = path_found_reg;
assign entry_y_step = entry_y_step_reg;
assign exit_y_step = exit_y_step_reg;
assign done = done_reg;

// Function to compute barrier
function automatic logic compute_barrier;
    logic [1:0] parent0, parent1, parent2, parent3;
    logic touch_top0, touch_top1, touch_top2, touch_top3;
    logic touch_bottom0, touch_bottom1, touch_bottom2, touch_bottom3;
    logic barrier;
    logic [31:0] dx, dy, dx2, dy2, dist_sq, rad_sum_sq;
    begin
        // Initialize
        parent0 = 2'd0; parent1 = 2'd1; parent2 = 2'd2; parent3 = 2'd3;
        touch_top0 = (snake_y_reg0 + snake_d_reg0 > 1000);
        touch_top1 = (snake_y_reg1 + snake_d_reg1 > 1000);
        touch_top2 = (snake_y_reg2 + snake_d_reg2 > 1000);
        touch_top3 = (snake_y_reg3 + snake_d_reg3 > 1000);
        touch_bottom0 = (snake_y_reg0 - snake_d_reg0 < 0);
        touch_bottom1 = (snake_y_reg1 - snake_d_reg1 < 0);
        touch_bottom2 = (snake_y_reg2 - snake_d_reg2 < 0);
        touch_bottom3 = (snake_y_reg3 - snake_d_reg3 < 0);
        
        // Pairwise intersections
        dx = (snake_x_reg0 > snake_x_reg1) ? (snake_x_reg0 - snake_x_reg1) : (snake_x_reg1 - snake_x_reg0);
        dy = (snake_y_reg0 > snake_y_reg1) ? (snake_y_reg0 - snake_y_reg1) : (snake_y_reg1 - snake_y_reg0);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg0 + snake_d_reg1) * (snake_d_reg0 + snake_d_reg1);
        if (dist_sq < rad_sum_sq) begin
            parent0 = parent1;
        end
        
        dx = (snake_x_reg0 > snake_x_reg2) ? (snake_x_reg0 - snake_x_reg2) : (snake_x_reg2 - snake_x_reg0);
        dy = (snake_y_reg0 > snake_y_reg2) ? (snake_y_reg0 - snake_y_reg2) : (snake_y_reg2 - snake_y_reg0);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg0 + snake_d_reg2) * (snake_d_reg0 + snake_d_reg2);
        if (dist_sq < rad_sum_sq) begin
            parent0 = parent2;
        end
        
        dx = (snake_x_reg0 > snake_x_reg3) ? (snake_x_reg0 - snake_x_reg3) : (snake_x_reg3 - snake_x_reg0);
        dy = (snake_y_reg0 > snake_y_reg3) ? (snake_y_reg0 - snake_y_reg3) : (snake_y_reg3 - snake_y_reg0);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg0 + snake_d_reg3) * (snake_d_reg0 + snake_d_reg3);
        if (dist_sq < rad_sum_sq) begin
            parent0 = parent3;
        end
        
        dx = (snake_x_reg1 > snake_x_reg2) ? (snake_x_reg1 - snake_x_reg2) : (snake_x_reg2 - snake_x_reg1);
        dy = (snake_y_reg1 > snake_y_reg2) ? (snake_y_reg1 - snake_y_reg2) : (snake_y_reg2 - snake_y_reg1);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg1 + snake_d_reg2) * (snake_d_reg1 + snake_d_reg2);
        if (dist_sq < rad_sum_sq) begin
            parent1 = parent2;
        end
        
        dx = (snake_x_reg1 > snake_x_reg3) ? (snake_x_reg1 - snake_x_reg3) : (snake_x_reg3 - snake_x_reg1);
        dy = (snake_y_reg1 > snake_y_reg3) ? (snake_y_reg1 - snake_y_reg3) : (snake_y_reg3 - snake_y_reg1);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg1 + snake_d_reg3) * (snake_d_reg1 + snake_d_reg3);
        if (dist_sq < rad_sum_sq) begin
            parent1 = parent3;
        end
        
        dx = (snake_x_reg2 > snake_x_reg3) ? (snake_x_reg2 - snake_x_reg3) : (snake_x_reg3 - snake_x_reg2);
        dy = (snake_y_reg2 > snake_y_reg3) ? (snake_y_reg2 - snake_y_reg3) : (snake_y_reg3 - snake_y_reg2);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sum_sq = (snake_d_reg2 + snake_d_reg3) * (snake_d_reg2 + snake_d_reg3);
        if (dist_sq < rad_sum_sq) begin
            parent2 = parent3;
        end
        
        // Check top-bottom
        barrier = 0;
        if (touch_top0 && touch_bottom0) barrier = 1;
        if (touch_top1 && touch_bottom1) barrier = 1;
        if (touch_top2 && touch_bottom2) barrier = 1;
        if (touch_top3 && touch_bottom3) barrier = 1;
        compute_barrier = barrier;
    end
endfunction

assign barrier_exists_comb = compute_barrier();

// Combinational left safety check
function automatic logic compute_left_safe;
    logic safe;
    logic [31:0] dx, dy, dx2, dy2, dist_sq, rad_sq;
    logic [16:0] py;
    begin
        safe = 1;
        py = y_step * STEP;
        
        dx = (0 > snake_x_reg0) ? (0 - snake_x_reg0) : (snake_x_reg0 - 0);
        dy = (py > snake_y_reg0) ? (py - snake_y_reg0) : (snake_y_reg0 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg0 * snake_d_reg0;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (0 > snake_x_reg1) ? (0 - snake_x_reg1) : (snake_x_reg1 - 0);
        dy = (py > snake_y_reg1) ? (py - snake_y_reg1) : (snake_y_reg1 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg1 * snake_d_reg1;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (0 > snake_x_reg2) ? (0 - snake_x_reg2) : (snake_x_reg2 - 0);
        dy = (py > snake_y_reg2) ? (py - snake_y_reg2) : (snake_y_reg2 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg2 * snake_d_reg2;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (0 > snake_x_reg3) ? (0 - snake_x_reg3) : (snake_x_reg3 - 0);
        dy = (py > snake_y_reg3) ? (py - snake_y_reg3) : (snake_y_reg3 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg3 * snake_d_reg3;
        if (dist_sq < rad_sq) safe = 0;
        
        compute_left_safe = safe;
    end
endfunction

wire is_safe_left_comb = compute_left_safe();

// Combinational right safety check
function automatic logic compute_right_safe;
    logic safe;
    logic [31:0] dx, dy, dx2, dy2, dist_sq, rad_sq;
    logic [16:0] py;
    begin
        safe = 1;
        py = y_step * STEP;
        
        dx = (1000 > snake_x_reg0) ? (1000 - snake_x_reg0) : (snake_x_reg0 - 1000);
        dy = (py > snake_y_reg0) ? (py - snake_y_reg0) : (snake_y_reg0 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg0 * snake_d_reg0;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (1000 > snake_x_reg1) ? (1000 - snake_x_reg1) : (snake_x_reg1 - 1000);
        dy = (py > snake_y_reg1) ? (py - snake_y_reg1) : (snake_y_reg1 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg1 * snake_d_reg1;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (1000 > snake_x_reg2) ? (1000 - snake_x_reg2) : (snake_x_reg2 - 1000);
        dy = (py > snake_y_reg2) ? (py - snake_y_reg2) : (snake_y_reg2 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg2 * snake_d_reg2;
        if (dist_sq < rad_sq) safe = 0;
        
        dx = (1000 > snake_x_reg3) ? (1000 - snake_x_reg3) : (snake_x_reg3 - 1000);
        dy = (py > snake_y_reg3) ? (py - snake_y_reg3) : (snake_y_reg3 - py);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist_sq = dx2 + dy2;
        rad_sq = snake_d_reg3 * snake_d_reg3;
        if (dist_sq < rad_sq) safe = 0;
        
        compute_right_safe = safe;
    end
endfunction

wire is_safe_right_comb = compute_right_safe();

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        path_found_reg <= 0;
        entry_y_step_reg <= 0;
        exit_y_step_reg <= 0;
        done_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                done_reg <= 0;
                if (start) begin
                    snake_x_reg0 <= snake_x0; snake_y_reg0 <= snake_y0; snake_d_reg0 <= snake_d0;
                    snake_x_reg1 <= snake_x1; snake_y_reg1 <= snake_y1; snake_d_reg1 <= snake_d1;
                    snake_x_reg2 <= snake_x2; snake_y_reg2 <= snake_y2; snake_d_reg2 <= snake_d2;
                    snake_x_reg3 <= snake_x3; snake_y_reg3 <= snake_y3; snake_d_reg3 <= snake_d3;
                    num_snakes_reg <= num_snakes;
                    state <= BARRIER_COMPUTE;
                end
            end

            BARRIER_COMPUTE: begin
                if (barrier_exists_comb) begin
                    path_found_reg <= 0;
                    state <= DONE;
                end else begin
                    state <= LEFT_START;
                end
            end

            LEFT_START: begin
                y_step <= MAX_Y_STEP;
                found_entry <= 0;
                state <= LEFT_LOOP;
            end

            LEFT_LOOP: begin
                if (y_step >= 0 && !found_entry) begin
                    if (is_safe_left_comb) begin
                        entry_y_step_reg <= y_step;
                        found_entry <= 1;
                    end else begin
                        y_step <= y_step - 1;
                    end
                end else if (y_step < 0) begin
                    path_found_reg <= 0;
                    state <= DONE;
                end else begin
                    state <= RIGHT_START;
                end
            end

            RIGHT_START: begin
                y_step <= MAX_Y_STEP;
                found_exit <= 0;
                state <= RIGHT_LOOP;
            end

            RIGHT_LOOP: begin
                if (y_step >= 0 && !found_exit) begin
                    if (is_safe_right_comb) begin
                        exit_y_step_reg <= y_step;
                        found_exit <= 1;
                    end else begin
                        y_step <= y_step - 1;
                    end
                end else if (y_step < 0) begin
                    path_found_reg <= 0;
                    state <= DONE;
                end else begin
                    path_found_reg <= 1;
                    state <= DONE;
                end
            end

            DONE: begin
                done_reg <= 1;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule