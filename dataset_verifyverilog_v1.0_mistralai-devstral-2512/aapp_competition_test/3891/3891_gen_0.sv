module BlackSquareCenterFinder(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_0,
    input [7:0] grid_1,
    input [7:0] grid_2,
    input [7:0] grid_3,
    input [7:0] grid_4,
    input [7:0] grid_5,
    input [7:0] grid_6,
    input [7:0] grid_7,
    input [7:0] grid_8,
    input [7:0] grid_9,
    input [7:0] grid_10,
    input [7:0] grid_11,
    input [7:0] grid_12,
    input [7:0] grid_13,
    input [7:0] grid_14,
    input [7:0] grid_15,
    input [3:0] valid_rows,
    output reg [7:0] center_row,
    output reg [7:0] center_col,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] CALC = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] row_min, row_max;
    reg [7:0] col_min, col_max;
    reg [3:0] scan_counter;
    reg [7:0] current_grid;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_min <= 8'd15;
            row_max <= 8'd0;
            col_min <= 8'd8;
            col_max <= 8'd0;
            scan_counter <= 4'd0;
            center_row <= 8'd0;
            center_col <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                end else begin
                    next_state = IDLE;
                end
            end

            SCAN: begin
                if (scan_counter == 4'd15) begin
                    next_state = CALC;
                end else begin
                    next_state = SCAN;
                end
            end

            CALC: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Scan logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_counter <= 4'd0;
        end else if (state == SCAN) begin
            // Select current grid row
            case (scan_counter)
                4'd0: current_grid = grid_0;
                4'd1: current_grid = grid_1;
                4'd2: current_grid = grid_2;
                4'd3: current_grid = grid_3;
                4'd4: current_grid = grid_4;
                4'd5: current_grid = grid_5;
                4'd6: current_grid = grid_6;
                4'd7: current_grid = grid_7;
                4'd8: current_grid = grid_8;
                4'd9: current_grid = grid_9;
                4'd10: current_grid = grid_10;
                4'd11: current_grid = grid_11;
                4'd12: current_grid = grid_12;
                4'd13: current_grid = grid_13;
                4'd14: current_grid = grid_14;
                4'd15: current_grid = grid_15;
                default: current_grid = 8'd0;
            endcase

            // Process current row if valid
            if (scan_counter < valid_rows && current_grid != 8'd0) begin
                // Update row min/max
                if (scan_counter < row_min) begin
                    row_min = scan_counter;
                end
                if (scan_counter > row_max) begin
                    row_max = scan_counter;
                end

                // Update column min/max
                if (current_grid[0] == 1'b1 && 0 < col_min) begin
                    col_min = 0;
                end
                if (current_grid[1] == 1'b1 && 1 < col_min) begin
                    col_min = 1;
                end
                if (current_grid[2] == 1'b1 && 2 < col_min) begin
                    col_min = 2;
                end
                if (current_grid[3] == 1'b1 && 3 < col_min) begin
                    col_min = 3;
                end
                if (current_grid[4] == 1'b1 && 4 < col_min) begin
                    col_min = 4;
                end
                if (current_grid[5] == 1'b1 && 5 < col_min) begin
                    col_min = 5;
                end
                if (current_grid[6] == 1'b1 && 6 < col_min) begin
                    col_min = 6;
                end
                if (current_grid[7] == 1'b1 && 7 < col_min) begin
                    col_min = 7;
                end

                if (current_grid[0] == 1'b1 && 0 > col_max) begin
                    col_max = 0;
                end
                if (current_grid[1] == 1'b1 && 1 > col_max) begin
                    col_max = 1;
                end
                if (current_grid[2] == 1'b1 && 2 > col_max) begin
                    col_max = 2;
                end
                if (current_grid[3] == 1'b1 && 3 > col_max) begin
                    col_max = 3;
                end
                if (current_grid[4] == 1'b1 && 4 > col_max) begin
                    col_max = 4;
                end
                if (current_grid[5] == 1'b1 && 5 > col_max) begin
                    col_max = 5;
                end
                if (current_grid[6] == 1'b1 && 6 > col_max) begin
                    col_max = 6;
                end
                if (current_grid[7] == 1'b1 && 7 > col_max) begin
                    col_max = 7;
                end
            end

            scan_counter <= scan_counter + 4'd1;
        end
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            center_row <= 8'd0;
            center_col <= 8'd0;
            done <= 1'b0;
        end else if (state == CALC) begin
            // Calculate center (0-based) and convert to 1-based
            center_row <= (row_min + row_max) >> 1 + 8'd1;
            center_col <= (col_min + col_max) >> 1 + 8'd1;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule