module ArraySum(
    input clk,
    input rst_n,
    input start,
    input [3:0] m,
    input [3:0] n,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state;
    reg [3:0] counter;
    reg [15:0] accumulator;
    reg [7:0] current_element;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        counter <= m;
                        accumulator <= 16'd0;
                    end
                end

                COMPUTE: begin
                    case (counter)
                        4'd0: current_element = arr_0;
                        4'd1: current_element = arr_1;
                        4'd2: current_element = arr_2;
                        4'd3: current_element = arr_3;
                        4'd4: current_element = arr_4;
                        4'd5: current_element = arr_5;
                        4'd6: current_element = arr_6;
                        4'd7: current_element = arr_7;
                        default: current_element = 8'd0;
                    endcase

                    accumulator <= accumulator + current_element;

                    if (counter == n) begin
                        state <= FINISH;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule