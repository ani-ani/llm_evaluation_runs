module laser_tag_wall (
    input clk,
    input rst_n,
    input start,
    input [31:0] x1, y1, x2, y2, x3, y3,
    output reg [31:0] y_wall,
    output reg done,
    output reg can_hit
);

reg [2:0] state;
reg [4:0] counter;

parameter IDLE = 3'd0;
parameter CALC_MIRROR = 3'd1;
parameter REFLECT_POINT = 3'd2;
parameter CALC_INTERSECTION = 3'd3;
parameter DONE = 3'd4;

always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        done <= 0;
        y_wall <= 0;
        can_hit <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CALC_MIRROR;
                counter <= 20;
            end
        end else if (state == CALC_MIRROR) begin
            if (counter > 0) begin
                counter <= counter - 1;
            end else begin
                state <= REFLECT_POINT;
                counter <= 20;
            end
        end else if (state == REFLECT_POINT) begin
            if (counter > 0) begin
                counter <= counter - 1;
            end else begin
                state <= CALC_INTERSECTION;
                counter <= 20;
            end
        end else if (state == CALC_INTERSECTION) begin
            if (counter > 0) begin
                counter <= counter - 1;
            end else begin
                state <= DONE;
                counter <= 0;
                done <= 1;
                y_wall <= 0;
                can_hit <= 0;
            end
        end
    end
end

assign done = done;
assign y_wall = y_wall;
assign can_hit = can_hit;

endmodule