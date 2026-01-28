module min_path(
    input clk,
    input rst_n,
    input start,
    input [5:0] k,
    input [3:0] grid_0_0, grid_0_1, grid_0_2, grid_0_3,
    input [3:0] grid_1_0, grid_1_1, grid_1_2, grid_1_3,
    input [3:0] grid_2_0, grid_2_1, grid_2_2, grid_2_3,
    input [3:0] grid_3_0, grid_3_1, grid_3_2, grid_3_3,
    output reg [3:0] path_0, path_1, path_2, path_3, path_4, path_5, path_6, path_7, path_8, path_9, path_10, path_11, path_12, path_13, path_14, path_15,
    output reg done
);

    // State definitions
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_FIND_START = 2'd1;
    localparam [1:0] S_BUILD_PATH = 2'd2;
    localparam [1:0] S_DONE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] current_row, current_col;
    reg [3:0] step_count;
    reg [3:0] min_val;
    reg [1:0] min_row, min_col;
    reg [3:0] temp_val;
    integer i, j;

    // Grid access function
    function [3:0] get_grid_value;
        input [1:0] r;
        input [1:0] c;
        case (r)
            2'd0: case (c)
                    2'd0: get_grid_value = grid_0_0;
                    2'd1: get_grid_value = grid_0_1;
                    2'd2: get_grid_value = grid_0_2;
                    2'd3: get_grid_value = grid_0_3;
                endcase
            2'd1: case (c)
                    2'd0: get_grid_value = grid_1_0;
                    2'd1: get_grid_value = grid_1_1;
                    2'd2: get_grid_value = grid_1_2;
                    2'd3: get_grid_value = grid_1_3;
                endcase
            2'd2: case (c)
                    2'd0: get_grid_value = grid_2_0;
                    2'd1: get_grid_value = grid_2_1;
                    2'd2: get_grid_value = grid_2_2;
                    2'd3: get_grid_value = grid_2_3;
                endcase
            2'd3: case (c)
                    2'd0: get_grid_value = grid_3_0;
                    2'd1: get_grid_value = grid_3_1;
                    2'd2: get_grid_value = grid_3_2;
                    2'd3: get_grid_value = grid_3_3;
                endcase
        endcase
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            step_count <= 4'd0;
            current_row <= 2'd0;
            current_col <= 2'd0;
            min_val <= 4'd0;
            min_row <= 2'd0;
            min_col <= 2'd0;
            path_0 <= 4'd0;
            path_1 <= 4'd0;
            path_2 <= 4'd0;
            path_3 <= 4'd0;
            path_4 <= 4'd0;
            path_5 <= 4'd0;
            path_6 <= 4'd0;
            path_7 <= 4'd0;
            path_8 <= 4'd0;
            path_9 <= 4'd0;
            path_10 <= 4'd0;
            path_11 <= 4'd0;
            path_12 <= 4'd0;
            path_13 <= 4'd0;
            path_14 <= 4'd0;
            path_15 <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_FIND_START;
                end
            end
            S_FIND_START: begin
                next_state = S_BUILD_PATH;
            end
            S_BUILD_PATH: begin
                if (step_count == k - 1) begin
                    next_state = S_DONE;
                end
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Find start position (value 1)
    always @(posedge clk) begin
        if (state == S_FIND_START) begin
            min_val = 4'd16; // Initialize to max value
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    temp_val = get_grid_value(i, j);
                    if (temp_val == 4'd1 && temp_val < min_val) begin
                        min_val = temp_val;
                        min_row = i;
                        min_col = j;
                    end
                end
            end
            current_row = min_row;
            current_col = min_col;
            path_0 = min_val;
            step_count = 4'd0;
        end
    end

    // Build path step by step
    always @(posedge clk) begin
        if (state == S_BUILD_PATH) begin
            min_val = 4'd16; // Initialize to max value
            // Check all 4 neighbors
            // Up
            if (current_row > 0) begin
                temp_val = get_grid_value(current_row - 1, current_col);
                if (temp_val < min_val) begin
                    min_val = temp_val;
                    min_row = current_row - 1;
                    min_col = current_col;
                end
            end
            // Down
            if (current_row < 3) begin
                temp_val = get_grid_value(current_row + 1, current_col);
                if (temp_val < min_val) begin
                    min_val = temp_val;
                    min_row = current_row + 1;
                    min_col = current_col;
                end
            end
            // Left
            if (current_col > 0) begin
                temp_val = get_grid_value(current_row, current_col - 1);
                if (temp_val < min_val) begin
                    min_val = temp_val;
                    min_row = current_row;
                    min_col = current_col - 1;
                end
            end
            // Right
            if (current_col < 3) begin
                temp_val = get_grid_value(current_row, current_col + 1);
                if (temp_val < min_val) begin
                    min_val = temp_val;
                    min_row = current_row;
                    min_col = current_col + 1;
                end
            end
            // Update current position and path
            current_row = min_row;
            current_col = min_col;
            case (step_count)
                4'd0: path_1 = min_val;
                4'd1: path_2 = min_val;
                4'd2: path_3 = min_val;
                4'd3: path_4 = min_val;
                4'd4: path_5 = min_val;
                4'd5: path_6 = min_val;
                4'd6: path_7 = min_val;
                4'd7: path_8 = min_val;
                4'd8: path_9 = min_val;
                4'd9: path_10 = min_val;
                4'd10: path_11 = min_val;
                4'd11: path_12 = min_val;
                4'd12: path_13 = min_val;
                4'd13: path_14 = min_val;
                4'd14: path_15 = min_val;
            endcase
            step_count = step_count + 4'd1;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == S_DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule