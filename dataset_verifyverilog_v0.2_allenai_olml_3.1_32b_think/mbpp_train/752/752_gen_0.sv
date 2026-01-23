module jacobsthal (
    input clk,
    input rst_n, // active low
    input start,
    input [3:0] n,
    output reg [12:0] result,
    output reg done
);

localparam IDLE = 2'd0,
        CHECK = 2'd1,
        COMPUTE = 2'd2,
        DONE = 2'd3;

reg [1:0] state;
reg [3:0] target_n;
reg [12:0] prev1, prev2;
reg [3:0] i;
reg [12:0] result;
reg done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        target_n <= 4'd0;
        prev1 <= 13'd0;
        prev2 <= 13'd0;
        i <= 4'd0;
        result <= 13'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK;
                    target_n <= n;
                end
            end
            CHECK: begin
                if (target_n == 4'd0) begin
                    state <= DONE;
                    result <= 13'd0;
                    done <= 1'b1;
                end else if (target_n == 4'd1) begin
                    state <= DONE;
                    result <= 13'd1;
                    done <= 1'b1;
                end else begin
                    state <= COMPUTE;
                    prev1 <= 13'd1;
                    prev2 <= 13'd0;
                    i <= 4'd2;
                end
            end
            COMPUTE: begin
                reg [12:0] current;
                current = prev1 + (prev2 << 1); // 2*prev2
                if (i == target_n) begin
                    result <= current;
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    prev2 <= prev1;
                    prev1 <= current;
                    i <= i + 1;
                end
            end
            DONE: begin
                // Stay in DONE
            end
        endcase
    end
end