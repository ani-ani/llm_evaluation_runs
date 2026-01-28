module case_flipper (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input [2:0] char_index,
    output reg [7:0] char_out,
    output reg [2:0] char_out_index,
    output reg char_out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INPUT_WAIT = 3'd1;
    localparam [2:0] INPUT      = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] buffer [0:7];  // 8x8 buffer
    reg [2:0] input_count;
    reg [2:0] output_count;
    reg [7:0] flipped_char;
    reg input_done;
    reg output_done;

    integer i;

    // Combinational logic for case flipping
    always @(*) begin
        if (char_in >= 8'd65 && char_in <= 8'd90) begin
            // Uppercase to lowercase: add 32
            flipped_char = char_in + 8'd32;
        end else if (char_in >= 8'd97 && char_in <= 8'd122) begin
            // Lowercase to uppercase: subtract 32
            flipped_char = char_in - 8'd32;
        end else begin
            // Pass through unchanged
            flipped_char = char_in;
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INPUT_WAIT;
                else
                    next_state = IDLE;
            end
            INPUT_WAIT: begin
                if (char_valid)
                    next_state = INPUT;
                else
                    next_state = INPUT_WAIT;
            end
            INPUT: begin
                if (!char_valid || input_done)
                    next_state = OUTPUT;
                else
                    next_state = INPUT_WAIT;
            end
            OUTPUT: begin
                if (output_done)
                    next_state = FINISH;
                else
                    next_state = OUTPUT;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            char_out_index <= 3'd0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
            input_count <= 3'd0;
            output_count <= 3'd0;
            input_done <= 1'b0;
            output_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    char_out_valid <= 1'b0;
                    input_count <= 3'd0;
                    output_count <= 3'd0;
                    input_done <= 1'b0;
                    output_done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            buffer[i] <= 8'd0;
                        end
                    end
                end

                INPUT_WAIT: begin
                    if (char_valid) begin
                        state <= INPUT;
                    end
                end

                INPUT: begin
                    if (char_valid) begin
                        buffer[char_index] <= flipped_char;
                        input_count <= input_count + 3'd1;
                        if (input_count == 3'd7) begin
                            input_done <= 1'b1;
                        end
                    end
                    if (!char_valid || input_done) begin
                        state <= OUTPUT;
                    end else begin
                        state <= INPUT_WAIT;
                    end
                end

                OUTPUT: begin
                    if (!output_done) begin
                        char_out <= buffer[output_count];
                        char_out_index <= output_count;
                        char_out_valid <= 1'b1;
                        output_count <= output_count + 3'd1;
                        if (output_count == 3'd7) begin
                            output_done <= 1'b1;
                        end
                    end else begin
                        char_out_valid <= 1'b0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    char_out_valid <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule