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
    localparam [2:0] DONE = 3'd6;

    reg [MAX_M-1:0] grid [0:MAX_N-1];
    reg [MAX_M-1:0] reachable [0:MAX_N-1];
    reg [MAX_M-1:0] can_reach [0:MAX_N-1];
    reg [3:0] diag_cnt [0:14];

    reg [2:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] diag_idx;
    reg path_exists;
    reg cell_forest;
    reg [3:0] max_diag;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            i <= 4'd0;
            j <= 4'd0;
            path_exists <= 1'b0;
            diag_idx <= 4'd0;
            cell_forest <= 1'b0;
            max_diag <= 4'd14;
            for (k = 0; k < 15; k = k + 1) begin
                diag_cnt[k] <= 4'd0;
            end
            for (k = 0; k < MAX_N; k = k + 1) begin
                grid[k] <= {MAX_M{1'b0}};
                reachable[k] <= {MAX_M{1'b0}};
                can_reach[k] <= {MAX_M{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                LOAD: begin
                    if (i < n) begin
                        if (j < m) begin
                            grid[i][j] <= grid_flat[i*MAX_M + j];
                            reachable[i][j] <= 1'b0;
                            can_reach[i][j] <= 1'b0;
                            if (j + 1'b1 < m) begin
                                j <= j + 1'b1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 1'b1;
                            end
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= FORWARD;
                        max_diag <= n + m - 4'd2;
                        if (max_diag > 4'd14) max_diag <= 4'd14;
                    end
                end

                FORWARD: begin
                    if (i < n && j < m) begin
                        cell_forest <= grid[i][j];
                        if (i == 4'd0 && j == 4'd0) begin
                            if (!grid[0][0]) begin
                                reachable[0][0] <= 1'b1;
                            end
                        end else if (!grid[i][j]) begin
                            if ((i > 4'd0 && reachable[i-1][j]) || (j > 4'd0 && reachable[i][j-1])) begin
                                reachable[i][j] <= 1'b1;
                            end
                        end
                        if (j + 1'b1 < m) begin
                            j <= j + 1'b1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        if (reachable[n-1][m-1]) begin
                            path_exists <= 1'b1;
                            i <= n - 1'b1;
                            j <= m - 1'b1;
                            state <= BACKWARD;
                        end else begin
                            result <= 2'd0;
                            state <= DONE;
                        end
                    end
                end

                BACKWARD: begin
                    if (i < MAX_N && j < MAX_M) begin
                        cell_forest <= grid[i][j];
                        if (i == n-1 && j == m-1) begin
                            if (!grid[n-1][m-1]) begin
                                can_reach[n-1][m-1] <= 1'b1;
                            end
                        end else if (!grid[i][j]) begin
                            if ((i < n-1 && can_reach[i+1][j]) || (j < m-1 && can_reach[i][j+1])) begin
                                can_reach[i][j] <= 1'b1;
                            end
                        end
                        if (j > 4'd0) begin
                            j <= j - 1'b1;
                        end else begin
                            j <= m - 1'b1;
                            if (i > 4'd0) begin
                                i <= i - 1'b1;
                            end else begin
                                i <= 4'd0;
                                j <= 4'd0;
                                state <= COUNT;
                            end
                        end
                    end else begin
                        state <= COUNT;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                COUNT: begin
                    if (i < n && j < m) begin
                        if (reachable[i][j] && can_reach[i][j] && !grid[i][j]) begin
                            diag_idx <= i + j;
                            if ((i + j) < 4'd15) begin
                                diag_cnt[i + j] <= diag_cnt[i + j] + 1'b1;
                            end
                        end
                        if (j + 1'b1 < m) begin
                            j <= j + 1'b1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1'b1;
                        end
                    end else begin
                        i <= 4'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (i < max_diag) begin
                        if (diag_cnt[i] == 4'd1) begin
                            result <= 2'd1;
                            state <= DONE;
                        end else begin
                            i <= i + 1'b1;
                        end
                    end else begin
                        if (path_exists) begin
                            result <= 2'd2;
                        end else begin
                            result <= 2'd0;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule