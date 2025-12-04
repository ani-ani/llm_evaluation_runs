module first_digit(
    input clk,
    input rst_n,
    input start,
    input [15:0] num,
    output reg [3:0] result,
    output reg done
);
    
    reg [15:0] temp;
    reg [2:0] state;
    parameter IDLE = 0, DIV1 = 1, DIV2 = 2, DIV3 = 3, DIV4 = 4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            temp <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        if (num < 10) begin
                            result <= num;
                            done <= 1;
                        end else begin
                            temp <= num;
                            done <= 0;
                            state <= DIV1;
                        end
                    end
                end
                DIV1: begin
                    temp <= temp / 10;
                    if (temp < 10) begin
                        result <= temp;
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        state <= DIV2;
                    end
                end
                DIV2: begin
                    temp <= temp / 10;
                    if (temp < 10) begin
                        result <= temp;
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        state <= DIV3;
                    end
                end
                DIV3: begin
                    temp <= temp / 10;
                    if (temp < 10) begin
                        result <= temp;
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        state <= DIV4;
                    end
                end
                DIV4: begin
                    temp <= temp / 10;
                    result <= temp;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule