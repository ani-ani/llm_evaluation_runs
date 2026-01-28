module circular_snake_rooms(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [1:0] belt_0,
    input [1:0] belt_1,
    input [1:0] belt_2,
    input [1:0] belt_3,
    input [1:0] belt_4,
    input [1:0] belt_5,
    input [1:0] belt_6,
    input [1:0] belt_7,
    input [1:0] belt_8,
    input [1:0] belt_9,
    input [1:0] belt_10,
    input [1:0] belt_11,
    input [1:0] belt_12,
    input [1:0] belt_13,
    input [1:0] belt_14,
    input [1:0] belt_15,
    output reg [5:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ALL = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [3:0] i;
    reg [5:0] counter;
    reg all_clockwise;
    reg all_anticlockwise;
    reg [1:0] belt_reg [0:15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            counter <= 6'd0;
            all_clockwise <= 1'b0;
            all_anticlockwise <= 1'b0;
            result <= 6'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_ALL;
                        all_clockwise <= 1'b1;
                        all_anticlockwise <= 1'b1;
                        i <= 4'd0;
                    end
                end

                CHECK_ALL: begin
                    if (i < n) begin
                        belt_reg[i] <= {belt_0, belt_1, belt_2, belt_3, belt_4, belt_5, belt_6, belt_7, belt_8, belt_9, belt_10, belt_11, belt_12, belt_13, belt_14, belt_15}[i];
                        if (belt_reg[i] != 2'd0) begin
                            all_clockwise <= 1'b0;
                        end
                        if (belt_reg[i] != 2'd1) begin
                            all_anticlockwise <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (all_clockwise || all_anticlockwise) begin
                            result <= n;
                            state <= DONE_STATE;
                        end else begin
                            state <= COUNT;
                            i <= 4'd0;
                            counter <= 6'd0;
                        end
                    end
                end

                COUNT: begin
                    if (i < n) begin
                        reg [1:0] left_belt;
                        reg [1:0] right_belt;
                        if (i == 4'd0) begin
                            left_belt = belt_reg[n - 4'd1];
                        end else begin
                            left_belt = belt_reg[i - 4'd1];
                        end
                        right_belt = belt_reg[i];
                        if (left_belt == 2'd2 || right_belt == 2'd2) begin
                            counter <= counter + 6'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        result <= counter;
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