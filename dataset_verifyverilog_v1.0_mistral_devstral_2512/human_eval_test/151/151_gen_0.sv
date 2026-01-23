module double_the_difference(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [23:0] accumulator;
    reg [15:0] square;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            accumulator <= 24'd0;
            result <= 24'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end

            PROCESSING: begin
                if (index == 3'd7)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 3'd0;
            accumulator <= 24'd0;
            result <= 24'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    index <= 3'd0;
                    accumulator <= 24'd0;
                    result <= 24'd0;
                    done <= 1'b0;
                end

                PROCESSING: begin
                    // Check if element is positive and odd
                    if (arr[index][7] == 1'b0 && arr[index][0] == 1'b1) begin
                        // Square the element (8-bit signed * 8-bit signed = 16-bit)
                        square = $signed(arr[index]) * $signed(arr[index]);
                        accumulator = accumulator + square;
                    end
                    index <= index + 3'd1;
                end

                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    index <= 3'd0;
                    accumulator <= 24'd0;
                end

                default: begin
                    index <= 3'd0;
                    accumulator <= 24'd0;
                    result <= 24'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule