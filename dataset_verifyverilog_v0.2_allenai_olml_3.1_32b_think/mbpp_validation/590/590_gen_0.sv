module polar_rect_converter (
input clk,
input rst_n,
input start,
input [1:0] mode,
input [31:0] input_a,
input [31:0] input_b,
output reg [31:0] output_x,
output reg [31:0] output_y,
output reg done
);

// State encoding
localparam IDLE = 2'd0;
localparam CALC_SQRT = 2'd1;
localparam CALC_TRIG = 2'd2;
localparam DONE = 2'd3;

reg [1:0] state;
reg [31:0] input_a_reg, input_b_reg;
reg [1:0] mode_reg;
reg [63:0] sum_sq;
reg [31:0] sqrt_val, sin_val, cos_val, atan2_val;
reg [3:0] trig_counter, sqrt_counter, atan2_counter;
reg sqrt_done, trig_done, atan2_done;

// Default assignments
assign state = 0;
assign input_a_reg = 0;
assign input_b_reg = 0;
assign mode_reg = 0;
assign sum_sq = 0;
assign sqrt_val = 0;
assign sin_val = 0;
assign cos_val = 0;
assign atan2_val = 0;
assign trig_counter = 0;
assign sqrt_counter = 0;
assign atan2_counter = 0;
assign sqrt_done = 0;
assign trig_done = 0;
assign atan2_done = 0;
assign done = 0;
assign output_x = 0;
assign output_y = 0;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        input_a_reg <= 0;
        input_b_reg <= 0;
        mode_reg <= 0;
        sum_sq <= 0;
        sqrt_val <= 0;
        sin_val <= 0;
        cos_val <= 0;
        atan2_val <= 0;
        trig_counter <= 0;
        sqrt_counter <= 0;
        atan2_counter <= 0;
        sqrt_done <= 0;
        trig_done <= 0;
        atan2_done <= 0;
        done <= 0;
        output_x <= 0;
        output_y <= 0;
    end else begin
        if (start) begin
            if (state == IDLE) begin
                input_a_reg <= input_a;
                input_b_reg <= input_b;
                mode_reg <= mode;
                if (mode_reg == 0) begin
                    state <= CALC_TRIG;
                end else begin
                    state <= CALC_SQRT;
                end
            end
        end
        case (state)
            IDLE: begin
            end
            CALC_SQRT: begin
                sum_sq <= (input_a_reg) [63:0] * input_a_reg + (input_b_reg) [63:0] * input_b_reg;
                if (sqrt_counter < 16) begin
                    sqrt_val <= sum_sq >> 32;
                    sqrt_counter <= sqrt_counter + 1;
                end else begin
                    sqrt_done <= 1;
                    if (mode_reg == 1) begin
                        state <= CALC_TRIG;
                        sqrt_counter <= 0;
                        trig_counter <= 0;
                    end
                end
            end
            CALC_TRIG: begin
                if (mode_reg == 0) begin
                    sin_val <= input_b_reg;
                    cos_val <= input_b_reg;
                    trig_done <= 1;
                end else begin
                    atan2_val <= input_b_reg - input_a_reg;
                    atan2_done <= 1;
                end
                if (trig_done) begin
                    state <= DONE;
                end
            end
            DONE: begin
                if (mode_reg == 0) begin
                    output_x <= ( (input_a_reg) [63:0] * cos_val ) >> 16;
                    output_y <= ( (input_a_reg) [63:0] * sin_val ) >> 16;
                end else begin
                    output_x <= sqrt_val;
                    output_y <= atan2_val;
                end
                done <= 1;
            end
        endcase
    end
endmodule