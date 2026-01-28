module PacManZamboni(
    input clk,
    input rst_n,
    input start,
    input [4:0] row_start,
    input [4:0] col_start,
    output reg done,
    output reg grid_valid,
    output reg [7:0] grid_data,
    output reg [5:0] grid_addr
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] INIT_GRID = 2'd1;
    localparam [1:0] SIMULATE  = 2'd2;
    localparam [1:0] OUTPUT    = 2'd3;

    // Grid memory (5x5)
    reg [7:0] grid [0:24];

    // Internal registers
    reg [1:0] state, next_state;
    reg [4:0] row, next_row;
    reg [4:0] col, next_col;
    reg [1:0] direction, next_direction;
    reg [4:0] color, next_color;
    reg [2:0] stepSize, next_stepSize;
    reg [2:0] iter_count, next_iter_count;
    reg [2:0] move_count, next_move_count;
    reg [5:0] output_addr, next_output_addr;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            grid_valid <= 1'b0;
            grid_data <= 8'd0;
            grid_addr <= 6'd0;
            row <= 5'd0;
            col <= 5'd0;
            direction <= 2'd0;
            color <= 5'd0;
            stepSize <= 3'd1;
            iter_count <= 3'd0;
            move_count <= 3'd0;
            output_addr <= 6'd0;
        end else begin
            state <= next_state;
            row <= next_row;
            col <= next_col;
            direction <= next_direction;
            color <= next_color;
            stepSize <= next_stepSize;
            iter_count <= next_iter_count;
            move_count <= next_move_count;
            output_addr <= next_output_addr;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_row = row;
        next_col = col;
        next_direction = direction;
        next_color = color;
        next_stepSize = stepSize;
        next_iter_count = iter_count;
        next_move_count = move_count;
        next_output_addr = output_addr;

        case (state)
            IDLE: begin
                done = 1'b0;
                grid_valid = 1'b0;
                if (start) begin
                    next_state = INIT_GRID;
                end
            end

            INIT_GRID: begin
                // Initialize grid to '.'
                integer i;
                for (i = 0; i < 25; i = i + 1) begin
                    grid[i] = 8'd'.';
                end
                // Set starting position
                next_row = row_start;
                next_col = col_start;
                next_state = SIMULATE;
            end

            SIMULATE: begin
                if (iter_count < 4) begin
                    if (move_count < stepSize) begin
                        // Move one step in current direction
                        case (direction)
                            2'd0: begin // Up
                                next_row = row - 1;
                                next_col = col;
                            end
                            2'd1: begin // Right
                                next_row = row;
                                next_col = col + 1;
                            end
                            2'd2: begin // Down
                                next_row = row + 1;
                                next_col = col;
                            end
                            2'd3: begin // Left
                                next_row = row;
                                next_col = col - 1;
                            end
                        endcase

                        // Wrapping
                        if (next_col < 0) next_col = next_col + 5;
                        if (next_col >= 5) next_col = next_col - 5;
                        if (next_row < 0) next_row = next_row + 5;
                        if (next_row >= 5) next_row = next_row - 5;

                        // Update grid with current color
                        grid[next_row * 5 + next_col] = 8'd'A' + color;
                        next_move_count = move_count + 1;
                    end else begin
                        // Rotate direction
                        next_direction = (direction + 1) % 4;
                        // Increment color
                        next_color = (color + 1) % 26;
                        // Increment stepSize (clip to 4)
                        if (stepSize < 4) next_stepSize = stepSize + 1;
                        else next_stepSize = 4;
                        // Reset move count
                        next_move_count = 0;
                        // Increment iteration count
                        next_iter_count = iter_count + 1;
                    end
                end else begin
                    // Final mark with '@'
                    grid[row * 5 + col] = 8'd'@';
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (output_addr < 25) begin
                    grid_valid = 1'b1;
                    grid_data = grid[output_addr];
                    grid_addr = output_addr;
                    next_output_addr = output_addr + 1;
                end else begin
                    grid_valid = 1'b0;
                    done = 1'b1;
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
                grid_valid = 1'b0;
            end
        endcase
    end

endmodule