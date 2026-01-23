module horse_chase (
    input clk,
    input rst_n,
    input start,
    input [3:0] L,
    input [3:0] A,
    input [3:0] B,
    input [3:0] P,
    output reg [3:0] result,
    output reg done
);

reg [3:0] result;
reg done;
reg [1:0] state;
reg [3:0] initial_time;

localparam IDLE = 2'd0;
localparam CALCULATE = 2'd1;
localparam FINISHED = 2'd2;

always @(posedge clk) begin
    if (!rst_n) begin
        result <= 4'd0;
        done <= 1'b0;
        state <= IDLE;
        initial_time <= 4'd0;
    end else begin
        if (start) begin
            if (state == IDLE) begin
                if (P == A || P == B) begin
                    result <= 4'd0;
                    done <= 1'b1;
                    state <= FINISHED;
                end else begin
                    state <= CALCULATE;
                    initial_time <= 4'd0;
                end
            end
        end
        if (state == CALCULATE) begin
            if (initial_time > 100) begin
                result <= 4'd16;
                done <= 1'b1;
                state <= FINISHED;
            end else begin
                initial_time <= initial_time + 1;
            end
        end
    end
end

endmodule