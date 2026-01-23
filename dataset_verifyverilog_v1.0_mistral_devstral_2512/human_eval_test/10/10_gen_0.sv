module make_palindrome(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input finish_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_INPUT = 3'd1;
    localparam [2:0] STATE_PROCESS = 3'd2;
    localparam [2:0] STATE_OUTPUT = 3'd3;
    localparam [2:0] STATE_DONE = 3'd4;

    reg [2:0] state, next_state;

    // Internal buffer and counters
    reg [7:0] buffer [0:7];
    reg [2:0] length;
    reg [2:0] output_index;
    reg [2:0] append_length;
    reg [2:0] append_start;
    reg [2:0] i, j;
    reg is_palindrome;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            length <= 3'd0;
            output_index <= 3'd0;
            append_length <= 3'd0;
            append_start <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            is_palindrome <= 1'b0;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            // Initialize buffer
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                buffer[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_INPUT;
                end
            end

            STATE_INPUT: begin
                if (finish_in || length == 3'd8) begin
                    next_state = STATE_PROCESS;
                end
            end

            STATE_PROCESS: begin
                if (length == 3'd0) begin
                    next_state = STATE_OUTPUT;
                end else if (is_palindrome) begin
                    next_state = STATE_OUTPUT;
                end
            end

            STATE_OUTPUT: begin
                if (output_index == (length + append_length - 1)) begin
                    next_state = STATE_DONE;
                end
            end

            STATE_DONE: begin
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // Input phase logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == STATE_INPUT) begin
            if (valid_in && length < 3'd8) begin
                buffer[length] <= char_in;
                length <= length + 3'd1;
            end
        end
    end

    // Processing phase logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == STATE_PROCESS) begin
            if (length == 3'd0) begin
                append_length <= 3'd0;
                append_start <= 3'd0;
            end else begin
                // Check if current substring is a palindrome
                if (buffer[i] == buffer[length - 1 - (i - j)]) begin
                    if (i == j) begin
                        is_palindrome <= 1'b1;
                        append_length <= length - j;
                        append_start <= 3'd0;
                    end else begin
                        i <= i - 3'd1;
                    end
                end else begin
                    is_palindrome <= 1'b0;
                    j <= j + 3'd1;
                    i <= length - 3'd1;
                end
            end
        end
    end

    // Output phase logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == STATE_OUTPUT) begin
            if (output_index < length) begin
                char_out <= buffer[output_index];
                valid_out <= 1'b1;
                output_index <= output_index + 3'd1;
            end else begin
                char_out <= buffer[append_length - 1 - (output_index - length)];
                valid_out <= 1'b1;
                output_index <= output_index + 3'd1;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == STATE_DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Initialize processing variables
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == STATE_PROCESS && !is_palindrome && j == 3'd0) begin
            i <= length - 3'd1;
            j <= 3'd0;
        end
    end

endmodule