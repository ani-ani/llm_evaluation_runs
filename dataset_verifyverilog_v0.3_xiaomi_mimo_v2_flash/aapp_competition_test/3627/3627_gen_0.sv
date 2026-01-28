module min_energy #(
    parameter MAX_ROWS = 17,
    parameter MAX_COLS = 15,
    parameter COST_WIDTH = 4,
    parameter DP_WIDTH = 12
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,
    input wire [3:0] C,
    input wire signed [COST_WIDTH-1:0] grid [0:MAX_ROWS-1][0:MAX_COLS-1],
    output reg [DP_WIDTH-1:0] result,
    output reg done
);

    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam RELAX = 3'b010;
    localparam UPDATE = 3'b011;
    localparam FIND_MIN = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [DP_WIDTH-1:0] dp [0:MAX_ROWS-1][0:MAX_COLS-1];
    reg [DP_WIDTH-1:0] next_dp [0:MAX_ROWS-1][0:MAX_COLS-1];
    reg [4:0] row, col;
    reg [8:0] iter;
    reg [2:0] state, next_state;

    reg [DP_WIDTH-1:0] candidate;
    reg [4:0] nr, nc;
    reg [4:0] n;
    reg signed [DP_WIDTH:0] sum;
    reg [DP_WIDTH-1:0] cand_val;
    reg in_bounds_flag;
    reg is_end_flag;
    reg is_start_flag;

    always @(*) begin
        candidate = dp[row][col];
        is_end_flag = (row == 0);
        
        if (!is_end_flag) begin
            for (n = 0; n < 4; n = n + 1) begin
                case (n)
                    0: begin
                        if (col > 0) begin
                            nr = row;
                            nc = col - 1;
                            in_bounds_flag = 1'b1;
                        end else begin
                            in_bounds_flag = 1'b0;
                        end
                    end
                    1: begin
                        if (col < MAX_COLS - 1) begin
                            nr = row;
                            nc = col + 1;
                            in_bounds_flag = 1'b1;
                        end else begin
                            in_bounds_flag = 1'b0;
                        end
                    end
                    2: begin
                        if (row > 0) begin
                            nr = row - 1;
                            nc = col;
                            in_bounds_flag = 1'b1;
                        end else begin
                            in_bounds_flag = 1'b0;
                        end
                    end
                    3: begin
                        if (row < MAX_ROWS - 1) begin
                            nr = row + 1;
                            nc = col;
                            in_bounds_flag = 1'b1;
                        end else begin
                            in_bounds_flag = 1'b0;
                        end
                    end
                endcase

                if (in_bounds_flag) begin
                    sum = dp[nr][nc];
                    if (nr > 0 && nr < R + 1) begin
                        sum = sum + grid[nr][nc];
                    end
                    if (sum < 0) begin
                        cand_val = 0;
                    end else begin
                        cand_val = sum[DP_WIDTH-1:0];
                    end
                    if (cand_val < candidate) begin
                        candidate = cand_val;
                    end
                end
            end
        end else begin
            candidate = 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= {DP_WIDTH{1'b0}};
            state <= IDLE;
            iter <= 9'd0;
            row <= 5'd0;
            col <= 5'd0;
            for (integer r = 0; r < MAX_ROWS; r = r + 1) begin
                for (integer c = 0; c < MAX_COLS; c = c + 1) begin
                    dp[r][c] <= {DP_WIDTH{1'b0}};
                    next_dp[r][c] <= {DP_WIDTH{1'b0}};
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iter <= 9'd0;
                    row <= 5'd0;
                    col <= 5'd0;
                end
                INIT: begin
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        if (row == 0) begin
                            dp[row][col] <= {DP_WIDTH{1'b0}};
                            next_dp[row][col] <= {DP_WIDTH{1'b0}};
                        end else begin
                            dp[row][col] <= {DP_WIDTH{1'b1}};
                            next_dp[row][col] <= {DP_WIDTH{1'b1}};
                        end
                        if (col == MAX_COLS - 1) begin
                            col <= 5'd0;
                            if (row == MAX_ROWS - 1) begin
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end
                RELAX: begin
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        next_dp[row][col] <= candidate;
                        if (col == MAX_COLS - 1) begin
                            col <= 5'd0;
                            if (row == MAX_ROWS - 1) begin
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end
                UPDATE: begin
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        dp[row][col] <= next_dp[row][col];
                        if (col == MAX_COLS - 1) begin
                            col <= 5'd0;
                            if (row == MAX_ROWS - 1) begin
                                iter <= iter + 1;
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end
                FIND_MIN: begin
                    if (row == 0 && col == 0) begin
                        result <= {DP_WIDTH{1'b1}};
                    end
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        is_start_flag = (row == R + 1);
                        if (is_start_flag) begin
                            if (dp[row][col] < result) begin
                                result <= dp[row][col];
                            end
                        end
                        if (col == MAX_COLS - 1) begin
                            col <= 5'd0;
                            if (row == MAX_ROWS - 1) begin
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                if (row == MAX_ROWS - 1 && col == MAX_COLS - 1) begin
                    next_state = RELAX;
                end
            end
            RELAX: begin
                if (row == MAX_ROWS - 1 && col == MAX_COLS - 1) begin
                    next_state = UPDATE;
                end
            end
            UPDATE: begin
                if (row == MAX_ROWS - 1 && col == MAX_COLS - 1) begin
                    if (iter >= 254) begin
                        next_state = FIND_MIN;
                    end else begin
                        next_state = RELAX;
                    end
                end
            end
            FIND_MIN: begin
                if (row == MAX_ROWS - 1 && col == MAX_COLS - 1) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule