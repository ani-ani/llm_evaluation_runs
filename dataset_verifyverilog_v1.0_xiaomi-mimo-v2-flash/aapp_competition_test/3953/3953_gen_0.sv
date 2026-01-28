module purification_sol (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid,
    input wire [3:0] n,
    output reg [3:0] out_row,
    output reg [3:0] out_col,
    output reg out_valid,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ROWS = 3'd1;
    localparam [2:0] CHECK_COLS = 3'd2;
    localparam [2:0] FIND_ROW_SOLUTION = 3'd3;
    localparam [2:0] FIND_COL_SOLUTION = 3'd4;
    localparam [2:0] OUTPUT_RESULT = 3'd5;
    localparam [2:0] IMPOSSIBLE_STATE = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state, next_state;
    
    // Control registers
    reg [2:0] cycle_count;
    reg [2:0] max_cycles;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] output_idx;
    
    // Result storage
    reg [3:0] row_solution [0:7];
    reg [3:0] col_solution [0:7];
    
    // Temporary registers for checking
    reg row_has_dot;
    reg col_has_dot;
    reg all_rows_have_dot;
    reg all_cols_have_dot;
    reg found_dot;
    reg found_row_full_e;
    reg found_col_full_e;
    
    // Wires for grid access
    wire [7:0] current_row;
    wire [7:0] current_col;
    
    // Extract current row from grid (8 bits)
    assign current_row = grid[row_idx * 8 + 7 : row_idx * 8];
    
    // Extract current column from grid (8 bits, LSB is row 0)
    // Column j has bits: [7*8+j], [6*8+j], ..., [0*8+j]
    wire [7:0] col_bits;
    assign col_bits[0] = grid[col_idx + 0*8];
    assign col_bits[1] = grid[col_idx + 1*8];
    assign col_bits[2] = grid[col_idx + 2*8];
    assign col_bits[3] = grid[col_idx + 3*8];
    assign col_bits[4] = grid[col_idx + 4*8];
    assign col_bits[5] = grid[col_idx + 5*8];
    assign col_bits[6] = grid[col_idx + 6*8];
    assign col_bits[7] = grid[col_idx + 7*8];
    assign current_col = col_bits;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_row <= 4'd0;
            out_col <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 3'd0;
            max_cycles <= 3'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            output_idx <= 4'd0;
            row_has_dot <= 1'b0;
            col_has_dot <= 1'b0;
            all_rows_have_dot <= 1'b0;
            all_cols_have_dot <= 1'b0;
            found_dot <= 1'b0;
            found_row_full_e <= 1'b0;
            found_col_full_e <= 1'b0;
            // Initialize arrays
            begin : init_row_sol
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    row_solution[i] <= 4'd0;
                end
            end
            begin : init_col_sol
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    col_solution[i] <= 4'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    out_valid <= 1'b0;
                    if (start) begin
                        state <= CHECK_ROWS;
                        row_idx <= 4'd0;
                        all_rows_have_dot <= 1'b1;
                        found_row_full_e <= 1'b0;
                        cycle_count <= 3'd0;
                    end
                end

                CHECK_ROWS: begin
                    cycle_count <= cycle_count + 3'd1;
                    row_has_dot <= 1'b0;
                    found_dot <= 1'b0;
                    
                    // Check current row for at least one '.'
                    if (current_row[0] == 1'b0) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[1] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[2] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[3] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[4] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[5] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[6] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    if (current_row[7] == 1'b0 && !found_dot) begin row_has_dot <= 1'b1; found_dot <= 1'b1; end
                    
                    if (!row_has_dot) begin
                        all_rows_have_dot <= 1'b0;
                    end
                    if (!found_dot) begin
                        found_row_full_e <= 1'b1;
                    end
                    
                    if (row_idx < n - 4'd1) begin
                        row_idx <= row_idx + 4'd1;
                    end else begin
                        state <= CHECK_COLS;
                        col_idx <= 4'd0;
                        all_cols_have_dot <= 1'b1;
                        found_col_full_e <= 1'b0;
                        cycle_count <= 3'd0;
                    end
                end

                CHECK_COLS: begin
                    cycle_count <= cycle_count + 3'd1;
                    col_has_dot <= 1'b0;
                    found_dot <= 1'b0;
                    
                    // Check current column for at least one '.'
                    if (current_col[0] == 1'b0) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[1] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[2] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[3] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[4] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[5] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[6] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    if (current_col[7] == 1'b0 && !found_dot) begin col_has_dot <= 1'b0; found_dot <= 1'b1; end
                    
                    if (!col_has_dot) begin
                        all_cols_have_dot <= 1'b0;
                    end
                    if (!found_dot) begin
                        found_col_full_e <= 1'b1;
                    end
                    
                    if (col_idx < n - 4'd1) begin
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        // Decision point
                        if (found_row_full_e && found_col_full_e) begin
                            state <= IMPOSSIBLE_STATE;
                        end else if (all_rows_have_dot) begin
                            state <= FIND_ROW_SOLUTION;
                            row_idx <= 4'd0;
                            cycle_count <= 3'd0;
                        end else if (all_cols_have_dot) begin
                            state <= FIND_COL_SOLUTION;
                            col_idx <= 4'd0;
                            cycle_count <= 3'd0;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end
                end

                FIND_ROW_SOLUTION: begin
                    cycle_count <= cycle_count + 3'd1;
                    found_dot <= 1'b0;
                    
                    // Find first '.' in current row
                    if (current_row[0] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd0;
                        found_dot <= 1'b1;
                    end
                    if (current_row[1] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd1;
                        found_dot <= 1'b1;
                    end
                    if (current_row[2] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd2;
                        found_dot <= 1'b1;
                    end
                    if (current_row[3] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd3;
                        found_dot <= 1'b1;
                    end
                    if (current_row[4] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd4;
                        found_dot <= 1'b1;
                    end
                    if (current_row[5] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd5;
                        found_dot <= 1'b1;
                    end
                    if (current_row[6] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd6;
                        found_dot <= 1'b1;
                    end
                    if (current_row[7] == 1'b0 && !found_dot) begin
                        row_solution[row_idx] <= 4'd7;
                        found_dot <= 1'b1;
                    end
                    
                    if (row_idx < n - 4'd1) begin
                        row_idx <= row_idx + 4'd1;
                    end else begin
                        state <= OUTPUT_RESULT;
                        output_idx <= 4'd0;
                        out_valid <= 1'b1;
                        cycle_count <= 3'd0;
                    end
                end

                FIND_COL_SOLUTION: begin
                    cycle_count <= cycle_count + 3'd1;
                    found_dot <= 1'b0;
                    
                    // Find first '.' in current column
                    if (current_col[0] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd0;
                        found_dot <= 1'b1;
                    end
                    if (current_col[1] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd1;
                        found_dot <= 1'b1;
                    end
                    if (current_col[2] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd2;
                        found_dot <= 1'b1;
                    end
                    if (current_col[3] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd3;
                        found_dot <= 1'b1;
                    end
                    if (current_col[4] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd4;
                        found_dot <= 1'b1;
                    end
                    if (current_col[5] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd5;
                        found_dot <= 1'b1;
                    end
                    if (current_col[6] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd6;
                        found_dot <= 1'b1;
                    end
                    if (current_col[7] == 1'b0 && !found_dot) begin
                        col_solution[col_idx] <= 4'd7;
                        found_dot <= 1'b1;
                    end
                    
                    if (col_idx < n - 4'd1) begin
                        col_idx <= col_idx + 4'd1;
                    end else begin
                        state <= OUTPUT_RESULT;
                        output_idx <= 4'd0;
                        out_valid <= 1'b1;
                        cycle_count <= 3'd0;
                    end
                end

                OUTPUT_RESULT: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    if (all_rows_have_dot) begin
                        out_row <= row_solution[output_idx];
                        out_col <= output_idx;
                    end else begin
                        out_row <= output_idx;
                        out_col <= col_solution[output_idx];
                    end
                    
                    if (output_idx < n - 4'd1) begin
                        output_idx <= output_idx + 4'd1;
                    end else begin
                        out_valid <= 1'b0;
                        state <= DONE_STATE;
                    end
                end

                IMPOSSIBLE_STATE: begin
                    impossible <= 1'b1;
                    out_valid <= 1'b0;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule