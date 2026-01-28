module smallest_change(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPARE_0 = 3'd1;
    localparam [2:0] COMPARE_1 = 3'd2;
    localparam [2:0] COMPARE_2 = 3'd3;
    localparam [2:0] COMPARE_3 = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] mismatch_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            mismatch_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        done = 1'b0;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE_0;
                end
            end

            COMPARE_0: begin
                if (arr_0 != arr_7) begin
                    mismatch_count = mismatch_count + 4'd1;
                end
                next_state = COMPARE_1;
            end

            COMPARE_1: begin
                if (arr_1 != arr_6) begin
                    mismatch_count = mismatch_count + 4'd1;
                end
                next_state = COMPARE_2;
            end

            COMPARE_2: begin
                if (arr_2 != arr_5) begin
                    mismatch_count = mismatch_count + 4'd1;
                end
                next_state = COMPARE_3;
            end

            COMPARE_3: begin
                if (arr_3 != arr_4) begin
                    mismatch_count = mismatch_count + 4'd1;
                end
                next_state = DONE;
            end

            DONE: begin
                result = mismatch_count;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule