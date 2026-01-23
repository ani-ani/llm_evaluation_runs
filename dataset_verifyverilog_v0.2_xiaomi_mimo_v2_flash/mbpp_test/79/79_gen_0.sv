module word_len_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_last,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam DONE = 2'b10;

    // ASCII Constant
    localparam SPACE = 8'h20;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [4:0] current_length;
    reg [4:0] next_current_length;
    reg result_reg;
    reg next_result_reg;
    reg done_reg;
    reg next_done;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_current_length = current_length;
        next_result_reg = result_reg;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READING;
                    next_current_length = 5'b0;
                    next_result_reg = 1'b0;
                end
            end

            READING: begin
                if (char_valid) begin
                    if (char_in == SPACE) begin
                        // Check current word length
                        if (current_length[0]) begin
                            next_result_reg = 1'b1;
                        end
                        // Reset for next word
                        next_current_length = 5'b0;
                    end else begin
                        // Non-space character
                        if (current_length < 16) begin
                            next_current_length = current_length + 1'b1;
                        end
                        // If >= 16, saturate (keep current value)
                        else begin
                            next_current_length = current_length;
                        end
                    end

                    // Check for end of input
                    if (char_last) begin
                        // If current character is space, current_length is already reset to 0
                        // If current character is non-space, current_length includes it
                        // Note: char_last triggers done immediately on this cycle
                        if ((char_in != SPACE) && current_length[0]) begin
                            next_result_reg = 1'b1;
                        end
                        next_state = DONE;
                        next_done = 1'b1;
                    end
                end
            end

            DONE: begin
                // Stay in DONE state, done signal asserted
                next_done = 1'b1;
                // Optional: Reset on start if needed, but user might wait for done to go low
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output Assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            current_length <= 5'b0;
            result_reg <= 1'b0;
        end else begin
            current_length <= next_current_length;
            result_reg <= next_result_reg;
            done <= next_done;
            result <= next_result_reg;
        end
    end

endmodule
