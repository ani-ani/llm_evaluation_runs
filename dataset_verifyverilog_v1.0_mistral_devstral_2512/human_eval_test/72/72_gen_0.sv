module will_it_fly(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr [0:3],
    input [15:0] w,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] CHECK_PALINDROME = 3'd1;
    localparam [2:0] CALC_SUM        = 3'd2;
    localparam [2:0] COMPARE         = 3'd3;
    localparam [2:0] DONE_TRUE       = 3'd4;
    localparam [2:0] DONE_FALSE      = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    reg [15:0] sum;
    reg [3:0] index;
    reg palindrome_valid;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sum <= 16'd0;
            index <= 4'd0;
            palindrome_valid <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_PALINDROME;
                    cycle_count = 8'd0;
                    sum = 16'd0;
                    index = 4'd0;
                    palindrome_valid = 1'b1;
                end
            end

            CHECK_PALINDROME: begin
                if (index < len) begin
                    if (arr[index] != arr[len - 1 - index]) begin
                        palindrome_valid = 1'b0;
                    end
                    index = index + 4'd1;
                end else begin
                    next_state = CALC_SUM;
                    index = 4'd0;
                end
            end

            CALC_SUM: begin
                if (index < len) begin
                    sum = sum + arr[index];
                    index = index + 4'd1;
                end else begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                if (palindrome_valid && (sum <= w)) begin
                    next_state = DONE_TRUE;
                end else begin
                    next_state = DONE_FALSE;
                end
            end

            DONE_TRUE: begin
                next_state = IDLE;
            end

            DONE_FALSE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                CHECK_PALINDROME: begin
                    done <= 1'b0;
                end

                CALC_SUM: begin
                    done <= 1'b0;
                end

                COMPARE: begin
                    done <= 1'b0;
                end

                DONE_TRUE: begin
                    result <= 1'b1;
                    done <= 1'b1;
                end

                DONE_FALSE: begin
                    result <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule