module drill_min_diameter (
input clk,
input rst_n, // active-low reset
input start,
input [31:0] flaw_x [0:7],
input [31:0] flaw_y [0:7],
output reg [31:0] diameter,
output reg done
);

localparam IDLE = 3'd0, CALC_BBOX = 3'd1, CALC_CENTER = 3'd2, CHECK_SUPPORT = 3'd3, REFINE_RADIUS = 3'd4, DONE = 3'd5;

reg [31:0] center_x, center_y, radius;
reg [31:0] iteration_count;
reg [2:0] state;
reg [31:0] best_x, best_y;

always @(negedge rst_n) begin
    center_x <= 32'd0; center_y <= 32'd0; radius <= 32'd0; iteration_count <= 32'd0; state <= 3'd0; best_x <= 32'd0; best_y <= 32'd0; diameter <= 32'd0; done <= 1'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        center_x <= 32'd0; center_y <= 32'd0; radius <= 32'd0; iteration_count <= 32'd0; state <= 3'd0; best_x <= 32'd0; best_y <= 32'd0; diameter <= 32'd0; done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CALC_BBOX; iteration_count <= 32'd0;
            end
        end else if (state == CALC_BBOX) begin
            state <= CALC_CENTER;
        end else if (state == CALC_CENTER) begin
            reg [31:0] min_x, max_x, min_y, max_y;
            min_x = flaw_x[0]; max_x = flaw_x[0]; min_y = flaw_y[0]; max_y = flaw_y[0];
            if (flaw_x[1] < min_x) min_x = flaw_x[1]; if (flaw_x[1] > max_x) max_x = flaw_x[1];
            if (flaw_y[1] < min_y) min_y = flaw_y[1]; if (flaw_y[1] > max_y) max_y = flaw_y[1];
            if (flaw_x[2] < min_x) min_x = flaw_x[2]; if (flaw_x[2] > max_x) max_x = flaw_x[2];
            if (flaw_y[2] < min_y) min_y = flaw_y[2]; if (flaw_y[2] > max_y) max_y = flaw_y[2];
            if (flaw_x[3] < min_x) min_x = flaw_x[3]; if (flaw_x[3] > max_x) max_x = flaw_x[3];
            if (flaw_y[3] < min_y) min_y = flaw_y[3]; if (flaw_y[3] > max_y) max_y = flaw_y[3];
            if (flaw_x[4] < min_x) min_x = flaw_x[4]; if (flaw_x[4] > max_x) max_x = flaw_x[4];
            if (flaw_y[4] < min_y) min_y = flaw_y[4]; if (flaw_y[4] > max_y) max_y = flaw_y[4];
            if (flaw_x[5] < min_x) min_x = flaw_x[5]; if (flaw_x[5] > max_x) max_x = flaw_x[5];
            if (flaw_y[5] < min_y) min_y = flaw_y[5]; if (flaw_y[5] > max_y) max_y = flaw_y[5];
            if (flaw_x[6] < min_x) min_x = flaw_x[6]; if (flaw_x[6] > max_x) max_x = flaw_x[6];
            if (flaw_y[6] < min_y) min_y = flaw_y[6]; if (flaw_y[6] > max_y) max_y = flaw_y[6];
            if (flaw_x[7] < min_x) min_x = flaw_x[7]; if (flaw_x[7] > max_x) max_x = flaw_x[7];
            if (flaw_y[7] < min_y) min_y = flaw_y[7]; if (flaw_y[7] > max_y) max_y = flaw_y[7];
            center_x <= (min_x + max_x) >> 1; center_y <= (min_y + max_y) >> 1;
            state <= CHECK_SUPPORT;
        end else if (state == CHECK_SUPPORT) begin
            reg [31:0] temp_dist;
            best_x <= flaw_x[0]; best_y <= flaw_y[0];
            temp_dist = (flaw_x[0]-center_x)*(flaw_x[0]-center_x) >> 16 + (flaw_y[0]-center_y)*(flaw_y[0]-center_y) >> 16;
            if ((flaw_x[1]-center_x)*(flaw_x[1]-center_x) >> 16 + (flaw_y[1]-center_y)*(flaw_y[1]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[1]-center_x)*(flaw_x[1]-center_x) >> 16 + (flaw_y[1]-center_y)*(flaw_y[1]-center_y) >> 16;
                best_x <= flaw_x[1]; best_y <= flaw_y[1];
            end
            if ((flaw_x[2]-center_x)*(flaw_x[2]-center_x) >> 16 + (flaw_y[2]-center_y)*(flaw_y[2]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[2]-center_x)*(flaw_x[2]-center_x) >> 16 + (flaw_y[2]-center_y)*(flaw_y[2]-center_y) >> 16;
                best_x <= flaw_x[2]; best_y <= flaw_y[2];
            end
            if ((flaw_x[3]-center_x)*(flaw_x[3]-center_x) >> 16 + (flaw_y[3]-center_y)*(flaw_y[3]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[3]-center_x)*(flaw_x[3]-center_x) >> 16 + (flaw_y[3]-center_y)*(flaw_y[3]-center_y) >> 16;
                best_x <= flaw_x[3]; best_y <= flaw_y[3];
            end
            if ((flaw_x[4]-center_x)*(flaw_x[4]-center_x) >> 16 + (flaw_y[4]-center_y)*(flaw_y[4]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[4]-center_x)*(flaw_x[4]-center_x) >> 16 + (flaw_y[4]-center_y)*(flaw_y[4]-center_y) >> 16;
                best_x <= flaw_x[4]; best_y <= flaw_y[4];
            end
            if ((flaw_x[5]-center_x)*(flaw_x[5]-center_x) >> 16 + (flaw_y[5]-center_y)*(flaw_y[5]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[5]-center_x)*(flaw_x[5]-center_x) >> 16 + (flaw_y[5]-center_y)*(flaw_y[5]-center_y) >> 16;
                best_x <= flaw_x[5]; best_y <= flaw_y[5];
            end
            if ((flaw_x[6]-center_x)*(flaw_x[6]-center_x) >> 16 + (flaw_y[6]-center_y)*(flaw_y[6]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[6]-center_x)*(flaw_x[6]-center_x) >> 16 + (flaw_y[6]-center_y)*(flaw_y[6]-center_y) >> 16;
                best_x <= flaw_x[6]; best_y <= flaw_y[6];
            end
            if ((flaw_x[7]-center_x)*(flaw_x[7]-center_x) >> 16 + (flaw_y[7]-center_y)*(flaw_y[7]-center_y) >> 16 > temp_dist) begin
                temp_dist = (flaw_x[7]-center_x)*(flaw_x[7]-center_x) >> 16 + (flaw_y[7]-center_y)*(flaw_y[7]-center_y) >> 16;
                best_x <= flaw_x[7]; best_y <= flaw_y[7];
            end
            state <= REFINE_RADIUS;
        end else if (state == REFINE_RADIUS) begin
            center_x <= (center_x + best_x) >> 1; center_y <= (center_y + best_y) >> 1;
            iteration_count <= iteration_count + 1;
            if (iteration_count == 16) begin
                state <= DONE;
            end else begin
                state <= CHECK_SUPPORT;
            end
        end else if (state == DONE) begin
            diameter <= radius << 1; done <= 1'b1;
        end
    end
end

assign diameter = diameter; assign done = done;

endmodule