module LongestInterestingSubsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] A [0:15],
    input wire [3:0] N,
    input wire [15:0] S,
    output reg [3:0] result_index,
    output reg [7:0] result_length,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET_ACC = 3'd1;
    localparam [2:0] CALC_SUM = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] CHECK_DONE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] current_K;
    reg [7:0] max_length;
    reg [15:0] sum_first;
    reg [15:0] sum_second;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            current_K <= 4'd0;
            max_length <= 8'd0;
            sum_first <= 16'd0;
            sum_second <= 16'd0;
            result_index <= 4'd0;
            result_length <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                done <= 1'b0;
                if (start) begin
                    next_state = RESET_ACC;
                    current_index <= 4'd0;
                    max_length <= 8'd0;
                    cycle_count <= 4'd0;
                end
            end

            RESET_ACC: begin
                sum_first <= 16'd0;
                sum_second <= 16'd0;
                current_K <= 4'd1;
                next_state = CALC_SUM;
            end

            CALC_SUM: begin
                // Calculate sum of first K elements
                if (current_K[0]) begin
                    sum_first <= sum_first + A[current_index + current_K - 1'b1];
                end
                // Calculate sum of second K elements
                if (current_K[0]) begin
                    sum_second <= sum_second + A[current_index + current_K];
                end
                // Check if we've accumulated K elements
                if (current_K == (N - current_index) / 2'b1) begin
                    next_state = COMPARE;
                end else begin
                    current_K <= current_K + 4'd1;
                end
            end

            COMPARE: begin
                if (sum_first <= S && sum_second <= S) begin
                    if (current_K * 2'b1 > max_length) begin
                        max_length <= current_K * 2'b1;
                    end
                end
                // Move to next K
                current_K <= current_K + 4'd1;
                if (current_K * 2'b1 > N - current_index) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = RESET_ACC;
                end
            end

            OUTPUT: begin
                result_index <= current_index;
                result_length <= max_length;
                result_valid <= 1'b1;
                // Move to next index
                current_index <= current_index + 4'd1;
                next_state = CHECK_DONE;
            end

            CHECK_DONE: begin
                result_valid <= 1'b0;
                if (current_index >= N) begin
                    done <= 1'b1;
                    next_state = IDLE;
                end else begin
                    next_state = RESET_ACC;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule