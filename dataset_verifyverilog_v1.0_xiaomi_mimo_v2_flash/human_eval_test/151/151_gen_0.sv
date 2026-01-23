module double_the_difference(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE        = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [2:0] index;              // 0 to 7 for 8 elements
    reg [23:0] accumulator;
    reg processing_done;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (processing_done)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            index <= 3'd0;
            accumulator <= 24'd0;
            processing_done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset accumulator and index when starting
                        accumulator <= 24'd0;
                        index <= 3'd0;
                        processing_done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    // Check conditions: positive AND odd
                    // Positive: MSB of 8-bit signed is 0
                    // Odd: LSB is 1
                    if (arr[index][0] == 1'b1 && arr[index][7] == 1'b0) begin
                        // Square the value: 8-bit * 8-bit = 16-bit
                        accumulator <= accumulator + ({16'd0, arr[index]} * arr[index]);
                    end
                    
                    // Increment index
                    index <= index + 3'd1;
                    
                    // Check if we've processed all 8 elements (indices 0-7)
                    if (index == 3'd7) begin
                        processing_done <= 1'b1;
                        result <= accumulator + ({16'd0, arr[7]} * arr[7]);
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    processing_done <= 1'b0;
                end
            endcase
        end
    end

endmodule