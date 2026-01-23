module sum_odd_even_pos(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    reg [1:0] state;
    reg [2:0] index;
    reg [15:0] accumulator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 3'd0;
                        accumulator <= 16'd0;
                    end
                end

                PROCESSING: begin
                    // Check if current index is even
                    if (index[0] == 1'b0) begin
                        // Check if current element is odd
                        if (arr[index][0] == 1'b1) begin
                            accumulator <= accumulator + arr[index];
                        end
                    end

                    // Increment index
                    index <= index + 3'd1;

                    // Check if we've processed all elements
                    if (index == 3'd8) begin
                        state <= DONE;
                        result <= accumulator;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule