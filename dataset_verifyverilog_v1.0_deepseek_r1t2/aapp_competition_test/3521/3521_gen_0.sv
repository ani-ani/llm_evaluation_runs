
module starship_max_distance #(
    parameter N = 4,
    parameter STEPS = 256,
    parameter DATA_WIDTH = 32,
    parameter ANGLE_WIDTH = 16,
    parameter FRAC_BITS = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] t_0, t_1, t_2, t_3, t_4, t_5, t_6, t_7,
    input wire [DATA_WIDTH-1:0] s_0, s_1, s_2, s_3, s_4, s_5, s_6, s_7,
    input wire [ANGLE_WIDTH-1:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg [DATA_WIDTH-1:0] max_distance,
    output reg done
);

localparam TWO_PI_Q16 = 32'h0006487F;
localparam TWO_PI_RAW = 16'h0001;

localparam STATE_IDLE = 3'd0;
localparam STATE_INIT_ANGLE = 3'd1;
localparam STATE_RESET_SUM = 3'd2;
localparam STATE_ADD_STAR = 3'd3;
localparam STATE_CHECK_DONE = 3'd4;
localparam STATE_DONE = 3'd5;

reg [2:0] state;
reg [7:0] angle_step;
reg [2:0] star_idx;
reg signed [DATA_WIDTH-1:0] current_sum;
reg signed [DATA_WIDTH-1:0] max_sum;
reg signed [ANGLE_WIDTH-1:0] current_angle;
reg signed [DATA_WIDTH-1:0] contribution;

wire signed [DATA_WIDTH-1:0] t_sel = 
    (star_idx == 3'd0) ? t_0 :
    (star_idx == 3'd1) ? t_1 :
    (star_idx == 3'd2) ? t_2 :
    (star_idx == 3'd3) ? t_3 :
    (star_idx == 3'd4) ? t_4 :
    (star_idx == 3'd5) ? t_5 :
    (star_idx == 3'd6) ? t_6 : t_7;

wire signed [DATA_WIDTH-1:0] s_sel = 
    (star_idx == 3'd0) ? s_0 :
    (star_idx == 3'd1) ? s_1 :
    (star_idx == 3'd2) ? s_2 :
    (star_idx == 3'd3) ? s_3 :
    (star_idx == 3'd4) ? s_4 :
    (star_idx == 3'd5) ? s_5 :
    (star_idx == 3'd6) ? s_6 : s_7;

wire signed [ANGLE_WIDTH-1:0] a_sel = 
    (star_idx == 3'd0) ? a_0 :
    (star_idx == 3'd1) ? a_1 :
    (star_idx == 3'd2) ? a_2 :
    (star_idx == 3'd3) ? a_3 :
    (star_idx == 3'd4) ? a_4 :
    (star_idx == 3'd5) ? a_5 :
    (star_idx == 3'd6) ? a_6 : a_7;

wire signed [ANGLE_WIDTH-1:0] diff_abs = 
    (current_angle > a_sel) ? (current_angle - a_sel) : (a_sel - current_angle);
wire signed [ANGLE_WIDTH-1:0] diff_complement = TWO_PI_RAW - diff_abs;
wire signed [ANGLE_WIDTH-1:0] dist = 
    (diff_abs < diff_complement) ? diff_abs : diff_complement;

wire signed [DATA_WIDTH*2-1:0] product_raw = s_sel * dist;
wire signed [DATA_WIDTH-1:0] product_q16 = product_raw[FRAC_BITS*2 +: DATA_WIDTH];

wire signed [DATA_WIDTH-1:0] contrib = 
    (t_sel > product_q16) ? (t_sel - product_q16) : 32'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        max_distance <= 32'd0;
        angle_step <= 8'd0;
        star_idx <= 3'd0;
        current_sum <= 32'd0;
        max_sum <= 32'd0;
        current_angle <= 16'd0;
        contribution <= 32'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    angle_step <= 8'd0;
                    max_sum <= 32'd0;
                    state <= STATE_INIT_ANGLE;
                end
            end
            
            STATE_INIT_ANGLE: begin
                current_angle <= (angle_step * TWO_PI_Q16) >> 8;
                state <= STATE_RESET_SUM;
            end
            
            STATE_RESET_SUM: begin
                current_sum <= 32'd0;
                star_idx <= 3'd0;
                state <= STATE_ADD_STAR;
            end
            
            STATE_ADD_STAR: begin
                current_sum <= current_sum + contrib;
                
                if (star_idx == N-1) begin
                    if (current_sum > max_sum) 
                        max_sum <= current_sum;
                    state <= STATE_CHECK_DONE;
                end else begin
                    star_idx <= star_idx + 3'd1;
                end
            end
            
            STATE_CHECK_DONE: begin
                if (angle_step >= STEPS-1) begin
                    state <= STATE_DONE;
                end else begin
                    angle_step <= angle_step + 8'd1;
                    state <= STATE_INIT_ANGLE;
                end
            end
            
            STATE_DONE: begin
                max_distance <= max_sum;
                done <= 1'b1;
                state <= STATE_IDLE;
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule