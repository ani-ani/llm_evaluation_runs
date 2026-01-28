module word_filter(
    input clk,
    input rst_n,
    input start,
    input [3:0] K,
    input [7:0] char_in,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READING   = 3'd1;
    localparam [2:0] PARSING   = 3'd2;
    localparam [2:0] OUTPUTTING = 3'd3;
    localparam [2:0] WAITING   = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] read_counter;      // Counts 64 input characters
    reg [3:0] word_length;       // Current word length
    reg [7:0] char_buffer [0:15]; // Current word buffer
    reg [7:0] output_buffer [0:63]; // Output buffer
    reg [5:0] output_ptr;        // Output buffer pointer
    reg [5:0] output_counter;    // Counts output characters
    reg [5:0] word_start;        // Start index of current word in output buffer
    reg space_pending;          // Flag for pending space
    reg last_word;              // Flag for last word

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_counter <= 6'd0;
            word_length <= 4'd0;
            output_ptr <= 6'd0;
            output_counter <= 6'd0;
            word_start <= 6'd0;
            space_pending <= 1'b0;
            last_word <= 1'b0;
            done <= 1'b0;
            out_valid <= 1'b0;
            char_out <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READING;
                    read_counter = 6'd0;
                    word_length = 4'd0;
                    output_ptr = 6'd0;
                    output_counter = 6'd0;
                    word_start = 6'd0;
                    space_pending = 1'b0;
                    last_word = 1'b0;
                    done = 1'b0;
                    out_valid = 1'b0;
                end else begin
                    next_state = IDLE;
                end
            end

            READING: begin
                if (read_counter == 6'd63) begin
                    next_state = PARSING;
                end else begin
                    next_state = READING;
                end
            end

            PARSING: begin
                if (output_counter == output_ptr) begin
                    next_state = OUTPUTTING;
                end else begin
                    next_state = PARSING;
                end
            end

            OUTPUTTING: begin
                if (output_counter == output_ptr) begin
                    next_state = WAITING;
                end else begin
                    next_state = OUTPUTTING;
                end
            end

            WAITING: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Reading state: store input characters
    always @(posedge clk) begin
        if (state == READING) begin
            if (read_counter < 6'd64) begin
                // Store character in output buffer
                output_buffer[read_counter] = char_in;
                read_counter = read_counter + 6'd1;
            end
        end
    end

    // Parsing state: process words
    always @(posedge clk) begin
        if (state == PARSING) begin
            if (output_counter < output_ptr) begin
                // Process words and build output
                reg [7:0] current_char = output_buffer[output_counter];
                reg is_space = (current_char == 8'h20);

                if (is_space) begin
                    // End of word
                    if (word_length == K) begin
                        // Skip this word and space
                        word_length = 4'd0;
                        space_pending = 1'b0;
                    end else begin
                        // Keep this word
                        if (word_length > 4'd0) begin
                            // Copy word to output buffer
                            integer i;
                            for (i = 0; i < word_length; i = i + 1) begin
                                output_buffer[output_ptr] = char_buffer[i];
                                output_ptr = output_ptr + 6'd1;
                            end
                            space_pending = 1'b1;
                        end
                        word_length = 4'd0;
                    end
                end else begin
                    // Middle of word
                    if (word_length < 16) begin
                        char_buffer[word_length] = current_char;
                        word_length = word_length + 4'd1;
                    end
                end

                output_counter = output_counter + 6'd1;

                // Check if this is the last character
                if (output_counter == 6'd63) begin
                    last_word = 1'b1;
                    if (word_length != K && word_length > 4'd0) begin
                        // Output last word
                        integer i;
                        for (i = 0; i < word_length; i = i + 1) begin
                            output_buffer[output_ptr] = char_buffer[i];
                            output_ptr = output_ptr + 6'd1;
                        end
                    end
                end
            end
        end
    end

    // Outputting state: send characters
    always @(posedge clk) begin
        if (state == OUTPUTTING) begin
            if (output_counter < output_ptr) begin
                char_out = output_buffer[output_counter];
                out_valid = 1'b1;
                output_counter = output_counter + 6'd1;
            end else begin
                out_valid = 1'b0;
            end
        end else begin
            out_valid = 1'b0;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == WAITING) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule