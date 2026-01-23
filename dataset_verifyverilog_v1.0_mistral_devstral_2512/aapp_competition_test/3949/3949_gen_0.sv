module monopole_magnet(
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
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ROW_CHECK = 3'd1;
    localparam [2:0] COL_CHECK = 3'd2;
    localparam [2:0] CONSISTENCY_CHECK = 3'd3;
    localparam [2:0] COMPONENT_COUNT = 3'd4;
    localparam [2:0] DONE = 3'd5;
    localparam [2:0] ERROR = 3'd6;

    localparam [7:0] GRID_SIZE = 8'd8;
    localparam [15:0] ERROR_VALUE = 16'hFFFF;

    // State and control signals
    reg [2:0] state, next_state;
    reg [7:0] row_idx, col_idx;
    reg [7:0] component_count;
    reg [7:0] empty_rows, empty_cols;
    reg [7:0] row_start [0:7], row_end [0:7];
    reg [7:0] col_start [0:7], col_end [0:7];
    reg [7:0] visited [0:7];
    reg [7:0] queue [0:63];
    reg [5:0] queue_head, queue_tail;
    reg [7:0] current_row, current_col;
    reg row_valid [0:7], col_valid [0:7];
    reg row_contiguous [0:7], col_contiguous [0:7];
    reg consistency_valid;
    reg [7:0] i, j, k;

    // Grid array for easier access
    reg [7:0] grid [0:7];

    // Initialize grid array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grid[0] <= 8'd0;
            grid[1] <= 8'd0;
            grid[2] <= 8'd0;
            grid[3] <= 8'd0;
            grid[4] <= 8'd0;
            grid[5] <= 8'd0;
            grid[6] <= 8'd0;
            grid[7] <= 8'd0;
        end else begin
            grid[0] <= grid_0;
            grid[1] <= grid_1;
            grid[2] <= grid_2;
            grid[3] <= grid_3;
            grid[4] <= grid_4;
            grid[5] <= grid_5;
            grid[6] <= grid_6;
            grid[7] <= grid_7;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            component_count <= 8'd0;
            empty_rows <= 8'd0;
            empty_cols <= 8'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
            consistency_valid <= 1'b0;
            
            // Initialize visited array
            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 8'd0;
            end
            
            // Initialize row and col validity
            for (i = 0; i < 8; i = i + 1) begin
                row_valid[i] <= 1'b0;
                col_valid[i] <= 1'b0;
                row_contiguous[i] <= 1'b1;
                col_contiguous[i] <= 1'b1;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = ROW_CHECK;
                end
            end
            
            ROW_CHECK: begin
                if (row_idx == 7) begin
                    next_state = COL_CHECK;
                end
            end
            
            COL_CHECK: begin
                if (col_idx == 7) begin
                    next_state = CONSISTENCY_CHECK;
                end
            end
            
            CONSISTENCY_CHECK: begin
                next_state = COMPONENT_COUNT;
            end
            
            COMPONENT_COUNT: begin
                if (component_count == 0 && queue_head == queue_tail) begin
                    if (consistency_valid) begin
                        next_state = DONE;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Row check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_idx <= 8'd0;
        end else if (state == ROW_CHECK) begin
            // Check if row is empty
            if (grid[row_idx] == 8'd0) begin
                empty_rows[row_idx] <= 1'b1;
                row_valid[row_idx] <= 1'b1;
            end else begin
                // Find first and last black cell
                for (i = 0; i < 8; i = i + 1) begin
                    if (grid[row_idx][i]) begin
                        row_start[row_idx] <= i;
                        break;
                    end
                end
                for (i = 7; i >= 0; i = i - 1) begin
                    if (grid[row_idx][i]) begin
                        row_end[row_idx] <= i;
                        break;
                    end
                end
                
                // Check for gaps
                row_contiguous[row_idx] <= 1'b1;
                for (i = row_start[row_idx]; i <= row_end[row_idx]; i = i + 1) begin
                    if (!grid[row_idx][i]) begin
                        row_contiguous[row_idx] <= 1'b0;
                        break;
                    end
                end
                
                row_valid[row_idx] <= row_contiguous[row_idx];
            end
            
            // Move to next row
            if (row_idx < 7) begin
                row_idx <= row_idx + 8'd1;
            end
        end
    end

    // Column check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_idx <= 8'd0;
        end else if (state == COL_CHECK) begin
            // Check if column is empty
            reg [7:0] col_data;
            for (i = 0; i < 8; i = i + 1) begin
                col_data[i] = grid[i][col_idx];
            end
            
            if (col_data == 8'd0) begin
                empty_cols[col_idx] <= 1'b1;
                col_valid[col_idx] <= 1'b1;
            end else begin
                // Find first and last black cell
                for (i = 0; i < 8; i = i + 1) begin
                    if (col_data[i]) begin
                        col_start[col_idx] <= i;
                        break;
                    end
                end
                for (i = 7; i >= 0; i = i - 1) begin
                    if (col_data[i]) begin
                        col_end[col_idx] <= i;
                        break;
                    end
                end
                
                // Check for gaps
                col_contiguous[col_idx] <= 1'b1;
                for (i = col_start[col_idx]; i <= col_end[col_idx]; i = i + 1) begin
                    if (!col_data[i]) begin
                        col_contiguous[col_idx] <= 1'b0;
                        break;
                    end
                end
                
                col_valid[col_idx] <= col_contiguous[col_idx];
            end
            
            // Move to next column
            if (col_idx < 7) begin
                col_idx <= col_idx + 8'd1;
            end
        end
    end

    // Consistency check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            consistency_valid <= 1'b0;
        end else if (state == CONSISTENCY_CHECK) begin
            // Check if all rows and columns are valid
            reg all_rows_valid = 1'b1;
            reg all_cols_valid = 1'b1;
            for (i = 0; i < 8; i = i + 1) begin
                if (!row_valid[i]) begin
                    all_rows_valid = 1'b0;
                end
                if (!col_valid[i]) begin
                    all_cols_valid = 1'b0;
                end
            end
            
            // Check consistency: empty rows xor empty cols should be 0
            reg has_empty_rows = 1'b0;
            reg has_empty_cols = 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                if (empty_rows[i]) begin
                    has_empty_rows = 1'b1;
                end
                if (empty_cols[i]) begin
                    has_empty_cols = 1'b1;
                end
            end
            
            consistency_valid <= all_rows_valid && all_cols_valid && (has_empty_rows == has_empty_cols);
            next_state = COMPONENT_COUNT;
        end
    end

    // Component counting logic (BFS)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            component_count <= 8'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            current_row <= 8'd0;
            current_col <= 8'd0;
        end else if (state == COMPONENT_COUNT) begin
            // Initialize queue and visited for BFS
            if (component_count == 0 && queue_head == queue_tail) begin
                // Find first unvisited black cell
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (grid[i][j] && !visited[i][j]) begin
                            queue[queue_tail] = {i, j};
                            queue_tail = queue_tail + 6'd1;
                            visited[i][j] = 1'b1;
                            component_count = component_count + 8'd1;
                            break;
                        end
                    end
                    if (queue_tail != queue_head) break;
                end
            end else if (queue_head != queue_tail) begin
                // Process queue
                current_row = queue[queue_head][7:4];
                current_col = queue[queue_head][3:0];
                queue_head = queue_head + 6'd1;
                
                // Check neighbors (4-directional)
                for (i = -1; i <= 1; i = i + 1) begin
                    for (j = -1; j <= 1; j = j + 1) begin
                        if (i == 0 || j == 0) begin
                            reg [7:0] new_row = current_row + i;
                            reg [7:0] new_col = current_col + j;
                            if (new_row < 8 && new_col < 8 && grid[new_row][new_col] && !visited[new_row][new_col]) begin
                                visited[new_row][new_col] = 1'b1;
                                queue[queue_tail] = {new_row, new_col};
                                queue_tail = queue_tail + 6'd1;
                            end
                        end
                    end
                end
            end
            
            // Check if done
            if (queue_head == queue_tail) begin
                reg all_visited = 1'b1;
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (grid[i][j] && !visited[i][j]) begin
                            all_visited = 1'b0;
                        end
                    end
                end
                
                if (all_visited) begin
                    if (consistency_valid) begin
                        next_state = DONE;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                DONE: begin
                    result <= component_count;
                    done <= 1'b1;
                end
                ERROR: begin
                    result <= ERROR_VALUE;
                    done <= 1'b1;
                end
                default: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule