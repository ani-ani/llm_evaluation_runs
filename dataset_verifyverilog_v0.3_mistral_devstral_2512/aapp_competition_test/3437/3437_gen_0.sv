module vacuum_tube_solver #(
    parameter N_MAX = 16,
    parameter DATA_WIDTH = 16,
    parameter INDEX_WIDTH = 5
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] L1,
    input wire [DATA_WIDTH-1:0] L2,
    input wire [7:0] N,
    input wire [DATA_WIDTH-1:0] tubes [0:N_MAX-1],
    output reg [DATA_WIDTH-1:0] max_sum,
    output reg possible,
    output reg done
);

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_INIT = 4'd1;
    localparam [3:0] S_LOOP_I = 4'd2;
    localparam [3:0] S_LOOP_J = 4'd3;
    localparam [3:0] S_CHECK_SUM1 = 4'd4;
    localparam [3:0] S_LOOP_K = 4'd5;
    localparam [3:0] S_LOOP_L = 4'd6;
    localparam [3:0] S_CHECK_SUM2 = 4'd7;
    localparam [3:0] S_UPDATE = 4'd8;
    localparam [3:0] S_DONE = 4'd9;

    reg [3:0] state;
    reg [INDEX_WIDTH-1:0] i, j, k, l;
    reg [DATA_WIDTH-1:0] sum1, sum2, total;
    reg [DATA_WIDTH-1:0] tubes_reg [0:N_MAX-1];
    reg [7:0] copy_idx;

    wire [DATA_WIDTH:0] sum1_wire = tubes_reg[i] + tubes_reg[j];
    wire [DATA_WIDTH:0] sum2_wire = tubes_reg[k] + tubes_reg[l];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            max_sum <= 16'd0;
            possible <= 1'b0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            l <= 5'd0;
            copy_idx <= 8'd0;
            sum1 <= 16'd0;
            sum2 <= 16'd0;
            total <= 16'd0;
            integer idx;
            for (idx = 0; idx < N_MAX; idx = idx + 1) begin
                tubes_reg[idx] <= 16'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_INIT;
                        copy_idx <= 8'd0;
                        max_sum <= 16'd0;
                        possible <= 1'b0;
                    end
                end

                S_INIT: begin
                    if (copy_idx < N_MAX) begin
                        if (copy_idx < N) begin
                            tubes_reg[copy_idx] <= tubes[copy_idx];
                        end else begin
                            tubes_reg[copy_idx] <= 16'd0;
                        end
                        copy_idx <= copy_idx + 8'd1;
                    end else begin
                        state <= S_LOOP_I;
                        i <= 5'd0;
                    end
                end

                S_LOOP_I: begin
                    if (i < N - 2) begin
                        state <= S_LOOP_J;
                        j <= i + 5'd1;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_LOOP_J: begin
                    if (j < N - 1) begin
                        state <= S_CHECK_SUM1;
                    end else begin
                        i <= i + 5'd1;
                        state <= S_LOOP_I;
                    end
                end

                S_CHECK_SUM1: begin
                    if (sum1_wire > L1) begin
                        j <= j + 5'd1;
                        state <= S_LOOP_J;
                    end else begin
                        sum1 <= sum1_wire[DATA_WIDTH-1:0];
                        k <= 5'd0;
                        state <= S_LOOP_K;
                    end
                end

                S_LOOP_K: begin
                    if (k < N - 1) begin
                        if (k == i || k == j) begin
                            k <= k + 5'd1;
                        end else begin
                            state <= S_LOOP_L;
                            l <= k + 5'd1;
                        end
                    end else begin
                        j <= j + 5'd1;
                        state <= S_LOOP_J;
                    end
                end

                S_LOOP_L: begin
                    if (l < N) begin
                        if (l == i || l == j) begin
                            l <= l + 5'd1;
                        end else begin
                            state <= S_CHECK_SUM2;
                        end
                    end else begin
                        k <= k + 5'd1;
                        state <= S_LOOP_K;
                    end
                end

                S_CHECK_SUM2: begin
                    if (sum2_wire > L2) begin
                        l <= l + 5'd1;
                        state <= S_LOOP_L;
                    end else begin
                        sum2 <= sum2_wire[DATA_WIDTH-1:0];
                        total <= sum1 + sum2_wire[DATA_WIDTH-1:0];
                        state <= S_UPDATE;
                    end
                end

                S_UPDATE: begin
                    if (total > max_sum) begin
                        max_sum <= total;
                        possible <= 1'b1;
                    end
                    l <= l + 5'd1;
                    state <= S_LOOP_L;
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= S_INIT;
                        copy_idx <= 8'd0;
                        max_sum <= 16'd0;
                        possible <= 1'b0;
                        done <= 1'b0;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule