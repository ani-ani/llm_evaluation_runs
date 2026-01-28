module StringGen (
    input [3:0] N,
    input [3:0] K,
    input [3:0] P,
    output reg [7:0] char_array [0:15],
    output reg valid,
    output reg error
);

    integer i;
    reg [3:0] used_chars;
    reg [3:0] half_len;
    reg [3:0] mid_offset;
    reg [3:0] block_start;
    reg [3:0] block_end;
    reg [3:0] distinct_needed;
    reg [3:0] distinct_count;
    reg [7:0] next_char;
    
    always @(*) begin
        // Initialize outputs
        valid = 1'b0;
        error = 1'b0;
        
        // Initialize all characters to 'a'
        for (i = 0; i < 16; i = i + 1) begin
            char_array[i] = 8'h61; // 'a'
        end
        
        // Error conditions
        if (P > N || K > N || P < 4'd1 || K < 4'd1 || N > 4'd16 || N < 4'd1) begin
            error = 1'b1;
            valid = 1'b0;
        end
        else if (P == 4'd1) begin
            // P == 1: Generate string with N distinct chars if K >= N
            if (K >= N) begin
                valid = 1'b1;
                for (i = 0; i < N; i = i + 1) begin
                    char_array[i] = 8'h61 + i[7:0]; // 'a' + i
                end
                // Fill remaining with 'a'
                for (i = N; i < 16; i = i + 1) begin
                    char_array[i] = 8'h61;
                end
            end
            else begin
                // K < N, generate repeating pattern ensuring no palindrome > 1
                // Pattern: 'abcabc...' (repeats every 3, K chars)
                if (K >= 4'd3) begin
                    valid = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        char_array[i] = 8'h61 + (i % 3);
                    end
                    for (i = N; i < 16; i = i + 1) begin
                        char_array[i] = 8'h61;
                    end
                end
                else if (K == 4'd2) begin
                    valid = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        char_array[i] = 8'h61 + (i % 2);
                    end
                    for (i = N; i < 16; i = i + 1) begin
                        char_array[i] = 8'h61;
                    end
                end
                else if (K == 4'd1) begin
                    valid = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        char_array[i] = 8'h61;
                    end
                    for (i = N; i < 16; i = i + 1) begin
                        char_array[i] = 8'h61;
                    end
                end
            end
        end
        else if (P == N) begin
            // P == N: Must be palindrome
            // Check feasibility: K <= N/2 + 1 (if N even) or K <= (N+1)/2 (if N odd)
            half_len = N >> 1;
            if ((N[0] == 1'b0 && K > (half_len + 4'd1)) || 
                (N[0] == 1'b1 && K > (half_len + 4'd1))) begin
                // For odd N: (N+1)/2 = N/2 + 1
                // For even N: N/2 + 1
                error = 1'b1;
                valid = 1'b0;
            end
            else begin
                valid = 1'b1;
                // Generate palindrome 'abc...cba' pattern
                for (i = 0; i < half_len; i = i + 1) begin
                    char_array[i] = 8'h61 + i[7:0];
                    char_array[N - 1 - i] = 8'h61 + i[7:0];
                end
                // Middle character if odd length
                if (N[0] == 1'b1) begin
                    char_array[half_len] = 8'h61 + half_len[7:0];
                end
                // Fill remaining with 'a'
                for (i = N; i < 16; i = i + 1) begin
                    char_array[i] = 8'h61;
                end
            end
        end
        else begin
            // 1 < P < N: Generate string with one palindromic block of length P
            // Place block in the middle to minimize interference
            // Remaining characters must be distinct to avoid longer palindromes
            
            distinct_needed = K - 4'd1; // One char for palindrome block
            
            // Check if we have enough distinct chars
            // Block needs ceil(P/2) distinct chars, remaining needs distinct_needed
            half_len = (P + 4'd1) >> 1; // ceil(P/2)
            
            // Maximum distinct chars we can place in the entire string is N
            if (distinct_needed + half_len > N) begin
                error = 1'b1;
                valid = 1'b0;
            end
            else begin
                valid = 1'b1;
                
                // Position block in the middle
                mid_offset = (N - P) >> 1;
                block_start = mid_offset;
                block_end = block_start + P;
                
                // Generate characters before block (distinct)
                distinct_count = 4'd0;
                next_char = 8'h61;
                
                // Fill characters before block
                for (i = 0; i < block_start; i = i + 1) begin
                    if (distinct_count < distinct_needed) begin
                        char_array[i] = next_char;
                        next_char = next_char + 8'd1;
                        distinct_count = distinct_count + 4'd1;
                    end
                    else begin
                        char_array[i] = 8'h61;
                    end
                end
                
                // Generate palindrome block
                // Use a new character for the block
                for (i = 0; i < half_len; i = i + 1) begin
                    char_array[block_start + i] = next_char;
                    char_array[block_end - 1 - i] = next_char;
                end
                next_char = next_char + 8'd1;
                distinct_count = distinct_count + 4'd1;
                
                // Fill characters after block (distinct)
                for (i = block_end; i < N; i = i + 1) begin
                    if (distinct_count < K) begin
                        char_array[i] = next_char;
                        next_char = next_char + 8'd1;
                        distinct_count = distinct_count + 4'd1;
                    end
                    else begin
                        char_array[i] = 8'h61;
                    end
                end
                
                // Fill remaining with 'a'
                for (i = N; i < 16; i = i + 1) begin
                    char_array[i] = 8'h61;
                end
            end
        end
    end

endmodule