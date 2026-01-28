module cube_array(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg [15:0] result_4,
    output reg [15:0] result_5,
    output reg [15:0] result_6,
    output reg [15:0] result_7,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [2:0] counter;
    reg [2:0] stage;
    reg [7:0] current_val;
    reg [15:0] square;
    reg [15:0] cube;

    reg [7:0] arr_reg [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 3'd0;
            stage <= 3'd0;
            result_0 <= 16'd0;
            result_1 <= 16'd0;
            result_2 <= 16'd0;
            result_3 <= 16'd0;
            result_4 <= 16'd0;
            result_5 <= 16'd0;
            result_6 <= 16'd0;
            result_7 <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 3'd0;
                    stage <= 3'd0;
                    if (start) begin
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (counter < len) begin
                        case (stage)
                            3'd0: begin
                                current_val <= arr_reg[counter];
                                square <= arr_reg[counter] * arr_reg[counter];
                                stage <= 3'd1;
                            end
                            3'd1: begin
                                cube <= square * current_val;
                                stage <= 3'd2;
                            end
                            3'd2: begin
                                case (counter)
                                    3'd0: result_0 <= cube;
                                    3'd1: result_1 <= cube;
                                    3'd2: result_2 <= cube;
                                    3'd3: result_3 <= cube;
                                    3'd4: result_4 <= cube;
                                    3'd5: result_5 <= cube;
                                    3'd6: result_6 <= cube;
                                    3'd7: result_7 <= cube;
                                endcase
                                counter <= counter + 3'd1;
                                stage <= 3'd0;
                            end
                        endcase
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule