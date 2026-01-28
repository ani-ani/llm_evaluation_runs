module SquareKiller(
    input clk,
    input rst_n,
    input start,
    input [3:0] row0,
    input [3:0] row1,
    input [3:0] row2,
    input [3:0] row3,
    input [2:0] R,
    input [2:0] C,
    output reg signed [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_SIZE = 3'd1;
    localparam [2:0] CHECK_POS  = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] current_size;
    reg [2:0] current_row;
    reg [2:0] current_col;
    reg [2:0] max_size;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            current_size <= 3'd0;
            current_row <= 3'd0;
            current_col <= 3'd0;
            max_size <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_SIZE;
                        max_size <= (R < C) ? R : C;
                        current_size <= max_size;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_SIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_size >= 2'd2) begin
                        current_row <= 3'd0;
                        current_col <= 3'd0;
                        next_state <= CHECK_POS;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                CHECK_POS: begin
                    cycle_count <= cycle_count + 8'd1;
                    reg [3:0] submatrix [0:3];
                    reg [3:0] rotated [0:3];
                    integer i, j;

                    // Extract submatrix
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < current_size) begin
                            case (i)
                                0: submatrix[i] = row0 >> current_col;
                                1: submatrix[i] = row1 >> current_col;
                                2: submatrix[i] = row2 >> current_col;
                                3: submatrix[i] = row3 >> current_col;
                            endcase
                        end
                    end

                    // Check if submatrix is symmetric under 180-degree rotation
                    reg is_killer = 1'b1;
                    for (i = 0; i < current_size; i = i + 1) begin
                        for (j = 0; j < current_size; j = j + 1) begin
                            if (submatrix[i][j] != submatrix[current_size - 1 - i][current_size - 1 - j]) begin
                                is_killer = 1'b0;
                            end
                        end
                    end

                    if (is_killer) begin
                        result <= current_size;
                        next_state <= FINISH;
                    end else begin
                        // Move to next position
                        current_col <= current_col + 1'd1;
                        if (current_col + current_size > C) begin
                            current_col <= 3'd0;
                            current_row <= current_row + 1'd1;
                            if (current_row + current_size > R) begin
                                current_row <= 3'd0;
                                current_size <= current_size - 1'd1;
                                next_state <= CHECK_SIZE;
                            end
                        end
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (result == 4'd0) begin
                        result <= 4'b1111; // -1 if no killer found
                    end
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule