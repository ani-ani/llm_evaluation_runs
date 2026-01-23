module longest_repeated_substring (
    input [127:0] char_array,
    input [3:0] valid_len,
    output reg [127:0] result_string,
    output reg [3:0] result_len
);

    // Intermediate storage for candidate substrings found at each length
    // We will check lengths 15 down to 1.
    // For each length L, we need to store the best candidate found.
    
    // Helper signals to unpack characters for easier access
    // char_array[7:0] is char 0, char_array[15:8] is char 1, etc.
    wire [7:0] chars [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : unpack_chars
            assign chars[i] = char_array[8*i + 7: 8*i];
        end
    endgenerate

    // Lexicographical comparison function
    // Returns 1 if A < B (lexicographically)
    // Assumes length of comparison is fixed externally, but we pass length.
    function automatic logic is_less_than(
        input [127:0] A,
        input [127:0] B,
        input [3:0] len
    );
        integer k;
        logic [7:0] char_a, char_b;
        begin
            is_less_than = 1'b0;
            // Compare from start (char 0) to end
            for (k = 0; k < 16; k = k + 1) begin
                if (k < len) begin
                    char_a = A[8*k + 7:8*k];
                    char_b = B[8*k + 7:8*k];
                    if (char_a < char_b) begin
                        is_less_than = 1'b1;
                        return; // Found a difference, A < B
                    end else if (char_a > char_b) begin
                        is_less_than = 1'b0;
                        return; // Found a difference, A > B
                    end
                    // If equal, continue to next character
                end
            end
            // If we reach here, strings are equal (or len is 0)
            is_less_than = 1'b0;
        end
    endfunction

    // Equality check function
    function automatic logic is_equal(
        input [127:0] A,
        input [127:0] B,
        input [3:0] len
    );
        integer k;
        begin
            is_equal = 1'b1;
            for (k = 0; k < 16; k = k + 1) begin
                if (k < len) begin
                    if (A[8*k + 7:8*k] != B[8*k + 7:8*k]) begin
                        is_equal = 1'b0;
                        return;
                    end
                end
            end
        end
    endfunction

    // Extract substring function
    // Extracts substring starting at 'start' of length 'len' from 'full_string'
    // Result is packed into [127:0] with nulls for rest, left aligned is standard, 
    // but we usually pack [7:0] as first char. 
    // Let's pack [7:0] as char 0 of the substring.
    function automatic [127:0] extract_sub(
        input [127:0] full_string,
        input [3:0] start,
        input [3:0] len
    );
        integer s, d;
        begin
            extract_sub = 128'd0;
            d = 0;
            for (s = 0; s < 16; s = s + 1) begin
                if (s >= start && s < (start + len)) begin
                    extract_sub[8*d + 7:8*d] = full_string[8*s + 7:8*s];
                    d = d + 1;
                end
            end
        end
    endfunction

    // Logic for length 15
    reg found_15;
    reg [127:0] best_15;
    reg [3:0] len_15;
    integer i_15, j_15;
    reg [127:0] sub1_15, sub2_15;
    
    always @(*) begin
        found_15 = 1'b0;
        best_15 = 128'd0;
        len_15 = 4'd0;
        if (valid_len >= 15) begin
            // Check all pairs (i, j) where j > i
            // To be efficient, we can break loops once we find one, 
            // but we need to find the smallest one.
            // Since i goes 0, 1, ..., and we compare j > i.
            // If we find a match at (i, j), we must check if it's smaller than current best.
            
            // Optimization: We need to iterate. For pure combinational unrolled logic,
            // we can generate a signal for every valid pair.
            
            // Nested loops unrolled manually or via generate, but here inside always block is fine if we keep it clean.
            // Let's use a linear approach to find the minimum.
            
            // Since this is comb logic, we can't break. We must compare all.
            // Let's implement a priority scheme.
            // We want the lexicographically smallest substring of length L that repeats.
            // Since 'i' is the start index, checking i=0, then i=1, etc, doesn't guarantee lexicographical order because 'i' is index, not value.
            // Example: string "abba", length 2. i=0 "ab", i=1 "bb", i=2 "ba".
            // "ab" < "ba" < "bb". i=0 gives "ab" which is smallest. But "ba" is at i=2.
            // So we cannot just stop at first match.
            
            // Strategy: Generate all valid substrings of length 15, compare them using the function.
            
            // Loop i 0 to valid_len - 15
            for (i_15 = 0; i_15 < 16; i_15 = i_15 + 1) begin
                if (i_15 <= valid_len - 15) begin
                    // Loop j i_15 + 1 to valid_len - 15
                    for (j_15 = i_15 + 1; j_15 < 16; j_15 = j_15 + 1) begin
                        if (j_15 <= valid_len - 15) begin
                            sub1_15 = extract_sub(char_array, i_15[3:0], 4'd15);
                            sub2_15 = extract_sub(char_array, j_15[3:0], 4'd15);
                            if (is_equal(sub1_15, sub2_15, 4'd15)) begin
                                // Match found
                                if (!found_15 || is_less_than(sub1_15, best_15, 4'd15)) begin
                                    best_15 = sub1_15;
                                    found_15 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_15) len_15 = 4'd15;
        end
    end

    // Logic for length 14
    reg found_14;
    reg [127:0] best_14;
    reg [3:0] len_14;
    integer i_14, j_14;
    reg [127:0] sub1_14, sub2_14;
    
    always @(*) begin
        found_14 = 1'b0;
        best_14 = 128'd0;
        len_14 = 4'd0;
        if (valid_len >= 14) begin
            for (i_14 = 0; i_14 < 16; i_14 = i_14 + 1) begin
                if (i_14 <= valid_len - 14) begin
                    for (j_14 = i_14 + 1; j_14 < 16; j_14 = j_14 + 1) begin
                        if (j_14 <= valid_len - 14) begin
                            sub1_14 = extract_sub(char_array, i_14[3:0], 4'd14);
                            sub2_14 = extract_sub(char_array, j_14[3:0], 4'd14);
                            if (is_equal(sub1_14, sub2_14, 4'd14)) begin
                                if (!found_14 || is_less_than(sub1_14, best_14, 4'd14)) begin
                                    best_14 = sub1_14;
                                    found_14 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_14) len_14 = 4'd14;
        end
    end

    // Logic for length 13
    reg found_13;
    reg [127:0] best_13;
    reg [3:0] len_13;
    integer i_13, j_13;
    reg [127:0] sub1_13, sub2_13;
    
    always @(*) begin
        found_13 = 1'b0;
        best_13 = 128'd0;
        len_13 = 4'd0;
        if (valid_len >= 13) begin
            for (i_13 = 0; i_13 < 16; i_13 = i_13 + 1) begin
                if (i_13 <= valid_len - 13) begin
                    for (j_13 = i_13 + 1; j_13 < 16; j_13 = j_13 + 1) begin
                        if (j_13 <= valid_len - 13) begin
                            sub1_13 = extract_sub(char_array, i_13[3:0], 4'd13);
                            sub2_13 = extract_sub(char_array, j_13[3:0], 4'd13);
                            if (is_equal(sub1_13, sub2_13, 4'd13)) begin
                                if (!found_13 || is_less_than(sub1_13, best_13, 4'd13)) begin
                                    best_13 = sub1_13;
                                    found_13 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_13) len_13 = 4'd13;
        end
    end

    // Logic for length 12
    reg found_12;
    reg [127:0] best_12;
    reg [3:0] len_12;
    integer i_12, j_12;
    reg [127:0] sub1_12, sub2_12;
    
    always @(*) begin
        found_12 = 1'b0;
        best_12 = 128'd0;
        len_12 = 4'd0;
        if (valid_len >= 12) begin
            for (i_12 = 0; i_12 < 16; i_12 = i_12 + 1) begin
                if (i_12 <= valid_len - 12) begin
                    for (j_12 = i_12 + 1; j_12 < 16; j_12 = j_12 + 1) begin
                        if (j_12 <= valid_len - 12) begin
                            sub1_12 = extract_sub(char_array, i_12[3:0], 4'd12);
                            sub2_12 = extract_sub(char_array, j_12[3:0], 4'd12);
                            if (is_equal(sub1_12, sub2_12, 4'd12)) begin
                                if (!found_12 || is_less_than(sub1_12, best_12, 4'd12)) begin
                                    best_12 = sub1_12;
                                    found_12 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_12) len_12 = 4'd12;
        end
    end

    // Logic for length 11
    reg found_11;
    reg [127:0] best_11;
    reg [3:0] len_11;
    integer i_11, j_11;
    reg [127:0] sub1_11, sub2_11;
    
    always @(*) begin
        found_11 = 1'b0;
        best_11 = 128'd0;
        len_11 = 4'd0;
        if (valid_len >= 11) begin
            for (i_11 = 0; i_11 < 16; i_11 = i_11 + 1) begin
                if (i_11 <= valid_len - 11) begin
                    for (j_11 = i_11 + 1; j_11 < 16; j_11 = j_11 + 1) begin
                        if (j_11 <= valid_len - 11) begin
                            sub1_11 = extract_sub(char_array, i_11[3:0], 4'd11);
                            sub2_11 = extract_sub(char_array, j_11[3:0], 4'd11);
                            if (is_equal(sub1_11, sub2_11, 4'd11)) begin
                                if (!found_11 || is_less_than(sub1_11, best_11, 4'd11)) begin
                                    best_11 = sub1_11;
                                    found_11 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_11) len_11 = 4'd11;
        end
    end

    // Logic for length 10
    reg found_10;
    reg [127:0] best_10;
    reg [3:0] len_10;
    integer i_10, j_10;
    reg [127:0] sub1_10, sub2_10;
    
    always @(*) begin
        found_10 = 1'b0;
        best_10 = 128'd0;
        len_10 = 4'd0;
        if (valid_len >= 10) begin
            for (i_10 = 0; i_10 < 16; i_10 = i_10 + 1) begin
                if (i_10 <= valid_len - 10) begin
                    for (j_10 = i_10 + 1; j_10 < 16; j_10 = j_10 + 1) begin
                        if (j_10 <= valid_len - 10) begin
                            sub1_10 = extract_sub(char_array, i_10[3:0], 4'd10);
                            sub2_10 = extract_sub(char_array, j_10[3:0], 4'd10);
                            if (is_equal(sub1_10, sub2_10, 4'd10)) begin
                                if (!found_10 || is_less_than(sub1_10, best_10, 4'd10)) begin
                                    best_10 = sub1_10;
                                    found_10 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_10) len_10 = 4'd10;
        end
    end

    // Logic for length 9
    reg found_9;
    reg [127:0] best_9;
    reg [3:0] len_9;
    integer i_9, j_9;
    reg [127:0] sub1_9, sub2_9;
    
    always @(*) begin
        found_9 = 1'b0;
        best_9 = 128'd0;
        len_9 = 4'd0;
        if (valid_len >= 9) begin
            for (i_9 = 0; i_9 < 16; i_9 = i_9 + 1) begin
                if (i_9 <= valid_len - 9) begin
                    for (j_9 = i_9 + 1; j_9 < 16; j_9 = j_9 + 1) begin
                        if (j_9 <= valid_len - 9) begin
                            sub1_9 = extract_sub(char_array, i_9[3:0], 4'd9);
                            sub2_9 = extract_sub(char_array, j_9[3:0], 4'd9);
                            if (is_equal(sub1_9, sub2_9, 4'd9)) begin
                                if (!found_9 || is_less_than(sub1_9, best_9, 4'd9)) begin
                                    best_9 = sub1_9;
                                    found_9 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_9) len_9 = 4'd9;
        end
    end

    // Logic for length 8
    reg found_8;
    reg [127:0] best_8;
    reg [3:0] len_8;
    integer i_8, j_8;
    reg [127:0] sub1_8, sub2_8;
    
    always @(*) begin
        found_8 = 1'b0;
        best_8 = 128'd0;
        len_8 = 4'd0;
        if (valid_len >= 8) begin
            for (i_8 = 0; i_8 < 16; i_8 = i_8 + 1) begin
                if (i_8 <= valid_len - 8) begin
                    for (j_8 = i_8 + 1; j_8 < 16; j_8 = j_8 + 1) begin
                        if (j_8 <= valid_len - 8) begin
                            sub1_8 = extract_sub(char_array, i_8[3:0], 4'd8);
                            sub2_8 = extract_sub(char_array, j_8[3:0], 4'd8);
                            if (is_equal(sub1_8, sub2_8, 4'd8)) begin
                                if (!found_8 || is_less_than(sub1_8, best_8, 4'd8)) begin
                                    best_8 = sub1_8;
                                    found_8 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_8) len_8 = 4'd8;
        end
    end

    // Logic for length 7
    reg found_7;
    reg [127:0] best_7;
    reg [3:0] len_7;
    integer i_7, j_7;
    reg [127:0] sub1_7, sub2_7;
    
    always @(*) begin
        found_7 = 1'b0;
        best_7 = 128'd0;
        len_7 = 4'd0;
        if (valid_len >= 7) begin
            for (i_7 = 0; i_7 < 16; i_7 = i_7 + 1) begin
                if (i_7 <= valid_len - 7) begin
                    for (j_7 = i_7 + 1; j_7 < 16; j_7 = j_7 + 1) begin
                        if (j_7 <= valid_len - 7) begin
                            sub1_7 = extract_sub(char_array, i_7[3:0], 4'd7);
                            sub2_7 = extract_sub(char_array, j_7[3:0], 4'd7);
                            if (is_equal(sub1_7, sub2_7, 4'd7)) begin
                                if (!found_7 || is_less_than(sub1_7, best_7, 4'd7)) begin
                                    best_7 = sub1_7;
                                    found_7 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_7) len_7 = 4'd7;
        end
    end

    // Logic for length 6
    reg found_6;
    reg [127:0] best_6;
    reg [3:0] len_6;
    integer i_6, j_6;
    reg [127:0] sub1_6, sub2_6;
    
    always @(*) begin
        found_6 = 1'b0;
        best_6 = 128'd0;
        len_6 = 4'd0;
        if (valid_len >= 6) begin
            for (i_6 = 0; i_6 < 16; i_6 = i_6 + 1) begin
                if (i_6 <= valid_len - 6) begin
                    for (j_6 = i_6 + 1; j_6 < 16; j_6 = j_6 + 1) begin
                        if (j_6 <= valid_len - 6) begin
                            sub1_6 = extract_sub(char_array, i_6[3:0], 4'd6);
                            sub2_6 = extract_sub(char_array, j_6[3:0], 4'd6);
                            if (is_equal(sub1_6, sub2_6, 4'd6)) begin
                                if (!found_6 || is_less_than(sub1_6, best_6, 4'd6)) begin
                                    best_6 = sub1_6;
                                    found_6 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_6) len_6 = 4'd6;
        end
    end

    // Logic for length 5
    reg found_5;
    reg [127:0] best_5;
    reg [3:0] len_5;
    integer i_5, j_5;
    reg [127:0] sub1_5, sub2_5;
    
    always @(*) begin
        found_5 = 1'b0;
        best_5 = 128'd0;
        len_5 = 4'd0;
        if (valid_len >= 5) begin
            for (i_5 = 0; i_5 < 16; i_5 = i_5 + 1) begin
                if (i_5 <= valid_len - 5) begin
                    for (j_5 = i_5 + 1; j_5 < 16; j_5 = j_5 + 1) begin
                        if (j_5 <= valid_len - 5) begin
                            sub1_5 = extract_sub(char_array, i_5[3:0], 4'd5);
                            sub2_5 = extract_sub(char_array, j_5[3:0], 4'd5);
                            if (is_equal(sub1_5, sub2_5, 4'd5)) begin
                                if (!found_5 || is_less_than(sub1_5, best_5, 4'd5)) begin
                                    best_5 = sub1_5;
                                    found_5 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_5) len_5 = 4'd5;
        end
    end

    // Logic for length 4
    reg found_4;
    reg [127:0] best_4;
    reg [3:0] len_4;
    integer i_4, j_4;
    reg [127:0] sub1_4, sub2_4;
    
    always @(*) begin
        found_4 = 1'b0;
        best_4 = 128'd0;
        len_4 = 4'd0;
        if (valid_len >= 4) begin
            for (i_4 = 0; i_4 < 16; i_4 = i_4 + 1) begin
                if (i_4 <= valid_len - 4) begin
                    for (j_4 = i_4 + 1; j_4 < 16; j_4 = j_4 + 1) begin
                        if (j_4 <= valid_len - 4) begin
                            sub1_4 = extract_sub(char_array, i_4[3:0], 4'd4);
                            sub2_4 = extract_sub(char_array, j_4[3:0], 4'd4);
                            if (is_equal(sub1_4, sub2_4, 4'd4)) begin
                                if (!found_4 || is_less_than(sub1_4, best_4, 4'd4)) begin
                                    best_4 = sub1_4;
                                    found_4 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_4) len_4 = 4'd4;
        end
    end

    // Logic for length 3
    reg found_3;
    reg [127:0] best_3;
    reg [3:0] len_3;
    integer i_3, j_3;
    reg [127:0] sub1_3, sub2_3;
    
    always @(*) begin
        found_3 = 1'b0;
        best_3 = 128'd0;
        len_3 = 4'd0;
        if (valid_len >= 3) begin
            for (i_3 = 0; i_3 < 16; i_3 = i_3 + 1) begin
                if (i_3 <= valid_len - 3) begin
                    for (j_3 = i_3 + 1; j_3 < 16; j_3 = j_3 + 1) begin
                        if (j_3 <= valid_len - 3) begin
                            sub1_3 = extract_sub(char_array, i_3[3:0], 4'd3);
                            sub2_3 = extract_sub(char_array, j_3[3:0], 4'd3);
                            if (is_equal(sub1_3, sub2_3, 4'd3)) begin
                                if (!found_3 || is_less_than(sub1_3, best_3, 4'd3)) begin
                                    best_3 = sub1_3;
                                    found_3 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_3) len_3 = 4'd3;
        end
    end

    // Logic for length 2
    reg found_2;
    reg [127:0] best_2;
    reg [3:0] len_2;
    integer i_2, j_2;
    reg [127:0] sub1_2, sub2_2;
    
    always @(*) begin
        found_2 = 1'b0;
        best_2 = 128'd0;
        len_2 = 4'd0;
        if (valid_len >= 2) begin
            for (i_2 = 0; i_2 < 16; i_2 = i_2 + 1) begin
                if (i_2 <= valid_len - 2) begin
                    for (j_2 = i_2 + 1; j_2 < 16; j_2 = j_2 + 1) begin
                        if (j_2 <= valid_len - 2) begin
                            sub1_2 = extract_sub(char_array, i_2[3:0], 4'd2);
                            sub2_2 = extract_sub(char_array, j_2[3:0], 4'd2);
                            if (is_equal(sub1_2, sub2_2, 4'd2)) begin
                                if (!found_2 || is_less_than(sub1_2, best_2, 4'd2)) begin
                                    best_2 = sub1_2;
                                    found_2 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_2) len_2 = 4'd2;
        end
    end

    // Logic for length 1
    reg found_1;
    reg [127:0] best_1;
    reg [3:0] len_1;
    integer i_1, j_1;
    reg [127:0] sub1_1, sub2_1;
    
    always @(*) begin
        found_1 = 1'b0;
        best_1 = 128'd0;
        len_1 = 4'd0;
        if (valid_len >= 1) begin
            for (i_1 = 0; i_1 < 16; i_1 = i_1 + 1) begin
                if (i_1 <= valid_len - 1) begin
                    for (j_1 = i_1 + 1; j_1 < 16; j_1 = j_1 + 1) begin
                        if (j_1 <= valid_len - 1) begin
                            sub1_1 = extract_sub(char_array, i_1[3:0], 4'd1);
                            sub2_1 = extract_sub(char_array, j_1[3:0], 4'd1);
                            if (is_equal(sub1_1, sub2_1, 4'd1)) begin
                                if (!found_1 || is_less_than(sub1_1, best_1, 4'd1)) begin
                                    best_1 = sub1_1;
                                    found_1 = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
            if (found_1) len_1 = 4'd1;
        end
    end

    // Final Mux for Output (Priority from 15 down to 1)
    always @(*) begin
        if (found_15) begin
            result_string = best_15;
            result_len = len_15;
        end else if (found_14) begin
            result_string = best_14;
            result_len = len_14;
        end else if (found_13) begin
            result_string = best_13;
            result_len = len_13;
        end else if (found_12) begin
            result_string = best_12;
            result_len = len_12;
        end else if (found_11) begin
            result_string = best_11;
            result_len = len_11;
        end else if (found_10) begin
            result_string = best_10;
            result_len = len_10;
        end else if (found_9) begin
            result_string = best_9;
            result_len = len_9;
        end else if (found_8) begin
            result_string = best_8;
            result_len = len_8;
        end else if (found_7) begin
            result_string = best_7;
            result_len = len_7;
        end else if (found_6) begin
            result_string = best_6;
            result_len = len_6;
        end else if (found_5) begin
            result_string = best_5;
            result_len = len_5;
        end else if (found_4) begin
            result_string = best_4;
            result_len = len_4;
        end else if (found_3) begin
            result_string = best_3;
            result_len = len_3;
        end else if (found_2) begin
            result_string = best_2;
            result_len = len_2;
        end else if (found_1) begin
            result_string = best_1;
            result_len = len_1;
        end else begin
            result_string = 128'd0;
            result_len = 4'd0;
        end
    end

endmodule
