module grasshopper_path (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [2:0] start_r,
    input [2:0] start_c,
    input [7:0] petals [0:7][0:7],
    output reg [7:0] max_path_length,
    output reg done
);

    // Parameters
    parameter MAX_N = 8;
    parameter IDLE = 3'b000;
    parameter LOAD_GRID = 3'b001;
    parameter COMPUTE_DP = 3'b010;
    parameter FIND_MAX = 3'b011;
    parameter COMPLETE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [7:0] petal_reg [0:MAX_N-1][0:MAX_N-1];
    reg [7:0] dp [0:MAX_N*MAX_N-1];
    reg [5:0] cell_idx;
    reg [5:0] jump_idx;
    reg [5:0] max_idx;
    reg [7:0] max_val;
    reg [5:0] sorted_cells [0:MAX_N*MAX_N-1];
    reg [5:0] current_cell;
    reg [5:0] next_cell;
    reg [5:0] r, c;
    reg [5:0] jump_r, jump_c;
    reg [7:0] current_petal;
    reg [7:0] jump_petal;
    reg [7:0] temp_dp;
    reg [5:0] counter;
    reg [5:0] i, j;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_path_length <= 0;
            cell_idx <= 0;
            jump_idx <= 0;
            max_idx <= 0;
            max_val <= 0;
            counter <= 0;
            i <= 0;
            j <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_GRID;
                        cell_idx <= 0;
                    end
                end
                LOAD_GRID: begin
                    if (cell_idx == MAX_N*MAX_N-1) begin
                        state <= COMPUTE_DP;
                        cell_idx <= 0;
                        counter <= 0;
                    end else begin
                        cell_idx <= cell_idx + 1;
                    end
                end
                COMPUTE_DP: begin
                    if (counter == MAX_N*MAX_N-1) begin
                        state <= FIND_MAX;
                        max_idx <= 0;
                        max_val <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                FIND_MAX: begin
                    state <= COMPLETE;
                    done <= 1;
                end
                COMPLETE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Load grid into internal registers
    always @(posedge clk) begin
        if (state == LOAD_GRID && cell_idx < MAX_N*MAX_N) begin
            r <= cell_idx[5:3];
            c <= cell_idx[2:0];
            if (r < N && c < N) begin
                petal_reg[r][c] <= petals[r][c];
            end else begin
                petal_reg[r][c] <= 0;
            end
        end
    end

    // Sort cells by petal count (descending)
    always @(posedge clk) begin
        if (state == COMPUTE_DP && counter == 0) begin
            // Initialize sorted_cells (simplified for synthesis)
            for (i = 0; i < MAX_N*MAX_N; i = i + 1) begin
                sorted_cells[i] <= i;
            end
            // Bubble sort (simplified for synthesis)
            for (i = 0; i < MAX_N*MAX_N; i = i + 1) begin
                for (j = 0; j < MAX_N*MAX_N - i - 1; j = j + 1) begin
                    r <= sorted_cells[j][5:3];
                    c <= sorted_cells[j][2:0];
                    reg [7:0] petal1 = petal_reg[r][c];
                    r <= sorted_cells[j+1][5:3];
                    c <= sorted_cells[j+1][2:0];
                    reg [7:0] petal2 = petal_reg[r][c];
                    if (petal1 < petal2) begin
                        reg [5:0] temp = sorted_cells[j];
                        sorted_cells[j] <= sorted_cells[j+1];
                        sorted_cells[j+1] <= temp;
                    end
                end
            end
        end
    end

    // Compute DP values
    always @(posedge clk) begin
        if (state == COMPUTE_DP && counter < MAX_N*MAX_N) begin
            current_cell <= sorted_cells[counter];
            r <= current_cell[5:3];
            c <= current_cell[2:0];
            current_petal <= petal_reg[r][c];
            temp_dp <= 1;
            // Check all possible jump positions
            for (jump_r = 0; jump_r < MAX_N; jump_r = jump_r + 1) begin
                for (jump_c = 0; jump_c < MAX_N; jump_c = jump_c + 1) begin
                    if ((jump_r == r && jump_c != c) || (jump_c == c && jump_r != r)) begin
                        if ((jump_r == r && (jump_c < c-1 || jump_c > c+1)) || 
                            (jump_c == c && (jump_r < r-1 || jump_r > r+1))) begin
                            jump_petal <= petal_reg[jump_r][jump_c];
                            if (jump_petal > current_petal) begin
                                reg [5:0] jump_cell = {jump_r, jump_c};
                                if (dp[jump_cell] + 1 > temp_dp) begin
                                    temp_dp <= dp[jump_cell] + 1;
                                end
                            end
                        end
                    end
                end
            end
            dp[current_cell] <= temp_dp;
        end
    end

    // Find maximum path length at start position
    always @(posedge clk) begin
        if (state == FIND_MAX) begin
            reg [5:0] start_cell = {start_r, start_c};
            max_path_length <= dp[start_cell];
        end
    end

endmodule