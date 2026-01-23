module tv_coverage (
    input clk, input rst_n, input start,
    input [7:0] N, input [15:0] D,
    input [7:0] transmitter_flags,
    input [15:0] X [0:7], input [15:0] H [0:7],
    output real covered_length, output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMP = 2'd1;
    localparam [1:0] MERGE = 2'd2;
    localparam [1:0] CALC = 2'd3;

    reg [1:0] state;
    reg [3:0] i, j, k;
    reg [3:0] cnt;
    reg valid [0:7];
    real intervals_left [0:7];
    real intervals_right [0:7];
    real total_length;
    real current_left;
    real current_right;
    real temp_left;
    real temp_right;
    real left_bounds [0:7];
    real right_bounds [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            covered_length <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            cnt <= 0;
            for (k = 0; k < 8; k = k + 1) begin
                valid[k] <= 1'b0;
                intervals_left[k] <= 0;
                intervals_right[k] <= 0;
                left_bounds[k] <= 0;
                right_bounds[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMP;
                        i <= 0;
                        j <= 0;
                        cnt <= 0;
                        for (k = 0; k < 8; k = k + 1) begin
                            valid[k] <= 1'b0;
                            left_bounds[k] <= 0;
                            right_bounds[k] <= 0;
                        end
                    end
                end
                COMP: begin
                    if (i < N) begin
                        if (transmitter_flags[i]) begin
                            if (j == 0) begin
                                left_bounds[i] = 0;
                                right_bounds[i] = D;
                                valid[i] <= 1'b1;
                            end
                            if (j < N) begin
                                if (j != i) begin
                                    if (X[j] < X[i]) begin
                                        if (H[j] * (X[i] - X[j]) > 0) begin
                                            real limit = X[j] - (H[j] / H[i]) * (X[i] - X[j]);
                                            if (limit > left_bounds[i]) begin
                                                left_bounds[i] = limit;
                                            end
                                        end
                                    end else if (X[j] > X[i]) begin
                                        if (H[j] * (X[j] - X[i]) > 0) begin
                                            real limit = X[j] + (H[j] / H[i]) * (X[j] - X[i]);
                                            if (limit < right_bounds[i]) begin
                                                right_bounds[i] = limit;
                                            end
                                        end
                                    end
                                end
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        state <= MERGE;
                        cnt <= 0;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (valid[k]) begin
                                intervals_left[cnt] = left_bounds[k];
                                intervals_right[cnt] = right_bounds[k];
                                cnt <= cnt + 1;
                            end
                        end
                        k <= 0;
                    end
                end
                MERGE: begin
                    if (cnt > 0) begin
                        if (k < cnt - 1) begin
                            if (intervals_left[k] > intervals_left[k + 1]) begin
                                temp_left = intervals_left[k];
                                temp_right = intervals_right[k];
                                intervals_left[k] = intervals_left[k + 1];
                                intervals_right[k] = intervals_right[k + 1];
                                intervals_left[k + 1] = temp_left;
                                intervals_right[k + 1] = temp_right;
                            end
                            k <= k + 1;
                        end else begin
                            current_left = intervals_left[0];
                            current_right = intervals_right[0];
                            total_length = 0;
                            k <= 1;
                            state <= CALC;
                        end
                    end else begin
                        covered_length <= 0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                CALC: begin
                    if (k < cnt) begin
                        if (intervals_left[k] <= current_right) begin
                            if (intervals_right[k] > current_right) begin
                                current_right = intervals_right[k];
                            end
                        end else begin
                            total_length = total_length + (current_right - current_left);
                            current_left = intervals_left[k];
                            current_right = intervals_right[k];
                        end
                        k <= k + 1;
                    end else begin
                        total_length = total_length + (current_right - current_left);
                        covered_length <= total_length;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule