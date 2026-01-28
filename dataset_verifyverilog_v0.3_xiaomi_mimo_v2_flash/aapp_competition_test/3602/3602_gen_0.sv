module lamp_assigner (
    input clk,
    input rst_n,
    input start,
    input [3:0] k,  // Number of lamps (1-16)
    input [31:0] packed_lamp_rows,  // 16 lamps × 2 bits each
    input [31:0] packed_lamp_cols,
    output reg result,
    output reg done
);

// Constants
parameter GRID_SIZE = 4;
parameter MAX_REACH = 2;  // Covers up to 5 squares
parameter MAX_LAMPS = 16;

// States
localparam IDLE = 0;
localparam PRECOMPUTE = 1;
localparam INIT_ASSIGN = 2;
localparam CHECK_ASSIGN = 3;
localparam ASSIGN_PASS = 4;
localparam ASSIGN_FAIL = 5;
localparam FINISHED = 6;

// Registers
reg [3:0] state;
reg [15:0] assignment_counter;  // Current assignment
reg [15:0] max_assignment;      // 2^k - 1
reg [1:0] lamp_rows [0:15];     // Unpacked rows
reg [1:0] lamp_cols [0:15];     // Unpacked cols
reg [1:0] row_interval_start [0:15];
reg [1:0] row_interval_end [0:15];
reg [1:0] col_interval_start [0:15];
reg [1:0] col_interval_end [0:15];

// Intermediate storage for checking
reg [1:0] row_group_col [0:3][0:3];   // [row][index] -> column
reg [1:0] row_group_start [0:3][0:3]; // [row][index] -> start
reg [1:0] row_group_end [0:3][0:3];   // [row][index] -> end
reg [1:0] row_group_count [0:3];      // Count per row
reg [1:0] col_group_row [0:3][0:3];   // [col][index] -> row
reg [1:0] col_group_start [0:3][0:3]; // [col][index] -> start
reg [1:0] col_group_end [0:3][0:3];   // [col][index] -> end
reg [1:0] col_group_count [0:3];      // Count per col

// Sorting/checking variables
reg [3:0] i, j;
reg [2:0] check_idx;
reg overlap_found;
reg row_check_done;
reg col_check_done;

// Unpack inputs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Clear all
        for (i = 0; i < 16; i = i + 1) begin
            lamp_rows[i] <= 2'd0;
            lamp_cols[i] <= 2'd0;
            row_interval_start[i] <= 2'd0;
            row_interval_end[i] <= 2'd0;
            col_interval_start[i] <= 2'd0;
            col_interval_end[i] <= 2'd0;
        end
    end else if (start && state == IDLE) begin
        for (i = 0; i < 16; i = i + 1) begin
            lamp_rows[i] <= packed_lamp_rows[2*i +: 2];
            lamp_cols[i] <= packed_lamp_cols[2*i +: 2];
        end
        max_assignment <= (1 << k) - 1;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 1'b0;
        done <= 1'b0;
        assignment_counter <= 16'd0;
        i <= 4'd0;
        j <= 4'd0;
        check_idx <= 3'd0;
        overlap_found <= 1'b0;
        row_check_done <= 1'b0;
        col_check_done <= 1'b0;
        // Clear grouping arrays
        for (i = 0; i < 4; i = i + 1) begin
            row_group_count[i] <= 2'd0;
            col_group_count[i] <= 2'd0;
            for (j = 0; j < 4; j = j + 1) begin
                row_group_col[i][j] <= 2'd0;
                row_group_start[i][j] <= 2'd0;
                row_group_end[i][j] <= 2'd0;
                col_group_row[i][j] <= 2'd0;
                col_group_start[i][j] <= 2'd0;
                col_group_end[i][j] <= 2'd0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result <= 1'b0;
                if (start) begin
                    state <= PRECOMPUTE;
                end
            end
            
            PRECOMPUTE: begin
                // Precompute intervals for all lamps
                for (i = 0; i < 16; i = i + 1) begin
                    // Row interval (for row mode)
                    if (lamp_cols[i] >= MAX_REACH) begin
                        row_interval_start[i] <= lamp_cols[i] - MAX_REACH;
                    end else begin
                        row_interval_start[i] <= 2'd0;
                    end
                    if (lamp_cols[i] + MAX_REACH < GRID_SIZE) begin
                        row_interval_end[i] <= lamp_cols[i] + MAX_REACH;
                    end else begin
                        row_interval_end[i] <= GRID_SIZE - 1;
                    end
                    
                    // Column interval (for column mode)
                    if (lamp_rows[i] >= MAX_REACH) begin
                        col_interval_start[i] <= lamp_rows[i] - MAX_REACH;
                    end else begin
                        col_interval_start[i] <= 2'd0;
                    end
                    if (lamp_rows[i] + MAX_REACH < GRID_SIZE) begin
                        col_interval_end[i] <= lamp_rows[i] + MAX_REACH;
                    end else begin
                        col_interval_end[i] <= GRID_SIZE - 1;
                    end
                end
                state <= INIT_ASSIGN;
                i <= 4'd0;
            end
            
            INIT_ASSIGN: begin
                assignment_counter <= 16'd0;
                state <= CHECK_ASSIGN;
                i <= 4'd0;
                j <= 4'd0;
                check_idx <= 3'd0;
                overlap_found <= 1'b0;
                row_check_done <= 1'b0;
                col_check_done <= 1'b0;
            end
            
            CHECK_ASSIGN: begin
                // Clear grouping for this assignment
                if (i == 0 && j == 0) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        row_group_count[i] <= 2'd0;
                        col_group_count[i] <= 2'd0;
                        for (j = 0; j < 4; j = j + 1) begin
                            row_group_col[i][j] <= 2'd0;
                            row_group_start[i][j] <= 2'd0;
                            row_group_end[i][j] <= 2'd0;
                            col_group_row[i][j] <= 2'd0;
                            col_group_start[i][j] <= 2'd0;
                            col_group_end[i][j] <= 2'd0;
                        end
                    end
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                // Group lamps by assignment (take k cycles)
                if (i < 16 && j < k) begin
                    if (assignment_counter[i] == 0) begin  // Row mode
                        row_group_col[lamp_rows[i]][row_group_count[lamp_rows[i]]] <= lamp_cols[i];
                        row_group_start[lamp_rows[i]][row_group_count[lamp_rows[i]]] <= row_interval_start[i];
                        row_group_end[lamp_rows[i]][row_group_count[lamp_rows[i]]] <= row_interval_end[i];
                        row_group_count[lamp_rows[i]] <= row_group_count[lamp_rows[i]] + 1;
                    end else begin  // Column mode
                        col_group_row[lamp_cols[i]][col_group_count[lamp_cols[i]]] <= lamp_rows[i];
                        col_group_start[lamp_cols[i]][col_group_count[lamp_cols[i]]] <= col_interval_start[i];
                        col_group_end[lamp_cols[i]][col_group_count[lamp_cols[i]]] <= col_interval_end[i];
                        col_group_count[lamp_cols[i]] <= col_group_count[lamp_cols[i]] + 1;
                    end
                    i <= i + 1;
                    if (i >= k - 1) begin
                        j <= 4'd16;  // Done
                    end
                end else begin
                    // Check for overlaps
                    state <= ASSIGN_PASS;
                    i <= 4'd0;
                    j <= 4'd0;
                    check_idx <= 3'd0;
                    row_check_done <= 1'b0;
                    col_check_done <= 1'b0;
                    overlap_found <= 1'b0;
                end
            end
            
            ASSIGN_PASS: begin
                // Check rows for overlaps (4 rows)
                if (!row_check_done) begin
                    if (i < 4) begin  // For each row
                        if (row_group_count[i] > 1) begin
                            // Check all pairs in this row
                            if (j < row_group_count[i] - 1 && check_idx < row_group_count[i]) begin
                                if (check_idx > j) begin
                                    // Check if intervals overlap
                                    if (!(row_group_end[i][j] < row_group_start[i][check_idx] || 
                                          row_group_start[i][j] > row_group_end[i][check_idx])) begin
                                        overlap_found <= 1'b1;
                                        state <= ASSIGN_FAIL;
                                    end
                                end
                                check_idx <= check_idx + 1;
                                if (check_idx >= row_group_count[i]) begin
                                    check_idx <= 3'd0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= 4'd0;
                                check_idx <= 3'd0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        row_check_done <= 1'b1;
                        i <= 4'd0;
                        j <= 4'd0;
                        check_idx <= 3'd0;
                    end
                end else if (!col_check_done && !overlap_found) begin
                    // Check columns for overlaps
                    if (i < 4) begin  // For each column
                        if (col_group_count[i] > 1) begin
                            // Check all pairs in this column
                            if (j < col_group_count[i] - 1 && check_idx < col_group_count[i]) begin
                                if (check_idx > j) begin
                                    // Check if intervals overlap
                                    if (!(col_group_end[i][j] < col_group_start[i][check_idx] || 
                                          col_group_start[i][j] > col_group_end[i][check_idx])) begin
                                        overlap_found <= 1'b1;
                                        state <= ASSIGN_FAIL;
                                    end
                                end
                                check_idx <= check_idx + 1;
                                if (check_idx >= col_group_count[i]) begin
                                    check_idx <= 3'd0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= 4'd0;
                                check_idx <= 3'd0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        col_check_done <= 1'b1;
                    end
                end
                
                if ((row_check_done && col_check_done) || overlap_found) begin
                    state <= ASSIGN_FAIL;
                end
            end
            
            ASSIGN_FAIL: begin
                // Check if current assignment passes
                if (!overlap_found && assignment_counter <= max_assignment) begin
                    result <= 1'b1;
                    done <= 1'b1;
                    state <= FINISHED;
                end else if (assignment_counter < max_assignment) begin
                    assignment_counter <= assignment_counter + 1;
                    state <= CHECK_ASSIGN;
                    i <= 4'd0;
                    j <= 4'd0;
                    check_idx <= 3'd0;
                    overlap_found <= 1'b0;
                    row_check_done <= 1'b0;
                    col_check_done <= 1'b0;
                end else begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                // Stay done
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule