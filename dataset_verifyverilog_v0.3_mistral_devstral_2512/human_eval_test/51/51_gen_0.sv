module remove_vowels(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESSING = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;

    reg [2:0] state, next_state;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [7:0] current_char;
    reg is_vowel;

    // Vowel check constants
    localparam [7:0] VOWEL_A = 8'h61;
    localparam [7:0] VOWEL_E = 8'h65;
    localparam [7:0] VOWEL_I = 8'h69;
    localparam [7:0] VOWEL_O = 8'h6F;
    localparam [7:0] VOWEL_U = 8'h75;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_index <= 4'd0;
            output_index <= 4'd0;
            current_char <= 8'd0;
            is_vowel <= 1'b0;
            result_len <= 4'd0;
            done <= 1'b0;
            // Initialize result array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
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
                    next_state = PROCESSING;
                    input_index = 4'd0;
                    output_index = 4'd0;
                    result_len = 4'd0;
                end
            end

            PROCESSING: begin
                if (input_index == 4'd8) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state register
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                PROCESSING: begin
                    // Get current character
                    current_char = str[input_index];

                    // Check if vowel
                    is_vowel = (current_char == VOWEL_A) ||
                               (current_char == VOWEL_E) ||
                               (current_char == VOWEL_I) ||
                               (current_char == VOWEL_O) ||
                               (current_char == VOWEL_U);

                    // If not vowel, write to result
                    if (!is_vowel) begin
                        result[output_index] = current_char;
                        output_index = output_index + 4'd1;
                        result_len = output_index;
                    end

                    // Move to next input character
                    input_index = input_index + 4'd1;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule