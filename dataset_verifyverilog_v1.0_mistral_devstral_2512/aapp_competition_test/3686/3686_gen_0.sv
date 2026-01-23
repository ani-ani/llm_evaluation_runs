module TwoLinesCover(
    input clk,
    input rst_n,
    input start,
    input [3:0] count,
    input signed [7:0] x [0:7],
    input signed [7:0] y [0:7],
    output reg success,
    output reg done
);

    reg [1:0] state;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            success <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    if (count <= 2) begin
                        success <= 1'b1;
                    end else begin
                        integer i, j, k, m;
                        reg [15:0] cross1, cross2;
                        reg [15:0] cross_rem1, cross_rem2;
                        reg [15:0] dx1, dy1, dx2, dy2;
                        reg [15:0] dx_rem1, dy_rem1, dx_rem2, dy_rem2;
                        reg [7:0] rem_x [0:7];
                        reg [7:0] rem_y [0:7];
                        reg [3:0] rem_count;
                        reg [3:0] on_line_count;
                        reg all_collinear;
                        reg found;

                        found = 1'b0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i >= count) begin
                                continue;
                            end
                            for (j = i + 1; j < 8; j = j + 1) begin
                                if (j >= count) begin
                                    continue;
                                end

                                dx1 = $signed(x[j]) - $signed(x[i]);
                                dy1 = $signed(y[j]) - $signed(y[i]);

                                on_line_count = 4'd0;
                                rem_count = 4'd0;
                                for (k = 0; k < 8; k = k + 1) begin
                                    if (k >= count) begin
                                        continue;
                                    end
                                    dx2 = $signed(x[k]) - $signed(x[i]);
                                    dy2 = $signed(y[k]) - $signed(y[j]);

                                    cross1 = dx1 * dy2;
                                    cross2 = dx2 * dy1;

                                    if (cross1 == cross2) begin
                                        on_line_count = on_line_count + 4'd1;
                                    end else begin
                                        rem_x[rem_count] = x[k];
                                        rem_y[rem_count] = y[k];
                                        rem_count = rem_count + 4'd1;
                                    end
                                end

                                if (rem_count <= 2) begin
                                    found = 1'b1;
                                end else begin
                                    all_collinear = 1'b1;
                                    dx_rem1 = $signed(rem_x[1]) - $signed(rem_x[0]);
                                    dy_rem1 = $signed(rem_y[1]) - $signed(rem_y[0]);

                                    for (m = 2; m < 8; m = m + 1) begin
                                        if (m >= rem_count) begin
                                            continue;
                                        end
                                        dx_rem2 = $signed(rem_x[m]) - $signed(rem_x[0]);
                                        dy_rem2 = $signed(rem_y[m]) - $signed(rem_y[1]);

                                        cross_rem1 = dx_rem1 * dy_rem2;
                                        cross_rem2 = dx_rem2 * dy_rem1;

                                        if (cross_rem1 != cross_rem2) begin
                                            all_collinear = 1'b0;
                                        end
                                    end

                                    if (all_collinear) begin
                                        found = 1'b1;
                                    end
                                end

                                if (found) begin
                                    break;
                                end
                            end
                            if (found) begin
                                break;
                            end
                        end

                        success <= found;
                    end
                    state <= DONE_STATE;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule