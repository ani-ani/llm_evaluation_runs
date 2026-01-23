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

localparam CHAR_TILDE = 8'h7E;
localparam CHAR_HASH = 8'h23;
localparam CHAR_AT = 8'h40;
localparam CHAR_GT = 8'h3E;
localparam CHAR_LT = 8'h3C;

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
reg [19:0] dp_prev [0:X-1];
reg [19:0] dp_current [0:X-1];
reg [7:0] grid_reg [0:Y-1][0:X-1];
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        castle_x <= 4'd0;
        castle_y <= 4'd0;
        current_row <= 4'd0;
        x_counter <= 4'd0;
        result <= 20'd0;
        cycle_count <= 8'd0;
        for (i = 0; i < X; i = i + 1) begin
            dp_prev[i] <= 20'd0;
            dp_current[i] <= 20'd0;
        end
        for (i = 0; i < Y; i = i + 1) begin
            for (j = 0; j < X; j = j + 1) begin
                grid_reg[i][j] <= 8'd0;
            end
        end
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= FIND_CASTLE;
                    for (i = 0; i < Y; i = i + 1) begin
                        for (j = 0; j < X; j = j + 1) begin
                            grid_reg[i][j] <= grid_flat[i * X + j];
                        end
                    end
                end
            end
            
            FIND_CASTLE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    state <= OUTPUT;
                end else if (grid_reg[castle_y][castle_x] == CHAR_AT) begin
                    state <= INIT_DP;
                end else begin
                    if (castle_x == X-1) begin
                        castle_x <= 4'd0;
                        castle_y <= castle_y + 4'd1;
                        if (castle_y == Y-1) state <= OUTPUT;
                    end else begin
                        castle_x <= castle_x + 4'd1;
                    end
                end
            end
            
            INIT_DP: begin
                for (i = 0; i < X; i = i + 1) begin
                    dp_current[i] <= 20'd0;
                end
                if (castle_x < X) dp_current[castle_x] <= 20'd1;
                current_row <= castle_y;
                x_counter <= X-1;
                state <= PASS1;
            end
            
            PASS1: begin
                if (x_counter < X) begin
                    if (grid_reg[current_row][x_counter] == CHAR_GT && x_counter < X-1) begin
                        if (grid_reg[current_row][x_counter+1] != CHAR_HASH) begin
                            if (dp_current[x_counter] + dp_current[x_counter+1] >= MOD)
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter+1] - MOD;
                            else
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter+1];
                        end
                    end
                    x_counter <= x_counter - 1;
                end else begin
                    x_counter <= 0;
                    state <= PASS2;
                end
            end
            
            PASS2: begin
                if (x_counter <= X-1) begin
                    if (grid_reg[current_row][x_counter] == CHAR_LT && x_counter > 0) begin
                        if (grid_reg[current_row][x_counter-1] != CHAR_HASH) begin
                            if (dp_current[x_counter] + dp_current[x_counter-1] >= MOD)
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter-1] - MOD;
                            else
                                dp_current[x_counter] <= dp_current[x_counter] + dp_current[x_counter-1];
                        end
                    end
                    x_counter <= x_counter + 1;
                end else begin
                    if (current_row == Y-1)
                        state <= OUTPUT;
                    else
                        state <= NEXT_ROW;
                end
            end
            
            NEXT_ROW: begin
                for (i = 0; i < X; i = i + 1) begin
                    dp_prev[i] <= dp_current[i];
                    if (grid_reg[current_row+1][i] != CHAR_HASH)
                        dp_current[i] <= dp_prev[i];
                    else
                        dp_current[i] <= 20'd0;
                end
                current_row <= current_row + 1;
                x_counter <= X-1;
                state <= PASS1;
            end
            
            OUTPUT: begin
                result <= dp_current[x_init];
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule