module PrimonimoSolver #(
    parameter N = 2,
    parameter M = 2,
    parameter DATA_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] p,
    input wire [DATA_WIDTH-1:0] board_0,
    input wire [DATA_WIDTH-1:0] board_1,
    input wire [DATA_WIDTH-1:0] board_2,
    input wire [DATA_WIDTH-1:0] board_3,
    output reg [DATA_WIDTH-1:0] count_0,
    output reg [DATA_WIDTH-1:0] count_1,
    output reg [DATA_WIDTH-1:0] count_2,
    output reg [DATA_WIDTH-1:0] count_3,
    output reg solution_exists,
    output reg done
);

    localparam SIZE = N * M;
    
    // State definitions with explicit widths
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_PIVOT = 4'd2;
    localparam [3:0] SWAP = 4'd3;
    localparam [3:0] NORMALIZE = 4'd4;
    localparam [3:0] ELIMINATE = 4'd5;
    localparam [3:0] BACK_SUBST = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] NO_SOLUTION = 4'd8;
    
    reg [3:0] state, next_state;
    
    // Matrix and vectors
    reg [DATA_WIDTH-1:0] A [0:3][0:3];
    reg [DATA_WIDTH-1:0] d [0:3];
    reg [DATA_WIDTH-1:0] x [0:3];
    
    // Working registers
    reg [3:0] row, col, pivot_row;
    reg [DATA_WIDTH-1:0] temp_d, pivot_val;
    reg [DATA_WIDTH-1:0] temp_A, factor;
    reg [1:0] i, j; // Loop indices
    reg [3:0] step_counter;
    reg found_pivot;
    reg inconsistent;
    
    // Cycle counter prevents infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Modular arithmetic functions
    function [DATA_WIDTH-1:0] mod_add;
        input [DATA_WIDTH-1:0] a, b;
        input [DATA_WIDTH-1:0] p;
        begin
            mod_add = (a + b) % p;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_sub;
        input [DATA_WIDTH-1:0] a, b;
        input [DATA_WIDTH-1:0] p;
        begin
            mod_sub = (a + p - b) % p;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_mul;
        input [DATA_WIDTH-1:0] a, b;
        input [DATA_WIDTH-1:0] p;
        integer temp;
        begin
            temp = a * b;
            mod_mul = temp % p;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_inv;
        input [DATA_WIDTH-1:0] a;
        input [DATA_WIDTH-1:0] p;
        integer i;
        begin
            mod_inv = 0;
            if (a != 0) begin // Only compute if non-zero
                for (i = 1; i < p; i = i + 1) begin
                    if ((a * i) % p == 1)
                        mod_inv = i;
                end
            end
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            solution_exists <= 1'b0;
            count_0 <= {DATA_WIDTH{1'b0}};
            count_1 <= {DATA_WIDTH{1'b0}};
            count_2 <= {DATA_WIDTH{1'b0}};
            count_3 <= {DATA_WIDTH{1'b0}};
            row <= 4'd0;
            col <= 4'd0;
            pivot_row <= 4'd0;
            found_pivot <= 1'b0;
            inconsistent <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            for (i = 0; i < 4; i = i + 1) begin
                d[i] <= {DATA_WIDTH{1'b0}};
                x[i] <= {DATA_WIDTH{1'b0}};
                for (j = 0; j < 4; j = j + 1) begin
                    A[i][j] <= {DATA_WIDTH{1'b0}};
                end
            end
        end 
        else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solution_exists <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Calculate d[i] = (p - board_i) % p
                    d[0] <= (p >= board_0) ? (p - board_0) : 0;
                    d[1] <= (p >= board_1) ? (p - board_1) : 0;
                    d[2] <= (p >= board_2) ? (p - board_2) : 0;
                    d[3] <= (p >= board_3) ? (p - board_3) : 0;
                    
                    // Initialize matrix A - 1 if same row or column
                    A[0][0] <= 3'd1; A[0][1] <= 3'd1; A[0][2] <= 3'd1; A[0][3] <= 3'd0;
                    A[1][0] <= 3'd1; A[1][1] <= 3'd1; A[1][2] <= 3'd0; A[1][3] <= 3'd1;
                    A[2][0] <= 3'd1; A[2][1] <= 3'd0; A[2][2] <= 3'd1; A[2][3] <= 3'd1;
                    A[3][0] <= 3'd0; A[3][1] <= 3'd1; A[3][2] <= 3'd1; A[3][3] <= 3'd1;
                    
                    row <= 4'd0;
                    col <= 4'd0;
                    state <= FIND_PIVOT;
                end
                
                FIND_PIVOT: begin
                    found_pivot <= 1'b0;
                    pivot_row <= row;
                    
                    for (i = row; i < 4; i = i + 1) begin
                        if (A[i][col] != 0) begin
                            pivot_row <= i;
                            found_pivot <= 1'b1;
                        end
                    end
                    
                    if (found_pivot) begin
                        state <= SWAP;
                    end
                    else begin
                        // No pivot - set x[col] = 0
                        x[col] <= 0;
                        if (col == 3) begin
                            state <= BACK_SUBST;
                        end
                        else begin
                            col <= col + 4'd1;
                            state <= FIND_PIVOT;
                        end
                    end
                end
                
                SWAP: begin
                    // Swap current row with pivot_row
                    if (row != pivot_row) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_A = A[row][j];
                            A[row][j] <= A[pivot_row][j];
                            A[pivot_row][j] <= temp_A;
                        end
                        temp_d = d[row];
                        d[row] <= d[pivot_row];
                        d[pivot_row] <= temp_d;
                    end
                    state <= NORMALIZE;
                end
                
                NORMALIZE: begin
                    pivot_val = A[row][col];
                    factor = mod_inv(pivot_val, p);
                    
                    // Normalize current row
                    for (j = 0; j < 4; j = j + 1) begin
                        A[row][j] <= mod_mul(A[row][j], factor, p);
                    end
                    d[row] <= mod_mul(d[row], factor, p);
                    
                    // Next step
                    step_counter <= 4'd0;
                    state <= ELIMINATE;
                end
                
                ELIMINATE: begin
                    // Eliminate column 'col' from all other rows
                    if (step_counter < 4) begin
                        if (step_counter != row) begin
                            factor = A[step_counter][col];
                            for (j = 0; j < 4; j = j + 1) begin
                                A[step_counter][j] <= mod_sub(A[step_counter][j], 
                                    mod_mul(A[row][j], factor, p), p);
                            end
                            d[step_counter] <= mod_sub(d[step_counter], 
                                mod_mul(d[row], factor, p), p);
                        end
                        step_counter <= step_counter + 4'd1;
                    end
                    else begin
                        if (col == 3) begin
                            state <= BACK_SUBST;
                        end
                        else begin
                            col <= col + 4'd1;
                            row <= row + 4'd1;
                            state <= FIND_PIVOT;
                        end
                    end
                end
                
                BACK_SUBST: begin
                    // Simple back substitution (assuming upper triangular)
                    x[3] = d[3];
                    x[2] = mod_sub(d[2], mod_mul(A[2][3], x[3], p), p);
                    x[1] = mod_sub(d[1], mod_mul(A[1][2], x[2], p) + 
                        mod_mul(A[1][3], x[3], p), p);
                    x[0] = mod_sub(d[0], mod_mul(A[0][1], x[1], p) + 
                        mod_mul(A[0][2], x[2], p) + mod_mul(A[0][3], x[3], p), p);
                    
                    // Check consistency
                    inconsistent <= 1'b0;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (d[i] != 0 && A[i][0] == 0 && A[i][1] == 0 && 
                            A[i][2] == 0 && A[i][3] == 0) begin
                            inconsistent <= 1'b1;
                        end
                    end
                    
                    state <= (inconsistent) ? NO_SOLUTION : OUTPUT;
                end
                
                OUTPUT: begin
                    count_0 <= x[0];
                    count_1 <= x[1];
                    count_2 <= x[2];
                    count_3 <= x[3];
                    solution_exists <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                NO_SOLUTION: begin
                    solution_exists <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
endmodule