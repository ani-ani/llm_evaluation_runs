module harmonic_sum (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 2'd0,
        CALCULATE = 2'd1,
        DONE = 2'd2;

reg [1:0] state;
reg [31:0] accumulator;
reg [3:0] counter;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        accumulator <= 32'd0;
        counter <= 4'd0;
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    accumulator <= 32'd65536;
                    counter <= 4'd1;
                    state <= CALCULATE;
                end else begin
                    accumulator <= accumulator;
                    counter <= counter;
                    state <= IDLE;
                    result <= result;
                    done <= 1'b0;
                end
            end
            CALCULATE: begin
                if (counter < (n-1)) begin
                    integer divisor;
                    divisor = counter + 1;
                    integer term;
                    term = 65536 / divisor;
                    accumulator <= accumulator + term;
                    counter <= counter + 1;
                    state <= CALCULATE;
                end else begin
                    state <= DONE;
                    result <= accumulator;
                    done <= 1'b1;
                end
            end
            DONE: begin
                result <= result;
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end else begin
                    state <= DONE;
                end
            end
        endcase
    end
end
endmodule