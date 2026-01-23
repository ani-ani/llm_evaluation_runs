module zamboni(
    input clk,
    input rst_n,
    input start,
    input [7:0] i,
    input [7:0] j,
    input [7:0] n,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT       = 4'd1;
    localparam [3:0] CHECK_ITER = 4'd2;
    localparam [3:0] MOVE_START = 4'd3;
    localparam [3:0] MOVE_STEP  = 4'd4;
    localparam [3:0] NEXT_ITER  = 4'd5;
    localparam [3:0] MARK_FINAL = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;

    // Grid: 8x8 array of 8-bit registers
    reg [7:0] grid [0:7];
    integer k;

    // Counters and position
    reg [7:0] iter_count;
    reg [7:0] step_count;
    reg [7:0] step_size;
    reg [7:0] current_i, current_j;
    reg [7:0] color;
    reg [1:0] direction; // 0: right, 1: down, 2: left, 3: up

    // Initialize grid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            iter_count <= 8'd0;
            step_count <= 8'd0;
            step_size <= 8'd0;
            current_i <= 8'd0;
            current_j <= 8'd0;
            color <= 8'd0;
            direction <= 2'd0;
            for (k = 0; k < 8; k = k + 1) begin
                grid[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                // Convert 1-based to 0-based
                current_i = i - 8'd1;
                current_j = j - 8'd1;
                color = 8'd0;
                direction = 2'd0;
                iter_count = 8'd0;
                step_size = 8'd1;
                next_state = CHECK_ITER;
            end

            CHECK_ITER: begin
                if (iter_count == n) begin
                    next_state = MARK_FINAL;
                end else begin
                    next_state = MOVE_START;
                end
            end

            MOVE_START: begin
                step_count = 8'd0;
                next_state = MOVE_STEP;
            end

            MOVE_STEP: begin
                if (step_count == step_size - 8'd1) begin
                    next_state = NEXT_ITER;
                end else begin
                    next_state = MOVE_STEP;
                end
            end

            NEXT_ITER: begin
                iter_count = iter_count + 8'd1;
                step_size = step_size + 8'd1;
                color = color + 8'd1;
                if (color == 8'd26) begin
                    color = 8'd0;
                end
                direction = direction + 2'd1;
                if (direction == 2'd4) begin
                    direction = 2'd0;
                end
                next_state = CHECK_ITER;
            end

            MARK_FINAL: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Grid update logic
    always @(posedge clk) begin
        if (state == INIT) begin
            // Initialize grid to all '.' (0)
            for (k = 0; k < 8; k = k + 1) begin
                grid[k] <= 8'd0;
            end
        end else if (state == MOVE_STEP) begin
            // Update current position with color
            grid[current_i][current_j] <= color + 8'd1;
            
            // Move in current direction with wrap-around
            case (direction)
                2'd0: current_j = current_j + 8'd1; // right
                2'd1: current_i = current_i + 8'd1; // down
                2'd2: current_j = current_j - 8'd1; // left
                2'd3: current_i = current_i - 8'd1; // up
            endcase
            
            // Wrap around
            if (current_i == 8'd8) begin
                current_i = 8'd0;
            end else if (current_i == 8'd255) begin
                current_i = 8'd7;
            end
            
            if (current_j == 8'd8) begin
                current_j = 8'd0;
            end else if (current_j == 8'd255) begin
                current_j = 8'd7;
            end
            
            step_count = step_count + 8'd1;
        end else if (state == MARK_FINAL) begin
            // Mark final position with '@' (27)
            grid[current_i][current_j] <= 8'd27;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            case (state)
                DONE_STATE: done <= 1'b1;
                default: done <= 1'b0;
            endcase
        end
    end

endmodule