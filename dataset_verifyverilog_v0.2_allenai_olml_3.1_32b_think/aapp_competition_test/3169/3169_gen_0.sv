module stick_sorter (input clk, input rst_n, input start, input [15:0] s0_x1, s0_y1, s0_x2, s0_y2, input [15:0] s1_x1, s1_y1, s1_x2, s1_y2, input [15:0] s2_x1, s2_y1, s2_x2, s2_y2, input [15:0] s3_x1, s3_y1, s3_x2, s3_y2, input [15:0] s4_x1, s4_y1, s4_x2, s4_y2, input [15:0] s5_x1, s5_y1, s5_x2, s5_y2, input [15:0] s6_x1, s6_y1, s6_x2, s6_y2, input [15:0] s7_x1, s7_y1, s7_x2, s7_y2, input [2:0] n_sticks, output reg [3:0] order_0, order_1, order_2, order_3, order_4, order_5, order_6, order_7, output reg done);
reg [7:0] removed_sticks;
reg [3:0] order_pos;
reg [3:0] selected_stick;
reg [3:0] state;
localparam IDLE=4'd0, FIND_NEXT=4'd1, UPDATE_REMOVED=4'd2, DONE=4'd3;
always @(posedge clk) begin
    if (!rst_n) begin
        removed_sticks <= 8'b0;
        order_pos <= 4'd0;
        selected_stick <= 4'd0;
        state <= IDLE;
        done <= 0;
        order_0 <=4'd0; order_1<=4'd0; order_2<=4'd0; order_3<=4'd0;
        order_4<=4'd0; order_5<=4'd0; order_6<=4'd0; order_7<=4'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= FIND_NEXT;
                else state <= IDLE;
            end
            FIND_NEXT: begin
                selected_stick <= 0;
                if (! (n_sticks>0 && !removed_sticks[0])) selected_stick <=1;
                if (! (n_sticks>1 && !removed_sticks[1])) selected_stick <=2;
                if (! (n_sticks>2 && !removed_sticks[2])) selected_stick <=3;
                if (! (n_sticks>3 && !removed_sticks[3])) selected_stick <=4;
                if (! (n_sticks>4 && !removed_sticks[4])) selected_stick <=5;
                if (! (n_sticks>5 && !removed_sticks[5])) selected_stick <=6;
                if (! (n_sticks>6 && !removed_sticks[6])) selected_stick <=7;
                state <= UPDATE_REMOVED;
            end
            UPDATE_REMOVED: begin
                case (order_pos)
                    0: order_0 <= selected_stick;
                    1: order_1 <= selected_stick;
                    2: order_2 <= selected_stick;
                    3: order_3 <= selected_stick;
                    4: order_4 <= selected_stick;
                    5: order_5 <= selected_stick;
                    6: order_6 <= selected_stick;
                    7: order_7 <= selected_stick;
                    default: state <= DONE;
                endcase
                order_pos <= order_pos +1;
                if (order_pos == n_sticks) begin
                    done <=1;
                    state <= DONE;
                end else begin
                    state <= FIND_NEXT;
                end
            end
            DONE: state <= DONE;
        endcase
    end
endmodule