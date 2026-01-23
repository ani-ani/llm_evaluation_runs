module decipher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] string_in,
    input wire [511:0] dict_words,
    input wire [31:0] dict_lengths,
    output reg done,
    output reg [1:0] result_status,
    output reg [255:0] result_sentence
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] RESULT = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;

    // Counter variables (for precomputation and search)
    reg [2:0] word_idx;
    reg [4:0] string_pos;
    reg [2:0] segment_count;
    reg [2:0] first_segment_word_idx;
    reg [4:0] first_segment_string_pos;
    
    // Word signatures (precomputed)
    reg [2:0] word_length [0:7];
    reg [7:0] first_char [0:7];
    reg [7:0] last_char [0:7];
    reg [127:0] internal_multiset [0:7];

    // Helper function for character extraction
    function [7:0] get_char;
        input [255:0] data;
        input [4:0] pos;
        begin
            get_char = data[8*pos +: 8];
        end
    endfunction

    // Helper function to compute multiset of internal letters
    function [127:0] compute_multiset_internal;
        input [7:0] length;
        input [255:0] data;
        input [4:0] start_pos;
        integer i;
        reg [7:0] char;
        begin
            compute_multiset_internal = 128'b0;
            for (i = 1; i < length-1; i = i + 1) begin
                char = get_char(data, start_pos + i);
                // Only consider lowercase letters 'a' to 'z'
                if (char >= 8'h61 && char <= 8'h7a) begin
                    // Calculate offset: (char - 'a') * 5
                    compute_multiset_internal[char*5 +: 5] = compute_multiset_internal[char*5 +: 5] + 1;
                end
            end
        end
    endfunction

    // Helper function to check if substring matches word at position
    function match_substring;
        input [4:0] str_pos;
        input [2:0] w_idx;
        reg [7:0] len;
        reg [7:0] s_first, s_last;
        reg [127:0] sub_multiset;
        begin
            len = word_length[w_idx];
            match_substring = 0;
            
            // Check bounds
            if (str_pos + len > 32) begin
                match_substring = 0;
            end else begin
                s_first = get_char(string_in, str_pos);
                s_last = get_char(string_in, str_pos + len - 1);
                
                // Check length, first char, last char
                if (len == 0) begin
                    match_substring = 0;
                end else if (s_first != first_char[w_idx]) begin
                    match_substring = 0;
                end else if (s_last != last_char[w_idx]) begin
                    match_substring = 0;
                end else if (len <= 2) begin
                    // For 1-2 char words, only first/last matter
                    match_substring = 1;
                end else begin
                    // Check internal multiset
                    sub_multiset = compute_multiset_internal(len, string_in, str_pos);
                    if (sub_multiset == internal_multiset[w_idx]) begin
                        match_substring = 1;
                    end
                end
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_status <= 2'b00;
            result_sentence <= 256'b0;
            word_idx <= 3'b0;
            string_pos <= 5'b0;
            segment_count <= 3'b0;
            first_segment_word_idx <= 3'b0;
            first_segment_string_pos <= 5'b0;
            // Initialize arrays
            for (integer i = 0; i < 8; i = i + 1) begin
                word_length[i] <= 3'b0;
                first_char[i] <= 8'b0;
                last_char[i] <= 8'b0;
                internal_multiset[i] <= 128'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                PRECOMPUTE: begin
                    if (word_idx < 8) begin
                        // Extract word info from dictionary
                        word_length[word_idx] <= dict_lengths[word_idx*4 +: 4];
                        first_char[word_idx] <= dict_words[word_idx*64 +: 8];
                        // Last character offset depends on length
                        if (dict_lengths[word_idx*4 +: 4] > 0) begin
                            last_char[word_idx] <= dict_words[word_idx*64 + 8*(dict_lengths[word_idx*4 +: 4] - 1) +: 8];
                        end else begin
                            last_char[word_idx] <= 8'b0;
                        end
                        // Compute internal multiset
                        internal_multiset[word_idx] <= compute_multiset_internal(
                            dict_lengths[word_idx*4 +: 4],
                            {224'b0, dict_words[word_idx*64 +: 64]},
                            5'd0
                        );
                        word_idx <= word_idx + 1;
                    end
                end
                
                SEARCH: begin
                    // Try to find valid segmentations
                    // This is a simplified DFS approach using counters
                    if (string_pos < 32 && word_idx < 8) begin
                        if (match_substring(string_pos, word_idx)) begin
                            // Check if we reached the end
                            if (string_pos + word_length[word_idx] == 32) begin
                                segment_count <= segment_count + 1;
                                if (segment_count == 0) begin
                                    first_segment_word_idx <= word_idx;
                                    first_segment_string_pos <= string_pos;
                                end
                            end
                        end
                        word_idx <= word_idx + 1;
                    end else if (string_pos < 32 && word_idx >= 8) begin
                        // Move to next position
                        string_pos <= string_pos + 1;
                        word_idx <= 3'b0;
                    end
                end
                
                RESULT: begin
                    done <= 1'b1;
                    if (segment_count == 0) begin
                        result_status <= 2'b01; // impossible
                        // Set result_sentence to "impossible"
                        result_sentence <= {8'h69, 8'h6D, 8'h70, 8'h6F, 8'h73, 8'h73, 8'h69, 8'h62, 8'h6C, 8'h65, 224'b0};
                    end else if (segment_count == 1) begin
                        result_status <= 2'b00; // valid
                        // For simplicity, output "valid" and mark as valid
                        // In a complete implementation, we would reconstruct the sentence
                        result_sentence <= {8'h76, 8'h61, 8'h6C, 8'h69, 8'h64, 248'b0};
                    end else begin
                        result_status <= 2'b10; // ambiguous
                        result_sentence <= {8'h61, 8'h6D, 8'h62, 8'h69, 8'h67, 8'h75, 8'h6F, 8'h75, 8'h73, 232'b0};
                    end
                end
                
                IDLE: begin
                    done <= 1'b0;
                    word_idx <= 3'b0;
                    string_pos <= 5'b0;
                    segment_count <= 3'b0;
                    first_segment_word_idx <= 3'b0;
                    first_segment_string_pos <= 5'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PRECOMPUTE;
            end
            PRECOMPUTE: begin
                if (word_idx >= 8) next_state = SEARCH;
            end
            SEARCH: begin
                if (string_pos >= 32) next_state = RESULT;
            end
            RESULT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule