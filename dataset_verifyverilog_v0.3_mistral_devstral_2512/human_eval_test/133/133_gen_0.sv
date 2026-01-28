module sum_squares(
    input clk,
    input rst_n,
    input start,
    input [7:0] numbers [0:7],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state;
    reg [2:0] counter;  // 3-bit counter for 8 elements
    reg [31:0] accumulator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 3'd0;
            accumulator <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        counter <= 3'd0;
                        accumulator <= 32'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Compute square of current element
                    reg [15:0] square;
                    square <= numbers[counter] * numbers[counter];

                    // Add to accumulator
                    accumulator <= accumulator + square;

                    // Increment counter
                    counter <= counter + 3'd1;

                    // Check if all elements processed
                    if (counter == 3'd8) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= accumulator;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule