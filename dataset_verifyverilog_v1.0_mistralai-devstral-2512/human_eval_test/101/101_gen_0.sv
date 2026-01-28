module StringSplitter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_in [0:15],
    input wire [3:0] len,
    output reg [63:0] words_out,
    output reg valid,
    output reg [3:0] word_count
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] char_index;
    reg [2:0] word_index;
    reg [2:0] word_char_index;
    reg [7:0] current_word [0:7];
    reg [7:0] current_char;
    reg in_word;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_index <= 4'd0;
            word_index <= 3'd0;
            word_char_index <= 3'd0;
            in_word <= 1'b0;
            cycle_count <= 8'd0;
            words_out <= 64'd0;
            valid <= 1'b0;
            word_count <= 4'd0;
            
            // Initialize current_word array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                current_word[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        char_index <= 4'd0;
                        word_index <= 3'd0;
                        word_char_index <= 3'd0;
                        in_word <= 1'b0;
                        
                        // Reset current_word array
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            current_word[i] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all characters
                    if (char_index == len) begin
                        // End of string - finalize current word if any
                        if (in_word) begin
                            // Pad current word with spaces
                            integer i;
                            for (i = word_char_index; i < 8; i = i + 1) begin
                                current_word[word_index][i] <= 8'h20;  // Space
                            end
                            
                            // Pack current word into output
                            words_out[(word_index * 8) + 7 : word_index * 8] <= current_word[word_index];
                            word_index <= word_index + 1'b1;
                        end
                        
                        // Update word count
                        word_count <= word_index;
                        next_state <= DONE;
                    end else begin
                        // Get current character
                        current_char <= str_in[char_index];
                        char_index <= char_index + 4'd1;
                        
                        // Check if it's a delimiter
                        if (current_char == 8'h20 || current_char == 8'h2c) begin
                            // Space or comma
                            if (in_word) begin
                                // End of current word
                                // Pad with spaces
                                integer i;
                                for (i = word_char_index; i < 8; i = i + 1) begin
                                    current_word[word_index][i] <= 8'h20;  // Space
                                end
                                
                                // Pack current word into output
                                words_out[(word_index * 8) + 7 : word_index * 8] <= current_word[word_index];
                                word_index <= word_index + 1'b1;
                                in_word <= 1'b0;
                                word_char_index <= 3'd0;
                            end
                            // Else: already between words, ignore consecutive delimiters
                        end else begin
                            // Regular character
                            if (word_index < 8) begin
                                if (!in_word) begin
                                    // Start new word
                                    in_word <= 1'b1;
                                    word_char_index <= 3'd0;
                                end
                                
                                // Add character to current word
                                if (word_char_index < 8) begin
                                    current_word[word_index][word_char_index] <= current_char;
                                    word_char_index <= word_char_index + 3'd1;
                                end
                            end
                        end
                        
                        next_state <= PROCESS;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    valid <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule