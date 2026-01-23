module chubby_yang (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;

    // Constant for sqrt(2) in Q16.16 format (92682)
    // result = 4 * floor(n * sqrt(2)) = (n * 92682) >> 14

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n == 0) begin
                            result <= 1;
                            done <= 1;
                        end else begin
                            state <= CALC;
                        end
                    end
                end
                CALC: begin
                    result <= (n * 92682) >> 14;
                    state <= DONE;
                    done <= 1;
                end
                DONE: begin
                    done <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule