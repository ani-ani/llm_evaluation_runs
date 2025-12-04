module is_prime (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg ready,
    output reg is_prime
);

reg [1:0] state;
reg [15:0] divisor;
parameter IDLE = 2'b00, CHECK = 2'b01;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ready <= 1'b0;
        is_prime <= 1'b0;
        divisor <= 16'd0;
    end
    else begin
        case (state)
            IDLE: begin
                ready <= 1'b0;
                divisor <= 16'd0;
                if (start) begin
                    state <= CHECK;
                end
            end
            CHECK: begin
                if (divisor == 16'd0) begin
                    if (n < 16'd2) begin
                        is_prime <= 1'b0;
                        ready <= 1'b1;
                        state <= IDLE;
                    end
                    else if (n == 16'd2) begin
                        is_prime <= 1'b1;
                        ready <= 1'b1;
                        state <= IDLE;
                    end
                    else begin
                        if ((16'd2 * 16'd2) > n) begin
                            is_prime <= 1'b1;
                            ready <= 1'b1;
                            state <= IDLE;
                        end
                        else if (n % 2 == 0) begin
                            is_prime <= 1'b0;
                            ready <= 1'b1;
                            state <= IDLE;
                        end
                        else begin
                            divisor <= 16'd3;
                        end
                    end
                end
                else begin
                    if ((divisor * divisor) > n) begin
                        is_prime <= 1'b1;
                        ready <= 1'b1;
                        state <= IDLE;
                    end
                    else if (n % divisor == 0) begin
                        is_prime <= 1'b0;
                        ready <= 1'b1;
                        state <= IDLE;
                    end
                    else begin
                        divisor <= divisor + 1;
                    end
                end
            end
        endcase
    end
end

endmodule