module start_withp(
    input [79:0] input_string,
    output reg [7:0] word1_char0,
    output reg [7:0] word1_char1,
    output reg [7:0] word1_char2,
    output reg [7:0] word1_char3,
    output reg [7:0] word1_char4,
    output reg [7:0] word1_char5,
    output reg [7:0] word1_char6,
    output reg [7:0] word1_char7,
    output reg [7:0] word2_char0,
    output reg [7:0] word2_char1,
    output reg [7:0] word2_char2,
    output reg [7:0] word2_char3,
    output reg [7:0] word2_char4,
    output reg [7:0] word2_char5,
    output reg [7:0] word2_char6,
    output reg [7:0] word2_char7,
    output reg found
);

    // Extract bytes from input string
    wire [7:0] char [9:0];
    assign char[0] = input_string[7:0];
    assign char[1] = input_string[15:8];
    assign char[2] = input_string[23:16];
    assign char[3] = input_string[31:24];
    assign char[4] = input_string[39:32];
    assign char[5] = input_string[47:40];
    assign char[6] = input_string[55:48];
    assign char[7] = input_string[63:56];
    assign char[8] = input_string[71:64];
    assign char[9] = input_string[79:72];

    // Helper functions
    function automatic logic is_upper_alpha(input [7:0] c);
        is_upper_alpha = (c >= 8'h41 && c <= 8'h5A);
    endfunction

    function automatic logic is_lower_alpha(input [7:0] c);
        is_lower_alpha = (c >= 8'h61 && c <= 8'h7A);
    endfunction

    function automatic logic is_alpha(input [7:0] c);
        is_alpha = is_upper_alpha(c) || is_lower_alpha(c);
    endfunction

    function automatic logic is_p(input [7:0] c);
        is_p = (c == 8'h50) || (c == 8'h70);
    endfunction

    function automatic logic is_non_alpha_or_boundary(input [7:0] c);
        is_non_alpha_or_boundary = ~is_alpha(c);
    endfunction

    // Detect word start positions (either at index 0 or preceded by non-alpha)
    wire [9:0] is_word_start;
    assign is_word_start[0] = 1'b1; // Position 0 is always a potential start
    assign is_word_start[1] = is_non_alpha_or_boundary(char[0]);
    assign is_word_start[2] = is_non_alpha_or_boundary(char[1]);
    assign is_word_start[3] = is_non_alpha_or_boundary(char[2]);
    assign is_word_start[4] = is_non_alpha_or_boundary(char[3]);
    assign is_word_start[5] = is_non_alpha_or_boundary(char[4]);
    assign is_word_start[6] = is_non_alpha_or_boundary(char[5]);
    assign is_word_start[7] = is_non_alpha_or_boundary(char[6]);
    assign is_word_start[8] = is_non_alpha_or_boundary(char[7]);
    assign is_word_start[9] = is_non_alpha_or_boundary(char[8]);

    // Find all potential P/p word starts
    wire [9:0] p_start_valid;
    wire [9:0] is_p_start;
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_p_start
            assign is_p_start[i] = is_p(char[i]);
            assign p_start_valid[i] = is_word_start[i] && is_p_start[i];
        end
    endgenerate

    // First word selection
    // Priority: lower index = first found
    wire [3:0] first_word_idx;
    wire first_word_found;
    wire [9:0] first_word_end_mask;
    wire [9:0] second_word_scan_mask;
    
    // Find first word index
    assign first_word_found = |p_start_valid;
    assign first_word_idx = (p_start_valid[0]) ? 4'd0 :
                            (p_start_valid[1]) ? 4'd1 :
                            (p_start_valid[2]) ? 4'd2 :
                            (p_start_valid[3]) ? 4'd3 :
                            (p_start_valid[4]) ? 4'd4 :
                            (p_start_valid[5]) ? 4'd5 :
                            (p_start_valid[6]) ? 4'd6 :
                            (p_start_valid[7]) ? 4'd7 :
                            (p_start_valid[8]) ? 4'd8 :
                            (p_start_valid[9]) ? 4'd9 : 4'd0;

    // Generate mask for first word characters (up to 8 chars, stop at non-alpha)
    // We need to know: start index, and then find the next non-alpha after start
    wire [9:0] first_word_char_mask;
    wire [3:0] first_word_len;
    wire [3:0] first_word_next_non_alpha_idx;
    
    // Find end of first word (next non-alpha after start)
    // We need to check positions from first_word_idx+1 to 9
    wire [9:0] is_non_alpha;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_non_alpha
            assign is_non_alpha[i] = is_non_alpha_or_boundary(char[i]);
        end
    endgenerate

    // Determine first word length (up to 8) and valid chars
    // This is complex combinational logic based on first_word_idx
    always @(*) begin
        // Initialize outputs to default
        word1_char0 = 8'h00;
        word1_char1 = 8'h00;
        word1_char2 = 8'h00;
        word1_char3 = 8'h00;
        word1_char4 = 8'h00;
        word1_char5 = 8'h00;
        word1_char6 = 8'h00;
        word1_char7 = 8'h00;
        word2_char0 = 8'h00;
        word2_char1 = 8'h00;
        word2_char2 = 8'h00;
        word2_char3 = 8'h00;
        word2_char4 = 8'h00;
        word2_char5 = 8'h00;
        word2_char6 = 8'h00;
        word2_char7 = 8'h00;
        found = 1'b0;

        if (first_word_found) begin
            // Extract First Word
            integer idx;
            integer w1_count;
            logic w1_done;
            w1_count = 0;
            w1_done = 0;
            
            // Scan for first word chars
            for (idx = first_word_idx; idx < 10; idx = idx + 1) begin
                if (!w1_done && w1_count < 8) begin
                    // First char is always P/p, valid
                    if (idx == first_word_idx) begin
                        case (w1_count)
                            0: word1_char0 = char[idx];
                            1: word1_char1 = char[idx];
                            2: word1_char2 = char[idx];
                            3: word1_char3 = char[idx];
                            4: word1_char4 = char[idx];
                            5: word1_char5 = char[idx];
                            6: word1_char6 = char[idx];
                            7: word1_char7 = char[idx];
                        endcase
                        w1_count = w1_count + 1;
                    end else begin
                        // Subsequent chars
                        if (!is_non_alpha[idx]) begin
                            case (w1_count)
                                0: word1_char0 = char[idx];
                                1: word1_char1 = char[idx];
                                2: word1_char2 = char[idx];
                                3: word1_char3 = char[idx];
                                4: word1_char4 = char[idx];
                                5: word1_char5 = char[idx];
                                6: word1_char6 = char[idx];
                                7: word1_char7 = char[idx];
                            endcase
                            w1_count = w1_count + 1;
                        end else begin
                            w1_done = 1'b1;
                        end
                    end
                end
            end

            // Find Second Word Start
            // Scan for next P/p that is a valid word start, AFTER first word ends
            integer s2_start_idx;
            logic s2_start_found;
            s2_start_found = 0;
            s2_start_idx = 0;
            
            // Determine where first word effectively ended for scanning purposes
            // If first word reached limit (8 chars), scan starts after char[first_word_idx+7]
            // If first word hit non-alpha, scan starts after that non-alpha
            
            // We need to find the boundary after first word
            integer boundary;
            boundary = first_word_idx;
            
            // Find the actual end of first word data in input (could be non-alpha or 8 chars)
            // Re-scan to find boundary
            for (int b = first_word_idx + 1; b < 10; b++) begin
                if (is_non_alpha[b] || (b - first_word_idx >= 8)) begin
                    boundary = b;
                    break;
                end
            end
            // If loop finished and word was continuous, boundary might be 10 or last index+1
            // Let's be precise: boundary is the index to start searching for word 2
            // It is usually after the last valid char of word 1 or after the first non-alpha
            
            // Proper logic: 
            // 1. Scan from first_word_idx + 1 onwards.
            // 2. Skip characters if they are part of word 1 (alphabetic).
            // 3. Stop skipping when non-alpha is found.
            // 4. From that point, look for P/p.
            
            logic skipped_w1;
            skipped_w1 = 0;
            
            for (int k = first_word_idx + 1; k < 10; k++) begin
                if (!skipped_w1) begin
                    if (is_non_alpha[k]) begin
                        skipped_w1 = 1'b1; // Found separator, next P/p is valid start
                    end
                    // If alpha, still in word 1, continue
                end else begin
                    // Already skipped word 1, now looking for word 2 start
                    // Check if index k is a valid start (preceded by non-alpha)
                    logic valid_start;
                    valid_start = 1'b0;
                    if (k == 0) valid_start = 1'b1;
                    else if (is_non_alpha[k-1]) valid_start = 1'b1;
                    
                    if (valid_start && is_p(char[k])) begin
                        s2_start_found = 1'b1;
                        s2_start_idx = k;
                        break;
                    end
                end
            end

            // Extract Second Word
            if (s2_start_found) begin
                integer w2_count;
                logic w2_done;
                w2_count = 0;
                w2_done = 0;
                
                for (int idx2 = s2_start_idx; idx2 < 10; idx2 = idx2 + 1) begin
                    if (!w2_done && w2_count < 8) begin
                        if (idx2 == s2_start_idx) begin
                            // First char of word 2 is valid (P/p)
                            case (w2_count)
                                0: word2_char0 = char[idx2];
                                1: word2_char1 = char[idx2];
                                2: word2_char2 = char[idx2];
                                3: word2_char3 = char[idx2];
                                4: word2_char4 = char[idx2];
                                5: word2_char5 = char[idx2];
                                6: word2_char6 = char[idx2];
                                7: word2_char7 = char[idx2];
                            endcase
                            w2_count = w2_count + 1;
                        end else begin
                            if (!is_non_alpha[idx2]) begin
                                case (w2_count)
                                    0: word2_char0 = char[idx2];
                                    1: word2_char1 = char[idx2];
                                    2: word2_char2 = char[idx2];
                                    3: word2_char3 = char[idx2];
                                    4: word2_char4 = char[idx2];
                                    5: word2_char5 = char[idx2];
                                    6: word2_char6 = char[idx2];
                                    7: word2_char7 = char[idx2];
                                endcase
                                w2_count = w2_count + 1;
                            end else begin
                                w2_done = 1'b1;
                            end
                        end
                    end
                end
                found = 1'b1;
            end
        end
    end

endmodule
