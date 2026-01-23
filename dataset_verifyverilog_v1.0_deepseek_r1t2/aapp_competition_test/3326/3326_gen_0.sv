module monotonic_subgrid_count #(
    parameter MAX_R = 3,
    parameter MAX_C = 3,
    parameter DATA_WIDTH = 8,
    parameter COUNT_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] r,
    input wire [1:0] c,
    input wire [DATA_WIDTH-1:0] grid_0_0, grid_0_1, grid_0_2,
    input wire [DATA_WIDTH-1:0] grid_1_0, grid_1_1, grid_1_2,
    input wire [DATA_WIDTH-1:0] grid_2_0, grid_2_1, grid_2_2,
    output reg [COUNT_WIDTH-1:0] count,
    output reg done
);

    reg [2:0] row_mask;
    reg [2:0] col_mask;
    reg [3:0] state;
    reg [COUNT_WIDTH-1:0] temp_count;
    reg grid_loaded;
    
    reg [DATA_WIDTH-1:0] grid [0:2][0:2];
    
    reg is_valid;
    
    reg [DATA_WIDTH-1:0] prev_val_row0, prev_val_row1, prev_val_row2;
    reg first_found_row0, first_found_row1, first_found_row2;
    reg increasing_row0, increasing_row1, increasing_row2;
    reg decreasing_row0, decreasing_row1, decreasing_row2;
    
    reg [DATA_WIDTH-1:0] prev_val_col0, prev_val_col1, prev_val_col2;
    reg first_found_col0, first_found_col1, first_found_col2;
    reg increasing_col0, increasing_col1, increasing_col2;
    reg decreasing_col0, decreasing_col1, decreasing_col2;
    
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_GRID = 4'd1;
    localparam [3:0] INIT = 4'd2;
    localparam [3:0] CHECK_SUBGRID = 4'd3;
    localparam [3:0] UPDATE_COUNT = 4'd4;
    localparam [3:0] NEXT_COL_MASK = 4'd5;
    localparam [3:0] NEXT_ROW_MASK = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;
    
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            done <= 1'b0;
            temp_count <= 0;
            row_mask <= 3'd0;
            col_mask <= 3'd0;
            grid_loaded <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
                count <= 0;
                done <= 1'b1;
            end else begin
                case (state)
                    IDLE: begin
                        done <= 1'b0;
                        cycle_count <= 8'd0;
                        if (start) begin
                            state <= LOAD_GRID;
                        end
                    end
                    
                    LOAD_GRID: begin
                        grid[0][0] <= grid_0_0;
                        grid[0][1] <= grid_0_1;
                        grid[0][2] <= grid_0_2;
                        grid[1][0] <= grid_1_0;
                        grid[1][1] <= grid_1_1;
                        grid[1][2] <= grid_1_2;
                        grid[2][0] <= grid_2_0;
                        grid[2][1] <= grid_2_1;
                        grid[2][2] <= grid_2_2;
                        grid_loaded <= 1'b1;
                        state <= INIT;
                    end
                    
                    INIT: begin
                        temp_count <= 0;
                        row_mask <= 3'b001;
                        col_mask <= 3'b001;
                        state <= CHECK_SUBGRID;
                    end
                    
                    CHECK_SUBGRID: begin
                        if (is_valid) begin
                            state <= UPDATE_COUNT;
                        end else begin
                            state <= NEXT_COL_MASK;
                        end
                    end
                    
                    UPDATE_COUNT: begin
                        temp_count <= temp_count + 1;
                        state <= NEXT_COL_MASK;
                    end
                    
                    NEXT_COL_MASK: begin
                        if (col_mask < ((3'b1 << c) - 3'b1)) begin
                            col_mask <= col_mask << 1;
                            state <= CHECK_SUBGRID;
                        end else begin
                            col_mask <= 3'b001;
                            state <= NEXT_ROW_MASK;
                        end
                    end
                    
                    NEXT_ROW_MASK: begin
                        if (row_mask < ((3'b1 << r) - 3'b1)) begin
                            row_mask <= row_mask << 1;
                            state <= CHECK_SUBGRID;
                        end else begin
                            count <= temp_count;
                            state <= DONE_STATE;
                        end
                    end
                    
                    DONE_STATE: begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
    
    always @(*) begin
        is_valid = 1'b1;
        
        first_found_row0 = 1'b0;
        increasing_row0 = 1'b1;
        decreasing_row0 = 1'b1;
        first_found_row1 = 1'b0;
        increasing_row1 = 1'b1;
        decreasing_row1 = 1'b1;
        first_found_row2 = 1'b0;
        increasing_row2 = 1'b1;
        decreasing_row2 = 1'b1;
        
        first_found_col0 = 1'b0;
        increasing_col0 = 1'b1;
        decreasing_col0 = 1'b1;
        first_found_col1 = 1'b0;
        increasing_col1 = 1'b1;
        decreasing_col1 = 1'b1;
        first_found_col2 = 1'b0;
        increasing_col2 = 1'b1;
        decreasing_col2 = 1'b1;
        
        // Check row 0
        if (row_mask[0]) begin
            // Column 0
            if (col_mask[0]) begin
                if (!first_found_row0) begin
                    prev_val_row0 = grid[0][0];
                    first_found_row0 = 1'b1;
                end else begin
                    if (grid[0][0] > prev_val_row0) decreasing_row0 = 1'b0;
                    if (grid[0][0] < prev_val_row0) increasing_row0 = 1'b0;
                    prev_val_row0 = grid[0][0];
                end
            end
            
            // Column 1
            if (col_mask[1]) begin
                if (!first_found_row0) begin
                    prev_val_row0 = grid[0][1];
                    first_found_row0 = 1'b1;
                end else begin
                    if (grid[0][1] > prev_val_row0) decreasing_row0 = 1'b0;
                    if (grid[0][1] < prev_val_row0) increasing_row0 = 1'b0;
                    prev_val_row0 = grid[0][1];
                end
            end
            
            // Column 2
            if (col_mask[2]) begin
                if (!first_found_row0) begin
                    prev_val_row0 = grid[0][2];
                    first_found_row0 = 1'b1;
                end else begin
                    if (grid[0][2] > prev_val_row0) decreasing_row0 = 1'b0;
                    if (grid[0][2] < prev_val_row0) increasing_row0 = 1'b0;
                    prev_val_row0 = grid[0][2];
                end
            end
            
            if (first_found_row0 && !(increasing_row0 || decreasing_row0)) is_valid = 1'b0;
        end
        
        // Check row 1
        if (row_mask[1]) begin
            // Column 0
            if (col_mask[0]) begin
                if (!first_found_row1) begin
                    prev_val_row1 = grid[1][0];
                    first_found_row1 = 1'b1;
                end else begin
                    if (grid[1][0] > prev_val_row1) decreasing_row1 = 1'b0;
                    if (grid[1][0] < prev_val_row1) increasing_row1 = 1'b0;
                    prev_val_row1 = grid[1][0];
                end
            end
            
            // Column 1
            if (col_mask[1]) begin
                if (!first_found_row1) begin
                    prev_val_row1 = grid[1][1];
                    first_found_row1 = 1'b1;
                end else begin
                    if (grid[1][1] > prev_val_row1) decreasing_row1 = 1'b0;
                    if (grid[1][1] < prev_val_row1) increasing_row1 = 1'b0;
                    prev_val_row1 = grid[1][1];
                end
            end
            
            // Column 2
            if (col_mask[2]) begin
                if (!first_found_row1) begin
                    prev_val_row1 = grid[1][2];
                    first_found_row1 = 1'b1;
                end else begin
                    if (grid[1][2] > prev_val_row1) decreasing_row1 = 1'b0;
                    if (grid[1][2] < prev_val_row1) increasing_row1 = 1'b0;
                    prev_val_row1 = grid[1][2];
                end
            end
            
            if (first_found_row1 && !(increasing_row1 || decreasing_row1)) is_valid = 1'b0;
        end
        
        // Check row 2
        if (row_mask[2]) begin
            // Column 0
            if (col_mask[0]) begin
                if (!first_found_row2) begin
                    prev_val_row2 = grid[2][0];
                    first_found_row2 = 1'b1;
                end else begin
                    if (grid[2][0] > prev_val_row2) decreasing_row2 = 1'b0;
                    if (grid[2][0] < prev_val_row2) increasing_row2 = 1'b0;
                    prev_val_row2 = grid[2][0];
                end
            end
            
            // Column 1
            if (col_mask[1]) begin
                if (!first_found_row2) begin
                    prev_val_row2 = grid[2][1];
                    first_found_row2 = 1'b1;
                end else begin
                    if (grid[2][1] > prev_val_row2) decreasing_row2 = 1'b0;
                    if (grid[2][1] < prev_val_row2) increasing_row2 = 1'b0;
                    prev_val_row2 = grid[2][1];
                end
            end
            
            // Column 2
            if (col_mask[2]) begin
                if (!first_found_row2) begin
                    prev_val_row2 = grid[2][2];
                    first_found_row2 = 1'b1;
                end else begin
                    if (grid[2][2] > prev_val_row2) decreasing_row2 = 1'b0;
                    if (grid[2][2] < prev_val_row2) increasing_row2 = 1'b0;
                    prev_val_row2 = grid[2][2];
                end
            end
            
            if (first_found_row2 && !(increasing_row2 || decreasing_row2)) is_valid = 1'b0;
        end
        
        // Check column 0
        if (col_mask[0]) begin
            // Row 0
            if (row_mask[0]) begin
                if (!first_found_col0) begin
                    prev_val_col0 = grid[0][0];
                    first_found_col0 = 1'b1;
                end else begin
                    if (grid[0][0] > prev_val_col0) decreasing_col0 = 1'b0;
                    if (grid[0][0] < prev_val_col0) increasing_col0 = 1'b0;
                    prev_val_col0 = grid[0][0];
                end
            end
            
            // Row 1
            if (row_mask[1]) begin
                if (!first_found_col0) begin
                    prev_val_col0 = grid[1][0];
                    first_found_col0 = 1'b1;
                end else begin
                    if (grid[1][0] > prev_val_col0) decreasing_col0 = 1'b0;
                    if (grid[1][0] < prev_val_col0) increasing_col0 = 1'b0;
                    prev_val_col0 = grid[1][0];
                end
            end
            
            // Row 2
            if (row_mask[2]) begin
                if (!first_found_col0) begin
                    prev_val_col0 = grid[2][0];
                    first_found_col0 = 1'b1;
                end else begin
                    if (grid[2][0] > prev_val_col0) decreasing_col0 = 1'b0;
                    if (grid[2][0] < prev_val_col0) increasing_col0 = 1'b0;
                    prev_val_col0 = grid[2][0];
                end
            end
            
            if (first_found_col0 && !(increasing_col0 || decreasing_col0)) is_valid = 1'b0;
        end
        
        // Check column 1
        if (col_mask[1]) begin
            // Row 0
            if (row_mask[0]) begin
                if (!first_found_col1) begin
                    prev_val_col1 = grid[0][1];
                    first_found_col1 = 1'b1;
                end else begin
                    if (grid[0][1] > prev_val_col1) decreasing_col1 = 1'b0;
                    if (grid[0][1] < prev_val_col1) increasing_col1 = 1'b0;
                    prev_val_col1 = grid[0][1];
                end
            end
            
            // Row 1
            if (row_mask[1]) begin
                if (!first_found_col1) begin
                    prev_val_col1 = grid[1][1];
                    first_found_col1 = 1'b1;
                end else begin
                    if (grid[1][1] > prev_val_col1) decreasing_col1 = 1'b0;
                    if (grid[1][1] < prev_val_col1) increasing_col1 = 1'b0;
                    prev_val_col1 = grid[1][1];
                end
            end
            
            // Row 2
            if (row_mask[2]) begin
                if (!first_found_col1) begin
                    prev_val_col1 = grid[2][1];
                    first_found_col1 = 1'b1;
                end else begin
                    if (grid[2][1] > prev_val_col1) decreasing_col1 = 1'b0;
                    if (grid[2][1] < prev_val_col1) increasing_col1 = 1'b0;
                    prev_val_col1 = grid[2][1];
                end
            end
            
            if (first_found_col1 && !(increasing_col1 || decreasing_col1)) is_valid = 1'b0;
        end
        
        // Check column 2
        if (col_mask[2]) begin
            // Row 0
            if (row_mask[0]) begin
                if (!first_found_col2) begin
                    prev_val_col2 = grid[0][2];
                    first_found_col2 = 1'b1;
                end else begin
                    if (grid[0][2] > prev_val_col2) decreasing_col2 = 1'b0;
                    if (grid[0][2] < prev_val_col2) increasing_col2 = 1'b0;
                    prev_val_col2 = grid[0][2];
                end
            end
            
            // Row 1
            if (row_mask[1]) begin
                if (!first_found_col2) begin
                    prev_val_col2 = grid[1][2];
                    first_found_col2 = 1'b1;
                end else begin
                    if (grid[1][2] > prev_val_col2) decreasing_col2 = 1'b0;
                    if (grid[1][2] < prev_val_col2) increasing_col2 = 1'b0;
                    prev_val_col2 = grid[1][2];
                end
            end
            
            // Row 2
            if (row_mask[2]) begin
                if (!first_found_col2) begin
                    prev_val_col2 = grid[2][2];
                    first_found_col2 = 1'b1;
                end else begin
                    if (grid[2][2] > prev_val_col2) decreasing_col2 = 1'b0;
                    if (grid[2][2] < prev_val_col2) increasing_col2 = 1'b0;
                    prev_val_col2 = grid[2][2];
                end
            end
            
            if (first_found_col2 && !(increasing_col2 || decreasing_col2)) is_valid = 1'b0;
        end
    end
    
endmodule