module remove_length(
    input clk,
    input rst_n,
    input start,
    input [3:0] k_len,
    input [127:0] input_str,
    output reg done,
    output reg [127:0] output_str,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PARSING = 3'b001;
    localparam CHECKING = 3'b010;
    localparam COPYING = 3'b011;
    localparam PADDING = 3'b100;
    localparam FINISH = 3'b101;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] char_idx, next_char_idx;       // Current char index (0-15)
    reg [3:0] word_len, next_word_len;       // Length of current word being built
    reg [3:0] out_idx, next_out_idx;         // Index for output buffer
    reg [7:0] word_buffer [0:7];             // Current word buffer
    reg [7:0] next_word_buffer [0:7];        // Next value for word buffer
    reg [127:0] temp_output, next_temp_output; // Output accumulator
    reg [127:0] saved_input;                 // Stored input string

    // Helper signals
    wire [7:0] current_char;
    assign current_char = saved_input[ (15-char_idx)*8 +: 8 ];

    integer i;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 4'd0;
            word_len <= 4'd0;
            out_idx <= 4'd0;
            temp_output <= 128'b0;
            saved_input <= 128'b0;
            for (i = 0; i < 8; i = i + 1) begin
                word_buffer[i] <= 8'h00;
            end
        end else begin
            state <= next_state;
            char_idx <= next_char_idx;
            word_len <= next_word_len;
            out_idx <= next_out_idx;
            temp_output <= next_temp_output;
            saved_input <= (state == IDLE && start) ? input_str : saved_input;
            for (i = 0; i < 8; i = i + 1) begin
                word_buffer[i] <= next_word_buffer[i];
            end
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_char_idx = char_idx;
        next_word_len = word_len;
        next_out_idx = out_idx;
        next_temp_output = temp_output;
        
        for (i = 0; i < 8; i = i + 1) begin
            next_word_buffer[i] = word_buffer[i];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSING;
                    next_char_idx = 4'd0;
                    next_word_len = 4'd0;
                    next_out_idx = 4'd0;
                    next_temp_output = 128'b0;
                    for (i = 0; i < 8; i = i + 1) begin
                        next_word_buffer[i] = 8'h20; // Space
                    end
                end
            end

            PARSING: begin
                if (char_idx < 4'd16) begin
                    if (current_char == 8'h20) begin // Space found
                        if (word_len > 0) begin
                            next_state = CHECKING;
                            // Do not increment char_idx yet, will return to PARSING after check
                        end else begin
                            // No word accumulated, just skip space (should not happen per spec, but safe)
                            next_char_idx = char_idx + 1;
                        end
                    end else begin // Character is part of a word
                        if (word_len < 4'd8) begin
                            next_word_buffer[word_len] = current_char;
                            next_word_len = word_len + 1;
                        end
                        next_char_idx = char_idx + 1;
                        // If we just finished the 16th char (last char), we need to process the pending word
                        if (char_idx == 4'd15) begin
                            if (word_len > 0) next_state = CHECKING;\ // Trigger check for last word
                            else next_state = FINISH;
                        end
                    end
                end else begin
                    // End of string
                    if (word_len > 0) begin
                        next_state = CHECKING;
                    end else begin
                        next_state = PADDING;
                    end
                end
            end

            CHECKING: begin
                if (word_len == k_len) begin
                    // Word matches K, skip it
                    next_word_len = 0;
                    // Clear buffer (optional, but good practice)
                    for (i = 0; i < 8; i = i + 1) next_word_buffer[i] = 8'h20;
                    
                    if (char_idx < 4'd16) begin
                         // Move past the space that triggered this check (which is at current char_idx)
                         // Actually, the space was at char_idx. We need to increment.
                         // But wait, the logic in PARSING didn't increment char_idx if it found a space and word_len > 0.
                         // So char_idx is currently pointing to the SPACE.
                         next_char_idx = char_idx + 1;
                         next_state = PARSING;
                    end else begin
                         next_state = PADDING;
                    end
                end else begin
                    // Word is kept
                    next_state = COPYING;
                    // Reset copy index for the word
                    next_out_idx = 0; // Re-use out_idx for copying within the word
                end
            end

            COPYING: begin
                if (out_idx < word_len) begin
                    // Copy one char
                    next_temp_output[ (15 - out_idx)*8 +: 8 ] = word_buffer[out_idx];
                    next_out_idx = out_idx + 1;
                end else begin
                    // Word copied completely
                    // Append a space
                    next_temp_output[ (15 - out_idx)*8 +: 8 ] = 8'h20;
                    next_out_idx = out_idx + 1; // This now points to position after space
                    
                    // Prepare for next word
                    next_word_len = 0;
                    for (i = 0; i < 8; i = i + 1) next_word_buffer[i] = 8'h20;
                    
                    if (char_idx < 4'd16) begin
                         // char_idx was pointing to the space. Increment it.
                         next_char_idx = char_idx + 1;
                         next_state = PARSING;
                    end else begin
                         next_state = PADDING;
                    end
                end
            end

            PADDING: begin
                // Fill remaining output positions with spaces
                if (next_out_idx < 4'd16) begin
                    next_temp_output[ (15 - next_out_idx)*8 +: 8 ] = 8'h20;
                    next_out_idx = next_out_idx + 1;
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                if (!start) begin // Wait for start to go low to return to IDLE (optional, but often requested)
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            valid <= 1'b0;
            output_str <= 128'b0;
        end else begin
            if (state == FINISH && next_state == IDLE) begin
                // Reset outputs when going to IDLE
                done <= 1'b0;
                valid <= 1'b0;
                output_str <= 128'b0;
            end else if (state == FINISH) begin
                done <= 1'b1;
                valid <= 1'b1;
                output_str <= temp_output;
            end else begin
                done <= 1'b0;
                valid <= 1'b0;
            end
        end
    end

endmodule