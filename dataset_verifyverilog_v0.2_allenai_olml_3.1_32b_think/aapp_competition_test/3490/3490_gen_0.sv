module witch_collision (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [31:0] x0, y0, r0,
    input [31:0] x1, y1, r1,
    input [31:0] x2, y2, r2,
    input [31:0] x3, y3, r3,
    output reg crash,
    output reg done
);

parameter IDLE = 2'd0,
                    PREPARE_TIPS = 2'd1,
                    CHECK_COLLISIONS = 2'd2,
                    DONE = 2'd3;

reg [1:0] state;

reg [31:0] tip_x [4:0];
reg [31:0] tip_y [4:0];

reg [3:0] check_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        check_counter <=0;
        tip_x <= 32'h0;
        tip_y <= 32'h0;
        crash <=0;
        done <=0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= PREPARE_TIPS;
                end else begin
                    state <= IDLE;
                end
            end
            PREPARE_TIPS: begin
                tip_x[0] <= x0 + 32'h00010000;
                tip_y[0] <= y0;
                tip_x[1] <= x1 + 32'h00010000;
                tip_y[1] <= y1;
                tip_x[2] <= x2 + 32'h00010000;
                tip_y[2] <= y2;
                tip_x[3] <= x3 + 32'h00010000;
                tip_y[3] <= y3;
                state <= CHECK_COLLISIONS;
                check_counter <=0;
            end
            CHECK_COLLISIONS: begin
                integer temp_crash =0;
                signed [31:0] x0_s = (signed)x0;
                signed [31:0] y0_s = (signed)y0;
                signed [31:0] x1_s = (signed)x1;
                signed [31:0] y1_s = (signed)y1;
                signed [31:0] x2_s = (signed)x2;
                signed [31:0] y2_s = (signed)y2;
                signed [31:0] x3_s = (signed)x3;
                signed [31:0] y3_s = (signed)y3;

                if (y0_s == y1_s) begin
                    if (x0_s < x1_s + 32'h00010000) && (x1_s < x0_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                if (y0_s == y2_s) begin
                    if (x0_s < x2_s + 32'h00010000) && (x2_s < x0_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                if (y0_s == y3_s) begin
                    if (x0_s < x3_s + 32'h00010000) && (x3_s < x0_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                if (y1_s == y2_s) begin
                    if (x1_s < x2_s + 32'h00010000) && (x2_s < x1_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                if (y1_s == y3_s) begin
                    if (x1_s < x3_s + 32'h00010000) && (x3_s < x1_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                if (y2_s == y3_s) begin
                    if (x2_s < x3_s + 32'h00010000) && (x3_s < x2_s + 32'h00010000) begin
                        temp_crash =1;
                    end
                end
                crash <= temp_crash;

                if (check_counter == 14) begin
                    state <= DONE;
                end else begin
                    check_counter <= check_counter +1;
                end
            end
            DONE: begin
                done <=1;
            end
        endcase
    end
endmodule