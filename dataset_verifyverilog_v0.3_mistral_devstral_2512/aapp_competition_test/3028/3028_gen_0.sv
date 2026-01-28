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
    localparam MAX_ROWS = SIZE;
    localparam MAX_COLS = SIZE;
    
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam FIND_PIVOT = 4'd2;
    localparam SWAP = 4'd3;
    localparam NORMALIZE = 4'd4;
    localparam ELIMINATE = 4'd5;
    localparam BACK_SUBST = 4'd6;
    localparam OUTPUT = 4'd7;
    localparam NO_SOLUTION = 4'd8;
    
    reg [3:0] state, next_state;
    
    reg [DATA_WIDTH-1:0] A [0:MAX_ROWS-1][0:MAX_COLS-1];
    reg [DATA_WIDTH-1:0] d [0:MAX_ROWS-1];
    reg [DATA_WIDTH-1:0] x [0:MAX_COLS-1];
    
    reg [3:0] row, col, pivot;
    reg [DATA_WIDTH-1:0] pivot_val;
    reg [DATA_WIDTH-1:0] factor;
    reg [3:0] r, c;
    reg [3:0] elim_row, elim_col;
    reg [3:0] back_row, back_col;
    
    function [DATA_WIDTH-1:0] mod_add;
        input [DATA_WIDTH-1:0] a, b, p;
        begin
            mod_add = (a + b) % p;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_sub;
        input [DATA_WIDTH-1:0] a, b, p;
        begin
            mod_sub = (a + p - b) % p;
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_mul;
        input [DATA_WIDTH-1:0] a, b, p;
        integer temp;
        begin
            temp = (a * b) % p;
            mod_mul = temp[DATA_WIDTH-1:0];
        end
    endfunction
    
    function [DATA_WIDTH-1:0] mod_inv;
        input [DATA_WIDTH-1:0] a;
        input [DATA_WIDTH-1:0] p;
        integer i;
        begin
            mod_inv = 0;
            for (i = 1; i < p; i = i + 1) begin
                if ((a * i) % p == 1) begin
                    mod_inv = i;
                end
            end
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            solution_exists <= 0;
            count_0 <= 0; count_1 <= 0; count_2 <= 0; count_3 <= 0;
            row <= 0; col <= 0; pivot <= 0;
            elim_row <= 0; elim_col <= 0;
            back_row <= 0; back_col <= 0;
        end else begin
            state <= next_state;
            done <= 0;
            solution_exists <= 0;
            
            case (state)
                INIT: begin
                    A[0][0] <= 1; A[0][1] <= 1; A[0][2] <= 0; A[0][3] <= 0;
                    A[1][0] <= 1; A[1][1] <= 1; A[1][2] <= 0; A[1][3] <= 0;
                    A[2][0] <= 0; A[2][1] <= 0; A[2][2] <= 1; A[2][3] <= 1;
                    A[3][0] <= 0; A[3][1] <= 0; A[3][2] <= 1; A[3][3] <= 1;
                    
                    d[0] <= mod_sub(p, board_0, p);
                    d[1] <= mod_sub(p, board_1, p);
                    d[2] <= mod_sub(p, board_2, p);
                    d[3] <= mod_sub(p, board_3, p);
                    
                    row <= 0;
                    col <= 0;
                    next_state <= FIND_PIVOT;
                end
                
                FIND_PIVOT: begin
                    if (col < SIZE) begin
                        pivot <= 0;
                        for (r = row; r < SIZE; r = r + 1) begin
                            if (A[r][col] != 0) begin
                                pivot <= r;
                            end
                        end
                        
                        if (pivot != 0) begin
                            next_state <= SWAP;
                        end else begin
                            x[col] <= 0;
                            col <= col + 1;
                            if (col == SIZE) begin
                                next_state <= BACK_SUBST;
                            end else begin
                                next_state <= FIND_PIVOT;
                            end
                        end
                    end else begin
                        next_state <= BACK_SUBST;
                    end
                end
                
                SWAP: begin
                    for (c = 0; c < SIZE; c = c + 1) begin
                        A[row][c] <= A[pivot][c];
                    end
                    d[row] <= d[pivot];
                    next_state <= NORMALIZE;
                end
                
                NORMALIZE: begin
                    pivot_val <= A[row][col];
                    factor <= mod_inv(pivot_val, p);
                    
                    for (c = 0; c < SIZE; c = c + 1) begin
                        A[row][c] <= mod_mul(A[row][c], factor, p);
                    end
                    d[row] <= mod_mul(d[row], factor, p);
                    next_state <= ELIMINATE;
                end
                
                ELIMINATE: begin
                    if (elim_row < SIZE) begin
                        if (elim_row != row) begin
                            factor <= A[elim_row][col];
                            for (c = 0; c < SIZE; c = c + 1) begin
                                A[elim_row][c] <= mod_sub(A[elim_row][c], mod_mul(A[row][c], factor, p), p);
                            end
                            d[elim_row] <= mod_sub(d[elim_row], mod_mul(d[row], factor, p), p);
                        end
                        elim_row <= elim_row + 1;
                        if (elim_row == SIZE) begin
                            row <= row + 1;
                            col <= col + 1;
                            elim_row <= 0;
                            next_state <= FIND_PIVOT;
                        end
                    end
                end
                
                BACK_SUBST: begin
                    if (back_row < SIZE) begin
                        if (A[back_row][back_col] == 0) begin
                            if (d[back_row] != 0) begin
                                next_state <= NO_SOLUTION;
                            end else begin
                                x[back_col] <= 0;
                            end
                        end else begin
                            x[back_col] <= d[back_row];
                            for (c = back_col + 1; c < SIZE; c = c + 1) begin
                                x[back_col] <= mod_sub(x[back_col], mod_mul(A[back_row][c], x[c], p), p);
                            end
                        end
                        back_row <= back_row + 1;
                        back_col <= back_col + 1;
                        if (back_row == SIZE) begin
                            next_state <= OUTPUT;
                        end
                    end
                end
                
                OUTPUT: begin
                    count_0 <= x[0];
                    count_1 <= x[1];
                    count_2 <= x[2];
                    count_3 <= x[3];
                    solution_exists <= 1;
                    done <= 1;
                    next_state <= IDLE;
                end
                
                NO_SOLUTION: begin
                    solution_exists <= 0;
                    done <= 1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            default: next_state = state;
        endcase
    end

endmodule