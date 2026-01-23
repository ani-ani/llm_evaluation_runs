module treasure_island #(
    parameter MAX_N = 8,
    parameter MAX_M = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [MAX_N*MAX_M-1:0] grid_flat,
    output reg [1:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] FORWARD = 3'd2;
    localparam [2:0] BACKWARD = 3'd3;
    localparam [2:0] COUNT = 3'd4;
    localparam [2:0] CHECK = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [MAX_M-1:0] grid [0:MAX_N-1];
    reg [MAX_M-1:0] reachable [0:MAX_N-1];
    reg [MAX_M-1:0] can_reach [0:MAX_N-1];
    reg [3:0] diag_cnt [0:14];

    reg [2:0] state, next_state;
    reg [3:0] i, j;
    reg [3:0] diag_idx;
    reg path_exists;

    wire cell_forest = grid[i][j];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            i <= 4'd0;
            j <= 4'd0;
            path_exists <= 1'b0;
            for (diag_idx = 0; diag_idx < 15; diag_idx = diag_idx + 1'b1) begin
                diag_cnt[diag_idx] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = LOAD;
                    i = 4'd0;
                    j = 4'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                if (i < n) begin
                    if (j < m) begin
                        grid[i][j] = grid_flat[i*MAX_M + j];
                        reachable[i][j] = 1'b0;
                        can_reach[i][j] = 1'b0;
                        j = j + 1'b1;
                        next_state = LOAD;
                    end else begin
                        j = 4'd0;
                        i = i + 1'b1;
                        next_state = LOAD;
                    end
                end else begin
                    i = 4'd0;
                    j = 4'd0;
                    next_state = FORWARD;
                end
            end

            FORWARD: begin
                if (i < n && j < m) begin
                    if (i == 0 && j == 0) begin
                        reachable[0][0] = ~grid[0][0];
                    end else if (!cell_forest) begin
                        if ((i > 0 && reachable[i-1][j]) || (j > 0 && reachable[i][j-1])) begin
                            reachable[i][j] = 1'b1;
                        end
                    end
                    if (j + 1'b1 < m) begin
                        j = j + 1'b1;
                        next_state = FORWARD;
                    end else begin
                        j = 4'd0;
                        i = i + 1'b1;
                        next_state = FORWARD;
                    end
                end else begin
                    if (reachable[n-1][m-1]) begin
                        path_exists = 1'b1;
                        i = n - 1'b1;
                        j = m - 1'b1;
                        next_state = BACKWARD;
                    end else begin
                        result = 2'd0;
                        next_state = DONE_STATE;
                    end
                end
            end

            BACKWARD: begin
                if (i >= 0 && j >= 0) begin
                    if (i == n-1 && j == m-1) begin
                        can_reach[n-1][m-1] = ~grid[n-1][m-1];
                    end else if (!cell_forest) begin
                        if ((i < n-1 && can_reach[i+1][j]) || (j < m-1 && can_reach[i][j+1])) begin
                            can_reach[i][j] = 1'b1;
                        end
                    end
                    if (j > 0) begin
                        j = j - 1'b1;
                        next_state = BACKWARD;
                    end else begin
                        j = m - 1'b1;
                        if (i > 0) begin
                            i = i - 1'b1;
                            next_state = BACKWARD;
                        end else begin
                            i = 4'd0;
                            j = 4'd0;
                            next_state = COUNT;
                        end
                    end
                end else begin
                    next_state = COUNT;
                end
            end

            COUNT: begin
                if (i < n && j < m) begin
                    if (reachable[i][j] && can_reach[i][j] && !cell_forest) begin
                        diag_idx = i + j;
                        if (diag_idx < 15) begin
                            diag_cnt[diag_idx] = diag_cnt[diag_idx] + 1'b1;
                        end
                    end
                    if (j + 1'b1 < m) begin
                        j = j + 1'b1;
                        next_state = COUNT;
                    end else begin
                        j = 4'd0;
                        i = i + 1'b1;
                        next_state = COUNT;
                    end
                end else begin
                    i = 4'd0;
                    next_state = CHECK;
                end
            end

            CHECK: begin
                if (i < (n + m - 2)) begin
                    if (diag_cnt[i] == 4'd1) begin
                        result = 2'd1;
                        next_state = DONE_STATE;
                    end else begin
                        i = i + 1'b1;
                        next_state = CHECK;
                    end
                end else begin
                    result = 2'd2;
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule