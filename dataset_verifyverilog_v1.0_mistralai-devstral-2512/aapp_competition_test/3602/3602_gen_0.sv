module lamp_lighting_2sat(
    input clk,
    input rst_n,
    input start,
    input [3:0] lamp_row [0:15],
    input [3:0] lamp_col [0:15],
    input [3:0] num_lamps,
    input [3:0] grid_size,
    input [3:0] max_reach,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SOLVE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [3:0] current_lamp;
    reg [15:0] assignment;
    reg [3:0] stack_ptr;
    reg [15:0] stack [0:15];
    reg [3:0] cycle_count;
    reg [3:0] i, j;
    reg [3:0] lamp_i_row, lamp_i_col;
    reg [3:0] lamp_j_row, lamp_j_col;
    reg conflict_found;
    reg valid_assignment;

    // Loaded lamp coordinates
    reg [3:0] loaded_row [0:15];
    reg [3:0] loaded_col [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_lamp <= 4'd0;
            assignment <= 16'd0;
            stack_ptr <= 4'd0;
            cycle_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            conflict_found <= 1'b0;
            valid_assignment <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;

            // Initialize stack
            for (integer k = 0; k < 16; k = k + 1) begin
                stack[k] <= 16'd0;
            end

            // Initialize loaded coordinates
            for (integer k = 0; k < 16; k = k + 1) begin
                loaded_row[k] <= 4'd0;
                loaded_col[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        current_lamp <= 4'd0;
                    end
                end

                LOAD: begin
                    // Load lamp coordinates
                    if (current_lamp < num_lamps) begin
                        loaded_row[current_lamp] <= lamp_row[current_lamp];
                        loaded_col[current_lamp] <= lamp_col[current_lamp];
                        current_lamp <= current_lamp + 4'd1;
                    end else begin
                        state <= SOLVE;
                        current_lamp <= 4'd0;
                        assignment <= 16'd0;
                        stack_ptr <= 4'd0;
                        cycle_count <= 4'd0;
                        valid_assignment <= 1'b0;
                    end
                end

                SOLVE: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Check if we've exceeded max cycles
                    if (cycle_count >= 4'd1000) begin
                        state <= FINISH;
                        result <= 1'b0;
                    end else if (stack_ptr == num_lamps) begin
                        // Found a complete assignment
                        state <= FINISH;
                        result <= 1'b1;
                        valid_assignment <= 1'b1;
                    end else begin
                        // Try next assignment for current lamp
                        if (current_lamp < num_lamps) begin
                            // Try both assignments (0 and 1)
                            if (assignment[current_lamp] == 1'b0) begin
                                assignment[current_lamp] <= 1'b1;
                                stack[stack_ptr] <= assignment;
                                stack_ptr <= stack_ptr + 4'd1;
                                current_lamp <= current_lamp + 4'd1;
                            end else begin
                                // Check if this assignment causes conflicts
                                conflict_found <= 1'b0;
                                i <= 4'd0;
                                j <= 4'd0;
                                state <= SOLVE;
                            end
                        end else begin
                            // Backtrack
                            if (stack_ptr > 4'd0) begin
                                stack_ptr <= stack_ptr - 4'd1;
                                assignment <= stack[stack_ptr];
                                current_lamp <= current_lamp - 4'd1;
                                assignment[current_lamp] <= 1'b1;
                            end else begin
                                // No solution found
                                state <= FINISH;
                                result <= 1'b0;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Conflict checking logic
    always @(posedge clk) begin
        if (state == SOLVE && current_lamp < num_lamps && assignment[current_lamp] == 1'b1) begin
            // Check row conflicts
            if (i < num_lamps) begin
                lamp_i_row <= loaded_row[i];
                lamp_i_col <= loaded_col[i];

                if (j < num_lamps && j != i) begin
                    lamp_j_row <= loaded_row[j];
                    lamp_j_col <= loaded_col[j];

                    // Check if both lamps can light the same square in row mode
                    if (assignment[i] == 1'b0 && assignment[j] == 1'b0) begin
                        if (lamp_i_row == lamp_j_row && 
                            (lamp_i_col <= lamp_j_col && lamp_j_col <= lamp_i_col + max_reach) &&
                            (lamp_j_col <= lamp_i_col && lamp_i_col <= lamp_j_col + max_reach)) begin
                            conflict_found <= 1'b1;
                        end
                    end

                    // Check if both lamps can light the same square in column mode
                    if (assignment[i] == 1'b1 && assignment[j] == 1'b1) begin
                        if (lamp_i_col == lamp_j_col && 
                            (lamp_i_row <= lamp_j_row && lamp_j_row <= lamp_i_row + max_reach) &&
                            (lamp_j_row <= lamp_i_row && lamp_i_row <= lamp_j_row + max_reach)) begin
                            conflict_found <= 1'b1;
                        end
                    end

                    j <= j + 4'd1;
                end else begin
                    j <= 4'd0;
                    i <= i + 4'd1;
                end
            end else begin
                if (!conflict_found) begin
                    // No conflicts, proceed to next lamp
                    stack[stack_ptr] <= assignment;
                    stack_ptr <= stack_ptr + 4'd1;
                    current_lamp <= current_lamp + 4'd1;
                end else begin
                    // Conflict found, try next assignment
                    assignment[current_lamp] <= 1'b1;
                end
                i <= 4'd0;
                j <= 4'd0;
            end
        end
    end

endmodule