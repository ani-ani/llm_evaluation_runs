module substitution_cipher_decrypt(
    input clk,
    input rst_n,
    input start,
    input [7:0] encrypted_text [0:31],
    input [5:0] length,
    output reg [7:0] result [0:31],
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] DECRYPT = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Vocabulary ROM (12 words × 8 bytes)
    localparam [7:0] VOCAB [0:11][0:7] = '
        '{ // "be      "
            8'd98, 8'd101, 8'd32, 8'd32, 8'd32, 8'd32, 8'd32, 8'd32,
            // "our     "
            8'd111, 8'd117, 8'd114, 8'd32, 8'd32, 8'd32, 8'd32, 8'd32,
            // "rum     "
            8'd114, 8'd117, 8'd109, 8'd32, 8'd32, 8'd32, 8'd32, 8'd32,
            // "will    "
            8'd119, 8'd105, 8'd108, 8'd108, 8'd32, 8'd32, 8'd32, 8'd32,
            // "dead    "
            8'd100, 8'd101, 8'd97, 8'd100, 8'd32, 8'd32, 8'd32, 8'd32,
            // "hook    "
            8'd104, 8'd111, 8'd111, 8'd107, 8'd32, 8'd32, 8'd32, 8'd32,
            // "ship    "
            8'd115, 8'd104, 8'd105, 8'd112, 8'd32, 8'd32, 8'd32, 8'd32,
            // "blood   "
            8'd98, 8'd108, 8'd111, 8'd111, 8'd100, 8'd32, 8'd32, 8'd32,
            // "sable   "
            8'd115, 8'd97, 8'd98, 8'd108, 8'd101, 8'd32, 8'd32, 8'd32,
            // "avenge  "
            8'd97, 8'd118, 8'd101, 8'd110, 8'd103, 8'd101, 8'd32, 8'd32,
            // "parrot  "
            8'd112, 8'd97, 8'd114, 8'd114, 8'd111, 8'd116, 8'd32, 8'd32,
            // "captain "
            8'd99, 8'd97, 8'd112, 8'd116, 8'd97, 8'd105, 8'd110, 8'd32
        };

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [7:0] word_count;
    reg [7:0] search_iter;
    reg [3:0] unique_letters [0:15];
    reg [7:0] mapping [0:15];
    reg [7:0] word_start [0:15];
    reg [7:0] word_end [0:15];
    reg [7:0] current_word [0:7];
    reg [7:0] temp_char;
    reg [7:0] i, j, k, l;
    reg found_mapping;
    reg valid_mapping;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            word_count <= 8'd0;
            search_iter <= 8'd0;
            done <= 1'b0;
            possible <= 1'b0;
            found_mapping <= 1'b0;
            valid_mapping <= 1'b0;
            
            for (i = 0; i < 16; i = i + 1) begin
                unique_letters[i] <= 4'd0;
                mapping[i] <= 8'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                word_start[i] <= 8'd0;
                word_end[i] <= 8'd0;
            end
            
            for (i = 0; i < 32; i = i + 1) begin
                result[i] <= 8'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                current_word[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PARSE: begin
                    // Parse input into words
                    word_count <= 8'd0;
                    j <= 8'd0;
                    k <= 8'd0;
                    
                    for (i = 0; i < length; i = i + 1) begin
                        temp_char <= encrypted_text[i];
                        
                        if (temp_char == 8'd32) begin
                            if (j > 8'd0) begin
                                word_end[word_count] <= i - 8'd1;
                                word_count <= word_count + 8'd1;
                                j <= 8'd0;
                            end
                        end else begin
                            if (j == 8'd0) begin
                                word_start[word_count] <= i;
                            end
                            j <= j + 8'd1;
                        end
                    end
                    
                    if (j > 8'd0) begin
                        word_end[word_count] <= length - 8'd1;
                        word_count <= word_count + 8'd1;
                    end
                    
                    next_state <= SEARCH;
                end
                
                SEARCH: begin
                    // Bounded search for mapping
                    if (cycle_count >= 8'd255) begin
                        next_state <= DECRYPT;
                    end else begin
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Try to find a valid mapping
                        found_mapping <= 1'b0;
                        valid_mapping <= 1'b0;
                        
                        // Reset mapping
                        for (i = 0; i < 16; i = i + 1) begin
                            mapping[i] <= 8'd0;
                        end
                        
                        // Attempt mapping
                        for (i = 0; i < word_count; i = i + 1) begin
                            // Extract current word
                            for (j = 0; j < 8; j = j + 1) begin
                                if (word_start[i] + j <= word_end[i]) begin
                                    current_word[j] <= encrypted_text[word_start[i] + j];
                                end else begin
                                    current_word[j] <= 8'd32;
                                end
                            end
                            
                            // Try to match with vocabulary
                            for (k = 0; k < 12; k = k + 1) begin
                                valid_mapping <= 1'b1;
                                
                                // Check if this word matches
                                for (l = 0; l < 8; l = l + 1) begin
                                    if (current_word[l] != 8'd32 && VOCAB[k][l] != 8'd32) begin
                                        // Find mapping index for encrypted char
                                        for (j = 0; j < 16; j = j + 1) begin
                                            if (unique_letters[j] == current_word[l]) begin
                                                if (mapping[j] != 8'd0 && mapping[j] != VOCAB[k][l]) begin
                                                    valid_mapping <= 1'b0;
                                                end
                                                mapping[j] <= VOCAB[k][l];
                                            end
                                        end
                                    end
                                end
                                
                                if (valid_mapping) begin
                                    found_mapping <= 1'b1;
                                end
                            end
                        end
                        
                        if (found_mapping) begin
                            next_state <= DECRYPT;
                        end else begin
                            next_state <= SEARCH;
                        end
                    end
                end
                
                DECRYPT: begin
                    // Apply mapping to generate result
                    possible <= found_mapping;
                    
                    for (i = 0; i < length; i = i + 1) begin
                        temp_char <= encrypted_text[i];
                        
                        if (temp_char == 8'd32) begin
                            result[i] <= 8'd32;
                        end else begin
                            // Find mapping
                            for (j = 0; j < 16; j = j + 1) begin
                                if (unique_letters[j] == temp_char) begin
                                    result[i] <= mapping[j];
                                end
                            end
                        end
                    end
                    
                    next_state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule