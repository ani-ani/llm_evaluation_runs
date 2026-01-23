module SquareKiller (
    input clk,
    input rst_n,
    input start,
    input [3:0] row0,
    input [3:0] row1,
    input [3:0] row2,
    input [3:0] row3,
    input [2:0] R,
    input [2:0] C,
    output reg [3:0] result,
    output reg done
);
    
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_SIZE = 4'd1;
    localparam [3:0] CHECK_SQUARE = 4'd2;
    localparam [3:0] NEXT_POS = 4'd3;
    localparam [3:0] NEXT_SIZE = 4'd4;
    localparam [3:0] NO_KILLER = 4'd5;
    localparam [3:0] DONE = 4'd6;
    
    reg [3:0] state, next_state;
    reg [3:0] rows_reg [0:3];
    reg [2:0] R_reg, C_reg;
    reg [2:0] current_size;
    reg [2:0] row_idx, col_idx;
    reg [2:0] max_row, max_col;
    
    integer i, j;
    reg is_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            current_size <= 3'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            max_row <= 3'd0;
            max_col <= 3'd0;
            for (i = 0; i < 4; i = i + 1) begin
                rows_reg[i] <= 4'd0;
            end
            R_reg <= 3'd0;
            C_reg <= 3'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        rows_reg[0] <= row0;
                        rows_reg[1] <= row1;
                        rows_reg[2] <= row2;
                        rows_reg[3] <= row3;
                        R_reg <= R;
                        C_reg <= C;
                        current_size <= (R < C) ? R : C;
                    end
                end
                INIT_SIZE: begin
                    if (next_state == CHECK_SQUARE) begin
                        max_row <= R_reg - current_size;
                        max_col <= C_reg - current_size;
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                    end else if (next_state == NEXT_SIZE) begin
                        current_size <= current_size - 3'd1;
                    end
                end
                NEXT_POS: begin
                    if (col_idx < max_col) begin
                        col_idx <= col_idx + 3'd1;
                    end else begin
                        col_idx <= 3'd0;
                        row_idx <= row_idx + 3'd1;
                    end
                end
                NEXT_SIZE: current_size <= current_size - 3'd1;
                NO_KILLER: begin
                    result <= 4'b1111;
                    done <= 1'b1;
                end
                DONE: begin
                    result <= {1'b0, current_size};
                    done <= 1'b1;
                end
                default: begin
                    // nothing
                end
            endcase
        end
    end

    always_comb begin
        is_valid = 1'b1;
        if (state == CHECK_SQUARE) begin
            for (i = 0; i < current_size; i = i + 1) begin
                for (j = 0; j < current_size; j = j + 1) begin
                    if (rows_reg[row_idx + i][col_idx + j] != rows_reg[row_idx + current_size - 1 -i][col_idx + current_size - 1 -j]) begin
                        is_valid = 1'b0;
                    end
                end
            end
        end else begin
            is_valid = 1'b0;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: next_state = start ? INIT_SIZE : IDLE;
            INIT_SIZE: begin
                if (current_size < 3'd2) begin
                    next_state = NO_KILLER;
                end else if (R_reg >= current_size && C_reg >= current_size) begin
                    next_state = CHECK_SQUARE;
                end else begin
                    next_state = NEXT_SIZE;
                end
            end
            CHECK_SQUARE: next_state = is_valid ? DONE : NEXT_POS;
            NEXT_POS: begin
                if ((col_idx < max_col) || (col_idx == max_col && row_idx < max_row)) begin
                    next_state = CHECK_SQUARE;
                end else begin
                    next_state = NEXT_SIZE;
                end
            end
            NEXT_SIZE: next_state = INIT_SIZE;
            NO_KILLER: next_state = IDLE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule