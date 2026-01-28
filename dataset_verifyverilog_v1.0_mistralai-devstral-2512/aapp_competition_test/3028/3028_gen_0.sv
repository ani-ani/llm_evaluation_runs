module PrimonimoSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] board_flat,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] p_val,
    output reg [255:0] result,
    output reg [5:0] move_count,
    output reg valid,
    output reg no_solution,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] SOLVE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd512;

    // Board and matrix storage
    reg [3:0] board [0:63];
    reg [3:0] A [0:63][0:63];
    reg [3:0] b [0:63];
    reg [3:0] x [0:63];

    // Temporary registers for computation
    reg [3:0] pivot_row, pivot_col;
    reg [3:0] row, col, k;
    reg [3:0] temp_val, temp_val2;
    reg [3:0] inv_p;
    reg [3:0] pivot_val;
    reg [3:0] swap_temp;
    reg [3:0] row_count, col_count;
    reg [3:0] solution_count;
    reg [3:0] current_index;
    reg [3:0] current_value;

    // Move sequence storage
    reg [5:0] move_sequence [0:63];
    reg [5:0] seq_index;

    // Helper functions for GF(p) arithmetic
    function [3:0] gf_add;
        input [3:0] a, b, p;
        begin
            gf_add = (a + b) % p;
        end
    endfunction

    function [3:0] gf_sub;
        input [3:0] a, b, p;
        begin
            gf_sub = (a - b + p) % p;
        end
    endfunction

    function [3:0] gf_mul;
        input [3:0] a, b, p;
        begin
            gf_mul = (a * b) % p;
        end
    endfunction

    function [3:0] gf_div;
        input [3:0] a, b, p;
        reg [3:0] i;
        begin
            gf_div = 0;
            for (i = 0; i < p; i = i + 1) begin
                if (gf_mul(i, b, p) == a) begin
                    gf_div = i;
                    break;
                end
            end
        end
    endfunction

    // Initialize board and matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            pivot_row <= 4'd0;
            pivot_col <= 4'd0;
            row <= 4'd0;
            col <= 4'd0;
            k <= 4'd0;
            temp_val <= 4'd0;
            temp_val2 <= 4'd0;
            inv_p <= 4'd0;
            pivot_val <= 4'd0;
            swap_temp <= 4'd0;
            row_count <= 4'd0;
            col_count <= 4'd0;
            solution_count <= 4'd0;
            current_index <= 4'd0;
            current_value <= 4'd0;
            seq_index <= 6'd0;
            valid <= 1'b0;
            no_solution <= 1'b0;
            done <= 1'b0;
            move_count <= 6'd0;
            result <= 256'd0;

            // Initialize board and matrix
            integer i, j;
            for (i = 0; i < 64; i = i + 1) begin
                board[i] <= 4'd0;
                b[i] <= 4'd0;
                x[i] <= 4'd0;
                move_sequence[i] <= 6'd0;
                for (j = 0; j < 64; j = j + 1) begin
                    A[i][j] <= 4'd0;
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    no_solution <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load board configuration
                    integer i;
                    for (i = 0; i < 64; i = i + 1) begin
                        board[i] <= board_flat[i*4 +: 4];
                    end

                    // Initialize matrix A and vector b
                    for (i = 0; i < 64; i = i + 1) begin
                        b[i] <= gf_sub(p_val, board[i], p_val);
                        integer j;
                        for (j = 0; j < 64; j = j + 1) begin
                            A[i][j] <= 4'd0;
                        end
                        // Set row and column influences
                        integer row_idx = i / m;
                        integer col_idx = i % m;
                        integer k;
                        for (k = 0; k < m; k = k + 1) begin
                            A[i][row_idx * m + k] <= gf_add(A[i][row_idx * m + k], 4'd1, p_val);
                        end
                        for (k = 0; k < n; k = k + 1) begin
                            A[i][k * m + col_idx] <= gf_add(A[i][k * m + col_idx], 4'd1, p_val);
                        end
                    end

                    row_count <= 4'd0;
                    col_count <= 4'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                        no_solution <= 1'b1;
                    end else begin
                        // Gaussian elimination
                        if (col_count < n * m && row_count < n * m) begin
                            // Find pivot
                            pivot_row <= row_count;
                            pivot_col <= col_count;
                            pivot_val <= A[pivot_row][pivot_col];
                            if (pivot_val == 4'd0) begin
                                // Search for non-zero pivot
                                integer i;
                                for (i = row_count + 1; i < n * m; i = i + 1) begin
                                    if (A[i][col_count] != 4'd0) begin
                                        pivot_row <= i;
                                        pivot_val <= A[i][col_count];
                                        break;
                                    end
                                end
                                if (pivot_val == 4'd0) begin
                                    col_count <= col_count + 4'd1;
                                end else begin
                                    // Swap rows
                                    integer j;
                                    for (j = 0; j < n * m; j = j + 1) begin
                                        swap_temp <= A[row_count][j];
                                        A[row_count][j] <= A[pivot_row][j];
                                        A[pivot_row][j] <= swap_temp;
                                    end
                                    swap_temp <= b[row_count];
                                    b[row_count] <= b[pivot_row];
                                    b[pivot_row] <= swap_temp;
                                end
                            end

                            if (pivot_val != 4'd0) begin
                                // Normalize pivot row
                                inv_p <= gf_div(4'd1, pivot_val, p_val);
                                for (k = col_count; k < n * m; k = k + 1) begin
                                    A[row_count][k] <= gf_mul(A[row_count][k], inv_p, p_val);
                                end
                                b[row_count] <= gf_mul(b[row_count], inv_p, p_val);

                                // Eliminate column
                                for (i = 0; i < n * m; i = i + 1) begin
                                    if (i != row_count && A[i][col_count] != 4'd0) begin
                                        temp_val <= A[i][col_count];
                                        for (k = col_count; k < n * m; k = k + 1) begin
                                            A[i][k] <= gf_sub(A[i][k], gf_mul(temp_val, A[row_count][k], p_val), p_val);
                                        end
                                        b[i] <= gf_sub(b[i], gf_mul(temp_val, b[row_count], p_val), p_val);
                                    end
                                end

                                row_count <= row_count + 4'd1;
                                col_count <= col_count + 4'd1;
                            end
                        end else begin
                            // Check for solution
                            integer i;
                            reg [3:0] inconsistent;
                            inconsistent <= 4'd0;
                            for (i = 0; i < n * m; i = i + 1) begin
                                if (A[i][i] == 4'd0 && b[i] != 4'd0) begin
                                    inconsistent <= 4'd1;
                                end
                            end

                            if (inconsistent) begin
                                next_state <= DONE;
                                no_solution <= 1'b1;
                            end else begin
                                // Back substitution
                                for (i = n * m - 1; i >= 0; i = i - 1) begin
                                    x[i] <= b[i];
                                    integer j;
                                    for (j = i + 1; j < n * m; j = j + 1) begin
                                        x[i] <= gf_sub(x[i], gf_mul(A[i][j], x[j], p_val), p_val);
                                    end
                                end
                                next_state <= SOLVE;
                            end
                        end
                    end
                end

                SOLVE: begin
                    // Extract move sequence
                    seq_index <= 6'd0;
                    solution_count <= 4'd0;
                    for (current_index = 0; current_index < n * m; current_index = current_index + 1) begin
                        current_value <= x[current_index];
                        if (current_value != 4'd0) begin
                            integer k;
                            for (k = 0; k < current_value; k = k + 1) begin
                                move_sequence[seq_index] <= current_index;
                                seq_index <= seq_index + 6'd1;
                                solution_count <= solution_count + 4'd1;
                            end
                        end
                    end

                    if (solution_count > 6'd0) begin
                        solution_count <= 6'd63;
                    end

                    move_count <= solution_count;
                    valid <= 1'b1;
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    // Pack result
                    integer i;
                    for (i = 0; i < 64; i = i + 1) begin
                        if (i < move_count) begin
                            result[i*6 +: 6] <= move_sequence[i];
                        end else begin
                            result[i*6 +: 6] <= 6'd0;
                        end
                    end
                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule