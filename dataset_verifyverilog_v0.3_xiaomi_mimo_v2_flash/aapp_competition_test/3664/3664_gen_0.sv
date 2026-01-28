module zamboni (
    input clk,
    input rst_n,
    input start,
    input [7:0] i,
    input [7:0] j,
    input [7:0] n,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INIT         = 3'd1;
    localparam [2:0] CHECK_ITER   = 3'd2;
    localparam [2:0] MOVE_START   = 3'd3;
    localparam [2:0] MOVE_STEP    = 3'd4;
    localparam [2:0] NEXT_ITER    = 3'd5;
    localparam [2:0] MARK_FINAL   = 3'd6;
    localparam [2:0] DONE_STATE   = 3'd7;

    // Direction definitions
    localparam [1:0] DIR_RIGHT = 2'd0;
    localparam [1:0] DIR_DOWN  = 2'd1;
    localparam [1:0] DIR_LEFT  = 2'd2;
    localparam [1:0] DIR_UP    = 2'd3;

    // Grid: 8x8 array of 8-bit registers
    reg [7:0] grid [0:7] [0:7];
    integer row_idx;
    integer col_idx;

    // Internal registers
    reg [2:0] state;
    reg [7:0] iter_count;      // 0 to n-1
    reg [7:0] step_size;       // step size for current iteration
    reg [7:0] step_count;      // steps taken in current move
    reg [7:0] curr_i;          // current row position (0-based)
    reg [7:0] curr_j;          // current column position (0-based)
    reg [1:0] direction;       // current moving direction
    reg [7:0] color;           // current color index (0-25 for A-Z)
    reg [7:0] max_iter;        // stores input n

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            iter_count <= 8'd0;
            step_size <= 8'd0;
            step_count <= 8'd0;
            curr_i <= 8'd0;
            curr_j <= 8'd0;
            direction <= 2'd0;
            color <= 8'd0;
            max_iter <= 8'd0;
            // Initialize grid to all zeros (clean)
            for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
                for (col_idx = 0; col_idx < 8; col_idx = col_idx + 1) begin
                    grid[row_idx][col_idx] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iter_count <= 8'd0;
                    step_count <= 8'd0;
                    if (start) begin
                        // Store inputs and start initialization
                        max_iter <= n;
                        // Convert 1-based inputs to 0-based
                        curr_i <= i - 8'd1;
                        curr_j <= j - 8'd1;
                        color <= 8'd0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Fill entire grid with current color + 1
                    // A=1, B=2, ..., Z=26
                    for (row_idx = 0; row_idx < 8; row_idx = row_idx + 1) begin
                        for (col_idx = 0; col_idx < 8; col_idx = col_idx + 1) begin
                            grid[row_idx][col_idx] <= color + 8'd1;
                        end
                    end
                    state <= CHECK_ITER;
                end

                CHECK_ITER: begin
                    if (iter_count < max_iter) begin
                        // Start of move sequence
                        direction <= DIR_RIGHT;
                        step_size <= 8'd1;
                        step_count <= 8'd0;
                        state <= MOVE_START;
                    end else begin
                        state <= MARK_FINAL;
                    end
                end

                MOVE_START: begin
                    // Check if we need to move or rotate
                    if (step_size == 8'd0) begin
                        // Done moving in this direction, rotate and increase step size
                        state <= NEXT_ITER;
                    end else begin
                        // Start moving in current direction
                        step_count <= 8'd0;
                        state <= MOVE_STEP;
                    end
                end

                MOVE_STEP: begin
                    if (step_count < step_size) begin
                        // Update position based on direction
                        case (direction)
                            DIR_RIGHT: begin
                                if (curr_j < 8'd7) begin
                                    curr_j <= curr_j + 8'd1;
                                end else begin
                                    curr_j <= 8'd0;
                                end
                            end
                            DIR_DOWN: begin
                                if (curr_i < 8'd7) begin
                                    curr_i <= curr_i + 8'd1;
                                end else begin
                                    curr_i <= 8'd0;
                                end
                            end
                            DIR_LEFT: begin
                                if (curr_j > 8'd0) begin
                                    curr_j <= curr_j - 8'd1;
                                end else begin
                                    curr_j <= 8'd7;
                                end
                            end
                            DIR_UP: begin
                                if (curr_i > 8'd0) begin
                                    curr_i <= curr_i - 8'd1;
                                end else begin
                                    curr_i <= 8'd7;
                                end
                            end
                            default: begin
                                curr_j <= curr_j;
                                curr_i <= curr_i;
                            end
                        endcase
                        // Color the new position
                        grid[curr_i][curr_j] <= color + 8'd1;
                        step_count <= step_count + 8'd1;
                        state <= MOVE_STEP;
                    end else begin
                        // Done with this step size
                        // Rotate direction and check if we need to increase step size
                        case (direction)
                            DIR_RIGHT: direction <= DIR_DOWN;
                            DIR_DOWN:  direction <= DIR_LEFT;
                            DIR_LEFT:  direction <= DIR_UP;
                            DIR_UP:    direction <= DIR_RIGHT;
                            default:   direction <= DIR_RIGHT;
                        endcase
                        // Step size only increases after right+down+left+up cycle (4 directions)
                        // This is handled by checking step_size in MOVE_START
                        state <= MOVE_START;
                    end
                end

                NEXT_ITER: begin
                    // Increment iteration and color
                    iter_count <= iter_count + 8'd1;
                    // Check if color needs to wrap (shouldn't happen with n <= 64, but safe)
                    if (color < 8'd25) begin
                        color <= color + 8'd1;
                    end else begin
                        color <= 8'd0;
                    end
                    // Double step size for next iteration
                    step_size <= {step_size[6:0], 1'b0}; // Multiply by 2
                    state <= CHECK_ITER;
                end

                MARK_FINAL: begin
                    // Mark final position with '@' (value 27)
                    grid[curr_i][curr_j] <= 8'd27;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule