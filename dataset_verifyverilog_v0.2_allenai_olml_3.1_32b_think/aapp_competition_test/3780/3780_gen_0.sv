module rescue_planner (input clk, input rst_n, input start, input signed [31:0] dx, input signed [31:0] dy, input signed [31:0] v_max, input signed [31:0] t_wind, input signed [31:0] vx, input signed [31:0] vy, input signed [31:0] wx, input signed [31:0] wy, output reg done, output reg [31:0] result);
localparam IDLE = 4'd0, SETUP = 4'd1, CALC_WIND = 4'd2, CHECK_DIST = 4'd3, ITERATE = 4'd4, DONE = 4'd5;
reg [63:0] low, high, mid, iteration;
reg [63:0] min_time;
reg [3:0] state;
reg done_reg;
reg [31:0] result_reg;
initial begin
    low = 64'd0;
    high = 64'd0x00001E84800000;
    iteration = 32'd32;
    min_time = 64'd0xFFFFFFFFFFFFFFFF;
    state = IDLE;
    done_reg = 1'b0;
    result_reg = 32'd0;
end
assign done = done_reg;
assign result = result_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        low <= 64'd0;
        high <= 64'd0x00001E84800000;
        iteration <= 32'd32;
        min_time <= 64'd0xFFFFFFFFFFFFFFFF;
        state <= IDLE;
        done_reg <= 1'b0;
        result_reg <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= SETUP;
                else state <= IDLE;
            end
            SETUP: begin
                low <= 64'd0;
                high <= 64'd0x00001E84800000;
                iteration <= 32'd32;
                min_time <= 64'd0xFFFFFFFFFFFFFFFF;
                state <= CALC_WIND;
            end
            CALC_WIND: begin
                mid <= (low + high) >> 1;
                state <= CHECK_DIST;
            end
            CHECK_DIST: begin
                wire [63:0] t_wind_64 = {{t_wind[31], t_wind[31:0]}};
                wire [63:0] mid_64 = mid;
                wire is_ge = (mid_64 >= t_wind_64);
                reg [63:0] wind_x, wind_y;
                if (is_ge) begin
                    reg [63:0] vx_sxt = {{vx[31], vx[31:0]}};
                    reg [63:0] vy_sxt = {{vy[31], vy[31:0]}};
                    reg [63:0] wx_sxt = {{wx[31], wx[31:0]}};
                    reg [63:0] wy_sxt = {{wy[31], wy[31:0]}};
                    wind_x = vx_sxt * t_wind_64;
                    wind_y = vy_sxt * t_wind_64;
                    reg [63:0] delta_T = mid_64 - t_wind_64;
                    wind_x = wind_x + wx_sxt * delta_T;
                    wind_y = wind_y + wy_sxt * delta_T;
                end else begin
                    reg [63:0] vx_sxt = {{vx[31], vx[31:0]}};
                    reg [63:0] vy_sxt = {{vy[31], vy[31:0]}};
                    wind_x = vx_sxt * mid_64;
                    wind_y = vy_sxt * mid_64;
                end
                reg [63:0] dx_64 = {{dx, 32{1'b0}}};
                reg [63:0] dy_64 = {{dy, 32{1'b0}}};
                reg [63:0] diff_x = dx_64 - wind_x;
                reg [63:0] diff_y = dy_64 - wind_y;
                reg [63:0] v_max_sxt = {{v_max[31], v_max[31:0]}};
                reg [63:0] v_max_mid = v_max_sxt * mid_64;
                reg [63:0] sq_diff_x = diff_x * diff_x;
                reg [63:0] sq_diff_y = diff_y * diff_y;
                reg [63:0] sq_sum = sq_diff_x + sq_diff_y;
                reg [63:0] sq_vm = v_max_mid * v_max_mid;
                wire condition_met = sq_sum <= sq_vm;
                if (condition_met) begin
                    if (mid_64 < min_time) min_time <= mid_64;
                    high <= mid_64;
                end else begin
                    low <= mid_64 + 1;
                end
                state <= ITERATE;
            end
            ITERATE: begin
                iteration <= iteration - 1;
                if (iteration > 0) state <= CALC_WIND;
                else state <= DONE;
            end
            DONE: begin
                done_reg <= 1'b1;
                result_reg <= min_time[31:0];
                state <= DONE;
            end
            default: state <= IDLE;
        endcase
    end
endmodule