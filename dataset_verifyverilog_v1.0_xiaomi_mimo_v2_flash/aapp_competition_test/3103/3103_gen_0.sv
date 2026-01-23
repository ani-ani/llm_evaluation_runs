module path_counter #(
    parameter Y = 8,
    parameter X = 16,
    parameter MOD = 1000003
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] x_init,
    input [7:0] grid_flat [0:Y*X-1],
    output reg [19:0] result,
    output reg done
);

localparam [7:0] CHAR_TILDE = 8'h7E;
localparam [7:0] CHAR_HASH = 8'h23;
localparam [7:0] CHAR_AT = 8'h40;
localparam [7:0] CHAR_GT = 8'h3E;
localparam [7:0] CHAR_LT = 8'h3C;

localparam [2:0] IDLE = 3'd0;
localparam [2:0] FIND_CASTLE = 3'd1;
localparam [2:0] INIT_DP = 3'd2;
localparam [2:0] PASS1 = 3'd3;
localparam [2:0] PASS2 = 3'd4;
localparam [2:0] NEXT_ROW = 3'd5;
localparam [2:0] OUTPUT = 3'd6;

reg [2:0] state, next_state;
reg [3:0] castle_x, castle_y;
reg [3:0] current_row;
reg [3:0] x_counter;
reg [19:0] dp_prev [0:15];
reg [19:0] dp_current [0:15];
reg [7:0] grid_reg [0:15][0:15];
reg [19:0] temp_sum;
integer i, y, x;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        castle_x <= 0;
        castle_y <= 0;
        current_row <= 0;
        x_counter <= 0;
        result <= 0;
        done <= 0;
        temp_sum <= 0;
        for (i = 0; i < 16; i = i + 1) begin
            dp_prev[i] <= 20'd0;
            dp_current[i] <= 20'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    for (y = 0; y < Y; y = y + 1) begin
                        for (x = 0; x < X; x = x + 1) begin
                            grid_reg[y][x] <= grid_flat[y * X + x];
                        end
                    end
                    castle_x <= 0;
                    castle_y <= 0;
                    current_row <= 0;
                    x_counter <= 0;
                    for (i = 0; i < 16; i = i + 1) begin
                        dp_prev[i] <= 20'd0;
                        dp_current[i] <= 20'd0;
                    end
                end
            end

            FIND_CASTLE: begin
                if (castle_x < X - 1) begin
                    castle_x <= castle_x + 1;
                end else begin
                    castle_x <= 0;
                    castle_y <= castle_y + 1;
                end
            end

            INIT_DP: begin
                for (i = 0; i < 16; i = i + 1) begin
                    dp_current[i] <= 20'd0;
                end
                dp_current[castle_x] <= 20'd1;
                x_counter <= X - 1;
                current_row <= castle_y;
            end

            PASS1: begin
                if (x_counter < X - 1) begin
                    if (grid_reg[current_row][x_counter] == CHAR_GT) begin
                        if (grid_reg[current_row][x_counter + 1] != CHAR_HASH) begin
                            temp_sum <= dp_current[x_counter] + dp_current[x_counter + 1];
                            if (dp_current[x_counter] + dp_current[x_counter + 1] >= MOD)
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter + 1] - MOD;
                            else
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter + 1];
                        end
                    end
                end
                x_counter <= x_counter - 1;
            end

            PASS2: begin
                if (x_counter > 0) begin
                    if (grid_reg[current_row][x_counter] == CHAR_LT) begin
                        if (grid_reg[current_row][x_counter - 1] != CHAR_HASH) begin
                            temp_sum <= dp_current[x_counter] + dp_current[x_counter - 1];
                            if (dp_current[x_counter] + dp_current[x_counter - 1] >= MOD)
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter - 1] - MOD;
                            else
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter - 1];
                        end
                    end
                end
                x_counter <= x_counter + 1;
            end

            NEXT_ROW: begin
                for (i = 0; i < 16; i = i + 1) begin
                    dp_prev[i] <= dp_current[i];
                end
                current_row <= current_row + 1;
                for (i = 0; i < 16; i = i + 1) begin
                    if ((current_row + 1) < Y && grid_reg[current_row + 1][i] != CHAR_HASH && 
                        grid_reg[current_row][i] != CHAR_HASH) begin
                        dp_current[i] <= dp_prev[i];
                    end else begin
                        dp_current[i] <= 20'd0;
                    end
                end
                x_counter <= X - 1;
            end

            OUTPUT: begin
                result <= dp_current[x_init];
                done <= 1;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = FIND_CASTLE;
        end

        FIND_CASTLE: begin
            if (castle_x == X - 1 && castle_y == Y - 1) begin
                next_state = INIT_DP;
            end else begin
                next_state = FIND_CASTLE;
            end
        end

        INIT_DP: begin
            if (castle_y == Y - 1) begin
                next_state = OUTPUT;
            end else begin
                next_state = PASS1;
            end
        end

        PASS1: begin
            if (x_counter == 0) next_state = PASS2;
            else next_state = PASS1;
        end

        PASS2: begin
            if (x_counter == X - 1) begin
                if (current_row == Y - 1) next_state = OUTPUT;
                else next_state = NEXT_ROW;
            end else begin
                next_state = PASS2;
            end
        end

        NEXT_ROW: begin
            next_state = PASS1;
        end

        OUTPUT: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

endmodule