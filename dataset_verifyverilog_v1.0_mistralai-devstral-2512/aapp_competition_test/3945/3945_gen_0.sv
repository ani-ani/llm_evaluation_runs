module minimal_max_height(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [255:0] grid_flat,
    output reg [255:0] result_flat,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ROW_RANKS = 3'd1;
    localparam [2:0] COMPUTE_COL_RANKS = 3'd2;
    localparam [2:0] COMPUTE_ANSWERS = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Grid and result storage
    reg [7:0] grid [0:15][0:15];
    reg [7:0] result [0:15][0:15];

    // Row and column rank storage
    reg [7:0] row_rank [0:15][0:15];
    reg [7:0] col_rank [0:15][0:15];

    // Row and column unique counts
    reg [7:0] row_unique_count [0:15];
    reg [7:0] col_unique_count [0:15];

    // Current processing indices
    reg [3:0] current_row;
    reg [3:0] current_col;

    // Temporary storage for sorting
    reg [7:0] row_temp [0:15];
    reg [7:0] col_temp [0:15];

    // Initialize grid from flat input
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_row <= 4'd0;
            current_col <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid[i][j] <= 8'd0;
                    result[i][j] <= 8'd0;
                    row_rank[i][j] <= 8'd0;
                    col_rank[i][j] <= 8'd0;
                end
                row_unique_count[i] <= 8'd0;
                col_unique_count[i] <= 8'd0;
            end
        end else begin
            // Flatten grid input to 2D array
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid[i][j] <= grid_flat[(i*16 + j)*8 +: 8];
                end
            end

            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_ROW_RANKS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_ROW_RANKS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_row < n) begin
                        // Copy current row to temp
                        for (j = 0; j < 16; j = j + 1) begin
                            row_temp[j] <= grid[current_row][j];
                        end
                        next_state <= COMPUTE_ROW_RANKS;
                        current_row <= current_row + 4'd1;
                    end else begin
                        current_row <= 4'd0;
                        next_state <= COMPUTE_COL_RANKS;
                    end
                end

                COMPUTE_COL_RANKS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_col < m) begin
                        // Copy current column to temp
                        for (i = 0; i < 16; i = i + 1) begin
                            col_temp[i] <= grid[i][current_col];
                        end
                        next_state <= COMPUTE_COL_RANKS;
                        current_col <= current_col + 4'd1;
                    end else begin
                        current_col <= 4'd0;
                        next_state <= COMPUTE_ANSWERS;
                    end
                end

                COMPUTE_ANSWERS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_row < n && current_col < m) begin
                        // Compute answer for current element
                        reg [7:0] row_r, col_r, row_len, col_len;
                        row_r = row_rank[current_row][current_col];
                        col_r = col_rank[current_row][current_col];
                        row_len = row_unique_count[current_row];
                        col_len = col_unique_count[current_col];
                        result[current_row][current_col] <= 
                            (row_r > col_r ? row_r : col_r) + 
                            ((row_len - row_r) > (col_len - col_r) ? (row_len - row_r) : (col_len - col_r));
                        
                        if (current_col == m - 1) begin
                            current_col <= 4'd0;
                            current_row <= current_row + 4'd1;
                        end else begin
                            current_col <= current_col + 4'd1;
                        end
                        next_state <= COMPUTE_ANSWERS;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            state <= next_state;
        end
    end

    // Compute row ranks (simplified for synthesis)
    always @(posedge clk) begin
        if (state == COMPUTE_ROW_RANKS && current_row < n) begin
            reg [7:0] unique_values [0:15];
            reg [7:0] unique_count = 8'd0;
            reg [7:0] temp_rank [0:15];
            integer k, l;

            // Find unique values in row
            for (k = 0; k < 16; k = k + 1) begin
                reg [7:0] val = row_temp[k];
                reg found = 1'b0;
                for (l = 0; l < unique_count; l = l + 1) begin
                    if (unique_values[l] == val) begin
                        found = 1'b1;
                    end
                end
                if (!found && val != 8'd0) begin
                    unique_values[unique_count] <= val;
                    unique_count <= unique_count + 8'd1;
                end
            end

            // Sort unique values (bubble sort for simplicity)
            for (k = 0; k < unique_count - 1; k = k + 1) begin
                for (l = 0; l < unique_count - k - 1; l = l + 1) begin
                    if (unique_values[l] > unique_values[l + 1]) begin
                        reg [7:0] temp = unique_values[l];
                        unique_values[l] <= unique_values[l + 1];
                        unique_values[l + 1] <= temp;
                    end
                end
            end

            // Assign ranks
            row_unique_count[current_row] <= unique_count;
            for (k = 0; k < 16; k = k + 1) begin
                reg [7:0] val = row_temp[k];
                for (l = 0; l < unique_count; l = l + 1) begin
                    if (unique_values[l] == val) begin
                        row_rank[current_row][k] <= l;
                    end
                end
            end
        end
    end

    // Compute column ranks (simplified for synthesis)
    always @(posedge clk) begin
        if (state == COMPUTE_COL_RANKS && current_col < m) begin
            reg [7:0] unique_values [0:15];
            reg [7:0] unique_count = 8'd0;
            integer k, l;

            // Find unique values in column
            for (k = 0; k < 16; k = k + 1) begin
                reg [7:0] val = col_temp[k];
                reg found = 1'b0;
                for (l = 0; l < unique_count; l = l + 1) begin
                    if (unique_values[l] == val) begin
                        found = 1'b1;
                    end
                end
                if (!found && val != 8'd0) begin
                    unique_values[unique_count] <= val;
                    unique_count <= unique_count + 8'd1;
                end
            end

            // Sort unique values (bubble sort for simplicity)
            for (k = 0; k < unique_count - 1; k = k + 1) begin
                for (l = 0; l < unique_count - k - 1; l = l + 1) begin
                    if (unique_values[l] > unique_values[l + 1]) begin
                        reg [7:0] temp = unique_values[l];
                        unique_values[l] <= unique_values[l + 1];
                        unique_values[l + 1] <= temp;
                    end
                end
            end

            // Assign ranks
            col_unique_count[current_col] <= unique_count;
            for (k = 0; k < 16; k = k + 1) begin
                reg [7:0] val = col_temp[k];
                for (l = 0; l < unique_count; l = l + 1) begin
                    if (unique_values[l] == val) begin
                        col_rank[k][current_col] <= l;
                    end
                end
            end
        end
    end

    // Flatten result to output
    always @(posedge clk) begin
        if (state == FINISH) begin
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    result_flat[(i*16 + j)*8 +: 8] <= result[i][j];
                end
            end
        end
    end

endmodule