module will_it_fly(
    input clk,
    input rst_n,
    input start,
    input [7:0] q [0:15],
    input [3:0] len,
    input [15:0] w,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_PALINDROME = 3'd1;
    localparam [2:0] CALCULATE_SUM = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [15:0] sum;
    reg is_palindrome;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 16'd0;
            is_palindrome <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK_PALINDROME;
                    index = 4'd0;
                    sum = 16'd0;
                    is_palindrome = 1'b1;
                    cycle_count = 8'd0;
                end
            end

            CHECK_PALINDROME: begin
                if (index < (len + 4'd1) / 2) begin
                    if (q[index] != q[len - 1 - index]) begin
                        is_palindrome = 1'b0;
                    end
                    index = index + 4'd1;
                end else begin
                    next_state = CALCULATE_SUM;
                    index = 4'd0;
                end
            end

            CALCULATE_SUM: begin
                if (index < len) begin
                    sum = sum + q[index];
                    index = index + 4'd1;
                end else begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                result = is_palindrome && (sum <= w);
                next_state = FINISH;
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule