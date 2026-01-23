module bacteria_game #(
    parameter N = 4,
    parameter M = 4,
    parameter K = 3,
    parameter MAX_CYCLES = 1048576
) (
    input clk,
    input rst_n,
    input start,
    input [4:0] trap_row, trap_col,
    input [4:0] start_row [K-1:0], start_col [K-1:0],
    input [1:0] start_dir [K-1:0],
    input [3:0] grid [K-1:0][N-1:0][M-1:0],
    output reg [19:0] duration,
    output reg done,
    output reg error
);

// Registers
reg [2:0] state;
reg [19:0] current_cycle;
reg [19:0] duration_reg;
reg [1:0] dir [K-1:0];
reg [N-1:0] row_pos [K-1:0];
reg [M-1:0] col_pos [K-1:0];

// Next state registers
reg [2:0] next_state;
reg [19:0] next_current_cycle;
reg [19:0] next_duration;
reg done_next;
reg error_next;
reg [1:0] next_dir [K-1:0];
reg [N-1:0] next_row_pos [K-1:0];
reg [M-1:0] next_col_pos [K-1:0];

always @(*) begin
    // Default assignments
    next_state = state;
    next_current_cycle = current_cycle;
    next_duration = duration_reg;
    done_next = done;
    error_next = error;
    next_row_pos = row_pos;
    next_col_pos = col_pos;
    next_dir = dir;

    if (!rst_n) begin
        next_state <= 3'd0;
        next_current_cycle <= 20'd0;
        next_duration <= 20'd0;
        done_next <= 1'b0;
        error_next <= 1'b0;
        next_row_pos[0] <= 1;
        next_row_pos[1] <= 1;
        next_row_pos[2] <= 1;
        next_col_pos[0] <= 1;
        next_col_pos[1] <= 1;
        next_col_pos[2] <= 1;
        next_dir[0] <= 2'd0;
        next_dir[1] <= 2'd0;
        next_dir[2] <= 2'd0;
    end else begin
        if (state == 3'd0) begin // IDLE
            if (start) begin
                next_state <= 3'd1;
            end
        end else if (state == 3'd1) begin // LOAD
            next_row_pos[0] <= start_row[0];
            next_row_pos[1] <= start_row[1];
            next_row_pos[2] <= start_row[2];
            next_col_pos[0] <= start_col[0];
            next_col_pos[1] <= start_col[1];
            next_col_pos[2] <= start_col[2];
            next_dir[0] <= start_dir[0];
            next_dir[1] <= start_dir[1];
            next_dir[2] <= start_dir[2];
            next_state <= 3'd2;
        end else if (state == 3'd2) begin // CHECK
            reg [1:0] all_at_trap = 2'd0;
            if (row_pos[0] == trap_row && col_pos[0] == trap_col) all_at_trap = all_at_trap +1;
            if (row_pos[1] == trap_row && col_pos[1] == trap_col) all_at_trap = all_at_trap +1;
            if (row_pos[2] == trap_row && col_pos[2] == trap_col) all_at_trap = all_at_trap +1;
            if (all_at_trap == K) begin
                next_state <= 3'd4;
                next_duration <= current_cycle;
                done_next <= 1'b1;
            end else begin
                if (current_cycle >= MAX_CYCLES) begin
                    next_state <= 3'd5;
                    error_next <= 1'b1;
                end else begin
                    next_state <= 3'd3;
                end
            end
        end else if (state == 3'd3) begin // UPDATE
            // Bacterium 0
            reg [3:0] X0;
            X0 = grid[0][row_pos[0]-1][col_pos[0]-1];
            reg [1:0] new_dir0;
            new_dir0 = (dir[0] + X0) %4;
            reg [3:0] new_row0, new_col0;
            new_row0 = row_pos[0];
            new_col0 = col_pos[0];
            case(new_dir0)
                0: new_row0 = row_pos[0] -1;
                1: new_col0 = col_pos[0] +1;
                2: new_row0 = row_pos[0] +1;
                3: new_col0 = col_pos[0] -1;
            endcase
            if (new_row0 <1 || new_row0 >N || new_col0 <1 || new_col0 >M) begin
                new_dir0 = (new_dir0 + 2) %4;
                new_row0 = row_pos[0];
                new_col0 = col_pos[0];
                case(new_dir0)
                    0: new_row0 = row_pos[0] -1;
                    1: new_col0 = col_pos[0] +1;
                    2: new_row0 = row_pos[0] +1;
                    3: new_col0 = col_pos[0] -1;
                endcase
                if (new_row0 <1 || new_row0 >N || new_col0 <1 || new_col0 >M) begin
                    new_row0 = row_pos[0];
                    new_col0 = col_pos[0];
                end
            end
            next_dir[0] <= new_dir0;
            next_row_pos[0] <= new_row0;
            next_col_pos[0] <= new_col0;

            // Bacterium 1
            reg [3:0] X1;
            X1 = grid[1][row_pos[1]-1][col_pos[1]-1];
            reg [1:0] new_dir1;
            new_dir1 = (dir[1] + X1) %4;
            reg [3:0] new_row1, new_col1;
            new_row1 = row_pos[1];
            new_col1 = col_pos[1];
            case(new_dir1)
                0: new_row1 = row_pos[1] -1;
                1: new_col1 = col_pos[1] +1;
                2: new_row1 = row_pos[1] +1;
                3: new_col1 = col_pos[1] -1;
            endcase
            if (new_row1 <1 || new_row1 >N || new_col1 <1 || new_col1 >M) begin
                new_dir1 = (new_dir1 + 2) %4;
                new_row1 = row_pos[1];
                new_col1 = col_pos[1];
                case(new_dir1)
                    0: new_row1 = row_pos[1] -1;
                    1: new_col1 = col_pos[1] +1;
                    2: new_row1 = row_pos[1] +1;
                    3: new_col1 = col_pos[1] -1;
                endcase
                if (new_row1 <1 || new_row1 >N || new_col1 <1 || new_col1 >M) begin
                    new_row1 = row_pos[1];
                    new_col1 = col_pos[1];
                end
            end
            next_dir[1] <= new_dir1;
            next_row_pos[1] <= new_row1;
            next_col_pos[1] <= new_col1;

            // Bacterium 2
            reg [3:0] X2;
            X2 = grid[2][row_pos[2]-1][col_pos[2]-1];
            reg [1:0] new_dir2;
            new_dir2 = (dir[2] + X2) %4;
            reg [3:0] new_row2, new_col2;
            new_row2 = row_pos[2];
            new_col2 = col_pos[2];
            case(new_dir2)
                0: new_row2 = row_pos[2] -1;
                1: new_col2 = col_pos[2] +1;
                2: new_row2 = row_pos[2] +1;
                3: new_col2 = col_pos[2] -1;
            endcase
            if (new_row2 <1 || new_row2 >N || new_col2 <1 || new_col2 >M) begin
                new_dir2 = (new_dir2 + 2) %4;
                new_row2 = row_pos[2];
                new_col2 = col_pos[2];
                case(new_dir2)
                    0: new_row2 = row_pos[2] -1;
                    1: new_col2 = col_pos[2] +1;
                    2: new_row2 = row_pos[2] +1;
                    3: new_col2 = col_pos[2] -1;
                endcase
                if (new_row2 <1 || new_row2 >N || new_col2 <1 || new_col2 >M) begin
                    new_row2 = row_pos[2];
                    new_col2 = col_pos[2];
                end
            end
            next_dir[2] <= new_dir2;
            next_row_pos[2] <= new_row2;
            next_col_pos[2] <= new_col2;

            // Update current_cycle and next state
            if (current_cycle < MAX_CYCLES) begin
                next_current_cycle = current_cycle +1;
            end
            next_state <= 3'd2;
        end else if (state == 3'd4) begin // DONE
            next_state <= 3'd4;
        end else if (state == 3'd5) begin // TIMEOUT
            next_state <= 3'd5;
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= next_state;
        current_cycle <= next_current_cycle;
        duration_reg <= next_duration;
        done <= done_next;
        error <= error_next;
        row_pos <= next_row_pos;
        col_pos <= next_col_pos;
        dir <= next_dir;
    end else begin
        state <= next_state;
        current_cycle <= next_current_cycle;
        duration_reg <= next_duration;
        done <= done_next;
        error <= error_next;
        row_pos <= next_row_pos;
        col_pos <= next_col_pos;
        dir <= next_dir;
    end
end

// Output assignments
assign duration = duration_reg[19:0];
assign done = done_next;
assign error = error_next;

endmodule