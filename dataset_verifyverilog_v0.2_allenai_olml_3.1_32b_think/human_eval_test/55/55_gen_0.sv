module fib (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 2'd0,
INIT = 2'd1,
CALCULATE = 2'd2,
COMPLETE = 2'd3;

reg [31:0] fib_prev, fib_curr, counter;
reg [1:0] state;
reg [31:0] next_fib_prev, next_fib_curr, next_counter, next_result;
reg next_state, next_done;

// Combinational block
always @(*) begin
    next_state = state;
    next_fib_prev = fib_prev;
    next_fib_curr = fib_curr;
    next_counter = counter;
    next_result = result;
    next_done = 1'b0;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        INIT: begin
            if (n == 0) begin
                next_result = 32'd0;
                next_done = 1'b1;
                next_state = COMPLETE;
            end else if (n == 1) begin
                next_result = 32'd1;
                next_done = 1'b1;
                next_state = COMPLETE;
            end else begin
                next_fib_prev = 32'd0;
                next_fib_curr = 32'd1;
                next_counter = 32'd1;
                next_state = CALCULATE;
            end
        end
        CALCULATE: begin
            next_fib_prev = fib_curr;
            next_fib_curr = fib_prev + fib_curr;
            next_counter = counter + 1;
            if (counter == n - 1) begin
                next_state = COMPLETE;
                next_done = 1'b1;
                next_result = next_fib_curr;
            end
        end
        COMPLETE: begin
            next_state = IDLE;
            next_done = 1'b0;
        end
    endcase
end

// Sequential block
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        fib_prev <= 32'd0;
        fib_curr <= 32'd0;
        counter <= 32'd0;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        fib_prev <= next_fib_prev;
        fib_curr <= next_fib_curr;
        counter <= next_counter;
        result <= next_result;
        done <= next_done;
    end
end

endmodule