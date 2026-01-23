module sort_numbers(
    input clk,
    input rst_n,
    input start,
    input [319:0] input_str,
    output reg [319:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 0;
    localparam PARSE = 1;
    localparam MAP_VALUES = 2;
    localparam SORT = 3;
    localparam CONVERT = 4;
    localparam BUILD_OUTPUT = 5;
    localparam DONE = 6;

    reg [2:0] state;
    reg [7:0] count;
    reg [7:0] i; // general loop counter
    reg [7:0] j; // inner loop counter for sort
    reg [7:0] k; // index for parsing
    reg [7:0] word_len;
    
    // Storage for extracted words (3 to 5 chars)
    reg [31:0] word_buffer; // 4 chars max needed (e.g. five, four)
    reg [3:0] values [0:7]; // Array of up to 8 values
    reg [3:0] num_values; // Number of valid values
    
    // Temporary registers for state transitions
    reg start_delayed;
    reg [3:0] temp_val;
    
    // Helper signals
    reg [7:0] char0, char1, char2, char3, char4;
    
    // Output string construction buffer
    reg [31:0] out_words [0:7]; // ASCII representation of numbers + space
    reg [3:0] out_idx;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            num_values <= 0;
            count <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            start_delayed <= 0;
        end else begin
            start_delayed <= start;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && !start_delayed) begin
                        state <= PARSE;
                        k <= 0; // pointer to char in input_str
                        num_values <= 0;
                    end
                end
                
                PARSE: begin
                    // Extract words (3-5 chars)
                    if (k < 40) begin // Input is 40 chars
                        // Look for non-space
                        if (input_str[k*8 +: 8] != 8'h20) begin
                            // Start of a word
                            if (num_values < 8) begin
                                // Detect word length and extract
                                word_len <= 0;
                                
                                // Manual extraction for fixed lengths
                                // Assume words are followed by space or end
                                
                                // Check 'zero'
                                if (input_str[k*8 +: 8] == "z" && input_str[(k+1)*8 +: 8] == "e" && input_str[(k+2)*8 +: 8] == "r" && input_str[(k+3)*8 +: 8] == "o" && (input_str[(k+4)*8 +: 8] == 8'h20 || k+4 >= 40)) begin
                                    values[num_values] <= 4'd0;
                                    k <= k + 5;
                                    num_values <= num_values + 1;
                                end
                                // Check 'one'
                                else if (input_str[k*8 +: 8] == "o" && input_str[(k+1)*8 +: 8] == "n" && input_str[(k+2)*8 +: 8] == "e" && (input_str[(k+3)*8 +: 8] == 8'h20 || k+3 >= 40)) begin
                                    values[num_values] <= 4'd1;
                                    k <= k + 4;
                                    num_values <= num_values + 1;
                                end
                                // Check 'two'
                                else if (input_str[k*8 +: 8] == "t" && input_str[(k+1)*8 +: 8] == "w" && input_str[(k+2)*8 +: 8] == "o" && (input_str[(k+3)*8 +: 8] == 8'h20 || k+3 >= 40)) begin
                                    values[num_values] <= 4'd2;
                                    k <= k + 4;
                                    num_values <= num_values + 1;
                                end
                                // Check 'three'
                                else if (input_str[k*8 +: 8] == "t" && input_str[(k+1)*8 +: 8] == "h" && input_str[(k+2)*8 +: 8] == "r" && input_str[(k+3)*8 +: 8] == "e" && input_str[(k+4)*8 +: 8] == "e" && (input_str[(k+5)*8 +: 8] == 8'h20 || k+5 >= 40)) begin
                                    values[num_values] <= 4'd3;
                                    k <= k + 6;
                                    num_values <= num_values + 1;
                                end
                                // Check 'four'
                                else if (input_str[k*8 +: 8] == "f" && input_str[(k+1)*8 +: 8] == "o" && input_str[(k+2)*8 +: 8] == "u" && input_str[(k+3)*8 +: 8] == "r" && (input_str[(k+4)*8 +: 8] == 8'h20 || k+4 >= 40)) begin
                                    values[num_values] <= 4'd4;
                                    k <= k + 5;
                                    num_values <= num_values + 1;
                                end
                                // Check 'five'
                                else if (input_str[k*8 +: 8] == "f" && input_str[(k+1)*8 +: 8] == "i" && input_str[(k+2)*8 +: 8] == "v" && input_str[(k+3)*8 +: 8] == "e" && (input_str[(k+4)*8 +: 8] == 8'h20 || k+4 >= 40)) begin
                                    values[num_values] <= 4'd5;
                                    k <= k + 5;
                                    num_values <= num_values + 1;
                                end
                                // Check 'six'
                                else if (input_str[k*8 +: 8] == "s" && input_str[(k+1)*8 +: 8] == "i" && input_str[(k+2)*8 +: 8] == "x" && (input_str[(k+3)*8 +: 8] == 8'h20 || k+3 >= 40)) begin
                                    values[num_values] <= 4'd6;
                                    k <= k + 4;
                                    num_values <= num_values + 1;
                                end
                                // Check 'seven'
                                else if (input_str[k*8 +: 8] == "s" && input_str[(k+1)*8 +: 8] == "e" && input_str[(k+2)*8 +: 8] == "v" && input_str[(k+3)*8 +: 8] == "e" && input_str[(k+4)*8 +: 8] == "n" && (input_str[(k+5)*8 +: 8] == 8'h20 || k+5 >= 40)) begin
                                    values[num_values] <= 4'd7;
                                    k <= k + 6;
                                    num_values <= num_values + 1;
                                end
                                // Check 'eight'
                                else if (input_str[k*8 +: 8] == "e" && input_str[(k+1)*8 +: 8] == "i" && input_str[(k+2)*8 +: 8] == "g" && input_str[(k+3)*8 +: 8] == "h" && input_str[(k+4)*8 +: 8] == "t" && (input_str[(k+5)*8 +: 8] == 8'h20 || k+5 >= 40)) begin
                                    values[num_values] <= 4'd8;
                                    k <= k + 6;
                                    num_values <= num_values + 1;
                                end
                                // Check 'nine'
                                else if (input_str[k*8 +: 8] == "n" && input_str[(k+1)*8 +: 8] == "i" && input_str[(k+2)*8 +: 8] == "n" && input_str[(k+3)*8 +: 8] == "e" && (input_str[(k+4)*8 +: 8] == 8'h20 || k+4 >= 40)) begin
                                    values[num_values] <= 4'd9;
                                    k <= k + 5;
                                    num_values <= num_values + 1;
                                end
                                else begin
                                    // Skip unknown char or garbage
                                    k <= k + 1;
                                end
                            end else begin
                                k <= k + 1; // Full, skip rest
                            end
                        end else begin
                            k <= k + 1; // Skip space
                        end
                    end else begin
                        // End of string
                        if (num_values > 0) begin
                            state <= SORT;
                            i <= 0;
                            j <= 0;
                        end else begin
                            state <= IDLE; // No valid numbers
                        end
                    end
                end

                SORT: begin
                    // Bubble sort
                    // First loop i from 0 to num_values-1
                    // Second loop j from 0 to num_values-i-1
                    // If values[j] > values[j+1], swap
                    if (i < num_values - 1) begin
                        if (j < num_values - 1 - i) begin
                            if (values[j] > values[j+1]) begin
                                // Swap
                                values[j] <= values[j+1];
                                values[j+1] <= values[j];
                            end
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        i <= 0;
                        state <= CONVERT;
                    end
                end

                CONVERT: begin
                    // Convert binary values back to ASCII words
                    // Each word is max 5 chars + 1 space = 6 chars * 8 bits = 48 bits per word in output buffer (but we only need 40 chars total)
                    // We will build 8-byte chunks in out_words array
                    case (values[i])
                        0: out_words[i] <= {"zero", 8'h20};
                        1: out_words[i] <= {"one ", 8'h20}; // 'one' + space + 1 byte filler? No, pad with space if needed? "one " is 4 bytes, need 8 bytes for alignment if we use 32-bit reg
                        // Actually, the output is [319:0], 40 bytes.
                        // Let's just build 5 chars + 1 space = 6 chars.
                        // Wait, 'three' is 5 chars. ' ' is 1 char. Total 6 chars.
                        // 6 chars * 8 bits = 48 bits. A 32-bit reg isn't enough.
                        // Let's use 64-bit regs for convenience or build directly.
                        // Re-evaluating build: Let's build 5 bytes (ASCII) + 1 byte space in 48-bit chunks.
                        // But Verilog reg must be power of 2 usually. Let's use 64-bit buffer for intermediate.
                    endcase
                    
                    // To save states/complexity, let's do logic to fill the result register directly in BUILD_OUTPUT
                    // But we need to convert values[i] to string. 
                    // Let's stay in CONVERT state and just set a register for the current word's ASCII
                    // then go to BUILD.
                    
                    if (i < num_values) begin
                        case (values[i])
                            0: out_words[i] <= {"zero", 8'h20, 24'h0};
                            1: out_words[i] <= {"one ", 8'h20, 24'h0}; // "one " (4 chars) + space (1 char) = 5. Wait, "one" is 3.
                            // Spec says: "zero" to "nine". Then space.
                            // "zero" (4) + space (1) = 5. "one" (3) + space (1) = 4.
                            // The input format is fixed 40 chars. Output must be same format.
                            // If input is "one two three", output is "one two three".
                            // Wait, requirement says: "Reconstruct output string with space delimiters".
                            // It does NOT say fixed width per number.
                            // It says "Fixed 40-character string" input. Output should be in SAME format.
                            // Maybe it implies we keep the variable length words but pad the end with spaces to 40 chars?
                            // Or maybe we assume up to 8 words, max length 5+1=6. 8*6=48 > 40.
                            // Let's assume we fit as many as we can into 40 chars.
                            // Actually, sorting network logic usually implies we sort the extracted list.
                            // Let's write the ASCII words sequentially into the result register.
                            // 'result' is [319:0] (40 bytes).
                            // Let's build the ASCII string byte by byte in BUILD_OUTPUT to be safe and robust.
                            // So CONVERT just marks that we are ready to build.
                        endcase
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        state <= BUILD_OUTPUT;
                        count <= 0; // Byte index for result
                        k <= 0; // Index of value we are writing
                    end
                end
                
                BUILD_OUTPUT: begin
                    // Write word by word
                    if (k < num_values && count < 40) begin
                        case (values[k])
                            0: begin
                                if (count < 38) result[count*8 +: 8] <= "z"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "r"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "o"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            1: begin
                                if (count < 38) result[count*8 +: 8] <= "o"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "n"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            2: begin
                                if (count < 38) result[count*8 +: 8] <= "t"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "w"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "o"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            3: begin
                                if (count < 38) result[count*8 +: 8] <= "t"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "h"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "r"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            4: begin
                                if (count < 38) result[count*8 +: 8] <= "f"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "o"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "u"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "r"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            5: begin
                                if (count < 38) result[count*8 +: 8] <= "f"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "i"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "v"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            6: begin
                                if (count < 38) result[count*8 +: 8] <= "s"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "i"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "x"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            7: begin
                                if (count < 38) result[count*8 +: 8] <= "s"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "v"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "n"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            8: begin
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "i"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "g"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "h"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "t"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                            9: begin
                                if (count < 38) result[count*8 +: 8] <= "n"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "i"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "n"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= "e"; count <= count + 1;
                                if (count < 38) result[count*8 +: 8] <= 8'h20; count <= count + 1;
                            end
                        endcase
                        k <= k + 1;
                    end else begin
                        // Pad rest with spaces if needed (or leave as is, specs say same format, input had spaces)
                        // Let's ensure 40 chars are filled. If we wrote less, fill remaining with spaces.
                        // Actually, just filling up to 40 is standard.
                        if (count < 40) begin
                            result[count*8 +: 8] <= 8'h20;
                            count <= count + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for start to go low to return to IDLE
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
