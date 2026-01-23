module last_digit(
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    output reg [3:0] last_digit,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [31:0] current_num;
    reg [31:0] next_current_num;
    reg [5:0] counter;
    reg [5:0] next_counter;
    reg [3:0] result;
    reg [3:0] next_result;
    reg done_reg;
    reg next_done;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 32'b0;
            counter <= 6'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            current_num <= next_current_num;
            counter <= next_counter;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_current_num = current_num;
        next_counter = counter;
        next_result = result;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_current_num = number;
                    next_counter = 6'd0;
                    next_result = 4'b0;
                end
            end

            PROCESSING: begin
                if (counter < 32) begin
                    // 32 cycles: Shift-and-subtract algorithm
                    // Shift current_num left by 1, accumulate to result
                    // If result >= 10, subtract 10 from result
                    next_current_num = {current_num[30:0], 1'b0}; // Shift left
                    next_result = {result[2:0], current_num[31]}; // Shift in MSB
                    if (next_result >= 10) begin
                        next_result = next_result - 4'd10;
                    end
                    next_counter = counter + 6'd1;
                end else if (counter < 35) begin
                    // Cycles 32, 33, 34: Iterative subtraction to find remainder
                    if (result >= 10) begin
                        next_result = result - 4'd10;
                    end
                    next_counter = counter + 6'd1;
                end else begin
                    // Cycle 35: Done
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Return to IDLE on next cycle
                next_state = IDLE;
                next_done = 1'b0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output assignments
    always @(*) begin
        if (state == DONE) begin
            last_digit = result;
        end else if (state == IDLE) begin
            last_digit = 4'b0;
        end else begin
            last_digit = 4'b0; // Or current intermediate value, keeping 0 for inactive
        end
    end

endmodule
