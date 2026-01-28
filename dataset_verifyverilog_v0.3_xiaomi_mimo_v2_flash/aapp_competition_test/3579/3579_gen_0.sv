module mad_calculator (
    input clk,
    input rst_n,
    input start,
    input [3:0] h, w,
    input [3:0] a, b,
    input [63:0] grid,
    output reg [31:0] median,
    output reg done
);

parameter MAX_H = 4;
parameter MAX_W = 2;
parameter MAX_RECT = 30;

reg [7:0] grid_2d [0:MAX_H-1][0:MAX_W-1];
reg [31:0] ps [0:MAX_H][0:MAX_W];
reg [3:0] top, bottom, left, right;
reg [5:0] rect_count;
reg [31:0] rect_sum [0:MAX_RECT-1];
reg [3:0] rect_area [0:MAX_RECT-1];

localparam [4:0] S_IDLE = 5'd0;
localparam [4:0] S_COMPUTE_PS = 5'd1;
localparam [4:0] S_INIT_RECT = 5'd2;
localparam [4:0] S_CHECK_RECT = 5'd3;
localparam [4:0] S_COMPUTE_RECT = 5'd4;
localparam [4:0] S_STORE_RECT = 5'd5;
localparam [4:0] S_NEXT_ITER = 5'd6;
localparam [4:0] S_SORT_INIT = 5'd7;
localparam [4:0] S_SORT_INNER_LOOP = 5'd8;
localparam [4:0] S_SORT_COMPARE = 5'd9;
localparam [4:0] S_SORT_SWAP = 5'd10;
localparam [4:0] S_SORT_INCREMENT_J = 5'd11;
localparam [4:0] S_MEDIAN = 5'd12;
localparam [4:0] S_COMPUTE_DENSITY = 5'd13;
localparam [4:0] S_DONE = 5'd14;

reg [4:0] state;
reg [3:0] i, j;
reg [5:0] sort_i, sort_j;
reg [31:0] comp_sum1, comp_sum2;
reg [3:0] comp_area1, comp_area2;
reg signed [63:0] product1, product2;
reg [31:0] temp_sum, temp_area;
reg [31:0] median_temp, divisor_temp;
reg [3:0] idx_odd, idx_even;

integer k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        median <= 32'd0;
        rect_count <= 6'd0;
        top <= 4'd0; bottom <= 4'd0; left <= 4'd0; right <= 4'd0;
        i <= 4'd0; j <= 4'd0;
        sort_i <= 6'd0; sort_j <= 6'd0;
        comp_sum1 <= 32'd0; comp_sum2 <= 32'd0;
        comp_area1 <= 4'd0; comp_area2 <= 4'd0;
        product1 <= 64'd0; product2 <= 64'd0;
        temp_sum <= 32'd0; temp_area <= 32'd0;
        median_temp <= 32'd0; divisor_temp <= 32'd0;
        idx_odd <= 4'd0; idx_even <= 4'd0;
        for (k = 0; k < MAX_H; k = k + 1) begin
            grid_2d[k][0] <= 8'd0;
            grid_2d[k][1] <= 8'd0;
        end
        for (k = 0; k <= MAX_H; k = k + 1) begin
            ps[k][0] <= 32'd0;
            ps[k][1] <= 32'd0;
            ps[k][2] <= 32'd0;
        end
        for (k = 0; k < MAX_RECT; k = k + 1) begin
            rect_sum[k] <= 32'd0;
            rect_area[k] <= 4'd0;
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    grid_2d[0][0] <= grid[7:0];
                    grid_2d[0][1] <= grid[15:8];
                    grid_2d[1][0] <= grid[23:16];
                    grid_2d[1][1] <= grid[31:24];
                    grid_2d[2][0] <= grid[39:32];
                    grid_2d[2][1] <= grid[47:40];
                    grid_2d[3][0] <= grid[55:48];
                    grid_2d[3][1] <= grid[63:56];
                    state <= S_COMPUTE_PS;
                    i <= 4'd0;
                    j <= 4'd0;
                    rect_count <= 6'd0;
                end
            end

            S_COMPUTE_PS: begin
                if (i <= h && j <= w) begin
                    if (i == 0 || j == 0) begin
                        ps[i][j] <= 32'd0;
                    end else begin
                        ps[i][j] <= ps[i-1][j] + ps[i][j-1] - ps[i-1][j-1] + grid_2d[i-1][j-1];
                    end
                    if (j < w) begin
                        j <= j + 1;
                    end else begin
                        j <= 4'd0;
                        if (i < h) begin
                            i <= i + 1;
                        end else begin
                            state <= S_INIT_RECT;
                        end
                    end
                end
            end

            S_INIT_RECT: begin
                top <= 4'd0;
                bottom <= 4'd0;
                left <= 4'd0;
                right <= 4'd0;
                rect_count <= 6'd0;
                state <= S_CHECK_RECT;
            end

            S_CHECK_RECT: begin
                state <= S_COMPUTE_RECT;
            end

            S_COMPUTE_RECT: begin
                temp_area <= (bottom - top + 1) * (right - left + 1);
                temp_sum <= ps[bottom+1][right+1] - ps[top][right+1] - ps[bottom+1][left] + ps[top][left];
                state <= S_STORE_RECT;
            end

            S_STORE_RECT: begin
                if (temp_area >= a && temp_area <= b && rect_count < MAX_RECT) begin
                    rect_sum[rect_count] <= temp_sum;
                    rect_area[rect_count] <= temp_area;
                    rect_count <= rect_count + 1;
                end
                state <= S_NEXT_ITER;
            end

            S_NEXT_ITER: begin
                if (right < w-1) begin
                    right <= right + 1;
                    state <= S_CHECK_RECT;
                end else if (left < w-1) begin
                    left <= left + 1;
                    right <= left + 1;
                    state <= S_CHECK_RECT;
                end else if (bottom < h-1) begin
                    bottom <= bottom + 1;
                    left <= 4'd0;
                    right <= 4'd0;
                    state <= S_CHECK_RECT;
                end else if (top < h-1) begin
                    top <= top + 1;
                    bottom <= top + 1;
                    left <= 4'd0;
                    right <= 4'd0;
                    state <= S_CHECK_RECT;
                end else begin
                    if (rect_count == 6'd0) begin
                        median <= 32'd0;
                        state <= S_DONE;
                    end else begin
                        state <= S_SORT_INIT;
                    end
                end
            end

            S_SORT_INIT: begin
                sort_i <= 6'd0;
                state <= S_SORT_INNER_LOOP;
            end

            S_SORT_INNER_LOOP: begin
                if (sort_i < rect_count - 1) begin
                    sort_j <= 6'd0;
                    state <= S_SORT_COMPARE;
                end else begin
                    state <= S_MEDIAN;
                end
            end

            S_SORT_COMPARE: begin
                comp_sum1 <= rect_sum[sort_j];
                comp_sum2 <= rect_sum[sort_j + 1];
                comp_area1 <= rect_area[sort_j];
                comp_area2 <= rect_area[sort_j + 1];
                state <= S_SORT_SWAP;
            end

            S_SORT_SWAP: begin
                product1 <= comp_sum1 * comp_area2;
                product2 <= comp_sum2 * comp_area1;
                state <= S_SORT_INCREMENT_J;
            end

            S_SORT_INCREMENT_J: begin
                if (product1 > product2) begin
                    rect_sum[sort_j] <= comp_sum2;
                    rect_sum[sort_j + 1] <= comp_sum1;
                    rect_area[sort_j] <= comp_area2;
                    rect_area[sort_j + 1] <= comp_area1;
                end
                if (sort_j < rect_count - sort_i - 2) begin
                    sort_j <= sort_j + 1;
                    state <= S_SORT_COMPARE;
                end else begin
                    sort_i <= sort_i + 1;
                    state <= S_SORT_INNER_LOOP;
                end
            end

            S_MEDIAN: begin
                idx_odd <= rect_count >> 1;
                idx_even <= (rect_count >> 1) - 1;
                state <= S_COMPUTE_DENSITY;
            end

            S_COMPUTE_DENSITY: begin
                if (rect_count[0]) begin
                    median_temp <= rect_sum[idx_odd];
                    divisor_temp <= rect_area[idx_odd];
                end else begin
                    median_temp <= rect_sum[idx_even] + rect_sum[idx_odd];
                    divisor_temp <= rect_area[idx_even] + rect_area[idx_odd];
                end
                if (divisor_temp != 32'd0) begin
                    median <= (median_temp * 32'h00010000) / divisor_temp;
                end else begin
                    median <= 32'd0;
                end
                state <= S_DONE;
            end

            S_DONE: begin
                done <= 1'b1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule