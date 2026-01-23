module grid_computation(
    input clk,
    input rst_n,
    input start,
    input [3:0] x,
    input [3:0] y,
    output reg [31:0] result,
    output reg done
);

    localparam MOD = 32'd1000000007;
    localparam IDLE = 2'b00;
    localparam COMPUTE_ROW = 2'b01;
    localparam COMPUTE_CELL = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [3:0] r, c;
    reg [31:0] row_prev [0:15];
    reg [31:0] row_curr [0:15];
    reg [31:0] fib_prev;
    reg init_done;
    reg [3:0] init_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            init_done <= 0;
            init_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (!init_done) begin
                            if (init_idx == 0) begin
                                row_prev[0] <= 32'd0;
                                row_prev[1] <= 32'd1;
                                init_idx <= 2;
                            end else if (init_idx < 16) begin
                                row_prev[init_idx] <= row_prev[init_idx-1] + row_prev[init_idx-2];
                                if (row_prev[init_idx-1] + row_prev[init_idx-2] >= MOD)
                                    row_prev[init_idx] <= row_prev[init_idx-1] + row_prev[init_idx-2] - MOD;
                                init_idx <= init_idx + 1;
                            end else begin
                                init_done <= 1;
                                if (x == 0) begin
                                    result <= row_prev[y];
                                    done <= 1;
                                    state <= DONE;
                                end else begin
                                    fib_prev <= row_prev[0];
                                    r <= 1;
                                    state <= COMPUTE_ROW;
                                end
                            end
                        end else begin
                            if (x == 0) begin
                                result <= row_prev[y];
                                done <= 1;
                                state <= DONE;
                            end else begin
                                r <= 1;
                                row_curr[0] <= 0;
                                state <= COMPUTE_ROW;
                            end
                        end
                    end
                end

                COMPUTE_ROW: begin
                    if (r == 1) begin
                        row_curr[0] <= 32'd1;
                    end else if (r > 1) begin
                        row_curr[0] <= row_prev[0] + fib_prev;
                        if (row_prev[0] + fib_prev >= MOD)
                            row_curr[0] <= row_prev[0] + fib_prev - MOD;
                        fib_prev <= row_prev[0];
                    end
                    c <= 1;
                    state <= COMPUTE_CELL;
                end

                COMPUTE_CELL: begin
                    row_curr[c] <= row_prev[c] + row_curr[c-1];
                    if (row_prev[c] + row_curr[c-1] >= MOD)
                        row_curr[c] <= row_prev[c] + row_curr[c-1] - MOD;
                    if (r == x && c == y)
                        result <= (row_prev[c] + row_curr[c-1] >= MOD) ? (row_prev[c] + row_curr[c-1] - MOD) : (row_prev[c] + row_curr[c-1]);
                    c <= c + 1;
                    if ((r == x && c == y) || (r < x && c == 15)) begin
                        row_prev[0] <= row_curr[0]; row_prev[1] <= row_curr[1]; row_prev[2] <= row_curr[2]; row_prev[3] <= row_curr[3];
                        row_prev[4] <= row_curr[4]; row_prev[5] <= row_curr[5]; row_prev[6] <= row_curr[6]; row_prev[7] <= row_curr[7];
                        row_prev[8] <= row_curr[8]; row_prev[9] <= row_curr[9]; row_prev[10] <= row_curr[10]; row_prev[11] <= row_curr[11];
                        row_prev[12] <= row_curr[12]; row_prev[13] <= row_curr[13]; row_prev[14] <= row_curr[14]; row_prev[15] <= row_curr[15];
                        if (r == x) begin
                            if (y == 0) result <= row_curr[0];
                            done <= 1;
                            state <= DONE;
                        end else begin
                            r <= r + 1;
                            state <= COMPUTE_ROW;
                        end
                    end else begin
                        state <= COMPUTE_CELL;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                        init_done <= 1;
                        c <= 0;
                        init_idx <= 0;
                    end
                end
            endcase
        end
    end
endmodule