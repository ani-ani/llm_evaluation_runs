module treasure_island (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_in,
    input grid_wr,
    input [1:0] row_idx,
    input [1:0] col_idx,
    output reg [1:0] result,
    output reg done,
    output reg valid
);

    // Grid storage (4x4)
    reg [3:0] grid [0:3][0:3];
    
    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        LOAD_GRID,
        FIND_PATH,
        COUNT_CRITICAL,
        COMPUTE_RESULT,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // DP arrays
    reg [7:0] forward_dp [0:3][0:3];
    reg [7:0] backward_dp [0:3][0:3];
    
    // Counters for grid traversal
    reg [1:0] i, j;
    reg [7:0] total_paths;
    reg [1:0] critical_count;
    reg [1:0] row, col;
    reg [7:0] temp_forward [0:3][0:3];
    reg [7:0] temp_backward [0:3][0:3];
    
    // Initialize grid
    integer k, l;
    initial begin
        for (k = 0; k < 4; k = k + 1) begin
            for (l = 0; l < 4; l = l + 1) begin
                grid[k][l] = 4'b0;
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            row <= 0;
            col <= 0;
            critical_count <= 0;
            total_paths <= 0;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
            end
            LOAD_GRID: begin
                if (grid_wr) next_state = LOAD_GRID;
                else next_state = FIND_PATH;
            end
            FIND_PATH: begin
                if (i == 3 && j == 3) next_state = COUNT_CRITICAL;
                else next_state = FIND_PATH;
            end
            COUNT_CRITICAL: begin
                if (row == 3 && col == 3) next_state = COMPUTE_RESULT;
                else next_state = COUNT_CRITICAL;
            end
            COMPUTE_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Load grid
    always @(posedge clk) begin
        if (current_state == LOAD_GRID && grid_wr) begin
            grid[row_idx][col_idx] <= grid_in;
        end
    end
    
    // Forward DP calculation
    always @(posedge clk) begin
        if (current_state == FIND_PATH) begin
            if (i == 0 && j == 0) begin
                temp_forward[i][j] <= (grid[i][j][0] == 0) ? 1 : 0;
            end else if (i == 0) begin
                temp_forward[i][j] <= (grid[i][j][0] == 0) ? temp_forward[i][j-1] : 0;
            end else if (j == 0) begin
                temp_forward[i][j] <= (grid[i][j][0] == 0) ? temp_forward[i-1][j] : 0;
            end else begin
                temp_forward[i][j] <= (grid[i][j][0] == 0) ? (temp_forward[i-1][j] + temp_forward[i][j-1]) : 0;
            end
            
            if (j == 3) begin
                j <= 0;
                i <= i + 1;
            end else begin
                j <= j + 1;
            end
        end
    end
    
    // Backward DP calculation
    always @(posedge clk) begin
        if (current_state == COUNT_CRITICAL) begin
            if (row == 3 && col == 3) begin
                temp_backward[row][col] <= (grid[row][col][0] == 0) ? 1 : 0;
            end else if (row == 3) begin
                temp_backward[row][col] <= (grid[row][col][0] == 0) ? temp_backward[row][col+1] : 0;
            end else if (col == 3) begin
                temp_backward[row][col] <= (grid[row][col][0] == 0) ? temp_backward[row+1][col] : 0;
            end else begin
                temp_backward[row][col] <= (grid[row][col][0] == 0) ? (temp_backward[row+1][col] + temp_backward[row][col+1]) : 0;
            end
            
            if (col == 0) begin
                col <= 3;
                row <= row + 1;
            end else begin
                col <= col - 1;
            end
        end
    end
    
    // Compute result
    always @(posedge clk) begin
        if (current_state == COMPUTE_RESULT) begin
            total_paths <= temp_forward[3][3];
            if (total_paths == 0) begin
                result <= 0;
            end else begin
                critical_count <= 0;
                for (row = 0; row < 4; row = row + 1) begin
                    for (col = 0; col < 4; col = col + 1) begin
                        if ((row != 0 || col != 0) && (row != 3 || col != 3)) begin
                            if (temp_forward[row][col] * temp_backward[row][col] == total_paths) begin
                                critical_count <= critical_count + 1;
                            end
                        end
                    end
                end
                if (critical_count > 0) begin
                    result <= 1;
                end else begin
                    result <= 2;
                end
            end
            done <= 1;
            valid <= 1;
        end else begin
            done <= 0;
            valid <= 0;
        end
    end
    
    // Copy temp arrays to main arrays
    always @(posedge clk) begin
        if (current_state == FIND_PATH && i == 3 && j == 3) begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    forward_dp[row][col] <= temp_forward[row][col];
                end
            end
        end
        if (current_state == COUNT_CRITICAL && row == 3 && col == 3) begin
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    backward_dp[row][col] <= temp_backward[row][col];
                end
            end
        end
    end

endmodule