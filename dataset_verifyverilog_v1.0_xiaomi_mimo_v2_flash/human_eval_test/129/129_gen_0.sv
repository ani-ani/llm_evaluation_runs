module min_path(
    input clk,
    input rst_n,
    input start,
    input [5:0] k,
    input [3:0] grid_0_0, grid_0_1, grid_0_2, grid_0_3,
    input [3:0] grid_1_0, grid_1_1, grid_1_2, grid_1_3,
    input [3:0] grid_2_0, grid_2_1, grid_2_2, grid_2_3,
    input [3:0] grid_3_0, grid_3_1, grid_3_2, grid_3_3,
    output reg [3:0] path_0, path_1, path_2, path_3, path_4, path_5, path_6, path_7,
    output reg [3:0] path_8, path_9, path_10, path_11, path_12, path_13, path_14, path_15,
    output reg done
);

    // State definitions
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_FIND_START = 2'd1;
    localparam [1:0] S_BUILD_PATH = 2'd2;
    localparam [1:0] S_DONE = 2'd3;

    reg [1:0] state, next_state;
    reg [5:0] step_counter;
    reg [5:0] max_steps;
    reg [1:0] curr_row, curr_col;
    reg [3:0] grid_val;
    reg [3:0] min_val;
    reg [3:0] best_val;
    reg [1:0] best_row;
    reg [1:0] best_col;
    reg [3:0] next_val;
    reg [1:0] next_row;
    reg [1:0] next_col;
    reg [2:0] neighbor_idx;
    reg found_min;
    reg found_start;
    reg path_updated;

    // Combinational grid lookup
    always @(*) begin
        case ({curr_row, curr_col})
            4'b0000: grid_val = grid_0_0;
            4'b0001: grid_val = grid_0_1;
            4'b0010: grid_val = grid_0_2;
            4'b0011: grid_val = grid_0_3;
            4'b0100: grid_val = grid_1_0;
            4'b0101: grid_val = grid_1_1;
            4'b0110: grid_val = grid_1_2;
            4'b0111: grid_val = grid_1_3;
            4'b1000: grid_val = grid_2_0;
            4'b1001: grid_val = grid_2_1;
            4'b1010: grid_val = grid_2_2;
            4'b1011: grid_val = grid_2_3;
            4'b1100: grid_val = grid_3_0;
            4'b1101: grid_val = grid_3_1;
            4'b1110: grid_val = grid_3_2;
            4'b1111: grid_val = grid_3_3;
            default: grid_val = 4'd0;
        endcase
    end

    // Neighbor selection logic
    always @(*) begin
        case (neighbor_idx)
            3'd0: begin // Up
                next_row = (curr_row > 2'd0) ? curr_row - 2'd1 : curr_row;
                next_col = curr_col;
            end
            3'd1: begin // Down
                next_row = (curr_row < 2'd3) ? curr_row + 2'd1 : curr_row;
                next_col = curr_col;
            end
            3'd2: begin // Left
                next_row = curr_row;
                next_col = (curr_col > 2'd0) ? curr_col - 2'd1 : curr_col;
            end
            3'd3: begin // Right
                next_row = curr_row;
                next_col = (curr_col < 2'd3) ? curr_col + 2'd1 : curr_col;
            end
            default: begin
                next_row = curr_row;
                next_col = curr_col;
            end
        endcase

        // Get neighbor value
        case ({next_row, next_col})
            4'b0000: next_val = grid_0_0;
            4'b0001: next_val = grid_0_1;
            4'b0010: next_val = grid_0_2;
            4'b0011: next_val = grid_0_3;
            4'b0100: next_val = grid_1_0;
            4'b0101: next_val = grid_1_1;
            4'b0110: next_val = grid_1_2;
            4'b0111: next_val = grid_1_3;
            4'b1000: next_val = grid_2_0;
            4'b1001: next_val = grid_2_1;
            4'b1010: next_val = grid_2_2;
            4'b1011: next_val = grid_2_3;
            4'b1100: next_val = grid_3_0;
            4'b1101: next_val = grid_3_1;
            4'b1110: next_val = grid_3_2;
            4'b1111: next_val = grid_3_3;
            default: next_val = 4'd0;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            step_counter <= 6'd0;
            max_steps <= 6'd0;
            curr_row <= 2'd0;
            curr_col <= 2'd0;
            min_val <= 4'd15;
            best_val <= 4'd15;
            best_row <= 2'd0;
            best_col <= 2'd0;
            neighbor_idx <= 3'd0;
            found_min <= 1'b0;
            found_start <= 1'b0;
            path_updated <= 1'b0;
            done <= 1'b0;
            path_0 <= 4'd0; path_1 <= 4'd0; path_2 <= 4'd0; path_3 <= 4'd0;
            path_4 <= 4'd0; path_5 <= 4'd0; path_6 <= 4'd0; path_7 <= 4'd0;
            path_8 <= 4'd0; path_9 <= 4'd0; path_10 <= 4'd0; path_11 <= 4'd0;
            path_12 <= 4'd0; path_13 <= 4'd0; path_14 <= 4'd0; path_15 <= 4'd0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    step_counter <= 6'd0;
                    neighbor_idx <= 3'd0;
                    found_min <= 1'b0;
                    found_start <= 1'b0;
                    path_updated <= 1'b0;
                    if (start) begin
                        max_steps <= (k < 6'd16) ? k : 6'd16;
                        state <= S_FIND_START;
                    end
                end

                S_FIND_START: begin
                    // Find cell with value 1 (minimum possible starting value)
                    if (grid_val == 4'd1) begin
                        best_row <= curr_row;
                        best_col <= curr_col;
                        found_start <= 1'b1;
                    end
                    // Move through all 16 cells
                    if (curr_col < 2'd3) begin
                        curr_col <= curr_col + 2'd1;
                    end else begin
                        curr_col <= 2'd0;
                        if (curr_row < 2'd3) begin
                            curr_row <= curr_row + 2'd1;
                        end else begin
                            curr_row <= 2'd0;
                            if (found_start) begin
                                state <= S_BUILD_PATH;
                                // Set initial path value
                                case (step_counter)
                                    6'd0: path_0 <= 4'd1;
                                    6'd1: path_1 <= 4'd1;
                                    6'd2: path_2 <= 4'd1;
                                    6'd3: path_3 <= 4'd1;
                                    6'd4: path_4 <= 4'd1;
                                    6'd5: path_5 <= 4'd1;
                                    6'd6: path_6 <= 4'd1;
                                    6'd7: path_7 <= 4'd1;
                                    6'd8: path_8 <= 4'd1;
                                    6'd9: path_9 <= 4'd1;
                                    6'd10: path_10 <= 4'd1;
                                    6'd11: path_11 <= 4'd1;
                                    6'd12: path_12 <= 4'd1;
                                    6'd13: path_13 <= 4'd1;
                                    6'd14: path_14 <= 4'd1;
                                    6'd15: path_15 <= 4'd1;
                                endcase
                                step_counter <= 6'd1;
                                curr_row <= best_row;
                                curr_col <= best_col;
                                min_val <= 4'd15;
                                found_min <= 1'b0;
                            end else begin
                                // No value 1 found, should not happen per spec
                                state <= S_DONE;
                            end
                        end
                    end
                end

                S_BUILD_PATH: begin
                    if (step_counter >= max_steps) begin
                        state <= S_DONE;
                    end else begin
                        // Check all neighbors to find minimum value
                        if (neighbor_idx < 3'd4) begin
                            // Check if this neighbor is better than current best
                            if (!found_min || next_val < best_val) begin
                                best_val <= next_val;
                                best_row <= next_row;
                                best_col <= next_col;
                                found_min <= 1'b1;
                            end
                            neighbor_idx <= neighbor_idx + 3'd1;
                        end else begin
                            // All neighbors checked, update path
                            if (found_min) begin
                                case (step_counter)
                                    6'd0: path_0 <= best_val;
                                    6'd1: path_1 <= best_val;
                                    6'd2: path_2 <= best_val;
                                    6'd3: path_3 <= best_val;
                                    6'd4: path_4 <= best_val;
                                    6'd5: path_5 <= best_val;
                                    6'd6: path_6 <= best_val;
                                    6'd7: path_7 <= best_val;
                                    6'd8: path_8 <= best_val;
                                    6'd9: path_9 <= best_val;
                                    6'd10: path_10 <= best_val;
                                    6'd11: path_11 <= best_val;
                                    6'd12: path_12 <= best_val;
                                    6'd13: path_13 <= best_val;
                                    6'd14: path_14 <= best_val;
                                    6'd15: path_15 <= best_val;
                                endcase
                                curr_row <= best_row;
                                curr_col <= best_col;
                                step_counter <= step_counter + 6'd1;
                                neighbor_idx <= 3'd0;
                                min_val <= 4'd15;
                                found_min <= 1'b0;
                            end else begin
                                // No valid neighbor found, stay in place
                                case (step_counter)
                                    6'd0: path_0 <= grid_val;
                                    6'd1: path_1 <= grid_val;
                                    6'd2: path_2 <= grid_val;
                                    6'd3: path_3 <= grid_val;
                                    6'd4: path_4 <= grid_val;
                                    6'd5: path_5 <= grid_val;
                                    6'd6: path_6 <= grid_val;
                                    6'd7: path_7 <= grid_val;
                                    6'd8: path_8 <= grid_val;
                                    6'd9: path_9 <= grid_val;
                                    6'd10: path_10 <= grid_val;
                                    6'd11: path_11 <= grid_val;
                                    6'd12: path_12 <= grid_val;
                                    6'd13: path_13 <= grid_val;
                                    6'd14: path_14 <= grid_val;
                                    6'd15: path_15 <= grid_val;
                                endcase
                                step_counter <= step_counter + 6'd1;
                                neighbor_idx <= 3'd0;
                                found_min <= 1'b0;
                            end
                        end
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule