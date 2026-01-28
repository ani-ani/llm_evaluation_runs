module FindBlackSquareCenter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid_0,
    input wire [7:0] grid_1,
    input wire [7:0] grid_2,
    input wire [7:0] grid_3,
    input wire [7:0] grid_4,
    input wire [7:0] grid_5,
    input wire [7:0] grid_6,
    input wire [7:0] grid_7,
    input wire [7:0] grid_8,
    input wire [7:0] grid_9,
    input wire [7:0] grid_10,
    input wire [7:0] grid_11,
    input wire [7:0] grid_12,
    input wire [7:0] grid_13,
    input wire [7:0] grid_14,
    input wire [7:0] grid_15,
    input wire [3:0] valid_rows,
    output reg [7:0] center_row,
    output reg [7:0] center_col,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] SCAN  = 2'd1;
    localparam [1:0] CALC  = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] row_idx;          // Counter for rows 0-15
    reg [7:0] row_min, row_max; // 0-based
    reg [3:0] col_min, col_max; // 0-based (0-7)
    reg [7:0] sum_row, sum_col; // For calculation
    reg [3:0] calc_stage;       // Pipeline stage counter
    reg [7:0] current_grid;     // Register to hold current row data
    
    // Cycle counter for safety
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

    // Combinational logic to select current row based on index
    reg [7:0] selected_grid;
    always @(*) begin
        case (row_idx)
            4'd0: selected_grid = grid_0;
            4'd1: selected_grid = grid_1;
            4'd2: selected_grid = grid_2;
            4'd3: selected_grid = grid_3;
            4'd4: selected_grid = grid_4;
            4'd5: selected_grid = grid_5;
            4'd6: selected_grid = grid_6;
            4'd7: selected_grid = grid_7;
            4'd8: selected_grid = grid_8;
            4'd9: selected_grid = grid_9;
            4'd10: selected_grid = grid_10;
            4'd11: selected_grid = grid_11;
            4'd12: selected_grid = grid_12;
            4'd13: selected_grid = grid_13;
            4'd14: selected_grid = grid_14;
            4'd15: selected_grid = grid_15;
            default: selected_grid = 8'd0;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            center_row <= 8'd0;
            center_col <= 8'd0;
            done <= 1'b0;
            row_idx <= 4'd0;
            row_min <= 8'd15; // Init high
            row_max <= 8'd0;
            col_min <= 4'd8;  // Init high
            col_max <= 4'd0;
            cycle_count <= 7'd0;
            sum_row <= 8'd0;
            sum_col <= 8'd0;
            calc_stage <= 4'd0;
            current_grid <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start) begin
                        row_idx <= 4'd0;
                        row_min <= 8'd15;
                        row_max <= 8'd0;
                        col_min <= 4'd8;
                        col_max <= 4'd0;
                    end
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 7'd1;
                    current_grid <= selected_grid;
                    
                    // Check if row is valid and has black cells
                    if (row_idx < valid_rows && selected_grid != 8'd0) begin
                        // Update row indices
                        if (row_idx < row_min) row_min <= row_idx;
                        if (row_idx > row_max) row_max <= row_idx;
                        
                        // Check columns (bits 0-7)
                        if (selected_grid[0] && (0 < col_min)) col_min <= 4'd0;
                        if (selected_grid[0] && (0 > col_max)) col_max <= 4'd0;
                        if (selected_grid[1] && (1 < col_min)) col_min <= 4'd1;
                        if (selected_grid[1] && (1 > col_max)) col_max <= 4'd1;
                        if (selected_grid[2] && (2 < col_min)) col_min <= 4'd2;
                        if (selected_grid[2] && (2 > col_max)) col_max <= 4'd2;
                        if (selected_grid[3] && (3 < col_min)) col_min <= 4'd3;
                        if (selected_grid[3] && (3 > col_max)) col_max <= 4'd3;
                        if (selected_grid[4] && (4 < col_min)) col_min <= 4'd4;
                        if (selected_grid[4] && (4 > col_max)) col_max <= 4'd4;
                        if (selected_grid[5] && (5 < col_min)) col_min <= 4'd5;
                        if (selected_grid[5] && (5 > col_max)) col_max <= 4'd5;
                        if (selected_grid[6] && (6 < col_min)) col_min <= 4'd6;
                        if (selected_grid[6] && (6 > col_max)) col_max <= 4'd6;
                        if (selected_grid[7] && (7 < col_min)) col_min <= 4'd7;
                        if (selected_grid[7] && (7 > col_max)) col_max <= 4'd7;
                    end
                    
                    row_idx <= row_idx + 4'd1;
                    calc_stage <= 4'd0;
                end
                
                CALC: begin
                    cycle_count <= cycle_count + 7'd1;
                    calc_stage <= calc_stage + 4'd1;
                    
                    if (calc_stage == 4'd0) begin
                        // Stage 0: Calculate sums
                        sum_row <= row_min + row_max;
                        sum_col <= col_min + col_max;
                    end else if (calc_stage == 4'd1) begin
                        // Stage 1: Divide by 2 (shift right) and add 1
                        center_row <= (sum_row >> 1) + 8'd1;
                        center_col <= (sum_col >> 1) + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Reset control signals
                    row_idx <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
                else
                    next_state = IDLE;
            end
            
            SCAN: begin
                if (row_idx >= 4'd15) // Scanned all 16 potential rows
                    next_state = CALC;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = IDLE; // Safety timeout
                else
                    next_state = SCAN;
            end
            
            CALC: begin
                if (calc_stage >= 4'd1) // Calculation complete
                    next_state = FINISH;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = IDLE;
                else
                    next_state = CALC;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule