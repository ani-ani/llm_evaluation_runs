module perrin_sum (output reg [15:0] result, output reg done, input clk, input rst_n, input [4:0] N, input start);
    reg [1:0] state;
    reg [7:0] a, b, c;
    reg [15:0] sum;
    reg [3:0] i;
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam CALCULATE = 2'b10;
    localparam DONE = 2'b11;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            a <= 4'd3;
            b <= 4'd0;
            c <= 4'd2;
            sum <= 16'd3;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                    end else begin
                        state <= IDLE;
                    end
                end
                INIT: begin
                    a <= 4'd3;
                    b <= 4'd0;
                    c <= 4'd2;
                    sum <= 16'd3;
                    i <= 4'd0;
                    state <= CALCULATE;
                end
                CALCULATE: begin
                    if (N == 0) begin
                        state <= DONE;
                    end else begin
                        if (i == 1) begin
                            sum <= sum + b;
                        end else if (i == 2) begin
                            sum <= sum + c;
                        end else if (i >= 3) begin
                            reg [7:0] d;
                            d = a + b;
                            sum <= sum + d;
                            a <= b;
                            b <= c;
                            c <= d;
                        end
                        i <= i + 1;
                        if (i > N) begin
                            state <= DONE;
                        end else begin
                            state <= CALCULATE;
                        end
                    end
                end
                DONE: begin
                    state <= DONE;
                end
                default: state <= IDLE;
            endcase
        end
    end
    assign result = sum;
    assign done = (state == DONE);
endmodule