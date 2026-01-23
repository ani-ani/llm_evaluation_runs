module tv_coverage (
    input clk, input rst_n, input start,
    input [7:0] N, input [15:0] D,
    input [7:0] transmitter_flags,
    input [15:0] X_0, input [15:0] X_1, input [15:0] X_2, input [15:0] X_3,
    input [15:0] X_4, input [15:0] X_5, input [15:0] X_6, input [15:0] X_7,
    input [15:0] H_0, input [15:0] H_1, input [15:0] H_2, input [15:0] H_3,
    input [15:0] H_4, input [15:0] H_5, input [15:0] H_6, input [15:0] H_7,
    output reg real covered_length, output reg done
);

    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] COMP          = 3'd1;
    localparam [2:0] MERGE_SORT    = 3'd2;
    localparam [2:0] MERGE_INTERVALS = 3'd3;
    localparam [2:0] DONE_STATE    = 3'd4;
    
    reg [2:0] state;
    reg [3:0] i, j, k;
    real left_bounds [0:7];
    real right_bounds [0:7];
    reg valid [0:7];
    real intervals_left [0:7];
    real intervals_right [0:7];
    real total_length, current_left, current_right;
    real temp_left, temp_right;
    integer cnt;
    integer m; // For-loop variable

    // Array unpacking
    wire [15:0] X [0:7];
    wire [15:0] H [0:7];
    assign X[0] = X_0; assign X[1] = X_1; assign X[2] = X_2; assign X[3] = X_3;
    assign X[4] = X_4; assign X[5] = X_5; assign X[6] = X_6; assign X[7] = X_7;
    assign H[0] = H_0; assign H[1] = H_1; assign H[2] = H_2; assign H[3] = H_3;
    assign H[4] = H_4; assign H[5] = H_5; assign H[6] = H_6; assign H[7] = H_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            covered_length <= 0.0;
            for (m = 0; m < 8; m = m + 1) begin
                left_bounds[m] <= 0.0;
                right_bounds[m] <= 0.0;
                valid[m] <= 1'b0;
                intervals_left[m] <= 0.0;
                intervals_right[m] <= 0.0;
            end
            total_length <= 0.0;
            current_left <= 0.0;
            current_right <= 0.0;
            temp_left <= 0.0;
            temp_right <= 0.0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    covered_length <= 0.0;
                    if (start) begin
                        state <= COMP;
                        i <= 4'd0;
                        j <= 4'd0;
                        cnt <= 0;
                        for (m = 0; m < 8; m = m + 1) begin
                            valid[m] <= 1'b0;
                        end
                    end
                end
                
                COMP: begin
                    if (i < N) begin
                        if (transmitter_flags[i]) begin
                            if (j == 4'd0) begin
                                left_bounds[i] <= 0.0;
                                right_bounds[i] <= real'(D);
                                valid[i] <= 1'b1;
                            end
                            if (j < 4'd8) begin
                                if (j != i) begin
                                    real x_t = real'(X[i]);
                                    real h_t = real'(H[i]);
                                    real x_j = real'(X[j]);
                                    real h_j = real'(H[j]);
                                    
                                    if (x_j < x_t) begin
                                        real limit = x_j - (h_j/h_t)*(x_t-x_j);
                                        if (limit > left_bounds[i]) begin
                                            left_bounds[i] <= limit;
                                        end
                                    end else if (x_j > x_t) begin
                                        real limit = x_j + (h_j/h_t)*(x_j-x_t);
                                        if (limit < right_bounds[i]) begin
                                            right_bounds[i] <= limit;
                                        end
                                    end
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= MERGE_SORT;
                        cnt <= 0;
                        for (m = 0; m < 8; m = m + 1) begin
                            if (valid[m]) begin
                                intervals_left[cnt] <= left_bounds[m];
                                intervals_right[cnt] <= right_bounds[m];
                                cnt <= cnt + 1;
                            end
                        end
                        k <= 4'd0;
                    end
                end
                
                MERGE_SORT: begin
                    if (cnt > 1 && k[3:0] < (cnt-1)) begin
                        if (intervals_left[k] > intervals_left[k+4'd1]) begin
                            temp_left <= intervals_left[k];
                            temp_right <= intervals_right[k];
                            intervals_left[k] <= intervals_left[k+4'd1];
                            intervals_right[k] <= intervals_right[k+4'd1];
                            intervals_left[k+4'd1] <= temp_left;
                            intervals_right[k+4'd1] <= temp_right;
                        end
                        k <= k + 4'd1;
                    end else begin
                        if (k == (cnt-1)) begin
                            state <= MERGE_INTERVALS;
                            current_left <= intervals_left[0];
                            current_right <= intervals_right[0];
                            total_length <= 0.0;
                            k <= 4'd1;
                        end else begin
                            k <= 4'd0;
                        end
                    end
                end
                
                MERGE_INTERVALS: begin
                    if (k < cnt) begin
                        if (intervals_left[k] <= current_right) begin
                            if (intervals_right[k] > current_right) begin
                                current_right <= intervals_right[k];
                            end
                        end else begin
                            total_length <= total_length + (current_right - current_left);
                            current_left <= intervals_left[k];
                            current_right <= intervals_right[k];
                        end
                        k <= k + 4'd1;
                    end else begin
                        total_length <= total_length + (current_right - current_left);
                        covered_length <= total_length;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
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