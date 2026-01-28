module MinimumMoveFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:15],  // 16 elements, each 8-bit
    input wire [3:0] n,
    input wire [3:0] m,
    output reg valid,
    output reg [15:0] moves,
    output reg is_rows,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SETUP_X   = 4'd1;
    localparam [3:0] COMP_COL  = 4'd2;
    localparam [3:0] COMP_ROW  = 4'd3;
    localparam [3:0] VERIFY    = 4'd4;
    localparam [3:0] UPDATE    = 4'd5;
    localparam [3:0] OUTPUT    = 4'd6;
    localparam [3:0] FINISH    = 4'd7;
    
    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] x;
    reg [7:0] x_next;
    reg [3:0] i;
    reg [3:0] i_next;
    reg [3:0] j;
    reg [3:0] j_next;
    reg [7:0] c_j;
    reg [7:0] c_j_next;
    reg [7:0] r_i;
    reg [7:0] r_i_next;
    reg [15:0] best_moves;
    reg [15:0] best_moves_next;
    reg best_valid;
    reg best_valid_next;
    reg best_is_rows;
    reg best_is_rows_next;
    reg [15:0] sum_r;
    reg [15:0] sum_r_next;
    reg [15:0] sum_c;
    reg [15:0] sum_c_next;
    reg [7:0] g_ij;
    reg [7:0] g_ij_next;
    reg [7:0] row_min;
    reg [7:0] row_min_next;
    reg [7:0] col_max;
    reg [7:0] col_max_next;
    reg [7:0] total_inc;
    reg [7:0] total_inc_next;
    reg valid_tmp;
    reg valid_tmp_next;
    reg [3:0] cycle_count;
    reg [3:0] cycle_count_next;
    localparam [3:0] MAX_CYCLES = 4'd10;  // Max 16 x 5 states ~ 80 cycles

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            c_j <= 8'd0;
            r_i <= 8'd0;
            best_moves <= 16'd0;
            best_valid <= 1'b0;
            best_is_rows <= 1'b0;
            sum_r <= 16'd0;
            sum_c <= 16'd0;
            g_ij <= 8'd0;
            row_min <= 8'd0;
            col_max <= 8'd0;
            total_inc <= 8'd0;
            valid_tmp <= 1'b0;
            cycle_count <= 4'd0;
            valid <= 1'b0;
            moves <= 16'd0;
            is_rows <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            x <= x_next;
            i <= i_next;
            j <= j_next;
            c_j <= c_j_next;
            r_i <= r_i_next;
            best_moves <= best_moves_next;
            best_valid <= best_valid_next;
            best_is_rows <= best_is_rows_next;
            sum_r <= sum_r_next;
            sum_c <= sum_c_next;
            g_ij <= g_ij_next;
            row_min <= row_min_next;
            col_max <= col_max_next;
            total_inc <= total_inc_next;
            valid_tmp <= valid_tmp_next;
            cycle_count <= cycle_count_next;
        end
    end

    // Combinational logic
    always @(*) begin
        next_state = state;
        x_next = x;
        i_next = i;
        j_next = j;
        c_j_next = c_j;
        r_i_next = r_i;
        best_moves_next = best_moves;
        best_valid_next = best_valid;
        best_is_rows_next = best_is_rows;
        sum_r_next = sum_r;
        sum_c_next = sum_c;
        g_ij_next = g_ij;
        row_min_next = row_min;
        col_max_next = col_max;
        total_inc_next = total_inc;
        valid_tmp_next = valid_tmp;
        cycle_count_next = cycle_count;
        
        case (state)
            IDLE: begin
                valid_tmp_next = 1'b0;
                best_moves_next = 16'hFFFF;
                best_valid_next = 1'b0;
                sum_r_next = 16'd0;
                sum_c_next = 16'd0;
                x_next = 8'd0;
                i_next = 4'd0;
                j_next = 4'd0;
                c_j_next = 8'd0;
                r_i_next = 8'd0;
                row_min_next = 8'd0;
                col_max_next = 8'd0;
                total_inc_next = 8'd0;
                cycle_count_next = 4'd0;
                
                if (start) begin
                    next_state = SETUP_X;
                end
            end
            
            SETUP_X: begin
                // Initialize column max calculation
                j_next = 4'd0;
                col_max_next = 8'd0;
                sum_c_next = 16'd0;
                sum_r_next = 16'd0;
                row_min_next = 8'dFF;  // Initialize to max for min calculation
                next_state = COMP_COL;
            end
            
            COMP_COL: begin
                // Compute c_j = g[0][j] - x, check >= 0, compute column max
                if (j < m) begin
                    g_ij_next = grid[j];  // grid[0][j] in packed format
                    if (g_ij >= x) begin
                        c_j_next = g_ij - x;
                        sum_c_next = sum_c + c_j_next;
                        if (c_j_next > col_max) begin
                            col_max_next = c_j_next;
                        end
                        j_next = j + 4'd1;
                    end else begin
                        // Invalid x, skip this x
                        valid_tmp_next = 1'b0;
                        next_state = UPDATE;
                    end
                end else begin
                    // All columns processed, move to row computation
                    i_next = 4'd0;
                    r_i_next = 8'd0;
                    sum_r_next = 16'd0;
                    row_min_next = 8'dFF;
                    next_state = COMP_ROW;
                end
            end
            
            COMP_ROW: begin
                // For each row i, compute r_i = min_j(g[i][j] - c_j)
                if (i < n) begin
                    j_next = 4'd0;
                    row_min_next = 8'dFF;
                    
                    // Find min for this row
                    if (j < m) begin
                        // Need c_j for this column - recompute or store
                        // Simplify: compute g[i][j] - (grid[0][j] - x) = g[i][j] - grid[0][j] + x
                        g_ij_next = grid[i * 4 + j];
                        reg [7:0] g0j = grid[j];
                        reg [7:0] diff = (g_ij >= g0j) ? (g_ij - g0j) : 8'dFF;
                        reg [7:0] r_candidate = (diff == 8'dFF) ? 8'dFF : (x + diff);
                        
                        if (r_candidate < row_min) begin
                            row_min_next = r_candidate;
                        end
                        
                        j_next = j + 4'd1;
                    end else begin
                        // Row i complete
                        if (row_min == 8'dFF) begin
                            // Invalid row
                            valid_tmp_next = 1'b0;
                            next_state = UPDATE;
                        end else begin
                            r_i_next = row_min;
                            sum_r_next = sum_r + r_i_next;
                            i_next = i + 4'd1;
                            row_min_next = 8'dFF;
                        end
                    end
                end else begin
                    // All rows processed, move to verification
                    i_next = 4'd0;
                    j_next = 4'd0;
                    total_inc_next = (n < m) ? n : m;
                    total_inc_next = total_inc * x;
                    valid_tmp_next = 1'b1;
                    next_state = VERIFY;
                end
            end
            
            VERIFY: begin
                // Verify: r_i + c_j + x == g[i][j] for all i,j
                if (i < n) begin
                    if (j < m) begin
                        g_ij_next = grid[i * 4 + j];
                        reg [7:0] g0j = grid[j];
                        reg [7:0] c_j_val = g0j - x;
                        reg [7:0] r_i_val = (g_ij >= g0j) ? (x + (g_ij - g0j)) : 8'dFF;
                        
                        if ((r_i_val + c_j_val + x) != g_ij) begin
                            valid_tmp_next = 1'b0;
                        end
                        
                        j_next = j + 4'd1;
                    end else begin
                        j_next = 4'd0;
                        i_next = i + 4'd1;
                    end
                end else begin
                    // Verification complete
                    if (valid_tmp) begin
                        next_state = UPDATE;
                    end else begin
                        next_state = UPDATE;
                    end
                end
            end
            
            UPDATE: begin
                // Update best solution if valid
                if (valid_tmp) begin
                    reg [15:0] total_moves = total_inc + sum_r + sum_c;
                    if (total_moves < best_moves) begin
                        best_moves_next = total_moves;
                        best_valid_next = 1'b1;
                        // Tie-breaking: is_rows = 1 if sum_r >= sum_c
                        best_is_rows_next = (sum_r >= sum_c) ? 1'b1 : 1'b0;
                    end
                end
                
                // Move to next x
                if (x < 8'd15) begin
                    x_next = x + 8'd1;
                    next_state = SETUP_X;
                    cycle_count_next = cycle_count + 4'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = OUTPUT;
                    end
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                valid <= best_valid;
                moves <= best_moves;
                is_rows <= best_is_rows;
                next_state = FINISH;
            end
            
            FINISH: begin
                done <= 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule