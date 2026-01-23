module cyclic_decode (
    input clk,
    input rst_n,
    input start,
    input [2:0] str_length,
    input [7:0] char_in,
    input char_valid,
    output reg [7:0] decoded_char,
    output reg char_out_valid,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        COLLECTING,
        DECODING,
        OUTPUTTING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] char_buffer [0:2]; // Buffer for up to 3 characters
    reg [1:0] group_pos;         // Position within current group (0, 1, 2)
    reg [2:0] remaining_chars;  // Total characters remaining to process
    reg [1:0] output_pos;        // Position within output group
    reg [7:0] output_buffer [0:2]; // Buffer for decoded group

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            group_pos <= 0;
            remaining_chars <= 0;
            output_pos <= 0;
            decoded_char <= 0;
            char_out_valid <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = current_state;
        char_out_valid = 0;
        done = 0;
        decoded_char = 0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COLLECTING;
                    group_pos = 0;
                    remaining_chars = str_length;
                    output_pos = 0;
                end
            end

            COLLECTING: begin
                if (char_valid) begin
                    char_buffer[group_pos] = char_in;
                    group_pos = group_pos + 1;
                    remaining_chars = remaining_chars - 1;

                    if (group_pos == 2 || remaining_chars == 0) begin
                        next_state = DECODING;
                    end
                end
            end

            DECODING: begin
                // Decode the current group
                if (group_pos == 2) begin
                    // Full group of 3: b c a -> a b c
                    output_buffer[0] = char_buffer[2];
                    output_buffer[1] = char_buffer[0];
                    output_buffer[2] = char_buffer[1];
                end else if (group_pos == 1) begin
                    // Group of 2: x y -> x y
                    output_buffer[0] = char_buffer[0];
                    output_buffer[1] = char_buffer[1];
                end else begin
                    // Group of 1: x -> x
                    output_buffer[0] = char_buffer[0];
                end

                output_pos = 0;
                next_state = OUTPUTTING;
            end

            OUTPUTTING: begin
                decoded_char = output_buffer[output_pos];
                char_out_valid = 1;
                output_pos = output_pos + 1;

                if (output_pos == group_pos) begin
                    group_pos = 0;
                    if (remaining_chars == 0) begin
                        next_state = DONE;
                    end else begin
                        next_state = COLLECTING;
                    end
                end
            end

            DONE: begin
                done = 1;
                if (start) begin
                    next_state = COLLECTING;
                    group_pos = 0;
                    remaining_chars = str_length;
                    output_pos = 0;
                    done = 0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule